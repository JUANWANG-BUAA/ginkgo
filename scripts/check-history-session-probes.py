#!/usr/bin/env python3
"""Run injected, offline synthetic tests against unmodified release sources."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TAGS = [f"android-v0.1.0-beta.{number}" for number in range(3, 8)]
EXPECTED_FAILURES = {
    "3": {"gateway_mismatch", "captcha_type"},
    "4": {"fallback", "captcha_type"},
    "5": {"uc_unavailable", "gateway_mismatch"},
    "6": {"ticket", "uc_unavailable", "gateway_mismatch"},
    "7": {"ticket", "cold_boot", "cold_boot_remembered", "gateway_mismatch"},
    "working-tree": set(),
}
BASE = (ROOT / "scripts/history-session-probe.rs").read_text()
COLD = (ROOT / "scripts/history-session-cold-probe.rs").read_text()
CURRENT = (ROOT / "scripts/history-session-current-probe.rs").read_text()


def validate_run(version, returncode, output):
    scenarios = {"ticket", "fallback", "uc_unavailable", "gateway_mismatch", "captcha_type"}
    if version in {"7", "working-tree"}:
        scenarios |= {"cold_boot", "cold_boot_remembered"}
    if version == "working-tree":
        scenarios.add("checkin_direct_failure")
    observations = re.findall(r"\bOBS (\w+) ", output)
    if len(observations) != len(scenarios) or set(observations) != scenarios:
        raise ValueError(f"{version}: missing, duplicate or unexpected observations")
    summaries = re.findall(
        r"^test result: (ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored;",
        output, re.MULTILINE,
    )
    expected_failures = EXPECTED_FAILURES[version]
    expected_summary = (
        "FAILED" if expected_failures else "ok",
        str(len(scenarios) - len(expected_failures)), str(len(expected_failures)), "0",
    )
    failures = re.findall(
        r"^\s+services::tests::history_session_probe::history_session_observe_(\w+)\s*$",
        output, re.MULTILINE,
    )
    if summaries != [expected_summary] or len(failures) != len(expected_failures) or set(failures) != expected_failures:
        raise ValueError(f"{version}: test counts or named failures differ from the recorded matrix")
    if returncode != (101 if expected_failures else 0):
        raise ValueError(f"{version}: unexpected cargo exit status {returncode}")


def main():
    env = dict(os.environ, CARGO_NET_OFFLINE="true", CARGO_TARGET_DIR=str(ROOT / "rust/target"))
    for tag in TAGS + ["working-tree"]:
        with tempfile.TemporaryDirectory(prefix="ginkgo-history-") as temp:
            directory = Path(temp)
            if tag == "working-tree":
                shutil.copytree(ROOT / "rust", directory / "rust", ignore=shutil.ignore_patterns("target"))
                shutil.copytree(ROOT / "fixtures", directory / "fixtures")
                version, commit = tag, "uncommitted local sources"
            else:
                archive = directory / "source.tar"
                subprocess.run(["git", "archive", "--format=tar", f"--output={archive}", tag, "rust", "fixtures"], cwd=ROOT, check=True)
                subprocess.run(["tar", "-xf", str(archive), "-C", str(directory)], check=True)
                version = tag.rsplit(".", 1)[-1]
                commit = subprocess.check_output(["git", "rev-list", "-n", "1", tag], cwd=ROOT, text=True).strip()
            tests = directory / "rust/crates/ginkgo_upstream/src/services/tests.rs"
            with tests.open("a") as file:
                file.write("\n#[path = \"history_session_probe.rs\"]\nmod history_session_probe;\n")
            (tests.parent / "history_session_probe.rs").write_text(BASE + ("\n" + COLD if version in {"7", "working-tree"} else "") + ("\n" + CURRENT if version == "working-tree" else ""))
            print(f"\n{tag} {commit}", flush=True)
            result = subprocess.run(["cargo", "test", "--offline", "--locked", "-p", "ginkgo_upstream", "--no-default-features", "--lib", "history_session_observe", "--", "--nocapture", "--test-threads=1"], cwd=directory / "rust", env=env, text=True, capture_output=True, timeout=600)
            output = result.stdout + result.stderr
            for line in output.splitlines():
                if "OBS " in line or "test result:" in line or "panicked at" in line or "error[" in line or line.startswith("error:"):
                    print(line, flush=True)
            try:
                validate_run(version, result.returncode, output)
            except ValueError as error:
                print(output, flush=True)
                raise SystemExit(str(error)) from error
    print("\nObservations matched the recorded matrix; the listed assertion failures are observed defects or behavior differences, not product test passes.")

if __name__ == "__main__":
    main()

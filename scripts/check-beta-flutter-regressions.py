#!/usr/bin/env python3
"""Replay named UI regressions against immutable historical application sources.

Only test sources are injected. Compilation errors, skipped/missing tests and
runner failures never count as reproducing a historical product defect.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOTFIX = "bd97642133a8b754451be88be45bbdadf47f3fea"
CASES = [
    ("B4-reminder-cache", HOTFIX + "^", HOTFIX, "extended_reminders_test.dart",
     ["automatic reminder refresh reuses fresh page snapshots"]),
    ("B4-more-bottom", HOTFIX + "^", HOTFIX, "service_directory_injection_test.dart",
     ["last More service scrolls fully above the bottom tab bar"]),
    ("B4-empty-refresh", HOTFIX + "^", HOTFIX, "today_progressive_widget_test.dart",
     ["empty sections stay hidden during a background refresh"]),
    ("B7-grade-retry", "android-v0.1.0-beta.6", "android-v0.1.0-beta.7", "grades_term_recovery_test.dart",
     ["term selection remains available after the first grade read fails"]),
    ("B4-SPOC-refusal", HOTFIX + "^", HOTFIX, "native_learning_failure_regression_test.dart",
     ["native learning collections preserve upstream refusal without data"]),
    ("B5-seven-days", "34a6d61^", "34a6d61", "schedule_day_strip_regression_test.dart",
     ["all school days are reachable at 430.0 dp and 1.0 type"]),
    ("B5-four-modes", "3750149^", "3750149", "schedule_modes_regression_test.dart",
     ["four schedule modes stay operable at 320.0 dp / 1.4"]),
    ("B5-demo-detail", "a65651e^", "a65651e", "demo_bridge_contract_test.dart",
     ["native demo homework list and detail preserve the same assignment"]),
    ("B6-school-clock", "5215a1b^", "5215a1b", "school_wall_clock_bridge_test.dart",
     ["native rules interpret the Beijing wall clock once"]),
]
LOCAL_TESTS = {case[3] for case in CASES[4:]}
HOST_TESTS = {"demo_bridge_contract_test.dart", "school_wall_clock_bridge_test.dart"}


def read_verdict(output, names):
    events = []
    for line in output.splitlines():
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    starts = [event["test"] for event in events if event.get("type") == "testStart"]
    started = {event["id"]: event["name"] for event in starts}
    if len(starts) != len(started):
        raise ValueError("Duplicate test-start event")
    selected = {key: name for key, name in started.items() if name in names}
    if len(selected) != len(names) or set(selected.values()) != set(names):
        raise ValueError("Selected tests missing, renamed or duplicated; no reproduction claimed")
    completed = [event for event in events if event.get("type") == "testDone" and event.get("testID") in selected]
    if len(completed) != len(names) or len({event["testID"] for event in completed}) != len(names):
        raise ValueError("Selected tests did not each finish once")
    if any(event.get("skipped") or event.get("result") not in {"success", "failure", "error"} for event in completed):
        raise ValueError("Selected tests skipped or have unknown verdicts")
    done = [event for event in events if event.get("type") == "done"]
    if len(done) != 1:
        raise ValueError("Runner did not finish exactly once")
    return {selected[event["testID"]]: event["result"] for event in completed}, done[0]["success"]


def extract(revision, paths, directory):
    archive = directory / "source.tar"
    subprocess.run(["git", "archive", "--format=tar", f"--output={archive}", revision, *paths], cwd=ROOT, check=True)
    subprocess.run(["tar", "-xf", str(archive), "-C", str(directory)], check=True)


def run(folder, test_file, names, library=None):
    env = dict(os.environ, PUB_ENVIRONMENT="ginkgo-offline-regression")
    if library:
        env["GINKGO_HOST_BRIDGE"] = str(library)
    result = subprocess.run(
        ["flutter", "test", "--no-pub", "--reporter", "json", f"test/{test_file}", "--name", "^(?:" + "|".join(re.escape(name) for name in names) + ")$"],
        cwd=folder, env=env, text=True,
        capture_output=True, timeout=180,
    )
    try:
        verdict, success = read_verdict(result.stdout, names)
    except ValueError:
        print(result.stdout[-12000:] + result.stderr[-4000:], flush=True)
        raise
    expected_code = 0 if success else 1
    if result.returncode != expected_code or success != all(value == "success" for value in verdict.values()):
        raise ValueError(f"Unexpected flutter exit status: {result.returncode}")
    return verdict


def build_host(workspace, directory):
    if sys.platform not in {"darwin", "linux"}:
        raise SystemExit("Host bridge replay requires macOS or Linux")
    target = ROOT / "rust/target"
    result = subprocess.run(["cargo", "build", "--manifest-path", str(workspace / "Cargo.toml"), "--offline", "--locked", "-p", "ginkgo_flutter_bridge"],
                            env=dict(os.environ, CARGO_TARGET_DIR=str(target)), text=True, capture_output=True, timeout=600)
    if result.returncode:
        raise SystemExit("Historical host bridge did not compile; no reproduction claimed\n" + result.stdout + result.stderr)
    filename = "libginkgo_flutter_bridge." + ("dylib" if sys.platform == "darwin" else "so")
    library = directory / filename
    shutil.copyfile(target / "debug" / filename, library)
    return library


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--case", choices=[case[0] for case in CASES])
    args = parser.parse_args()
    report = {"source": "synthetic", "cases": []}
    for identifier, old, fixed, test_file, names in CASES:
        if args.case and identifier != args.case:
            continue
        case = {"id": identifier, "test_file": test_file, "observations": []}
        report["cases"].append(case)
        for revision, role in [(old, "faulty"), (fixed, "fixed")]:
            with tempfile.TemporaryDirectory(prefix="ginkgo-ui-history-") as temporary:
                directory = Path(temporary)
                paths = ["flutter", "fixtures"] + (["rust"] if test_file in HOST_TESTS else [])
                extract(revision, paths, directory)
                extract(fixed, ["flutter/test"], directory)
                folder = directory / "flutter"
                if test_file in LOCAL_TESTS:
                    shutil.copyfile(ROOT / "flutter/test" / test_file, folder / "test" / test_file)
                resolved = subprocess.run(["flutter", "pub", "get", "--offline"], cwd=folder, text=True, capture_output=True, timeout=120)
                if resolved.returncode:
                    raise SystemExit("Historical offline dependencies unavailable; no reproduction claimed\n" + resolved.stdout + resolved.stderr)
                library = build_host(directory / "rust", directory) if test_file in HOST_TESTS else None
                verdict = run(folder, test_file, names, library)
                if role == "faulty" and all(value == "success" for value in verdict.values()):
                    raise SystemExit(f"{identifier}: regression did not detect historical source")
                if role == "fixed" and any(value != "success" for value in verdict.values()):
                    raise SystemExit(f"{identifier}: pinned fixed source did not pass")
                commit = subprocess.check_output(["git", "rev-parse", revision], cwd=ROOT, text=True).strip()
                test_sha = hashlib.sha256((folder / "test" / test_file).read_bytes()).hexdigest()
                observation = {"commit": commit, "role": role, "test_sha256": test_sha, "tests": verdict}
                if library:
                    observation["native_library_sha256"] = hashlib.sha256(library.read_bytes()).hexdigest()
                case["observations"].append(observation)
                print(f"{identifier} {role}: {verdict}", flush=True)
                args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        with tempfile.TemporaryDirectory(prefix="ginkgo-current-host-") as temporary:
            library = build_host(ROOT / "rust", Path(temporary)) if test_file in HOST_TESTS else None
            verdict = run(ROOT / "flutter", test_file, names, library)
        if any(value != "success" for value in verdict.values()):
            raise SystemExit(f"{identifier}: current source did not pass")
        case["observations"].append({"role": "working-tree", "tests": verdict})
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("Named regressions failed on historical sources and passed on fixed/current sources")


if __name__ == "__main__":
    main()

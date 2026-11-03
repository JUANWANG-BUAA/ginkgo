#!/usr/bin/env python3
"""Execute pinned UBAA Ktor tests offline and compare two synthetic history traces.

Only --prepare-dependencies contacts public Gradle/Maven repositories. Tests run
with macOS network sandboxing and Gradle offline; no school account is used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from urllib.parse import parse_qsl, urlsplit

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "e8a397fcb35a68147eee65a94c66ffb84e2f09fe"
SANDBOX = '(version 1) (allow default) (deny network-outbound) (allow network-outbound (remote ip "localhost:*"))'
PROBE_SUITES = (
    "ReferenceSessionProbeTest", "ReferenceBusinessWireTest", "ReferenceTransportProbeTest",
    "ReferenceClockProbeTest",
)
BUSINESS_CASES = tuple(
    f"{route}-{scenario}"
    for route in ("direct", "webvpn")
    for scenario in ("terms", "checkin", "checkin-nonempty", "library", "grades", "classroom")
)


def validate_capture_ids(capture, key, expected):
    identifiers = [case["id"] for case in capture[key]]
    if not expected or identifiers != list(expected) or len(set(identifiers)) != len(identifiers):
        raise ValueError(f"Missing, duplicate, reordered or unexpected {key}: {identifiers}")


def validate_current_stages(found, reference):
    for scenario in ("ticket", "uc_unavailable"):
        if found.get(("working-tree", scenario)) != reference[scenario]:
            raise ValueError(f"Current authentication stages differ from pinned UBAA: {scenario}")


def original_suites(source):
    suites = []
    for path in sorted((source / "shared/src/commonTest/kotlin").rglob("*Test.kt")):
        content = path.read_text()
        package = re.search(r"^package ([\w.]+)", content, re.MULTILINE)
        classes = re.findall(r"^class (\w+Test)\b", content, re.MULTILINE)
        if not package or not classes or "@Test" not in content:
            raise ValueError(f"Review unrecognized reference test source: {path}")
        suites.extend(f"{package[1]}.{name}" for name in classes)
    if not suites or len(set(suites)) != len(suites):
        raise ValueError("Missing or duplicate original UBAA test suites")
    return suites


def canonical(request):
    parsed = urlsplit(request["url"])
    headers = {key.lower(): value for key, value in request["headers"].items()}
    if "cookie" in headers:
        headers["cookie"] = sorted(part.strip() for part in headers["cookie"].split(";"))
    body = request["body"]
    if "application/json" in headers.get("content-type", "") and body:
        body = json.loads(body)
    elif "application/x-www-form-urlencoded" in headers.get("content-type", ""):
        body = sorted(parse_qsl(body, keep_blank_values=True))
    return {"method": request["method"], "url": [parsed.scheme, parsed.netloc, parsed.path, sorted(parse_qsl(parsed.query, keep_blank_values=True)), parsed.fragment], "headers": headers, "body": body}


def business_probe(folder, reference_wire, env):
    directory = folder / "rust-copy"
    shutil.copytree(ROOT / "rust", directory / "rust", ignore=shutil.ignore_patterns("target"))
    shutil.copytree(ROOT / "fixtures", directory / "fixtures")
    rust_wire = folder / "rust-wire.json"
    probe_env = dict(env, CARGO_NET_OFFLINE="true", CARGO_TARGET_DIR=str(ROOT / "rust/target"), GINKGO_REFERENCE_DAY=reference_wire["day"], GINKGO_RUST_WIRE=str(rust_wire))
    result = subprocess.run(["sandbox-exec", "-p", SANDBOX, "cargo", "test", "--offline", "--locked", "-p", "ginkgo_upstream", "--no-default-features", "--lib", "reference_business_wire_capture"], cwd=directory / "rust", env=probe_env, text=True, capture_output=True, timeout=600)
    if not rust_wire.exists():
        print(result.stdout)
        print(result.stderr)
        raise SystemExit("Rust business wire probe did not pass")
    rust = json.loads(rust_wire.read_text())
    for capture in (reference_wire, rust):
        validate_capture_ids(capture, "cases", BUSINESS_CASES)
    comparisons = []
    for kotlin_case, rust_case in zip(reference_wire["cases"], rust["cases"], strict=True):
        if kotlin_case["id"] != rust_case["id"]:
            raise SystemExit("Business case identifiers differ")
        changes = []
        if kotlin_case.get("values") != rust_case.get("values"):
            changes.append({"field":"values", "ubaa":kotlin_case.get("values"), "rust":rust_case.get("values")})
        if kotlin_case["count"] != rust_case["count"]:
            changes.append({"field": "result-count", "ubaa": kotlin_case["count"], "rust": rust_case["count"]})
        left, right = kotlin_case["requests"], rust_case["requests"]
        if len(left) != len(right):
            changes.append({"field": "request-count", "ubaa": len(left), "rust": len(right)})
        for index, (before, after) in enumerate(zip(left, right)):
            before, after = canonical(before), canonical(after)
            for field in before:
                if before[field] != after[field]:
                    changes.append({"request": index + 1, "field": field, "ubaa": before[field], "rust": after[field]})
        policy = [{"request": 2, "field": "url", "ubaa": ["https", "app.buaa.edu.cn", "/site/classRoomQuery/index", [], ""], "rust": ["https", "d.buaa.edu.cn", "/https/77726476706e69737468656265737421f1e751d225256951300d8db9d6562d/site/classRoomQuery/index", [], ""]}] if kotlin_case["id"] == "webvpn-classroom" else []
        comparisons.append({"id": kotlin_case["id"], "differences": changes, "unexpected_differences": [change for change in changes if change not in policy], "missing_policy_differences": [change for change in policy if change not in changes]})
        print(f"Business {kotlin_case['id']}: {len(left)}/{len(right)} requests, {len(changes)} observed field differences", flush=True)
        for change in changes:
            print(json.dumps(change, ensure_ascii=False), flush=True)
    return {"ubaa": reference_wire, "rust": rust, "comparisons": comparisons, "rust_regression_passed": result.returncode == 0}


def auth_probe(folder, reference, env):
    workspace = folder / "rust-copy/rust"
    tests = workspace / "crates/ginkgo_upstream/src/services/tests.rs"
    with tests.open("a") as output:
        output.write('\n#[path = "reference_auth_probe.rs"]\nmod reference_auth_probe;\n')
    (tests.parent / "reference_auth_probe.rs").write_text("\n".join(
        (ROOT / "scripts" / name).read_text()
        for name in ("history-session-probe.rs", "history-session-cold-probe.rs", "history-session-current-probe.rs")
    ))
    wire = folder / "rust-auth-wire.json"
    probe_env = dict(env, CARGO_NET_OFFLINE="true", CARGO_TARGET_DIR=str(ROOT / "rust/target"), GINKGO_RUST_AUTH_WIRE=str(wire))
    result = subprocess.run(["sandbox-exec", "-p", SANDBOX, "cargo", "test", "--offline", "--locked", "-p", "ginkgo_upstream", "--no-default-features", "--lib", "reference_auth_wire_capture"], cwd=workspace, env=probe_env, text=True, capture_output=True, timeout=600)
    if result.returncode or not wire.exists():
        raise SystemExit("Authentication capture did not finish\n" + result.stdout + result.stderr)
    rust = json.loads(wire.read_text())
    if set(reference) != {"ticket", "uc_unavailable", "webvpn"} or set(rust) != set(reference):
        raise SystemExit("Missing authentication request capture")
    differences = []
    for scenario in reference:
        before, after = reference[scenario], rust[scenario]
        if scenario == "webvpn":
            if len(before) != 9 or len(after) != 5:
                raise SystemExit("WebVPN single-password policy request count changed")
            extra = before[5:]
            if [request["method"] for request in extra] != ["GET", "POST", "GET", "GET"]:
                raise SystemExit("Original additional direct-login policy changed")
            if sorted(parse_qsl(extra[1]["body"])) != sorted(parse_qsl(before[1]["body"])):
                raise SystemExit("Original second password submission changed")
            before = before[:5]
        if len(before) != len(after):
            differences.append({"scenario": scenario, "field": "request-count", "ubaa": len(before), "rust": len(after)})
        for index, (left, right) in enumerate(zip(before, after)):
            left, right = canonical(left), canonical(right)
            for field in left:
                if left[field] != right[field]:
                    differences.append({"scenario": scenario, "request": index + 1, "field": field, "ubaa": left[field], "rust": right[field]})
    print(f"Authentication full requests: {len(differences)} unexplained field differences; explicit WebVPN policy omits the reference's second password submission", flush=True)
    for difference in differences:
        print(json.dumps(difference, ensure_ascii=False), flush=True)
    return {"ubaa": reference, "rust": rust, "unexpected_differences": differences, "intentional_policy": "No unconditional second direct-password transaction after WebVPN login"}



def transport_probe(folder, reference, env):
    rust_wire = folder / "rust-transport-wire.json"
    probe_env = dict(env, CARGO_NET_OFFLINE="true", GINKGO_TRANSPORT_WIRE=str(rust_wire))
    result = subprocess.run(["sandbox-exec", "-p", SANDBOX, "cargo", "test", "--manifest-path", "rust/Cargo.toml", "--offline", "--locked", "-p", "ginkgo_upstream", "--features", "network", "--test", "transport_loopback", "--", "--nocapture"], cwd=ROOT, env=probe_env, text=True, capture_output=True, timeout=180)
    if not rust_wire.exists():
        raise SystemExit("Rust socket capture missing\n" + result.stdout + result.stderr)
    rust = json.loads(rust_wire.read_text())
    cases = json.loads((ROOT / "rust/crates/ginkgo_upstream/tests/data/http-loopback-cases.json").read_text())
    identifiers = [case["id"] for case in cases["cases"]]
    for capture in (reference, rust):
        validate_capture_ids(capture, "requests", identifiers)
    differences = []
    for left, right in zip(reference["requests"], rust["requests"], strict=True):
        if left["id"] != right["id"]:
            raise SystemExit("Transport case identifiers differ")
        a, b = left["request"].copy(), right["request"].copy()
        for request in (a, b):
            request["headers"] = request["headers"].copy()
            host = request["headers"].get("host", "")
            if not re.fullmatch(r"127\.0\.0\.1:\d+", host):
                raise SystemExit("Transport capture escaped IPv4 loopback")
            request["headers"]["host"] = "127.0.0.1:<ephemeral>"
            if "cookie" in request["headers"]:
                request["headers"]["cookie"] = sorted(part.strip() for part in request["headers"]["cookie"].split(";"))
        for field in a:
            if field == "headers":
                for name in sorted(set(a[field]) | set(b[field])):
                    if a[field].get(name) != b[field].get(name):
                        differences.append({"case":left["id"], "field":"headers." + name, "ubaa":a[field].get(name), "rust":b[field].get(name)})
            elif a[field] != b[field]:
                differences.append({"case":left["id"], "field":field, "ubaa":a[field], "rust":b[field]})
    if reference["results"] != rust["results"]:
        differences.append({"field":"results", "ubaa":reference["results"], "rust":rust["results"]})
    print(f"Real Android-OkHttp-on-JVM/reqwest loopback: {len(reference['requests'])} cases, {len(differences)} raw normalized differences", flush=True)
    for difference in differences:
        print(json.dumps(difference, ensure_ascii=False), flush=True)
    golden = json.loads((ROOT / "rust/crates/ginkgo_upstream/tests/data/ubaa-transport-wire.json").read_text())
    if golden["reference_commit"] != COMMIT or golden["fixture_sha256"] != hashlib.sha256((ROOT / "rust/crates/ginkgo_upstream/tests/data/http-loopback-cases.json").read_bytes()).hexdigest():
        raise SystemExit("Transport golden reference/fixture changed; independent review required")
    policy = golden["intentional_differences"]
    unexpected = [difference for difference in differences if difference not in policy]
    missing = [difference for difference in policy if difference not in differences]
    print(f"Transport: {len(unexpected)} unexplained, {len(differences) - len(unexpected)} explicit policy differences; full parity=False", flush=True)
    return {"ubaa": reference, "rust": rust, "differences":differences, "unexpected_differences":unexpected, "missing_policy_differences":missing, "full_parity":False, "rust_regression_passed":result.returncode == 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ubaa-root", required=True, type=Path)
    parser.add_argument("--gradle", default=shutil.which("gradle"))
    parser.add_argument("--prepare-dependencies", action="store_true")
    parser.add_argument("--transport-only", action="store_true", help="Run only the real CIO/reqwest loopback comparison")
    parser.add_argument("--output", type=Path, help="Write synthetic request evidence as JSON")
    parser.add_argument("--observe-differences", action="store_true", help="Diagnostic mode: retain business differences without treating them as a pass")
    args = parser.parse_args()
    if not args.gradle or not shutil.which("sandbox-exec"):
        raise SystemExit("Gradle and macOS sandbox-exec are required; tests were not run")
    subprocess.run(["git", "cat-file", "-e", f"{COMMIT}^{{commit}}"], cwd=args.ubaa_root, check=True)
    env = dict(os.environ)
    for key in ("http_proxy", "https_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        env.pop(key, None)
    evidence = {
        "reference_commit": COMMIT,
        "source": "synthetic",
        "response_sha256": hashlib.sha256((ROOT / "rust/crates/ginkgo_upstream/tests/data/ubaa-business-responses.json").read_bytes()).hexdigest(),
        "comparison_scope": "All original commonTest suites; twelve synthetic read scenarios plus 17 real Android-OkHttp-on-JVM/reqwest HTTP loopback cases; no Android OS TLS/Keystore/JNI parity",
        "normalization": ["header names lowercased", "query pairs sorted and decoded preserving duplicates", "form pairs sorted and decoded preserving duplicates", "JSON objects compared by value", "cookie pairs sorted"],
    }
    digest = hashlib.sha256()
    rust_inputs = sorted((ROOT / "rust/crates").rglob("*.rs")) + [ROOT / "rust/Cargo.toml", ROOT / "rust/Cargo.lock"]
    for path in sorted(rust_inputs):
        digest.update(str(path.relative_to(ROOT)).encode() + b"\0" + path.read_bytes() + b"\0")
    evidence["ginkgo_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    evidence["ginkgo_rust_source_sha256"] = digest.hexdigest()
    with tempfile.TemporaryDirectory(prefix="ubaa-reference-") as folder:
        folder = Path(folder)
        env["GINKGO_REFERENCE_RESPONSES"] = str(ROOT / "rust/crates/ginkgo_upstream/tests/data/ubaa-business-responses.json")
        env["GINKGO_REFERENCE_WIRE"] = str(folder / "kotlin-wire.json")
        env["GINKGO_REFERENCE_AUTH_WIRE"] = str(folder / "kotlin-auth-wire.json")
        env["GINKGO_TRANSPORT_CASES"] = str(ROOT / "rust/crates/ginkgo_upstream/tests/data/http-loopback-cases.json")
        env["GINKGO_TRANSPORT_KTOR_WIRE"] = str(folder / "ktor-transport-wire.json")
        env["GINKGO_TRANSPORT_OKHTTP_WIRE"] = str(folder / "okhttp-transport-wire.json")
        archive = folder / "reference.tar"
        source = folder / "source"
        source.mkdir()
        subprocess.run(["git", "archive", "--format=tar", f"--output={archive}", COMMIT, "shared/src"], cwd=args.ubaa_root, check=True)
        subprocess.run(["tar", "-xf", str(archive), "-C", str(source)], check=True)
        build = folder / "build"
        base = [args.gradle, "--no-daemon", "--project-cache-dir", str(folder / "gradle-cache"),
                "-Dkotlin.compiler.execution.strategy=in-process", f"-PubaaRoot={source}",
                f"-PoracleBuildDir={build}"]
        if args.prepare_dependencies:
            subprocess.run(base + ["resolveOracleDependencies"], cwd=ROOT / "scripts/ubaa-reference", env=env, check=True)
        command = ["sandbox-exec", "-p", SANDBOX] + base + ["--offline", "jvmTest"]
        originals = original_suites(source)
        suites = ["cn.edu.ubaa.api.ReferenceTransportProbeTest"] if args.transport_only else originals + [f"cn.edu.ubaa.api.{suite}" for suite in PROBE_SUITES]
        for suite in suites:
            command.extend(["--tests", suite])
        test_result = subprocess.run(command, cwd=ROOT / "scripts/ubaa-reference", env=env)
        if test_result.returncode:
            for report in sorted((build / "test-results/jvmTest").glob("TEST-*.xml")):
                for failure in ET.parse(report).getroot().iter("failure"):
                    print(f"{report.name}: {failure.get('message')}\n{failure.text}", flush=True)
            print("UBAA original tests include failures; collecting diagnostic comparisons, final verdict will fail", flush=True)
        reference = {}
        total = 0
        suite_results = []
        for suite in suites:
            report = build / "test-results/jvmTest" / f"TEST-{suite}.xml"
            tree = ET.parse(report).getroot()
            if int(tree.get("tests", "0")) < 1 or int(tree.get("skipped", "0")):
                raise SystemExit(f"Reference suite missing or skipped: {suite}")
            total += int(tree.get("tests"))
            suite_results.append({"suite": suite, "tests": int(tree.get("tests")), "failures": int(tree.get("failures", "0")), "errors": int(tree.get("errors", "0")), "original": suite in originals, "cases": [{"name": case.get("name"), "passed": case.find("failure") is None and case.find("error") is None} for case in tree.findall("testcase")]})
            if suite.endswith("ReferenceClockProbeTest"):
                suite_results[-1]["controlled_original_replays"] = (tree.findtext("system-out") or "").splitlines()
            if suite == "cn.edu.ubaa.api.ReferenceSessionProbeTest":
                for line in (tree.findtext("system-out") or "").splitlines():
                    match = re.fullmatch(r"ORACLE (\w+) result=(\w+) requests=\[(.*)\]", line)
                    if match:
                        reference[match[1]] = (match[2], match[3].split(", ") if match[3] else [])
                        print(line, flush=True)
        if not args.transport_only and set(reference) != {"ticket", "uc_unavailable", "webvpn"}:
            raise SystemExit("Incomplete UBAA reference observations")
        print(f"UBAA {COMMIT}: {total} original and probe tests executed in network sandbox; exit={test_result.returncode}", flush=True)
        evidence["reference_tests"] = total
        evidence["reference_suites"] = suite_results
        evidence["reference_tests_passed"] = test_result.returncode == 0
        if not args.transport_only:
            if args.output:
                evidence["raw_reference_business"] = json.loads(Path(env["GINKGO_REFERENCE_WIRE"]).read_text())
                args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
            evidence["business"] = business_probe(folder, json.loads(Path(env["GINKGO_REFERENCE_WIRE"]).read_text()), env)
            evidence["authentication"] = auth_probe(folder, json.loads(Path(env["GINKGO_REFERENCE_AUTH_WIRE"]).read_text()), env)
        evidence["jvm_cio_transport"] = json.loads(Path(env["GINKGO_TRANSPORT_KTOR_WIRE"]).read_text())
        evidence["transport"] = transport_probe(folder, json.loads(Path(env["GINKGO_TRANSPORT_OKHTTP_WIRE"]).read_text()), env)

    if args.transport_only:
        if args.output:
            args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
        if not evidence["reference_tests_passed"] or evidence["transport"]["unexpected_differences"] or evidence["transport"]["missing_policy_differences"] or not evidence["transport"]["rust_regression_passed"]:
            raise SystemExit("Transport differences require review; evidence retained")
        return

    result = subprocess.run(["sandbox-exec", "-p", SANDBOX, "python3", "scripts/check-history-session-probes.py"], cwd=ROOT, env=env, text=True, capture_output=True)
    if result.returncode:
        print(result.stdout)
        print(result.stderr)
        raise SystemExit("Historical probes did not complete")
    version = None
    found = {}
    for line in result.stdout.splitlines():
        section = re.match(r"^(android-v0\.1\.0-beta\.\d|working-tree) ", line)
        if section:
            version = section[1]
        observation = re.search(r"\bOBS (ticket|uc_unavailable) result=(\S+) requests=\[(.*)\]$", line)
        if observation and version:
            requests = re.findall(r'"([^\"]+)"', observation[3])
            stages = [request.split(":cookie=", 1)[0] for request in requests]
            outcome = "Error" if observation[2].startswith("Error") else observation[2]
            key = (version, observation[1])
            if key in found:
                raise SystemExit(f"Duplicate historical observation: {key}")
            found[key] = (outcome, stages)
    versions = [f"android-v0.1.0-beta.{number}" for number in range(3, 8)] + ["working-tree"]
    for version in versions:
        for scenario in ("ticket", "uc_unavailable"):
            observed = found.get((version, scenario))
            if observed is None:
                raise SystemExit(f"Missing historical observation: {version} {scenario}")
            verdict = "MATCH" if observed == reference[scenario] else "DIFFER"
            print(f"{version} {scenario}: {verdict} result={observed[0]} requests={observed[1]}", flush=True)
    evidence["stage_reference"] = reference
    evidence["stage_history"] = [{"version": version, "scenario": scenario, "result": value[0], "requests": value[1]} for (version, scenario), value in found.items()]
    if args.output:
        args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
        print(f"Synthetic evidence written to {args.output}")
    validate_current_stages(found, reference)
    differences = sum(len(case["unexpected_differences"]) + len(case["missing_policy_differences"]) for case in evidence["business"]["comparisons"])
    transport_failed = evidence["transport"]["unexpected_differences"] or evidence["transport"]["missing_policy_differences"] or not evidence["transport"]["rust_regression_passed"]
    if transport_failed:
        raise SystemExit("Actual transport differs from pinned reference and explicit policy")
    if evidence["authentication"]["unexpected_differences"]:
        raise SystemExit("Authentication request fields differ; diagnostic evidence retained")
    if not evidence["reference_tests_passed"]:
        raise SystemExit("Original UBAA suites failed; diagnostic evidence retained, no reference pass claimed")
    if not evidence["business"]["rust_regression_passed"]:
        raise SystemExit("Rust business golden regression failed; diagnostic evidence retained")
    if differences and not args.observe_differences:
        raise SystemExit(f"Business comparison failed: {differences} observed field differences")
    if differences:
        print(f"Diagnostic observations only: {differences} business field differences remain; this is not a parity pass")
    print("MATCH compares only result and ordered method-stage/route labels, not bytes, headers, cookies, business modules or real services.")


if __name__ == "__main__":
    main()

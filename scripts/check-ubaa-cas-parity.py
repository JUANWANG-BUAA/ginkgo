#!/usr/bin/env python3
"""Run the pinned UBAA CAS parser verbatim, offline, against shared vectors.

This executes only LocalCasParser, with a minimal Parameters append collector
and DTOs. It does NOT execute Ktor, UBAA authentication orchestration or HTTP.
No dependency resolution, downloads, credentials or network clients are used.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VECTORS = ROOT / "rust/crates/ginkgo_upstream/tests/data/ubaa-cas.json"
SOURCE = "shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalConnectionAuth.kt"
COMMIT = "e8a397fcb35a68147eee65a94c66ffb84e2f09fe"


def jar(cache, module, version):
    matches = list(cache.glob(f"*/{module}/{version}/*/{module}-{version}.jar"))
    if len(matches) != 1:
        raise SystemExit(f"Missing/ambiguous cached {module} {version}; no download attempted")
    return matches[0]


def b64(value):
    return base64.b64encode(value.encode()).decode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ubaa-root", required=True, type=Path)
    parser.add_argument("--java", default=shutil.which("java"))
    parser.add_argument("--cache", type=Path, default=Path.home() / ".gradle/caches/modules-2/files-2.1")
    args = parser.parse_args()
    if not args.java:
        raise SystemExit("A local Java runtime is required; no download attempted")
    data = json.loads(VECTORS.read_text())
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=args.ubaa_root, text=True).strip()
    source = (args.ubaa_root / SOURCE).read_bytes()
    if commit != COMMIT or hashlib.sha256(source).hexdigest() != data["reference"]["sha256"]:
        raise SystemExit("UBAA reference changed; review the reference before updating vectors")
    for entry in [data["reference"], *data["reference"]["related_sources"]]:
        actual = (args.ubaa_root / entry["path"]).read_bytes()
        pinned = subprocess.check_output(["git", "show", f'{COMMIT}:{entry["path"]}'], cwd=args.ubaa_root)
        if actual != pinned or hashlib.sha256(actual).hexdigest() != entry["sha256"]:
            raise SystemExit(f'UBAA source is not the pinned reference: {entry["path"]}')
    oracle = source.decode().split("internal object LocalCasParser {", 1)[1]
    prelude = '''
import java.util.Base64
data class LoginRequest(val username: String, val password: String,
    val captcha: String? = null, val execution: String? = null)
data class CaptchaInfo(val id: String, val type: String, val imageUrl: String)
class Parameters(val pairs: List<Pair<String, String>>) {
    class Builder {
        val pairs = mutableListOf<Pair<String, String>>()
        fun append(name: String, value: String) { pairs.add(name to value) }
    }
    companion object {
        fun build(block: Builder.() -> Unit): Parameters {
            val builder = Builder(); builder.block(); return Parameters(builder.pairs)
        }
    }
}
fun decode(text: String) = String(Base64.getDecoder().decode(text), Charsets.UTF_8)
fun encode(text: String) = Base64.getEncoder().encodeToString(text.toByteArray(Charsets.UTF_8))
'''
    calls = []
    for case in data["cases"]:
        captcha = "null" if case["captcha"] is None else f'decode("{b64(case["captcha"])}")'
        request = f'LoginRequest("sy2501001", "pa+ss/word", {captcha}, decode("{b64(case["execution"])}"))'
        call = (f'LocalCasParser.buildCaptchaLoginParameters({request})'
                if case["captcha"] is not None else
                f'LocalCasParser.buildCasLoginParameters(decode("{b64(case["html"])}"), {request})')
        calls.append(f'println("{case["id"]}\\t" + {call}.pairs.joinToString("\\t") {{ encode(it.first) + ":" + encode(it.second) }})')
    compiler = [jar(args.cache, "kotlin-compiler-embeddable", "2.3.20"),
                jar(args.cache, "kotlin-stdlib", "2.3.20"),
                jar(args.cache, "kotlin-reflect", "2.3.0"),
                jar(args.cache, "kotlinx-coroutines-core-jvm", "1.10.1"),
                jar(args.cache, "annotations", "23.0.0")]
    classpath = os.pathsep.join(map(str, compiler[1:]))
    with tempfile.TemporaryDirectory(prefix="ubaa-cas-oracle-") as folder:
        folder = Path(folder)
        kotlin = folder / "Oracle.kt"
        kotlin.write_text(prelude + "internal object LocalCasParser {" + oracle
                          + "\nfun main() {\n" + "\n".join(calls) + "\n}\n")
        output = folder / "oracle.jar"
        subprocess.run([args.java, "-cp", os.pathsep.join(map(str, compiler)),
                        "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
                        "-classpath", classpath, str(kotlin), "-d", str(output)], check=True)
        lines = subprocess.check_output([args.java, "-cp", str(output) + os.pathsep + classpath,
                                         "OracleKt"], text=True).splitlines()
    observed = {}
    for line in lines:
        case_id, *pairs = line.split("\t")
        observed[case_id] = sorted([[base64.b64decode(value).decode() for value in pair.split(":")]
                                    for pair in pairs])
    for case in data["cases"]:
        if observed.get(case["id"]) != sorted(case["fields"]):
            raise SystemExit(f'Pinned UBAA parser disagrees with vector {case["id"]}: {observed.get(case["id"])}')
    if len(observed) != len(data["cases"]):
        raise SystemExit("Oracle returned an incomplete case set")
    print(f"UBAA verbatim parser: {len(observed)} vectors match (Parameters collector/DTO shims only)", flush=True)
    subprocess.run(["cargo", "test", "--offline", "--locked", "-p", "ginkgo_upstream",
                    "--no-default-features", "ubaa_cas_oracle"], cwd=ROOT / "rust", check=True)


if __name__ == "__main__":
    main()

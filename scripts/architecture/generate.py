#!/usr/bin/env python3
"""Rebuild the checked-in static graph from compiler and syntax evidence."""

import json
import os
import platform
import subprocess
import sys
from pathlib import Path

from check_snapshot import source_manifest

ROOT = Path(__file__).resolve().parents[2]


def main():
    raw = ROOT / "artifacts/local/architecture-analysis"
    raw.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    sdk = Path(
        env.get("ANDROID_HOME")
        or env.get("ANDROID_SDK_ROOT")
        or (
            Path.home() / "Library/Android/sdk"
            if platform.system() == "Darwin"
            else Path.home() / "Android/Sdk"
        )
    )
    hosts = {
        "Darwin": "darwin-x86_64",
        "Linux": "linux-x86_64",
        "Windows": "windows-x86_64",
    }
    bin_dir = (
        sdk
        / "ndk/28.2.13676358/toolchains/llvm/prebuilt"
        / hosts[platform.system()]
        / "bin"
    )
    suffix = ".cmd" if platform.system() == "Windows" else ""
    compiler = bin_dir / ("aarch64-linux-android23-clang" + suffix)
    if "CC_aarch64_linux_android" not in env:
        if not compiler.exists():
            raise SystemExit(
                "Set ANDROID_HOME or CC_aarch64_linux_android / AR_aarch64_linux_android for the Android NDK."
            )
        env["CC_aarch64_linux_android"] = str(compiler)
        env["AR_aarch64_linux_android"] = str(
            bin_dir / ("llvm-ar.exe" if suffix else "llvm-ar")
        )
    before = source_manifest(ROOT)
    steps = [
        (
            ["dart", "pub", "get", "--enforce-lockfile"],
            ROOT / "scripts/architecture/dart",
        ),
        (
            [
                "dart",
                "run",
                "scripts/architecture/dart/bin/call_graph.dart",
                str(ROOT),
                str(raw / "dart.json"),
            ],
            ROOT,
        ),
        (
            [
                sys.executable,
                "scripts/architecture/rust_calls.py",
                str(ROOT),
                str(raw / "rust-android.json"),
            ],
            ROOT,
        ),
        ([sys.executable, "scripts/architecture/render.py"], ROOT),
        ([sys.executable, "scripts/architecture/check_snapshot.py"], ROOT),
    ]
    for command, cwd in steps:
        if command[-1] == "scripts/architecture/render.py":
            if before != source_manifest(ROOT):
                raise SystemExit("Sources changed during analysis; rerun generation.")
            (raw / "source-manifest.json").write_text(
                json.dumps(before, sort_keys=True)
            )
        print("Running:", " ".join(command), flush=True)
        subprocess.run(command, cwd=cwd, env=env, check=True)


if __name__ == "__main__":
    main()

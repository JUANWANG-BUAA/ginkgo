#!/usr/bin/env python3
"""Cheap stale-snapshot check; no compiler tool installation required."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def source_manifest(root):
    paths = set((root / "flutter/lib").rglob("*.dart"))
    paths |= set((root / "rust/crates").rglob("*.rs"))
    paths |= set((root / "flutter/android/app/src/main/kotlin").rglob("*.kt"))
    paths |= set((root / "rust").glob("Cargo.*"))
    paths |= set((root / "rust/crates").glob("*/Cargo.toml"))
    paths |= {root / "flutter/pubspec.yaml", root / "flutter/pubspec.lock"}
    paths |= set((root / "scripts/architecture").glob("*.py"))
    paths |= set((root / "scripts/architecture/dart/bin").glob("*.dart"))
    paths |= set((root / "scripts/architecture/dart").glob("pubspec.*"))
    return {
        p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(paths)
    }


def main():
    expected = json.loads((ROOT / "docs/architecture/source-manifest.json").read_text())
    actual = source_manifest(ROOT)
    changed = sorted(
        p for p in expected.keys() | actual.keys() if expected.get(p) != actual.get(p)
    )
    if changed:
        raise SystemExit(
            "Architecture snapshot is stale; run scripts/architecture/generate.py:\n"
            + "\n".join(changed)
        )
    print(f"Architecture source snapshot verified ({len(actual)} files)")


if __name__ == "__main__":
    main()

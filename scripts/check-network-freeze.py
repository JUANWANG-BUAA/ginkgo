#!/usr/bin/env python3
"""Reject drift from the user-frozen Beta.9 network baseline, without HTTP."""

import hashlib
import json
import re
from pathlib import Path
from typing import TypedDict

ROOT = Path(__file__).resolve().parent.parent
BASELINE = "c4afc0c3f5edad5cded1352da5b536001edb430a"
TAG = "android-v0.1.0-beta.9"
MANIFEST = "docs/network-freeze.json"


class Freeze(TypedDict):
    schema: int
    baseline_commit: str
    baseline_tag: str
    patterns: list[str]
    files: dict[str, str]


def validate_manifest(value: object) -> Freeze:
    """Validate the fixed baseline and reject empty or unsafe scopes."""
    if not isinstance(value, dict):
        raise TypeError("invalid freeze manifest")
    if (
        value.get("schema") != 1
        or value.get("baseline_commit") != BASELINE
        or value.get("baseline_tag") != TAG
    ):
        raise ValueError("frozen baseline changed; explicit user approval required")
    patterns, files = value.get("patterns"), value.get("files")
    if (
        not isinstance(patterns, list)
        or not patterns
        or not isinstance(files, dict)
        or not files
    ):
        raise ValueError("freeze patterns/files must not be empty")
    for path in [*patterns, *files]:
        if (
            not isinstance(path, str)
            or not path
            or Path(path).is_absolute()
            or ".." in Path(path).parts
        ):
            raise ValueError("unsafe freeze path")
    for digest in files.values():
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid freeze digest")
    return Freeze(
        schema=1,
        baseline_commit=BASELINE,
        baseline_tag=TAG,
        patterns=patterns,
        files=files,
    )


def check(root: Path, frozen: Freeze) -> list[str]:
    """Compare bytes and membership, including newly added source files."""
    current: dict[str, Path] = {}
    errors: list[str] = []
    root = root.resolve()
    for pattern in frozen["patterns"]:
        for path in root.glob(pattern):
            if path.is_file() or path.is_symlink():
                current[path.relative_to(root).as_posix()] = path
    for name in sorted(current.keys() | frozen["files"].keys()):
        path = current.get(name)
        if path is None:
            errors.append(f"deleted or outside frozen scope: {name}")
        elif not path.resolve().is_relative_to(root) or any(
            part.is_symlink() for part in (path, *path.parents) if part != root
        ):
            errors.append(f"symlink not allowed: {name}")
        elif name not in frozen["files"]:
            errors.append(f"added: {name}")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != frozen["files"][name]:
            errors.append(f"changed: {name}")
    return errors


def main() -> None:
    """Fail closed without offering an automatic refresh or bypass flag."""
    try:
        frozen = validate_manifest(json.loads((ROOT / MANIFEST).read_text()))
        errors = check(ROOT, frozen)
        if errors:
            raise ValueError("\n".join(errors))
    except (OSError, ValueError, TypeError) as error:
        raise SystemExit(
            f"Network freeze FAILED: {error}\n"
            "Read docs/NETWORK-FREEZE.md; do not refresh hashes without explicit "
            "user authorization."
        ) from error
    print(f"Network freeze verified: {TAG}, {len(frozen['files'])} unchanged files")


if __name__ == "__main__":
    main()

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
APPROVED_REVISIONS = {
    "rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs":
        "87bc2392af0f25cb94b14da9eed986bf957bcba3a7dc65450bc05b2a4aecec61",
    "rust/crates/ginkgo_upstream/src/auth/uc.rs":
        "3c3657f974ffb7d7275c241dd7cdc83efc973a2d9fc88774145780860a48707d",
    "rust/crates/ginkgo_upstream/src/foundation/cookie.rs":
        "638de5679628e9c8d8c1df94a8e3e5fa8d1e1100384c4bb97c1e58462127787d",
    "rust/crates/ginkgo_upstream/src/services/session_service/session_source.rs":
        "d0e3d91bc05cd7324c5d9c8d08eb9b11b82070a92323fa4dfdcb068c2ccd079e",
    "scripts/check-session-regressions.py":
        "949d6ab2a6ed47daa6a3e4f7b00d1689f1f64b3d5cf6b60cb7ed6c86748ff93c",
}
APPROVAL_RECORD = "docs/_audit/2026-11-03-background-reminders-and-recovery.md"


class Freeze(TypedDict):
    schema: int
    baseline_commit: str
    baseline_tag: str
    patterns: list[str]
    files: dict[str, str]
    authorized_revisions: dict[str, str]


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
    revisions = value.get("authorized_revisions", {})
    if not isinstance(revisions, dict):
        raise ValueError("invalid authorized revisions")
    for path, digest in revisions.items():
        if path not in files or APPROVED_REVISIONS.get(path) != digest:
            raise ValueError("unapproved frozen revision")
    if revisions and value.get("authorization_record") != APPROVAL_RECORD:
        raise ValueError("missing authorization evidence")
    return Freeze(
        schema=1,
        baseline_commit=BASELINE,
        baseline_tag=TAG,
        patterns=patterns,
        files=files,
        authorized_revisions=revisions,
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
        elif hashlib.sha256(path.read_bytes()).hexdigest() != frozen["authorized_revisions"].get(
            name, frozen["files"][name]
        ):
            errors.append(f"changed: {name}")
    return errors


def main() -> None:
    """Fail closed without offering an automatic refresh or bypass flag."""
    try:
        frozen = validate_manifest(json.loads((ROOT / MANIFEST).read_text()))
        errors = check(ROOT, frozen)
        if frozen["authorized_revisions"] and not (ROOT / APPROVAL_RECORD).is_file():
            errors.append("authorization record is missing")
        if errors:
            raise ValueError("\n".join(errors))
    except (OSError, ValueError, TypeError) as error:
        raise SystemExit(
            f"Network freeze FAILED: {error}\n"
            "Read docs/NETWORK-FREEZE.md; do not refresh hashes without explicit "
            "user authorization."
        ) from error
    print(f"Network freeze verified: {TAG}, {len(frozen['files'])} protected files, "
          f"{len(frozen['authorized_revisions'])} explicitly authorized revision(s)")


if __name__ == "__main__":
    main()

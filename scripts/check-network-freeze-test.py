#!/usr/bin/env python3
"""Local negative controls for the network freeze gate; no school requests."""

import copy
import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "freeze", Path(__file__).with_name("check-network-freeze.py")
)
assert spec is not None and spec.loader is not None
freeze = importlib.util.module_from_spec(spec)
spec.loader.exec_module(freeze)


class NetworkFreezeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / "network/login.rs"
        self.path.parent.mkdir()
        self.path.write_bytes(b"synthetic frozen implementation\n")
        self.record = {
            "schema": 1,
            "baseline_commit": freeze.BASELINE,
            "baseline_tag": freeze.TAG,
            "patterns": ["network/**/*.rs"],
            "files": {
                "network/login.rs": hashlib.sha256(self.path.read_bytes()).hexdigest()
            },
        }

    def check(self) -> list[str]:
        return freeze.check(self.root, freeze.validate_manifest(self.record))

    def test_unchanged_without_git_history(self) -> None:
        self.assertEqual(self.check(), [])

    def test_unrelated_business_file_allowed(self) -> None:
        (self.root / "business.rs").write_text("synthetic new feature")
        self.assertEqual(self.check(), [])

    def test_changed_bytes_rejected(self) -> None:
        self.path.write_bytes(self.path.read_bytes() + b" ")
        self.assertEqual(self.check(), ["changed: network/login.rs"])

    def test_deleted_file_rejected(self) -> None:
        self.path.unlink()
        self.assertEqual(
            self.check(), ["deleted or outside frozen scope: network/login.rs"]
        )

    def test_added_and_renamed_files_rejected(self) -> None:
        self.path.rename(self.path.with_name("replacement.rs"))
        self.assertEqual(
            self.check(),
            [
                "deleted or outside frozen scope: network/login.rs",
                "added: network/replacement.rs",
            ],
        )

    def test_new_nested_source_rejected(self) -> None:
        nested = self.path.parent / "alternate"
        nested.mkdir()
        (nested / "transport.rs").write_text("synthetic alternate transport")
        self.assertEqual(self.check(), ["added: network/alternate/transport.rs"])

    def test_same_bytes_symlink_rejected(self) -> None:
        target = self.root / "copy.rs"
        self.path.rename(target)
        self.path.symlink_to(target)
        self.assertEqual(self.check(), ["symlink not allowed: network/login.rs"])

    def test_manifest_scope_and_baseline_validation(self) -> None:
        for key, value in [
            ("baseline_commit", "invented"),
            ("baseline_tag", "moved"),
            ("patterns", []),
            ("files", {}),
            ("patterns", ["../escape"]),
            ("patterns", ["/absolute"]),
            ("files", {"network/login.rs": "invalid"}),
        ]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                record = copy.deepcopy(self.record)
                record[key] = value
                freeze.validate_manifest(record)
        with self.assertRaises(TypeError):
            freeze.validate_manifest(None)


if __name__ == "__main__":
    unittest.main()

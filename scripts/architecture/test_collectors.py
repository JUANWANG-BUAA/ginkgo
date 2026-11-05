#!/usr/bin/env python3
"""Semantic fixtures: identical names must not create false call edges."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def links(data, kind):
    nodes = {n["id"]: n for n in data["nodes"]}
    return [
        (nodes[e["from"]], nodes[e["to"]])
        for e in data["edges"]
        if e["kind"] == kind and e.get("to") in nodes
    ]


class CollectorTests(unittest.TestCase):
    def test_dart_resolves_receiver_and_keeps_callback_reference_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            lib = root / "flutter/lib"
            lib.mkdir(parents=True)
            (lib / "main.dart").write_text("""
abstract class Port { void run(); }
class First implements Port { void run() {} }
class Second { void run() {} }
class BaseStatic { static void ping() {} }
class ChildStatic extends BaseStatic { static void ping() {} }
void register(void Function() callback) {}
void main() {
  final first = First();
  final second = Second();
  first.run();
  register(second.run);
  register(() { first.run(); });
}
""")
            output = root / "graph.json"
            subprocess.run(
                [
                    "dart",
                    "run",
                    str(ROOT / "scripts/architecture/dart/bin/call_graph.dart"),
                    str(root),
                    str(output),
                ],
                cwd=ROOT,
                check=True,
                capture_output=True,
            )
            data = json.loads(output.read_text())
            self.assertEqual(data["issues"], [])
            calls = links(data, "call")
            main_targets = [b["name"] for a, b in calls if a["name"] == "main"]
            self.assertIn("First.run", main_targets)
            self.assertNotIn("Second.run", main_targets)
            self.assertTrue(
                any(b["name"] == "Second.run" for _, b in links(data, "reference"))
            )
            self.assertFalse(
                any("ping" in b["name"] for _, b in links(data, "implementation"))
            )
            constructors = {b["id"] for _, b in links(data, "construct")}
            self.assertEqual(len(constructors), 2)
            self.assertTrue(
                all(b.get("line", 0) > 0 for _, b in links(data, "construct"))
            )
            self.assertTrue(
                any(
                    a["name"] == "Port.run" and b["name"] == "First.run"
                    for a, b in links(data, "implementation")
                )
            )
            self.assertTrue(
                any(a["name"] != "main" and b["name"] == "First.run" for a, b in calls)
            )

    def test_rust_resolves_module_not_same_spelling(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            lib = root / "rust/crates/probe/src"
            lib.mkdir(parents=True)
            (root / "rust/Cargo.toml").write_text(
                '[workspace]\nmembers=["crates/probe"]\nresolver="2"\n'
            )
            (lib.parent / "Cargo.toml").write_text(
                '[package]\nname="probe"\nversion="0.0.0"\nedition="2021"\n'
            )
            (lib / "lib.rs").write_text(
                "mod a;\nmod b;\npub fn entry() { a::same(); }\n"
            )
            (lib / "a.rs").write_text("pub fn same() {}\n")
            (lib / "b.rs").write_text("pub fn same() {}\n")
            host = next(
                line.split(": ", 1)[1]
                for line in subprocess.check_output(
                    ["rustc", "-vV"], text=True
                ).splitlines()
                if line.startswith("host:")
            )
            output = root / "graph.json"
            subprocess.run(
                [
                    "python3",
                    str(ROOT / "scripts/architecture/rust_calls.py"),
                    str(root),
                    str(output),
                    "--target",
                    host,
                ],
                cwd=ROOT,
                check=True,
                capture_output=True,
            )
            data = json.loads(output.read_text())
            self.assertEqual(data["issues"], [])
            targets = [
                b["file"] for a, b in links(data, "call") if a["name"] == "entry"
            ]
            self.assertEqual(targets, ["rust/crates/probe/src/a.rs"])


if __name__ == "__main__":
    unittest.main()

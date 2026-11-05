#!/usr/bin/env python3
"""Regression tests for interface index completeness."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('interface_index', Path(__file__).with_name('generate-interface-index.py'))
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class IndexTests(unittest.TestCase):
    def test_dependency_edges_include_relative_conditional_and_part(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'application').mkdir()
            (root / 'shared').mkdir()
            source = root / 'application/a.dart'
            source.write_text(
                '// import "../shared/missing.dart";\n'
                '/* export "../shared/missing.dart"; */\n'
                'import "../shared/b.dart" if (dart.library.io) "../shared/c.dart";\n'
                "export 'package:ginkgo_mirror/shared/b.dart';\n"
                "part 'piece.dart';\n"
                "const fake = \"import '../shared/missing.dart';\";\n")
            for file in ('shared/b.dart', 'shared/c.dart', 'application/piece.dart'):
                (root / file).write_text('')
            previous = module.FLUTTER_LIB
            module.FLUTTER_LIB = root
            try:
                edges = module.dart_dependency_edges()
                self.assertEqual(edges, [
                    ('application/a.dart', 'application/piece.dart', 5),
                    ('application/a.dart', 'shared/b.dart', 3),
                    ('application/a.dart', 'shared/b.dart', 4),
                    ('application/a.dart', 'shared/c.dart', 3),
                ])
                self.assertEqual(module.dart_dependency_graph(), {'application': {'shared'}})
                (root / 'shared/b.dart').unlink()
                with self.assertRaisesRegex(ValueError, 'unresolved local dependency'):
                    module.dart_dependency_edges()
            finally:
                module.FLUTTER_LIB = previous

    def test_group_cycle_is_not_necessarily_a_file_cycle(self):
        files = {'a/one.dart': {'b/two.dart'}, 'b/three.dart': {'a/four.dart'}}
        self.assertEqual(module.strongly_connected(files), [])
        self.assertEqual(module.strongly_connected({'a': {'b'}, 'b': {'a'}}), [['a', 'b']])
        self.assertEqual(module.strongly_connected({'a.dart': {'b.dart'}, 'b.dart': {'a.dart'}}), [['a.dart', 'b.dart']])

    def test_rust_public_items_after_test_module_are_indexed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'sample.rs'
            file.write_text('pub fn before() {}\n#[cfg(test)]\nmod tests {\n    pub fn hidden() {}\n}\npub fn after() {}\n')
            previous = module.REPO
            module.REPO = root
            try:
                self.assertEqual([e.name for e in module.scan_rust(file, 'sample').entries], ['before', 'after'])
            finally:
                module.REPO = previous

    def test_dart_functions_and_named_parameters_are_complete(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'sample.dart'
            file.write_text('Future<String> resolve({\n  required String root,\n  String? fallback,\n}) async => root;\n')
            previous = module.FLUTTER_LIB
            module.FLUTTER_LIB = root
            try:
                entry = module.scan_dart(file)[0].entries[0]
                self.assertEqual(entry.name, 'resolve')
                self.assertIn('required String root', entry.signature)
                self.assertIn('String? fallback', entry.signature)
                self.assertTrue(entry.signature.endswith('=> …'))
            finally:
                module.FLUTTER_LIB = previous


if __name__ == '__main__':
    unittest.main()

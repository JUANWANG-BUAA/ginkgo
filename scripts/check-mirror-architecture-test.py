#!/usr/bin/env python3
"""Regression tests for the school integration boundary gate."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('boundary', Path(__file__).with_name('check-mirror-architecture.py'))
BOUNDARY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BOUNDARY)


class BoundaryTests(unittest.TestCase):
    def test_core_cannot_reintroduce_upstream_even_as_a_test_dependency(self):
        errors = BOUNDARY.dependency_violations([{
            'name': 'ginkgo_core', 'dependencies': [
                {'name': 'ginkgo_upstream', 'path': '/synthetic/upstream', 'kind': 'dev'},
            ],
        }])
        self.assertTrue(errors)

    def test_renaming_a_local_school_package_does_not_bypass_the_gate(self):
        errors = BOUNDARY.dependency_violations([{
            'name': 'ginkgo_core', 'dependencies': [
                {'name': 'school_api', 'path': '/synthetic/school_api'},
            ],
        }])
        self.assertTrue(errors)

    def test_only_composition_may_connect_core_and_upstream(self):
        errors = BOUNDARY.dependency_violations([{
            'name': 'ginkgo_runtime', 'dependencies': [
                {'name': name, 'path': '/synthetic/' + name}
                for name in ['ginkgo_core', 'ginkgo_upstream']
            ],
        }])
        self.assertEqual(errors, [])

    def test_school_http_and_native_fixture_decoding_are_rejected_outside_upstream(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            core = root / 'rust/crates/ginkgo_core/src/lib.rs'
            bridge = root / 'rust/crates/ginkgo_flutter_bridge/src/api/live.rs'
            core.parent.mkdir(parents=True)
            bridge.parent.mkdir(parents=True)
            core.write_text('use school::HttpTransport;\n')
            bridge.write_text('let body = include_str!("school-response.json");\n')
            self.assertEqual(len(BOUNDARY.source_violations(root)), 2)
            core.write_text('use ginkgo_domain::ports::SessionSource;\n')
            bridge.write_text('use ginkgo_core::application::SessionStatus;\n')
            self.assertEqual(BOUNDARY.source_violations(root), [])

    def test_business_ports_cannot_return_raw_json_envelopes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            ports = root / 'rust/crates/ginkgo_domain/src/ports/example.rs'
            ports.parent.mkdir(parents=True)
            ports.write_text('pub type Payload = serde_json::Value;\n')
            self.assertEqual(len(BOUNDARY.source_violations(root)), 1)


if __name__ == '__main__':
    unittest.main()

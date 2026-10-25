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

    def test_pages_cannot_decode_school_payload_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            page = lib / 'cgyy_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text('final rows = jsonDecode(payload) as List;\n')
            widgets = lib / 'widgets/apple_surfaces.dart'
            widgets.parent.mkdir(parents=True)
            widgets.write_text('var value = jsonDecode(source);\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)
            page.write_text('final rows = cgyySites(payload);\n')
            widgets.write_text('const value = 1;\n')
            self.assertEqual(BOUNDARY.payload_decode_violations(root), [])

    def test_presentation_widget_apis_reject_payload_maps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            page = lib / 'today_page.dart'
            page.parent.mkdir(parents=True)
            widgets = lib / 'widgets/apple_surfaces.dart'
            widgets.parent.mkdir(parents=True)
            shared = lib / 'cgyy_widgets.dart'
            page.write_text('class Row { final Map<String, dynamic> course; }\n')
            widgets.write_text('final rows = <Map<String, dynamic>>[];\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)
            shared.write_text('class Tile { final CgyySite site; }\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)

    def test_model_projections_and_local_codecs_decode_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            models = lib / 'bykc_models.dart'
            codec = lib / 'app_preferences.dart'
            models.parent.mkdir(parents=True)
            models.write_text('final value = jsonDecode(payload);\n')
            codec.write_text('final value = jsonDecode(text);\n')
            self.assertEqual(BOUNDARY.payload_decode_violations(root), [])


if __name__ == '__main__':
    unittest.main()

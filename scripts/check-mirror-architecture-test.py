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
    def test_reminder_controller_cannot_import_platform_adapters(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            file = root / 'flutter/lib/shared/reminder_controller.dart'
            file.parent.mkdir(parents=True)
            for directive in [
                "import 'dart:io';",
                "import 'package:flutter/services.dart';",
                "import 'package:ginkgo_mirror/infrastructure/reminder_store.dart';",
            ]:
                file.write_text(directive)
                self.assertTrue(BOUNDARY.dart_boundary_violations(root), directive)
            file.write_text("import 'package:ginkgo_mirror/application/reminder_store.dart';")
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_application_cannot_import_platform_storage_plugin(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            file = root / 'flutter/lib/application/example.dart'
            file.parent.mkdir(parents=True)
            file.write_text("import 'package:path_provider/path_provider.dart';\n")
            self.assertTrue(BOUNDARY.dart_boundary_violations(root))
            file.write_text('abstract class TaskStorageRoot {}\n')
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

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

    def test_domain_features_cannot_host_school_implementation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            features = root / 'rust/crates/ginkgo_domain/src/features/example.rs'
            features.parent.mkdir(parents=True)
            features.write_text('pub const ENDPOINT: &str = "https://iclass.buaa.edu.cn/app";\n')
            self.assertEqual(len(BOUNDARY.source_violations(root)), 1)
            features.write_text('pub struct Day { pub label: String }\n')
            self.assertEqual(BOUNDARY.source_violations(root), [])

    def test_dart_pages_cannot_reference_school_destinations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            page = root / 'flutter/lib/classroom_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text("final url = 'https://yjs.buaa.edu.cn/gsmis';\n")
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            page.write_text('final url = schoolEndpoint;\n')
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_only_contracts_facade_imports_generated_bindings(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            page = lib / 'today_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text("import 'src/rust/api/mirror.dart';\n")
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            page.write_text("import 'application/contracts.dart';\n")
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_native_construction_stays_in_composition(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            page = root / 'flutter/lib/today_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text('final service = NativeMirrorService();\n')
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            page.write_text('final service = widget.service;\n')
            composition = root / 'flutter/lib/main.dart'
            composition.write_text('final service = NativeMirrorService();\n')
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_contracts_facade_exports_types_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            facade = root / 'flutter/lib/application/contracts.dart'
            facade.parent.mkdir(parents=True)
            facade.write_text("export '../src/rust/api/mirror.dart' show ScheduleDto, loadSchedule;\n")
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            facade.write_text("export '../src/rust/api/mirror.dart';\n")
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            facade.write_text("export '../src/rust/api/mirror.dart' show ScheduleDto;\n")
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])
            failures = root / 'flutter/lib/application/failures.dart'
            failures.write_text("export '../src/rust/api/mirror.dart' show FailureCode, loadSchedule;\n")
            self.assertEqual(len(BOUNDARY.dart_boundary_violations(root)), 1)
            failures.write_text("export '../src/rust/api/mirror.dart' show FailureCode;\n")
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_pages_cannot_decode_school_payload_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            page = lib / 'features/cgyy/cgyy_page.dart'
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
            page = lib / 'features/today/today_page.dart'
            page.parent.mkdir(parents=True)
            widgets = lib / 'widgets/apple_surfaces.dart'
            widgets.parent.mkdir(parents=True)
            shared = lib / 'features/cgyy/cgyy_widgets.dart'
            shared.parent.mkdir(parents=True)
            page.write_text('class Row { final Map<String, dynamic> course; }\n')
            widgets.write_text('final rows = <Map<String, dynamic>>[];\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)
            shared.write_text('class Tile { final CgyySite site; }\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)

    def test_shared_and_design_layers_are_presentation_scoped(self):
        """新目录层级同样受呈现层约束，不能靠换目录绕开类型边界。"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            shared = lib / 'shared/checkin_sessions.dart'
            shared.parent.mkdir(parents=True)
            design = lib / 'widgets/ginkgo_visuals.dart'
            design.parent.mkdir(parents=True)
            shared.write_text('final rows = <Map<String, dynamic>>[];\n')
            design.write_text('final rows = <Map<String, dynamic>>[];\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 2)

    def test_local_json_codecs_are_recognised_by_path(self):
        """本机持久化编解码器按路径豁免；改名后不再豁免。"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            codec = lib / 'shared/app_preferences.dart'
            codec.parent.mkdir(parents=True)
            codec.write_text('final value = jsonDecode(text);\n')
            self.assertEqual(BOUNDARY.payload_decode_violations(root), [])
            moved = lib / 'shared/renamed_preferences.dart'
            moved.write_text('final value = jsonDecode(text);\n')
            self.assertEqual(len(BOUNDARY.payload_decode_violations(root)), 1)

    def test_model_projections_and_local_codecs_decode_json(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            models = lib / 'features/bykc/bykc_models.dart'
            codec = lib / 'shared/app_preferences.dart'
            models.parent.mkdir(parents=True)
            codec.parent.mkdir(parents=True)
            models.write_text('final value = jsonDecode(payload);\n')
            codec.write_text('final value = jsonDecode(text);\n')
            self.assertEqual(BOUNDARY.payload_decode_violations(root), [])

    def test_lib_root_keeps_entry_points_only(self):
        """新增功能必须落进领域目录，不能重新把文件平铺回 lib 根。"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            lib.mkdir(parents=True)
            (lib / 'main.dart').write_text('void main() {}\n')
            (lib / 'mirror_service.dart').write_text('export "x.dart";\n')
            self.assertEqual(BOUNDARY.layout_violations(root), [])
            stray = lib / 'cgyy_page.dart'
            stray.write_text('class P {}\n')
            errors = BOUNDARY.layout_violations(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('entry points only', errors[0])

    def test_oversized_dart_file_is_rejected(self):
        """单文件超过上限应拆分，而不是继续堆叠职责。"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            page = lib / 'features/today/today_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text('\n'.join(['// line'] * 601))
            errors = BOUNDARY.layout_violations(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('split by responsibility', errors[0])
            page.write_text('\n'.join(['// line'] * 600))
            self.assertEqual(BOUNDARY.layout_violations(root), [])

    def test_dart_import_and_export_cycles_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            lib = root / 'flutter/lib'
            first = lib / 'application/first.dart'
            second = lib / 'application/second.dart'
            first.parent.mkdir(parents=True)
            first.write_text("import 'second.dart';\n")
            second.write_text("export 'first.dart';\n")
            errors = BOUNDARY.dart_import_cycles(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('first.dart', errors[0])
            self.assertIn('second.dart', errors[0])
            second.write_text('class Second {}\n')
            self.assertEqual(BOUNDARY.dart_import_cycles(root), [])

    def test_synchronous_mutex_guard_cannot_cross_await(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'rust/crates/ginkgo_upstream/src/services/example.rs'
            source.parent.mkdir(parents=True)
            source.write_text('''async fn unsafe_read(&self) {
    let guard = self.identity.lock();
    self.fetch().await;
    drop(guard);
}
''')
            errors = BOUNDARY.sync_lock_await_violations(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('guard', errors[0])
            source.write_text('''async fn safe_read(&self) {
    let guard = self.identity.lock();
    drop(guard);
    self.fetch().await;
    let async_guard = self.requests.lock().await;
    self.fetch().await;
    drop(async_guard);
}
''')
            self.assertEqual(BOUNDARY.sync_lock_await_violations(root), [])

    def test_presentation_pages_cannot_import_adapters(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            page = root / 'flutter/lib/features/example/example_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text(
                "import 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';\n"
            )
            errors = BOUNDARY.dart_boundary_violations(root)
            self.assertEqual(len(errors), 1)
            self.assertIn('adapters belong to the composition root', errors[0])
            page.write_text(
                "import 'package:ginkgo_mirror/application/mirror_service.dart';\n"
            )
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_the_composition_root_may_still_wire_adapters(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shell = root / 'flutter/lib/workspace/workspace_shell.dart'
            shell.parent.mkdir(parents=True)
            shell.write_text(
                "import 'package:ginkgo_mirror/infrastructure/task_storage.dart';\n"
            )
            self.assertEqual(BOUNDARY.dart_boundary_violations(root), [])

    def test_the_pending_adapter_import_list_cannot_grow_silently(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            page = root / 'flutter/lib/features/settings/settings_page.dart'
            page.parent.mkdir(parents=True)
            page.write_text(
                "import 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';\n"
            )
            # The migration is done: the list is empty and the file is caught.
            self.assertEqual(BOUNDARY.PENDING_ADAPTER_IMPORTS, set())
            self.assertTrue(BOUNDARY.dart_boundary_violations(root))



if __name__ == '__main__':
    unittest.main()

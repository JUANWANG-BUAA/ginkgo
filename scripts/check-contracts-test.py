#!/usr/bin/env python3
"""Negative controls for document drift and fail-closed release acceptance."""
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from datetime import date
from pathlib import Path

spec = importlib.util.spec_from_file_location('contracts', Path(__file__).with_name('check-contracts.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ContractsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ['docs', 'rust', 'flutter/lib/workspace']:
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / 'rust/protocol.rs').write_text('protocol-v1')
        (self.root / 'docs/API.md').write_text('# AUTH-01\n')
        (self.root / 'docs/test.rs').write_text('regression evidence')
        (self.root / 'flutter/pubspec.yaml').write_text('version: 1.0.0+1\n')
        (self.root / 'flutter/lib/workspace/workspace_catalog.dart').write_text("id: 'today',\nid: 'settings',\n")
        self.contract = {'schema_version': 1, 'groups': []}
        for name in sorted(module.GROUPS):
            group = {'id': name, 'inputs': ['rust/*.rs'], 'documents': ['docs/API.md'],
                     'evidence': ['docs/test.rs'], 'invariants': ['AUTH-01']}
            group['source_sha256'] = module.digest_files(self.root, module.source_files(self.root, group))
            group['document_sha256'] = module.digest_files(self.root, [self.root / 'docs/API.md'])
            self.contract['groups'].append(group)
        self.fingerprint = 'candidate-sha256'
        names = module.required_cases(self.root)
        (self.root / 'docs/report.md').write_text(self.fingerprint + '\n' + '\n'.join(names))
        self.record = {'schema_version': 1, 'status': 'ready', 'version': '1.0.0+1',
                       'source_sha256': self.fingerprint,
                       'contract_sha256': hashlib.sha256(json.dumps(self.contract, sort_keys=True).encode()).hexdigest(),
                       'reviewer': 'synthetic reviewer', 'reviewed_at': date.today().isoformat(),
                       'open_p0': 0, 'open_p1': 0,
                       'cases': {name: {'status': 'passed', 'level': level, 'report': 'docs/report.md',
                                        'section': name, 'date': date.today().isoformat(),
                                        'environment': 'synthetic environment', 'result': 'synthetic result'}
                                 for name, level in names.items()}}

    def release_errors(self):
        return module.check_release(self.root, self.record, self.contract, self.fingerprint)

    def test_current_lock_and_complete_candidate_are_accepted(self):
        self.assertEqual(module.check_lock(self.root, self.contract), [])
        self.assertEqual(self.release_errors(), [])

    def test_source_and_document_drift_are_both_rejected(self):
        (self.root / 'rust/protocol.rs').write_text('protocol-v2')
        (self.root / 'docs/API.md').write_text('# AUTH-01\nchanged policy')
        errors = module.check_lock(self.root, self.contract)
        self.assertTrue(any('source changed' in e for e in errors))
        self.assertTrue(any('documents changed' in e for e in errors))

    def test_missing_group_reference_or_invariant_cannot_be_silently_dropped(self):
        self.contract['groups'].pop()
        self.contract['groups'][0]['invariants'] = ['NONEXISTENT']
        self.contract['groups'][0]['evidence'] = ['docs/missing.rs']
        errors = module.check_lock(self.root, self.contract)
        self.assertTrue(any('groups missing' in e for e in errors))
        self.assertTrue(any('missing reference' in e for e in errors))
        self.assertTrue(any('missing invariant' in e for e in errors))

    def test_new_protocol_file_invalidates_lock(self):
        (self.root / 'rust/new_protocol.rs').write_text('new endpoint')
        self.assertTrue(module.check_lock(self.root, self.contract))

    def test_empty_or_wrong_level_evidence_blocks_release(self):
        self.record['cases'].pop('auth:correct-and-wrong-password')
        self.record['cases']['writes:checkin-confirm-submit-readback']['level'] = 'local'
        errors = self.release_errors()
        self.assertTrue(any('auth:correct' in e for e in errors))
        self.assertTrue(any('manual-write' in e for e in errors))

    def test_old_source_version_contract_and_blockers_are_rejected(self):
        self.record.update(source_sha256='old', contract_sha256='old', version='old', open_p0=1, open_p1=None)
        self.assertGreaterEqual(len(self.release_errors()), 4)

    def test_old_report_and_missing_section_are_rejected(self):
        (self.root / 'docs/report.md').write_text('old source report')
        self.assertTrue(any('not bound' in e for e in self.release_errors()))
        (self.root / 'docs/report.md').write_text(self.fingerprint)
        self.assertTrue(any('section' in e for e in self.release_errors()))

    def test_new_catalog_destination_requires_new_acceptance(self):
        catalog = self.root / 'flutter/lib/workspace/workspace_catalog.dart'
        catalog.write_text(catalog.read_text() + "id: 'new-feature',\n")
        self.assertTrue(any('feature:new-feature' in e for e in self.release_errors()))

    def test_refreshing_freshness_does_not_release_blocked_candidate(self):
        self.record['status'] = 'blocked'
        self.assertEqual(module.check_lock(self.root, self.contract), [])
        self.assertTrue(any('remains blocked' in e for e in self.release_errors()))

    def test_untracked_implementation_invalidates_candidate_fingerprint(self):
        subprocess.run(['git', 'init', '-q'], cwd=self.root, check=True)
        before = module.candidate_fingerprint(self.root)
        (self.root / 'rust/new.rs').write_text('untracked change')
        self.assertNotEqual(before, module.candidate_fingerprint(self.root))
        with self.assertRaises(ValueError):
            module.safe_path(self.root, '../outside')


if __name__ == '__main__':
    unittest.main()

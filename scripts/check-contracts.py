#!/usr/bin/env python3
"""Fail closed on protocol-document drift and incomplete Android acceptance.

Default checks the reviewed protocol source lock. --release additionally checks
candidate-bound evidence. --refresh-lock updates freshness hashes ONLY, never
acceptance status. This checks traceability, not the truth of a human report.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = 'docs/protocol-contracts.json'
READINESS = 'docs/android-release-readiness.json'
GROUPS = {'authentication', 'school-protocols', 'client-contracts'}


def safe_path(root: Path, value: str) -> Path:
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f'path outside repository: {value}')
    return path


def digest_files(root: Path, paths: list[Path]) -> str:
    digest = hashlib.sha256()
    root = root.resolve()
    for path in sorted({p.resolve() for p in paths}):
        if not path.is_relative_to(root):
            raise ValueError('digest input outside repository')
        digest.update(path.relative_to(root).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def source_files(root: Path, group: dict) -> list[Path]:
    files: list[Path] = []
    if not group.get('inputs'):
        raise ValueError('protocol source inputs cannot be empty')
    for pattern in group['inputs']:
        safe_path(root, pattern)
        matched = [p for p in root.glob(pattern) if p.is_file()]
        if not matched:
            raise ValueError(f'empty protocol input: {pattern}')
        files.extend(matched)
    return files


def check_lock(root: Path, contract: dict) -> list[str]:
    errors = []
    if contract.get('schema_version') != 1 or not contract.get('groups'):
        return ['invalid protocol lock schema/groups']
    names = set()
    for group in contract['groups']:
        if group['id'] in names:
            errors.append(f'duplicate protocol group: {group["id"]}')
        names.add(group['id'])
        if not group.get('invariants') or not group.get('evidence'):
            errors.append(f'{group["id"]}: missing invariants/evidence')
        for reference in group.get('documents', []) + group.get('evidence', []):
            if not safe_path(root, reference).is_file():
                errors.append(f'{group["id"]}: missing reference {reference}')
        documents = [safe_path(root, p) for p in group.get('documents', [])]
        if not documents or not all(p.is_file() for p in documents):
            errors.append(f'{group["id"]}: missing contract documents')
        elif group.get('document_sha256') != digest_files(root, documents):
            errors.append(f'{group["id"]}: reviewed documents changed; review and refresh lock')
        combined = '\n'.join(p.read_text() for p in documents if p.is_file())
        for invariant in group.get('invariants', []):
            if invariant not in combined:
                errors.append(f'{group["id"]}: missing invariant {invariant} in contract documents')
        actual = digest_files(root, source_files(root, group))
        if group.get('source_sha256') != actual:
            errors.append(f'{group["id"]}: source changed; review API/local contracts and regression evidence before refreshing lock')
    if names != GROUPS:
        errors.append('required protocol groups missing or unknown')
    return errors


def candidate_fingerprint(root: Path) -> str:
    # Includes untracked implementation files. Excludes acceptance metadata so
    # adding evidence does not invalidate the very candidate it describes.
    scopes = ['flutter/lib', 'flutter/android', 'flutter/windows', 'flutter/pubspec.yaml',
              'flutter/pubspec.lock', 'rust', 'fixtures', 'scripts', '.github/workflows']
    result = subprocess.run(['git', 'ls-files', '-c', '-o', '--exclude-standard', '--', *scopes],
                            cwd=root, check=True, capture_output=True, text=True)
    files = [safe_path(root, name) for name in result.stdout.splitlines()]
    return digest_files(root, [path for path in files if path.is_file()])


def required_cases(root: Path) -> dict[str, str]:
    cases = {
        'baseline': 'local', 'production-entrypoint': 'emulator',
        'auth:correct-and-wrong-password': 'real-readonly',
        'auth:captcha-first-wrong-refresh-expired': 'real-readonly',
        'auth:gateway-challenge-and-return-to-module': 'real-readonly',
        'auth:directory-failure-never-fakes-login': 'local',
        'auth:single-submit-and-unknown-result': 'local',
        'route:automatic-direct-webvpn': 'real-readonly',
        'route:campus-and-offcampus': 'real-readonly',
        'session:remember-and-no-remember-cold-start': 'real-readonly',
        'session:logout-account-switch-and-old-response': 'emulator',
        'settings:all-persistent-choices-after-restart': 'device',
        'ux:keyboard-back-cancel-scroll-large-text-themes': 'device',
        'ux:loading-empty-error-stale-partial-and-retry': 'emulator',
        'ux:startup-scroll-and-navigation-performance': 'device',
        'notifications:permissions-channel-reboot-isolation': 'device',
        'upgrade:signed-overwrite-and-local-data': 'device',
        'writes:library-confirm-submit-readback': 'manual-write',
        'writes:checkin-confirm-submit-readback': 'manual-write',
        'writes:cgyy-confirm-submit-readback': 'manual-write',
        'writes:homework-file-confirm-submit-readback': 'manual-write',
        'security:auth-vault-tls-review': 'human-review',
        'windows:shared-build-and-tests': 'remote-ci',
    }
    catalog = (root / 'flutter/lib/workspace/workspace_catalog.dart').read_text()
    for name in re.findall(r"\bid:\s*'([^']+)'", catalog):
        cases[f'feature:{name}'] = 'emulator' if name in {'tasks', 'more', 'settings'} else 'real-readonly'
    return cases


def check_release(root: Path, record: dict, contract: dict, fingerprint: str) -> list[str]:
    errors = []
    if record.get('schema_version') != 1 or record.get('status') != 'ready':
        errors.append('release remains blocked (status must be ready after acceptance)')
    if record.get('source_sha256') != fingerprint:
        errors.append('acceptance does not match current candidate source')
    contract_hash = hashlib.sha256(json.dumps(contract, sort_keys=True).encode()).hexdigest()
    if record.get('contract_sha256') != contract_hash:
        errors.append('acceptance does not match current protocol contract')
    version = re.search(r'^version:\s*(\S+)', (root / 'flutter/pubspec.yaml').read_text(), re.M).group(1)
    if record.get('version') != version:
        errors.append('acceptance version does not match pubspec')
    if record.get('open_p0') != 0 or record.get('open_p1') != 0:
        errors.append('P0/P1 blockers must both be zero')
    if not record.get('reviewer') or not record.get('reviewed_at'):
        errors.append('missing maintainer review')
    else:
        try:
            if date.fromisoformat(record['reviewed_at']) > date.today():
                errors.append('future maintainer review date')
        except ValueError:
            errors.append('invalid maintainer review date')
    for name, level in required_cases(root).items():
        evidence = record.get('cases', {}).get(name, {})
        if evidence.get('status') != 'passed' or evidence.get('level') != level:
            errors.append(f'{name}: requires passed {level} evidence')
            continue
        path = evidence.get('report', '')
        if not path or not safe_path(root, path).is_file():
            errors.append(f'{name}: missing repository report')
        elif fingerprint not in safe_path(root, path).read_text():
            errors.append(f'{name}: report is not bound to current candidate')
        elif not evidence.get('section') or evidence['section'] not in safe_path(root, path).read_text():
            errors.append(f'{name}: report does not contain referenced evidence section')
        try:
            recorded = date.fromisoformat(evidence.get('date', ''))
            if recorded > date.today():
                errors.append(f'{name}: future evidence date')
        except ValueError:
            errors.append(f'{name}: invalid evidence date')
        if not evidence.get('environment') or not evidence.get('result'):
            errors.append(f'{name}: missing environment/result')
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--refresh-lock', action='store_true')
    parser.add_argument('--candidate', action='store_true')
    parser.add_argument('--show-required', action='store_true')
    args = parser.parse_args()
    try:
        contract = json.loads((ROOT / LOCK).read_text())
        if args.refresh_lock:
            for group in contract['groups']:
                group['source_sha256'] = digest_files(ROOT, source_files(ROOT, group))
                group['document_sha256'] = digest_files(ROOT, [safe_path(ROOT, p) for p in group['documents']])
            (ROOT / LOCK).write_text(json.dumps(contract, ensure_ascii=False, indent=2) + '\n')
            print('Protocol freshness lock refreshed; acceptance status was NOT changed.')
        if args.show_required:
            print(json.dumps(required_cases(ROOT), ensure_ascii=False, indent=2))
        if args.candidate:
            print('source_sha256=' + candidate_fingerprint(ROOT))
            print('contract_sha256=' + hashlib.sha256(json.dumps(contract, sort_keys=True).encode()).hexdigest())
        errors = check_lock(ROOT, contract)
        if args.release:
            errors += check_release(ROOT, json.loads((ROOT / READINESS).read_text()), contract, candidate_fingerprint(ROOT))
        if errors:
            raise ValueError('\n'.join(errors))
        print('Protocol contract freshness verified' + ('; Android release evidence verified' if args.release else ' (not release acceptance)'))
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error


if __name__ == '__main__':
    main()

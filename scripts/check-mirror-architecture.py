#!/usr/bin/env python3
"""Check dependency direction and keep native commands out of presentation."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


ALLOWED_DEPENDENCIES = {
    'ginkgo_domain': set(),
    'ginkgo_upstream': {'ginkgo_domain'},
    'ginkgo_core': {'ginkgo_domain'},
    'ginkgo_runtime': {'ginkgo_core', 'ginkgo_upstream'},
    'ginkgo_flutter_bridge': {'ginkgo_core', 'ginkgo_runtime'},
}


def dependency_violations(packages):
    errors = []
    for package in packages:
        name = package['name']
        if name not in ALLOWED_DEPENDENCIES:
            continue
        for dependency in package['dependencies']:
            target = dependency['name']
            if name in {'ginkgo_domain', 'ginkgo_core'} and target in {
                'reqwest', 'flutter_rust_bridge', 'keyring', 'jni', 'rsa', 'aes', 'url',
            }:
                errors.append(f'{name} must not depend on protocol/platform library {target}')
            if name == 'ginkgo_domain' and target == 'tokio':
                errors.append('domain values must not depend on an async runtime')
            if (dependency.get('path') or target.startswith('ginkgo_')) and target not in ALLOWED_DEPENDENCIES[name]:
                errors.append(f'{name} must not depend on {target}')
    return errors


def source_violations(root):
    errors = []
    forbidden = re.compile(r'\b(?:HttpTransport|CredentialVault|LoginPage|IClassSession|ReqwestTransport|CookieJar)\b|https?://[^\s\"<>]*buaa|ginkgo_upstream::|(?:auth|adapters)::')
    for directory in ['rust/crates/ginkgo_core/src', 'rust/crates/ginkgo_domain/src/ports',
                      'rust/crates/ginkgo_domain/src/features']:
        for file in (root / directory).rglob('*.rs'):
            # Comments may explain a prohibited dependency; check executable source.
            code = re.sub(r'(?m)^\s*//.*$', '', file.read_text())
            if directory.endswith("/ports") and "serde_json" in code:
                errors.append(f"{file.relative_to(root)}: business ports require typed values, not JSON envelopes")
            if forbidden.search(code) or "ginkgo_runtime::" in code:
                errors.append(f'{file.relative_to(root)}: school implementation crosses the business boundary')
    for file in (root / 'rust/crates/ginkgo_flutter_bridge/src/api').rglob('*.rs'):
        code = re.sub(r'(?m)^\s*//.*$', '', file.read_text())
        if forbidden.search(code) or 'include_str!' in code or 'serde_json::from_' in code:
            errors.append(f'{file.relative_to(root)}: native protocol/fixture decoding belongs to upstream/runtime')
    return errors


# Local persistence codecs decode files this app wrote itself (preferences,
# reminders, update gate), never school payloads. Located by path so a rename
# cannot silently promote a codec into an unchecked layer.
LOCAL_JSON_CODECS = {
    'shared/app_preferences.dart',
    'features/schedule/course_visibility.dart',
    'shared/reminders.dart',
    'platform/update_gate.dart',
    'workspace/workspace_shortcut_preferences.dart',
}

# Presentation layers own screens and shared components. Their widget APIs
# stay typed end to end: no raw school-payload maps cross this boundary.
PRESENTATION_DIRS = {'widgets', 'design', 'shared', 'features', 'workspace'}


def payload_decode_violations(root):
    """School payload JSON may only be decoded by typed model projections."""
    errors = []
    lib = root / 'flutter/lib'
    for file in lib.rglob('*.dart'):
        relative = file.relative_to(lib)
        top = relative.parts[0]
        if top in ('src', 'infrastructure', 'application'):
            continue
        if relative.name.endswith('_models.dart'):
            continue
        if relative.as_posix() in LOCAL_JSON_CODECS:
            continue
        code = file.read_text()
        if re.search(r'\bjsonDecode\s*\(', code):
            errors.append(
                f'{relative}: pages consume typed values; payload decoding belongs to *_models.dart')
        # Widget APIs stay typed end to end: pages and shared components never
        # accept or expose raw school-payload maps.
        is_presentation = (
            relative.name.endswith(('_page.dart', '_widgets.dart'))
            or top in PRESENTATION_DIRS
        )
        if is_presentation and 'Map<String, dynamic>' in code:
            errors.append(
                f'{relative}: presentation APIs must use typed values, not payload maps')
    return errors


def dart_boundary_violations(root):
    """Dart-side composition rules, kept pure so the self-test can cover them."""
    errors = []
    lib = root / 'flutter/lib'
    for file in lib.rglob('*.dart'):
        relative = file.relative_to(lib)
        if relative.parts[0] in ('src', 'infrastructure'):
            continue
        if re.search(r"[\"'][^\"']*buaa\.edu\.cn", file.read_text()):
            errors.append(f'{relative}: school destinations and domain policies belong to the provider')
        for imported in re.findall(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", file.read_text()):
            if 'src/rust/' in imported:
                # One type-only contract facade may expose generated values,
                # never command functions or the native library singleton.
                if relative.as_posix() != 'application/contracts.dart':
                    errors.append(f'{relative}: native dependency {imported}')
        if relative.as_posix() not in {'main.dart', 'mirror_service.dart'}:
            if re.search(r'\b(?:NativeMirrorService|DemoMirrorService|RustLib)\b', file.read_text()):
                errors.append(f'{relative}: native construction belongs to composition/adapters')
        if relative.as_posix() == 'application/contracts.dart':
            for directive in file.read_text().split(';'):
                if 'export ' in directive and ' show ' not in re.sub(r'\s+', ' ', directive):
                    errors.append('contracts.dart must use explicit type-only exports')
                elif 'export ' in directive:
                    exported = re.split(r'\bshow\b', directive, maxsplit=1)[1]
                    if any(not value.strip()[0].isupper() for value in exported.split(',') if value.strip()):
                        errors.append('contracts.dart must not export native commands')
    return errors


# Layering keeps new work grouped by domain instead of re-flattening `lib/`.
# Only composition entry points may sit at the root; everything else belongs in
# a domain directory. Growth inside one file is bounded the same way.
ROOT_ENTRY_POINTS = {'main.dart', 'mirror_service.dart', 'startup_page.dart'}
PRESENTATION_LINE_LIMIT = 600


def layout_violations(root):
    """lib/ stays grouped by responsibility; single files stay reviewable."""
    errors = []
    lib = root / 'flutter/lib'
    if not lib.exists():
        return errors

    for file in sorted(lib.glob('*.dart')):
        if file.name not in ROOT_ENTRY_POINTS:
            errors.append(
                f'{file.relative_to(lib)}: lib root holds entry points only; '
                f'group feature files under a domain directory')

    for file in lib.rglob('*.dart'):
        relative = file.relative_to(lib)
        if relative.parts[0] == 'src':
            # Generated bindings are not hand-edited and not size-reviewed.
            continue
        lines = len(file.read_text().splitlines())
        if lines > PRESENTATION_LINE_LIMIT:
            errors.append(
                f'{relative}: {lines} lines exceeds {PRESENTATION_LINE_LIMIT}; '
                f'split by responsibility instead of growing one file')
    return errors


def violations(root):
    metadata = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--manifest-path', str(root / 'rust/Cargo.toml'),
         '--no-deps', '--offline', '--locked', '--format-version', '1'], text=True))
    errors = dependency_violations(metadata['packages']) + source_violations(root)
    errors += payload_decode_violations(root)
    errors += dart_boundary_violations(root)
    errors += layout_violations(root)
    return errors


if __name__ == '__main__':
    failures = violations(ROOT)
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Mirror architecture boundaries passed.')

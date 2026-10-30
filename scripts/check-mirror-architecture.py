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
    'shared/course_visibility.dart',
    'shared/reminder_controller.dart',
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


# The presentation layer never reaches into the adapter layer. A page that
# composes its own adapter would read against a different account binding than
# the workspace it belongs to, which is exactly the bug the removed
# `service_factory` fallback could cause. The composition roots and the
# platform layer are exempt; they are where adapters are wired.
PRESENTATION_COMPOSITION_ROOTS = {'workspace/workspace_shell.dart'}
# Still pending migration: these name an injected port as a default value
# instead of composing an adapter. They are listed so the set cannot grow.
PENDING_ADAPTER_IMPORTS: set[str] = set()


def dart_boundary_violations(root):
    """Dart-side composition rules, kept pure so the self-test can cover them."""
    errors = []
    lib = root / 'flutter/lib'
    for file in lib.rglob('*.dart'):
        relative = file.relative_to(lib)
        if relative.parts[0] in ('src', 'infrastructure'):
            continue
        if relative.parts[0] == 'application' and re.search(
            r"(?:import|export)\s+['\"]package:path_provider/", file.read_text()
        ):
            errors.append(f'{relative}: platform storage belongs to infrastructure')
        if relative.as_posix() in {'shared/reminder_controller.dart', 'shared/reminder_scope.dart'} and re.search(
            r"(?:import|export)\s+['\"](?:package:ginkgo_mirror/infrastructure/|package:flutter/services\.dart|dart:io)",
            file.read_text(),
        ):
            errors.append(f'{relative}: reminder adapters belong to composition/infrastructure')
        if re.search(r"[\"'][^\"']*buaa\.edu\.cn", file.read_text()):
            errors.append(f'{relative}: school destinations and domain policies belong to the provider')
        for imported in re.findall(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", file.read_text()):
            if (
                relative.parts[0] in ('features', 'workspace')
                and relative.as_posix()
                not in PRESENTATION_COMPOSITION_ROOTS | PENDING_ADAPTER_IMPORTS
                and imported.startswith('package:ginkgo_mirror/infrastructure/')
            ):
                errors.append(f'{relative}: adapters belong to the composition root')
            if 'src/rust/' in imported:
                # Type-only facades may expose generated values, never command
                # functions or the native library singleton.
                if relative.as_posix() not in {'application/contracts.dart', 'application/failures.dart'}:
                    errors.append(f'{relative}: native dependency {imported}')
        if relative.as_posix() not in {'main.dart', 'mirror_service.dart'}:
            if re.search(r'\b(?:NativeMirrorService|DemoMirrorService|RustLib)\b', file.read_text()):
                errors.append(f'{relative}: native construction belongs to composition/adapters')
        if relative.as_posix() in {'application/contracts.dart', 'application/failures.dart'}:
            for directive in file.read_text().split(';'):
                if 'export ' in directive and ' show ' not in re.sub(r'\s+', ' ', directive):
                    errors.append(f'{relative}: use explicit type-only exports')
                elif 'export ' in directive:
                    exported = re.split(r'\bshow\b', directive, maxsplit=1)[1]
                    if any(not value.strip()[0].isupper() for value in exported.split(',') if value.strip()):
                        errors.append(f'{relative}: must not export native commands')
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


def sync_lock_await_violations(root):
    """Custom synchronous guards must be dropped before an async suspension."""
    errors = []
    declaration = re.compile(r'\blet\s+(?:mut\s+)?(\w+)\s*=\s*[^;]*\.lock\(\)\s*;')
    for file in (root / 'rust/crates/ginkgo_upstream/src').rglob('*.rs'):
        lines = file.read_text().splitlines()
        depth = 0
        guards = {}
        for number, line in enumerate(lines, 1):
            code = re.sub(r'//.*$', '', line)
            match = declaration.search(code)
            if match:
                guards[match.group(1)] = (depth, number)
            for name, (scope, start) in list(guards.items()):
                if re.search(rf'\bdrop\s*\(\s*{re.escape(name)}\s*\)', code):
                    del guards[name]
                elif '.await' in code:
                    errors.append(
                        f'{file.relative_to(root)}:{start}: synchronous guard `{name}` crosses await at line {number}')
                    del guards[name]
            depth += code.count('{') - code.count('}')
            for name, (scope, _) in list(guards.items()):
                if depth < scope:
                    del guards[name]
    return errors


def dart_import_cycles(root):
    """Reject file-level Dart import/export/part cycles, excluding generated bindings."""
    lib = (root / 'flutter/lib').resolve()
    if not lib.exists():
        return []
    files = {file.resolve() for file in lib.rglob('*.dart') if 'src/rust' not in file.as_posix()}
    graph = {file: set() for file in files}
    directive = re.compile(r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''', re.M)
    for file in files:
        for target in directive.findall(file.read_text()):
            if target.startswith('package:ginkgo_mirror/'):
                imported = lib / target.removeprefix('package:ginkgo_mirror/')
            elif target.startswith(('dart:', 'package:')):
                continue
            else:
                imported = (file.parent / target).resolve()
            if imported in files:
                graph[file].add(imported)

    index = 0
    indices, lowlinks, stack, on_stack, components = {}, {}, [], set(), []

    def visit(file):
        nonlocal index
        indices[file] = lowlinks[file] = index
        index += 1
        stack.append(file)
        on_stack.add(file)
        for imported in graph[file]:
            if imported not in indices:
                visit(imported)
                lowlinks[file] = min(lowlinks[file], lowlinks[imported])
            elif imported in on_stack:
                lowlinks[file] = min(lowlinks[file], indices[imported])
        if lowlinks[file] == indices[file]:
            component = []
            while True:
                member = stack.pop()
                on_stack.remove(member)
                component.append(member)
                if member == file:
                    break
            if len(component) > 1 or file in graph[file]:
                components.append(component)

    for file in sorted(files):
        if file not in indices:
            visit(file)
    return [
        'Dart import/export cycle: ' + ' -> '.join(
            str(file.relative_to(lib)) for file in component + [component[0]]
        )
        for component in components
    ]


def violations(root):
    metadata = json.loads(subprocess.check_output(
        ['cargo', 'metadata', '--manifest-path', str(root / 'rust/Cargo.toml'),
         '--no-deps', '--offline', '--locked', '--format-version', '1'], text=True))
    errors = dependency_violations(metadata['packages']) + source_violations(root)
    errors += payload_decode_violations(root)
    errors += dart_boundary_violations(root)
    errors += layout_violations(root)
    errors += sync_lock_await_violations(root)
    errors += dart_import_cycles(root)
    return errors


if __name__ == '__main__':
    failures = violations(ROOT)
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Mirror architecture boundaries passed.')

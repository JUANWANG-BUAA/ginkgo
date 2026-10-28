#!/usr/bin/env python3
"""生成全代码接口索引。

扫描 Rust workspace 与 Flutter lib 的公开接口，按层次与功能域排布输出到
docs/interfaces/。同一份源码只被解析一次，输出可直接 diff 审阅。

设计约束：
- 只索引公开面（Rust `pub*`、Dart 非下划线开头），私有实现不进入索引。
- 测试代码不计入接口面：Rust 跳过 `#[cfg(test)]` 后的内容，Dart 跳过 test/ 目录。
- 签名跨行时按括号平衡合并；超长签名折叠，避免表格难以阅读。
"""
from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / 'docs' / 'interfaces'
FLUTTER_LIB = REPO / 'flutter' / 'lib'
RUST_CRATES = REPO / 'rust' / 'crates'

SIGNATURE_LIMIT = 150
# 截断时保留尾部：返回类型是接口最重要的信息，不能被切掉。
TAIL_KEEP = 60

RUST_CRATE_ORDER = [
    'ginkgo_domain',
    'ginkgo_core',
    'ginkgo_upstream',
    'ginkgo_runtime',
    'ginkgo_flutter_bridge',
]


@dataclass
class Entry:
    """一条接口记录。"""

    name: str
    kind: str
    signature: str
    doc: str
    location: str
    members: list['Entry'] = field(default_factory=list)


@dataclass
class Section:
    """一个源码文件或逻辑分组。"""

    title: str
    location: str
    entries: list[Entry] = field(default_factory=list)


def collapse(text: str) -> str:
    """把跨行签名压成单行；超长时按参数边界智能缩写，保留返回类型。"""
    flat = re.sub(r'\s+', ' ', text).strip()
    flat = normalize_future(flat)
    if len(flat) <= SIGNATURE_LIMIT:
        return flat
    return abbreviate(flat)


FUTURE_PATTERN = re.compile(
    r'impl (?:std::future::Future|Future)\s*<\s*Output\s*=\s*(.+?)\s*>\s*\+\s*Send')


def normalize_future(text: str) -> str:
    """把 `impl Future<Output = T> + Send` 缩写为 `Future<T>`。

    这是本仓库端口方法的统一形态；保留原始 T 让返回类型一眼可见。
    """
    return FUTURE_PATTERN.sub(lambda m: f'Future<{m.group(1)}>', text)


def abbreviate(flat: str) -> str:
    """超长签名按结构缩写：保留函数名、首个参数与完整返回类型。"""
    # 定位参数括号与返回箭头，保证箭头之后的返回类型不被切断。
    arrow = flat.find(') -> ')
    if arrow < 0:
        head = flat[: SIGNATURE_LIMIT - TAIL_KEEP - 3].rstrip()
        return f'{head} … {flat[-TAIL_KEEP:].lstrip()}'
    open_paren = flat.find('(')
    prefix = flat[:open_paren]
    params = flat[open_paren + 1 : arrow]
    returns = flat[arrow + 1 :]
    first_param = params.split(',')[0].strip() if params.strip() else ''
    elided = '…' if ',' in params else ''
    combined = f'{prefix}({first_param}{elided}) {returns}'
    if len(combined) <= SIGNATURE_LIMIT:
        return combined
    keep = SIGNATURE_LIMIT - len(prefix) - 8
    return f'{prefix}(…{elided}) {returns[-keep:]}'


def signature_only(text: str) -> str:
    """截取声明签名，丢弃函数体。

    函数体是实现细节，混进索引只会淹没返回类型；按首个语句块大括号切分。
    """
    flat = re.sub(r'\s+', ' ', text).strip()
    # 找到签名部分：第一个 `{` 之前的内容（排除结构体字面量外的块）。
    depth = 0
    for index, char in enumerate(flat):
        if char == '{':
            if depth == 0:
                return flat[:index].rstrip() + ' {…}'
            depth += 1
        elif char == '}':
            depth -= 1
    return flat


def cell(text: str) -> str:
    """表格单元格转义。"""
    return text.replace('|', r'\|').replace('\n', ' ')


def doc_head(lines: list[str], index: int) -> str:
    """取紧邻声明上方的文档注释首行。"""
    collected: list[str] = []
    cursor = index - 1
    while cursor >= 0:
        line = lines[cursor].strip()
        if line.startswith('///'):
            collected.append(line[3:].strip())
        elif line.startswith('//!'):
            collected.append(line[3:].strip())
        elif line.startswith('#[') or line.startswith('@'):
            cursor -= 1
            continue
        else:
            break
        cursor -= 1
    if not collected:
        return ''
    return collected[-1]


def balanced_end(lines: list[str], start: int, stop_chars: str) -> int:
    """从 start 行起找到括号平衡且以 stop_chars 结尾的行号。"""
    depth = 0
    for index in range(start, len(lines)):
        line = lines[index]
        for char in line:
            if char in '({[':
                depth += 1
            elif char in ')}]':
                depth -= 1
        if depth <= 0 and any(char in line for char in stop_chars):
            return index
        if depth <= 0 and index > start:
            return index
    return start


def block_end(lines: list[str], start: int) -> int:
    """从 start 行起找到大括号配对的结束行（用于 trait/struct 等带 body 的声明）。"""
    depth = 0
    opened = False
    for index in range(start, len(lines)):
        for char in lines[index]:
            if char == '{':
                depth += 1
                opened = True
            elif char == '}':
                depth -= 1
        if opened and depth == 0:
            return index
        if not opened and index > start:
            return index
    return start


RUST_DECL = re.compile(
    r'^\s*pub(?:\((?P<scope>[a-z:]+)\))?\s+'
    r'(?P<kind>async\s+fn|fn|struct|enum|trait|type|const|static|use)\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)'
)
RUST_FIELD = re.compile(r'^\s+pub(?:\([a-z:]+\))?\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?),?\s*$')


def scan_rust(path: Path, crate: str) -> Section:
    """解析单个 Rust 文件的公开接口。"""
    lines = path.read_text(encoding='utf-8').splitlines()
    relative = path.relative_to(REPO).as_posix()

    # 测试模块之后不再是接口面。
    cut = len(lines)
    for index, line in enumerate(lines):
        if line.strip() == '#[cfg(test)]':
            cut = index
            break
    lines = lines[:cut]

    section = Section(title=path.stem, location=relative)
    index = 0
    while index < len(lines):
        match = RUST_DECL.match(lines[index])
        if not match:
            index += 1
            continue
        kind = match.group('kind').replace('async ', '')
        if kind == 'use':
            index += 1
            continue
        name = match.group('name')
        doc = doc_head(lines, index)

        if kind in {'trait', 'struct', 'enum'}:
            end = block_end(lines, index)
            # 头部只保留声明行，成员逐个列出，避免签名被截断掩盖接口。
            header = collapse(lines[index].rstrip(' {').rstrip())
            entry = Entry(name=name, kind=kind, signature=header, doc=doc,
                          location=f'{relative}:{index + 1}')
            if kind == 'trait':
                entry.members = rust_trait_members(lines, index, end)
            else:
                entry.members = rust_fields(lines, index, end)
            section.entries.append(entry)
            index = end + 1
            continue

        if kind in {'fn', 'type'}:
            end = balanced_end(lines, index, ';{')
            # 函数只取签名，实现体不进入索引。
            body = '\n'.join(lines[index : end + 1])
            signature = collapse(signature_only(body) if kind == 'fn' else body)
            section.entries.append(
                Entry(name=name, kind=kind, signature=signature, doc=doc,
                      location=f'{relative}:{index + 1}'))
            index = end + 1
            continue

        end = balanced_end(lines, index, ';')
        signature = collapse('\n'.join(lines[index : end + 1]))
        section.entries.append(
            Entry(name=name, kind=kind, signature=signature, doc=doc,
                  location=f'{relative}:{index + 1}'))
        index = end + 1
    return section


def rust_fields(lines: list[str], start: int, end: int) -> list[Entry]:
    """提取结构体/枚举的公开字段。"""
    members: list[Entry] = []
    for index in range(start, end + 1):
        field_match = RUST_FIELD.match(lines[index])
        if field_match:
            members.append(
                Entry(name=field_match.group(1), kind='field',
                      signature=collapse(field_match.group(1) + ': ' + field_match.group(2)),
                      doc=doc_head(lines, index),
                      location=f':{index + 1}'))
    return members


RUST_TRAIT_ITEM = re.compile(
    r'^    (?:async\s+)?fn\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)|'
    r'^    type\s+(?P<assoc>[A-Za-z_][A-Za-z0-9_]*)|'
    r'^    const\s+(?P<konst>[A-Z_][A-Z0-9_]*)\s*:'
)


def rust_trait_members(lines: list[str], start: int, end: int) -> list[Entry]:
    """提取 trait 的方法、关联类型与常量。

    trait 的方法才是它的接口面；只保留声明不保留默认实现体。
    """
    members: list[Entry] = []
    index = start + 1
    while index < end:
        match = RUST_TRAIT_ITEM.match(lines[index])
        if not match:
            index += 1
            continue
        name = match.group('name') or match.group('assoc') or match.group('konst')
        stop = ';{' if match.group('name') else ';'
        item_end = balanced_end(lines, index, stop)
        body = '\n'.join(lines[index:item_end + 1])
        is_method = match.group('name') is not None
        members.append(
            Entry(name=name, kind='method' if is_method else 'assoc',
                  signature=collapse(signature_only(body) if is_method else body),
                  doc=doc_head(lines, index),
                  location=f':{index + 1}'))
        index = item_end + 1
    return members


DART_TOP = re.compile(
    r'^(?:(?:abstract|final|sealed|base|interface|mixin)\s+)*'
    r'(?P<kind>class|mixin|enum|extension|typedef)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)'
)
DART_MEMBER = re.compile(
    r'^  (?P<static>static\s+)?'
    r'(?P<sig>(?:const\s+)?[A-Za-z_][A-Za-z0-9_<>,?. ]*\s+'
    r'(?:get\s+)?[a-zA-Z_][A-Za-z0-9_]*\s*[({=])'
)


def scan_dart(path: Path) -> list[Section]:
    """解析单个 Dart 文件的公开类型与成员。

    一个文件渲染为一个分组（而不是每个类一个分组）：按类拆分会让目录比条目
    更冗长，反而不利于浏览。
    """
    lines = path.read_text(encoding='utf-8').splitlines()
    relative = path.relative_to(FLUTTER_LIB).as_posix()
    entries: list[Entry] = []
    index = 0
    while index < len(lines):
        match = DART_TOP.match(lines[index])
        if not match:
            index += 1
            continue
        kind = match.group('kind')
        name = match.group('name')
        if name.startswith('_'):
            index = block_end(lines, index) + 1
            continue
        doc = doc_head(lines, index)
        end = block_end(lines, index) if kind in {'class', 'mixin', 'enum', 'extension'} else balanced_end(lines, index, ';')
        entry = Entry(name=name, kind=kind,
                      signature=collapse(lines[index].rstrip(' {').rstrip()),
                      doc=doc, location=f'{relative}:{index + 1}')
        if kind in {'class', 'mixin', 'enum', 'extension'}:
            entry.members = dart_members(lines, index, end)
        entries.append(entry)
        index = end + 1
    if not entries:
        return []
    return [Section(title=relative, location=relative, entries=entries)]


def dart_members(lines: list[str], start: int, end: int) -> list[Entry]:
    """提取类内公开成员。"""
    members: list[Entry] = []
    index = start + 1
    while index < end:
        member_match = DART_MEMBER.match(lines[index])
        if not member_match:
            index += 1
            continue
        sig = member_match.group('sig').strip()
        identifier = re.search(r'([a-zA-Z_][A-Za-z0-9_]*)\s*[({=]\s*$', sig)
        if identifier is None or identifier.group(1).startswith('_'):
            index += 1
            continue
        stop = ';' if sig.endswith(';') else '{;'
        member_end = balanced_end(lines, index, stop)
        body = '\n'.join(lines[index:member_end + 1])
        # 抽象成员保留完整声明；有实现体的成员只保留签名。
        rendered = collapse(body) if sig.endswith(';') else collapse(signature_only(body))
        members.append(
            Entry(name=identifier.group(1), kind='member',
                  signature=rendered,
                  doc=doc_head(lines, index),
                  location=f':{index + 1}'))
        index = member_end + 1
    return members


def slugify(text: str) -> str:
    """生成 GitHub 风格锚点。"""
    lowered = text.strip().lower()
    lowered = re.sub(r'[`*_]', '', lowered)
    lowered = re.sub(r'[^\w\u4e00-\u9fff\s-]', '', lowered)
    return re.sub(r'\s+', '-', lowered)


def render_sections(sections: list[Section], heading_level: int = 2) -> list[str]:
    """渲染分组为 Markdown；超过 8 个分组时先给目录。"""
    output: list[str] = []
    visible = [section for section in sections if section.entries]
    if len(visible) > 8:
        output.append('## 目录')
        output.append('')
        for section in visible:
            count = len(section.entries)
            output.append(f'- [{section.title}](#{slugify(section.title)}) ({count})')
        output.append('')

    for section in visible:
        output.append(f'{"#" * heading_level} {section.title}')
        output.append('')
        for entry in section.entries:
            signature = cell(entry.signature)
            doc = cell(entry.doc)
            suffix = f' — {doc}' if doc else ''
            output.append(f'- `{signature}`{suffix}  ')
            output.append(f'  <sub>{entry.kind} · {entry.location}</sub>')
            for member in entry.members:
                member_doc = f' — {cell(member.doc)}' if member.doc else ''
                output.append(
                    f'    - `{cell(member.signature)}`{member_doc}  '
                    f'<sub>{member.location}</sub>')
        output.append('')
    return output


HEADER = (
    '> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。\n'
    '> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；\n'
    '> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。\n'
)


def write(name: str, title: str, sections: list[Section], note: str = '') -> int:
    """写出一个索引文件，返回条目数。"""
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [f'# {title}', '', HEADER]
    if note:
        lines.append(note)
        lines.append('')
    lines.extend(render_sections(sections))
    content = '\n'.join(line.rstrip() for line in lines).rstrip() + '\n'
    (OUT_DIR / name).write_text(content, encoding='utf-8')
    return sum(len(section.entries) for section in sections)


def group_rust() -> dict[str, list[Section]]:
    """按 crate 与模块层收集 Rust 接口。"""
    grouped: dict[str, list[Section]] = {}
    for crate in RUST_CRATE_ORDER:
        root = RUST_CRATES / crate / 'src'
        if not root.exists():
            continue
        for path in sorted(root.rglob('*.rs')):
            if path.name == 'frb_generated.rs':
                continue
            # 测试目录与 tests.rs 是测试代码，不算接口面。
            parts = set(path.parts)
            if path.name == 'tests.rs' or 'tests' in parts:
                continue
            section = scan_rust(path, crate)
            if not section.entries:
                continue
            layer = rust_layer(crate, path, root)
            grouped.setdefault(layer, []).append(section)
    return grouped


def rust_layer(crate: str, path: Path, root: Path) -> str:
    """把 Rust 文件归入逻辑层，作为文档的一级分组。"""
    relative = path.relative_to(root).as_posix()
    top = relative.split('/')[0]
    if crate == 'ginkgo_domain':
        if top == 'ports':
            return 'domain-ports'
        if top == 'features':
            return 'domain-features'
        return 'domain-foundation'
    if crate == 'ginkgo_core':
        return 'core-application'
    if crate == 'ginkgo_upstream':
        return {
            'adapters': 'upstream-adapters',
            'codecs': 'upstream-codecs',
            'auth': 'upstream-auth',
            'services': 'upstream-services',
        }.get(top, 'upstream-foundation')
    if crate == 'ginkgo_runtime':
        return 'runtime'
    return 'bridge'


RUST_LAYERS = [
    ('domain-ports', 'domain-ports', '领域业务端口（ginkgo_domain::ports）',
     '稳定能力边界；core 只依赖这些 trait，不依赖学校实现。'),
    ('domain-features', 'domain-features', '领域值类型与纯规则（ginkgo_domain::features）',
     '业务数据结构与不依赖网络的规则；此处禁止出现学校 URL 与 HTTP。'),
    ('domain-foundation', 'domain-foundation', '领域基础类型（ginkgo_domain）',
     '错误分类、序列化信封与共享值。'),
    ('core-application', 'core-application', '应用编排（ginkgo_core）',
     '命令编排、账号隔离与本机持久化。'),
    ('upstream-adapters', 'upstream-adapters', '上游适配器（ginkgo_upstream::adapters）',
     '请求构造、认证注入与响应分类；学校协议事实见 API.md。'),
    ('upstream-codecs', 'upstream-codecs', '上游解析（ginkgo_upstream::codecs）',
     '响应结构到领域值的映射；不推断缺失字段。'),
    ('upstream-auth', 'upstream-auth', '认证与会话（ginkgo_upstream::auth）',
     '登录页解析、表单提交、凭据与会话验证。'),
    ('upstream-services', 'upstream-services', '上游服务（ginkgo_upstream::services）',
     '业务会话、token、查询缓存与协议时序。'),
    ('upstream-foundation', 'upstream-foundation', '上游基础能力（ginkgo_upstream）',
     'HTTP 传输、Cookie、路由与错误映射。'),
    ('runtime', 'runtime', '组装（ginkgo_runtime）',
     '连接 core 与真实学校/平台实现；平台保险库选择。'),
    ('bridge', 'bridge', '桥接（ginkgo_flutter_bridge）',
     'FFI DTO 与粗粒度命令；Dart 唯一可见的 Rust 面。'),
]


DART_LAYERS = [
    ('application', 'Dart 应用接口（flutter/lib/application）',
     '页面依赖的 gateway、契约与局部应用状态。'),
    ('infrastructure', 'Dart 基础设施（flutter/lib/infrastructure）',
     'native/demo 适配器、运行时与持久化实现。'),
    ('shared', '跨域共享状态（flutter/lib/shared）',
     '时间、偏好、提醒等被多个域复用的状态与值。'),
    ('platform', '平台集成（flutter/lib/platform）',
     '系统设置、更新门禁与启动更新。'),
    ('widgets', '共享呈现组件（flutter/lib/widgets）',
     '设计系统之上的可复用组件。'),
    ('design', '设计系统（flutter/lib/design）',
     'token 层与视觉常量。'),
    ('app', '应用外壳组件（flutter/lib/app）',
     'CupertinoApp 组合与主题桥接。'),
    ('workspace', '工作区壳层（flutter/lib/workspace）',
     '导航、功能登记表与布局壳。'),
]


def group_dart() -> tuple[dict[str, list[Section]], dict[str, list[Section]]]:
    """收集 Dart 接口，返回（分层组, 功能域组）。"""
    layers: dict[str, list[Section]] = {}
    features: dict[str, list[Section]] = {}

    for path in sorted(FLUTTER_LIB.rglob('*.dart')):
        relative = path.relative_to(FLUTTER_LIB)
        top = relative.parts[0]
        # 生成的绑定不是手写接口面。
        if top == 'src':
            continue
        sections = scan_dart(path)
        if not sections:
            continue
        if top == 'features' and len(relative.parts) > 2:
            domain = relative.parts[1]
            features.setdefault(domain, []).extend(sections)
        elif relative.name == 'main.dart':
            layers.setdefault('app', []).extend(sections)
        elif len(relative.parts) == 1:
            layers.setdefault('app', []).extend(sections)
        else:
            layers.setdefault(top, []).extend(sections)
    return layers, features


def main() -> None:
    check = '--check' in sys.argv
    before = snapshot()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    totals: list[tuple[str, str, int]] = []
    # 反向索引：源码文件 -> 该文件暴露的接口，用于从代码位置回查能力。
    reverse: dict[str, list[str]] = {}

    rust_groups = group_rust()
    for key, filename, title, note in RUST_LAYERS:
        sections = rust_groups.get(key, [])
        if not sections:
            continue
        count = write(f'rust-{filename}.md', title, sections, note)
        totals.append((f'rust-{filename}.md', title, count))
        collect_reverse(reverse, sections, f'rust-{filename}.md')

    dart_layers, dart_features = group_dart()
    for key, title, note in DART_LAYERS:
        sections = dart_layers.get(key, [])
        if not sections:
            continue
        count = write(f'dart-{key}.md', title, sections, note)
        totals.append((f'dart-{key}.md', title, count))
        collect_reverse(reverse, sections, f'dart-{key}.md')

    for domain in sorted(dart_features):
        sections = dart_features[domain]
        count = write(f'dart-feature-{domain}.md', f'Flutter 功能域：{domain}', sections,
                      f'`flutter/lib/features/{domain}/` 的页面、域内组件与模型。')
        totals.append((f'dart-feature-{domain}.md', f'Flutter 功能域：{domain}', count))
        collect_reverse(reverse, sections, f'dart-feature-{domain}.md')

    write_reverse(reverse)
    write_dependency_graph()
    write_readme(totals)

    if check:
        after = snapshot()
        stale = sorted(set(before) ^ set(after)) + sorted(
            name for name in set(before) & set(after) if before[name] != after[name])
        if stale:
            raise SystemExit(
                'interface index is stale; run python3 scripts/generate-interface-index.py:\n  '
                + '\n  '.join(stale))
        print(f'interface index is current ({len(totals)} files)')
        return

    print(f'generated {len(totals)} index files, {sum(t[2] for t in totals)} entries')


def collect_reverse(reverse: dict[str, list[str]], sections: list[Section],
                    index_file: str) -> None:
    """累积「源码文件 -> 接口名（所属索引页）」的反向映射。"""
    for section in sections:
        source = section.location.split(':')[0]
        bucket = reverse.setdefault(source, [])
        for entry in section.entries:
            bucket.append(f'{entry.name} → {index_file}')


def dart_group(relative: str) -> str:
    """把 lib 相对路径归入依赖图的分组。"""
    parts = relative.split('/')
    if parts[0] == 'features' and len(parts) > 2:
        return 'features/' + parts[1]
    return parts[0] if len(parts) > 1 else 'root'


def dart_dependency_graph() -> dict[str, set[str]]:
    """按目录分组统计 Dart 跨组依赖。"""
    graph: dict[str, set[str]] = {}
    for path in sorted(FLUTTER_LIB.rglob('*.dart')):
        relative = path.relative_to(FLUTTER_LIB).as_posix()
        if relative.startswith('src/'):
            continue
        source = dart_group(relative)
        code = path.read_text(encoding='utf-8')
        for match in re.finditer(r"(?:import|export)\s+'([^']+)'", code):
            target = match.group(1)
            if not target.startswith('package:ginkgo_mirror/'):
                continue
            target_group = dart_group(target[len('package:ginkgo_mirror/'):])
            if target_group == source:
                continue
            graph.setdefault(source, set()).add(target_group)
    return graph


def strongly_connected(graph: dict[str, set[str]]) -> list[list[str]]:
    """Tarjan 求强连通分量，只返回真正的环（成员数 > 1）。"""
    index: dict[str, int] = {}
    low: dict[str, int] = {}
    stack: list[str] = []
    on_stack: set[str] = set()
    components: list[list[str]] = []
    counter = [0]

    nodes = set(graph) | {target for targets in graph.values() for target in targets}

    def visit(node: str) -> None:
        index[node] = low[node] = counter[0]
        counter[0] += 1
        stack.append(node)
        on_stack.add(node)
        for neighbour in graph.get(node, ()):
            if neighbour not in index:
                visit(neighbour)
                low[node] = min(low[node], low[neighbour])
            elif neighbour in on_stack:
                low[node] = min(low[node], index[neighbour])
        if low[node] == index[node]:
            component: list[str] = []
            while True:
                popped = stack.pop()
                on_stack.discard(popped)
                component.append(popped)
                if popped == node:
                    break
            if len(component) > 1:
                components.append(sorted(component))

    for node in sorted(nodes):
        if node not in index:
            visit(node)
    return components


def write_dependency_graph() -> None:
    """生成 Dart 目录依赖图与循环检测结果。"""
    graph = dart_dependency_graph()
    components = strongly_connected(graph)
    edges = sum(len(targets) for targets in graph.values())
    node_count = len(set(graph) | {t for v in graph.values() for t in v})

    lines = [
        '# Flutter 目录依赖图（生成）',
        '',
        HEADER,
        f'按目录分组统计：{node_count} 个分组节点（其中 {len(graph)} 个有出向依赖）、'
        f'{edges} 条跨组依赖。'
        '箭头方向为「依赖方 → 被依赖方」。',
        '',
        '## 依赖图',
        '',
        '```mermaid',
        'flowchart LR',
    ]
    # 节点按分组名排序，保证输出稳定。
    for group in sorted(set(graph) | {t for v in graph.values() for t in v}):
        lines.append(f'  {mermaid_id(group)}["{group}"]')
    for group in sorted(graph):
        for target in sorted(graph[group]):
            lines.append(f'  {mermaid_id(group)} --> {mermaid_id(target)}')
    lines += ['```', '']

    lines.append('## 循环依赖')
    lines.append('')
    if components:
        lines.append(
            '以下分组互相依赖，构成强连通分量。Dart 侧没有像 Rust 那样的依赖方向门禁，'
            '因此这些环不会被自动拦截；改动前先确认是否真的需要双向引用。')
        lines.append('')
        for component in sorted(components, key=len, reverse=True):
            lines.append(f'- **{len(component)} 个分组**：' + '、'.join(f'`{c}`' for c in component))
            lines.append('')
            lines.append('```mermaid')
            lines.append('flowchart LR')
            inside = set(component)
            for source in component:
                for target in sorted(graph.get(source, set()) & inside):
                    lines.append(f'  {mermaid_id(source)} --> {mermaid_id(target)}')
            lines.append('```')
            lines.append('')
    else:
        lines.append('未发现循环依赖。')
        lines.append('')

    (OUT_DIR / 'DEPENDENCY-GRAPH.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def mermaid_id(group: str) -> str:
    """把分组名转成 Mermaid 安全的节点 id。"""
    return 'n_' + re.sub(r'[^A-Za-z0-9]', '_', group)


def write_reverse(reverse: dict[str, list[str]]) -> None:
    """生成源码文件到接口的反向索引。"""
    lines = [
        '# 反向索引：源码文件 → 接口',
        '',
        HEADER,
        '从代码位置回查它暴露了哪些接口，以及这些接口记录在哪个索引页。',
        '按路径排序；同一文件内的接口保持源码顺序。',
        '',
        '| 源码文件 | 接口（→ 索引页） |',
        '| --- | --- |',
    ]
    for source in sorted(reverse):
        names = reverse[source]
        joined = '<br>'.join(cell(name) for name in names)
        lines.append(f'| `{source}` | {joined} |')
    (OUT_DIR / 'REVERSE-INDEX.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def snapshot() -> dict[str, str]:
    """记录当前索引文件内容，用于 --check 比对。"""
    if not OUT_DIR.exists():
        return {}
    return {path.name: path.read_text(encoding='utf-8')
            for path in OUT_DIR.glob('*.md')}


def write_readme(totals: list[tuple[str, str, int]]) -> None:
    """生成索引目录页。"""
    lines = [
        '# 接口索引（生成）',
        '',
        HEADER,
        '按层与功能域拆分的全量接口清单。每个文件列出该层所有公开类型、函数与方法，'
        '含签名、源码位置与文档首行。',
        '',
        '| 文件 | 内容 | 条目数 |',
        '| --- | --- | --- |',
    ]
    for filename, title, count in totals:
        lines.append(f'| [{title}]({filename}) | `{filename}` | {count} |')
    lines.append('')
    lines.append('## 快速导航')
    lines.append('')
    lines.append('- 新增接口先选模式：[接口设计模式](../INTERFACE-INDEX.md#11-接口设计模式)')
    lines.append('- 从代码位置回查接口：[反向索引](REVERSE-INDEX.md)')
    lines.append('- 分层说明、能力总表、模块 IO 与跨层不变量：[INTERFACE-INDEX.md](../INTERFACE-INDEX.md)')
    lines.append('- 学校协议事实：[API.md](../API.md)')
    (OUT_DIR / 'README.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

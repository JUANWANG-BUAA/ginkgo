#!/usr/bin/env python3
"""检查协议与接口文档是否跟得上代码。

`docs/API.md` 是学校协议的唯一事实源，`docs/FEATURES-AND-PROTOCOLS.md` 是能力
与本地契约索引，`docs/INTERFACE-INDEX.md` 是全代码接口总览。三份都靠手工维护，
而代码一直在动：目录重组会让链接指空，新增适配器会漏登记，载荷信封命令迁移
会让 §6.10 的手抄清单过期。这个门禁只拦这三类**可机械判定**的漂移。

三项检查：

1. **内部链接可达**：`README.md` 与 `docs/**/*.md` 里的相对链接必须指向存在的
   文件；带 `#锚点` 的必须命中目标文档真实存在的标题（GitHub slug 规则）。
   代码块与行内代码先剥离，避免把正则字符类当成链接。
2. **协议适配器已登记**：`upstream/src/adapters/*_http.rs` 每一个都必须在
   FEATURES-AND-PROTOCOLS 或 INTERFACE-INDEX 中被按文件名引用。新增学校协议
   却没有文档入口时失败。
3. **载荷信封清单与计数一致**：从 FRB 生成的 Dart 绑定重新统计命令总数与返回
   `ReadOnlyResponse` 的命令，与 INTERFACE-INDEX §6.10 的手抄清单和计数比对。

用法：
    python3 scripts/check-api-doc.py            # 检查，失败即非零退出
    python3 scripts/check-api-doc.py --report   # 只打印统计，不判定
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / 'docs'
API_DIR = ROOT / 'flutter' / 'lib' / 'src' / 'rust' / 'api'
ADAPTERS = ROOT / 'rust' / 'crates' / 'ginkgo_upstream' / 'src' / 'adapters'

# 协议与接口文档的登记入口：适配器必须出现在其中之一。
REGISTRIES = ('FEATURES-AND-PROTOCOLS.md', 'INTERFACE-INDEX.md')

LINK = re.compile(r'\[[^\]]*\]\(([^)\s]+)\)')
HEADING = re.compile(r'^(#{1,6})\s+(.*)$')
FENCE = re.compile(r'^(```|~~~)')
COMMAND = re.compile(r'^Future<([A-Za-z_]+)>\s+(\w+)\(', re.M)


def strip_code(text: str) -> str:
    """去掉围栏代码块与行内代码，它们里的方括号不是链接。"""
    kept: list[str] = []
    fenced = False
    for line in text.splitlines():
        if FENCE.match(line.strip()):
            fenced = not fenced
            continue
        if fenced:
            continue
        kept.append(re.sub(r'`[^`]*`', '', line))
    return '\n'.join(kept)


def anchors(text: str) -> set[str]:
    """按 GitHub 的规则生成标题锚点：小写、去标点、空格转连字符。

    CJK 表意文字属于字母，`isalnum()` 为真因此保留；全角括号等标点是假，
    因此被剔除——这正是 `### 2.4 周课表（核心）` 变成 `#24-周课表核心` 的原因。
    """
    found: set[str] = set()
    for line in text.splitlines():
        match = HEADING.match(line)
        if not match:
            continue
        slug = re.sub(r'[`*_]', '', match.group(2).strip().lower())
        slug = ''.join(c for c in slug if c.isalnum() or c in ' -_')
        found.add(slug.replace(' ', '-'))
    return found


def markdown_documents() -> list[Path]:
    readme = ROOT / 'README.md'
    documents = [readme] if readme.exists() else []
    return documents + sorted(DOCS.rglob('*.md'))


def check_links() -> tuple[list[str], int]:
    """返回（断链清单, 检查过的链接数）。"""
    cache: dict[Path, set[str]] = {}

    def anchors_for(path: Path) -> set[str]:
        if path not in cache:
            cache[path] = anchors(path.read_text(encoding='utf-8')) if path.exists() else set()
        return cache[path]

    broken: list[str] = []
    total = 0
    for document in markdown_documents():
        text = strip_code(document.read_text(encoding='utf-8'))
        for target in LINK.findall(text):
            if target.startswith(('http://', 'https://', 'mailto:', '#')):
                continue
            total += 1
            file_part, _, fragment = target.partition('#')
            if not file_part:
                continue
            resolved = (document.parent / file_part).resolve()
            if not resolved.exists():
                broken.append(f'{document.relative_to(ROOT)} -> {target} (文件不存在)')
                continue
            if not fragment or resolved.suffix != '.md':
                continue
            if fragment.lower() not in anchors_for(resolved):
                broken.append(f'{document.relative_to(ROOT)} -> {target} (锚点不存在)')
    return broken, total


def check_adapters() -> tuple[list[str], int]:
    """返回（未登记的协议适配器, 适配器总数）。"""
    registry = '\n'.join(
        (DOCS / name).read_text(encoding='utf-8') for name in REGISTRIES
    )
    adapters = sorted(
        path.name for path in ADAPTERS.glob('*_http.rs')
    )
    missing = [name for name in adapters if name not in registry]
    return missing, len(adapters)


def command_shapes() -> tuple[int, list[str]]:
    """从生成绑定统计命令总数与载荷信封命令。"""
    total = 0
    envelope: list[str] = []
    for path in sorted(API_DIR.rglob('*.dart')):
        for match in COMMAND.finditer(path.read_text(encoding='utf-8')):
            total += 1
            if match.group(1) == 'ReadOnlyResponse':
                envelope.append(match.group(2))
    return total, sorted(envelope)


def check_envelope_list() -> list[str]:
    """比对 §6.10 的手抄清单、计数表与生成绑定。"""
    text = (DOCS / 'INTERFACE-INDEX.md').read_text(encoding='utf-8')
    total, envelope = command_shapes()
    problems: list[str] = []

    listing = re.search(r'使用载荷信封的 (\d+) 个命令：\n\n(.+?)\n\n', text, re.S)
    if not listing:
        return ['INTERFACE-INDEX.md 缺少「使用载荷信封的 N 个命令」清单']
    claimed = int(listing.group(1))
    listed = sorted(set(re.findall(r'`(\w+)`', listing.group(2))))
    if claimed != len(envelope):
        problems.append(f'§6.10 声称 {claimed} 个信封命令，生成绑定实际 {len(envelope)} 个')
    if listed != envelope:
        for name in set(envelope) - set(listed):
            problems.append(f'§6.10 清单缺少已返回信封的命令 `{name}`')
        for name in set(listed) - set(envelope):
            problems.append(f'§6.10 清单仍列着已不再返回信封的命令 `{name}`')

    table = re.search(
        r'\| 类型化 DTO \| (\d+) \|.*?\n\| `ReadOnlyResponse` 载荷 \| (\d+) \|',
        text,
        re.S,
    )
    if table:
        typed, wrapped = int(table.group(1)), int(table.group(2))
        if typed != total - len(envelope) or wrapped != len(envelope):
            problems.append(
                f'§6.10 计数表写 {typed}/{wrapped}，生成绑定实际 '
                f'{total - len(envelope)}/{len(envelope)}'
            )
    counts = re.search(r'(\d+) 个命令按返回形态分为两类', text)
    if counts and int(counts.group(1)) != total:
        problems.append(f'§6.10 写 {counts.group(1)} 个命令，生成绑定实际 {total} 个')
    return problems


def main() -> None:
    broken, link_total = check_links()
    missing, adapter_total = check_adapters()
    envelope_problems = check_envelope_list()
    total, envelope = command_shapes()

    print('api & interface doc sync:')
    print(f'  internal links      {link_total - len(broken):>4} / {link_total:<4} resolve'
          + ('  ok' if not broken else '  BROKEN'))
    print(f'  protocol adapters   {adapter_total - len(missing):>4} / {adapter_total:<4} registered'
          + ('  ok' if not missing else '  MISSING'))
    print(f'  ffi commands        {total:>4} total, {len(envelope)} payload envelope'
          + ('  ok' if not envelope_problems else '  STALE'))

    if '--report' in sys.argv:
        return

    details: list[str] = []
    for item in broken:
        details.append(f'  broken link: {item}')
    for name in missing:
        details.append(
            f'  unregistered adapter: adapters/{name} '
            f'(add it to {" or ".join(REGISTRIES)})'
        )
    details.extend(f'  {problem}' for problem in envelope_problems)
    if details:
        raise SystemExit(
            '\n'.join(details)
            + '\ndocs/API.md is the protocol source of truth and the interface'
            ' index is generated; keep the hand-written parts in step with code.'
        )


if __name__ == '__main__':
    main()

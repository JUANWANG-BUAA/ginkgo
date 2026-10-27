#!/usr/bin/env python3
"""检查 Flutter 侧的硬编码视觉常量是否回潮。

设计 token 定义在 `flutter/lib/design/tokens/`，门面是 `AppleDesign`。页面里
直接写 `fontSize: 17`、`EdgeInsets.all(16)`、`SizedBox(height: 96)` 会绕过
token，让大字号与深浅色适配失去统一出口。

这个门禁不要求一次性清零（历史页面仍在迁移），而是**只许减、不许增**：
预算写在下方 BUDGET 里，计数上升即失败。页面改用 token 后计数下降时，
请同步下调预算，让门禁始终反映真实状态。

用法：
    python3 scripts/check-design-tokens.py           # 检查并打印统计
    python3 scripts/check-design-tokens.py --report  # 只打印统计，不判定
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'flutter' / 'lib'

# 计数上限。下降时请同步下调，使门禁始终卡住“回潮”。
# 口径：带数字字面量的 `fontSize:`、`EdgeInsets*(`、`SizedBox(`、
# `BorderRadius.circular(`；注释不计入；`flutter/lib/design/` 与生成物不计入。
# 用了 token 的写法不计为硬编码。
BUDGET = {
    'font_size': 204,
    'edge_insets': 268,
    'sized_box': 208,
    'border_radius': 42,
}

# 允许的例外：设计系统自身、共享组件与演示/测试替身不在门禁范围内，
# 因为它们就是 token 的定义处或刻意展示原始值。
EXEMPT_PREFIXES = (
    'design/',
    'src/',  # FRB 生成物
)

FONT_SIZE = re.compile(r'\bfontSize\s*:\s*(-?\d+(?:\.\d+)?)\b')
# 只统计带数字字面量的调用：用了 token 的写法不算硬编码。
EDGE_INSETS = re.compile(r'\bEdgeInsets(?:\.\w+)?\s*\([^)]*\d')
SIZED_BOX = re.compile(r'\bSizedBox\s*\([^)]*\d')
BORDER_RADIUS = re.compile(r'\bBorderRadius\.(?:circular|elliptical)\s*\([^)]*\d')


def strip_comments(text: str) -> str:
    """去掉行注释与块注释，避免注释里的示例数字计入统计。"""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'(?m)//.*$', '', text)
    return text


def scan() -> dict[str, int]:
    """统计各���硬编码类别的出现次数。"""
    counts = {'font_size': 0, 'edge_insets': 0, 'sized_box': 0, 'border_radius': 0}
    for path in sorted(LIB.rglob('*.dart')):
        relative = path.relative_to(LIB).as_posix()
        if relative.startswith(EXEMPT_PREFIXES):
            continue
        code = strip_comments(path.read_text(encoding='utf-8'))
        counts['font_size'] += len(FONT_SIZE.findall(code))
        counts['edge_insets'] += len(EDGE_INSETS.findall(code))
        counts['sized_box'] += len(SIZED_BOX.findall(code))
        counts['border_radius'] += len(BORDER_RADIUS.findall(code))
    return counts


def main() -> None:
    counts = scan()
    print('design token adoption (hard-coded occurrences):')
    for key, value in counts.items():
        budget = BUDGET.get(key, 0)
        status = 'ok' if value <= budget else 'over budget'
        print(f'  {key:<14} {value:>4} / budget {budget:>4}  {status}')
    if '--report' in sys.argv:
        return
    exceeded = [key for key, value in counts.items() if value > BUDGET.get(key, 0)]
    if exceeded:
        raise SystemExit(
            'hard-coded design values grew: ' + ', '.join(exceeded)
            + '\nuse the tokens in flutter/lib/design/tokens/ instead'
            + '\n(if the count dropped, lower the budget in scripts/check-design-tokens.py)')


if __name__ == '__main__':
    main()

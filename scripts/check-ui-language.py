#!/usr/bin/env python3
"""检查 Flutter 侧是否偏离 iOS 原初交互语言。

原初设计以冻结的 Apple 实现为准（`BUAA-Assistant-iOS/Sources/IOSMainView.swift`、
`Native/IOSGradeView.swift`、`Core/UI/PageComponents.swift`）。本门禁把其中
不可退让的部分写成可判定规则，避免后续改动把系统控件语义换成自制控件，
或把说明文字重新堆回卡片底部。

用法：
    python3 scripts/check-ui-language.py           # 检查并打印统计
    python3 scripts/check-ui-language.py --report  # 只打印统计，不判定

门禁与设计令牌门禁同口径：**只许减、不许增**。硬性规则（刷新动作只在导航栏、
状态必须有图标、一级标签固定 5 个且含「更多」）要求计数为 0；说明区与汇总层
记录当前债务，页面改造后应同步下调预算。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'flutter' / 'lib'
FEATURES = LIB / 'features'

# 卡片内的刷新动作：刷新动作只属于导航栏或下拉刷新。只匹配按钮，
# 错误提示与说明文字里的"刷新"是另一回事。
REFRESH_BUTTON = re.compile(
    r"CupertinoButton\((?:[^;]{0,400}?)child:\s*(?:const\s+)?Text\(\s*'[^']*"
    r"(刷新|重新加载|重新读取)[^']*'"
)
REFRESH_LABEL = re.compile(
    r"CupertinoButton\((?:[^;]{0,400}?)child:\s*(?:const\s+)?Text\(\s*'查询余额'"
)

# 状态标签必须带图标：状态 = 文案 + 颜色 + 图标。
BADGE_CALL = re.compile(r'GinkgoBadge\((?:[^()]|\([^()]*\))*?\)', re.S)
BADGE_ICON = re.compile(r'icon\s*:')

# 说明区只允许一行：多行散文或超长段落属于说明堆砌，必须收进详情或口径行。
LONG_FOOTER = re.compile(r"footer:\s*(?:const\s+)?Text\(\s*'([^']{40,})'")
FOOTER_LIMIT = 72

# 汇总层：页面必须能说清"现在是什么情况"。汇总组件可以与页面分文件，
# 因此按功能目录整体判断。
SUMMARY_TOKENS = (
    'SummaryStrip(',
    'SummaryLine(',
    'AcademicMetricGrid(',
    'AcademicOverview(',  # Hero value plus labeled supporting academic metrics.
    'ResourceMeter(',
    'CheckinStatusSummary(',
    'GraduateStat(',
    'GraduateProgress(',
    # Homework combines status counts with its segmented filter. This keeps
    # the overview actionable without repeating a separate summary card.
    "Key('homework-status-summary')",
    "Key('homework-deadline-summary')",
)

# 页面外壳：表单页、聚合页与设置页没有单一数据集，不要求汇总层。
SUMMARY_EXEMPT = (
    'task_editor.dart',
    'settings_page.dart',
    'login_page.dart',
    'today_page.dart',
    'cgyy_captcha_page.dart',
    'network_diagnostics_page.dart',
)

# 计数上限。下降时请同步下调，使门禁始终卡住"回潮"。
BUDGET = {
    'refresh_button': 0,
    'badge_without_icon': 0,
    'long_footer': 0,
    'page_without_summary': 0,
}


def strip_comments(text: str) -> str:
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'(?m)//.*$', '', text)
    return text


def feature_files() -> list[Path]:
    return sorted(FEATURES.rglob('*.dart'))


def main() -> None:
    violations: list[str] = []
    details: dict[str, list[str]] = {
        'refresh_button': [],
        'badge_without_icon': [],
        'long_footer': [],
        'page_without_summary': [],
    }
    counts = {key: 0 for key in details}

    for path in feature_files():
        relative = path.relative_to(LIB).as_posix()
        if relative.startswith('features/auth/'):
            # 验证码重载是图像动作，不是数据刷新。
            continue
        code = strip_comments(path.read_text(encoding='utf-8'))

        for match in REFRESH_BUTTON.finditer(code):
            counts['refresh_button'] += 1
            details['refresh_button'].append(
                f'{relative}: 卡片内刷新动作；刷新属于导航栏或下拉刷新'
            )
        for match in REFRESH_LABEL.finditer(code):
            counts['refresh_button'] += 1
            details['refresh_button'].append(
                f'{relative}: 卡片内查询动作；查询属于导航栏'
            )
        for match in BADGE_CALL.finditer(code):
            if 'icon' not in match.group(0):
                counts['badge_without_icon'] += 1
                details['badge_without_icon'].append(
                    f'{relative}: 状态标签缺少图标；状态 = 文案 + 颜色 + 图标'
                )
        # 设置页是说明性表面：那里的长文案就是页面内容，不受数据页口径
        # 一行的限制。
        in_settings = relative.startswith('features/settings/')
        for match in LONG_FOOTER.finditer(code):
            if in_settings:
                continue
            text = match.group(1)
            if '\\n' not in text and len(text) <= FOOTER_LIMIT:
                continue
            counts['long_footer'] += 1
            details['long_footer'].append(
                f'{relative}: 说明区超过一行；长说明收进详情或口径行'
            )

        if path.name.endswith('_page.dart') and path.name not in SUMMARY_EXEMPT:
            folder = path.parent
            feature_code = strip_comments(
                '\n'.join(
                    item.read_text(encoding='utf-8')
                    for item in sorted(folder.glob('*.dart'))
                )
            )
            if not any(token in feature_code for token in SUMMARY_TOKENS):
                counts['page_without_summary'] += 1
                details['page_without_summary'].append(
                    f'{relative}: 页面没有汇总层；每页要能回答"现在是什么情况"'
                )

    catalog = strip_comments(
        (LIB / 'workspace' / 'workspace_catalog.dart').read_text(encoding='utf-8')
    )
    tabs = len(re.findall(r'mobileTab:\s*\d+', catalog))
    if tabs != 5:
        violations.append(
            f'workspace/workspace_catalog.dart: 移动标签数 {tabs}；一级标签固定 5 个'
        )
    if "id: 'more'" not in catalog:
        violations.append(
            'workspace/workspace_catalog.dart: 缺少「更多」目的地；其余功能不得藏在页面底部'
        )

    print('ui language (deviations from the shared Apple interaction rules):')
    for key, value in counts.items():
        print(f'  {key:<24}{value:>4}')
    if '--report' in sys.argv:
        return
    exceeded = [key for key, value in counts.items() if value > BUDGET.get(key, 0)]
    if exceeded:
        lines = [
            'ui language deviations grew: '
            + ', '.join(f'{key} {counts[key]}>{BUDGET.get(key, 0)}' for key in exceeded)
        ]
        for key in exceeded:
            lines.extend(details[key])
        raise SystemExit(
            '\n'.join(lines)
            + '\nrestore the native interaction language; see docs/UI-DESIGN.md'
            + '\n(if a count dropped, lower the budget in scripts/check-ui-language.py)'
        )


if __name__ == '__main__':
    main()

# Flutter 功能域：finance

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/finance/` 的页面、域内组件与模型。

## features/finance/finance_page.dart

- `class FinancePage extends StatefulWidget`
  <sub>class · features/finance/finance_page.dart:18</sub>
    - `const FinancePage({super.key, this.gateway});`  <sub>:19</sub>
    - `State<FinancePage> createState() => …`  <sub>:24</sub>

## features/finance/finance_visuals.dart

- `String formatCompactYuan(int minor) {…}`
  <sub>function · features/finance/finance_visuals.dart:9</sub>
- `class FinanceInstrumentPanel extends StatelessWidget` — Top instrument panel for [FinancePage]:
  <sub>class · features/finance/finance_visuals.dart:32</sub>
    - `const FinanceInstrumentPanel({ super.key, required this.supported, required this.busy, required this.data, required this.failure, required this.showAmounts, });`  <sub>:33</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:49</sub>

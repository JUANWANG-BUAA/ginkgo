# Flutter 功能域：network_account

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/network_account/` 的页面、域内组件与模型。

## features/network_account/network_account_page.dart

- `class NetworkAccountPage extends StatefulWidget`
  <sub>class · features/network_account/network_account_page.dart:20</sub>
    - `const NetworkAccountPage({super.key, this.gateway, this.officialLinks});`  <sub>:21</sub>
    - `State<NetworkAccountPage> createState() => …`  <sub>:27</sub>

## features/network_account/network_account_visuals.dart

- `double? parseTrafficBytesForChart(String raw) {…}` — Pure presentation parser converting human traffic text (e.g. `12.5G`, `512M`, `0`)
  <sub>function · features/network_account/network_account_visuals.dart:11</sub>
- `String formatTrafficScaleTick(double bytes) {…}`
  <sub>function · features/network_account/network_account_visuals.dart:31</sub>
- `String formatTrafficTotal(double bytes) {…}`
  <sub>function · features/network_account/network_account_visuals.dart:48</sub>
- `class NetworkAccountInstrumentPanel extends StatelessWidget` — Top instrument panel for [NetworkAccountPage]: renders a 3D glass liquid
  <sub>class · features/network_account/network_account_visuals.dart:63</sub>
    - `const NetworkAccountInstrumentPanel({ super.key, required this.supported, required this.busy, required this.data, required this.failure, required this.selectedProduct, required this.onSelectProduct, });`  <sub>:64</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:82</sub>

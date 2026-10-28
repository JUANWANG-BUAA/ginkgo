# 应用外壳组件（flutter/lib/app）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
CupertinoApp 组合与主题桥接。

## app/ginkgo_app.dart

- `Widget ginkgoApp({ required Widget home, Brightness? brightness, AppPreferences? preferences, StartupUpdateController? startupUpdate, }) {…}`
  <sub>function · app/ginkgo_app.dart:10</sub>

## main.dart

- `Future<void> main() async {…}`
  <sub>function · main.dart:23</sub>
- `class GinkgoRoot extends StatefulWidget` — Chooses between the real-account session and the explicit offline demo.
  <sub>class · main.dart:56</sub>
    - `const GinkgoRoot({ super.key, this.liveService = const NativeMirrorService(), this.demoService = const DemoMirrorService(), this.loadUpdateGate, this.startupUpdates, this.challengeGateway, });`  <sub>:57</sub>
    - `final Future<UpdateGate?> Function()? loadUpdateGate;` — 启动时读取最低版本清单；测试与离线场景传 null 即跳过门禁。  <sub>:73</sub>
    - `State<GinkgoRoot> createState() => …`  <sub>:75</sub>

## startup_page.dart

- `class StartupPage extends StatefulWidget` — 冷启动画面：一枚银杏叶在纸感底色上展开，随后出现字标与细进度线。
  <sub>class · startup_page.dart:11</sub>
    - `const StartupPage({super.key});`  <sub>:12</sub>
    - `State<StartupPage> createState() => …`  <sub>:15</sub>

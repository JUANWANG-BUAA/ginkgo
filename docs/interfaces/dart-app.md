# 应用外壳组件（flutter/lib/app）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

CupertinoApp 组合与主题桥接。

## main.dart

- `class GinkgoRoot extends StatefulWidget` — Chooses between the real-account session and the explicit offline demo.  
  <sub>class · main.dart:54</sub>
    - `const GinkgoRoot( {…}`  <sub>:55</sub>
    - `final Future<UpdateGate?> Function()? loadUpdateGate;` — 启动时读取最低版本清单；测试与离线场景传 null 即跳过门禁。  <sub>:71</sub>
    - `State<GinkgoRoot> createState() => _GinkgoRootState();`  <sub>:73</sub>

## startup_page.dart

- `class StartupPage extends StatelessWidget` — A single, quiet entrance while restoration runs; never delays navigation.  
  <sub>class · startup_page.dart:7</sub>
    - `const StartupPage( {…}`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:11</sub>

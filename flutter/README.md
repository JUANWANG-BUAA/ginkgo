# Ginkgo Rust + Flutter mirror

Android 对齐 iPhone SwiftUI，Windows 对齐 macOS SwiftUI。Apple 应用保持独立。

当前手机入口为工作台 / 签到 / 课表 / 作业 / 预约，宽屏切换桌面侧栏；各目的地保留独立导航。认证、主要只读模块、Android Keystore、Windows Credential Manager、离线演示和本地待办已接入；签到及图书馆实验写路径包含确认、单次提交与回查，真实写入未验收。Android 与 Windows Alpha.4 均已发布，最近实网登录失败仍需复验。Windows 主推未签名 x64 单文件安装器，同时保留需完整解压的便携 ZIP；物理 x64、干净系统运行依赖和真实学校业务仍待验收。范围见 [实施现状](../docs/MIRROR-IMPLEMENTATION.md)、[Windows Alpha.4](../docs/archive/mirror/MIRROR-WINDOWS-ALPHA4.md)、[模块对照](../docs/MIRROR-PARITY.md) 和 [待办](../docs/MIRROR-TODO.md)。

## 工具链

先检查本地工具和缓存，再安装缺项。当前固定基线：

| 工具 | 版本 |
| --- | --- |
| Flutter / Dart | 3.47.0 / 3.13.0 |
| Rust | 1.99.0 |
| Flutter Rust Bridge（Rust、Dart、生成器一致） | 2.12.0 |
| cargo-expand（生成绑定需要） | 1.0.127 |
| Android SDK / Build Tools | 36 / 36.0.0 |
| Android NDK | 27.0.12077973 |
| Gradle / AGP / Kotlin | 9.4.1 / 9.1.0 / 2.3.20 |

`../rust/rust-toolchain.toml` 和本目录 `.fvmrc` 固定版本；Cargo 和 Dart 锁文件入库。升级时同时更新 CI、工具链文件、Cargokit 的版本选择、依赖锁及本文，并重新执行两端验收。

Android Studio 打开本目录；Windows 需要 Visual Studio C++ 桌面工具链。Windows PowerShell 5.1 路径回归用 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-mirror-windows-paths.ps1`（仓库根目录）。Parallels 共享目录只用于复制源码，构建放在来宾本地 NTFS，具体环境与本轮结果见 [Windows 验证](../docs/archive/mirror/WINDOWS-2026-10-21.md)。Flutter 的 Android `local.properties` 由本机生成，不入库。

## 运行

```sh
# 在仓库根目录检查和重新生成绑定
scripts/check-mirror.sh
scripts/generate-mirror-bridge.sh

cd flutter
flutter pub get
flutter devices
flutter run -d emulator-5554
# 平台保险库 JNI/Keystore 往返 + 登录页启动（不提交真实账号）
flutter test integration_test/auth_test.dart -d emulator-5554
flutter test integration_test/today_test.dart -d emulator-5554
flutter test integration_test/mirror_test.dart -d emulator-5554

# Windows 主机
flutter run -d windows
flutter test integration_test/windows_test.dart -d windows
```

Rust Android 目标随选定设备确定；当前 ARM64 模拟器使用 `aarch64-linux-android`。安装缺失目标前可用 `rustup target list --installed` 检查。

## 边界

- `lib/src/rust/` 与 Rust `frb_generated.rs` 是生成物；改 `rust/crates/ginkgo_flutter_bridge/src/api/` 后运行生成脚本。生成结果的 `stem` 必须是 `ginkgo_flutter_bridge`，脚本会拒绝 `UNKNOWN`。
- Dart 只保存页面选择、导航和呈现状态；图书馆共享快照、请求合并和写后回查集中在 `LibraryController`，状态色集中在 `AppleDesign.status*`。学校日期、教室节次解析、过滤/排序、缓存 TTL、课表周次与认证会话都在 Rust。真实服务只在第一次异步命令时创建网络运行时；不要在 `init_app` 预热，否则 Android 会卡启动。
- `application/mirror_service.dart` 定义按功能拆分的 gateway，`mirror_service.dart` 保留兼容导出与默认组装；`infrastructure/` 实现真实/演示适配。页面只导入 `application/contracts.dart` 的值类型，不调用生成函数。`mirror_service.dart` 是页面测试注入点：`NativeMirrorService` 走真实 bridge，`DemoMirrorService` 走 `load_demo_*`。`auth_test.dart` 只写入并删除 `__ginkgo_vault_test__` 前缀的合成密钥，不需要真实账号。
- 设备上的 `mirror_test.dart` 仍有一个校区/日期/缓存长流程未收敛；`today/schedule/grades/homework` 与 `auth_test.dart` 可分别独立验收，不要用一个长文件的失败/通过替代模块结论。
- `flutter test integration_test/...` 会把**测试入口**打包进 `build/app/outputs/flutter-apk/app-debug.apk`；直接安装并启动这个 APK 会停在 Flutter 启动页等待测试驱动。要看真实登录页/演示页，必须重新运行 `flutter build apk` 再安装。
- 演示仓库仅保留进程内合成查询元数据，不读取 Swift 缓存，不保存账号。学院路/沙河分别使用共享样例中的两组房间，杭州为空；日期参与缓存隔离，不代表当天真实学校安排。
- Windows 本轮结果来自 Parallels Windows 11 ARM 中运行的 x64 工具链，具体通过项与剩余验收见主机记录；宿主 macOS 的构建结果不替代 Windows。

## Vendored Cargokit

独立 build_tool Dart 包需先解析依赖，冷目录的全量分析前执行 `(cd rust_builder/cargokit/build_tool && dart pub get)`；`scripts/check-mirror.sh` 与 CI 已包含此步。产品构建会由 Cargokit 自行准备工具，不能用本机已有缓存推断冷环境分析通过。

来自 FRB 2.12.0 官方 `integrate` 模板，保留 MIT 许可。为本工程做了有限适配：

1. Gradle 9 使用注入的 `ExecOperations`。
2. 只构建 Flutter 选中的架构，不额外下载 x86 目标。
3. 固定 Rust 1.99.0，同时复用版本相同的已安装 stable；跳过无关的损坏工具链。
4. 识别含正确 `source.properties` 和 Clang 的官方 NDK ZIP 安装。
5. 构建工具优先从本地 Pub 缓存解析，缺项时才联网。

更新 FRB/Cargokit 时逐项核对上述差异，不直接覆盖本地适配。

目录职责与自动边界检查见 [Rust / Flutter 工程边界](../docs/MIRROR-ARCHITECTURE.md)。

学校协议与会话实现已独立到 `ginkgo_upstream`；core 只消费 domain 中的业务端口，`ginkgo_runtime` 负责真实客户端与保险库的组装。学校响应 fixture 的解析不再进入 FFI API。独立验证和更新位置见上述工程边界文档。

作业详情的官网入口由上游通过可空 `sourceUrl` 返回，页面只校验通用 HTTPS URI。本轮同时移除了未使用的 FFI 命令，Rust 动态库与 Dart 生成绑定需配套构建，不能混用旧版本。

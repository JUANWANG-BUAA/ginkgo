# Ginkgo Rust + Flutter mirror

Android 对齐 iPhone SwiftUI，Windows 对齐 macOS SwiftUI。Apple 应用保持独立。

当前实现包含登录页、会话恢复门禁、显式离线演示，以及空教室/课表/今天/成绩的真实只读页面；作业仍是合成切片。Android Keystore 保险库、FRB 真实会话和 mock 只读链路已接入；真实账号只读验收、Windows 实机和写操作尚未完成。阶段状态与验收矩阵见 [实施记录](../docs/MIRROR-IMPLEMENTATION.md)。

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

Android Studio 打开本目录；Windows 需要 Visual Studio C++ 桌面工具链。Flutter 的 Android `local.properties` 由本机生成，不入库。

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
flutter test integration_test/mirror_test.dart -d windows
```

Rust Android 目标随选定设备确定；当前 ARM64 模拟器使用 `aarch64-linux-android`。安装缺失目标前可用 `rustup target list --installed` 检查。

## 边界

- `lib/src/rust/` 与 Rust `frb_generated.rs` 是生成物；改 `rust/crates/ginkgo_flutter_bridge/src/api/` 后运行生成脚本。生成结果的 `stem` 必须是 `ginkgo_flutter_bridge`，脚本会拒绝 `UNKNOWN`。
- Dart 只保存页面选择、导航和加载状态。学校日期、教室节次解析、过滤/排序、缓存 TTL、课表周次与认证会话都在 Rust。真实服务只在第一次异步命令时创建网络运行时；不要在 `init_app` 预热，否则 Android 会卡启动。
- `mirror_service.dart` 是页面测试注入点：`NativeMirrorService` 走真实 bridge，`DemoMirrorService` 走 `load_demo_*`。`auth_test.dart` 只写入并删除 `__ginkgo_vault_test__` 前缀的合成密钥，不需要真实账号。
- 设备上的 `mirror_test.dart` 仍有一个校区/日期/缓存长流程未收敛；`today/schedule/grades/homework` 与 `auth_test.dart` 可分别独立验收，不要用一个长文件的失败/通过替代模块结论。
- `flutter test integration_test/...` 会把**测试入口**打包进 `build/app/outputs/flutter-apk/app-debug.apk`；直接安装并启动这个 APK 会停在 Flutter 启动页等待测试驱动。要看真实登录页/演示页，必须重新运行 `flutter build apk` 再安装。
- 演示仓库仅保留进程内合成查询元数据，不读取 Swift 缓存，不保存账号。学院路/沙河分别使用共享样例中的两组房间，杭州为空；日期参与缓存隔离，不代表当天真实学校安排。
- 当前 Windows 提供工程及 CI 入口，本机 macOS 不作为 Windows 构建/运行验收环境。

## Vendored Cargokit

来自 FRB 2.12.0 官方 `integrate` 模板，保留 MIT 许可。为本工程做了有限适配：

1. Gradle 9 使用注入的 `ExecOperations`。
2. 只构建 Flutter 选中的架构，不额外下载 x86 目标。
3. 固定 Rust 1.99.0，同时复用版本相同的已安装 stable；跳过无关的损坏工具链。
4. 识别含正确 `source.properties` 和 Clang 的官方 NDK ZIP 安装。
5. 构建工具优先从本地 Pub 缓存解析，缺项时才联网。

更新 FRB/Cargokit 时逐项核对上述差异，不直接覆盖本地适配。

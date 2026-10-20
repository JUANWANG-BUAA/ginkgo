# Ginkgo Rust + Flutter mirror

Android 对齐 iPhone SwiftUI，Windows 对齐 macOS SwiftUI。Apple 应用保持独立。

当前实现是**离线合成数据切片**：空教室查询交互、筛选/排序、详情，以及北京时间/课表缓存周次示例。未接入 CAS、真实学校查询或上游写操作。阶段状态和验收矩阵见 [实施记录](../docs/MIRROR-IMPLEMENTATION.md)。

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
flutter test integration_test/mirror_test.dart -d emulator-5554

# Windows 主机
flutter run -d windows
flutter test integration_test/mirror_test.dart -d windows
```

Rust Android 目标随选定设备确定；当前 ARM64 模拟器使用 `aarch64-linux-android`。安装缺失目标前可用 `rustup target list --installed` 检查。

## 边界

- `lib/src/rust/` 与 Rust `frb_generated.rs` 是生成物；改 `rust/crates/ginkgo_flutter_bridge/src/api/` 后运行生成脚本。
- Dart 只保存页面选择、导航和加载状态。学校日期、教室节次解析、过滤/排序、缓存 TTL 与课表周次保留都在 Rust。
- `mirror_service.dart` 是页面测试注入点。设备集成测试调用真实 Rust 动态库；错误测试通过无效 typed 请求产生真实 Rust 错误码。
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

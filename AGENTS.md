# Ginkgo 仓库指南

## 1. 项目概述与当前主线

Ginkgo（BUAA Assistant，北航校园工作台）是北航校园服务聚合客户端，覆盖工作台、课表与考试、成绩、研究生教务、SPOC 作业、博雅、图书馆座位与公开书目、教学楼研讨室（CGYY）、空教室、课程签到、本机待办、校园通知和校车时刻表等能力；各平台支持范围并不完全相同。

- **当前主开发平台是 Android**，使用 Flutter + Rust，优先交付用户可感知的功能与体验改进，同时补齐异步、缓存、账号隔离和失败态回归。
- **当前唯一开发目标是 Android**（Flutter + Rust）。`docs/MULTI-PLATFORM-STRATEGY.md` 记录了这一决策。
- **Windows 与 Android 共用同一 Flutter 工程**：不做功能开发，但共享代码改动必须保持 Windows 可编译（`mirror.yml` 的 windows job 会验证）。
- **macOS / iOS 的 Swift/SwiftUI 应用暂时冻结**：不再做功能开发、不再做跨端对齐、不再为其排期。只在影响 Android 构建、共享 fixture 或存在安全问题时被动修。公共契约变化不必顾虑 Apple 端。
- 2026-10-24 的全方位工程 / 设计 / UI 评审与 Android-only 重排见 [`docs/_audit/2026-10-24-comprehensive-review.md`](docs/_audit/2026-10-24-comprehensive-review.md)；其中的 P0/P1 顺序是当前待办排序的依据。
- 应用没有项目自建中转服务器。学校请求在设备进程内直连北航系统，或经北航官方 WebVPN；Rust 不是独立后端服务。
- 当前公开基线为 Android Alpha.7（`0.1.0-alpha.7+8`）和 Windows Alpha.6。`flutter/pubspec.yaml` 的版本号不能证明工作树中的后续改动已经发布；公开内容以对应 tag、Release 和发布记录为准。
- 当前工作树已移除作业详情“加入个人待办”入口。保留既有本机记录，不要根据历史迭代文档重新添加该入口。
- 未完成任务只维护在 `docs/MIRROR-TODO.md`，当前顺序为 P0 可复现回归与安全边界、P1 设备/账号验收及小步体验、P2 扩展。不要另建重复 TODO 清单。

开始改动前，按范围阅读：

- Android / Windows：`flutter/README.md`、`docs/ANDROID-DEVELOPMENT.md`、`docs/MIRROR-ARCHITECTURE.md`、`docs/MIRROR-IMPLEMENTATION.md`。
- Apple（**已冻结**，仅在被动修时参考）：`docs/ARCHITECTURE.md`、`docs/IOS.md`、`docs/TESTING.md`。其中历史设计和目标结构不能直接当作当前实现。
- 学校接口：`docs/API.md` 是唯一协议事实源；功能与客户端契约索引见 `docs/FEATURES-AND-PROTOCOLS.md`。

## 2. 技术栈与运行时架构

| 平台 | UI / 应用壳 | 本地业务与网络 | 主要工具链 |
| --- | --- | --- | --- |
| Android | Flutter，正常入口 `flutter/lib/main.dart` | 进程内 Rust，经 Flutter Rust Bridge 调用 | Flutter 3.47.0 / Dart 3.13.0、Rust 1.99.0、FRB 2.12.0、Android SDK 36、NDK 28.2.13676358、JDK 17 |
| Windows | 同一 Flutter 工作区，宽屏侧栏、窄屏底部导航 | 同一 Rust workspace；Windows Credential Manager | Flutter + Rust + Visual Studio C++ 桌面工具链 |
| macOS | SwiftUI，侧栏与菜单栏应用 | Swift 客户端、Repository / ViewModel、本地 Codable 缓存 | Xcode 16+，macOS 14+ |
| iOS | 独立原生 SwiftUI 壳，iPhone / iPad 自适应 | 复用 Apple 共享源码 | XcodeGen 2.46+，iOS 17+ |

Flutter / Dart 与 Rust 的锁文件均入库。Android Gradle 使用 AGP 9.1.0、Kotlin 2.3.20；`flutter/android/` 的 `local.properties` 是本机生成文件，不入库。FRB 的 Rust、Dart 和生成器版本必须一致。

### Flutter + Rust 调用链

```text
Flutter 页面
  → application/mirror_service.dart 中按功能拆分的 gateway
  → infrastructure 中 NativeMirrorService 或 DemoMirrorService
  → FRB 生成绑定
  → ginkgo_flutter_bridge 的 DTO / 命令映射
  → ginkgo_runtime 组装
  → ginkgo_core 应用规则 + ginkgo_upstream 学校实现
```

Rust workspace 位于 `rust/`，依赖方向必须保持：

| crate | 职责 | 允许依赖的本项目 crate |
| --- | --- | --- |
| `ginkgo_domain` | 值类型、纯规则、按功能拆分的业务端口与结果 | 无 |
| `ginkgo_core` | `Workspace<U>` 应用命令、业务投影、账号隔离的本机待办 | domain |
| `ginkgo_upstream` | CAS、Cookie、直连/WebVPN、HTTP、学校响应解析、业务 token、会话恢复与查询快照 | domain |
| `ginkgo_runtime` | 真实/演示适配与平台保险库组装，惰性初始化 | core、upstream |
| `ginkgo_flutter_bridge` | FFI DTO、粗粒度命令和应用命令排他 | core、runtime |

关键运行约束：

- 学校 URL、表单、Cookie、token、成功码和响应字段只属于 upstream；core 不得接触 HTTP 或学校协议。
- 页面只消费 `application/contracts.dart` 的值类型，不解析学校响应、不读取 token、不直接调用生成函数。
- Dart 保存导航、页面选择和呈现状态；学校日期、稳定业务规则、缓存 TTL、认证会话等留在 Rust。展示层可以做纯呈现排序。
- 真实网络运行时只在第一次异步命令需要时创建；不要在 `init_app` 预热，以免阻塞 Android 启动。
- 成功空结果可以覆盖旧数据；失败保留旧快照和原成功时间，不延长 TTL。旧响应不得写回新账号或新查询。
- `workspace_catalog.dart` 是移动标签、桌面侧栏和快捷入口的静态登记点；`main.dart` 管启动/登录状态，`workspace_shell.dart` 管布局。它不是运行时插件系统。
- 演示服务使用合成数据，不读取真实账号或 Apple 缓存。平台凭据分别使用 Android Keystore、Windows Credential Manager 和 Apple Keychain。

### Apple 结构（已冻结）

> 本节仅用于理解历史实现与共享 fixture。**不做 Apple 功能开发**，除被动修复构建 / 安全 / 共享契约问题外不在此投入。Android 端的对应决策见 [`docs/_audit/2026-10-24-comprehensive-review.md`](docs/_audit/2026-10-24-comprehensive-review.md)。

`BUAA-Assistant/` 根目录是 macOS 应用壳；`Features/` 按 Auth、Today、Schedule、Grade、Graduate、Homework、BYKC、Library、Venue、Campus、Classroom、CheckIn、Tasks、Settings 分模块；`Core/` 包含 Network、Storage、Parsing、Crypto、Time、Logging、Notification、Update、UI 等共享能力。

iOS 壳和原生页面在 `BUAA-Assistant-iOS/Sources/`，通过 target membership 复用共享 Swift 源码。多数功能以 Repository 隔离客户端、缓存和 ViewModel；不要把 `docs/ARCHITECTURE.md` 中标注的目标结构或历史 SwiftData 示例当成现状。

## 3. 目录与关键配置

| 路径 | 内容 |
| --- | --- |
| `flutter/lib/` | Flutter 页面、呈现组件、应用 gateway 与平台适配 |
| `flutter/lib/application/` | 页面契约、功能 gateway、局部应用状态 |
| `flutter/lib/infrastructure/` | native / demo 服务、运行时和维护服务实现 |
| `flutter/lib/src/rust/` | FRB 生成的 Dart 绑定，不手改 |
| `flutter/test/` | Dart 单元与 widget 测试 |
| `flutter/integration_test/` | 设备集成、Windows 集成及显式启用的真实网络验收 |
| `flutter/android/`、`flutter/windows/` | 各平台 Flutter runner 与构建配置 |
| `flutter/rust_builder/` | Rust 构建封装及 vendored Cargokit |
| `rust/crates/` | 五个 Rust crate |
| `fixtures/` | Rust / Swift 共享的合成或脱敏契约样例 |
| `BUAA-Assistant/` | Apple 共享源码及 macOS 壳 |
| `BUAA-Assistant-iOS/` | iOS 壳、资源、XcodeGen spec、UI 测试 |
| `BUAA-AssistantTests/` | macOS / iOS 共享 XCTest |
| `packaging/windows/` | Inno Setup 安装器配置 |
| `scripts/` | 架构防回退、FRB 生成和 Windows 路径检查 |
| `docs/` | 协议、架构、实现状态、验收和发布记录 |
| `.github/workflows/` | Apple / mirror CI 与 macOS、Windows 发布流程 |

主要配置文件：

- `flutter/pubspec.yaml`、`flutter/pubspec.lock`：Flutter 包、版本和依赖。
- `flutter/.fvmrc`：Flutter 版本；`flutter/analysis_options.yaml`：`flutter_lints`。
- `flutter/flutter_rust_bridge.yaml`：FRB 输入与输出位置。
- `flutter/android/*.gradle.kts`：Android 插件、NDK、签名和应用配置。
- `rust/Cargo.toml`、`rust/Cargo.lock`、`rust/rust-toolchain.toml`：workspace、锁文件和 Rust 工具链。
- `BUAA-Assistant.xcodeproj/`：Xcode 管理的 macOS 工程。
- `BUAA-Assistant-iOS/project.yml`：iOS 工程的生成源；`BUAA-Assistant.entitlements`：macOS 沙箱与网络权限。
- `docs/update-gate.json`：最低 build 门禁，拉取失败或内容异常时放行。

仓库没有 Node.js 或 Python 应用清单；Python 用于 `scripts/` 中的检查工具，不是应用运行时。不要凭常见技术栈额外假设依赖。

## 4. 构建、运行与生成

### Rust / Flutter 基线

在仓库根目录执行完整本地门禁：

```sh
bash scripts/check-mirror.sh
```

该脚本会解析依赖，不是纯离线检查；依次执行架构规则及其自测、`cargo fmt --check`、严格 Clippy、core / upstream / workspace 测试、Cargokit 独立分析依赖解析、`flutter analyze` 和 `flutter test test`。只改 Flutter 或 Rust 时，也应运行此基线，不要只验证能编译。

独立分层检查：

```sh
cargo test --manifest-path rust/Cargo.toml -p ginkgo_core --no-default-features --locked
cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked
```

只有 `rust/crates/ginkgo_flutter_bridge/src/api/` 的桥接 API 变化时才重新生成：

```sh
bash scripts/generate-mirror-bridge.sh
git diff -- flutter/lib/src/rust rust/crates/ginkgo_flutter_bridge/src/frb_generated.rs
```

生成器需为 `flutter_rust_bridge_codegen 2.12.0`，生成绑定还需要 `cargo-expand 1.0.127`。不得手改 `flutter/lib/src/rust/` 或 Rust `frb_generated.rs`；Rust 动态库与 Dart 绑定必须配套构建，生成结果的库 stem 不得为 `UNKNOWN`。

Vendored Cargokit 来自 FRB 模板但有本项目适配。冷目录全量分析前需解析其独立 Dart 包；完整基线和 CI 已执行：

```sh
cd flutter/rust_builder/cargokit/build_tool
dart pub get
```

更新 FRB / Cargokit 时逐项保留 `flutter/README.md` 记录的本地适配，不能直接覆盖模板。

### Android

```sh
cd flutter
flutter pub get
flutter devices
flutter run -d emulator-5554
flutter build apk --debug --target-platform android-arm64 --target lib/main.dart
```

ARM64 设备对应 Rust target `aarch64-linux-android`。发布构建使用正常 main 入口；外部签名配置通过 `GINKGO_ANDROID_SIGNING_PROPERTIES` 指定，Release 任务缺少配置会失败，绝不可回退到 Debug 签名：

```sh
flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub
```

`integration_test` 会把自己的测试入口打进 `build/app/outputs/flutter-apk/app-debug.apk`。设备测试后若要安装正常应用，必须重新执行 `flutter build apk ... --target lib/main.dart`，不能安装停留在测试驱动等待页的包。

### Windows

以下命令必须在 Windows 主机运行；macOS 结果不能代替 Windows 验收。仓库根的路径回归使用 Windows PowerShell 5.1：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-mirror-windows-paths.ps1
cd flutter
flutter run -d windows
flutter build windows --debug --target lib/main.dart
flutter build windows --release --target lib/main.dart
```

Parallels 共享目录只用于复制源码，实际构建放在来宾本地 NTFS。便携 ZIP 必须完整解压，不能只复制 exe。

### Apple（已冻结）

> 仅在被动修复构建 / 安全 / 共享契约问题时使用本节命令。日常开发走上面的 Rust / Flutter 基线。

从仓库根执行：

```sh
xcodebuild build -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet

xcodebuild build -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet
xcrun simctl list devices available
xcodebuild test -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'platform=iOS Simulator,id=<可用设备UDID>' -quiet
```

iOS 模拟器测试需要已安装的 Simulator Runtime；generic-device build 不能代替模拟器或真机验收。iOS 工程由 spec 生成：

```sh
cd BUAA-Assistant-iOS
xcodegen generate --spec project.yml
```

不要手改 iOS 生成的 `.xcodeproj`。macOS 工程仍由 Xcode 管理，AI 不手改 `project.pbxproj`；需要 target / entitlement 变化时说明维护者操作。无签名命令行产物仅用于编译和测试，本地运行、签名与图标注意事项见 `docs/SIGNING.md`。

收尾统一执行 `git diff --check`。

## 5. 测试策略与验收边界

### 自动化分层

- **Rust**：domain/core 用最小合成端口验证应用规则；upstream 用合成请求/响应验证认证、路由、会话恢复、缓存、请求次数和写入分类。测试不访问真实账号。
- **Flutter**：`flutter/test/` 注入 gateway fake 覆盖页面、导航、异步状态和业务呈现；`flutter/integration_test/` 验证设备上的 Rust bridge、平台保险库和系统交互。
- **Swift**：`BUAA-AssistantTests/` 使用 XCTest、`@testable import BUAA_Assistant`、合成 fixture 和 `URLProtocol` mock；iOS 复用共享测试，`BUAA-Assistant-iOS/UITests/` 覆盖原生 UI 冒烟。
- **共享契约**：`fixtures/` 的 JSON 具有 `contract`、`version`、`source`、`input`、`expected` 信封；Rust runner 递归消费全部文件，未知契约失败。Swift 只覆盖 `fixtures/README.md` 列出的子集，不能宣称全部模块已双端一致。
- 修复 bug 应添加能抓住原问题的回归测试；覆盖成功空结果、结构漂移、业务拒绝、认证失效、账号切换、旧数据迁移和迟到响应，而不只覆盖 happy path。

常用设备测试：

```sh
cd flutter
flutter test integration_test/auth_test.dart -d emulator-5554
flutter test integration_test/today_test.dart -d emulator-5554
flutter test integration_test/mirror_test.dart -d emulator-5554
flutter test integration_test/windows_test.dart -d windows  # 仅 Windows
```

`auth_test.dart` 只写入并删除 `__ginkgo_vault_test__` 前缀的合成密钥。`mirror_test.dart` 仍有校区/日期/缓存长流程未收敛记录；模块应分别验收，不能用一个长文件的通过或失败替代全部结论。

真实网络 / 账号测试默认跳过，需分别通过 `GINKGO_MANUAL_LIVE_NETWORK` 或 `GINKGO_LIVE_ACCEPTANCE` 显式启用；iOS live UI 从模拟器进程环境读取 `GINKGO_LIVE_USERNAME` / `GINKGO_LIVE_PASSWORD`。未经授权不得使用真实凭据；只读授权不包含学校写操作。

自动化、模拟器、正常入口构建、物理设备、真实账号只读、真实写入和签名分发是不同证据。分别记录环境、日期、结果和未覆盖范围，不把 Mock 或 CI 通过写成“真实业务已验收”。历史测试数量只属于当次运行，稳定文档不要维护随提交变化的总数。

## 6. 编码与模块改动约定

### Rust / Flutter

- Rust 使用 workspace 标准风格，必须通过 `cargo fmt` 和 `clippy -D warnings`；同步锁不得跨 `await`。
- Dart 使用既有 `lowerCamelCase` API、`snake_case` 文件名和 `flutter_lints`；沿用当前状态管理方式，不为换皮引入全局状态框架。
- 新增功能的顺序：domain 值类型与最小端口 → upstream adapter / codec / service → core 应用命令与测试 → bridge DTO / 命令及 FRB 生成 → Flutter gateway、native/demo adapter、页面与 `workspace_catalog.dart` 登记。
- 仅改已有学校协议时，通常只改 upstream、协议 fixture 与 `docs/API.md`，不要为了“统一”把学校成功码抽象成通用常量。
- 页面复杂异步状态参考 `LibraryController` 和 `application/refresh_section.dart`：重叠读取合流、刷新保留旧内容、局部失败可重试、账号或服务代次变化后丢弃旧状态。
- UI 遵循 Android 系统返回、键盘、安全区、至少 48dp 触控目标、大字号、TalkBack 和减少动态效果；加载、确认空、失败、旧缓存和部分成功要区分，不用未知伪造零值或进度。
- 状态色复用 `AppleDesign.status*`，颜色之外保留文字；大量记录复用 `CollectionWindow` / `CollectionToolbar`，本地分页不代表学校服务端分页。
- 检索、统计和生成差异审查排除 FRB 生成物，不用生成代码规模或 `setState` / `Semantics` 出现次数代替质量判断。

### Swift / Apple 工程（已冻结）

> 仅供被动修复时参考；不做功能开发，不为 Apple 新建类型或能力。

- 沿用两空格缩进、`UpperCamelCase` 类型、`lowerCamelCase` 成员，文件按主类型命名；UI 状态放在 `@MainActor`，解析与网络、呈现分离。
- 功能客户端、模型、解析器、Repository、ViewModel 和视图放在对应 `Features/<模块>/`，共享基础能力放 `Core/`。
- 网络测试和实现使用 `UpstreamRoutePreference` 的自动 / 直连 / WebVPN 抽象，不在各功能客户端散落硬编码网关路由。
- 当前没有额外 Swift formatter / linter 配置；以现有代码和 Xcode / XCTest 为准。

## 7. 安全、隐私与上游写操作

- 永不提交真实学号、姓名、手机号、密码、Cookie、票据、原始 HAR、个人课表/成绩/订单、未打码截图或日志。示例使用 `sy2501001`、`李文` 等合成值。
- 密码只在用户选择“记住密码”后写平台保险库；Cookie、token 和学校响应不得进入日志或普通明文偏好。账号摘要只用于隔离，不是加密。
- 不改弱 TLS，不绕过认证或风控，不做批量请求。认证、保险库、日志、TLS、网络权限和 entitlements 变更须按 `docs/COLLABORATION.md` 人工审查。
- 新协议断言必须有 `docs/API.md` 的证据；不确定就标为待验证。协议修正要更新证据及修订对照表，原始 HAR 不入库，审计记录放 `docs/_audit/YYYY-MM-DD-<主题>.md`。
- 学校写操作必须由用户明确触发和确认，单次提交并回查；结果不明禁止自动重发。签到、图书馆和 CGYY 的自动化通过不代表真实写入验收，代理不得自动执行真实提交。
- 本地待办完成不等于学校作业已提交；清除查询缓存不得删除个人待办。持久化格式升级要验证备份、损坏保护、失败不覆盖和账号隔离。
- 缴费、充值、挂失、转账、修改支付密码等资金写操作禁止接入。
- 详细数据位置和清理边界见 `docs/PRIVACY.md`。

## 8. CI、发布与更新

### 持续集成

- `.github/workflows/mirror.yml`：相关路径变化时在 Ubuntu 跑 Rust 契约、FRB 生成差异、Flutter 分析和测试，在 Ubuntu 构建 Android ARM64 Debug，并在 Windows 跑路径检查、构建、widget / Windows 集成测试和正常入口产物检查。
- `.github/workflows/ci.yml`：push / PR 到 `main` 时在 macOS runner 构建并运行完整 macOS XCTest，归档结果并执行 `git diff --check`。
- `.github/workflows/ios.yml`：用 XcodeGen 生成 iOS 工程，做 generic device build，并自动选择可用 iPhone Simulator 跑测试。
- 本地通过不自动等于远端 CI 通过；某平台的结果不能外推到其他平台。

### 发布

- **Android**：当前没有自动 Android Release workflow；按对应发布记录执行签名 ARM64 正常入口构建、产物/摘要/签名校验、覆盖升级和 GitHub prerelease 发布。独立 tag 形式为 `android-v*`。不要把测试/Debug APK 当公开更新资产。
- **Windows**：`windows-v*` tag 触发 `.github/workflows/windows-release.yml`，运行测试、构建 Release、用 Inno Setup 生成并验证单文件安装器，同时发布便携 ZIP 和 SHA-256。当前安装器未签名。`windows-installer.yml` 是特定 Alpha.4 安装器补发流程，不是通用最新发布入口。
- **macOS**：`v*` tag 触发 `.github/workflows/release.yml`，构建 Release，优先使用外部导入的 `Ginkgo Local Signing`，否则 ad-hoc 签名，产出 ZIP、DMG、checksums 和草稿 Release；未配置 Developer ID / 公证。
- **iOS**：仓库只有构建与测试 workflow，没有 TestFlight / App Store 发布流程。
- Android 更新检查读取 GitHub Releases；最低版本门禁读取 `docs/update-gate.json`，失败放行。提升 `minBuild` 前必须确认新版本已可下载，避免锁死旧版本且无法更新。

GitHub Release 正文和应用内更新说明保持 3–5 条简短中文，每条只讲一个用户收益；不堆测试数、架构术语、签名打包过程或验收报告。数据损失、不兼容或安全限制另作明确提醒，不发布未完成能力，不自动改写历史 Release。

## 9. 文档、提交与交付

- `docs/MIRROR-IMPLEMENTATION.md` 记录工作树实现，`docs/MIRROR-PARITY.md` 记录平台差距，`docs/MIRROR-TODO.md` 只记录未完成事项；发布、审计和验收按日期归档，不在多个入口重复维护。
- `docs/ROADMAP.md`、`docs/TESTING.md` 等含历史计划或示例时，以源码和文档中的“当前实现”说明为准，不根据示例创建并不存在的类型或能力。
- 最近提交使用简洁中文主题前缀，如 `功能：…`、`修复：…`、`文档勘误：…`。功能/修复分支使用 `feat/<模块>` / `fix/<问题>`，保持 `main` 可用。
- PR 说明范围、动机、验证命令和结果、未覆盖边界及相关 issue；UI 变化附截图。真实设备、账号和写入结果与自动化结果分开写。
- 交付前检查受影响文档、生成绑定和跨平台消费者是否同步；不要把“工作树已实现”写成“已发布”或“已真实验收”。

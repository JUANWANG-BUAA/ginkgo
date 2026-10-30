# Android Beta.3 Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复阻塞 Beta.3 可信验收的依赖注入与能力替换问题，并形成经过分层验证的 Android 候选版本。

**Architecture:** 页面继续只依赖 application 窄端口，由测试或组合根显式注入；独立能力身份进入页面现有代次控制，不引入新状态框架。验收修复与产品修复分开验证，真实写入和公开发布不在自动执行范围内。

**Tech Stack:** Flutter/Dart 3.13、Rust 1.99、flutter_test、integration_test、Android ARM64。

---

### Task 1: 修复验收页面的显式端口注入

**Files:**
- Modify: `flutter/integration_test/cgyy_test.dart`
- Modify: `flutter/integration_test/academic_learning_ux_test.dart`
- Modify: `flutter/integration_test/live_acceptance_test.dart`

- [x] **Step 1: 在演示测试中复用同一个演示适配器**

```dart
const service = DemoMirrorService();
await tester.pumpWidget(
  ginkgoApp(home: const CgyyPage(demo: true, service: service)),
);
```

研究生页面同时传入：

```dart
GraduatePage(service: service, creditMapGateway: service)
```

- [x] **Step 2: 在真实验收中传入同一个真实读写适配器**

```dart
const CgyyPage(service: service, bookingGateway: service)
```

- [x] **Step 3: 运行静态分析和演示设备测试**

Run: `cd flutter && flutter analyze integration_test/cgyy_test.dart integration_test/academic_learning_ux_test.dart integration_test/live_acceptance_test.dart`
Expected: `No issues found!`

Run: `cd flutter && flutter test integration_test/cgyy_test.dart -d emulator-5554`
Expected: 进入“合成研讨室”，找到时段与预约记录，测试通过；不是因找不到场馆而提前失败。

### Task 2: 用失败回归锁定独立能力替换

**Files:**
- Modify: `flutter/test/read_page_generation_test.dart`
- Modify: `flutter/test/graduate_page_test.dart`
- Modify: `flutter/test/tasks_simplification_widget_test.dart`

- [x] **Step 1: 为研讨室写能力替换添加 Completer 回归**

使用两个 `CgyyBookingGateway` fake，分别返回待完成的 `CgyyWriteGuard`。在旧 guard 未完成时替换 `bookingGateway`，随后完成旧 guard，断言旧能力状态没有恢复预约入口，并完成新 guard 后只采用新状态。

- [x] **Step 2: 为学分地图与待办来源能力添加替换回归**

分别用两个 gateway fake 让旧读取悬置，替换 widget 后完成旧读取，断言旧学分地图/旧来源作业不出现；随后完成新读取并断言新内容出现。

- [x] **Step 3: 运行测试并确认修复前失败**

Run: `cd flutter && flutter test test/read_page_generation_test.dart test/graduate_page_test.dart test/tasks_simplification_widget_test.dart`
Expected: 新增用例失败，旧用例保持通过；失败证据是旧能力结果被采用或新能力未重新读取。

### Task 3: 将独立能力纳入页面身份代次

**Files:**
- Modify: `flutter/lib/features/cgyy/cgyy_day_page.dart`
- Modify: `flutter/lib/features/graduate/graduate_page.dart`
- Modify: `flutter/lib/features/tasks/tasks_page.dart`

- [x] **Step 1: 研讨室写能力变化时使旧读取失效**

在现有服务身份判断中加入：

```dart
oldWidget.bookingGateway != widget.bookingGateway
```

保留 `request++`、清空旧状态和 `load()`，确保旧 read/guard 的 serial 不能落地。

- [x] **Step 2: 学分地图能力变化时重建 RefreshSection**

在研究生服务身份判断中加入：

```dart
oldWidget.creditMapGateway != widget.creditMapGateway
```

沿用 `generation++`、dispose/recreate 和重新 `load()`。

- [x] **Step 3: 待办来源能力变化时阻断旧来源导航**

在 `TasksPage.didUpdateWidget` 中，当 `academicService` 改变时执行 `generation++` 并将 `locating` 复位为 `false`；不因此清空或重读本地待办，因为本地存储身份没有变化。`source()` 已用 epoch 阻断旧响应，无需新增框架。

- [x] **Step 4: 运行回归并确认转绿**

Run: `cd flutter && flutter test test/read_page_generation_test.dart test/graduate_page_test.dart test/tasks_simplification_widget_test.dart`
Expected: 全部通过。

### Task 4: 完整验证与候选构建

**Files:**
- Modify: `flutter/pubspec.yaml`
- Modify: `docs/RELEASE-NOTES.md`
- Create: `docs/_audit/2026-10-30-android-beta3-readiness.md`

- [x] **Step 1: 运行完整工程门禁**

Run: `bash scripts/check-mirror.sh`
Expected: 退出码 0，Rust/Flutter 测试、严格 Clippy、架构、FRB 与接口索引全部通过。

- [x] **Step 2: 运行 Android 演示设备回归并恢复普通应用**

Run: `cd flutter && flutter test integration_test/cgyy_test.dart integration_test/academic_learning_ux_test.dart -d emulator-5554`
Expected: 两个目标测试文件通过。

Run: `cd flutter && flutter build apk --debug --target-platform android-arm64 --target lib/main.dart`
Expected: 正常 main APK 构建成功；设备测试后若安装，则安装此正常入口包而非测试驱动包。

- [ ] **Step 3: 真实账号只读验收（待本人凭据）**

使用 `GINKGO_LIVE_ACCEPTANCE` 的既有临时回环通道，不把凭据写入命令行、文件或日志。验证小写研究生学号登录及核心只读页面；不触发任何学校写确认。若凭据或设备不可用，记录未验收，不伪造通过。

- [x] **Step 4: 冻结版本并构建签名候选**

将 pubspec 改为 `0.1.0-beta.3+13`，只写 3–5 条用户收益说明。运行：

Run: `cd flutter && flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`
Expected: 使用外部签名配置成功；缺签名配置则停止，不回退 Debug 签名。

- [x] **Step 5: 检查候选与文档**

核对版本、证书、非 debuggable、ARM64、zipalign/apksigner、SHA-256 和正常入口。记录真实账号、物理设备、Release 覆盖升级及远端 CI 的独立结果；未执行或失败项明确保留。执行 `git diff --check` 并提交本地候选变更；未经后续明确授权不推送 tag 或公开发布。

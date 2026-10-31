# Beta Read-only Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前 Android 工作树收敛到真实账号核心只读链路可验收、完整门禁通过的 Beta 候选状态，不执行发布或学校写操作。

**Architecture:** 保持现有 domain / upstream / core / bridge / Flutter 分层。只修改 Session 的自动 WebVPN 回退条件、匿名公开读取路线和少量呈现文案；不修改学校 URL、响应解析、TLS、Cookie 安全规则或写入状态机。

**Tech Stack:** Rust、Flutter/Dart、Android API 37 ARM64 模拟器、现有 FRB 与集成验收管线。

---

### Task 1: 匿名公开读取不再回退 WebVPN

**Files:**
- Modify: `rust/crates/ginkgo_upstream/src/auth/session.rs`
- Test: 同文件 `anonymous_request_tests`

- [x] **Step 1: 写失败回归**

```rust
let error = session
    .send_anonymous(HttpRequest::get(CAREER_URL), RouteMode::Automatic)
    .await
    .expect_err("direct failure");
assert_eq!(transport.requests().len(), 1);
```

- [x] **Step 2: 验证旧实现失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream anonymous_automatic_read_never_falls_back_to_gateway -- --nocapture`
Expected: 请求数为 2，断言失败。

- [x] **Step 3: 最小修复**

```rust
let isolated = Session::new(AnonymousTransport(&self.transport));
isolated.set_route(RouteMode::Direct);
isolated.send_following_redirects(request).await
```

- [x] **Step 4: 验证通过**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream anonymous_request_tests -- --nocapture`
Expected: 2 passed。

### Task 2: 无网关凭据时不自动回退

**Files:**
- Modify: `rust/crates/ginkgo_upstream/src/auth/session.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/session_service.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/session_service/session_source.rs`
- Test: `rust/crates/ginkgo_upstream/src/services/tests/session.rs`

- [x] **Step 1: 写失败回归**

真实手动登录但不保存密码后，第一次业务直连失败应保留原错误，且总请求数是 5 次登录请求加 1 次业务请求，不出现 `d.buaa.edu.cn`。

- [x] **Step 2: 验证旧实现失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream unremembered_login_does_not_fallback_to_an_unauthenticated_gateway -- --nocapture`
Expected: 实际 7，预期 6。

- [x] **Step 3: 最小修复**

`Session` 增加默认开启的 `automatic_fallback`。手动登录开始时允许认证链回退；成功后仅在实际保存凭据或已有 WebVPN Cookie 时允许后续自动回退；静默登录成功重新允许。

- [x] **Step 4: 验证新旧两条路径**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream unremembered_login_does_not_fallback_to_an_unauthenticated_gateway -- --nocapture`
Expected: 1 passed。
Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream checkin_webvpn_fallback_establishes_the_gateway_session_once -- --nocapture`
Expected: 1 passed，保存凭据后的网关恢复不回归。

### Task 2A: 图书馆公开统计 TLS 缺链

**Files:**
- Modify: `rust/crates/ginkgo_upstream/src/adapters/reqwest_transport.rs`
- Test: 同文件 `incomplete_chain_tests`

- [x] **Step 1: 写主机白名单失败测试**

断言 `space.lib.buaa.edu.cn` 与 `lib.buaa.edu.cn` 使用随仓库附带的中间证书，SSO 和相似恶意域名不得使用。

- [x] **Step 2: 验证旧实现失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --features network only_the_two_library_hosts_use_the_scoped_intermediate -- --nocapture`
Expected: 编译失败，缺少 `requires_incomplete_chain_anchor`。

- [x] **Step 3: 最小修复**

用 `INCOMPLETE_CHAIN_HOSTS` 白名单和 `requires_incomplete_chain_anchor(url)` 统一判断，复用已有 GlobalSign 中间证书，不新增信任锚或修改默认 client。

- [x] **Step 4: 验证通过**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --features network only_the_two_library_hosts_use_the_scoped_intermediate -- --nocapture`
Expected: 1 passed；真实公开统计返回两个校区。

### Task 3: 呈现与 live 管线修复

**Files:**
- Modify: `flutter/lib/features/{schedule/schedule_page.dart,homework/homework_page.dart,homework/homework_detail_page.dart,grades/grades_page.dart,checkin/checkin_page.dart}`
- Modify: `flutter/integration_test/live_acceptance_test.dart`

- [x] **Step 1: 中性错误辅助文案**

将统一的“请检查网络后重试”改为“请根据上方提示处理后重试”，避免认证错误被误导为网络故障。

- [x] **Step 2: 更新新增待办选择器**

```dart
await tester.tap(find.text('确认添加'));
```

- [x] **Step 3: 增加诊断用强制直连开关**

仅在 live 测试显式传入 `GINKGO_LIVE_DIRECT=true` 时调用：

```dart
await live.setRoute(route: live.RouteChoice.direct);
```

- [ ] **Step 4: 在真实模拟器验证完整页面阶段**

Run: `flutter test integration_test/live_acceptance_test.dart -d emulator-5554 --dart-define=GINKGO_LIVE_ACCEPTANCE=true`
Expected: 不再在待办“保存”旧文案处中断；所有页面阶段执行，失败只保留真实上游错误证据。

### Task 4: 自动化基线

**Files:**
- Update: `docs/API.md`
- Update: `docs/interfaces/`（仅生成器要求时）

- [ ] **Step 1: 格式化与上游测试**

Run: `cargo fmt --manifest-path rust/Cargo.toml --check && cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked`
Expected: 全部通过。

- [ ] **Step 2: 完整镜像门禁**

Run: `bash scripts/check-mirror.sh`
Expected: 架构、文档、Rust、FRB、Flutter analyze/test 全部通过。

- [ ] **Step 3: 正常入口构建**

Run: `flutter build apk --debug --target-platform android-arm64 --target lib/main.dart`
Expected: 生成正常 `main` 的 ARM64 Debug APK，不停留在测试驱动入口。

### Task 5: 真实设备视觉闭环与记录

**Files:**
- Update: `docs/MIRROR-TODO.md`
- Update: `docs/_audit/2026-11-01-beta-readonly-release.md`

- [ ] **Step 1: 自动路线真实复验**

在隔离 API 37 模拟器运行 live 管线，不保存密码。核心成功模块必须不再把直连失败误报为全局 `sessionExpired`；不可达主机允许保留 `networkUnreachable` 证据，不伪造成功。

- [ ] **Step 2: 强制直连视觉复验**

在同一设备以 `GINKGO_LIVE_DIRECT=true` 复跑，复核真实 Today、课表、作业、博雅、研究生、空教室、设置、完整工作壳及大字号截图。真实截图只存权限受限临时目录，复核后删除。

- [ ] **Step 3: 清理与边界**

登出并确认不可恢复，删除测试包、临时截图和专用 AVD；重建正常入口。记录未覆盖的物理设备、TalkBack、Windows 和学校写入，不宣称已公开发布。

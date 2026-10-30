# P0 Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 修复退出吊销、恢复型快照和提醒迟到响应三个已定位的正确性缺陷，并用回归测试锁定。

**Architecture:** 复用现有 `SchoolClient.sign_out()`、`AppError`、`SnapshotCache`/`SnapshotBook` 和 `ReminderController`，不增加新的业务状态机。每处只修改错误路径或代次判断，不改变学校协议和正常成功路径。

**Tech Stack:** Rust 2021、Tokio、Dart 3.13、Flutter、flutter_test。

---

### Task 1: 退出锁超时也执行本地吊销

**Files:**
- Modify: `rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs`
- Modify: `rust/crates/ginkgo_flutter_bridge/src/api/live.rs`

- [x] **Step 1: 增加锁超时回归测试**

在 bridge 测试中增加仅测试构建可见的本地吊销计数器，并让测试先占住 `SESSION_ACCESS` 读锁。使用 `#[tokio::test(start_paused = true)]` 推进超过 90 秒，断言超时路径仍调用本地吊销，而不是只返回 `SignedOut`。测试需位于支持平台保险库的目标上；正常路径计数不得混淆，因此每次测试读取前后差值。

核心断言形态：

```rust
let before = LOCAL_REVOCATIONS.load(Ordering::SeqCst);
let read = SESSION_ACCESS.read().await;
let response = sign_out().await;
assert!(matches!(response.state, SessionState::SignedOut));
assert_eq!(LOCAL_REVOCATIONS.load(Ordering::SeqCst), before + 1);
drop(read);
```

- [x] **Step 2: 运行测试并确认旧实现失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_flutter_bridge sign_out_revokes_locally_when_the_gate_times_out -- --nocapture`

Expected: 原实现计数差为 0，测试失败。

- [x] **Step 3: 最小实现超时补偿吊销**

把正常闭包和超时补偿共用的本地调用收成一个私有助手：

```rust
async fn revoke_locally(service: &LiveService) {
    service.sign_out().await;
    #[cfg(test)]
    LOCAL_REVOCATIONS.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
}
```

正常路径仍在会话写锁内调用它；只有 `with_session_write` 未返回 `Ok(true)` 时，在锁外再调用一次。`SchoolClient.sign_out()` 是幂等本地清理。补偿后仍执行既有 `purge_credentials()`，然后才能返回 `signed_out()`。不将闸门失败伪造成“无需清理”。

- [x] **Step 4: 运行专项和既有生命周期测试**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_flutter_bridge sign_out -- --nocapture`

Expected: 新超时测试和 `sign_out_waits_for_active_bridge_reads` 均通过。

### Task 2: 新网络错误码允许有效恢复快照

**Files:**
- Modify: `rust/crates/ginkgo_domain/src/lib.rs`
- Modify: `rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/cache.rs`

- [x] **Step 1: 写两套失败回归**

在 `SnapshotBook` 测试中，提交并 decode 一个有效条目，然后断言：

```rust
let old = copy
    .fallback(&s, &key(), 2000, AppError::network_unreachable())
    .unwrap()
    .unwrap();
assert_eq!(old.fetched_at_ms, 1000);
assert_eq!(old.failure.code, ErrorCode::NetworkUnreachable);
assert!(book
    .fallback(&s, &key(), 2000, AppError::session_expired())
    .is_err());
```

在 `SnapshotCache` 测试中使用 `restore` 写入 `restored=true` 的条目，分别用 `ServiceUnavailable` 和 `NetworkUnreachable` 调 `resolve_current`，断言均保留值、原时间和错误；再断言 `SessionExpired` 被拒绝。

- [x] **Step 2: 运行测试并确认旧实现失败**

Run: `cargo test --manifest-path rust/Cargo.toml network_unreachable -- --nocapture`

Expected: 两个新错误码回退用例失败，认证失败拒绝用例不受影响。

- [x] **Step 3: 在 domain 集中暂时性错误分类**

在 `AppError` 增加：

```rust
pub fn allows_stale_snapshot(&self) -> bool {
    matches!(
        self.code,
        ErrorCode::ServiceUnavailable | ErrorCode::NetworkUnreachable
    )
}
```

`SnapshotBook::fallback` 改为 `if !failure.allows_stale_snapshot() { return Err(failure); }`。`SnapshotCache` 两个 restored 分支改为 `!error.allows_stale_snapshot() || expired`，其余账号、TTL、写票和缓存提交逻辑保持不变。

- [x] **Step 4: 运行 domain 与 upstream 测试**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_domain --locked && cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked`

Expected: 全部通过。

### Task 3: 签到和作业提醒丢弃旧刷新轮次

**Files:**
- Modify: `flutter/lib/shared/reminders.dart`
- Modify: `flutter/test/extended_reminders_test.dart`

- [x] **Step 1: 写超时后乱序完成回归**

给 `ReminderController` 测试传入短 `refreshDeadline`。让第一轮签到和作业读取挂起，推进 BusyGate 到期；第二轮先返回带 `new` ID 的数据，再让第一轮返回带 `old` ID 的数据。使用课程时间位于 `now` 之后的合成 `CheckInCourse` 和未来截止的 `HomeworkItem`，最后断言：

```dart
final keys = controller.plans.map((plan) => plan.key).join('\n');
expect(keys, contains('new'));
expect(keys, isNot(contains('old')));
```

测试同时记录平台计划，防止仅内部列表正确但又用旧数据重新排程。

- [x] **Step 2: 运行测试并确认旧实现失败**

Run: `flutter test test/extended_reminders_test.dart --name 'stalled refresh cannot overwrite a newer reminder generation'`

Expected: 最终包含 `old`，测试失败。

- [x] **Step 3: 增加整轮刷新代次**

构造函数增加默认 5 分钟的可注入 `refreshDeadline`，初始化 `_refreshGate`。新增 `_refreshGeneration = 0`，每次成功 `enter()` 后执行 `final generation = ++_refreshGeneration;`。

签到和作业的成功、异常及提示更新必须满足：

```dart
if (!_disposed && generation == _refreshGeneration) {
    // apply this round's result
}
```

只有最新轮次才能执行 `_refreshGate.leave()` 和后续 `reconcile()`，避免旧轮次完成时把新轮次的闸门提前释放，或用旧数据重新排程。课程和待办已有 ticket 的代码保持原样。

- [x] **Step 4: 运行提醒和 Flutter 全量测试**

Run: `flutter test test/extended_reminders_test.dart test/busy_gate_test.dart && flutter analyze && flutter test test`

Expected: 全部通过，静态分析无问题。

### Task 4: 全量验证与边界核对

**Files:**
- Modify only if generated checks require it: `docs/interfaces/`
- No school protocol or fixture changes.

- [x] **Step 1: 检查格式和 Rust 全量质量**

Run: `cargo fmt --manifest-path rust/Cargo.toml --all --check && cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets --all-features --locked -- -D warnings && cargo test --manifest-path rust/Cargo.toml --workspace --locked`

Expected: 全部退出码为 0。

- [x] **Step 2: 运行完整镜像门禁**

Run: `bash scripts/check-mirror.sh`

Expected: 全部通过。若 `docs/interfaces/rust-upstream-auth.md` 仍因本批之外的既有漂移失败，先运行 `python3 scripts/generate-interface-index.py` 刷新生成索引，再重跑；不得手改生成文档。

- [x] **Step 3: 最终差异检查**

Run: `git diff --check && git status --short`

Expected: 无空白错误；只出现本批设计、计划、实现和测试改动，以及用户原有工作树改动。不提交、不删除用户文件，不执行真实账号或学校写操作。

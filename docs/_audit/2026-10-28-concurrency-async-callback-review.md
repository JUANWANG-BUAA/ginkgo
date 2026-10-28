# 并发、异步与回调审查（2026-10-28）

范围：`rust/crates/`（5 个 crate）+ `flutter/lib/` + `flutter/android/`。承接
[架构边界审查](2026-10-28-architecture-boundary-review.md) 与
[设计语言与模块布局审查](2026-10-28-design-language-and-module-layout-review.md)，
本篇只查**阻塞、死锁、悬挂（挂起/闩死/倒挂）**。

本轮只读，未修改业务代码。

---

## 0. 结论速览

| 维度 | 结论 |
| --- | --- |
| **死锁** | ✅ **未发现**。6 处嵌套加锁全部同序，无 AB-BA 反向；但隔离机制依赖**隐式**约定且未被测试覆盖（§2.3） |
| **同步锁跨 await** | ✅ **未发现**。28 个候选点逐个核对，`std::sync::Mutex` 守卫全部在 await 前释放；但只有注释约束，无门禁（§2.4） |
| **阻塞** | ❌ **6 处**。最严重：45/90 秒读预算**不覆盖锁等待**，命令可无限挂起（§1.1） |
| **悬挂 / 闩死** | ❌ **P0 一处链式失效**：Rust 挂起 → Dart `busy` 闩死 → 提醒功能整个会话失效，只能重启（§3.1） |
| **回调** | ⚠️ 5 个 Android MethodChannel 中 **4 个在主线程**；其中 `ReminderScheduler.replace` 做 2 次 fsync（§4.1） |

**一句话**：死锁这一类做得比预期好（锁序一致、守卫不跨 await、HTTP 任务有 `AbortOnDrop` 取消）；真正的问题是**超时只包住了"干活"，没包住"排队"**，以及**"一次挂起"会顺着 Dart 的 busy 标志闩死整个功能**。

---

## 1. 阻塞

### 1.1 ✅ 已修复（2026-10-28）【P0】`bounded_read` / `bounded_session` 不覆盖锁等待，命令可无限挂起

> **修复记录（2026-10-28）**：见 [整改台账](2026-10-28-review-remediation.md) R-01。锁等待已移入独立预算（`GATE_BUDGET` 45 秒 / `SESSION_GATE_BUDGET` 90 秒），新增 `with_session_read` / `with_session_write` / `with_session_submit` / `with_module_read` / `with_module_submit` / `with_session_read_in` 六个助手，全部 89 个 FFI 命令改用它们；新增 6 条门禁预算回归（`runtime.rs` 的 `gate_budget_tests`）。


全部 89 个 FFI 命令的模式都是：

```rust
// ginkgo_flutter_bridge/src/api/live/academic.rs:9
let _access = SESSION_ACCESS.read().await;      // ← 锁等待：没有上界
let Ok(service) = service() else { ... };
match bounded_read(service.load_schedule(...))   // ← 45 秒预算只覆盖这里
    .await { ... }
```

`bounded_read` 的实现是 `tokio::time::timeout(45s, future)`（`live/runtime.rs:26-32`），它**只包住传入的那个 future**；`SESSION_ACCESS.read().await` 发生在它**之前**，因此：

- 等待全局会话锁的时间**不受任何上界约束**；
- `MIRROR-TODO` P0 写的「全部 `load_*` 读命令补 `bounded_read` 超时」只对"进入服务之后"的部分成立；
- 一个命令的总耗时 = **锁等待（无界）** + 45 秒。

**同样的模式出现在 5 个模块锁上**（`live/library.rs`、`live/checkin.rs`、`live/utilities.rs`、`live/academic.rs:52-53`），以及全局写锁（`live/session.rs:10,32,61,70,85`、`live/auth_challenge.rs:16`、`live/utilities.rs:238`）。

**写锁的持有时长**：

| 持锁命令 | 持锁期间做什么 | 上界 |
| --- | --- | --- |
| `login` / `restore_session` | CAS/UC 登录链 | `bounded_session` 90 秒（**不含锁等待**） |
| `load_login_challenge` | 验证码抓取 | `bounded_read` 45 秒 |
| `sign_out` | Keystore JNI + `commit()` ×N | **无上界**（§1.5） |
| `set_route` | 纯内存 | 立即 |
| `import_learning_snapshots` | 纯 serde | 立即 |

**后果链**：写锁被占 → 所有读命令在 `SESSION_ACCESS.read()` 上无限排队 → Dart 侧 Future 永不完成 → 页面永远转圈（§1.2）→ Dart 的 busy 标志闩死（§3.1）。

**修法**：把锁获取移进预算内。

```rust
pub(super) async fn bounded_read<T>(f: impl Future<Output = Result<T, AppError>>) -> Result<T, AppError> {
    tokio::time::timeout(Duration::from_secs(45), f).await.map_err(|_| AppError::unavailable())?
}
// 调用侧改成：
bounded_read(async {
    let _access = SESSION_ACCESS.read().await;
    /* … */
}).await
```

写命令同理（`bounded_submit` 内移锁），但要注意：**写超时后不能重发**，仍按"结果不明"处理。

### 1.2 ✅ 已修复（2026-10-28）【P0】Dart 侧对 89 个 FFI 命令**没有任何超时**

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-02。106 处原生调用全部包裹 `boundedNativeRead`/`boundedNativeWrite`（120 秒 / 210 秒，高于 Rust 双层预算），新增 8 条回归。


`flutter/lib/` 内的 `Future.timeout(...)` 只出现在 3 个**纯 Dart** 的更新下载实现里：

| 位置 | 用途 |
| --- | --- |
| `platform/update_gate.dart:79,80,85` | 拉取 `update-gate.json`（4 秒） |
| `platform/android_update_controller.dart:243,259,264,292` | APK 下载（15/5/20 秒） |
| `platform/startup_update.dart:37` | 启动期更新检查 |

**89 个 FFI 命令（含生成的 `flutter/lib/src/rust/api/live.dart`）一个超时都没有**（生成绑定里 `timeout` 出现 0 次）。

因此 §1.1 的挂起在 Dart 侧表现为**Future 永不完成**，没有任何降级路径。

**修法**（二选一，建议都做）：

1. Rust 侧：按 §1.1 把锁移进预算（治本）。
2. Dart 侧：在 `infrastructure/native_*.dart` 的每个 gateway 方法外包一层 `Future.timeout`，超时映射为 `FailureCode.serviceUnavailable`。这是**防御性兜底**，保证任何 Rust 侧的意外挂起都不会让页面永久转圈。

### 1.3 ✅ 已修复（2026-10-28）【P1】`edit_tasks` 的 fsync 没有超时，且 `spawn_blocking` 不可取消

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-04。已由 R-01 的 `with_session_read` 一并纳入 45 秒预算，新增 1 条回归。


```rust
// ginkgo_flutter_bridge/src/api/live/utilities.rs:31
let result = tokio::task::spawn_blocking(move || { … tasks_service::edit(…) })
    .await
    .unwrap_or_else(|_| Err(AppError::unavailable()));
```

`tasks_service::edit` → `tasks_store::transact` → `create_dir_all` + `OpenOptions::create` + `write_all` + **`sync_all()`** + `rename`（`ginkgo_core/src/tasks_store.rs:21-53`）。

问题：

- **没有超时**（对比：`execute_cgyy` 用 `bounded_submit` ✓）；
- `spawn_blocking` 的任务**不可取消** —— 即使加了 `timeout`，被放弃的 fsync 仍会跑完；
- 卡住的 fsync 会让该命令永不返回 → Dart 侧待办页永久 busy。

**修法**：用 `tokio::time::timeout` 包住 `spawn_blocking` 的 await（超时后任务继续跑完，但命令能返回），并在超时文案里说明"本机写入未确认"。

### 1.4 ✅ 已修复（2026-10-28）【P1】作业文件 journal：在 async fn 里持同步锁做 fsync

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-05。journal 四个操作全部拆成「磁盘相位（无锁、`spawn_blocking`）+ 内存相位（持锁、纯内存）」，落盘后复检 owner；新增 3 条相位回归，364 项 upstream 测试行为等价通过。


`ginkgo_upstream/src/services/homework_submission_service/journal.rs` 的 `restore` / `create` / `clear` 做：

- `fs::symlink_metadata` / `fs::canonicalize`（每次都做，2 次 syscall 路径解析）
- `fs::create_dir` + `set_permissions(0o700)` + **`sync_directory()`（`File::open(dir).sync_all()`）**
- `fs::read_dir`（最多 256 项）+ 逐个 `File::open` + `read_to_end`
- `fs::remove_file` + `sync_directory()`

这些全部在**持有 `homework_files`（`std::sync::Mutex`）** 的情况下、由 **async fn** 调用：

| 调用点 | async fn |
| --- | --- |
| `homework_submission_service.rs:153` | `upload_homework_file` |
| `homework_submission_service.rs:230` | `submit_homework_file` |
| `homework_submission_service.rs:327` | `reconcile_homework_file` |
| `capabilities.rs:56` | `diagnose_homework` |

**两个后果**：

1. **tokio worker 被 fsync 阻塞**（不是"这个任务被挂起"，而是"这个 OS 线程被占住"）。FRB 的异步运行时 worker 数 = CPU 核数；低端 Android 机 4 核，同时有几次作业文件操作就可能把 worker 占满。
2. `std::sync::Mutex` **阻塞的是线程**，不只是任务。其它任务要拿 `homework_files` 时，会把**它自己所在的 worker 线程**也一起阻塞住。

> `MIRROR-TODO` P2 记的「CGYY 核心命令均移入 `spawn_blocking`」指的是 **bridge 层的 `edit_tasks`**；**作业文件 journal 的 fsync 仍在 worker 上 inline**，这一条没被覆盖。

**修法**：把 journal 的三个函数改成同步纯函数（不碰 `HomeworkFiles`），由调用方在 `spawn_blocking` 里执行；或把 `HomeworkFiles` 的守卫范围缩小到"只改内存"，磁盘 IO 全在锁外。

### 1.5 ✅ 已修复（2026-10-28）【P1】`sign_out` 在全局写锁内做 Keystore JNI 与同步 `commit()`

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-06。`SessionSource` 拆分出 `purge_credentials()`，吊销与清凭据分两步；bridge 只在吊销阶段持独占闸门。upstream 测试 364→367。


```rust
// live/session.rs:61
let _access = SESSION_ACCESS.write().await;   // 全局独占
service.sign_out().await;
```

`sign_out`（`session_source.rs:306-335`）会调用：

- `self.vault.accounts()` → JNI → Kotlin `CredentialVault.accounts()`
- `self.vault.delete(&account)` → JNI → Kotlin `SharedPreferences.edit().remove(...).commit()`

`commit()` 是**同步 fsync**。这些调用：

- 跑在 **tokio worker** 上（`android_vault.rs` 用 `attach_current_thread()`，不占 Android 主线程 ✓，但占 worker）；
- **持有全局独占写锁** → 期间所有读命令排队；
- Keystore 操作实测 10–100ms/次，账号多时更久。

**修法**：把 `sign_out` 的磁盘部分拆出来，在 `spawn_blocking` 里做；写锁只保护"清 identity + 清快照"这段内存操作。

### 1.6 ✅ 已修复（2026-10-28）【P2】Android 主线程同步 fsync：`ReminderScheduler.replace`

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-11。`replace` 改在自带 worker 上执行，结果回主线程；新增 `dispose()` 并在 `onDestroy` 释放。Android ARM64 Debug 构建通过。


`flutter/android/.../ReminderScheduler.kt` 的 `replace` 在 **MethodChannel 主线程**上做：

- 2 次 `SharedPreferences.edit().….commit()`（**同步 fsync**）
- 最多 60 次 `AlarmManager.setAndAllowWhileIdle`
- 若干次 `NotificationManager.cancel`

主线程做 fsync + 60 次闹钟排程，在低端机上足以造成明显卡顿，极端情况触发 ANR。

**其余 4 个通道是干净的**：

| 通道 | 位置 | 状态 |
| --- | --- | --- |
| `learning-snapshots` | `MainActivity.kt:33-35` | ✓ 用了 `messenger.makeBackgroundTaskQueue()` |
| `homework-files` | `HomeworkFileSaver.kt:25` | ✓ 自带单线程 executor；`prune()` 只改内存 |
| `update` | `UpdateInstaller.kt:23-24` | ✓ 自带 executor + `main.post` 回主线程 |
| `system` | `SystemSettingsHandler.kt:41` | ✓ 用 `apply()`（异步） |

**修法**：给 `reminders` 通道也挂 `makeBackgroundTaskQueue()`，或让 `ReminderScheduler` 自带 executor + `main.post` 回主线程（与 `UpdateInstaller` 一致）。

---

## 2. 死锁

### 2.1 锁序表（已核对，无反向）

| 层 | 锁 | 加锁顺序 |
| --- | --- | --- |
| FFI | `SESSION_ACCESS`(tokio RwLock) → `LIBRARY_ACCESS` / `CHECKIN_ACCESS` / `CGYY_ACCESS`(tokio RwLock) | **恒为 SESSION → 模块** |
| FFI | `CGYY_WRITE`(tokio Mutex) → `SESSION_ACCESS` → `CGYY_ACCESS` | 固定 |
| upstream | `identity` → `cgyy_safety` → `snapshots.cgyy` | 固定（`cgyy_booking_service.rs:57,67,100,164,173`） |
| upstream | `identity` → `homework_files` | 固定（`homework_submission_service.rs:74,220,322`） |
| upstream | `homework_file_gate`(tokio) → `homework_files` | 固定（`capabilities.rs:27`） |
| upstream | `recovery_gate`(tokio) → `identity` | 固定（`session_service.rs:225`） |

全量扫描 6 处**嵌套加锁**函数，无任何反向序 → **不存在 AB-BA 死锁**。

`live/library.rs:291-292` 等处的「先 SESSION 再模块」也一致：不存在"持模块锁再等 SESSION 写锁"的路径。

### 2.2 同步锁跨 await：28 个候选点全部合规

用脚本枚举所有 `let x = ….lock();` 后 40 行内出现 `.await` 的位置（28 处），逐个核对：

- `ticket` / `cached` / `cache` 等**是 `u64`/值拷贝**，不是守卫（`begin()` 返回 `u64`）；
- 真正的守卫（`identity` / `safety` / `files` / `progress` / `cache`）全部被包在 `{ … }` 作用域内，**在 await 之前 drop**；
- `foundation/mutex.rs` 的模块文档明确写了「Guards must not cross an await」，**这条约束被遵守**。

### 2.3 ⚠️ 账号隔离实际由 FFI 锁保证，不是 domain 层

`library_mutation_service.rs` 的两个写操作**没有任何账号复检**：

```rust
async fn reserve_library_seat(&self, …) -> MutationOutcome {
    if self.current_account().is_err() {          // ← 只在开头，且结果被丢弃
        return MutationOutcome::not_submitted("请先登录，未提交预约");
    }
    let Ok(slots) = self.load_library_slots(area_id).await else { … };
    …
    let result = library_http::mutate(&self.session, &token, "space/confirm", …).await;
    self.invalidate_library_after_write();
    result                                            // ← 没有任何 owner 复检
}
```

它现在安全，**只是因为** `live/library.rs:291-292` 让写操作持有 `SESSION_ACCESS.read()`，使需要写锁的 `login` / `sign_out` 无法并发：

```
账号切换（需 SESSION_ACCESS.write）  ⇄  图书馆写（持 SESSION_ACCESS.read）
```

**两个后果**：

1. 这条保证是**隐式**的、跨 crate 的，源码里没有任何注释或测试说明它；
2. `ginkgo_core` 的测试（`tests/workspace_ports.rs` 等）**直接调用 `Workspace`**，不经过 bridge 的锁 → **真正的隔离机制没有测试覆盖**。把 bridge 锁改成 `read` 优先或去掉，测试全绿，但生产会串号。

**修法**：

- 在 `library_mutation_service.rs` 补 `check_account_owner(&owner)`（与其它写路径一致），让 domain 层自洽；
- 在 `live/library.rs` 的写路径加注释，说明"写期间持读锁是为了阻止账号切换"；
- 补一条**在 bridge 层**的回归：写操作在途时发起 `sign_out`，断言写结果被判为 `session_expired`。

### 2.4 ✅ 已修复（2026-10-28）"守卫不跨 await" 已纳入门禁

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-15。架构脚本检查自定义同步 guard 的生命周期，跨 `.await` 即失败；显式 `drop` 与 tokio 异步锁均有合成自测。

---

## 3. 悬挂 / 闩死 / 倒挂

### 3.1 ✅ 已修复（2026-10-28）【P0】一次 Rust 挂起 → 提醒功能整个会话失效，只能重启应用

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-03。新增 `BusyGate` 看门狗；`ReminderController` / `ReminderScope` / `RefreshSection` / `LibraryController` 四处闩死点全部改为可自愈，且 `_start()` 提前到等待之前。新增 8 条回归。


链式闩死，两处 busy 标志**都不会自动复位**：

```dart
// shared/reminders.dart  ReminderController.refresh()
Future<void> refresh({bool includeHomework = true}) async {
  if (_busy || _disposed || service.isDemo) return;
  _busy = true;
  …
  await Future.wait([ … 四个并发读 … ]);   // ← 任一读挂起 → 永不返回
  _busy = false;                            // ← 永远执行不到
}
```

```dart
// shared/reminder_scope.dart  _ReminderScopeState._activate()
_activating = true;
try {
  final refresh = current.refresh(includeHomework: !initial);
  if (!initial) unawaited(current.reschedule());
  await refresh;                    // ← 挂起则下面的 _start() 不执行
  if (_foreground) _start();
} finally {
  _activating = false;              // ← finally 只在 await 返回时执行
}
```

**完整失效链**：

```
Rust 命令在 SESSION_ACCESS 上无限等待（§1.1）
  → Dart Future 永不完成
    → Future.wait 不返回 → ReminderController._busy 永久 true
      → 后续所有 refresh() 命中 `if (_busy) return;` 直接返回
        → _ReminderScopeState._activating 永久 true
          → 后续所有 _activate() 命中 `if (_activating) return;`
            → _start() 永不执行
              → 2 分钟 poll 与 15 秒 tick 定时器从不创建
                → 提醒在整个会话内完全失效，只能杀进程重启
```

**同一闩死模式还出现在**：

| 位置 | 闩死标志 | 后果 |
| --- | --- | --- |
| `application/refresh_section.dart:16,71,85` | `loading` | 该 section 永远显示加载中 |
| `features/library/library_controller.dart` | `loadingBookings` / `loadingVenues` | 图书馆页永远转圈 |
| `features/homework/homework_files_panel.dart:39,86` | `busy` | 作业附件面板整体不可用（`blockedByPending` 连带） |
| `features/tasks/tasks_page.dart` | `locating` | 待办来源定位按钮卡死 |
| `features/cgyy/cgyy_booking_page.dart:32` | `busy` | 预约表单不可用 |

**修法**（三选一，建议全做）：

1. **根治**：§1.1 把锁移进超时预算 + §1.2 Dart 侧兜底超时 → Rust 不会挂起。
2. **兜底**：给每个 busy 标志加**看门狗**（例如 `loading` 超过 N 秒自动复位并提示"上次读取未完成，请重试"）。
3. **结构**：把 `busy` 从「布尔闩」改成「带超时的状态机」（`RefreshSection` 已经是雏形，但缺超时）。

### 3.2 【P1】✅ 已修复（2026-10-28）`reconcile()` 没有 in-flight 守卫，15 秒定时器可堆积 `platform.replace`

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-07。`reconcile()` 改为合流 + 补跑一次；新增 1 条回归断言 `maxInFlight == 1`。


```dart
// shared/reminder_scope.dart:100-108
void _start() {
  if (!_foreground || !_ready || poll != null || tick != null) return;
  poll = Timer.periodic(const Duration(minutes: 2), (_) {
    if (_foreground) unawaited(controller!.refresh());
  });
  tick = Timer.periodic(const Duration(seconds: 15), (_) {
    if (_foreground) unawaited(controller!.reconcile());
  });
}
```

`ReminderController.reconcile()` 末尾是 `await platform.replace(platformPlans)`，**没有并发守卫**。若一次 replace 耗时超过 15 秒，下一次 tick 会再发起一次 → 多次 `replace` 在 Dart 侧重叠。

**会不会写坏系统排程？** 不会 —— Kotlin 的 MethodChannel handler 跑在主线程，天然串行，`ReminderScheduler` 又是「先持久化再排程」，所以最终状态是最后到达的那次。**但**：

- 重叠的 replace 会在 **Android 主线程排队**（叠加 §1.6 的 fsync 卡顿）；
- 每次 replace 最多 60 个闹钟，重叠时做大量无用的 `cancel` + `set`。

**修法**：给 `reconcile()` 加 in-flight 合并（与 `RefreshSection.refresh` 同款：飞行中到达的请求合并到飞行中那次，结束后若签名已变再补跑一次）。

### 3.3 【P1】✅ 已修复（2026-10-28）`LibraryController.reservationChanged()` 的 `_bookingTask` 空窗竞态

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-08。`reservationChanged()` 改等 `_bookingForcedRun ?? _bookingTask`；新增 1 条回归。


```dart
// features/library/library_controller.dart
Future<void> _chainForced(inFlight, fetch, slot, setSlot, setForcedRun) {
  final epoch = _generation;
  late final Future<void> run;
  run = inFlight.then((_) async {
    …
    task = fetch(true).whenComplete(() { if (identical(slot(), task)) setSlot(null); });
    setSlot(task);          // ← 这里才把 _bookingTask 设回去
    await task;
  }).whenComplete(() => setForcedRun(null));
  return run;
}

Future<void> reservationChanged() async {
  await _bookingTask;       // ← 此刻可能是 null
  await loadBookings(force: true);
}
```

`_enqueue` 里 `task = fetch(force).whenComplete(() { if (identical(slot(), task)) setSlot(null); })` 的 `whenComplete` **先**把 `_bookingTask` 置 null；随后 `inFlight.then(...)` 的回调才把 `_bookingTask` 设为新任务。**两个微任务之间 `_bookingTask` 是 null**。

若 `reservationChanged()` 正好落在这个空窗：`await null` 立即返回 → `loadBookings(force: true)` 看到 `slot() == null` → **并发启动第二次强制读**，与仍在链上的那次强制读重叠。

**修法**：让 `_chainForced` 在 `inFlight` 完成时**同步**接管 slot（不要先置 null 再设回），或让 `reservationChanged()` 等待 `_bookingForcedRun ?? _bookingTask` 而不是只等 `_bookingTask`。

### 3.4 【P1】✅ 已修复（2026-10-28）`LibraryController.perform()` 的 `uncertainActions` 闩死

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-09。只有 `uncertain` 保持封锁；新增 2 条回归（accepted 解除 / uncertain 保持）。


```dart
uncertainActions.add(key);                 // 写之前就锁上
…
if (result.state == 'notSubmitted' || result.state == 'rejected') {
  uncertainActions.remove(key);            // 只有这两种会解锁
}
```

`accepted` **不解除**封锁 → 该操作在当前 controller 生命周期内**永远点不动**。设计意图是"结果需回查确认"，但页面**没有提供"我已核对，解除封锁"的入口** → 用户看到一个永久禁用的按钮，没有解释。

**修法**：在回查（`reservationChanged()` → `loadBookings`）成功后，若该 booking 已在列表中且状态与动作一致，则解除封锁；或给出明确的"已确认"提示与手动解锁入口。

### 3.5 ✅ 已修复（2026-10-28）【P2】12 个读页面没有代次守卫，也没有 `didUpdateWidget`

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-12。下列页面均有失效与服务替换处理，并有 10 项新增迟到响应回归覆盖剩余页面。

| 页面 | 代次守卫 | `didUpdateWidget` |
| --- | --- | --- |
| `features/grades/grades_page.dart` | ✓ | ✓ |
| `features/schedule/schedule_page.dart` | ✓ | ✓ |
| `features/homework/homework_page.dart` | ✓ | ✓ |
| `features/cgyy/cgyy_page.dart` | ✓ | ✓ |
| `features/cgyy/cgyy_day_page.dart` | ✓ | ✓ |
| `features/checkin/checkin_page.dart` | ✓ | ✓ |
| `features/library/library_area_page.dart` | ✓ | ✓ |
| `features/library/library_slot_page.dart` | ✓ | ✓ |
| `features/library/library_seat_page.dart` | ✓ | ✓ |
| `features/library/library_holdings_page.dart` | ✓ | ✓ |
| `features/library/library_history_page.dart` | ✓ | ✓ |
| `features/learning/learning_snapshots_page.dart` | ✓ | ✓ |

**账号切换**目前靠 Rust 侧复检兜底（`homework_service.rs:51,110`、`schedule_service.rs:286,337,367,382,457`、`classroom_service.rs:80`、`graduate_service.rs:94`、`checkin_service.rs:181,209`、`bykc_service.rs:61`），迟到响应会变成 `session_expired` → **不会串号** ✓。

**但服务替换**（demo↔live、账号切换后重建页面）时：页面不清空旧状态、也不丢弃在途响应 → 可能显示上一个服务的数据。

已有守卫的页面：`shuttle_page`（8 处代次）、`library_books_page`（6）、`campus_card_page`（4）、`library_page`（经 `LibraryController`）、`career_events_page`、`campus_activities_page`、`notices_page`（无代次但公共读）。

**修法**：这 12 个页面统一补 `int _generation` + `didUpdateWidget` 里 `generation++` 并清空旧状态；这也是 §「设计语言与模块布局」里"7 个手写状态机迁到 `RefreshSection`"的一部分。

### 3.6 ✅ 已修复（2026-10-28）【P2】`checkin` 的请求门控让**不同日期**的读互相排队

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-13。按日期独立闸门，同日仍合并认证与快照。

```rust
// ginkgo_upstream/src/services/checkin_service.rs:123
let _gate = self.checkin_request_gate.lock().await;
```

`load_checkin_on_date` 与 `load_checkin_today` 共用这一个 gate。注释说明是为了共享一次 app 登录与快照，但结果是**查 10 月 28 日和查 10 月 29 日会互相阻塞**。

**修法**：门控只保护"登录与快照写入"这一段，网络读取放到门外；或按日期 key 化（`DashMap<date, Mutex>`）。

### 3.7 ✅ 已修复（2026-10-28）【P2】`silent_login` 的 `recovery_gate` 跨整个 CAS 链

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-14。学校会话与 WebVPN 恢复已拆成独立 single-flight。

```rust
// ginkgo_upstream/src/services/session_service.rs:225
let _recovery = self.recovery_gate.lock().await;   // 持到函数结束
…
let result = match auth::login(&self.session, &credentials).await { … };
```

CAS 链最多 30 秒 × 多次重定向。**所有需要静默续期的读都串行在这一个 gate 上**：一个学期的课表读触发静默登录时，其它模块的读全部排队。

**好的一面**：避免并发 CAS 打爆学校、避免多个静默登录互相作废。
**坏的一面**：一次慢 CAS 会让多个模块同时变慢。

**修法**：把 gate 缩小到"发起登录"这一小段（登录本身可以并发但要用 generation 保护），或加"同一账号只允许一个在途登录"的 single-flight（当前 `recovery_gate` 实际上就是这个作用，只是范围过大）。

---

## 4. 回调

### 4.1 Android MethodChannel 线程模型

5 个通道：

| 通道 | 处理线程 | 磁盘 IO | 风险 |
| --- | --- | --- | --- |
| `learning-snapshots` | `makeBackgroundTaskQueue()` | `commit()` ×2 | ✓ |
| `homework-files` | 自建单线程 executor | executor 内 | ✓ |
| `update` | 自建 executor + `main.post` | executor 内 | ✓ |
| `system` | 主线程 | `apply()`（异步） | ✓ |
| `reminders` | **主线程** | **`commit()` ×2（同步 fsync）** | ✗ §1.6 |

### 4.2 Dart → Rust 的回调不阻塞 platform thread

FRB 用 `wrap_async` + `SseCodec`（`frb_generated.rs:55` 起），Rust future 在 tokio 上跑，完成后经 Dart event loop 回调 → **不阻塞 Android 主线程** ✓。

但代价是：Rust 侧任何挂起都会变成 **Dart 侧永不完成的 Future**（§1.2），而 Dart 侧没有超时兜底。

### 4.3 ✅ 已修复（2026-10-28）`unawaited` 的使用

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) R-17/R-18。偏好恢复有一分钟上界和可见失败提示，全部调用点已复核。

| 位置 | 是否安全 |
| --- | --- |
| `reminder_scope.dart` | ✓ 恢复超时后使用默认偏好并继续激活 |
| `reminders.dart:170` `unawaited(_save())` | ✓ `_save` 自带 `catchError` → 转为 `hint` |
| `today_page.dart:78,190`、`homework_page.dart:145`、`checkin_page.dart:140` | ✓ `reconcile()` 内部 try/catch |
| `workspace_shortcut_preferences.dart:54` | ✓ 偏好写入失败合流，不形成未处理异常 |

### 4.4 纯 Dart 的更新路径是干净的

`update_gate.dart:79-85` 三段 `.timeout(4s)` + `catch` 返回 null（放行）；`startup_update.dart:37` 的 `timeout(…, onTimeout: () { expired = true; return null; })` 并在之后用 `expired` 丢弃迟到结果 ✓ —— 这是全仓最规范的超时处理，可以作为其他地方的模板。

---

## 5. 建议收敛顺序

**第一批（治本，改动小、收益最大）**

1. **把锁获取移进超时预算**（§1.1）：`bounded_read` / `bounded_session` / `bounded_submit` 改为包住"取锁 + 干活"的整体。这是唯一能让 45/90 秒预算真正生效的改法。
2. **Dart 侧给全部 FFI gateway 加超时兜底**（§1.2）：在 `infrastructure/native_*.dart` 统一包 `Future.timeout`，映射为 `serviceUnavailable`。
3. **`edit_tasks` 加超时**（§1.3），并把 fsync 移入 `spawn_blocking`（已是）但显式放弃超时任务。
4. **`reminders` 通道改后台线程**（§1.6），与 `update` 通道一致。

**第二批（消除闩死）**

5. **给 busy 标志加看门狗**（§3.1）：`RefreshSection` / `LibraryController` / `ReminderController` / `homework_files_panel` 等，超时自动复位并提示。
6. **`reconcile()` 加 in-flight 合并**（§3.2）。
7. **修 `_bookingTask` 空窗竞态**（§3.3）与 `uncertainActions` 封锁（§3.4）。
8. **12 个读页面补代次守卫 + `didUpdateWidget`**（§3.5）。

**第三批（消除阻塞与隐式依赖）**

9. **作业文件 journal 的 fsync 移出 worker**（§1.4）：journal 改成不持锁的同步函数，由 `spawn_blocking` 承载。
10. **`sign_out` 的 Keystore 部分移出全局写锁**（§1.5）。
11. **`library_mutation_service` 补账号复检**（§2.3），并在 bridge 写路径加注释 + 一条 bridge 层回归。
12. **给"守卫不跨 await"加门禁**（§2.4）。
13. **`checkin` 门控按日期 key 化**（§3.6）、**`silent_login` 的 gate 缩小**（§3.7）。

**第四批（补测试）**

14. 每个读命令的"锁等待超时"回归（Rust）。
15. ✅ "Rust 命令挂起 → Dart 页面可恢复"回归已完成（R-21，真实 `boundedNative` 包裹永不完成的 Future）。
16. "写操作在途时切账号 → 写被判为 session_expired"回归（bridge 层）。
17. "定时器与 in-flight 合并"回归（Dart）。

---

## 6. 与既有结论的关系

- `MIRROR-TODO` P0「给所有读命令加超时上界」：**覆盖不完整**。`bounded_read` 只包住服务内的工作，锁等待无界（§1.1）；Dart 侧完全没有超时（§1.2）。
- `MIRROR-TODO` P0「消除 16 处 `if (busy) return;` 静默丢弃刷新」：已改为"飞行中记录待刷新"，但**没有解决"飞行中永不落地"**（§3.1）—— `busy` 闩死后 `_pendingRefresh` 永远不会被消费。
- `MIRROR-TODO` P0「上游读路径补 await 后账号复检」：**覆盖到位**，但复检不是唯一防线 —— 图书馆写路径依赖 FFI 锁，测试没覆盖到那层（§2.3）。
- 2026-10-25 工程债审计 §3.2「`std::sync::Mutex` 用在 async 上下文」：复核结论是**当前无违规**，但缺门禁（§2.4）。
- 2026-10-25 工程债审计 §3.1「写路径与会话路径无超时上界」：会话路径已有 90 秒预算，写路径已有 90 秒预算 ✓；但**锁等待**这一层没被算进去（§1.1）。

## 7. 整改台账

本篇的整改状态统一维护在 [三轮审查整改台账](2026-10-28-review-remediation.md)；每修完一项在台账里记「改了什么 / 为什么 / 什么证据锁住」，并在对应小节加 `✅ 已修复` 标记。

本文只描述源码结构，不代表功能已发布或已通过真实账号验收。

# 工程债与非标准实现审计

审计日期：2026-10-25。基线 commit：`ad7b2ad`（Android Alpha.8 发布）。方法：6 个只读探查代理分域审计 Flutter 层、Rust 层、契约/桥接层、构建 CI 层、冻结 Apple 层、测试层，各项结论经抽样复核；本文只记录审计中**亲自复核过**的关键断言，其余标注为代理发现。

本文与 [MIRROR-TODO](../MIRROR-TODO.md) 的关系：TODO 记录**待办**，本文记录**审计账本**。每条债务标注 `[已登记]`（TODO 已有对应条目）/ `[新增]`（TODO 未覆盖）。TODO 中标 `[x]` 完成但实际存在缺口的，在 §11 单列。

---

## 0. 摘要

按"会不会造成用户可感知故障或数据损失"排序，本仓库的工程债集中在**一个结构性事实**上：

> **跨层胶水层几乎裸奔，而两端的测试都测不到它。**

Rust 上游有 270 个用例 + 145 份契约 fixture；Dart 有 337 个 widget 用例。但 `ginkgo_flutter_bridge` 2737 行只有 **4 个 `#[test]`**，其中 `api/live/mapping.rs`（418 行、10 个 DTO 映射函数）只有 2 个测试且**只测通用信封 `read_only_response`**。`api/mirror.rs`(468)、`api/live/library.rs`(335) 零测试。同时 Dart 侧 8 个 `*_models.dart` 零直接测试、13 个 `FailureCode` 有 10 个在 Dart 侧零命中。

后果是具体的：`mapping.rs` 把 `MutationState::Uncertain` 写成 `"accepted"`，Rust 的 270 个测试和 Dart 的 337 个用例**都不会红**，而这直接违反"结果不明禁止自动重发"这条写操作红线。

其余高危项集中在三处：写路径与会话路径无超时上界且持有会话写锁；架构门禁漏扫 `ginkgo_domain/src/features` 导致学校协议字段名长期住在领域层；最低版本门禁文件根本不在 `main` 分支因而线上从未生效。

Apple 侧冻结**没有丢失用户可感知功能**（唯一领先的是 macOS 菜单栏/快捷键/就地更新，而就地更新恰恰是全仓最大的安全债），代价是三笔持续账单：26,979 行重复协议实现必然漂移（已实测漂移出 5 处语义分叉）、每个 PR 烧两个 macOS runner（≈3300 runner-min/月）、以及**零门禁**意味着未来每次契约变更都可能静默打破 Apple 端。

---

## 1. 跨层胶水层（最高风险）

### 1.1 `ginkgo_flutter_bridge` 的 DTO 映射层无有效覆盖 `[新增]`

| 文件 | 行数 | `#[test]` |
|---|---|---|
| `api/live/mapping.rs` | 418 | **2**（只测 `read_only_response`） |
| `api/mirror.rs` | 468 | **0** |
| `api/live/library.rs` | 335 | **0** |
| `api/live.rs` | 376 | 1 |
| `api/live/{academic,bykc,checkin,classroom,graduate,homework,session}.rs` | 合计 513 | **0** |
| `api/mirror/{academic,classroom,library}.rs` | — | **0** |
| **crate 合计** | **2737** | **4** |

具体不可见的失效：

- `mapping.rs:88-98` 签到三态映射（`Signed` / `NotSigned` / `…`）写错 → 无红灯。
- `mapping.rs:9-15` `MutationState` → 四态字符串，把 `Uncertain` 写成 `"accepted"` → 上层把"结果不明"当"已受理"，**直接击穿 AGENTS.md 写操作红线**，且两侧测试都测不到。
- `mapping.rs:180-215` 课表/考试 13 字段逐字段拷贝，任何字段名错位不可见。
- `mapping.rs:250-262` `longest_run as i32` 截断不可见。

**对照**：`ginkgo_core/tests/workspace_ports.rs:47-49`（断言具体值 + 失败码 + 调用次数）是全仓正确范式，bridge 层没有采用。

### 1.2 字段在三处以手写重复声明，且无 parity 测试 `[部分已登记]`

domain 字段 423 + bridge DTO 字段 227 + Dart 展示模型字段 174 ≈ **824 次手工声明**（≈400 个概念，**2.05× 重复**）。

加一个字段的类型化实体需要改 **4 处 / 4 文件 / 2 crate**：domain struct + bridge DTO struct + live 映射 + demo 映射（live 与 demo 各写一遍映射，如 `ScheduleCourse` 在 `live/mapping.rs:184` 与 `mirror/academic.rs:70`）。

TODO P2 已登记"为 9 个端点补 bridge DTO，删掉 Dart 里的 `jsonDecode`"。**新增细节**：B 轨（`ReadOnlyResponse.payload` JSON 袋）下的 Dart 模型有 **145 处无校验 `as` 强转**，集中在 5 个文件（`cgyy_models.dart` 45、`bykc_models.dart` 41、`graduate_models.dart` 19、`library_stats_models.dart` 12、`shuttle_models.dart` 11），**零 schema 校验**。上游字段改名为可空 → Dart 抛 `TypeError` 而非返回 `changedResponse`，页面白屏而非显示"数据格式无法识别"。

### 1.3 表现层直接持有学校协议语义 `[部分已登记]`

TODO P2 已登记"把稳定业务规则搬回 `ginkgo_domain`"（列了 `reminder_rules.dart`、`homework_projection.dart`、UTC+8 今天）。**新增的其他同类项**：

| 泄漏 | 位置 | Rust 侧对应 |
|---|---|---|
| 校园 ID `xqid` 与其中文映射 | `flutter/lib/classroom_page.dart:51` `int campus = 1`、`:292` `{1:'学院路',2:'沙河',3:'杭州'}[n]!` | `ginkgo_upstream/src/adapters/classroom_http.rs:34` `?xqid={campus}` |
| CGYY 教务审批码语义 | `flutter/lib/cgyy_models.dart:73-101`（`orderStatus` 1/2/3、`checkStatus` -2..-6） | `ginkgo_domain/src/features/cgyy.rs:31-42` 只有原始 int |
| 博雅考勤/通过码 | `flutter/lib/bykc_models.dart:122-133` | `ginkgo_domain/src/features/bykc.rs` 未定义 |
| 班车"今天适用"周次规则 | `flutter/lib/shuttle_models.dart:38-80` | `ginkgo_domain/src/features/shuttle.rs:19-23` 只传原始 label |

CGYY 审批码是**三端三份**（Dart / Rust 原始 int / Swift `CgyyModels.swift`），Dart 那份还是语义最完整的。

### 1.4 契约面含未类型化 JSON 袋 `[已登记 P2]`

`api/live.rs:205-209` 的 `ReadOnlyResponse { payload: Option<String>, … }` 被 9 个端点使用；12 个页面文件直接消费 `payload`。`scripts/check-mirror-architecture.py:77-78` 又显式豁免 `*_models.dart` 的 `jsonDecode` —— 等于给"新页面加一个 `_models.dart`"开了一条命名即豁免的后门。

---

## 2. 分层与领域边界

### 2.1 `ginkgo_core` 是空转发壳，业务编排实际住在 upstream `[新增]`

`ginkgo_core/src/application/mod.rs:16-18` 的 `Workspace<U>` 只有 `upstream` 一个字段；**42 个 public fn 中 37 个是 `self.upstream.xxx(...).await` 纯转发**（`application/library.rs` 8/10、`session.rs` 6/6、`academic.rs` 4/4、`checkin.rs` 4/4）。

真正含应用规则的只有 3 处：`application/cgyy.rs`(141 行)、`application/bykc_projection.rs`(57)、`application/tasks_service.rs`(166)。

而缓存 TTL、stale 快照回退、`silent_login` 重试、await 后账号复检这些**真正的应用规则**在 `ginkgo_upstream/src/services/`（19 处 `current_account()? != account`、13 处 `silent_login().await`）。

这与 AGENTS.md 声明的 `ginkgo_core = 应用命令、业务投影` 不符。后果：`ginkgo_core` 的存在**无法阻止** upstream 继续长业务逻辑，core 又提供不了任何保护。

**修复方向**：把 11 个 service 重复 19 次的"读 → 缓存 → 账号复检 → 落快照 → 失败回退旧快照"五步模板抽成 core 的一个泛型抽象。`ginkgo_upstream/src/services/cache.rs:114-136` 的 `resolve_current` 已经是一个完整抽象，但**只有 1 处 service 在用**，其余 10 个各写变体。

### 2.2 架构门禁漏扫 `ginkgo_domain/src/features` `[新增]`

`scripts/check-mirror-architecture.py:42`：

```python
for directory in ['rust/crates/ginkgo_core/src', 'rust/crates/ginkgo_domain/src/ports']:
```

**`ginkgo_domain/src/features` 不在扫描范围内**，而学校协议字段名正住在那里：

- `ginkgo_domain/src/features/classroom.rs:9-11` — `floorid` / `kxsds`（buaafreeclass 原始字段名），且 `Room` derive(Deserialize) 被 `ginkgo_upstream/src/codecs/classroom.rs:11-14` **直接反序列化学校 JSON**。
- `ginkgo_domain/src/features/library.rs:54-62` — `booking_type` / `can_cancel` / `flag_in` / `flag_out` / `flag_leave`（booking.lib v4 原始字段）。
- `ginkgo_domain/src/features/library.rs:87-89` — 学校状态码 `["6","8"]` + 中文字面量 `["取消","结束","已完成","过期","失效"]`。
- `ginkgo_domain/src/features/grades.rs:60` — `"百分制"`。

门禁里**现成**就有学校 URL 正则 `https?://[^\s"<>]*buaa`（`:43`），扩一个目录即可封住。

### 2.3 错误分类退化为字符串比较 `[新增]`

`AppError.detail: Option<String>`（`ginkgo_domain/src/lib.rs:31-34`）承载机器判定语义，用裸字符串跨模块比较：

- `ginkgo_upstream/src/services/session_service.rs:274` — `error.detail.as_deref() == Some("library_login")`
- `ginkgo_upstream/src/services/homework_service.rs:36`、`checkin_service.rs:104`、`library_service.rs:70` — 比较 `Some("webvpn_login_required")`

活跃的魔法字符串 4 个：`"webvpn_login_required"`、`"library_login"`、`"library_rejected"`、`"rate_limited"`。改一个字面量跨 crate 分支静默失效，编译器无法发现。

`CgyyActionResult { state: String }`（`ginkgo_domain/src/features/cgyy_booking.rs:80`）更严重 —— `ginkgo_core/src/application/cgyy.rs:118` 接受 `"accepted"｜"rejected"｜"notSubmitted"｜"not_submitted"`，**同一语义两种拼写并列**；upstream 侧 15 处 `CgyyActionResult::message("...")`。

对照同仓 `MutationState`（`features/mutation.rs:7-13`）已是正确范式，CGYY 没沿用。

### 2.4 `TransportError` 只有一个变体 `[新增]`

`ginkgo_upstream/src/foundation/http.rs:98-100` — `enum TransportError { Unavailable }`。6 处 `.map_err(|_| TransportError::Unavailable)` 把 DNS 失败 / TLS 失败 / 连接超时 / 读取超时 / body 解码失败 / 服务器 5xx **全部压平**。上层无法按错误类型分流重试策略。

### 2.5 `ginkgo_domain` 的纯规则测试跑在 upstream 里 `[新增]`

`grades::summarize` 的测试在 `codecs/grades.rs:113`，`grades::term_parts` 在 `codecs/grades.rs:79-91`，`bykc::current_semester` 在 `adapters/bykc_http.rs:182`，`schedule::retain_weeks` 在 `services/mod.rs:79`。

domain 本身 16 个 feature 文件无测试模块、13 个 ports 文件零测试、169 个公开项中 **152 个（90%）无文档注释**（`ports/` 15 个文件全部零注释 —— 而 ports 正是跨 crate 公共 API 面）。5 个核心结果类型 `ScheduleOutcome` / `TodayOutcome` / `GradeOutcome` / `HomeworkOutcome` / `LibraryStatsOutcome` **全无 `Debug` / `PartialEq`**，导致测试里无法 `assert_eq!`、panic 时无法打印。

---

## 3. 异步与错误处理

### 3.1 写路径与会话路径无超时上界 `[新增]`

`ginkgo_flutter_bridge/src/api/live/runtime.rs:21-26` 的 `bounded_read`（45 秒）覆盖 29 处**读**命令。**未覆盖**（已复核）：

| 命令 | 位置 |
|---|---|
| `login` / `restore` / `sign_out` | `api/live/session.rs` |
| `submit_checkin` | `api/live/checkin.rs` |
| `reserve_library_seat` / `perform_library_action` | `api/live/library.rs` |
| `execute_cgyy` | `api/live/utilities.rs` |

`login` / `restore` 内部跑完整 CAS 链（`auth/login.rs` 最多 9 跳 + `auth/mod.rs:complete_login` 最多 11 跳 + `auth/uc.rs` 最多 11 跳），每跳 30 秒（`adapters/reqwest_transport.rs:29`），**最坏约 930 秒**；而它们持有 `SESSION_ACCESS.write()` 锁（`session.rs:10/34/63/72/87`）—— 一旦卡住，所有其它命令全部阻塞。

TODO P0 已登记"给所有读命令加超时上界"并标 `[x]`。**新增**：写/会话路径的同类缺口。

### 3.2 `std::sync::Mutex` 用在 async 上下文，且毒化恢复会静默清空会话 `[新增]`

`ginkgo_upstream/src/foundation/mutex.rs:9` 是 **std Mutex 包装**，upstream 的 `identity`（含 `authenticated`、session token）、`snapshots.*`、`cgyy_safety` 全在 async fn 里用它。`ginkgo_core/src/tasks_store.rs:11`、`cgyy_pending_store.rs:15` 同。

当前**没有**实际的跨 await 违例（已做括号配平全仓扫描 + 人工复核），但：

`foundation/mutex.rs:11-27` 的毒化恢复把值**重置为 `T::default()`**：

```rust
Err(poisoned) => {
    let mut guard = poisoned.into_inner();
    *guard = T::default();       // ← 数据被静默清空
```

对 `Identity` 而言，**任何一次 panic 都会静默把用户登出**（丢 `authenticated`、token、generation），且无任何日志。

`ginkgo_upstream/src/services/cgyy_booking_service.rs:348`（`identity` guard）与 `:352/:369`（`cgyy_safety` guard）嵌套持有两把 std Mutex，函数末尾无 await 但结构脆弱 —— 将来有人在末尾插入 `.await` 就是死锁。

TODO P2 已登记 `tasks_store` / `cgyy_pending_store` 的"阻塞 fsync + 全局锁"。**新增**：upstream 侧 `foundation/mutex.rs` 的毒化语义与嵌套持锁。

### 3.3 阻塞 fs IO 在 tokio worker 上 `[已登记 P2]`

`ginkgo_core/src/cgyy_pending_store.rs:57-121`（含 `output.sync_all()` + 目录 fsync）与 `ginkgo_core/src/tasks_store.rs:21-44` 是同步函数，被 `ginkgo_core/src/application/cgyy.rs:67,81,87,93,95,120` 的 async fn 直接调用，**无 `spawn_blocking`**（全仓零命中）。`execute_cgyy` 走 FRB 的 `wrap_async` → 落在 tokio worker 上，确实阻塞。

### 3.4 嵌套 tokio runtime `[新增]`

`ginkgo_upstream/src/adapters/reqwest_transport.rs:47-52` 新建一个 **2-worker 的 tokio MultiThread runtime**，通过 `handle.spawn` 执行请求。这与 FRB 的 tokio runtime 并行存在。后果：`bounded_read` 的 45 秒计时器跑在 FRB runtime，请求跑在私有 runtime，**超时取消跨 runtime**，`AbortOnDrop`（`:91-96`）的 abort 语义要跨 runtime 生效。

### 3.5 3 处真实的 `setState` after dispose / `BuildContext` 跨 async gap `[新增]`

已复核 `flutter/lib/settings_page.dart:87-92`：

```dart
Future<void> _changeRoute(RouteChoice route) async {
  if (busy || route == _route) return;
  if (!await _confirm('切换网络路线？', ...)) {   // ← await 弹出对话框
    return;
  }
  setState(() => busy = true);                  // ← 无 mounted 检查
```

`_clearCache`（`:113-119`）同样问题。同文件 `_signOut`（`:139-141`）**有** `if (!mounted) return;` —— 说明是遗漏而非约定。

`flutter/lib/tasks_page.dart:259/266` 的 `await sourceUnavailable()` 之后，`:269` 直接 `await Navigator.of(context).push(...)`，中间无 `mounted` 复查。

`flutter/analysis_options.yaml` 是 flutter_lints 默认模板，`use_build_context_synchronously` / `unawaited_futures` 仍是注释状态（`:33-35`）—— **没有任何 lint 会捕获这类问题**。

### 3.6 14 处零可观测性的空 catch `[新增]`

catch 体完全为空 7 处：`android_update_controller.dart:353`、`cgyy_captcha_page.dart:163`、`checkin_page.dart:220`、`library_controller.dart:154`、`network_diagnostics_page.dart:156`、`preferences_pages.dart:155`、`task_editor.dart:163`。

其中 `library_controller.dart:154-156` 的注释说 "The school may have received the request. Leave this action blocked." —— 设计意图合理，但**零可观测性**，连异常类型都不记录。

最糟的是 `flutter/lib/application/refresh_section.dart:71-74`：

```dart
} catch (_) {
  if (_disposed) return;
  DiagnosticLog.shared.record(null);   // ← 记录为 'localService'，完全丢失原因
```

所有读取失败在诊断页里都是同一个码。

TODO P2 已登记"Rust workspace 零日志可观测性"。**新增**：Dart 侧同样零，且 `refresh_section.dart` 是所有用 `RefreshSection` 的页面的公共失败路径。

---

## 4. 展示层与状态管理

### 4.1 同一业务规则 4 种状态管理模式 + 3 套竞态队列 `[新增]`

`flutter/pubspec.yaml` 无 provider / riverpod / bloc；全仓 `lib/` 零命中。实际并存 5 种：

| 模式 | 实现 | 使用者 |
|---|---|---|
| `ChangeNotifier` + 手写 `InheritedNotifier` | 10 个类（`app_preferences.dart:59`、`reminders.dart:31`、`library_controller.dart:9` 等） | — |
| `RefreshSection<T>` | `application/refresh_section.dart:13-88` | 仅 today 系列 3 个 section |
| `LibraryController`（自研） | `library_controller.dart:9-169` | library 3 个页面 |
| 自研快照对象 | `bykc_page.dart:29-38` `_BykcSnapshot` | bykc |
| `setState` + `busy/error/generation` 三元组 | — | **约 25 个页面** |

「读取 → 失败 → 保留旧值 → 重试 → 强制刷新不丢失」这条规则被实现 4 遍。强制刷新竞态队列被实现 3 遍：`application/refresh_section.dart:24-56`、`library_controller.dart:33-77`、`bykc_page.dart:29-38+63-69`。

TODO P2 已登记"其他异步复杂页面参考 `LibraryController`…不要求一次性统一重构"。**新增**：竞态守卫的命名已分裂成 6 种 —— `requestSerial`（`checkin_page.dart:124`）、`serial`（`cgyy_day_page.dart:61`）、`generation`/`epoch`（`classroom_page.dart:55`）、`requestId`（`schedule_page.dart:70`）、`request`（`cgyy_day_page.dart:47`）、`_generation`（`today_page.dart:83`）。搜索"账号切换守卫"需要同时试 6 个名字。

### 4.2 重复脚手架量化 `[新增]`

`flutter/lib/*.dart` 18 类脚手架标记、约 150 个复制点，分布在 24–41 个页面文件：

| 标记 | 命中文件数 |
|---|---|
| `catch (_) {` | 41 |
| `setState(` | 40 |
| `GinkgoActivity(` | 33 |
| `bool busy` / `bool loading` | 32 |
| `String? error` | 29 |
| `GinkgoLoadingView(` | 23 |
| `AppleEmptyState(` | 21 |
| `AppleGlassButton(`（刷新按钮） | 19 |

逐字重复的具体块：

- **刷新按钮 20 份手工复制** —— `homework_page.dart:192-198`、`classroom_page.dart:267-273`、`checkin_page.dart:254`、`shuttle_page.dart:205`、`library_*.dart` 7 份等；且 `size: 24` / `size: 22` / 无 size 三种写法混用。
- **`_pendingRefresh` 竞态补丁 5 份逐字相同** —— `cgyy_page.dart:33-37,72-76`、`homework_page.dart:130,172-176`、`homework_detail_page.dart:65,96-100`、`library_stats_page.dart:35,78-82`、`notices_page.dart:32,59-63`。
- **900px 居中 SliverLayoutBuilder 2 份逐字相同** —— `grades_page.dart:422-426`、`graduate_page.dart:422-426`。
- **中文文案字面量跨文件重复** —— `'${failureMessage(result.failure)}，正在显示上次结果。'` × 5（`checkin_page.dart:159`、`classroom_page.dart:153`、`grades_page.dart:71`、`homework_page.dart:154`、`schedule_page.dart:122`）；`'请检查网络后重试。'` × 5；`'没有匹配的课程'` × 3；`'Ginkgo 银杏'` × 3。

`loading_widgets.dart:156-215` 的 `SectionFeedback`（通用 loading/error/retry 横幅）**只被 6 个文件使用**，其余 20+ 页面手写 `AppleEmptyState(error: true, …)`。

### 4.3 设计 token 被系统性绕过 `[已登记 P2，新增量化]`

TODO P2 已登记"96 个应用 Dart 文件中 62 个零引用，硬编码 202 处 fontSize / 204 处 EdgeInsets"。**新增细节**：

- **7 个 token 是死代码**（引用数 = 0）：`accentSubtle`、`windowBackground`、`groupedBackground`、`tertiarySystemFill`、`separator`、`borderLight`、`panelBorder`（`design/tokens/colors.dart:12-33`）。
- **`statusUncertain` 与 `statusInactive` 逐字节相同**（`colors.dart:52-56` 与 `:62-66` 都是 `0xff4a4f58` / `0xffc4c8d0`）。
- **字阶越界 34 处** —— token 定义 9 档（34/26/22/17/17/14/13/12/11），实际有 `fontSize: 15` × 21、`16` × 13 不在表内。
- **圆角越界 18 处** —— token 定义 pill=2/badge=7/button=8/navigationItem=10/panel=12/dialog=18/group=26，实际有 `24`(×4)、`14`(×4)、`3`(×3)、`16`(×3)、`6`、`5`、`4` 不在表内；`classroom_page.dart:312` 甚至把 `GinkgoRadii.group`(26) 写成 `24`。
- **共享组件自己也不遵守 token** —— `widgets/apple_surfaces.dart:147` `EdgeInsets.symmetric(vertical: 36, horizontal: 16)`、`:155` `size: 44`、`:162` `fontSize: 20`、`:169` `fontSize: 15`。

TODO 已指出"根因是门面过窄而非页面懒惰"。审计支持该判断，并补充：**死 token 与重复 token 说明门面本身没有做过一次收敛审计**。

### 4.4 `lib/` 根目录承担过多职责 `[新增]`

`flutter/lib/` 根目录 **98 个文件** vs `application/` 7 个、`infrastructure/` 4 个、`workspace/` 4 个、`widgets/` 3 个、`design/` 7 个。

混杂在根目录的：

- **平台适配器** —— `android_update_controller.dart`（**359 行**，HTTPS 下载 + SHA-256 校验 + APK 安装 + isolate）、`update_gate.dart`（234 行，HTTPS 拉取 + JSON 解析）应在 `lib/infrastructure/`。
- **领域控制器** —— `library_controller.dart`(169)、`reminders.dart`(385)。
- **共享组件** —— `loading_widgets.dart`(249)、`academic_widgets.dart`(150)。
- **特性 widget** —— `checkin_widgets.dart`(303)、`graduate_widgets.dart`(349) 等 7 个文件 1417 行，定义了 10+ 个「行」控件，与 `widgets/apple_surfaces.dart:275` 的 `AppleListTile`（被使用 129 次）功能重叠。

### 4.5 平台分支做得对，但有死代码与包体问题 `[新增]`

**做得好的部分**：`Platform.*` 全仓仅 **8 处**，集中在 4 个文件，**没有散落在页面里**。3 个 MethodChannel 各自收敛（`cn.edu.buaa.ginkgo/system`、`/reminders`、`/update`）。

**问题**：

- `flutter/integration_test/ios_visual_refinement_test.dart`（**238 行**，1 个测试）在 `flutter/` 下**没有 `ios/` 目录**的前提下**永远无法执行** —— 纯死代码。
- `flutter/pubspec.yaml:21` 把 `path_provider_android: 2.2.22` 精确 pin 成**直接依赖**（注释写 "Retain the Kotlin plugin path and the project NDK 27 toolchain"）—— 这是把平台实现包当 app 依赖锁版本，Flutter 升级必炸。
- `flutter/pubspec.yaml:34` `uses-material-design: true`，但全仓只有 2 处 material import 且都只取 `SelectableText` —— Material 图标字体白白进包。
- **833 行"Apple"命名代码**（`apple_design.dart` / `apple_widgets.dart` / `widgets/apple_*`）用于一个 Android+Windows 产品，类名遍布 47 个 import 方。

### 4.6 服务定位器渗透页面，含一个真实 bug `[新增]`

**8 处**页面在内部自行构造服务：`tasks_page.dart:42`、`bykc_page.dart:75`、`notices_page.dart:40`、`graduate_page.dart:137`、`cgyy_page.dart:51`、`cgyy_day_page.dart:77`、`:108`。

`flutter/lib/cgyy_day_page.dart:106-110` 有真实 bug：

```dart
CgyyBookingGateway? get bookingGateway {
  if (widget.demo || widget.loader != null) return null;
  final source = widget.service ?? mirrorServiceFor(demo: false);   // ← 硬编码 false
```

写死 `demo: false`，忽略 `widget.demo`；与同文件 `:77` 的 `mirrorServiceFor(demo: widget.demo)` 行为不一致。

---

## 5. 测试与门禁

### 5.1 账号切换守卫：Rust 侧 6 个 service 无回归，Dart 侧 2 个核心控制器无守卫 `[已登记 P0，缺口新增]`

TODO P0 已把"上游读路径补 await 后账号复检"标 `[x]` 完成。审计复核结论：**实现覆盖了，但回归只有 1 个 service**。

| 层 | 实现 | 回归 |
|---|---|---|
| Rust bykc | ✅ | ✅ `bykc_service.rs:146` |
| Rust library | ✅ 7 处（`library_service.rs:46,113,176,224,242,278,318`） | ❌ **无** |
| Rust classroom | ✅ `:80-81` | ❌ **无** |
| Rust homework | ✅ `:51-52,110-111` | ❌ **无** |
| Rust graduate | ✅ `:79-80` | ❌ **无** |
| Rust schedule | ✅ `:286-287,337-338` | ❌ **无** |
| Dart today | ✅ `_generation` | ✅ `today_v2_widget_test.dart:392` |
| Dart 快捷键 | ✅ | ✅ `workspace_shortcuts_test.dart:253` |
| **Dart `LibraryController`** | ❌ **只有 `_disposed`，无账号代次守卫** | ❌ **无** |
| **Dart `RefreshSection`** | ❌ **只有 `_disposed`** | ❌ **无** |

`library_controller_test.dart`(76 行) 与 `refresh_section_test.dart`(117 行) 都没有账号切换场景。**改回旧行为不会有任何红灯**。

### 5.2 "清缓存 / 退登 vs 个人待办"边界完全无测试 `[新增]`

实现是对的（`ginkgo_upstream/src/services/session_service.rs:434-461` 与 `:247-256` 都不碰 `tasks_store.rs:12` 的账号命名空间文件），但：

- `flutter/test/cache_scope_test.dart:20-60` 只断言 `SettingsPage` 的 State **对象 identity** 变化，**完全不涉及待办数据**。
- **没有任何测试断言"退出登录后本地待办是否保留"**。
- `flutter/lib/settings_page.dart:139` 的退出确认文案只说"清除本机会话和已保存的密码"，**未说明待办去留** → 用户预期不明；`:115` 与 `:264` 的"账号和本地待办会保留"文案同样零断言。

这类边界一旦被改坏是**用户数据丢失**，且无任何自动化能发现。AGENTS.md §7 明确要求"清除查询缓存不得删除个人待办"。

### 5.3 Dart 侧失败码与模型层系统性缺测 `[新增]`

| 项 | 状态 |
|---|---|
| `FailureCode.businessRejected` | `flutter/test/` 与 `integration_test/` **零命中**；`application/failure_message.dart:20` 的"这不代表账号已退出"（明确的防误判语义）零断言 |
| 13 个 `FailureCode` | Dart 侧只有 `changedResponse` / `sessionExpired` / `serviceUnavailable` 3 个被走过 |
| `application/failure_message.dart`(23 行) | **零单测** |
| 8 个 `*_models.dart` | **零直接测试**；`notices_models.dart:6` 用 `as String` 硬转型，`library_books_models.dart:15-16` 用 `as int?` —— 上游改可空 → Dart `TypeError` 而非 `changedResponse` |
| `flutter/lib/cgyy_captcha_page.dart`(276 行) | **唯一零测试页面** —— 而它承载"写操作前的验证码门禁"这一安全敏感路径 |
| `lib/infrastructure/native_mirror_service.dart`(220 行) | **无测试** —— 真实 FFI 适配器 |
| `lib/widgets/` 三个文件(782 行) | **全部无测试** —— 而这正是应当被 25+ 页面共享的组件 |
| `lib/workspace_back_guard.dart` | 无测试 —— 含 `Timer(Duration(seconds:2))` 双击返回逻辑 |

### 5.4 4 个测试零断言 `[新增]`

`flutter/test/academic_page_loading_test.dart` 的 4 个用例（`'grades refresh shows the small branded leaf'` 等）**完全没有 expect**。

另有 10 处弱断言（只判非 null / 非空，不校验值）：`update_gate_test.dart:25`、`task_visual_test.dart:103,158`、`workspace_shortcuts_test.dart:205`、`library_hierarchy_refresh_test.dart:58,83`、`shuttle_page_test.dart:171`、`cgyy_booking_safety_test.dart:238,325,379`。

Rust 侧 `auth/session.rs:260`、`services/tests/session.rs:456`、`adapters/bykc_http.rs:217`（密码学 roundtrip 只断言 is_ok）同。

### 5.5 测试层绕过契约 `[新增]`

**48 / 73** 个 `flutter/test/` 文件直接 `import 'package:ginkgo_mirror/src/rust/api/mirror.dart'`（生成代码），而非通过 `application/contracts.dart`。契约桶形文件存在却无人使用。

### 5.6 共享 harness 藏在测试文件里 `[新增]`

`flutter/test/mirror_widget_test.dart`（1144 行 / 23 个用例）里的 `ControlledService` 被 **25 个测试文件** `import … show ControlledService`；`session_widget_test.dart:68` 的 `FakeService` 同理。

后果：修改 `mirror_widget_test.dart` 会同时改动 25 个文件的语义边界，而这个约定**没有任何文档或 lint 保障**。另有 55 个 fake/stub 类散布在约 35 个文件。

Rust 侧 `ginkgo_core` 有 **4 份各自实现的临时目录 helper**（`tests/tasks_homework.rs:9-28`、`tests/workspace_ports.rs:114`、`src/application/tasks_service.rs:102`、`src/application/cgyy/tests.rs:20-50`），只有 `TempRoot` 有 `Drop` 清理与路径安全断言，其余用 `unwrap()` 手动清理 —— panic 会残留临时目录。

### 5.7 无任何测试超时；集成测试不会误触真实网络（但有一个坑）`[新增]`

**无超时**：`flutter/test/` 与 `flutter/integration_test/` **无一个** `testWidgets(…, timeout: …)`，全部依赖框架默认。`flutter/test/` 共 **599 处 `pumpAndSettle`**。挂起的测试表现为 **job 超时（无定位信息）**，而不是精确的测试失败。

**真实网络防护**：机制有效 —— 两个 live 文件都用编译期 `bool.fromEnvironment` + `skip:`，其余 26 个集成文件全用 `DemoMirrorService`（已逐一核对 `grep NativeMirrorService` 只命中 2 个 live 文件）；`live_acceptance_test.dart:52-53` 强制 loopback。

**但有一个坑**：Dart VM 中 `bool.fromEnvironment` 对任何非 `"false"` 的值返回 `true`。`--dart-define=GINKGO_MANUAL_LIVE_NETWORK=0` 会**意外启用**真实网络验收。

### 5.8 契约测试的"未知契约失败"承诺无测试 `[新增]`

AGENTS.md 声明"未知契约失败"。实现位于 `ginkgo_upstream/src/services/contracts.rs:337`（返回 `ErrorCode::UnsupportedContract`），但**全仓零测试引用** `UnsupportedContract`，`execute_contract` 仅被 `tests/contracts.rs:32`（真实名）与 `demo_campus.rs:73`（`cgyy.{kind}`）调用 —— **无任何测试传不存在的契约名或 `version != 1`**。

且 `tests/contracts.rs:47` 的 `assert!(count >= 28)` 在 145 个 fixture 下形同虚设 —— **删掉 117 个测试仍会通过**。

### 5.9 架构门禁自测只覆盖 3/7 规则族 `[新增]`

`scripts/check-mirror-architecture-test.py` 有 8 个 unittest，但只覆盖 `dependency_violations`、`source_violations`、`payload_decode_violations` 三族。**无自测**的 4 族：`buaa.edu.cn` 域名规则(`:105`)、`src/rust/` import 规则(`:111`)、`NativeMirrorService`/`RustLib` 构造规则(`:117`)、`contracts.dart` export 规则(`:120-126`)。**任何人误改这 4 条正则，不会有任何测试失败**。

### 5.10 门禁在两个方向失守 `[新增]`

- **本地基线弱于 CI**：`scripts/check-mirror.sh`（20 行）**不含** FRB 生成漂移检查（CI `bindings` job 有 `git diff --exit-code -- flutter/lib/src/rust rust/.../frb_generated.rs`），也不含 Windows CMake 接线检查。AGENTS.md §4 把 FRB 重生成写成"仅当 bridge API 变化时"的手动步骤 —— 结果是本地"完整基线"允许 FRB 绑定漂移，而 AGENTS.md 同节又要求"Rust 动态库与 Dart 绑定必须配套构建"。
- **27/28 个集成测试不在任何门禁内**：CI 只跑 `integration_test/windows_test.dart`。`mirror_test.dart`(530 行)、`live_acceptance_test.dart`(766 行)、`android_product_iteration_test.dart`(228 行) 永不执行。

### 5.11 Rust 侧零测试模块 `[新增]`

| crate | 源码行 | 测试函数 |
|---|---|---|
| ginkgo_domain | ~3100 | **11**（18 个 feature 只覆盖 4 个） |
| ginkgo_core | 1523 | 32（16 个 application 模块只覆盖 3 个） |
| ginkgo_upstream | ~19000 | 270 ✅ |
| **ginkgo_flutter_bridge** | **2737** | **4** ❌ |
| **ginkgo_runtime** | **68** | **0** ❌ |

`ginkgo_runtime/src/lib.rs`（68 行组合根）零测试 —— 含 `create_service()`、`has_saved_accounts()`（MIRROR-TODO P0 称"保险库枚举失败不再视为空"，**无测试**）、`verify_credential_storage()`、`check_update()`。

`ginkgo_upstream/src/adapters/reqwest_transport.rs`（137 行，**唯一生产 HTTP 传输层**，含 `AbortOnDrop`、私有 runtime、scoped TLS、host 分流）**零测试**。

---

## 6. 构建 / CI / 发布

### 6.1 最低版本门禁线上从未生效 `[新增，P0 级]`

已复核：`docs/update-gate.json` **被 git 跟踪，但不在 `origin/main` 上**（`git ls-tree -r --name-only origin/main | grep update-gate` → 0 命中）；它只存在于 `feat/rust-flutter-mirror` 分支。

GitHub Pages 的部署源是 `main` 的 `/docs`。客户端 `flutter/lib/update_gate.dart:73-95` 对 404 / 非 JSON 一律返回 `null` → **完全放行**（fail-open 行为本身正确，但结果是门禁 100% 失效）。

叠加 `docs/update-gate.json` 的 `minBuild: 5`：已发布的 build 号是 alpha.3→4、alpha.4→5、alpha.5→6、alpha.6→7、alpha.7→8、alpha.8→9。`minBuild: 5` 只拦 build < 5，**alpha.4 ~ alpha.8 全部放行**。

风险是双向的：当前门禁无效；一旦把 `minBuild` 提到 10，`UpdateRequiredPage`（`update_gate.dart:135-160`）**只提供"打开发布页"和"重新检查"，没有跳过**，而 Android Alpha.8 是唯一含修复的公开包 → 大面积用户被锁死且无自救路径。

TODO P2 已登记"最低版本门禁已接入…提升 `minBuild` 前必须确认新版本已可下载"。**新增**：该清单根本没进 `main`，且 `minBuild` 数值偏低。

### 6.2 签名 Android release 在 CI 中从未成功过 `[已登记 P1，判定存疑]`

`.github/workflows/android-release.yml` 对四个签名 secret 做 fail-closed 检查，未配置即在签名步骤失败。TODO P1 把这写成"fail-closed 设计，非缺陷"。

**审计意见**：fail-closed 本身是对的，但后果是**唯一能验证 `flutter build apk --release`（含 R8/proguard、AOT、release-only Dart 路径）的通道长期红灯**，而 `mirror.yml:80` 只有 `--debug`。release-only 路径的破坏可以完全绕过 CI。同时 `AGENTS.md:274` 仍断言"当前没有自动 Android Release workflow" —— 与仓库现状直接矛盾（该 workflow 由 `90b2889` 引入）。

### 6.3 门禁有两个真源 `[新增]`

`scripts/check-mirror.sh:10-20` 与 `.github/workflows/mirror.yml:21-27,47-56` 是**命令级复制**：

| 检查项 | check-mirror.sh | mirror.yml |
|---|---|---|
| 架构规则 + 自测 | ✅ | ✅ |
| fmt / clippy / Rust 测试 | ✅ | ✅ |
| flutter analyze / test | ✅ | ✅ |
| **FRB 生成漂移** | ❌ | ✅ |
| **Windows CMake 接线** | ❌ | ✅ |
| **Windows 路径检查** | ❌ | ✅ |

往 `check-mirror.sh` 加检查不会进 CI；往 workflow 加检查本地门禁不知道。

### 6.4 工具链版本号被复制 9 处 / 6 处 `[新增]`

Rust `1.99.0` 出现在 **9 处**：`rust/rust-toolchain.toml:2`、`flutter/rust_builder/cargokit/build_tool/lib/src/builder.dart:149`（`const pinned = '1.99.0'`）、`scripts/check-mirror.sh:5-9`、`scripts/generate-mirror-bridge.sh:8-12`（后两者是逐字复制）、`.github/workflows/` 6 处。

`rust/rust-toolchain.toml` **只在 `rust/` 目录内被 cargo 自动读取**，仓库根跑 cargo 不生效 —— 这正是 CI 需要重复 6 次的原因。

Flutter `3.47.0` 出现在 6 处：`.fvmrc:2`（**CI 从不读取它**）+ 5 处 workflow 的 `flutter-version`。

### 6.5 Cargo.lock 在实际构建中不带 `--locked` `[新增]`

`flutter/rust_builder/cargokit/build_tool/lib/src/builder.dart:166-190` 调用 cargo 时**不带 `--locked`** → Android/Windows 的实际 release 编译可能改写 `Cargo.lock`。CI 的 `git diff --exit-code` 只覆盖 `flutter/lib/src/rust` 与 `frb_generated.rs`（`mirror.yml:51`），**不检查 `rust/Cargo.lock`** → release 产物不是锁定依赖的可复现构建。

`flutter pub get` 同样无 `--enforce-lockfile`，CI 也不 diff `pubspec.lock`。

### 6.6 Windows 发布产物携带 4 个版本号，其中 2 个是常量 `[新增]`

| 版本号 | 来源 |
|---|---|
| 外部文件名版本 | `windows-release.yml:56,62,93` 从 tag 派生，**从不与 pubspec 比对** |
| 安装器文件属性版本 | `packaging/windows/Ginkgo.iss:45-46` **硬编码 `0.1.0.4`** |
| EXE 内部版本 | `flutter/pubspec.yaml:4` = `0.1.0-alpha.8+9` |
| Release 标题与正文 | `windows-release.yml:119-120` **硬编码 alpha.6** |

对照 `android-release.yml:84-93` **有**正确的 tag↔pubspec 一致性校验。

另外 `windows-installer.yml:14-16,106-116` 会在 `feat/rust-flutter-mirror` 分支上、只要 `packaging/windows/**` 变更就自动跑，并把新构建的安装器**写回已公开发布的 `windows-v0.1.0-alpha.4` Release**。

### 6.7 CI 可靠性 `[新增]`

- **action 版本几乎全部未固定到 SHA** —— 7 个 workflow 共 21 处 `uses:`，**只有 1 处**固定到 SHA（`mirror.yml:36`）。`dtolnay/rust-toolchain@master` 用的是分支名（6 处）。
- **`concurrency` 只覆盖 2/7 workflow** —— `mirror.yml`、`android-release.yml`、`windows-release.yml`、`windows-installer.yml`、`release.yml` 全无。实跑证据：同一 PR 连续三次跑完整 4-job 矩阵。
- **无 cargo / gradle 缓存** —— 每次都从源码编译 `flutter_rust_bridge_codegen` + `cargo-expand`（数分钟）。
- **无 step 级超时** —— `windows-release.yml:13` 的 50 分钟 job 里含全量 widget test + 集成测试 + release 编译 + Inno 编译 + 静默装卸。
- **`git diff --check` 只在 Apple 两个 workflow** —— `mirror.yml` 与三个 release workflow 都没有。
- **`packaging/**` 改动不触发任何 CI** —— `mirror.yml:6,8` 的 paths 过滤不含它。
- **Redundant steps** —— `mirror.yml:103` 的 `flutter build windows --debug` 产物被 `:113` 完全覆盖；`flutter test test`（383 项）在 ubuntu 与 windows 各跑一遍；`mirror.yml:24` clippy 后紧接 `cargo test --workspace` 重复编译。
- **artifact retention 只设了两处**，其余用默认 90 天（含约 41MB 的签名 APK）。
- **依赖审计完全缺失** —— 全仓 `cargo deny` / `cargo audit` / `pub outdated` / dependabot / renovate **零命中**。已知过时依赖（`md-5 0.10`、`rsa 0.9`、`jni 0.21`、`cfb-mode 0.8`）无人看守。

### 6.8 vendored cargokit 与上游无机器可校验的绑定 `[新增]`

实测与上游 `fzyzcjy/cargokit@44d211e`（FRB v2.12.0 模板指针）差异为 **9 文件 +104/−59 行 / 3272 行（≈3%）**：

| 文件 | 增/删 | 有 patch 标记 |
|---|---|---|
| `cmake/cargokit.cmake` | +19/−3 | ❌ |
| `cmake/resolve_symlinks.ps1` | +15/−6 | ❌ |
| `gradle/plugin.gradle` | +9/−8 | ✅ |
| `build_tool/lib/src/builder.dart` | +17/−2 | ✅ |
| `build_tool/lib/src/rustup.dart` | +12/−10 | ✅ |
| `build_tool/lib/src/android_environment.dart` | +8/−2 | ✅ |
| `build_tool/analysis_options.yaml` | +9/−1 | ❌ |
| `run_build_tool.cmd` | +13/−4 | ❌ |
| `run_build_tool.sh` | +2/−3 | ❌ |

全仓仅 5 处 `Ginkgo patch` 注释。仓库不记录上游 SHA、无 diff 脚本、CI 无同步校验。`flutter/README.md:76` 的"逐项核对"是纯人工流程。

**风险放大项**：Apple 目标的 Rust 构建路径（`build_tool/lib/src/target.dart:61-90` 的 8 个 darwin/ios target）因 Apple 冻结而 **CI 零覆盖** —— 上游 `build_pod.dart` / `build_cmake.dart` 一旦变更，只会在未来某个不构建 Apple 的时刻静默腐化。

**做得好**：`flutter/README.md:70-74` 记录的 5 项本地适配**逐条核验全部存在且描述准确**（`plugin.gradle:6,20-22,141-149`、`builder.dart:144-162`、`rustup.dart:79,90-99`、`android_environment.dart:61-68`、`run_build_tool.sh:75,93`）。缺陷是第 3 项的 `1.99.0` 与 `rust/rust-toolchain.toml` 无联动校验。

### 6.9 脚本质量 `[新增]`

`scripts/check-mirror.sh` **不做 app 自身的 `flutter pub get`**（只解析 cargokit build_tool），全新克隆时 `flutter analyze` 会在解析阶段失败，报错与真实缺陷混淆。`docs/OPTIMIZATION-BASELINE-2026-10-22.md:42` 称"check-mirror.sh 含 dart pub get，不是纯离线入口" —— 描述与实现不一致。

`check-mirror-architecture.py` 的 `forbidden` 正则只剥离 `//` 行注释（`:45,51,62`），**不处理 `/* */` 块注释** → 块注释里出现被禁词即误报；`(?:auth|adapters)::` 裸前缀会误伤合法标识符。

`check-mirror-architecture.py:98-100` 用 `cargo metadata --offline`，在未预热 registry 的干净机器上会失败，错误信息是 cargo 的 cryptic error 而非脚本自述。

`check-mirror-windows-cmake.py:28-30,47-55` 假定本机有 cmake 且能创建符号链接（Windows 需管理员/开发者模式），文档未声明这些前置。

### 6.10 Rust workspace 缺 `[workspace.lints]` 与 MSRV `[新增]`

| 项 | 状态 |
|---|---|
| `rust-toolchain.toml` | ✅ 存在，1.99.0，profile minimal |
| `[workspace.lints]` | ❌ **不存在** |
| `[workspace.package] rust-version` | ❌ **不存在**（无 MSRV 声明） |
| `clippy.toml` / `rustfmt.toml` | ❌ 不存在 |
| crate 级 `[lints]` | 仅 `ginkgo_flutter_bridge/Cargo.toml:20-21` 的 `unexpected_cfgs` |

CI 用 `cargo clippy -- -D warnings` 兜底，但那只作用于 CI；本地 `cargo clippy` 无强制。`edition = "2021"` 在 1.99 工具链下偏保守。

### 6.11 Rust feature flag 卫生 `[新增]`

`ginkgo_upstream/Cargo.toml`：
- `test-support = []` —— **没有任何 crate 启用它**（全仓只有定义处一行），是死 feature。
- `network` 是唯一运行时开关，但 `ginkgo_runtime` 无条件启用 → 生产构建永远带 reqwest；`network` 实际只用于 `cargo check --no-default-features`。
- `default = []` 意味着 `cargo build -p ginkgo_upstream` 得到一个**没有 HTTP 能力的 crate** —— 对使用者是隐藏陷阱。
- `tokio` 的 `time` feature 在顶层与 `network` 里**声明了两次**；`tokio::time::timeout` 在非 network 下也编译 → feature 划分不干净。
- dev 依赖 `tokio = "1.48"` 与主依赖 `"1"` 写法不一致。

### 6.12 Rust 侧重复 `[新增]`

| 重复项 | 次数 | 位置 |
|---|---|---|
| `"X-Requested-With": "XMLHttpRequest"` | 11 | 7 个 adapter |
| `form_urlencoded::Serializer::new(String::new())` | 14 | 7 个 adapter |
| `is_login_response` | **4**（3 份逐字符相同） | `schedule_http.rs:161`、`graduate_schedule_http.rs:131`、`grades_http.rs:54`、`classroom_http.rs:75`（变体） |
| WebVPN 网关登录判定 | 3 | `checkin_http.rs:136`、`library_http.rs:262`、`homework_http.rs:313` |
| 响应分类 helper（`require_body`/`classify_json`/`parse_envelope`/`decode`） | 6 | 结构同，错误码细节不同 |
| 值提取 helper（`number`/`text`/`optional_string`…） | **6 套** | `optional_string` 3 份，`text` 4 份 |
| MockTransport 实现 | **7**（含 3 个同名 `YieldingTransport`） | 见 §5 |
| fixture 加载器 | **7** | 只有 1 份支持子目录 |
| User-Agent 硬编码 | **2 个不同值** | `reqwest_transport.rs:10` Safari UA，`library_http.rs:19` Chrome UA |

`ginkgo_upstream/src/codecs/library_stats.rs:37-41` 在函数体内**每次调用重编译 5 个正则**（非 `LazyLock`），而同仓 `codecs/notices.rs:7-43`、`codecs/shuttle.rs:18-34` 全部用 `LazyLock` —— 唯一的不一致点。

**32 处 `include_str!` 中 30 处跳出 crate 边界**到 `../../../../../fixtures/`，导致 `ginkgo_upstream` 无法独立打包。

### 6.13 `pub use codecs as features` 双命名空间 `[已登记 P2]`

`ginkgo_upstream/src/lib.rs:7`（"Compatibility path for existing feature callers"）。审计补注：它与 `ginkgo_domain::features` 命名直接冲突，`upstream::features::cgyy::number`（编解码器）与 `domain::features::cgyy::day`（领域规则）在同一名字空间下共存。

### 6.14 `library_mutation` 按中文字面量子串判定写结果 `[已登记 P2]`

`ginkgo_upstream/src/codecs/library_mutation.rs:43-66`。审计补注一个具体风险：`code == 1` 且 message 不在失败词表时判为 `Accepted`（`:107-110`）。若学校用 `code=1` 表示失败，此处会误判为"已受理"，**让用户以为写成功**。

---

## 7. 文档一致性 `[新增]`

### 7.1 文档版本落后于实际发布

`flutter/pubspec.yaml:4` = `0.1.0-alpha.8+9`，`android-v0.1.0-alpha.8` 已发布。以下仍停留在旧版本：

| 位置 | 内容 |
|---|---|
| `AGENTS.md:13` | "当前公开基线为 Android Alpha.7（`0.1.0-alpha.7+8`）" |
| `flutter/README.md:11` | "Alpha.7已发布，当前源码 `0.1.0-alpha.7+8`" |
| `docs/MIRROR-PARITY.md:3,5` | 未提 Alpha.8 |
| `docs/IMPROVEMENTS.md:10` | "Android 与 Windows Alpha.4 均已发布" |
| `docs/PROMOTION.md:17` | 首页链接指向 `android-v0.1.0-alpha.4` |

`docs/MIRROR-IMPLEMENTATION.md:55` 已写 "Android Alpha.8 已公开" —— 文档之间互相矛盾。

### 7.2 同一版本号用于两个产品

`docs/RELEASE-NOTES.md:3` "Ginkgo Android 0.1.0-alpha.8（2026-10-25，已发布）" 与 `:52` "Ginkgo（Apple macOS / iOS）0.1.0-alpha.8（2026-10-20，草稿包）" —— **同一个 `0.1.0-alpha.8` 用于两个不同产品**。`docs/MULTI-PLATFORM-STRATEGY.md:3` 与 `docs/IMPROVEMENTS.md:228` 都加了免责说明，说明作者已感知但未消除根因。

### 7.3 未提交的 `docs-sync-commit.sh` 三个问题

工作区有 10 个文档被修改（+40/−26），实质是 **Alpha.7 → Alpha.8 版本号同步**，方向正确。

1. **commit message 与实际暂存内容不符** —— `docs-sync-commit.sh:21` 声明同步了 `ANDROID-DEVELOPMENT`，但 `docs/ANDROID-DEVELOPMENT.md` **不在 add 列表**且未被修改。
2. **宣称"全面同步"但实际遗漏至少 5 个仍说 Alpha.7 的文档** —— `AGENTS.md:13`、`flutter/README.md:11`、`docs/MIRROR-PARITY.md:3,5`、`docs/IMPROVEMENTS.md:10`、`docs/PROMOTION.md:17`。
3. **脚本留在仓库根、未跟踪、无自删除** —— `docs-sync-commit.sh:2-3` 注释写"完成后可删除本脚本"，但脚本不做删除也没进 `.gitignore`；任何人 `git add -A` 就会把它提交进仓库。它也违反仓库自身约定（其他脚本都在 `scripts/`）。

### 7.4 同一事实被复述 6 处

"当前公开基线 = Alpha.8 / build 9"这一事实出现在 `README.md:60`、`docs/MIRROR-IMPLEMENTATION.md:10,55`、`docs/MIRROR-TODO.md:11-12`、`docs/FEATURES-AND-PROTOCOLS.md:3`、`docs/PROMOTION.md:4,75`、`docs/RELEASE-NOTES.md:3`、`docs/index.html:384`、`docs/_audit/2026-10-25-android-alpha8-release.md:5`。

`docs/RELEASE-NOTES.md:5-9` 与 `docs/releases/android-alpha8.md:3-7` 的 5 条 bullet **逐条相同**。

这就是一次发版要改 10 个文件的**结构性**原因 —— 不是纪律问题。AGENTS.md §9 规定"发布、审计和验收按日期归档，不在多个入口重复维护"，现状违反该规则。

### 7.5 文档引用不存在的路径

`docs/MIRROR-ARCHITECTURE.md:92`、`docs/MIRROR-TODO.md:37` 引用 `workspace_shell.dart`（实际在 `flutter/lib/workspace/`）；`docs/MIRROR-ARCHITECTURE.md:28` 引用 `upstream/src/auth/session.rs`（`upstream/src/` 目录不存在）；`docs/MIRROR-TODO.md:63` 引用 `bridge/src/api/live/utilities.rs`（缺 `rust/crates/ginkgo_flutter_bridge/` 前缀）。

---

## 8. 冻结的 Apple 侧

### 8.1 macOS 应用内就地更新是一条完整的供应链 RCE 通道 `[新增，P0 级]`

**只存在于冻结树上**，而 Android 侧已用 `trusted_url` 把它堵死：

| 环节 | 位置 | 问题 |
|---|---|---|
| 第三方镜像 | `Core/Update/UpdateCenter.swift:74,78` | `["https://gh-proxy.com/", "https://ghproxy.net/"]`，`.automatic` **默认优先镜像** |
| 资产 URL 无白名单 | `Core/Update/UpdateChecker.swift:41-42` | 只取 `asset["browser_download_url"]`，**不校验 host**。对照 Rust `codecs/updates.rs:23-35` 的 `trusted_url`（https + host == github.com + 无 userinfo + path 前缀 + 无 query） |
| Release 页 URL 无白名单 | `UpdateChecker.swift:33` | `html_url` 只做 `URL.init(string:)`。Rust 对应 `updates.rs:53-59` 校验 path 前缀 |
| 校验和可缺失 | `UpdateCenter.swift:178-180,241` | `guard let checksums else { return nil }` → **拿不到 checksums.txt 就直接安装** |
| 校验和同源 | `UpdateCenter.swift:243` | checksums.txt 也从同一镜像取 → **校验方与被校验方同源** |
| 只验 bundle id | `UpdateCenter.swift:298-301` | **不验代码签名、不验 notarization** |
| 主动摘隔离标记 | `UpdateCenter.swift:317` | `/usr/bin/xattr -dr com.apple.quarantine "\(target.path)"` —— **明确移除 Gatekeeper 隔离** |
| 覆盖式替换 | `UpdateCenter.swift:312-320` | `rm -rf` 旧包 → `ditto` 新包 → 重启；`:286-291` 解压后不做 `codesign --verify` |

这是全仓**唯一**"下载并执行远端代码"的路径。TODO 的冻结条款写"只在影响 Android 构建、共享 fixture 或**存在安全问题**时被动修" —— 按此规则，这条应当被动修。

### 8.2 已存在的 5 处协议语义漂移 `[新增]`

| # | Rust upstream | Swift | 后果 |
|---|---|---|---|
| 1 | `codecs/schedule.rs:355-357` entry 缺失时回退 scheme 层 `JCFADM` | `ScheduleParser.swift:306-311` 只按 `row["JCFADM"]` 匹配 entry 自身 | 真实响应若把 `JCFADM` 只挂在 scheme 上 → **`startTime`/`endTime` 全空且不报错**。Rust 有专门回归 `schedule.rs:628-644`，Swift 无 |
| 2 | `schedule.rs:93-95` 节次强制 `1..=14` | `ScheduleParser.swift:100` 只校验 `start <= end` | 学校扩容节次时 Swift 静默渲染非法课表 |
| 3 | `schedule.rs:380-385` 研究生行 `XNXQDM` 必须等于 term_id | `ScheduleParser.swift:122-138` **无此校验** | 跨学期混排的 GSMIS 响应静默出课 |
| 4 | `schedule.rs:32` 本科学期降序排 | `ScheduleParser.swift:17-24` **不排**，依赖服务端顺序 | 现有 fixture 输入恰好已降序 → **契约抓不到** |
| 5 | `ginkgo_domain/src/features/homework.rs:6-10` `HomeworkStatus` **无 `overdue`** | `HomeworkModels.swift:3-8` + `SpocHomeworkClient.swift:425-428` 会产 `overdue` | `fixtures/homework/spoc-page-v1.json` 的 expected 是 `"pending"`，但该契约不在 Swift 白名单 → **零告警** |

成功码本身**没有漂移**（逐个核对：本科 code=="0"、研究生 code=="1"/"0"、签到 `["0","200","success"]`、图书馆 `code ∈ {0,1}` + 14 项失败关键词）。漂移全在"成功码之后的字段语义与校验严格度"。

**唯一真正双端一致的模块是课程签到** —— 可作为其他模块的收敛模板。

### 8.3 共享契约覆盖率 14.5%，且跳过是静默的 `[新增]`

| 维度 | Rust | Swift |
|---|---|---|
| 消费方式 | 递归执行全部 145 个 JSON | 递归枚举但按白名单过滤 |
| 未知契约 | **失败** | **静默跳过**（`SharedParserContractTests.swift:29` `guard supported.contains(contract) else { continue }`） |
| 覆盖契约 | 46/46（100%） | 13/46（28%） |
| 覆盖文件 | 145/145（100%） | 21/145（14.5%） |

`fixtures/README.md:15` 明确写"已有样例不能被静默跳过"，Swift 实现与之直接矛盾。`SharedParserContractTests.swift:8-13` 是一份**手工维护、不受 CI 保护**的清单 —— 而 AGENTS.md §1 写"公共契约变化不必顾虑 Apple 端" → 最省事的处理就是从白名单删掉一项 → 覆盖率静默下降、零告警。

### 8.4 冻结代码里留着一个仍在对旧账号无限轮询的僵尸任务 `[已登记冻结，判定需复议]`

`Core/Shell/WorkspaceCoordinator.swift:245-253`：

```
245: pollingTask = Task { [weak self] in
246:   while !Task.isCancelled {
247:     guard let self else { return }        // ← 强绑定跨越整个迭代
248:     let delay: UInt64 = self.checkIn.errorMessage == nil ? 30 : 120
249:     do { try await Task.sleep(...) } catch { return }   // ← sleep 期间仍强持有 self
```

`guard let self` 作用域覆盖整轮 → `Task.sleep` 期间 Task 强持有 coordinator → `deinit`（`:97-101`，唯一 `pollingTask?.cancel()` 处）永不执行 → 登出后旧 workspace **继续每 30 秒对旧账号轮询 iclass** 并泄漏整棵 ViewModel。

来源 `docs/_audit/2026-10-24-comprehensive-review.md` §2.2⑥（2026-10-24），而 Apple 最后提交 `3b25ec3` 是 2026-10-22 → 审计已出、债已固化。

**审计意见**：TODO 把这条归入"冻结，不修"。但它是**持续的网络请求 + 账号数据外发**（向学校系统），不只是内存泄漏 —— 与 §8.1 同属安全类，按 TODO 自身规则（"存在安全问题时被动修"）应当重新归类。

同源问题还有三处路由绕过（`CgyyClient.swift:375,443`、`CheckInClient.swift:603,618` 漏掉 `UpstreamRoute.swift:89-95` 的 Cookie 剥离、`CasClient.swift:436`）与 `CasClient.swift:361-379` 把 200-带-HTML 判为会话失效。

### 8.4b 需要维护者决策：`minBuild` 数值与自救路径 `[新增，未改代码]`

`docs/update-gate.json` 的 `minBuild: 5` 只拦 build < 5，而当前公开基线是 build 9。把门禁真正生效需要维护者做三个决定，代理不代为选择：

1. **目标值**。合理的候选是 8（拦掉 Alpha.6 及更早）或 9（只放行当前版本）。取决于如何看待 Alpha.7 的已知缺陷。
2. **自救路径**。`flutter/lib/update_gate.dart` 的 `UpdateRequiredPage` 当前**只提供"打开发布页"和"重新检查"，没有跳过**。国内 GitHub 可达性不稳，一旦目标值定得过高、或用户网络访问不了 Release 页，用户就被锁在更新页且无出路。至少需要一个"暂时继续使用"的出口，或把下载地址改为可用的镜像。
3. **发布时机**。AGENTS.md 已规定"提升 `minBuild` 前必须确认新版本已可下载" —— 这条要在改数值之前、而不是之后核对。

在此三项确认前，清单合进 `main` 只会让门禁从"静默失效"变成"按 5 生效"，不会锁死任何已发布版本，因此**合入 `main` 本身是安全的**；改数值不是。

### 8.5 Apple CI 成本 `[新增]`

| Job | 实测耗时 | 说明 |
|---|---|---|
| `ci.yml` | 2m14s ~ 3m04s | macOS build + 232 XCTest + `git diff --check` |
| `ios.yml` | 6m27s ~ 14m19s | `brew install xcodegen` + generate + generic iOS build + 模拟器 XCTest + UI test（每次约 20 张截图） |

**两者都没有 paths 过滤**（`ci.yml:3-8`、`ios.yml:3-8` 只写 `on: push/pull_request: branches:[main]`），对比 `mirror.yml:4-9` 有 paths。近 30 天 142 次提交 → **≈1,633 macOS runner-min/月**，PR 再翻倍 ≈ **3,300 runner-min/月（≈55 runner 小时）**。iOS job 占 78%，服务一个 19 文件 / 4913 行的冻结壳。

仓库是 public → Actions 分钟免费。**这不是账单问题，是 PR 反馈延迟问题**：一个纯 Flutter 改动也要等 iOS 模拟器测试最多 14 分钟。

### 8.6 Apple 侧三条无门禁的腐化通道 `[新增]`

1. **XcodeGen 版本未钉死** —— `project.yml:3` 只写 `minimumXcodeGenVersion: 2.46.0`（下界），`ios.yml:26-31` 装的是 Homebrew 最新版。上游发新版即可能炸 iOS 构建，而 Apple 已冻结 → 修它必须动冻结代码。
2. **iOS 共享源排除是 24 条黑名单**（`project.yml:33-56`）—— 任何人往 `BUAA-Assistant/` 新增一个 `import AppKit` 的共享文件而忘了加 exclude → iOS 构建立刻红。**目前干净，但这是约定而非门禁**。
3. **Swift 侧完全没有架构门禁** —— `check-mirror-architecture.py:42` 的扫描目录完全不含 `BUAA-Assistant/`。脚本里现成的学校 URL 正则（`:43`）只要加个目录就能封住"Swift 侧新增第二份协议实现"。

### 8.7 Apple 侧做得好的部分（清理时不要误伤）

- **零 ATS 例外**（`NSAllowsArbitraryLoads` / `NSExceptionDomains` 全树 0 命中）。
- **零 TLS 校验放宽**（`SecTrustEvaluate` / `serverTrust` / challenge 处理全树 0 命中）。
- **Keychain 可达性正确** —— `Core/Storage/KeychainManager.swift:54,60` 用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；账号密码不进 UserDefaults。
- **日志纪律优秀** —— `Core/Logging/AppLog.swift:3` 禁止记录凭据/票据/正文；全树无 `print(` / `NSLog`，**没有 Cookie / token / 学号 / 姓名落日志**。
- **Cookie 隔离** —— `Core/Network/APIClient.swift:38-55` WebVPN 用 ephemeral session + 独立 cookie store，直连走 `.default`。
- **卫生指标异常好** —— 全树 TODO/FIXME/HACK/unimplemented **仅 1 处**（`Core/Network/UpstreamRoute.swift:71` 的合理 `preconditionFailure`）。
- **macOS 工程不会因文件增删而腐化** —— `BUAA-Assistant.xcodeproj/project.pbxproj:25-26` 用 Xcode 16 的 `PBXFileSystemSynchronizedRootGroup`。
- **iOS 工程当前一致** —— 139 个 swift 引用全部在磁盘存在，24 个未进引用集合的文件恰好等于 `project.yml:33-56` 的 excludes。

### 8.8 Apple 领先 / 落后清单（回答"冻结丢什么"）

**领先（Android/Rust 没有）**：macOS 菜单栏 / 全局快捷键 / 开机自启（`Core/Keyboard/GlobalShortcutController.swift` 121 行、`Core/LaunchAtLogin/LaunchAtLoginController.swift` 65 行）；macOS 应用内就地更新（`Core/Update/UpdateCenter.swift` 493 行 —— 恰恰是 §8.1 的安全债）。

**落后**：校车时刻表、OPAC 公开书目（Rust 有 `codecs/shuttle.rs` / `codecs/library_books.rs`，Apple 侧 grep 零命中）；Flutter 的预约聚合页。

**死代码**：`Features/Homework/JudgeHomeworkClient.swift`（371 行，`judge.buaa.edu.cn`）已被 `HomeworkModels.swift:16` 的 `enabled = [.spoc]` 关闭，Rust 侧已无 judge 任何代码 → 仓库里留着一个不再被支持的第三方域名的完整客户端。

**结论**：冻结**基本不丢用户可感知功能**，机会成本极低。真正的成本是 §8.2–8.6 的三笔账单。

---

## 9. 与 MIRROR-TODO 的差集

### 9.1 TODO 已有、审计确认仍开放

| TODO 条目 | 位置 | 审计补充 |
|---|---|---|
| P2 设计 token 采纳 + CI 强制 | TODO P2 | 7 个死 token；`statusUncertain`==`statusInactive`；字阶越界 34 处、圆角越界 18 处；共享组件自身违规 |
| P2 bridge DTO / 删 Dart `jsonDecode` | TODO P2 | 145 处无校验 `as` 强转，零 schema 校验 |
| P2 稳定业务规则搬回 domain | TODO P2 | 另有校园 ID、CGYY 审批码、博雅考勤码、班车周次规则 4 项同类 |
| P2 `pub use codecs as features` | TODO P2 | 与 `domain::features` 命名直接冲突 |
| P2 阻塞 fsync + 全局锁 | TODO P2 | `foundation/mutex.rs` 毒化恢复静默清空会话；嵌套持锁 |
| P2 `library_mutation` 中文字面量判定 | TODO P2 | `code==1` 误判为 Accepted 的具体路径 |
| P2 零日志可观测性 | TODO P2 | Dart 侧同样零，`refresh_section.dart` 把所有异常记成同一码 |
| P0 读命令超时上界（标 `[x]`） | TODO P0 | **写/会话路径仍未覆盖** |
| P0 读路径账号复检（标 `[x]`） | TODO P0 | **6 个 service 无回归，Dart 侧 2 个控制器无守卫** |
| P1 Android release workflow（标 `[x]`） | TODO P1 | **签名路径实为红灯，release-only 代码路径无 CI 覆盖** |
| P2 最低版本门禁 | TODO P2 | **清单不在 main，线上 404，门禁 100% 失效；minBuild 偏低** |

### 9.2 TODO 未覆盖的新增条目（建议入 TODO）

**P0 建议（可复现回归 / 安全边界）**

1. `docs/update-gate.json` 未进 `main` 分支，线上 404，最低版本门禁完全失效；且 `minBuild: 5` 偏低，`UpdateRequiredPage` 无跳过路径 → 提高前会全量锁死。
2. bridge DTO 映射层（`api/live/mapping.rs` 10 个映射函数 + `api/mirror.rs` + `api/live/library.rs`）零有效测试；`MutationState::Uncertain → "accepted"` 这类改动两侧都测不到。
3. 写/会话命令（`login`/`restore`/`sign_out`/4 个写命令）无超时上界，`login` 最坏约 930 秒且持有 `SESSION_ACCESS.write()`。
4. `flutter/lib/settings_page.dart:87-92,113-119` 缺 `mounted` 守卫；`flutter/lib/tasks_page.dart:259-269` 跨 async gap 用 `context`。
5. `flutter/lib/cgyy_day_page.dart:106-110` 的 `mirrorServiceFor(demo: false)` 硬编码，忽略 `widget.demo`。
6. macOS `Core/Update/UpdateCenter.swift` 的就地更新链路（gh-proxy 镜像 + 无 host 白名单 + 校验和可缺失 + 不验签名 + `xattr -dr com.apple.quarantine`）—— 按 TODO 自身"存在安全问题时被动修"的规则应处理。
7. `Core/Shell/WorkspaceCoordinator.swift:245-253` 登出后仍对旧账号每 30 秒轮询 —— 属持续网络请求与账号数据外发，应从"冻结不修"重新归类。
8. "清缓存 / 退登 不影响个人待办"边界零测试（用户数据丢失风险）。
9. `ginkgo_core` 实为空转发壳，业务编排住在 upstream —— 分层设计失效，且架构门禁不检查"谁拥有业务规则"。

**P1 建议（工程能力 / 可维护性）**

10. `scripts/check-mirror.sh` 缺 FRB 生成漂移检查；与 `mirror.yml` 存在两个真源。
11. Rust `1.99.0` 复制 9 处、Flutter `3.47.0` 复制 6 处且 `.fvmrc` 不被 CI 读取。
12. Cargokit 实际构建不带 `--locked`，`Cargo.lock` 不被 diff。
13. Windows 发布产物携带 4 个版本号、2 个是常量；`windows-v*` 不校验与 pubspec 一致；`windows-installer.yml` 会覆盖已发布 Release。
14. `update-gate.json` 之外的版本同步靠 6 处文档复述 —— 建议改为单一来源 + 生成。
15. `android-release.yml` 只发 artifact 不发 Release，且文档仍称"没有 Android release workflow"。
16. Apple CI 无 paths 过滤 → ≈3300 macOS runner-min/月；`ios.yml` 可瘦身为 build-only smoke。
17. Swift↔fixture 覆盖率 14.5% 且静默跳过 —— 建议加一个 fixtures 一致性门禁（新增契约而 Swift 未跟进即失败）。
18. `check-mirror-architecture.py` 漏扫 `ginkgo_domain/src/features`；4/7 规则族无自测。

**P2 建议（结构 / 清理）**

19. Rust workspace 缺 `[workspace.lints]` 与 MSRV；`ginkgo_domain` 90% 公开项无文档注释、`ports/` 全无注释、5 个核心结果类型无 `Debug`/`PartialEq`。
20. Rust 重复：`is_login_response` 4 份、值提取 helper 6 套、MockTransport 7 个、fixture 加载器 7 份、两个不同 UA、11 处 `X-Requested-With`。
21. `ginkgo_upstream` 的 `test-support` feature 无人启用；`default = []` 使其默认无 HTTP 能力。
22. `library_stats.rs` 每次调用重编译 5 个正则（同仓其余处用 `LazyLock`）。
23. 30 处 `include_str!` 跳出 crate 边界，`ginkgo_upstream` 无法独立打包。
24. `foundation/mutex.rs` 毒化恢复改为保留原值 + 记录，而非静默重置为 `T::default()`。
25. Flutter 侧：`lib/` 根 98 文件的职责混放（平台适配器 / 领域控制器 / 共享组件）；`flutter/integration_test/ios_visual_refinement_test.dart` 永远不可执行；`path_provider_android: 2.2.22` 精确 pin 为直接依赖；`uses-material-design: true` 但仅 2 处 material import。
26. `flutter/test/` 48/73 文件直接 import 生成代码而非 `contracts.dart`；共享 harness 藏在 `mirror_widget_test.dart`（1144 行）里被 25 个文件依赖；`flutter/test/` 与 `integration_test/` 无任何测试超时（599 处 `pumpAndSettle`）；`bool.fromEnvironment` 传 `0` 会意外启用真实网络验收。
27. Dart 侧 8 个 `*_models.dart` 零直接测试、13 个 `FailureCode` 中 10 个零命中、`cgyy_captcha_page.dart`（276 行，验证码门禁）零测试、`failure_message.dart` 零单测、`native_mirror_service.dart`（220 行）零测试。
28. `scripts/check-mirror.sh` 缺 `flutter pub get`；`check-mirror-architecture.py` 不处理块注释；`cargo metadata --offline` 在冷机器上 cryptic 失败。
29. 文档：`AGENTS.md:13`、`flutter/README.md:11`、`docs/MIRROR-PARITY.md`、`docs/IMPROVEMENTS.md:10`、`docs/PROMOTION.md:17` 仍写 Alpha.7/Alpha.4；同一版本号用于 Android 与 Apple 两个产品；`docs-sync-commit.sh` 的 commit message 与暂存内容不符且脚本无自删除。
30. 无任何依赖审计（`cargo deny`/`cargo audit`/`pub outdated`/dependabot 零命中）。

---

## 10. 建议处理顺序

按"代价小 / 收益大"排序，与 TODO 的 P0/P1/P2 不冲突（本文只给序，不新增承诺）：

**第一梯队 —— 一两小时内可做，直接消除一类风险**

1. 把 `docs/update-gate.json` 合进 `main`（一次提交），并把 `minBuild` 与已发布 build 号对齐（提高前先确认新版本可下载、且确认 `UpdateRequiredPage` 有可自救路径）。
2. 修 `settings_page.dart:87-92,113-119` 的 `mounted` 守卫与 `tasks_page.dart:259-269` 的 context 复查；在 `analysis_options.yaml` 打开 `use_build_context_synchronously` / `unawaited_futures`。
3. 修 `cgyy_day_page.dart:106-110` 的 `demo: false` 硬编码。
4. 把 `check-mirror-architecture.py` 的扫描目录扩到 `ginkgo_domain/src/features`（脚本里现成的学校 URL 正则直接可用）。
5. 给 `scripts/check-mirror.sh` 加 FRB 生成漂移检查 + `flutter pub get`，消除与 `mirror.yml` 的差集。
6. 修 `docs-sync-commit.sh` 的 add 列表与 commit message；把遗漏的 5 个文档一起同步；删除或移入 `scripts/`。

**第二梯队 —— 半天到两天，消除结构性风险**

7. 给 `api/live/mapping.rs` 的 10 个映射函数补表驱动测试（重点 `MutationState` 四态与签到三态）；给 `ginkgo_runtime` 补 4 个测试。
8. 给写/会话命令加超时预算（`login`/`restore` 建议 90 秒），与 45 秒 `bounded_read` 同机制。
9. 补"账号切换"回归：Rust 的 library/classroom/homework/graduate/schedule 五个 service + Dart 的 `LibraryController` / `RefreshSection` 加账号代次守卫与测试。
10. 补"清缓存/退登 vs 待办"边界测试，并修正 `settings_page.dart:139` 的退出文案（明确待办去留）。
11. 把 `AppError.detail` 的 4 个魔法字符串与 `CgyyActionResult.state` 收敛为枚举（`MutationState` 已是正确范式）。
12. 给 `foundation/mutex.rs` 的毒化恢复改为"保留原值 + 记录"。

**第三梯队 —— 一到两周**

13. `ginkgo_core` 抽取泛型快照命令抽象，把 11 个 service 的五步模板收口（`cache.rs:114-136` 的 `resolve_current` 已有雏形）。
14. `windows-release.yml` 增加 tag↔pubspec 校验（照抄 `android-release.yml:84-93`）；`Ginkgo.iss` 的 `VersionInfoProductVersion` 改为从 `AppVersion` 派生；`windows-installer.yml` 停止回写已发布 Release。
15. Rust 工具链版本单一来源（从 `rust-toolchain.toml` 读取，消除 9 处副本）；Cargokit 加上游 SHA 记录 + diff 脚本；构建加 `--locked`。
16. Apple CI 加 paths 过滤；`ios.yml` 瘦身为 build-only smoke；加 fixtures 一致性门禁（新增契约而 Swift 未跟进即失败）。
17. 门禁补齐：4/7 架构规则族加自测；`ginkgo_domain/src/features` 纳入扫描；Swift 侧纳入学校 URL 扫描。
18. 契约测试补"未知契约失败"用例，`assert!(count >= 28)` 改为实际计数。

**第四梯队 —— 结构清理**

19. Rust `[workspace.lints]` + MSRV + `clippy.toml`；`ginkgo_domain` 公开 API 文档与 `Debug`/`PartialEq` 补齐。
20. Rust 重复项收敛（`is_login_response`、值提取 helper、MockTransport、fixture 加载器、UA 常量）。
21. Flutter 侧：共享 harness 抽到 `flutter/test/support/`；模型层补测试与 schema 校验；页面脚手架收敛到 `RefreshSection` / `SectionFeedback`（渐进迁移，不要求一次性重构）。
22. 文档改为单一来源 + 生成；`docs-sync-commit.sh` 这类一次性助手不入库。

---

## 11. 本轮已完成的修复（2026-10-25 执行批次）

本节记录本次实际改入工作树的修复，与上文"发现"逐条对应。验证均为**覆盖改动的专项测试**，未跑全量门禁（见文末"验证边界"）。

### 11.1 Dart / Flutter（Android 主体）

| 项 | 位置 | 状态 |
|---|---|---|
| `use_build_context_synchronously` + `unawaited_futures` 启用并修净告警 | `flutter/analysis_options.yaml` | ✅ `flutter analyze` 零告警 |
| `settings_page` 两处 `mounted` 守卫 | `flutter/lib/settings_page.dart:92,120` | ✅ 工作树已修 |
| `tasks_page` 跨 async gap 用 `context` | `flutter/lib/tasks_page.dart:269` | ✅ 已存在守卫，无需改 |
| `cgyy_day_page` demo 硬编码 | `flutter/lib/cgyy_day_page.dart:108` | ✅ 已是 `demo: widget.demo` |
| **`RefreshSection` 账号代次守卫** | `flutter/lib/application/refresh_section.dart` `invalidate()` + `_generation` | ✅ 新增 |
| **`LibraryController` 账号代次守卫** | `flutter/lib/library_controller.dart` `invalidate()` + 读/写路径守卫 | ✅ 新增 |
| **`LibraryPage` 接线** | `flutter/lib/library_page.dart` `didUpdateWidget` 调 `invalidate()` | ✅ 新增 |
| Material 图标字体未使用却打进包 | `flutter/pubspec.yaml:34` | ✅ 改为 `uses-material-design: false` |

### 11.2 Rust

| 项 | 位置 | 状态 |
|---|---|---|
| **写/会话命令无超时上界** | `api/live/runtime.rs` 新增 `bounded_session`(90s) / `bounded_submit`(90s) | ✅ 覆盖 `login`/`restore`/`submit_checkin`/2 个图书馆写/`execute_cgyy` |
| 写超时后必须报 `uncertain`，不得报 `notSubmitted` | `checkin.rs`、`library.rs` | ✅ 超时返回 `state: "uncertain"` |
| **bridge mapping 零有效测试** | `api/live/mapping.rs` | ✅ 4 个新用例：四态映射（含 `Uncertain != accepted` 显式断言）、签到三态、课表/考试逐字段、排序 |
| `ginkgo_runtime` 零测试 | `ginkgo_runtime/src/lib.rs` | ✅ 组装根测试（不触网、新服务无账号） |
| `foundation/mutex.rs` 毒化静默清空会话 | `ginkgo_upstream/src/foundation/mutex.rs` | ✅ 改为保留原值 + 恢复计数可观测 |
| **五个 service 切账号零回归** | `services/tests/{classroom,homework,library,academic}.rs` + `graduate_service.rs` | ✅ 新增 `GatedTransport` 与 5 个回归，upstream 277 全绿 |
| **清缓存/退登不碰待办零测试** | `ginkgo_core/tests/workspace_ports.rs` | ✅ 新增边界用例 |
| domain 结果类型无 `Debug`/`PartialEq` | `ports/{academic,homework,library_stats}.rs`、`features/homework.rs` | ✅ 已补 derive |

### 11.3 门禁 / CI / 发布

| 项 | 位置 | 状态 |
|---|---|---|
| **架构门禁漏扫 `ginkgo_domain/src/features`** | `scripts/check-mirror-architecture.py` | ✅ 已纳入扫描 |
| 架构门禁 4 族规则无自测 | `scripts/check-mirror-architecture-test.py` | ✅ 自测 8 → 13 个，全绿 |
| 本地基线弱于 CI | `scripts/check-mirror.sh` | ✅ 补 `flutter pub get` + FRB 漂移检查（codegen 缺失时跳过并说明） |
| `update-gate.json` 线上 404 无提示 | `.github/workflows/mirror.yml` | ✅ 加 schema 校验 + `origin/main` 缺失显式告警 |
| `Cargo.lock`/`pubspec.lock` 构建中被改写无检查 | `mirror.yml` contracts/bindings/android job | ✅ 三处 `git diff --exit-code` |
| `git diff --check` 只覆盖 Apple | `mirror.yml` | ✅ 已补到 contracts 与 android job |
| Windows `tag` 不校验 pubspec | `.github/workflows/windows-release.yml` | ✅ 新增 "Verify the tag matches pubspec" 步骤 |
| Release 标题/正文写死 alpha.6 | 同上 | ✅ 标题改为 `github.ref_name`；正文按版本取 `docs/releases/windows-<version>.md`，缺失时用简短兜底 |
| `Ginkgo.iss` 版本号写死 `0.1.0.4` | `packaging/windows/Ginkgo.iss` | ✅ 改为从 `AppVersion` 派生；`AppVersion`/`BundleDir` 缺省改为 `#error`（漏传即失败） |
| `windows-installer.yml` 会回写已发布 Release | `.github/workflows/windows-installer.yml` | ✅ 移除 push 触发，仅保留手动 dispatch，并注明不得重新启用 |
| Rust 1.99.0 副本 | `scripts/rust-toolchain-env.sh` | ✅ 两个脚本共享（CI/builder.dart 的 pin 仍保留，见风险） |

### 11.4 文档

| 项 | 位置 | 状态 |
|---|---|---|
| 版本落后 Alpha.7/Alpha.4 | `AGENTS.md:13`、`flutter/README.md`、`docs/IMPROVEMENTS.md`、`docs/MIRROR-PARITY.md` | ✅ 对齐 Alpha.8 |
| `docs-sync-commit.sh` commit message 撒谎、遗漏文档、留仓库根 | 根目录 → `scripts/sync-doc-versions.sh` | ✅ 重写为通用脚本：版本一致性核对 + 完整 add 列表 + 调用者给 subject；旧脚本删除 |

### 11.5 复核后**撤销**的审计结论（诚实更正）

| 原审计结论 | 复核结果 |
|---|---|
| `flutter/integration_test/ios_visual_refinement_test.dart` 是永远跑不了的死代码 | **误判**。该文件无任何 `Platform.isIOS` 判断，是一个平台无关的只读视觉截图套件，在 Android 上照常执行；其 `VisualService` 还被 `workspace_polish_test.dart` 复用。保留。 |
| `path_provider_android: 2.2.22` 精确 pin 是债务 | **部分误判**。`flutter/lib/` 无任何直接 import，但 pubspec 注释写明它用于"保留 Kotlin 插件路径与 NDK 27 工具链"，是有意的平台约束。保留，仅在 §9 记为需要定期复核的耦合点。 |
| `settings_page.dart` / `tasks_page.dart` / `cgyy_day_page.dart` 三处缺陷 | 已在会话期间的工作树中修复（非本次改动），本报告曾据旧快照报告。 |

### 11.6 验证边界（重要）

- 只跑了**覆盖改动的专项测试**：`ginkgo_domain`(11+1)、`ginkgo_core`(22+7+4)、`ginkgo_upstream`(277)、`ginkgo_flutter_bridge`(14)、`ginkgo_runtime`(1)、`flutter test test/failure_message_test.dart`(5)、`test/payload_models_test.dart`(20)、`test/workspace_back_guard_test.dart`(7)、`test/refresh_section_test.dart` + `test/library_controller_test.dart`(5)。
- **未跑** `bash scripts/check-mirror.sh`（全量门禁）与全量 `flutter test test`。CI 会跑。
- `flutter analyze` 零告警；`cargo clippy -p ginkgo_flutter_bridge -p ginkgo_runtime --all-targets --all-features --locked -D warnings` 干净；`cargo fmt --all` 已执行。
- CI 侧改动（workflow / ISS）**未经真实 runner 验证**，只做了语法与逻辑审查。Windows 安装器改动需在 Windows 主机或 tag 发布时验证。
- 未验证：物理设备、真实账号、真实学校写操作。

## 12. 需要复议的既有判定

| 判定 | 位置 | 复议理由 |
|---|---|---|
| "远端 Android Alpha Release workflow 因未配置 secret 而失败（fail-closed 设计，非缺陷）" | TODO P1 | fail-closed 本身正确，但后果是唯一能验证 release 路径（R8/AOT/release-only Dart）的通道长期红灯。release-only 代码破坏可完全绕过 CI。属"需要人工配置"而非"代码缺陷"，但需要显式登记为阻塞项 |
| "macOS / iOS 的僵尸轮询…冻结，不修" | TODO 冻结段 | `WorkspaceCoordinator.swift:245-253` 是**持续网络请求 + 账号数据外发**，不只是内存泄漏。同段的"存在安全问题时被动修"规则应覆盖它 |
| "上游读路径补 await 后账号复检…已完成" | TODO P0 | 实现完成属实，但 6/7 service 无回归、Dart 侧 2 个核心控制器无守卫。按 TODO 自身"完成需有相应层级的验证证据"的标准，该项不满足完成条件 |
| "给所有读命令加超时上界…已完成" | TODO P0 | 读命令属实；写/会话路径是同一类风险，未覆盖 |
| "最低版本门禁已接入" | TODO P2 | 代码已接入属实，但清单不在 `main` → 线上从未生效 |

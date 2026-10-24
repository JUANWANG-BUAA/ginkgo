# 全方位评审：代码工程 / 软件设计 / UI 组件 / 视觉交互

日期：2026-10-24。范围：`rust/`（5 crate，27.3K 行）、`flutter/`（24K 行 lib + 19K 行测试）、`BUAA-Assistant/` 与 `BUAA-Assistant-iOS/`（25.6K 行 Swift）、`BUAA-AssistantTests/`（5.1K 行）、`docs/`（12.9K 行）。
基线：`e149f90` + 工作树（74 文件未提交改动）。

> **范围说明（2026-10-24 追加）**：开发范围已收窄为**仅 Android**（Flutter + Rust）。第 1–6 节是全量技术评审，结论不受影响；**第 7 节起已按 Android-only 重排**，并新增第 10 节说明收窄本身带来的新风险。Apple 侧问题从"待修"降级为"冻结"，但**不是删除**。

本评审是**只读审查**，未修改任何产品代码。所有结论均在本地复核过，引用均为 `文件:行`。命令类结论附实际执行结果。

---

## 0. 总体判断

这是一个**工程成熟度显著高于同类校园客户端**的个人项目。它的强项不是功能数量，而是**约束的可执行化**：架构分层不是文档承诺而是 CI 门禁，写操作不是"加个确认框"而是有状态机与回查，协议差异不是"统一成常量"而是留在各系统本地。

四个技术栈（Rust core/upstream/runtime/bridge、Flutter、SwiftUI macOS、SwiftUI iOS）都通过了本地门禁：

| 门禁 | 命令 | 结果 |
|---|---|---|
| 架构防回退 | `python3 scripts/check-mirror-architecture.py` | ✅ 通过 |
| Rust 格式 | `cargo fmt --all --check` | ✅ 通过 |
| Rust 静态检查 | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | ✅ 零告警 |
| Rust 测试 | `cargo test --workspace --locked` | ✅ 263 passed / 0 failed |
| Flutter 静态检查 | `flutter analyze` | ✅ No issues found |
| Flutter 测试 | `flutter test test` | ✅ 372 passed / 0 failed |
| Swift 测试 | `xcodebuild test -destination 'platform=macOS'` | ✅ 通过 |

规模：Rust 310 个测试函数、Dart 326 个、Swift 232 个；`TODO/FIXME/HACK/unimplemented!` 标记数为 **0**。

**主要问题不在"写得对不对"，而在"做完了没"**——设计系统的采纳率、跨端产品一致性、以及若干异步/生命周期边角。项目自己的 `MIRROR-TODO.md` 已经把大部分剩余工作列为待人工验收项，说明团队**清楚**差距在哪里；缺的是把几个已知技术债排上修复顺序。

---

## 1. 代码工程：优秀

### 1.1 做对的

**分层约束被机械强制，而不是口头约定。** `scripts/check-mirror-architecture.py:11-36` 用 `cargo metadata` 校验 crate 依赖矩阵（domain→∅；core→domain；upstream→domain；runtime→core+upstream；bridge→core+runtime），并禁止 domain/core 依赖 `reqwest/keyring/rsa/aes/url/tokio`；`:39-54` 正则扫描 `ginkgo_core/src` 与 `ginkgo_domain/src/ports` 中的 `HttpTransport|CredentialVault|CookieJar`、`https://…buaa`、`ginkgo_upstream::`，并禁止 bridge `api/` 目录出现 `include_str!`/`serde_json::from_`。`check-mirror-architecture-test.py:14-59` 是这道门禁自身的回归测试（含"core 不能把 upstream 重新引入为 dev-dependency"）。

实测 `ginkgo_core/src` 中 `http`/`Cookie`/`token`/`buaa.edu.cn` 只命中 **1 处注释**。core 真正做到了协议无关。

**并发纪律是真实的，不是风格偏好。** 全部 std 锁站点（`auth/session.rs`、`auth/vault.rs`、`foundation/mutex.rs`、`ginkgo_core/src/tasks_store.rs:11`）都是"取锁→拷贝→释放→await"；跨 await 持有的锁全部是 `tokio::sync::Mutex`。`foundation/mutex.rs:16-26` 还在锁中毒后回落到 `Default` 而不是传播 panic，并且 `lock_value`（`:38-44`）保留 `Copy` 的路由枚举，避免 panic 静默翻转用户的直连/WebVPN 策略——这是很多项目会漏掉的细节。

**错误分类是可辨识的，不是一坨 `Exception`。** `ginkgo_domain/src/lib.rs:9-26` 的 `ErrorCode` 区分 `SessionExpired`（学校会话没了）/ `BusinessRejected`（上游明确拒绝，注释里专门写了"这不是登出"）/ `ServiceUnavailable`（网络或 5xx）/ `ChangedResponse`（结构漂移）/ `InvalidRequest` / `CaptchaRequired` / `AccessPolicyDenied` / `CredentialStore`，bridge 1:1 映射（`api/mirror.rs:60-78`），Dart 侧可以据此区分四种完全不同的 UI 表现。`AppError` 的 `Display` 只输出 code、绝不输出 `detail`（`domain/src/lib.rs:64-68`），从根上杜绝了上游报文泄进日志。

**协议解析是纯函数且防漂移。** `auth/redirect.rs:8-29` 是显式的开放重定向/SSRF 策略：只允许把 `http://sso.buaa.edu.cn/login` 升级为 HTTPS，`:52-77` 用测试证明了 `sso.buaa.edu.cn:80/login`、`sso.buaa.edu.cn./login`、`user:password@…`、`javascript:`、`ftp:` 全部被拒。`codecs/checkin.rs:33-44` 把上游状态净化成固定字符集。

**写路径纪律是我见过的同类项目里最严的一档。** 单次提交、不可重试、challenge 先消费再 await（`cgyy_booking_service.rs:545-550`）、提交后必须回查订单。`codecs/library_mutation.rs` 在解析不出 code 时才退到按中文字面量匹配。

**回归测试是行为级的。** `services/tests/cgyy_booking.rs`（1691 行）里的用例名就是协议规则本身：`late_read_401_after_account_change_cannot_clear_new_token_or_renew`、`draft_uncertainty_never_replays_and_blocks_followup_submission`、`all_unknown_{draft,submit,cancel}_results_invalidate_queries_keep_lock_and_send_once`、`acknowledged_submission_requires_matching_order_readback`。`ginkgo_core/src/application/cgyy/tests.rs:393` 的 `account_and_root_isolation_ignores_caller_supplied_account` 与 `:418` 的 `marker_contains_no_account_form_challenge_or_credentials` 直接把"本机待办不泄露账号"钉成可执行断言。Swift 侧 `AppStateSessionTests.swift:70-87`（503 不得清会话）、`CheckInClientTests.swift:11-19`（WebVPN cookie store 与 `HTTPCookieStorage.shared` 不同实例）、`CgyyClientTests.swift:6-23`（取消 POST 只发一次 → `.uncertain`）同理。

**"失败 ≠ 空" 的缓存语义是精确实现的。** `upstream/src/services/cache.rs:74-95` 的 `resolve()`：成功替换（**包括空结果**），失败返回旧值但**不刷新 `fetched_at`/`timestamp`**——原始成功时间被保留、TTL 不被延长。`:108-144` 有对应单测。

### 1.2 零散问题

- `rust/crates/ginkgo_upstream/src/lib.rs:7` 的 `pub use codecs as features;` 造出了**第二个 `features` 命名空间**，与 `ginkgo_domain::features`（业务规则）语义冲突。`services/cgyy_booking_service.rs:50` 与 `:91` 同一个文件里同时用到两者：`crate::features::cgyy::number` 是编解码器，`crate::features::cgyy::day` 是领域规则。改名可消除这类心智负担。
- `codecs/library_mutation.rs:43-66` 用中文字面量子串（"失败"/"已满"/"不足"/"不可"）判定写操作结果。上游改一次文案，`Accepted`/`Rejected`/`Uncertain` 就会静默翻转，且不会报"结构漂移"。建议降级为兜底并在 `docs/API.md` 标注未验证。
- `services/library_service.rs:100-110` 一带把"token 失效后重试一次"的块复制了 5 遍，可抽 `with_library_token_retry`。
- `codecs/shuttle.rs:128` 的 `.expect("just pushed")` 与 `cgyy_booking_service.rs:49-57` 三个遮蔽 codec 的包装函数，属于可清理项。

---

## 2. 软件设计：强，但有两处架构裂缝

### 2.1 做对的

**Rust 五层切分是真的。** `Workspace<U>`（`ginkgo_core/src/application/mod.rs:15-22`）对端口泛型，core 连 HTTP 类型都看不见；`ginkgo_upstream` 独占学校 URL、表单、Cookie、token、成功码与响应字段；`ginkgo_runtime` 惰性组装真实/演示适配。

**"学校成功码不统一"被正确地当作上游事实。** `codecs/library_books.rs:53` 的 `code === 0`、`codecs/checkin.rs:11-14` 的 `"0"|"200"|"success"`、`codecs/schedule.rs:538`、`codecs/library_mutation.rs:35-37` 的 int-or-string 各不相同——这是对的，把它们抽成通用常量才是错的。

**账号隔离有三层且有效。** ①本地文件用 `Sha1(account)` 命名空间（`tasks_store.rs:12-14`、`cgyy_pending_store.rs:43-47`，演示数据另用 `"ginkgo-isolated-demo"` 命名空间）；②`session_service.rs:249-260` 的 `clear_identity()` 在登录/登出/换路由时清空**全部**快照；③bridge 的 `SESSION_ACCESS` `tokio::sync::RwLock`（`api/live/runtime.rs:8`）——账号域读操作持读锁跨整个上游 await，身份变更持写锁，tokio 的公平 RwLock 会把写者排在新读者前面。**第 ③ 层正是阻止"A 账号的迟到响应落进 B 账号缓存"的机制。**

实测确认：`sign_in`（`session_service.rs:298-317`）检测到 `switching_account` 时先 `clear_identity()`（递增 generation + 清 Cookie + 清全部快照）再建立新会话。缓存 key 不含账号是**安全的**。

**桥接面粗粒度且有互斥。** `api/live.rs` 暴露约 30 个用例级命令，URL/Cookie/token/表单字段/上游 code 都不跨界；`cgyy_sso_token` 是 `pub(crate)` 且明确不桥接（`auth/session.rs:82-93`）。互斥分两级：`SESSION_ACCESS` 管身份/缓存，`CHECKIN_ACCESS`/`LIBRARY_ACCESS` 管模块——所以慢的研究生报表不会卡住签到。`api/live.rs:350-363` 有真测试证明"登出请求会等到在途读取释放读锁"。

**Apple 侧的路由抽象是真的。** `UpstreamRoute.swift` + `APIClient` + `WebVPNRouter` 提供唯一的 cookie 隔离机制，**全局零手搭 Cookie header**——`CLAUDE.md:59` 警告的那个失败模式在结构上不可能发生。

### 2.2 架构裂缝

**① 上游层缺少自洽的账号复检（Defect）。**
12 条左右的读路径里只有 2 条在 await 之后复检账号：`library_service.rs:84,112-114`（历史）与 `checkin_service.rs:148,181,208-210`。缺失的包括 `load_library_venues`（`library_service.rs:144` 丢弃了 `current_account()` 的结果，`:173-177` 写缓存时无复检）、`load_library_bookings`（`:270` → `:296-302`）、`classroom_service.rs:53→82`、`homework_service.rs:20→52`、`bykc_service.rs:29→60`、`graduate_service.rs:45→78`、`notices_service.rs:19-21`、`schedule_service.rs:255→288` 与 `:337/:405→441`。

**今天不可利用**（bridge 的 RwLock 挡住了），但上游层不自洽，且快照 key 是常量（`"venues"`/`"bookings"`/`"current"`/`"public"`，`library_service.rs:20-21`、`homework_service.rs:21`），隔离完全依赖"清缓存 + 外部锁"。二选一即可闭合：(a) 每条读路径加一行 await 后 `current_account() != account → Err(session_expired)`；(b) 快照按账号分键。`services/tests/campus.rs:4` 只覆盖了登出隔离，没覆盖在途竞态。

**② 部分读命令没有超时上界（Defect）。**
`bounded_read`（`api/live/runtime.rs:20-26`，45 秒）覆盖了场馆/预约/历史/作业/签到/博雅/研究生，但**没有**覆盖 `load_classrooms`（`api/live/classroom.rs:29`）、`load_library_areas`/`load_library_slots`（`library.rs:54,78`）、`load_today`（`academic.rs:37`）、`load_notices`/`load_cgyy`/`load_shuttle_timetable`/`load_book_holdings`（`utilities.rs:48,73,115,125`）。一次慢 SSO 链（10 跳 × 2 路由 × 36 秒）可以让 `SESSION_ACCESS` 的**读**锁被持住数分钟，从而阻塞 `login`/`sign_out`/`set_route`/`clear_cache`——这些都要写锁。

**③ `unreachable!()` 在 FFI 路径可达（Defect）。**
`ginkgo_upstream/src/services/cgyy_booking_service.rs:334` 与 `:798`、`ginkgo_core/src/application/cgyy.rs:102`。三处目前静态不可达，但 FFI crate 里的 panic 会 abort 进程而不是返回错误。应换成 `AppError::changed()`（解析漂移）。

**④ 阻塞式 fsync 跑在 tokio worker 上（Risk）。**
`ginkgo_core/src/application/cgyy.rs:64-101` 在 `async fn` 里做 `create_dir_all`/`open`/`write_all`/`sync_all` + 目录 fsync（`grizzly_pending_store.rs:96-104`），并持一个**进程级全局** `std::sync::Mutex`（`cgyy_pending_store.rs:15`）。锁没有跨 await（规则没破），但 fsync 会卡住 runtime worker，且全局锁把所有账号串行化。`tasks_store.rs:11` 同样模式。建议 `spawn_blocking` + 按账号加锁。

**⑤ CGYY 写操作持全局写锁（Risk）。**
`api/live/utilities.rs:80` 的 `execute_cgyy` 拿的是全局 `SESSION_ACCESS` **写**锁，预约的整个多跳验证码链期间**全应用所有读都被阻塞**。应仿 `CHECKIN_ACCESS` 设独立 `CGYY_ACCESS`。另 `api/live/utilities.rs:13` 的 `edit_tasks` 用 `try_read()`，别人正在登录就返回 `ServiceUnavailable`——同步 FFI 因登录失败而失败是反直觉的 UX。

**⑥ Apple 侧轮询任务的僵尸保留（Defect）。**
`WorkspaceCoordinator.swift:243-251`：

```swift
pollingTask = Task { [weak self] in
  while !Task.isCancelled {
    guard let self else { return }          // ← 强引用活到本轮迭代结束
    let delay: UInt64 = self.checkIn.errorMessage == nil ? 30 : 120
    do { try await Task.sleep(...) } catch { return }   // ← 睡眠期间 self 仍被强持有
    ...
    await self.checkIn.refresh()
  }
}
```

`guard let self` 的强绑定作用域覆盖整轮迭代，所以 `Task.sleep` 期间 coordinator 被 Task 强持有 → `deinit`（`:97-101`，唯一会 `pollingTask?.cancel()` 的地方）永远不会执行 → 登出时 `RootView.swift:31-34` 把 `WorkspaceHost` 从视图树摘掉，`.task(id:)` 随子树一起被销毁（因此 `activateSession(account: nil)` 那条取消路径**不会**被走到）→ 旧 workspace 继续每 30 秒对**旧账号**轮询 iclass，并泄漏一整棵 ViewModel。

这直接违反 `CLAUDE.md:53`"账号切换会释放整个 workspace"。触发条件是登出时正处于 Today/CheckIn 页且场景活跃——真实但有条件。修法：不要跨 sleep 强持有 `self`，并在显式拆卸路径里取消 `pollingTask`。

**⑦ Apple 侧三处路由绕过（Rule deviation）。**
`CLAUDE.md:59` 说"绝不在功能客户端里手搓 URLSession 调用"。实际：
- `CgyyClient.swift:375` 与 `:443` 直接用 `session.data(for:)`——**CGYY 从不走 WebVPN**。`:303-306` 有注释说明是刻意的直连专属，但与"所有上游请求都经过 `routedData`"的通则冲突。
- `CheckInClient.swift:603,618` 手搓路由（`routedRequest` `:634-638`），**漏掉了 `UpstreamRequestRouting.route` 在 `UpstreamRoute.swift:89` 做的 Cookie header 剥离**。今天无害（没有任何客户端设 Cookie header），但这是第二份路由实现，会漂移。
- `CasClient.swift:436` 同样手搓，且跳过 `routedData` 的响应归一化（靠 `WebVPNRouter.unwrap` `:447` 补偿）。

另有一个陷阱：`routedData` 的 `allowWebVPN` 默认是 `appOwnedSession`（`UpstreamRoute.swift:138-142`），功能自有的 session 会**静默失去 WebVPN 路由**。

**⑧ `validateSession` 把 200-带-HTML 当作会话失效（Risk）。**
`CasClient.swift:372-378` 只认 `code==0` + 非空 data，任何不合规的 200（HTML 插页、运营商劫持页、WAF 页）都判 `sessionInvalid` → 清会话。这与规则禁止的"5xx 抖动误杀登录"是同一类抖动，只是换了形态。

### 2.3 Flutter 侧的架构裂缝

**① 页面在解析桥接载荷（Defect）。**
18 个 Dart 文件里有 **24 处 `jsonDecode`**，页面直接读学校字段名：`space_id`/`time_ids`/`challenge_id`/`joiner_num`/`philosophy`/`off_school`（`cgyy_booking_page.dart:245-259`）、`currentTerm`/`courses`/`teacher`/`position`（`bykc_page.dart:96-104`）、`phase`/`elapsedMs`（`checkin_loading.dart:44`）、`actualTotal`/`hasMore`/`bibId`（`library_books_page.dart:104-106`）。

根因是架构性的：`ginkgo_flutter_bridge/src/api/live.rs:205-209` 的

```rust
/// Sanitized domain JSON, never raw upstream data, credentials or tokens.
pub struct ReadOnlyResponse { payload: Option<String>, stale: bool, failure: Option<FailureCode> }
```

这个逃生舱被约 9 个端点使用（bykc / graduate / notices / cgyy / shuttle / library_books / library_stats / checkin_progress）。**缓解因素**：载荷是 Rust 净化过的领域 JSON，不是原始上游数据，所以是契约侵蚀而非凭据泄露。修法是在 bridge 侧补 DTO，然后删掉 Dart 里的 `jsonDecode`。

**② 稳定业务规则留在了 Dart（Defect）。**
`AGENTS.md:58` 要求"学校日期、稳定业务规则……留在 Rust"。实际：
- `reminder_rules.dart:18-33` 签到窗口规则（课前 10 分钟到结束）——Rust 只有 `sign_in_allowed`（`codecs/checkin.rs:201`），没有窗口。
- `reminder_rules.dart:46-63,65-110` 提醒排程（截止前 48h/24h，`:77`）。
- `homework_projection.dart:44-70` 逾期/无日期/非法截止分类（其自身注释 `:37` 说这是按 `docs/NEXT-STAGE-PLAN-2026-10-23.md` 实现的）。
- `checkin_page.dart:54-57` 与 `library_stats_page.dart:48` 在 Dart 里算 UTC+8 的"学校今天"。

`ginkgo_domain` 的定位正是"值类型、纯规则"，这些规则本该在那儿——放过去还能直接拿到 Rust 单测。

**③ 强制刷新被静默丢弃（Defect，用户可感知）。**
`application/refresh_section.dart:20-24`：

```dart
Future<void> refresh(...) => _task ??= _refresh(read, fallbackError).whenComplete(() => _task = null);
```

`read` 闭包捕获了 `force`。若一次非强制读正在进行，此时到达的 `force: true` 刷新会**并入在途任务**，强制标志被丢弃——下拉刷新等于没做。`library_controller.dart:29-30,50-52` 同形。

更糟的是一批页面连合流都不做，直接 `if (busy) return;`（`notices_page.dart:29`、`cgyy_page.dart:43`、`homework_page.dart:126`、`library_stats_page.dart:33`、`shuttle_page.dart:53`、`library_books_page.dart:394`，全项目共 16 处）：**初次加载期间的 18 处 `CupertinoSliverRefreshControl` 下拉刷新被丢弃，无错误、无反馈**。这正面违反 `AGENTS.md:232`"重叠读取合流、刷新保留旧内容"。现有测试只覆盖了同参数合流，没覆盖 force 路径。

---

## 3. UI 组件设计：定义优秀，采纳不足

### 3.1 现状

`flutter/lib/design/tokens/`（colors 85 / typography 96 / spacing 43 / radii 22 / layout 28 / motion 17 行）是一套**质量很高**的 token：4pt/8pt 间距标尺、34/26/22/17/17/14/13/12/11 的 HIG 类型标尺、2/7/8/10/12/18/26 圆角、`GinkgoMotion.duration` 尊重 `MediaQuery.disableAnimationsOf`（`motion.dart:13`）。`apple_design.dart` 是它的一层薄门面——这个模式是对的。

### 3.2 问题：token 存在但基本没被使用

实测（96 个应用 Dart 文件，排除 `design/` 与 `src/`）：

| 项 | 硬编码 | token 引用 |
|---|---|---|
| `fontSize: N` | **202**（18 个不同值：10–40） | 31 `GinkgoTypography` |
| `EdgeInsets.*(数字)` | **204** | 8 `GinkgoSpacing` |
| `SizedBox(h/w: N)` | **199**（26 个不同值） | 6 `GinkgoLayout` / 1 `GinkgoMotion` |
| `BorderRadius.circular(N)` | **49** | 2 `GinkgoRadii` |
| `Color(0x…)` | **8** | 24 `GinkgoColors` |

**96 个文件里 62 个（65%）完全没碰过 token 系统。** 根因不是懒惰，是**门面太窄**：`apple_design.dart` 只暴露了约 60 个 token 中的 16 个——没有 `GinkgoSpacing.xs/sm/md/base/lg/xl`，没有 `GinkgoRadii.button/panel/badge/dialog`，没有 `GinkgoTypography.title2/headline/subheadline/footnote/caption`。而且 `AppleDesign.title` 被别名到 `largeTitle`（34pt/w700），与 `AppleDesign.body`（17pt）之间缺了整档台阶，页面表达不出来就绕过它。甚至 `apple_widgets.dart` 自己也在硬编码自己的字号（`:90,114,166,173,102,398`）和圆角（`:234,484,676,700`）。

**颜色是唯一真正受控的维度**——那 8 处十六进制全部合法（4 个强调色 `app_preferences.dart:26-46`，2 处阴影黑 `apple_widgets.dart:237,529`）。类型与间距不是。

**与 Rust 架构门禁形成鲜明对比**：Rust 分层有 CI 强制，Dart token 采纳率没有任何检查。这是一个**可执行化的约束缺口**——补一个 lint 或 CI 检查的成本很低，收益直接。

### 3.3 组件复用

`CollectionWindow` / `CollectionToolbar`（`AGENTS.md:234` 指定的"大量记录"方案）**只被 2 个页面使用**（`classroom_page.dart:27`、`library_seat_page.dart:42`）。真正的主力是 `AppleSection`（177 处）、`AppleListTile`（135 处）、`AppleEmptyState`（36 处）、`ApplePageHeader`（27 处）。

发现的具体近重复对：
1. **三套分页 UI**：`collection_toolbar.dart`（页码选择 + 箭头）、`library_history_page.dart:176-183`（上一页/下一页）、`library_books_page.dart:291`（载入下一页）。
2. `AppleSection` 分组列表 vs 散布在 30+ 文件里的约 49 个手搭 `BoxDecoration(borderRadius:…, Border.all(...))` 卡片。
3. `AppleEmptyState` vs `today_page.dart:445` 的 `_TodayCourseEmpty`——Flutter 的"今天"自己重画了空态卡。
4. **图标 tile 复制 3 份**：`ginkgo_visuals.dart:7`、`PageComponents.swift:56-60`、`apple_widgets.dart:75-80`。
5. Swift：`AcademicPageHeader`（`PageComponents.swift:44`）vs `PageHeading`（`:30`）两个页头组件。

### 3.4 状态反馈

**做对的**：陈旧缓存处理是全项目最强的一环——约 10 个页面都明确标注"正在显示上次结果"（`today_course_focus.dart:80,93`、`library_page.dart:60`、`library_seat_page.dart:197`、`schedule_page.dart:120`、`checkin_page.dart:160`、`classroom_page.dart:443`、`notices_page.dart:96`、`bykc_page.dart:176`）。

**问题**：
- **空态与错误态视觉上不可分。** `AppleEmptyState` 的图标颜色对 error 与 empty 两个分支都是 `CupertinoColors.secondaryLabel`（`apple_widgets.dart:154-161`）——错误三角和空托盘是**同一个灰**。而且 36 个使用点里只有 16 个设了 `error: true`，`bykc_page.dart:406,427,480` 完全没设，于是博雅加载失败显示为一个灰色空托盘。
- **Flutter 缺"部分成功"。** Swift 有"以下来源暂时未能更新：…；作业结果不完整"，Flutter 的 `homework()` 只返回单个 `HomeworkResponse`（`application/mirror_service.dart:54`），`homework_page.dart:143-148` 把任何来源失败都折叠成"整页错误（无数据）"或"显示上次结果（缓存）"。部分刷新被报告成整页失败，违反 `AGENTS.md:233`。
- `SectionFeedback`（`loading_widgets.dart:156`）这个共享部件只在 5–6 个文件里用，约 40 个页面各自手搓 banner。
- `library_stats_page.dart:107` 是唯一带内联"· 缓存"标记的页面；别处的陈旧性只存在于会消失的临时 banner。

---

## 4. 视觉与交互体验

### 4.1 macOS 端：明显好于同类，但两个真问题

看 `docs/images/` 实际截图（1200×800 pt）后的判断：

**做得好的**：跨 8+ 页一致的"eyebrow / 标题 / 副标题"结构（`CAMPUS / LIBRARY` → `图书馆` → `选择楼馆与分区…`）；分组面板用发丝分隔线而非"一物一卡"；指标条同时是筛选器（`library.png` 的两个校区卡）；`QueryFlowSteps` 四步流程引导；一致的"上次同步"时间戳；`grades.png` 的空态（图标 + "该学期暂无已发布成绩 / 成绩发布后可在这里刷新查看"）是**真正的确认空**而不是占位符。

**真问题**：
1. **周网格在默认 1200pt 宽度下被裁切**（`schedule.png`、`overview.png`）："周日"列头在右边缘被切掉半个字符，有游离的 "3" 碎片，**且没有任何滚动提示**。`UI-DESIGN.md` 要求"窄窗口允许横向滚动"，但连默认宽度都放不下。
2. **主内容列里塞了一段运维日志**：`today.png` 的"WebVPN CAS 会话已验证；签到到集仍以 iclass 实际返回为准。系统通知已关闭，可在系统设置 → 通知 → Ginkgo 中开启。联网时自动轮询，正常约每 30 秒…"——3 行 11px 灰字与真正的日程内容争夺同一列的注意力。`checkin.png` 同样。
3. **信息密度过低**：`today.png` 的签到行，标题在 x≈390、状态徽标在 x≈1030，中间约 600pt 空白。对比 `library.png` 的密度明显更合理——说明好的排版在本项目内并未统一应用。
4. **"已更新"横幅颜色不一致**：`schedule.png` 的"课表已更新"是绿色，`grades.png` 同为绿色，`library.png` 的"楼位已更新"是蓝色（`ScheduleView.swift:24`、`GradeView.swift:25` 用 `.success`，`LibraryView.swift:32` 用 `.information`）。同一语义、两种颜色。
5. **`graduate.png` 的图例撒谎**：图例承诺"● 已认定 ● 在修 ● 待考核 ● 缺口"四色图例，进度条却是一根纯蓝条。
6. `settings.png` 的"已登录"徽标对比度过低，section 标题约 10px。

### 4.2 跨端一致性：一个真正的产品身份分裂

| | Flutter（Android/Windows） | SwiftUI（macOS/iOS） |
|---|---|---|
| 强调色 | 硬编码绿 `0xff189840`（`colors.dart:8`）+ 7 组可选强调色 | 系统 `Color.accentColor`（蓝），**57 处使用**，无自定义色、无强调色选择 |
| pending 状态 | 棕 `#713900`/`#ffbd70`（`colors.dart:52-55`） | 蓝（`StatusPresentation.swift:44`） |
| overdue 状态 | 棕 | 橙（`StatusPresentation.swift:48`） |
| 字体 | Inter + NotoSansSC（`pubspec.yaml:35-41`） | SF Pro |
| 图标语言 | 饱和多色 tile（橙签到 / 紫预约 / 蓝作业） | 单色 SF Symbols |

**结果：Windows 版是绿色，macOS 版是蓝色，两个应用不像同一个产品。** `windows-alpha.png` 与 `today.png` 并排即可看出。`statusUncertain` 与 `statusInactive` 更是**取值完全相同**（`colors.dart:65,70`），两个语义槽塌缩成一个颜色。

这不是审美偏好问题，是**产品身份**问题。修法二选一：把 Flutter 默认强调色改为系统强调色，或给 Swift 端加同样的绿 + 强调色选择器；同时补齐 Swift 侧 `statusPending`/`statusDanger` 的等价色，并拆开 uncertain/inactive。**改动很小，跨端一致性收益最大。**

### 4.3 信息架构也分叉了

`UI-DESIGN.md:9` 规定"「今天」是登录后的默认页…按时间排序"。macOS 的今天是：课程签到 → 接下来要做 → 今天有 2 门课。Flutter 的今天是（`windows-alpha.png`）：**账户与设置卡 → 日期 → 课程 → 常用服务**——以一张账户卡开头，而不是当天的日程。同名页面、不同信息架构。

`windows-alpha.png` 另外两点：右上角有两个绿色描边圆钮（设置 + 刷新），而设置已在侧栏里，冗余；"离线演示"提示同时出现在侧栏底部和内容区，合理但略啰嗦。

### 4.4 动效

整体克制且**正确尊重"减少动态效果"**：`motion.dart:13-16` 返回 0，`workspace_tab_transition.dart:46-49`、`loading_widgets.dart:28-30`（同时用 TickerMode 停 offstage）、`apple_widgets.dart:508,521,759`、`schedule_grid.dart:302` 都接上了；`workspace_shell.dart:100` 把应用内偏好折进 `MediaQuery.disableAnimations`；`preferences_pages.dart:78` 有开关。

唯一离群：`workspace_tab_transition.dart:109-118` 让进入页**横移整整一个页宽**，并手绘"纸边"渐变阴影（`:220` 的 `Color.fromRGBO(0,0,0,…)`）。`UI-DESIGN.md:16` 明确写着"不用装饰性玻璃、渐变或持续动画制造'原生感'"，`:138` 写着"不要手绘跨版本材质模仿"——这正是被禁止的那类东西。

另外动效时长是随意的：1400ms 脉冲（`loading_widgets.dart:22`）、230ms（`workspace_tab_transition.dart:24`）、280ms（`startup_page.dart:51`）、220ms（`apple_widgets.dart:761`），**没有一个走 `GinkgoMotion`**。

### 4.5 无障碍与交互

**做得好的**：Android 返回手势完整（`workspace_back_guard.dart:98-108` 的 `PopScope`，`workspace_shell.dart:248-292` 的 tab→工作台→退出排序，脏表单另有 `PopScope`）；表单标签同时给 `CupertinoTextField.label:` 和 `Semantics(label:)`（`login_page.dart:196-197,211-212,224-225` + `:321-324`）；27 处 `SafeArea`；**零个裸 `IconButton`/`GestureDetector`**——每个控件都是 Cupertino + `Semantics`；状态色一律配文字（`checkin_page.dart:549-555` 的"已签"/"待签"图例、`library_page.dart:232` 的 `booking.statusName`、`cgyy_page.dart:862-864`）。

**违反 `AGENTS.md:233` 的 ≥48dp 触控目标（8 处）**：
`apple_widgets.dart:63-68`（桌面返回键，padding 8 + icon 20 = **36dp**）、`:476-479`（`AppleGlassButton` 桌面 `minimumSize: Size(36,36)`）、`:542-543`（移动端 44×44，**这是每页都有的刷新/账号钮**）、`collection_toolbar.dart:70-89`（页码选择器只有约 20dp 高）、`:117-131`（上下页箭头 36dp）、`diagnostic_hints.dart:53-68`（约 29-31dp）、`long_page_scroll.dart:61-70`（回顶 FAB 约 37dp）、`today_page.dart:706,779` / `today_presentation.dart:86` / `library_books_page.dart:166,197` / `classroom_page.dart:647`。

**Semantics 覆盖偏薄**：全应用 61 处 `Semantics(...)`；`GinkgoIconTile.semanticLabel`（`ginkgo_visuals.dart:16`）存在但很少传值。Swift 侧是显式给每个图标按钮加标签的（`PageComponents.swift:151`）。

**大字号韧性**：20 个文件按 `MediaQuery.textScalerOf` 分支（`today_page.dart:593,649`、`schedule_page.dart:348,412`、`grades_page.dart:259`），`AppleListTile` 用 `ConstrainedBox(minHeight:)` 会长高（`apple_widgets.dart:428`）。但 `GinkgoBadge`（`ginkgo_visuals.dart:80-90`）把 11/12pt 文字放进只有 1–2px 垂直内边距的容器，**2.0× 缩放下会溢出**；`GinkgoIconTile` 把字形固定在 `size/2`（`ginkgo_visuals.dart:44`），图标不随文字缩放。

**SafeArea 部分缺失**：15 个页面文件完全没有 `SafeArea`，靠硬编码占位（`library_page.dart:169` 的 `const SizedBox(height: 96)`）。

### 4.6 空态与新手引导

**Apple 端强**：`PageEmptyState` → `ContentUnavailableView`（`PageComponents.swift:250-256`），`grades.png` 是合格的确认空，`library.png` 的四步 `QueryFlowSteps` 是可抄的模型。

**Flutter 端弱**：`AppleEmptyState` 存在（36 处）但只一半接线（见 3.4），`bykc_page.dart:427` 的"本学期暂无已选课程 / 学校返回了 0 条记录"**没有"上次检查时间"**，所以确认空与从未加载无法区分。

**完全没有新手引导**：`startup_page.dart` 是品牌闪屏，`login_page.dart` 是裸表单。登录后的用户进到一个空模块，得到的是一张静态卡片，而不是下一步提示。

---

## 5. 测试、CI、文档、流程：优秀

**CI 覆盖真实**。`.github/workflows/mirror.yml` 五个 job：contracts（架构门禁 + fmt + clippy + 三层 Rust 测试）、bindings（**重新生成 FRB 并 `git diff --exit-code` 校验生成物与源码一致**）、android（Ubuntu 上构建 ARM64 Debug APK）、windows（路径检查 + 构建 + widget 测试 + **Windows 集成测试** + 产物完整性校验 + 重新构建正常入口）。`ci.yml` 跑 macOS 全量 XCTest；`ios.yml` 用 XcodeGen 生成 + generic device build + 选可用模拟器跑测试。

**"正常入口"纪律被 CI 强制**。`mirror.yml` 的 windows job 在跑完集成测试后显式重新 `flutter build windows --debug --target lib/main.dart`，并注释"Integration tests rebuild the runner with their own Dart entrypoint. Restore the product main.dart before publishing a runnable artifact."——这防的是一个非常常见的真实事故。

**共享契约 fixture 是这个项目最聪明的设计之一**。`fixtures/` 用统一信封（`contract`/`version`/`source`/`input`/`expected`），Rust runner 递归消费全部文件、**遇到未知契约失败**（`services/contracts.rs` + `tests/contracts.rs`），Swift 侧 `SharedParserContractTests` 直接读**同一份** fixture 调**各自的生产解析器**断言同一 `expected` 投影——不复制算法、不生成第二份 JSON。`fixtures/README.md` 明确划出尚未双端一致的模块（签到、图书馆、博雅、研究生、SPOC 列表/详情），不夸大覆盖。

**文档纪律罕见地好**。`docs/API.md` 是唯一协议事实源，带 ✅/⚠️ 证据分级与修订对照表；`MIRROR-TODO.md` 只放未完成事项，P0/P1/P2 分层；`MIRROR-PARITY.md` 的对照表逐模块列"代码链路存在"与"真实证据"的差别。`docs/TESTING.md` 后面那 2000 多行的"目标测试方案"节**开头就显式免责**："以下各节保留目标测试方案及示例，出现 AuthService、GPACalculator 等类型不表示工程已有这些实现"——我核对过，`AuthServiceTests.swift`、`GPACalculatorTests.swift`、`SwiftDataStoreIntegrationTests.swift`、`E2ETests.swift` 等 7 个被引用的文件**确实不存在**，但文档已诚实标注，不算漂移（只是标题层级容易让快读者误解）。

**`.learnings/` 结构化错误日志**是我见过的最好实践之一：`LRN-20261015-001` 记的是"不要从通用客户端错误推断上游端点不可用"，`LRN-20261015-002` 记的是"要把先前观察到的真实成功与最近失败区分开"。把 AI 协作的纠错结构化沉淀下来。

**`MIRROR-TODO.md` 的验收边界表述专业**：反复强调"自动化通过不能替代真实写入验收""代理不自动执行真实提交""合成测试不代表真实业务已验收"。

---

## 6. 安全与隐私：强

- **零手搭 Cookie header**（Apple 侧）、**直连与 WebVPN cookie 存储物理分离**（`APIClient.swift:36-52`：WebVPN 用 `URLSessionConfiguration.ephemeral` + 独立 `WebVPNCookieStore.storage`，直连用 `.default` → `HTTPCookieStorage.shared`），并有断言测试（`CheckInClientTests.swift:11-19`）。
- **Keychain 唯一**，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`（`KeychainManager.swift:54,60`），凭据不进 UserDefaults。
- **日志脱敏到位**：`CasClient.redactedURL`（`:395-402`）只记录 host + path + **query key 名**；`CheckInClient.gatewayCookieScopeSummary`（`:545`）只记录 cookie 作用域不记名值；敏感插值一律 `privacy: .private`（`AppState.swift:60,82,110,252,258`、`CasClient.swift:127,440`）。
- **Rust 侧整个 workspace 零日志**（唯一 `println!` 在 `build.rs` 的链接参数里）→ 没有可泄漏的日志面。`AppError::Display` 只输出 code。`android_vault.rs:69-73` 主动吞掉 Java 异常消息（注释说"可能含数据"）。
- **本机待办隔离 + 最小化**：`tasks_store.rs:12-14` 按 `Sha1(account)` 分命名空间；`ginkgo_core/src/application/cgyy/tests.rs:418` 断言待核实标记里不含账号、表单、challenge 或凭据。
- **写操作人工授权**：`CLAUDE.md` / `AGENTS.md` 均禁止代理自动执行真实写入，`MIRROR-TODO.md` 也把"代理不得自动提交"写进 P0。

**一处可加固**：`LocalStore.swift:5` 的成绩/课表/预约是 **Application Support 下的明文 JSON**，只靠账号摘要隔离（文档已诚实说明"digest ≠ encryption"）。但 iOS 备份会包含 Application Support，`FileProtection` 是廉价的加固。

---

## 7. 优先级问题清单（Android-only 重排）

收窄为仅 Android 后，Apple 侧问题不再排期；Rust/Dart 问题从"两个栈之一"变成**全部产品**。

### P0 — Android 用户可感知或安全边界

| # | 问题 | 位置 |
|---|---|---|
| 1 | **强制刷新被静默丢弃**（下拉刷新无效） | `flutter/lib/application/refresh_section.dart:20-24`、`library_controller.dart:29-30,50-52`；16 处 `if (busy) return;` |
| 2 | **部分读命令无超时上界，可锁死登录/登出** | `ginkgo_flutter_bridge/src/api/live/{classroom.rs:29, library.rs:54,78, academic.rs:37, utilities.rs:48,73,115,125}` |
| 3 | **上游读路径缺 await 后账号复检** | `upstream/src/services/{library_service.rs:144,173-177,270,296-302, classroom_service.rs:53→82, homework_service.rs:20→52, bykc_service.rs:29→60, graduate_service.rs:45→78, notices_service.rs:19-21, schedule_service.rs:255→288}` |
| 4 | **FFI 可达 `unreachable!()`（panic 会 abort 进程）** | `cgyy_booking_service.rs:334,798`、`ginkgo_core/src/application/cgyy.rs:102` |

### P1 — Android 产品体验

| # | 问题 | 位置 |
|---|---|---|
| 5 | **空态与错误态同色同形**（错误三角 = 空托盘 = 同一个灰） | `flutter/lib/apple_widgets.dart:154-161`；36 处用点仅 16 处设 `error: true`（`bykc_page.dart:406,427,480` 完全没设） |
| 6 | **Flutter 缺"部分成功"表达**（多来源部分失败被折叠成整页失败） | `application/mirror_service.dart:54`、`homework_page.dart:143-148` |
| 7 | **页面解析桥接载荷**（18 文件 24 处 `jsonDecode`） | `ginkgo_flutter_bridge/src/api/live.rs:205-209` |
| 8 | **稳定业务规则留在了 Dart**（签到窗口 / 提醒排程 / 截止分类 / 学校"今天"） | `reminder_rules.dart:18-33,46-110`、`homework_projection.dart:44-70`、`checkin_page.dart:54-57`、`library_stats_page.dart:48` |
| 9 | **8 处 <48dp 触控目标**（违反 `AGENTS.md:233`） | `apple_widgets.dart:63-68,476-479,542-543`、`collection_toolbar.dart:70-89,117-131`、`diagnostic_hints.dart:53-68`、`long_page_scroll.dart:61-70` |
| 10 | **`GinkgoBadge` 大字号（2.0×）溢出** | `flutter/lib/ginkgo_visuals.dart:80-90` |
| 11 | **Semantics 覆盖偏薄（61 处）**；`GinkgoIconTile.semanticLabel` 存在但很少传值 | `flutter/lib/ginkgo_visuals.dart:16` |
| 12 | **15 个页面无 `SafeArea`**，靠硬编码占位 | `library_page.dart:169` 等 |
| 13 | **确认空缺"上次检查时间"**（确认空 ≠ 从未加载） | `bykc_page.dart:427` |
| 14 | **无新手引导**（登录后进空模块只有静态卡片） | `startup_page.dart`、`login_page.dart` |

### P2 — 设计系统与组件（Android 唯一的 UI 系统，权重上调）

| # | 问题 | 位置 |
|---|---|---|
| 15 | **token 采纳率 35%**（202 `fontSize` / 204 `EdgeInsets` / 199 `SizedBox` / 49 `BorderRadius` 硬编码；96 文件中 62 个零引用） | `flutter/lib/design/tokens/*`；门面过窄在 `apple_design.dart` |
| 16 | **无 token 采纳的 CI/lint 强制**（Rust 分层有门禁、Dart 没有——收窄后这是唯一的设计系统约束手段） | 建议加 `scripts/` 检查 |
| 17 | **三套分页 UI + 图标 tile 重复** | `collection_toolbar.dart`、`library_history_page.dart:176-183`、`library_books_page.dart:291`、`ginkgo_visuals.dart:7` |
| 18 | **动效时长全未走 `GinkgoMotion`**（1400/230/280/220ms 四个各自为政） | `loading_widgets.dart:22`、`workspace_tab_transition.dart:24` |
| 19 | **手绘"纸边"渐变违反自有规范** | `workspace_tab_transition.dart:109-118,220`（`UI-DESIGN.md:16,138` 明令禁止） |

### P3 — 架构债（Android 侧）

| # | 问题 | 位置 |
|---|---|---|
| 20 | `pub use codecs as features` 造出两个 `features` 命名空间 | `upstream/src/lib.rs:7` |
| 21 | 阻塞 fsync + 全局锁跑在 tokio worker，串行化所有账号 | `ginkgo_core/src/cgyy_pending_store.rs:15,51,77,111`、`tasks_store.rs:11` |
| 22 | CGYY 写操作持全局写锁，阻塞全应用读 | `bridge/src/api/live/utilities.rs:80` |
| 23 | `edit_tasks` 用 `try_read()`，登录中直接失败 | `bridge/src/api/live/utilities.rs:13` |
| 24 | 写结果按中文字面量子串判定 | `codecs/library_mutation.rs:43-66` |
| 25 | library token 重试块复制 5 遍 | `upstream/src/services/library_service.rs:100-110` |
| 26 | **零日志/可观测性**（Rust workspace 全无日志）——线上排障只能靠复现 | workspace-wide |

### 冻结（Apple 侧，不再排期）

原 #2 僵尸轮询、原 #6/#7/#8 跨端一致性、原 #9/#10 macOS 视觉、原 #27–#34 Apple 路由与死代码等，**在 Android-only 下不再是缺陷**。其中两条需注意：

- **跨端强调色分裂（绿 vs 蓝）自动消失**——不再有第二个栈要对齐。但反过来，Flutter 的绿色 `0xff189840` 现在是**唯一**强调色，需确认它作为产品主色成立（当前 App 图标是蓝色，见 `docs/images/`）。
- **macOS 的两个视觉问题 Flutter 侧不存在**：Flutter 周网格**已有**横向滚动（`schedule_grid.dart:199-214`，含 `CupertinoScrollbar` 顶部滚动条与 `DayScrollPhysics`），Flutter Today 页**没有**运维日志段落。因此这两条不必迁移，只需在 Android 端复核。

---

## 8. 建议的推进顺序（Android-only）

**第一批（一次提交可覆盖，收益最大）**
1. 修 #1 强制刷新：把 `refresh` 的合并键改为包含 `force`，或在途任务结束后若收到过 force 请求则再跑一次；并把 16 处 `if (busy) return;` 改成"标记一次待刷新"。
2. 修 #2 给所有读命令加 `bounded_read`。
3. 修 #4 把 3 处 `unreachable!()` 换成类型化错误。

**第二批（Android 产品体验）**
4. 给 `AppleEmptyState` 两个图标色并把所有失败路径接上 `error: true`（#5）；补"部分成功"表达（#6）。
5. 修 8 处 <48dp 触控目标（#9）与 `GinkgoBadge` 大字号溢出（#10）。
6. 补新手引导（#14）与确认空的"上次检查时间"（#13）。

**第三批（结构性，需先设计）**
7. 给 `AppleDesign` 补齐 token 门面 + **一个 CI token 采纳检查**（#15、#16）——收窄为 Android 后这是守住设计系统的唯一自动化手段。
8. bridge 补 9 个端点的 DTO，删掉 Dart 里的 `jsonDecode`（#7）。
9. 把 Dart 里的稳定规则搬回 `ginkgo_domain`（#8）。
10. 上游读路径统一加账号复检，或快照按账号分键（#3）。

**关于 Flutter 侧的两个"看起来很大"的问题——`RefreshSection`/`LibraryController`/`SectionFeedback`/`CollectionToolbar` 只被 1–2 个页面使用——建议不要一次性重构。** 更稳的做法是：先修掉它们共有的那个 bug（#1），再在新页面里默认用它们，让旧页面在被修改时逐个迁移。这比"把 34 个页面的状态管理统一重写"风险低得多，也更符合这个项目一贯的"小步 + 有证据"的工作方式。

---

## 9. 结论

**这是一个工程质量明显超出个人项目平均水平的作品**：架构约束被写成了 CI 门禁而不是文档承诺，写操作有真正的状态机与回查，协议差异被诚实地留在上游本地，验收边界在文档里反复声明，AI 协作的纠错被结构化沉淀。

收窄为 Android-only 之后，**结论比之前更集中、也更乐观**：跨端一致性这整个维度（原本 P1 的 5 条）不再存在；Rust/Dart 这一个栈的每一个缺陷都从"两个栈之一"变成"全部产品"，因此上面 P0 的 4 条应该被当成 Android 产品的必修项，而不是可选优化。

剩下的主要问题仍是**一组已知的技术债没有排上修复顺序**——token 采纳率、bridge 的字符串逃生舱、若干异步与生命周期边角。

---

## 10. 范围收窄为"仅 Android"本身带来的新风险

这一节是收窄决策**新增**的问题，不在原评审范围内。按对交付的影响排序。

### 10.1 Android 是唯一发布路径，却是唯一没有自动发布 CI 的平台 —— P0

实测 `.github/workflows/`：

| 平台 | 发布 workflow | 触发 |
|---|---|---|
| macOS | `release.yml` | tag `v*` ✅ 全自动 |
| Windows | `windows-release.yml` | tag `windows-v*` ✅ 全自动（Inno Setup + SHA-256 + 校验） |
| **Android** | **无** | **全手工** |

`AGENTS.md:266` 确认："当前没有自动 Android Release workflow；按对应发布记录执行签名 ARM64 正常入口构建、产物/摘要/签名校验、覆盖升级和 GitHub prerelease 发布。"

**这不是理论风险。** `docs/_audit/2026-10-23-android-alpha7-release.md:24` 记录的正是手工流程的一次真实失败：

> Release 初次因 GeneratedPluginRegistrant 引用 integration_test 而 Gradle 排除 dev plugin 编译失败……改用 `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`

也就是说，**一个 CI 里跑一遍就能自动发现的产物污染问题，在手工流程里发生了一次**（而且是在已经准备发布的包上）。收窄为 Android-only 后，这条路径没有任何自动化兜底。

**建议**：加 `.github/workflows/android-release.yml`，tag `android-v*` 触发。签名仍留本地（`GINKGO_ANDROID_SIGNING_PROPERTIES` 外部注入、缺配置即失败——这个设计是对的，不要改）。CI 负责可自动化的部分：

1. `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub` ——**必须带 `--pub`**，正是 Alpha.7 踩过的坑；
2. 断言产物里**不含** `integration_test`（与 `mirror.yml` 里 Windows 那条"Restore the product main.dart"同源的正确思路）；
3. 计算并记录 SHA-256、校验 APK 内 manifest 与版本号、`apksigner verify`；
4. 上传为 workflow artifact（不自动发布——发布仍需人工确认，因为涉及真实学校写入验收）。

这样至少保证"构建可重复、产物干净、摘要可信"三件事不依赖人。

### 10.2 仓库指令文件会持续误导后续协作 —— P0（成本最低、影响最广）

仓库有 **2 个指令文件 + 80 个文档**，它们当前描述的是一个四平台项目：

- `AGENTS.md:9` 写的是"macOS / iOS 是独立的 Swift/SwiftUI 应用……**Apple 功能开发不是默认范围**"——接近但**不等于**"只开发 Android"。按现在的措辞，后续协作者仍会认为 Apple 是"次要但在范围内"。
- `AGENTS.md:66`、`:237-242` 整节在讲 Apple 结构与 Swift 约定；`AGENTS.md:174-194` 的构建章节有 Apple 专段。
- `CLAUDE.md` 开头整段是 Swift 架构说明。
- `README.md` **首屏**就是 macOS/iOS 产品介绍 + 12 张 macOS 截图，"界面预览"全部是用户拿不到的产品。
- `docs/MIRROR-PARITY.md` 是 Apple↔Flutter 对照表——Apple 冻结后它变成历史对照，读者仍会误以为需要追平。
- `docs/MIRROR-TODO.md` 的 P1 里混着 Apple 条目（VoiceOver 验收、Swift 抽取模型与解析器等）。
- `docs/UI-DESIGN.md` 全篇是 **macOS 原生** UI 准则，标题即"macOS 原生 UI 设计准则"——而现在唯一的 UI 是 Flutter/Android。

**后果是可预见的**：下一个 AI 或协作者读到这些文件，会继续为 Apple 排期、继续修 Apple 缺陷、继续做跨端对齐——把本该投给 Android 的注意力分掉一半。Apple 侧那 8 个"待修"问题正是这么来的。

**建议**（一次提交可完成，纯文档）：

1. `AGENTS.md` / `CLAUDE.md` 顶部加一句明确的范围声明：**"当前唯一开发目标是 Android（Flutter + Rust）；Apple 端冻结，只修构建与安全问题，不再做功能开发与跨端对齐。"**
2. `AGENTS.md` 的 Apple 结构节与 Swift 约定节标注"冻结，仅供理解历史实现"。
3. `docs/MIRROR-TODO.md` 把 Apple 条目移到单独的"冻结（不再排期）"小节，P0–P2 只留 Android。
4. `README.md` 重排：Android 为主，macOS/iOS 降为"历史版本"一段。
5. `docs/UI-DESIGN.md` 改为 Flutter/Android 侧的设计准则；macOS 准则归档到 `docs/archive/`。
6. `docs/MIRROR-PARITY.md` 标题与开头加"Apple 端已冻结，本表为历史对照，不再作为追平依据"。

### 10.3 Apple 冻结树仍在每次 push 跑 CI —— P2

`ci.yml`（macOS 全量 XCTest）与 `ios.yml`（XcodeGen + iOS 构建 + 模拟器测试）当前**每次 push/PR 都跑**。Swift 不再演进后：

- 它们不再提供有效安全网（保护的是不再变化的代码）；
- 但会消耗可观 CI 分钟；
- 更麻烦的是 **`fixtures/` 是共享的**：Rust 侧若改动契约格式，Swift 的 `SharedParserContractTests` 会失败——那是一个**没人关心的假警报**，却会让 CI 变红，训练团队忽略红色。

**建议**：给这两个 workflow 加 `paths:` 过滤，只在 `BUAA-Assistant/**`、`BUAA-Assistant-iOS/**`、`fixtures/**`、`BUAA-AssistantTests/**` 变化时触发。保留最小安全网（防"我改坏了 Rust 契约，Swift 编译不过"），同时去掉大部分无效运行。**不建议直接删除 Swift 代码**——25.6K 行里包含 `LocalStore`/`SchoolTime`/`HTMLText`/`AESCipher`/`FormURLEncoding` 等已被 Rust 侧重新实现的思路，且删除会让 `fixtures/` 双端契约失去意义。

### 10.4 "Apple" 命名的语义失效 —— P2（可选，机械但有波峰）

`flutter/lib/apple_design.dart` 与 `apple_widgets.dart`（共 811 行）里的 "Apple" 指的是"对齐 macOS 设计基线"。macOS 不再是参照物后，这个命名失去依据，**但它是 Flutter 侧唯一的共享组件库**——重命名 54 个引用文件会造成一个巨大的、纯语义的 diff，正好落在你不想有波峰的时候。

**建议**：**暂不重命名**。在两个文件的顶部注释里写清楚"历史命名：源自早期对齐 macOS 设计的基线；当前是 Android 端唯一的共享 UI 基座"。等下一次大版本节点（如 1.0）再整体改名。`flutter/lib/ginkgo_visuals.dart` 已是中性命名，是好范例。

### 10.5 README 的界面预览展示的不是产品 —— P2

`docs/images/` 有 **12 张 macOS 截图 + 1 张 Windows 截图，0 张 Android 截图**。README 的"界面预览"章节因此展示的是用户拿不到的产品。这是收窄后最直接的用户沟通问题。

**建议**：补 3–5 张真机 Android 截图（今天 / 课表 / 图书馆 / 作业 / 签到），替换 README 的预览章节。**注意 `AGENTS.md:246` 的隐私红线**：真机截图必须打码姓名、学号、课程、成绩，且不能把原始 HAR 或个人数据入库。已有的 macOS 截图正是打过码的（`today.png` 里课程名与姓名是马赛克），可以照此办理。

### 10.6 Apple 侧更成熟、需主动迁移到 Android 的实现 —— P1

Apple 冻结后，那边"比 Android 好"的部分**不会自动迁移**。逐条核对后：

| Apple 侧成熟点 | Android 侧状态 | 动作 |
|---|---|---|
| 写操作"结果待核实"UX（`.uncertain` 语义 + 文案 + 锁住后续提交） | **已迁移且更完整**（Swift 20 处 / Dart 24 处） | ✅ 无需动作 |
| 直连与 WebVPN cookie 物理隔离 | Rust 侧等价实现已具备 | ✅ 无需动作 |
| `SessionExpired` vs `BusinessRejected` 区分 | Rust `ErrorCode` 1:1 桥接，Dart 侧可用 | ✅ 无需动作 |
| **多来源"部分成功"表达**（"以下来源暂时未能更新…；作业结果不完整"） | **缺失** | 迁移（P1 #6） |
| **图标按钮的显式无障碍标签质量**（Swift 侧逐个给） | Semantics 仅 61 处 | 迁移（P1 #11） |
| 确认空态的"上次检查时间" | 多数页面缺失 | 迁移（P1 #13） |

上表第一行是好消息：最容易丢的"写操作不确定"语义**已经完整搬到 Flutter 了**。真正需要主动迁移的只有后三条，且都属于 Flutter 侧本身的问题，不需要读 Swift 代码。

### 10.7 Rust/Dart 现在是全部产品 —— 判定标准随之改变

收窄前，一个 Rust 层的缺陷只影响"两个栈之一"；收窄后，**每一个 Rust/Dart 缺陷都直接命中 100% 的用户**。这带来两个判定上的变化：

1. **原 P1 的跨端一致性整组消失**（绿 vs 蓝强调色、"今天"IA 分叉、"已更新"横幅配色）。其中"已更新"横幅配色问题（`ScheduleView.swift:24` 绿 vs `LibraryView.swift:32` 蓝）**在 Flutter 侧需要单独复核**——Flutter 是否有同样的不一致？本评审未逐页核对 Flutter 的横幅配色，**建议列为一次专项排查**。
2. **原 P0 的 Apple 僵尸轮询不再是 P0**（Swift 不再跑），但**原 P0 的 4 条 Rust/Dart 缺陷全部升为"Android 产品的必修项"**，不再是可以缓一缓的"另一个栈的问题"。

### 10.8 一个需要你确认的决策：Windows 是否也停？

`flutter/windows/` 与 Android **共用同一个 Flutter 工程**（`flutter/windows/CMakeLists.txt` 等）。`AGENTS.md:8` 现在的表述是"Windows 复用 Flutter + Rust，共享代码改动必须保持 Windows 兼容"。

"只开发 Android 端"有两种解读，后果不同：

- **解读 A（推荐）**：Windows **不再做功能开发**，但继续保证可编译可运行（因为它共享同一个 Flutter 工程，编译成本几乎为零），并且保留 `windows-release.yml`。这样"Android-only"指的是**投入**，不是**代码存在性**。
- **解读 B**：Windows 也彻底停掉，`flutter/windows/` 与 `windows-release.yml` 一并冻结/移除，CI 只保留 Rust/Flutter/Android 三个 job。

**我倾向 A**：Windows 的构建成本几乎为零（`mirror.yml` 里只是多了两个 job），而删掉它会失去一个"同一份 Flutter 代码在桌面端跑得通"的交叉验证——这恰好是 Flutter 层 bug 的免费探测器。但这是你的取舍，我按 A 执行，除非你说 B。

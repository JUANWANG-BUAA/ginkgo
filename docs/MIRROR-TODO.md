# Rust + Flutter 镜像待办

更新：2026-10-24。这里只保留未完成事项；实现范围见 [现状](MIRROR-IMPLEMENTATION.md)，模块差距见 [对照表](MIRROR-PARITY.md)。完成需有代码和相应层级的验证证据，不反复追加已完成过程；历史计划保留于 [归档](archive/mirror/README.md)。

> **当前唯一开发目标是 Android（Flutter + Rust）。macOS / iOS 暂时冻结**，不做功能开发、不做跨端对齐、不为其排期；只在影响 Android 构建、共享 fixture 或存在安全问题时被动修。Windows 与 Android 共用同一 Flutter 工程，不做功能开发但必须保持可编译。范围决策见 [多平台路线](MULTI-PLATFORM-STRATEGY.md#当前开发范围2026-10-24-决策)。

## 当前推进顺序：先收口，再扩展

当前主线为 **Android / Flutter + Rust**。以工作树为准，不将历史设计或已发布内容重复排成新开发任务。

- 已发布基线：Android Alpha.7（build 8）；Windows Alpha.6（build 7）。证据见 [发布记录](_audit/2026-10-23-android-alpha7-release.md)。
- Alpha.7 后源码：作业提交状态与截止判定分离、工作台/学分展示优化、CGYY 静态协议对齐、公开查书/馆藏与排序、应用内校车时刻表；`e149f90` 已移除作业详情“加入个人待办”，保留既有本机数据。2026-10-24 复核批次另含：CAS 表单 action 白名单、账号身份一致性校验（`account == profile.school_id`）、保险库枚举失败不再视为空、快照缓存请求代次防护、课程范围读取失败锁定编辑、显式退出标记阻止自动恢复、更新门禁时序与发布址白名单、课表已确认快照、作业详情倒计时取最新状态、APK 校验失败可重下载、`RefreshSection`/`LibraryController` 强制刷新补跑、FFI 可达 `unreachable!()` 清除、预约按钮组件与查书目页重做、导航栏强调色（`navActionTextStyle`）。以上不意味着已经发新包或通过所有真实业务验收。
- [下一阶段方案](NEXT-STAGE-PLAN-2026-10-23.md) 与 [IA方案](NEXT-STAGE-IA-2026-10-23.md) 保留研究依据，不能将其中已落地方案重新实施，也不能将未批准的导航/写能力视为现有功能。
- 执行顺序：**P0 可复现回归与安全边界 → P1 设备/账号验收及小步体验 → P2 扩展**。本地自动化与正常入口构建通过只能关闭相应本地事项；需要本人账号、真实写入或物理设备的条目继续保留。
- **2026-10-24 综合评审**（工程 / 设计 / UI / 视觉）已按 Android-only 重排，其可复现缺陷并入下方 P0 / P1，范围收窄带来的新风险并入 P0：[_audit/2026-10-24-comprehensive-review.md](_audit/2026-10-24-comprehensive-review.md)。

本轮盘点与回归证据见 [推进收口记录](_audit/2026-10-23-android-progress-closeout.md)；随后完成 [图书馆与校车模拟器真实只读视觉闭环](_audit/2026-10-24-library-shuttle-visual.md)，修复键盘遮挡与窄屏大字双列，保留物理设备、TalkBack、真实非空订单/写入等人工事项；这些记录不替代下方人工验收。

## P0：认证可靠性与真实行为

- [ ] **消除 16 处 `if (busy) return;` 静默丢弃刷新**：`notices_page.dart`、`cgyy_page.dart`、`homework_page.dart`、`library_stats_page.dart`、`shuttle_page.dart`、`library_books_page.dart` 等。初次加载期间的下拉刷新被丢弃且无任何反馈，违反“重叠读取合流、刷新保留旧内容”。改为记录一次待刷新并在下一次机会执行。`RefreshSection` 与 `LibraryController` 的强制刷新合流问题已在 2026-10-24 修复，其余页面的 busy 守卫仍未迁移。
- [ ] **给所有读命令加超时上界**：`bounded_read`（`ginkgo_flutter_bridge/src/api/live/runtime.rs:20-26`，45 秒）已覆盖场馆/预约/历史/作业/签到/博雅/研究生，但**未覆盖** `load_classrooms`（`classroom.rs:29`）、`load_library_areas`/`load_library_slots`（`library.rs:54,78`）、`load_today`（`academic.rs:37`）、`load_notices`/`load_cgyy`/`load_shuttle_timetable`/`load_book_holdings`（`utilities.rs:48,73,115,125`）。慢 SSO 链可让 `SESSION_ACCESS` 读锁被持住数分钟，阻塞 `login`/`sign_out`/`set_route`/`clear_cache`。
- [ ] **上游读路径补 await 后账号复检**：12 条左右读路径中只有 `library_service.rs:84,112-114`（历史）与 `checkin_service.rs:148,181,208-210` 做了 await 后复检。缺失：`library_service.rs:144→173-177`（场馆）与 `:270→296-302`（预约）、`classroom_service.rs:53→82`、`homework_service.rs:20→52`、`bykc_service.rs:29→60`、`graduate_service.rs:45→78`、`notices_service.rs:19-21`、`schedule_service.rs:255→288`。当前被 bridge 的 RwLock 挡住、无实际跨账号泄漏，但上游层不自洽，且快照 key 是常量（`"venues"`/`"bookings"`/`"current"`/`"public"`）。二选一：统一加 `current_account() != account → Err(session_expired)`，或快照按账号分键。
- [ ] 对 [最近认证失败](_audit/2026-10-21-auth-redirect-incident.md) 中的 UC→HTTP SSO 跳转，区分旧版行为、Alpha.4 已发布修复与后续实网复验结果。合成修复通过不能替代用户授权下的真实复验，不推断账号被封。
- [ ] 在用户逐次人工操作下验收签到、图书馆预约 / 取消 / 暂离 / 离馆及 CGYY 预约 / 取消，记录提交前状态、结果分类、审批与取消回查；CGYY 还需覆盖重启/重登后的待核实保护和可取消时间门禁、真实非空订单。现有自动化通过不能勾除此项，代理不自动执行真实写入。
- [ ] 补充受控超时、断网与认证失败的模块回归，重点保留旧快照、恢复次数上限和写操作不重放；不为了消除失败而放宽业务断言。
- [ ] 继续定位首次 iclass / 博雅 / 研究生读取的高延迟及“切页才更新”反馈。Alpha.4 已有阶段 / 耗时反馈、并发恢复、缓存锁前命中、迟到 token 失效和预约回查同步修复；尚无足够证据宣布所有等待问题已消除。

## P1：Android 产品与平台验收

- [ ] **增加 Android 自动发布 workflow**：`.github/workflows/` 下 macOS 有 `release.yml`（tag `v*`）、Windows 有 `windows-release.yml`（tag `windows-v*`），**Android 没有任何自动发布 workflow**，当前完全手工。Alpha.7 发布记录（[_audit/2026-10-23-android-alpha7-release.md:24](_audit/2026-10-23-android-alpha7-release.md)）记载的正是手工流程的一次真实失败：Release 因 `GeneratedPluginRegistrant` 引用 `integration_test` 编译失败。收窄为 Android-only 后这条路径没有兜底。建议 tag `android-v*` 触发：签名仍留本地（`GINKGO_ANDROID_SIGNING_PROPERTIES` 外部注入、缺配置即失败，此设计不改），CI 负责可自动化部分——带 `--pub` 构建、断言产物不含 `integration_test`、计算并记录 SHA-256、`apksigner verify`、上传 workflow artifact（不自动发布，真实写入验收仍需人工确认）。
- [ ] **区分空态与错误态**：`apple_widgets.dart:154-161` 的 `AppleEmptyState` 对 error 与 empty 两个分支使用同一灰色图标（`CupertinoColors.secondaryLabel`），错误三角与空托盘不可分；36 个使用点中仅 16 处设了 `error: true`，`bykc_page.dart:406,427,480` 完全没设，博雅加载失败显示为灰色空托盘。给两个分支独立图标色并把所有失败路径接上 `error: true`。
- [ ] **补 Flutter 侧的“部分成功”表达**：Swift 端有“以下来源暂时未能更新：…；作业结果不完整”，Flutter 的 `homework()` 只返回单个 `HomeworkResponse`（`application/mirror_service.dart:54`），`homework_page.dart:143-148` 把任何来源失败折叠成整页错误或“显示上次结果”。多来源部分失败在 Android 端当前不可表达。
- [ ] **修 `GinkgoBadge` 大字号溢出**：`ginkgo_visuals.dart:80-90` 把 11/12pt 文字放进仅 1–2px 垂直内边距的容器，2.0× 缩放下溢出。`GinkgoIconTile`（`ginkgo_visuals.dart:44`）字形固定为 `size/2`，图标不随文字缩放。
- [ ] **补 Semantics 与 SafeArea 覆盖**：全应用仅 61 处 `Semantics(...)`，`GinkgoIconTile.semanticLabel`（`ginkgo_visuals.dart:16`）存在但很少传值；15 个页面文件完全无 `SafeArea`，靠硬编码占位（`library_page.dart:169` 的 `const SizedBox(height: 96)`）。共享 `choose` 菜单的选中项 Semantics 与 8 处 <48dp 触控目标已在 2026-10-24 修复，其余 Semantics/SafeArea 缺口仍开放。
- [ ] **横竖屏跨越 760dp 时提升导航状态**：移动 tab 壳与桌面侧栏壳在断点两侧分别重建（`workspace_shell.dart`），旋转后当前目的地回到工作台、未提交表单丢失；需把选中目的地与各 tab 导航栈提升到壳层共享状态。
- [ ] ~~**待办编辑增加脏草稿放弃确认**~~ —— 已完成（2026-10-24）：`task_editor.dart` 有未保存修改时返回弹出“放弃未保存的修改？”确认，未编辑时静默退出。
- [ ] **物理 Android 真机验收系统返回/预测返回、TalkBack 全流程、大字号/深浅色及长列表性能**；覆盖强调色、常用入口、栏目过渡与新校车页实际帧率。合成 widget 与 ARM64 模拟器不能替代。
- [ ] 用户授权下核对真实作业来源定位与截止时间；验证已提交无倒计时、待处理排除已截止、个人待办不重复显示学校来源事项，保留 v1→v2 升级前备份与不可降级编辑说明。不得新增提交权限或自动改学校状态。
- [ ] 公开查书/馆藏与校车时刻表补真实设备只读验收：~~排序/分页/空态/限流与官方对照~~ 排序/分页/公开检索已随 2026-10-24/25 授权账号只读验收覆盖（真实目录检索、翻页、卡片渲染），余静态时刻表与官方页对照保留。~~区分计划可乘人数与实时余票~~ 已由 2026-10-25 授权实测定证：智慧校车系统不接 CAS（CAS 会话下 indexPage 仍报未认证、ShiftsSearch 403），动态余票确认不接入，维持静态时刻表+官方外链。图书馆本人非空借阅不在公开目录验收范围。
- [ ] 评审剩余扩展的依赖与分包范围：我的借阅（非空模型/分页/隐私待验）、热门/封面、未来七天聚合、筛选记忆与课表导出；预约摘要不得增加首屏阻塞。校车动态余票在完整事务与资格证据前不接入。
- [ ] 阳光打卡 P1 安全写闭环：先补上传/提交/回查与 `isopen` 服务端语义证据及隐私、单写门禁评审，通过后分包实现本人手动填写/照片/确认流程，真实提交另行逐次授权。未验证前不得开放真实提交或承诺私密，不执行自动打卡。
- [ ] 真实非空成绩 / GPA、本科教务账号、图书馆多页历史、博雅非空已选记录及 CGYY 非空订单逐项对照；既往研究生账号的成功空结果不覆盖这些分支。
- [ ] 设备复核北京时间跨午夜、学期 / 周次切换、离屏页返回和缓存失效；保留 `mirror_test.dart` 校区 / 日期 / 缓存长流程未收敛的记录，先拆成有界场景定位。
- [ ] 空教室刷新后的精确像素锚定：已保留页码与页首条目，但 sliver 重排仍可能产生可见位置偏移（合成观察约 119px）；与设备滚动性能、读屏验收一并补。
- [ ] **补 Android 真机截图并替换 README 界面预览**：`docs/images/` 现有 12 张 macOS + 1 张 Windows、**0 张 Android**，README 展示的不是产品。补今天 / 课表 / 图书馆 / 作业 / 签到 3–5 张；按隐私红线打码姓名、学号、课程、成绩，不入库原始 HAR 或个人数据。
- [ ] **专项排查 Flutter 侧“已更新”横幅配色**：macOS 侧存在同语义不同色（`ScheduleView.swift:24` 与 `GradeView.swift:25` 用 `.success` 绿，`LibraryView.swift:32` 用 `.information` 蓝）。Flutter 侧是否同样不一致尚未逐页核对，收窄后 Flutter 是唯一 UI 端，需统一。

## P2：功能与结构

- [ ] **补齐设计 token 采纳并加 CI 强制**：`flutter/lib/design/tokens/` 定义质量高（4pt/8pt 间距、HIG 类型标尺、圆角、动效），但 96 个应用 Dart 文件中 **62 个（65%）零引用**，实测硬编码 202 处 `fontSize`、204 处 `EdgeInsets`、199 处 `SizedBox`、49 处 `BorderRadius`；仅 `apple_design.dart` 引用了 token，且只暴露约 60 个中的 16 个（`AppleDesign.title` 还被别名到 `largeTitle`，与 `body` 之间缺整档）。根因是门面过窄而非页面懒惰。收窄为 Android-only 后这是唯一的设计系统，补齐门面 + 一个 CI token 采纳检查（Rust 分层已有门禁、Dart 没有）是守住它的唯一自动化手段。
- [ ] **为 9 个端点补 bridge DTO，删掉 Dart 里的 `jsonDecode`**：18 个 Dart 文件 24 处 `jsonDecode` 直接读学校字段名（`space_id`/`time_ids`/`currentTerm`/`phase`/`bibId` 等），根因是 `ginkgo_flutter_bridge/src/api/live.rs:205-209` 的 `ReadOnlyResponse { payload: Option<String>, … }` 逃生舱被约 9 个端点使用。载荷是 Rust 净化过的领域 JSON（不是原始上游数据），属契约侵蚀而非凭据泄露；修复顺序是先补 DTO 再删 Dart 解析。
- [ ] **把稳定业务规则搬回 `ginkgo_domain`**：`reminder_rules.dart:18-33`（签到窗口）、`:46-110`（提醒排程）、`homework_projection.dart:44-70`（截止分类）、`checkin_page.dart:54-57` 与 `library_stats_page.dart:48`（UTC+8 学校“今天”）目前留在 Dart，违反“学校日期与稳定业务规则留在 Rust”；放回 domain 才能拿到 Rust 单测。
- [ ] 补齐验证码图片传输、展示和刷新；当前挑战提示与手填框仍不足以完成所有风控分支。
- [ ] “登录成功但密码保存失败”提供就地提示；解释 WebVPN 网关为何可能要求记住密码，减少首次使用的困惑。
- [ ] 继续验收已接入的签到 / 作业本地提醒：Android 权限拒绝 / 恢复、重启、强停和厂商省电；补 Windows 系统通知、完整课程 / 待办提醒、后台能力及查询快照持久化。
- [ ] 完整研究生学分地图及成绩 / 考试组合、图书馆本机趋势仍未齐；SPOC 附件下载 / 作答 / 提交、希冀来源、BYKC 选退课 / 签到、CGYY 门锁码尚未迁移，预约 / 取消已接入但真实往返未验收。
- [ ] 其他异步复杂页面在出现跨路由状态或重复加载职责时参考 `LibraryController`；**不要求一次性统一重构**——先修掉共用的强制刷新缺陷，再在新页面默认使用 `RefreshSection`/`LibraryController`/`SectionFeedback`，旧页面在被修改时逐个迁移。
- [ ] 移动端“个人与校园”快捷入口（`service_directory.dart`）仍是精选清单，与 `workspace_catalog.dart` 的功能清单重复；如需完全单一来源，可改为从登记表派生（需把 `WorkspaceContext` 工厂传入目录）。
- [ ] 更新体系：最低版本门禁已接入（`update_gate.dart` + `docs/update-gate.json`，拉取失败放行）；清单签名、差分补丁、灰度/回滚、Windows Authenticode 与应用内更新仍待做。提升 `minBuild` 前必须确认新版本已可下载，避免把旧版锁在无法更新的状态。
- [ ] Android 应用内下载、断点续传、摘要 / 签名校验和系统安装确认已进入 Alpha.4；Alpha.6→7 的签名包模拟器覆盖升级已完成，仍需发布后在物理设备验证旧版发现、未知来源授权、覆盖升级和网络中断恢复。
- [ ] 架构债清理（低优先，逐项处理）：`upstream/src/lib.rs:7` 的 `pub use codecs as features` 造出两个 `features` 命名空间（`crate::features::cgyy::number` 是编解码器、`day` 是领域规则）；`ginkgo_core/src/cgyy_pending_store.rs:15,51,77,111` 与 `tasks_store.rs:11` 在 tokio worker 上做阻塞 fsync 且持全局锁、串行化所有账号；`bridge/src/api/live/utilities.rs:80` 的 CGYY 写操作持全局写锁阻塞全应用读、`:13` 的 `edit_tasks` 用 `try_read()` 在登录中直接失败；`codecs/library_mutation.rs:43-66` 按中文字面量子串判定写结果；`upstream/src/services/library_service.rs:100-110` 的 token 重试块复制 5 遍；Rust workspace 零日志可观测性，线上排障只能靠复现。

## 冻结：macOS / iOS（2026-10-24 起不再排期）

以下条目随范围收窄移出主线，**不做功能开发、不做跨端对齐**；仅在影响 Android 构建、共享 fixture 或存在安全问题时被动处理。完整问题清单见 [综合评审 §7「冻结」](_audit/2026-10-24-comprehensive-review.md)。

- [ ] ~~Swift 的 LibraryClient / CheckInClient / CgyyClient 按模块逐步抽取模型、密码学与纯解析器~~ —— 冻结。
- [ ] ~~Apple VoiceOver 与其他平台减少动态效果等全模块验收~~ —— 冻结；Android 侧读屏验收见 P1。
- [ ] ~~扩展 Swift / Rust 同源解析契约到签到、图书馆、博雅、研究生和 SPOC 列表 / 详情~~ —— **拆分**：Rust 侧继续扩（属 Android 契约面），Swift 侧冻结。已有覆盖见 [fixtures 说明](../fixtures/README.md)。
- [ ] ~~Windows 物理 x64 / 干净系统依赖、完整键盘与读屏、真实只读及签名 / 更新方案~~ —— 降级为“保持可编译”，不做功能开发；Windows 侧不新增排期。
- [ ] ~~macOS / iOS 的僵尸轮询、`LibraryClientTests` 缺失、`GraduateRequirementView` 死代码、三处路由绕过等~~ —— 冻结，不修（其中跨端强调色分裂随范围收窄自动消失）。

## 文档维护

- 三个入口只写一次现状、待办和差距；发布、审计及验收按日期归档并从入口链接，协议唯一事实源仍是 [API](API.md)。
- README 不写会随提交变化的测试 / fixture 总数；需要数量时从当次运行输出取得并连同日期记录。
- 代码检索排除 FRB 生成物；不把生成代码比例或 `Semantics` / `setState` 出现次数直接当作质量结论。
- 范围收窄后，`docs/MIRROR-PARITY.md`（Apple↔Flutter 对照表）作为历史对照保留，不再作为追平依据；`docs/UI-DESIGN.md` 需补 Flutter/Android 侧准则，macOS 准则归档到 `docs/archive/`。

# Rust + Flutter 镜像待办

更新：2026-10-26。这里只保留未完成事项；实现范围见 [现状](MIRROR-IMPLEMENTATION.md)，模块差距见 [对照表](MIRROR-PARITY.md)。完成需有代码和相应层级的验证证据，不反复追加已完成过程；历史计划保留于 [归档](archive/mirror/README.md)。

> **当前唯一开发目标是 Android（Flutter + Rust）。macOS / iOS 暂时冻结**，不做功能开发、不做跨端对齐、不为其排期；只在影响 Android 构建、共享 fixture 或存在安全问题时被动修。Windows 与 Android 共用同一 Flutter 工程，不做功能开发但必须保持可编译。范围决策见 [多平台路线](MULTI-PLATFORM-STRATEGY.md#当前开发范围2026-10-24-决策)。

## 本轮 Goal：原会话全范围集成与交付（2026-10-26）

**目标**：逐项落实原会话承诺的 SPOC 学习/作业、验证码、学分地图、课程/待办提醒、查询快照与本人借阅；模块仅暴露业务接口，App 能区分未支持、未验证、认证失败、暂不可用和协议变化。完成可独立执行的实现、回归及 Android 合成设备验证；不将真实学校写入、物理设备或人工安全审查冒充完成。

本表是本轮唯一执行清单。状态随代码与证据更新；完成的实现证据转入实施现状/带日期审计，不另建 TODO。

| ID | 执行事项 | 当前状态 / 完成条件 |
| --- | --- | --- |
| G04 | 个人文件作业的真实提交与回查验收 | 代码/default 入口/journal/合成门禁已落实；剩余本人逐次指定作业和最终文件的真实操作，详见 P2 |
| G05 | 小组/文本/链接作答协议 | 字段及共用提交组件已定位；仍缺组身份/代表资格、后端文本/URL处理和真实回查契约，见 [协议复核](_audit/2026-10-26-spoc-submission-protocol-followup.md)，不开放未经验证的新写方式 |
| G09 | 快照安全审查及其他模块覆盖 | Android 可选加密学习元数据快照已实际接线并通过 Keystore 设备往返；仍需人工安全审查，课表/成绩等不在本开关覆盖范围 |
| G10 | 本人借阅真实认证与非空分页 | 合成/API/UI 已接；真实认证循环仍未定位；[匿名复核](_audit/2026-10-26-library-loans-auth-followup.md)确认入口可跳 SSO，未证明已建立读者会话；不重试被拒登录或复制 Cookie |
| G14 | 校车实时余票及未知 Release 故障 | 已找到并修复官网外链：用户根地址→CASLogin→学校CAS，见 [入口补充](_audit/2026-10-26-shuttle-auth-followup.md#用户准确入口补充根地址会进入-cas)；应用内仍缺安全认证回程（官方 service 本次为 HTTP）及完整余票只读事务，未接通；未知 Release 故障仍需复现 |

**Goal 状态：可独立执行的实现与合成设备验证已收口；以下真实协议/认证/人审事项受阻，尚未全范围完成。** 已核销的 G01/G02/G03/G06/G07/G08/G11/G12/G13 的源码、测试与深浅色/320dp 大字截图证据统一转入 [本轮集成记录](_audit/2026-10-26-module-integration.md)，不再保留为重复未完成任务。其真实样本/物理设备边界继续在下方 P1/P2 维护。

真实学校写入、未经脱敏的非空协议样本、物理真机及敏感存储人工审查受仓库安全规则约束；无人值守不扩大授权。

## 当前推进顺序：先收口，再扩展

当前主线为 **Android / Flutter + Rust**。以工作树为准，不将历史设计或已发布内容重复排成新开发任务。

- 已发布基线：Android Alpha.9（build 10）；Windows Alpha.6（build 7）。证据见 [Alpha.9 发布记录](_audit/2026-10-26-android-alpha9-release.md)。
- Alpha.9（build 10）已公开：全量门禁（513 项 Flutter 测试）、签名构建与产物校验通过，模拟器签名包覆盖升级（Alpha.8→Alpha.9，本机待办保留）通过。**未验收**：物理设备（TalkBack、预测返回、大字号/深浅色、帧率）、真实学校认证与写入、借阅非空分页、校车余票和非空协议样本。
- Alpha.7 后源码：作业提交状态与截止判定分离、工作台/学分展示优化、CGYY 静态协议对齐、公开查书/馆藏与排序、应用内校车时刻表、跨断点旋转保持位置；`e149f90` 已移除作业详情“加入个人待办”，保留既有本机数据。2026-10-24 复核批次另含：CAS 表单 action 白名单、账号身份一致性校验（`account == profile.school_id`）、保险库枚举失败不再视为空、快照缓存请求代次防护、课程范围读取失败锁定编辑、显式退出标记阻止自动恢复、更新门禁时序与发布址白名单、课表已确认快照、作业详情倒计时取最新状态、APK 校验失败可重下载、`RefreshSection`/`LibraryController` 强制刷新补跑、FFI 可达 `unreachable!()` 清除、预约按钮组件与查书目页重做、导航栏强调色（`navActionTextStyle`）。2026-10-25 收口批次：全部读命令补 `bounded_read` 超时、上游读路径统一 await 后账号复检（含 bykc 飞行中切账号回归）、剩余刷新静默丢弃页面改为待刷新补跑、壳层共享状态修复跨 760dp 旋转丢导航（含旋转回归测试）、CGYY 写迁移到模块级 `CGYY_ACCESS`/`CGYY_WRITE`（对齐 checkin/library）、`android-v*` 自动构建校验 workflow、bridge 层补 `bounded_read`/CGYY 双击退避测试、`CgyyDayPage` 补 widget 测试、页面载荷解码收口到 `*_models.dart`。上述已随 Alpha.8 公开；合成与模拟器通过不等于完成真实业务验收。
- [下一阶段方案](NEXT-STAGE-PLAN-2026-10-23.md) 与 [IA方案](NEXT-STAGE-IA-2026-10-23.md) 保留研究依据，不能将其中已落地方案重新实施，也不能将未批准的导航/写能力视为现有功能。
- 执行顺序：**P0 可复现回归与安全边界 → P1 设备/账号验收及小步体验 → P2 扩展**。本地自动化与正常入口构建通过只能关闭相应本地事项；需要本人账号、真实写入或物理设备的条目继续保留。
- **2026-10-24 综合评审**（工程 / 设计 / UI / 视觉）已按 Android-only 重排，其可复现缺陷并入下方 P0 / P1，范围收窄带来的新风险并入 P0：[_audit/2026-10-24-comprehensive-review.md](_audit/2026-10-24-comprehensive-review.md)。

本轮盘点与回归证据见 [推进收口记录](_audit/2026-10-23-android-progress-closeout.md)；随后完成 [图书馆与校车模拟器真实只读视觉闭环](_audit/2026-10-24-library-shuttle-visual.md)，修复键盘遮挡与窄屏大字双列，保留物理设备、TalkBack、真实非空订单/写入等人工事项；这些记录不替代下方人工验收。

## P0：认证可靠性与真实行为

- [x] ~~**消除 16 处 `if (busy) return;` 静默丢弃刷新**~~ —— 已完成（2026-10-25）：清单内页面（notices/cgyy/homework/library_stats/shuttle/library_books 馆藏、homework_detail）全部改为“飞行中记录待刷新、落定后补跑”，notices 拉刷新回归锁定于 `campus_service_pages_test.dart`；today/bykc/graduate/classroom/checkin 已在先前批次迁移。其余 `busy` 守卫（login/settings/booking/提交类）为防抖语义，不属于刷新丢弃。
- [x] ~~**给所有读命令加超时上界**~~ —— 已完成（2026-10-25）：`bounded_read`（45 秒）现覆盖全部 `load_*` 读命令，含 `load_classrooms`、`load_library_areas/slots/seats/stats`、`load_schedule/load_today/load_grade_terms/load_grades`、`load_notices/load_cgyy/load_library_books/load_shuttle_timetable/load_library_holdings`、`load_homework_detail`。超时与直通行为有 bridge 单测（`runtime.rs bounded_read_tests`）。
- [x] ~~**上游读路径补 await 后账号复检**~~ —— 已完成（2026-10-25）：统一采用“入口取 `current_account()`，网络 await 后 `!= account → Err(session_expired)`”，覆盖 library（venues/bookings/areas/slots/seats，history/token 原有）、classroom、homework（列表+详情）、bykc（共享 `read_bykc_snapshot` 助手）、graduate（`load_graduate_part`）、schedule（grades/terms/today/schedule，today 的课表回退路径同样复检）。回归：`bykc_service::tests::an_account_change_during_the_network_read_rejects_its_result`（飞行中切账号拒绝结果且不落缓存）。notices 为公共读取无身份，维持原状。
- [ ] 对 [最近认证失败](_audit/2026-10-21-auth-redirect-incident.md) 中的 UC→HTTP SSO 跳转，区分旧版行为、Alpha.4 已发布修复与后续实网复验结果。合成修复通过不能替代用户授权下的真实复验，不推断账号被封。
- [ ] 在用户逐次人工操作下验收签到、图书馆预约 / 取消 / 暂离 / 离馆及 CGYY 预约 / 取消，记录提交前状态、结果分类、审批与取消回查；CGYY 还需覆盖重启/重登后的待核实保护和可取消时间门禁、真实非空订单。现有自动化通过不能勾除此项，代理不自动执行真实写入。
- [ ] 补充受控超时、断网与认证失败的模块回归，重点保留旧快照、恢复次数上限和写操作不重放；不为了消除失败而放宽业务断言。
- [ ] 继续定位首次 iclass / 博雅 / 研究生读取的高延迟及“切页才更新”反馈。Alpha.4 已有阶段 / 耗时反馈、并发恢复、缓存锁前命中、迟到 token 失效和预约回查同步修复；尚无足够证据宣布所有等待问题已消除。

## P1：Android 产品与平台验收

- [x] ~~**增加 Android 自动发布 workflow**~~ —— 可自动化部分已完成（2026-10-25）：`.github/workflows/android-release.yml` 由 tag `android-v*` 触发，外部注入四个签名 secret 组装 `GINKGO_ANDROID_SIGNING_PROPERTIES` 指向的 properties 文件（缺配置即失败，Gradle 侧 fail-closed 不变），带 `--pub` 构建正常入口 Release APK，断言 pubspec 版本与 tag 一致、`GeneratedPluginRegistrant` 不含 `integration_test`（对应 Alpha.7 事故）、`versionName` 匹配、非 debuggable、仅 arm64-v8a、`zipalign`/`apksigner verify`，产出 `Ginkgo-<version>-android-arm64.apk` + checksums 的 workflow artifact。**发布仍人工**：真实设备覆盖升级、发布说明与 GitHub prerelease 公开由维护者执行。四个 secret（KEYSTORE_BASE64/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD）需在仓库 Settings 配置后 workflow 才可用。
- [x] ~~**区分空态与错误态**~~ —— 已完成：`AppleEmptyState`（`widgets/apple_surfaces.dart`）错误分支用 `exclamationmark_triangle`、空态用 `tray`，失败路径统一传 `error: true`；bykc 的失败走独立状态横幅与空态分离，属设计差异而非遗漏。
- [ ] **补 Flutter 侧的“部分成功”表达**：Swift 端有“以下来源暂时未能更新：…；作业结果不完整”，Flutter 的 `homework()` 只返回单个 `HomeworkResponse`（`application/mirror_service.dart:54`），`homework_page.dart:143-148` 把任何来源失败折叠成整页错误或“显示上次结果”。多来源部分失败在 Android 端当前不可表达。
- [ ] **补 Semantics 与 SafeArea 覆盖**：全应用仅 61 处 `Semantics(...)`，`GinkgoIconTile.semanticLabel`（`ginkgo_visuals.dart:16`）存在但很少传值；15 个页面文件完全无 `SafeArea`，靠硬编码占位（`library_page.dart:169` 的 `const SizedBox(height: 96)`）。共享 `choose` 菜单的选中项 Semantics 与 8 处 <48dp 触控目标已在 2026-10-24 修复，其余 Semantics/SafeArea 缺口仍开放。
- [x] ~~**横竖屏跨越 760dp 时提升导航状态**~~ —— 已完成（2026-10-25）：`workspace_shell.dart` 新增 `_WorkspaceShell`，选中目的地、已访问集合与各目的地的 `GlobalKey<NavigatorState>` 提升到断点之上，移动 tab 壳与桌面侧栏壳共用；跨断点旋转通过 GlobalKey 保活各目的地的导航栈（含未提交表单页面）。桌面专有目的地（无移动标签）转回移动端时回到首个标签并同步选中，属既定边界。回归：`workspace_navigation_test.dart` 的旋转用例（移动选课表→桌面侧栏同选中→转回移动仍在课表）。
- [ ] ~~**待办编辑增加脏草稿放弃确认**~~ —— 已完成（2026-10-24）：`task_editor.dart` 有未保存修改时返回弹出“放弃未保存的修改？”确认，未编辑时静默退出。
- [ ] **物理 Android 真机验收系统返回/预测返回、TalkBack 全流程、大字号/深浅色及长列表性能**；覆盖强调色、常用入口、栏目过渡与新校车页实际帧率。合成 widget 与 ARM64 模拟器不能替代。
- [ ] 用户授权下核对真实作业来源定位与截止时间；验证已提交无倒计时、待处理排除已截止、个人待办不重复显示学校来源事项，保留 v1→v2 升级前备份与不可降级编辑说明。不得新增提交权限或自动改学校状态。
- [ ] 公开查书/馆藏与校车时刻表补真实设备只读验收：~~排序/分页/空态/限流与官方对照~~ 排序/分页/公开检索已随 2026-10-24/25 授权账号只读验收覆盖（真实目录检索、翻页、卡片渲染），余静态时刻表与官方页对照保留。~~区分计划可乘人数与实时余票~~ 2026-10-25 的 CAS 会话下 indexPage 仍报未认证、ShiftsSearch 403，仅能证明该次会话未建立校车身份，动态余票当前未接通，尚缺独立授权入口；保留静态时刻表及单独智慧校车入口，不能据此断言永远不可接入。图书馆本人非空借阅不在公开目录验收范围。
- [ ] 评审剩余扩展的依赖与分包范围：我的借阅（工作树已接独立只读端口、CAS 入口及按需分页；真实 App 认证/非空字段/多页与隐私设备验收待完成，见 [接续记录](_audit/2026-10-26-library-loans-integration.md)）、热门/封面、未来七天聚合、筛选记忆与课表导出；预约摘要不得增加首屏阻塞。校车动态余票在完整事务与资格证据前不接入。
- [ ] 阳光打卡 P1 安全写闭环：先补上传/提交/回查与 `isopen` 服务端语义证据及隐私、单写门禁评审，通过后分包实现本人手动填写/照片/确认流程，真实提交另行逐次授权。未验证前不得开放真实提交或承诺私密，不执行自动打卡。
- [ ] 真实非空成绩 / GPA、本科教务账号、图书馆多页历史、博雅非空已选记录及 CGYY 非空订单逐项对照；既往研究生账号的成功空结果不覆盖这些分支。
- [ ] 设备复核北京时间跨午夜、学期 / 周次切换、离屏页返回和缓存失效；保留 `mirror_test.dart` 校区 / 日期 / 缓存长流程未收敛的记录，先拆成有界场景定位。
- [ ] 空教室刷新后的精确像素锚定：已保留页码与页首条目，但 sliver 重排仍可能产生可见位置偏移（合成观察约 119px）；与设备滚动性能、读屏验收一并补。
- [x] ~~**补 Android 真机截图并替换 README 界面预览**~~ —— 已完成（2026-10-27）：新增 7 张真机尺寸 Android 截图（`docs/images/android-*.png`，1080×2400，工作台 / 课表 / 作业 / 签到 / 预约 / 研讨室 / 图书馆）与 1 段约 20 秒离线演示录屏（`docs/media/ginkgo-android-demo.mp4`），由 `flutter/integration_test/promo_capture_test.dart` 在隔离模拟器上驱动真实界面生成，只用离线演示合成数据。仓库首页与 GitHub Pages 主页的界面预览已全部换成 Android 素材；macOS 旧截图保留在 `docs/images/` 仅作历史对照，不再用于对外宣传。
- [ ] **专项排查 Flutter 侧“已更新”横幅配色**：macOS 侧存在同语义不同色（`ScheduleView.swift:24` 与 `GradeView.swift:25` 用 `.success` 绿，`LibraryView.swift:32` 用 `.information` 蓝）。Flutter 侧是否同样不一致尚未逐页核对，收窄后 Flutter 是唯一 UI 端，需统一。
- [ ] **宣传口径随发布同步**（2026-10-27 起）：仓库首页、GitHub Pages 主页与 [PROMOTION](PROMOTION.md) 已改为 Android 主推，界面素材换成真机尺寸截图与离线演示录屏。每次 Android 发布后需同步：README 顶部下载链接、主页版本号（脚本自动指向最新 `android-v*` 资产）、[RELEASE-NOTES](RELEASE-NOTES.md) 与 [releases/](releases/) 的用户收益，并复核截图／录屏是否仍与当前界面一致（可用 `flutter/integration_test/promo_capture_test.dart` 重新生成）。不把未验收能力写进对外文案。

## P2：功能与结构

- [ ] **补齐设计 token 采纳并加 CI 强制**：`flutter/lib/design/tokens/` 定义质量高（4pt/8pt 间距、HIG 类型标尺、圆角、动效），但 96 个应用 Dart 文件中 **62 个（65%）零引用**，实测硬编码 202 处 `fontSize`、204 处 `EdgeInsets`、199 处 `SizedBox`、49 处 `BorderRadius`；仅 `apple_design.dart` 引用了 token，且只暴露约 60 个中的 16 个（`AppleDesign.title` 还被别名到 `largeTitle`，与 `body` 之间缺整档）。根因是门面过窄而非页面懒惰。收窄为 Android-only 后这是唯一的设计系统。**CI 强制已就位**（2026-10-27）：新增 `scripts/check-design-tokens.py`，按当前实测值（`fontSize` 206 / `EdgeInsets` 277 / `SizedBox` 228 / `BorderRadius` 42）设定只许减不许增的预算，并接入本地基线与 CI；**门面补齐与存量迁移仍未做**，需先拓宽 `AppleDesign` 导出再逐页替换硬编码值，每替换一批就下调预算。
- [ ] **为载荷信封命令补 bridge DTO，删掉 Dart 里的 `jsonDecode`**：页面层 `jsonDecode` 已于 2026-10-25 收口为零，学校字段名解码集中在 8 个 `*_models.dart`（`space_id`/`time_ids`/`currentTerm`/`phase`/`bibId` 等），剩余 11 处 `jsonDecode` 均为本地偏好/维护文件，非学校 payload。根因仍是 `ginkgo_flutter_bridge/src/api/live.rs` 的 `ReadOnlyResponse { payload: Option<String>, … }` 逃生舱：**2026-10-27 实测 87 个 FFI 命令中 46 个返回类型化 DTO、41 个仍用载荷信封**（逐个清单见 [INTERFACE-INDEX §6.10](INTERFACE-INDEX.md#610-返回形态与载荷契约)，此前“约 9 个端点”的估计已过时）；载荷是 Rust 净化过的领域 JSON（不是原始上游数据），属契约侵蚀而非凭据泄露；修复顺序仍是先补 DTO 再删 Dart 解析。
- [ ] **把稳定业务规则搬回 `ginkgo_domain`**：`reminder_rules.dart:18-33`（签到窗口）、`:46-110`（提醒排程）、`homework_projection.dart:44-70`（截止分类）、`checkin_page.dart:54-57` 与 `library_stats_page.dart:48`（UTC+8 学校“今天”）目前留在 Dart，违反“学校日期与稳定业务规则留在 Rust”；放回 domain 才能拿到 Rust 单测。
- [ ] 验证码图片/刷新/挑战代次已在工作树接通；仍需本人真实风控分支及物理设备辅助功能验收，未知类型不自动发送。
- [ ] “登录成功但密码保存失败”提供就地提示；解释 WebVPN 网关为何可能要求记住密码，减少首次使用的困惑。
- [ ] 继续验收已接入的签到 / 作业本地提醒：Android 权限拒绝 / 恢复、重启、强停和厂商省电；课程/待办提醒已接 opt-in 规则/排程与设置；可选 Android 加密学习元数据快照已接线，仍需人工安全审查；其余课表/成绩等快照持久化、重启/强停/厂商后台验收未完成。Windows 仅保持编译，不新增通知排期。
- [ ] 研究生严格执行报告学分图已接线，成绩 / 考试组合及图书馆本机趋势仍未齐；SPOC 文件能力已在工作树分层接入（[集成记录](_audit/2026-10-25-spoc-homework-integration.md)），普通构建已开放受私有待确认记录保护的个人文件入口，仍需本人逐次指定作业和最终文件的真实分片/合并/提交/回查与失败验收；小组及非文件作答、希冀来源、BYKC 选退课 / 签到尚未迁移；CGYY 订单详情与门锁码已接入 UBAA 对照的只读链路、用途内置降级和合成页面，真实预约 / 取消 / 门锁码往返仍未验收。
- [ ] SPOC 学习只读扩展：Alpha.9 已公开 gateway/native/demo/页面与课程、根资料抽查，证据见 [接续记录](_audit/2026-10-26-spoc-learning-integration.md)；仍需授权范围内的非空公告详情/附件、资料目录/后页和非空测验字段验收，以及抽查第 2 项课程测验 `ServiceUnavailable` 的脱敏定位。Android 物理设备视觉/读屏和实际页面链未验收；无原成功时间字段，不伪造同步时间。不包含公告标读、课程访问记录或考试开始/作答/提交。
- [ ] 其他异步复杂页面在出现跨路由状态或重复加载职责时参考 `LibraryController`；**不要求一次性统一重构**——先修掉共用的强制刷新缺陷，再在新页面默认使用 `RefreshSection`/`LibraryController`/`SectionFeedback`，旧页面在被修改时逐个迁移。
- [ ] 移动端“个人与校园”快捷入口（`service_directory.dart`）仍是精选清单，与 `workspace_catalog.dart` 的功能清单重复；如需完全单一来源，可改为从登记表派生（需把 `WorkspaceContext` 工厂传入目录）。
- [ ] 更新体系：最低版本门禁已接入（`update_gate.dart` + `docs/update-gate.json`，拉取失败放行）；清单签名、差分补丁、灰度/回滚、Windows Authenticode 与应用内更新仍待做。提升 `minBuild` 前必须确认新版本已可下载，避免把旧版锁在无法更新的状态。
- [ ] Android 应用内下载、断点续传、摘要 / 签名校验和系统安装确认已进入 Alpha.4；Alpha.6→7 的签名包模拟器覆盖升级已完成，仍需发布后在物理设备验证旧版发现、未知来源授权、覆盖升级和网络中断恢复。
- [ ] 架构债清理（低优先，逐项处理）：~~`upstream/src/lib.rs:7` 的 `pub use codecs as features` 造出两个 `features` 命名空间~~（**2026-10-27 已清**：别名删除，上游内部只余 `codecs`，`features` 专指 `ginkgo_domain::features` 领域规则）；~~`bridge/src/api/live/utilities.rs` 的 `edit_tasks` 用 `try_read()` 在登录中直接失败~~（**2026-10-27 已修**：改为等待会话读锁，命令排队而非丢弃，阻塞式 fsync 移入 `spawn_blocking`）；~~`upstream/src/services/library_service.rs` 的 token 重试块复制 5 遍~~（**2026-10-27 已收**：统一为 `library_retry` 助手，行为不变并补回归测试）；**仍开放**：`ginkgo_core/src/cgyy_pending_store.rs` 与 `tasks_store.rs` 在 tokio worker 上做阻塞 fsync 且持全局锁、串行化所有账号（待办写已移到 `spawn_blocking`，CGYY pending marker 仍在调用链内）；`codecs/library_mutation.rs:43-66` 按中文字面量子串判定写结果；Rust workspace 零日志可观测性，线上排障只能靠复现（引入前须按 `docs/COLLABORATION.md` 定脱敏白名单并人工审查）。

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

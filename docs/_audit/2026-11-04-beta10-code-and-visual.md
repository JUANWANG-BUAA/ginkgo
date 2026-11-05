# Beta.10 候选代码检查与视觉闭环

日期：2026-11-04。工作分支 main，起点 e783a3d；接手时有四个已跟踪 UI 修改及未跟踪组件/总结，保留原工作。本文是本轮证据，不代表发布或真实验收。

## 授权与边界

用户要求按 Beta.10 标准检查代码并完成 Swift/iOS 风格的全页面视觉闭环。另明确授权仅修正 `ubaa_protocol_stability.rs` 无效测试；认证、HTTP、Cookie、路线与恢复实现和既有参考预期未修改。网络冻结 64 文件/1 项原授权修订检查通过。后台 bridge 文件只格式化已有测试缩进。

## 已确认问题与处理

1. 新增 Rust 稳定性测试有 20 个编译错误，引用不存在的 API，且含恒真断言。改为调用实际 snapshot/SchoolClient 的离线集成回归：有效/失效/错账号 UC、严格单次 GET 目标和头/无正文、前台保险库不变、错 owner 无请求。原冻结 CAS/验证码严格转录保留，不宣称全协议一致。
2. 新增后台模拟器测试未触发后台作业、未重启，却声称验证这些行为。改为明确限定的离线 demo 导航/缩放冒烟；后台验收仍由现有原生测试与独立脚本承担。
3. 今天页新增 GestureDetector 缺按钮语义，按压取消/减少动态效果处理不全；额外分隔线与父分组重复、状态 10pt 难读、摘要层级丢失。恢复 Cupertino 控件语义，统一 20/17/15/13 层级、状态色与 spacing，保留 48dp 和大字换行。
4. Swift 质感：共享 `PressFeedback` 包裹系统控件，1.5% 触压收缩、120ms 压下/240ms 小幅回弹，滚动/取消释放，减少动态效果不缩放；共享分组展开采用统一 240ms 单调曲线。保留系统导航与连续圆角，不以装饰阴影冒充原生。
5. 未接入产品的新按钮草稿改用系统按钮、忙状态语义、当前强调色和可换行文字，取消重复手势实现；未引入另一套页面导航。分析发现的弃用调用/无用 import 已清理。
6. 设计值预算由实际降低后的数量收紧，没有放宽门禁。

## 契约审查

当前 client-contracts 摘要漂移包含接手前的 demo/environment 导出、后台提醒和设计组件。核对公开 gateway 未改变学校协议，页面 DTO/写入状态机仍沿既有路径；本轮删除冗余 import，新增纯呈现组件并刷新生成索引。Rust/Dart `mutation_result` 草稿没有被生产引用，不能作为已实现能力或替代既有 MutationState；不接入认证或自动重试。协议锁仅刷新已审查源码摘要，readiness 保持 blocked。

## 初期验证记录

- 起始完整门禁被设计 token 漂移阻断；独立 Rust Clippy 被虚构测试编译错误阻断。日志：`artifacts/local/beta10-review/`。
- 修复后严格 Clippy 与 Rust workspace 测试通过（rust.log）；Flutter analyze 无问题；Flutter 单测 841 通过/2 显式跳过（无宿主 bridge 时），后续最终完整门禁结果另记。
- 新增按钮语义回归在旧实现失败；修复后定向 12 项通过。按压/拖动取消/减少动态效果有专项回归。
- 隔离只读 AVD `GinkgoBackground20261103` / emulator-5580，未使用 emulator-5554 或真实凭据。全页面测试使用合成数据和实际 Rust demo bridge。
- 首轮 before 截图已查看浅色页面图集；标准与窄屏大字分两次构建，期间有代码修改，因此 before 仅为逐场景参考，不能称为同一候选全矩阵。最终 after 须绑定统一代码。

## 发布边界

`check-contracts.py --release` 当前拒绝发布：旧候选摘要/版本、真实账号与物理设备、本人写入、维护者安全审查和 Windows CI 缺口。版本未提升、未发布 Beta.10。真实验收暂停约束继续有效。

## 全范围复核补充

用户指出首轮仅检查部分页面后，本轮重新以 `workspace_catalog.dart` 的全部 21 个目的地、页面类型和导航调用为入口盘点，而不是按截图数量宣布完成。首轮遗漏的课程/成绩/通知详情、待办编辑、签到历史、馆舍选择、研究生课程/学籍/单课/独立学分图、会话恢复和网关挑战已加入合成设备检查。页面中的官网跳转不在代理中触发；学校写操作仍仅运行合成回归。

| 功能域 | 页面与功能复核范围 | 本地功能回归入口（flutter/test） |
| --- | --- | --- |
| 启动与账号 | 登录、路线控件、挑战显示、恢复失败、退出/账号代次；冻结实现只读 | login、session、startup、gateway、non_auth_lifecycle 相关测试 |
| 今天 | 课程/考试/作业/待办分区、局部刷新、旧内容、签到显式入口 | today、refresh_audit、today_action_accessibility |
| 课表与考试 | 周/日/学期、课程详情、课程范围、搜索、网格/日列表及考试 | schedule_page、schedule_scroll、schedule_grid、course_visibility |
| 成绩 | 学期选择、总览、课程成绩详情、失败保留与切换 | grades、refresh_audit、academic_hierarchy |
| 学校作业 | 状态筛选、详情、附件、角色门禁、确认与未知结果；不恢复转待办入口 | homework_hierarchy、homework_roles、homework_files、homework_files_safety |
| SPOC 学习 | 课程列表、资料目录/检索/分页、公告详情/附件、测验、接口状态 | learning_page、learning_context、native_learning、learning_snapshots |
| 博雅 | 课程库、已选、统计、课程详情、筛选与账号替换 | bykc_learning、bykc_account_isolation |
| 研究生 | 学分地图、课程筛选、单课、学籍、空/未知/部分失败与展开 | graduate_page、graduate_progressive_widget、graduate_credit_map |
| 图书馆座位 | 当前预约、馆舍/区域/时段/座位、预约历史、公共人数、写后核实 | library_controller、library_hierarchy_refresh、library_service_replacement、library_seat_mutation_context |
| 图书检索 | 搜索、结果分页、馆藏复本、空态与失败 | library_books、library_read_page_generation |
| 本人借阅 | 显式读取、分页、私密清理、失败分类/重试；真实认证仍有用户反馈问题 | library_loans；Rust services/tests/library_loans 与 codecs/library_loans |
| 研讨室 | 场馆、日期/空档、订单/详情、门锁、预约表单/拼图、待核实保护 | cgyy_day_page、cgyy_management、cgyy_booking_safety、cgyy_detail_isolation |
| 空教室 | 校区/日期/楼栋/节次、筛选、结果/详情、规则说明与迟到响应 | classroom_collection、non_auth_lifecycle_regression |
| 校园卡 | 显式读取、隐藏/显示余额、失败及后台清理 | campus_card_page |
| 校园通知 | 列表、日期、详情和官网入口 | public_read_contract、campus_service_pages |
| 就业/学术文化 | 月份/分页、日期与地点、来源、空与失败保留 | public_read_contract、campus_service_pages |
| 校车 | 线路/方向、时刻表、当天计划、到点更新、官网入口 | shuttle、public_read_contract |
| 本机待办 | 新建/编辑/删除/完成/重载、截止选择、键盘和放弃修改 | tasks、local_tasks |
| 更多与设置 | 本地搜索、快捷入口、主题/颜色/字阶、隐私/关于、自检与更新 | workspace、service_directory_injection、app_preferences、settings、android_update |
| 提醒/存储 | 队列串行、通知权限/类别、账号隔离、后台发现、学习快照和缓存边界 | reminders、background_reminders、serial_reminder_platform、learning_snapshots |

表格是范围与回归索引，**不是每项真实业务已成功**。完整门禁执行整个 `flutter/test` 和 Rust workspace；设备截图额外覆盖主要读取页面的等待/失败状态。设备真实功能、后台系统行为、本人写入与 Windows CI 按后文分别判定。

### 新复现并修复

- 博雅页面没有处理服务/loader 替换，旧账号响应可写回新页面，新服务不读取。新增回归先得到 `newReads=0`（预期 1），修复后丢弃旧代次并清空旧三组快照。日志 `bykc-isolation-before.log` / `bykc-isolation-after.log`。
- CGYY 订单详情和门锁页面同样未处理 service/loader/订单变更。两个回归在旧实现失败，修复后清空旧私密内容、重读新上下文、拒绝旧响应；不改认证或学校写操作。日志 `cgyy-isolation-before.log` / `cgyy-isolation-after.log`。
- 部分旧 Android 集成测试仍点击已移除的“作业转待办”入口，或认为馆舍在图书馆首页。修正为验证入口不存在且保留既有记录，并按当前“预约座位 → 馆舍”导航；没有改产品来迎合旧测试。
- 课程详情原来强制两行截断，已改为可换行的主信息组件；课表事实行复用大字可堆叠布局。成绩/培养进度使用突出关键数字的总览；校园通知/就业用日期块；图书馆、学籍、待办编辑和详情使用带语义的图标与标题分组。共享按压取消、动效减少、分组层级保持统一。
- 旧优化总结和发布草稿包含未绑定证据的“全部完成/已部署”，保留原稿并标注不可作验收；Beta10 发布入口撤下错误的就绪结论及不存在的构建路径命令。

### 用户补报：Beta.9 本人借阅认证/权限/服务错误

2026-11-04 用户明确选择“提示认证、权限或服务错误”。源码比对确认 `library_loans_http.rs` / `library_loans_service.rs` / 页面核心读取与 Beta.9 一致；不能称这轮 UI 重写修复了借阅认证。

当前链路是当前账号 → rosetta → 受限 SSO/图书馆 GET → CasBoard → loans；不会提交密码、导入浏览器 Cookie 或读取完整读者资料。API §6.2 与 2026-10-26 复核已记录真实 App 读者会话未打通/未验收。401/登录页、403、循环上限、非零业务码与其他服务失败都有不同错误类别；仅有“认证/权限/服务错误”还不能确定真实失败所在阶段。现有 FFI 只传 `failure`，不传认证跳转细节。

已修正的仅是恢复指引：不再把读者认证失败直接指示为反复重登整个 App；显示不含个人信息的错误枚举诊断代码，并说明官网会话不会同步回 App。模块认证失败清除本页私密记录，仍不自动重试。新增回归在旧提示失败、修正后通过，见 `loans-guidance-before.log` / `loans-guidance-after.log`。四类错误加入设备视觉场景。

**借阅认证根因保持未解决，列为发包阻断。** 当前证据不足以针对冻结链提出确定修复；不猜测新增请求头/复制 Cookie/自动重登，不因用户报告而恢复已暂停的真实凭据请求。

### 大字号截图驱动的第二轮修正

标准字号首轮全页面浅/深色通过；窄屏检查的成绩详情脚本先因惰性列表尚无行、随后因多行匹配中断。修正为先滚动到实际构建的条目再选择首行，不跳过成绩详情。原生 PixelCopy 偶发错误仅对截图复制失败重试，UI 异常仍立即失败。

逐图查看 320dp / 1.6 倍字号发现两项单靠 `takeException()` 抓不到的问题：带返回文字的折叠导航标题会换行裁切；行内失败说明被右侧重试挤成窄列。`ApplePageHeader` 的收起标题改为单行系统标题，完整大标题仍保留；`SectionFeedback` 在窄容器或大字号时把重试放到说明下方。`compact_header_feedback_test.dart` 验证实际文字渲染高度/宽度及重试可操作；旧实现分别失败，修复后与共享视觉单测一并通过。相关日志 `compact-header-before.log`、`compact-before.log`、`compact-after.log`。完整矩阵在这些修改后重新采集到 `candidate-system-visual/`，此前 `verified-all-pages/` 作为发现问题的中间证据，不冒充最终候选。

主机端 `SessionSnapshotCipher` 合成 Java 合约通过（`cipher.log`），只证明加密封装测试；直接运行 Gradle test 先遇到系统 JDK 27 与 Android jlink 不兼容，改 JDK 17 后明确该源为独立 main 合约、无 JUnit 测试可发现，未关闭 Gradle 失败门禁。Android Keystore 与原生后台能力另以隔离模拟器测试验收，结果见最终记录，不以主机测试替代。

## 完整矩阵起始代码基线

- 源码摘要：`9a3d5cf6e91bc61e5b399de1317e532b3a9e1fc4900779e53ec71f84c4f8251a`。
- 契约摘要：`e18b925e1603938ab8fbcdf4c61fa5d91710575a7d7b1870f9adeb03c592ac19`。
- `bash scripts/check-mirror.sh` 在该基线通过：Rust fmt / 严格 Clippy / workspace 合约、已知错误变体检查、文档与源码门禁、Flutter analyze、851 项 Flutter 单测、FRB 重生成零漂移。日志 `artifacts/local/beta10-review/baseline-final-candidate.log`。这是本地离线证据，不能外推真实网络。
- `python3 scripts/check-network-freeze.py` 通过：64 个保护文件、1 项既有明确授权修订，未刷新冻结基线或清单。
- `python3 scripts/check-contracts.py --release` 继续失败（`release-gate-final.log`）：readiness 为 blocked，旧验收记录不匹配当前候选，真实账号/物理设备/本人写入/维护者安全人审/Windows 远端证据未齐。未提升版本、未打 tag、未创建 Release。
- 视觉测试源码单独存入 `visual-harness-manifest.json`，因发布摘要不涵盖 integration_test，不能用发布摘要替代视觉脚本版本说明。


## 最后一轮逐图修正

系统截图复核发现待办标题在深色模式下为黑色；实测文字亮度为 0。另查到必需更新页标题及辅助说明、SPOC 根目录、助教作业筛选说明、共享桌面侧栏分组也直接使用未解析的动态文字颜色。已按当前主题解析，未更改更新策略、网络或认证。待办/必需更新的深色回归先在旧实现失败，修复后通过（`tasks-dark-before.log`、`update-dark-before.log`、`dark-colors-after.log`）。必需更新页补入四模式视觉矩阵，使用合成门禁，不请求或调整线上更新门禁。

博雅及图书馆局部错误仍用独立横排组件，大字号时说明被挤成窄列。已复用自适应 `SectionFeedback`，保留各读取重试和旧结果语义；新增可选 retryKey 仅保持原控件定位。图书馆回归在旧实现得到文字宽 128.42，期望超过 220；修正后通过（`library-feedback-before.log`、`feedback-final.log`）。更新的源码索引和契约摘要只涉及呈现接口，不改变学校协议。

该轮呈现代码摘要为 `2750523370c511f84f09fea2d54c41335c480f21875a7b7573ad5311e4450980`；契约摘要仍为 `e18b925e1603938ab8fbcdf4c61fa5d91710575a7d7b1870f9adeb03c592ac19`。全矩阵先在上节 9a3d5cf6 基线采集，再对上述变更影响的页面/状态及新增交互进行四模式补拍；未受影响图片沿用其原采集基线，不能称所有图片来自同一次构建。最终图片清单记录逐图哈希和批次来源。

待办大字号旧截图虽写入文字，但系统键盘并未显示，不能作为键盘验收。补拍脚本增加真实点击输入框、请求 Android 键盘，并断言底部键盘 inset 大于零；最终以补拍结果判定。

## 视觉闭环结果

- 全部 21 个工作区目的地及次级页、详情、表单、恢复/挑战、主要等待/失败状态共 101 个基础场景，四模式首图无缺失；另含滚动末尾、主导航、分段切换、选择器、取消确认与真实系统键盘，共 704 张 Android 系统截图。
- `candidate-system-visual.log` 和 `visual-variants-final.log` 均通过。全矩阵保留 530 张；最终修正影响页补拍 174 张。按图集逐图复看，疑似裁切处查原图，最后深色大字号尾页与全部补拍已复看；没有把截图数量当作真实业务成功证据。
- 浏览入口：`artifacts/local/beta10-review/candidate-system-visual/index.html`；逐图尺寸、SHA-256、来源批次及路线覆盖：同目录 `manifest.json`。实际采集脚本版本见 `visual-harness-manifest.json`。
- `beta10_motion_visual_test.dart` 的 18 张动效过程截图与设备操作覆盖压下/取消释放、标签导航、设置进入/返回；减少动态效果另有 widget 回归。最后补正首帧取证：在设备上断言实际 `ScaleTransition` 完成到 0.985，取消后恢复 1，再直接拍 Android 系统画面；浅/深色按下与取消截图均不同，已复看 `motion/contact-final.jpg`。日志 `motion-final.log` 通过；该证据不等于物理设备帧率/性能验收。
- 上述是 Android 合成环境的视觉闭环，未执行真实学校写入、官网跳转或账号查询。Windows 运行、TalkBack 实机和物理设备性能仍待验收。

## 最后设备回归中的旧测试勘误

1. 今日页已按产品规则合并学校作业和关联待办；旧脚本查找被有意隐藏的重复待办，导致定位失败。现在定位独立待办，同时断言重复行不存在、合并说明存在，不改变产品去重。
2. Rust 演示签到固定在 2026-10-20 08:00–09:35（北京时间），旧脚本用运行日时钟，按钮因已过期禁用。现在通过页面已有 clock 注入该合成课程的有效时间，仍走真实确认与演示写入拒绝，不删除时间门禁。
3. 已提交的 `73b2dcf` 将后台普通失败状态映射为 `retryLater`，旧设备脚本仍期待 `sessionRequired`。首次补充原生前置断言曾错误期待 unavailable，实际设备得到 sessionExpired；继续追踪确认 `create_background_service` 在缺少本地快照时即返回 sessionExpired，尚未进入后续 restore 的 unavailable 分支。修正测试以区分 bridge 错误和 Dart 后台状态：直接断言无账号返回 sessionExpired 且 account 为空，后台和冷进程脚本核对 retryLater，存储读取错误仍严格期待 storageUnavailable。两次失败日志保留，没有改变冻结实现。

这轮仅改设备测试与检查脚本后，候选摘要为 `ea29bed919bc4241efdfde0fd3834a26a28e2d715b1c79f83dec8aa63321b8d7`，应用呈现与 27505233 批次一致。

## 设备回归结果

`android_product_iteration`、`library`、`academic_learning_ux`、`auth`（合成保险库）、`non_auth_lifecycle` 均通过，日志为 `device-<名称>.log`。两份勘误后的 `ios_visual_refinement`、`write_actions` 通过，日志为 `device-<名称>-retest.log`；后者只提交演示确认并校验原生无账号预检拒绝，没有真实学校写入。

独立 `check-android-background-reminders.sh emulator-5580` 最终通过，见 `background-retest-final.log` 和 `background-evidence/`：分组/账号隔离、第二 Flutter engine、进程被杀后的冷 JNI/FRB 执行、重启重排未过期合成提醒、正常入口覆盖安装后后台执行、缺少记录与存储损坏的状态区分，以及损坏记录保留/前台恢复提示。未运行可选 Profile/AOT 探针，不推广成 Release 后台验收。所有请求在飞行模式、无账号的隔离 AVD 中执行，末尾清除合成数据。

最后重新以 `lib/main.dart --pub` 构建 ARM64 Debug 并安装，冷启动显示登录页与离线演示入口，不是 integration_test 等待页。产物哈希、构建日志和截图见 `normal-entrypoint.json`、`main-closeout-build.log`、`normal-main.png`。版本仍为 `0.1.0-beta.9+19`，Debug 仅作本机 QA，不作为公开 Beta.10 更新资产。

## 当前候选验收绑定

以下证据绑定 `ea29bed919bc4241efdfde0fd3834a26a28e2d715b1c79f83dec8aa63321b8d7`，审计日期 2026-11-04（America/Los_Angeles）。不是将历史账号/签名/CI 验收改写为通过。

- **EVIDENCE baseline**：最终 `baseline-closeout-final.log` 完整退出 0：Rust fmt、严格 Clippy、core/upstream/workspace、22/22 可编译错误变体检出、源码/文档门禁、Flutter analyze、854 项 Flutter 测试和 FRB 重生成零漂移。之前 `baseline-closeout.log` 因动效测试未使用变量警告中断；修正后重新执行完整脚本，不把那次中断写成通过。
- **EVIDENCE auth:directory-failure-never-fakes-login**：上述完整门禁运行 `unexpected_login_page_and_broken_directory_never_sign_in`、`uc_server_error_does_not_publish_an_unverified_identity` 等真实 transport 合成回归；目录失败不发布身份。仅离线证据。
- **EVIDENCE auth:single-submit-and-unknown-result**：完整门禁运行一次密码提交、网关未知结果不重放和严格认证转录回归；`a_silent_network_failure_opens_the_gateway_without_a_second_password` 与单次密码 POST 测试通过，22 个已知错误变体仍被检出。未改认证实现或参考向量。
- **EVIDENCE production-entrypoint**：`main-closeout-build.log`、`normal-entrypoint.json`、`normal-main-ui.xml` / `normal-main.png`；正常 main Debug 安装与冷启动通过。首次 UI dump 瞬时返回 null root 后，先删除旧 dump 再重新采集并校验，不使用残留 XML 作为新证据。
- **EVIDENCE feature:tasks**：`device-android_product_iteration.log` 在设备上经实际 Rust demo 本机文件写入、完成、返回后重读，验证关联记录保留；四模式待办/编辑/键盘及放弃修改截图复核通过。未验证签名升级。
- **EVIDENCE feature:more**：全页面测试及 `motion-final.log` 操作实际更多入口、服务导航/常用服务编辑、设置进入和返回；四模式复看通过。
- **EVIDENCE feature:settings**：全目录设置/主题/阅读/隐私/更新/通知页面合成视觉与实际壳导航通过，后台测试另校验真实存储错误恢复提示。物理设备全部偏好重启持久化、系统权限及签名升级仍独立待验。

机器验收记录只更新这些本地/模拟器证据，旧 Windows 等记录标记 historical；维护者签核为空，未声称 P0/P1 为零。发布门禁仍拒绝，主要阻断为本人借阅认证、真实账号/物理设备/本人写入、安全人审和当前 Windows CI。未提升版本、minBuild、打 tag 或发布 Beta.10。


## 用户后续发布指令（2026-11-04）

用户随后明确要求真实账号测试暂停期间直接发布。上节“不打 tag / 未发布”和阻断结论只属于该指令前的检查时点；现在按[Beta.10 手动发布记录](2026-11-04-beta10-publication.md)继续，未执行项目不再拦住本次发布，也不伪造通过。网络冻结与正式 readiness 保持原样。

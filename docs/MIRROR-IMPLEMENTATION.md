# Rust + Flutter 镜像实施现状

更新：2026-10-29。功能与本地接口统一索引见 [功能和接口协议](FEATURES-AND-PROTOCOLS.md)，全代码接口总览与逐层清单见 [接口索引](INTERFACE-INDEX.md)。本页描述工作树；公开 APK 的内容以对应发布记录为准。模块差距只维护在 [功能对照](MIRROR-PARITY.md)，未完成事项只维护在 [待办](MIRROR-TODO.md)，过程与历次测试见 [历史证据索引](archive/mirror/README.md)。

## 产品与验收边界

| 平台 | 当前状态 | 证据与限制 |
| --- | --- | --- |
| macOS / iOS | 独立 SwiftUI 应用，共享 Swift 客户端、模型与工作区编排 | Apple 测试见 [TESTING](TESTING.md)；模拟器通过不代表真机、签名分发或真实写入通过 |
| Android | Rust + Flutter；公开包 Beta.2（build 12，2026-10-29） | [Beta.2 发布与验收记录](_audit/2026-10-29-android-beta2-release.md)；公开只读请求与登录态隔离，真实认证、设备和学校写入未验收 |
| Windows | Rust + Flutter；公开包 Alpha.6（build 7），Windows 10 / 11 x64 单文件安装器 + 便携 ZIP | [首发记录](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)、[主机验证](archive/mirror/WINDOWS-2026-10-21.md)；系统保险库、宽屏侧栏、窄屏底部导航、键盘与返回栈基础通过；安装器未签名，物理 x64 / 干净系统运行依赖 / 真实学校业务仍未验收 |

既往真实账号只读检查已覆盖已接入模块，但最近一次集成登录失败；两次结果分别保留于 [验收记录](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md) 与 [认证异常诊断](_audit/2026-10-21-auth-redirect-incident.md)。不能把早先通过推广为当前所有网络均可用，也不能将工作树改动当作已经发布。

手机一级入口为工作台、签到、课表、作业、预约；桌面使用分组侧栏与独立目的地栈。`main.dart` 已按可用宽度 760px 选择手机或桌面布局。Android 保险库使用 Keystore；Windows Credential Manager 合成往返已通过，macOS 镜像保险库分支仍待验收。

Alpha.4 起，手机端使用 iOS 式大标题、分组卡片和触控尺寸；宽度达到 760px 后切换为 macOS 式“分区 / 标题 / 说明 / 操作”固定页头、较小圆角和桌面侧栏。Windows 首发包复用同一界面规则，在宽屏显示分组侧栏、窄窗口切换底部导航。系统返回一次先离开非工作台主页面，详情只退一层；工作台第一次返回只显示退出提示。显示与阅读、通知与后台、账号与隐私、UBAA 致谢和分享入口均已进入设置；未接入的后台提醒或品牌自启动能力在页面中明确说明。

2026-10-22 源码新增渐进加载样板：工作台的今日课程与个人课程作业分别读取、完成即显示，局部失败可单独重试；研究生教务保留学籍与执行报告的独立加载。两页参考原生 `IOSTodayView`、`IOSGraduateAcademicView` 的分组与局部状态，并沿用桌面的紧凑圆角及固定页头。加载使用主题色银杏叶轻微呼吸，首次内容出现时淡入；刷新时保留已有结果，不逐字输出课程或成绩。减少动态效果或所在标签页关闭 ticker 时停止呼吸动画；桌面支持 `Ctrl+R` / `⌘R` 刷新当前页。这些改动已进入 Android Alpha.5 公开包。

同日进一步优化大量结果浏览：座位与空教室每页 50 条、固定查询栏、按需构建、直接跳页；空教室增加楼栋选择与搜索输入合并，同一查询刷新保留页码和位置。课表固定节次轴、触摸横滑按天对齐、周次平滑定位与滑条、周次/星期直接选择。长页提供纵向滚动条及深处返回顶部入口。详见 [交互与更新边界](MIRROR-INTERACTION.md)；本地呈现分页不代表学校服务端分页或已接入远程代码补丁。同轮壳层收敛为功能登记表：移动端标签、桌面侧栏与今日快捷入口由同一条目派生，`main.dart` 只保留启动与登录状态机；登记仍是编译期静态表，不引入运行时插件加载。

同日补上最低版本门禁：客户端启动时读取 GitHub Pages 上的 [update-gate.json](update-gate.json)，已安装 build 低于 `minBuild` 时进入更新页并引导到 Releases；清单拉取失败、结构异常或无法读取版本时一律放行，保证离线可用。清单目前只做门禁，不包含签名、差分或灰度；维护方式见 [MIRROR-TODO](MIRROR-TODO.md)。

Android 更新检查仍读取 GitHub Releases，但 Alpha.4 起可在应用内下载官方 APK（Alpha.5 保留），支持暂停、断点续传、GitHub 发布与 API 两个官方入口、SHA-256、包名、版本和签名证书校验。安装始终交由 Android 系统确认。没有自控国内 CDN 时，直接下载速度仍取决于 GitHub 连通性；页面保留手动发布入口。

2026-10-26 接续修复共享状态徽标：窄屏大字允许完整状态换行，不再以省略号隐藏限定语；徽标与图标底座的显式动态颜色按当前深浅主题解析。图标底座尺寸不变，字形随系统字号适度放大并限制在底座的 75% 以内；显式大图标同样有界，父级图标主题不会重复缩放。新增截断/语义/动态色及缩放边界回归，设备证据见 [集成记录](_audit/2026-10-26-module-integration.md)。物理设备和完整 TalkBack 验收未完成；改动随 Alpha.9 公开。

## 工作台状态修正（2026-10-28 工作树）

学校作业与历史关联本机待办仅在作业确实显示于工作台时去重；作业失败、过滤或未进入展示行时关联待办仍可见。空课表的日期不是学校今天时提示日期待更新，不再显示“今天没有课程”。作业区域展示学期及 Rust 原成功同步时间；演示和无快照时显示未确认，失败回退保留原时间。作业列表成功但课程身份辅助查询失败时，工作台和完整作业页均明确显示“作业结果不完整 / 课程身份未能全部核对”，即使列表为空也不将范围冒充已确认。日期仅今天统一显示“今天截止”，日期仅与精确时间的 24 小时内紧迫色一致；跨午夜、未知及非法日期有合成回归。

近期时间线已移除，不再重复课程、作业、待办或签到。考试使用独立 `TodayExamSection`，仅在有未早于学校今天的考试时显示，加载、失败和成功为空均不占位；刷新与账号/服务替换继续隔离旧响应。多来源作业部分成功契约与设备验收仍见 [待办](MIRROR-TODO.md)。

2026-10-28 本地完整镜像门禁通过；Android ARM64 模拟器上 `integration_test/today_test.dart` 以演示数据验证课程和考试条件显示，正常入口 Debug APK 另行构建。这些证据不包含物理设备、真实账号或学校写入。

## 学生服务搜索（2026-10-28 工作树）

移动工作台保留原有 iOS 分组列表，并提供“全部服务 / 搜索服务”二级页；搜索名称、领域、说明及本地别名，不发起学校请求、不检索个人记录。原生目的地复用工作区登记表，校车也登记为目的地；打印、住宿、就业、学术活动和网络指南标记“前往官网”，地址由 Rust upstream 提供，经 runtime / bridge / 应用接口传递，未知 ID 拒绝。返回搜索页保留查询，找不到时显示空态；研究生旧学分图别名不重复出现，物理设备、官网跳转及更多入口仍见 [待办](MIRROR-TODO.md)。

## 就业活动只读（2026-10-28 工作树）

新增独立“就业活动”入口：Rust upstream 匿名读取学校就业网公开月度日历，只接受 `state=1` 和数组结构，投影标题、校区、地点、时间、类型、状态原文和详情链接；成功结果进入 5 分钟查询缓存，失败保留旧快照和原时间，首次返回与缓存命中使用同一成功时间。Flutter 通过应用接口展示月份选择、同步时间、空态、失败重试，用户点击才打开详情；不发送个人数据、不提交报名，也不推断状态语义。合成覆盖正常、空、结构变化和缓存回退；真实非空设备与网络验收未完成。

## 学术文化只读（2026-10-28 工作树）

新增独立“学术文化”入口：匿名读取学校官网讲座与演出，分别投影类型、标题、发布日期、活动时间、地点和官方详情。后续页按首页当次总页数计算倒序页码，不把当前总页数写死；相对链接归一化为官方 HTTPS 地址。无列表项或结构漂移不冒充确认空，失败保留旧快照与原成功时间。页面回归覆盖字段、来源和失败旧值，Rust 回归覆盖解析、缓存、详情链接和总页数变化；真实设备与官网对照仍未完成。

就业活动采用类型化桥接 DTO，学术文化保留 JSON 信封并在缺少必需投影字段时报结构变化；两者均保留 Rust 返回的旧快照和失败码。切换月份或页码时清除旧查询呈现。共享刷新容器按请求代次管理看门狗和强制刷新槽，旧任务完成不会取消新请求的超时保护。

## 校园卡余额与签到重复记录（2026-10-28 工作树）

新增独立 `CampusCardGateway` 与航财通只读链路：`channel=BUAASSO` 复用北航统一认证，Rust 依次读取校园卡列表和余额，金额以整数分跨桥；不调用银行卡、消费明细或任何资金写接口。移动服务目录和桌面校园侧栏增加“校园卡”入口，用户点击才查询，金额默认遮挡，失败仅在本页保留旧值，离页/后台/换账号清除且不写通用快照。协议证据见 [校园卡余额记录](_audit/2026-10-28-campus-card-balance.md)，真实回跳和金额一致性未验收。

签到同场次的不同上游 ID 仅在存在未签到目标时分别显示并保留提交入口；已签到等无需操作的重复记录折叠为一行，同 ID 真重复仍折叠，冲突仍待确认。Flutter 统计和提醒按上游 ID 去重，不再误合并不同教学班。相关合成回归已接入，真实签到写入仍未验收。

## 安全加固与接口解耦（2026-10-28 工作树）

显式退出登录完成三处修复：`GinkgoApp` 向 `WorkspaceShell` 补传账号、路线和退出回调，设置页不再拿到空操作；Rust 退出不再等待上游登出 GET，本地身份、Cookie、快照和已保存密码直接清理；根页面先返回登录页，再等待退出标记的磁盘写入。合成回归覆盖退出期间零上游请求，以及从工作区设置确认退出后返回统一认证页。真实设备退出仍待用户复验。就业活动和学术文化页面在服务替换时清理旧状态并丢弃迟到响应；CGYY 核心命令与待办写均通过 `spawn_blocking` 移出异步 worker，写互斥与 pending marker 语义不变。

`tokio`、`rustls-webpki`、`webpki-roots` 已升级到安全公告修复版本。个人待办临时文件在 Unix 使用 `0600`，保留原子替换和损坏不覆盖；`AccountOwner` 与代次校验归回 `session_service`，CGYY、本人借阅、校园卡只消费统一身份接口，不再跨业务模块调用。项目主页 CSP 增加 `frame-ancestors='none'` 与 Trusted Types，保持自托管脚本和 GitHub API 白名单。`rsa` 的 RUSTSEC-2023-0071 公告无修复版本，当前博雅协议仍需要该依赖，风险单列于 [安全加固记录](_audit/2026-10-28-security-hardening.md)，未通过忽略公告或降低检查标准掩盖。

## 实现与维护边界

2026-10-26 正常 Android 安装包实测后，课表普通字号控制区改为学期/周次并排，大字号仍分行；修复周次文字溢出、已提交作业超期误提示与学习成功加载误报诊断。手机目录补齐学习、学分图和本人借阅入口。桥接空账号查询在运行时创建前拒绝。实测画面、环境和验收限制见 [正常包 UI 实测](_audit/2026-10-26-installed-app-ui-qa.md)，改动随 Alpha.9 公开。

2026-10-26 Alpha.9 增加连续左右翻页：点击移动标签时旧页与新页同屏交接，底部栏可左右轻扫切换相邻标签；各页仍只有一个导航栈，保留筛选与滚动位置。退场页停止 ticker 且不接收点击、焦点或读屏操作，减少动态效果时直接切换，不抢占课表横滑。提交文件响应另修复显式失败被文件 ID 误当成功的问题。验证与未覆盖范围见 [交互与协议接续记录](_audit/2026-10-26-page-turn-and-protocol-followup.md)。借阅真实认证、校车余票与新作答方式仍未打通。

| 层 | 定位 | 职责 |
| --- | --- | --- |
| 领域 | [domain](../rust/crates/ginkgo_domain/src/) | 数据模型与纯规则；无网络、平台保险库和 Flutter 依赖 |
| 协议 | [adapters](../rust/crates/ginkgo_upstream/src/adapters/)、[codecs](../rust/crates/ginkgo_upstream/src/codecs/)、[auth](../rust/crates/ginkgo_upstream/src/auth/) | 上游请求、认证、Cookie、路由与响应分类 |
| 上游会话 | [services](../rust/crates/ginkgo_upstream/src/services/) | 学校/业务会话恢复、token、查询缓存、协议时序 |
| 应用 | [application](../rust/crates/ginkgo_core/src/application/) | 只依赖 domain 业务端口的应用命令、投影和本地待办 |
| 组装 | [runtime](../rust/crates/ginkgo_runtime/src/) | 连接 core 与真实学校/平台实现 |
| 桥接 | [bridge API](../rust/crates/ginkgo_flutter_bridge/src/api/) | 类型映射与粗粒度命令；生命周期 RwLock 排斥身份变更和进行中的读取 |
| 呈现投影 | `lib/features/*/*_models.dart` | Rust payload JSON 的唯一解码点：按 domain 结构映射为类型值（cgyy、shuttle、bykc、library_books、library_stats、notices、graduate、checkin 遥测）；页面与共享组件不调用 `jsonDecode`，该边界由 `check-mirror-architecture.py` 强制 |
| 设计系统 | [design tokens](../flutter/lib/design/tokens/)、[widgets](../flutter/lib/widgets/) | token 层（颜色/布局/动效/圆角/间距/字体）+ 按职责拆分的组件模块（surfaces/controls/navigation）；`apple_widgets.dart` 仅作 barrel 转发 |
| 功能域 | [features/](../flutter/lib/features/) | 一个域一个目录：页面、域内组件（`<domain>_widgets.dart`）、模型与控制器同居；新增功能落在此处 |
| 功能组件 | `today_course_section`、`homework_widgets`、`homework_files_widgets`、`graduate_sections`、`library_cards`、`shuttle_widgets`、`checkin_widgets`、`schedule_widgets`、`cgyy_widgets`、`cgyy_day_view`、`bykc_course_tile` | 大页面抽出的行级/区块组件与整页拆分（如 CGYY 日查询/订单页独立于 hub）；widget API 只收发类型值，不出现 `Map<String, dynamic>`（同由架构脚本强制） |
| 跨域共享 | [shared/](../flutter/lib/shared/)、[platform/](../flutter/lib/platform/)、[workspace/](../flutter/lib/workspace/) | 多域共用的时间/偏好/提醒状态、平台与系统集成、壳层与功能登记表 |
| 组合入口 | `lib/main.dart`、`lib/mirror_service.dart`、`lib/startup_page.dart` | `lib/` 根只放入口；其余文件必须归入上表目录，由架构脚本强制 |
| 共享契约 | [fixtures](../fixtures/README.md) | 两种语言独立消费同一输入与期望领域投影；覆盖范围须明确 |

维护时遵守以下规则：

- 上游协议变化先记录 [API.md](API.md) 的证据及修订表，再修改适配器和版本化 fixture；结构漂移、业务拒绝与成功空结果保持区别。
- 同步锁不跨 `await`。可丢弃的内存状态中毒后整体重置；路线枚举保留完整值。持久化锁仍返回错误，不使用内存重置策略掩盖存储问题。
- 账号、profile、待续登录与业务 token 统一由 `ginkgo_upstream::services::SchoolClient.identity` 管理；增加身份字段时同时检查登录、退出、切路线及恢复路径。
- 安全 GET 的有界回退与认证恢复维持现有规则；写请求不自动重放。签到和图书馆操作须由用户确认、单次提交、回查；结果不明时禁止重复提交。
- Flutter 复杂异步页面先收拢快照、加载和回查状态。图书馆已有 `LibraryController`；选择器和导航等局部交互继续由页面管理。状态颜色通过 `AppleDesign.status*` 表达，颜色之外保留文字。
- 修改桥接 API 才重新生成 FRB 绑定；禁止手改生成文件。代码搜索和规模审查排除 `flutter/lib/src/rust/` 与 Rust `frb_generated.rs`。
- Dart 文件按域分目录：新功能新建或加入 `lib/features/<域>/`，跨域能力才进 `shared/`、`platform/`、`workspace/`。`lib/` 根只保留组合入口，单个 Dart 文件上限 600 行——两条都由 `check-mirror-architecture.py` 的 `layout_violations` 强制，超出需拆分而不是放宽阈值。
- 真实网络、设备交互、人工视觉与自动化合成测试分别记录。演示入口不得访问真实账号；仓库不保存凭据、票据或个人内容。

## 当前源码与发布基线

Android Beta.2（`0.1.0-beta.2+12`）已公开；[发布与验收记录](_audit/2026-10-29-android-beta2-release.md) 包含全量本地门禁、签名、摘要、公开 APK/校验文件回下载和验收限制。Beta.1 的历史发布与覆盖升级证据见 [Beta.1 记录](_audit/2026-10-27-android-beta1-preparation.md)。`docs/update-gate.json` 的 `minBuild` 仍为 5，未随本次发布提高。

## Android Beta.2 严重问题与工程收口（2026-10-29，已发布）

公开就业、学术文化、通知、校车、书目/馆藏、图书馆人数等请求此前复用了学校认证会话的 Cookie 容器。Rust `Session::send_anonymous` 为已迁移适配器创建隔离会话，移除 Cookie 与认证头，不导入响应 `Set-Cookie`，也不污染账号会话路线；父域 Cookie、响应 Cookie 和路线隔离均由合成回归覆盖。

本版同时按架构边界评审收拢 Flutter gateway、任务存储、提醒存储/平台通知与 native command 适配，补充单飞/迟到响应门禁并将可能阻塞的持久化工作移出异步执行路径。逐项依据和未完成项见 [工程整改记录](_audit/2026-10-28-review-remediation.md)。学校协议及其证据已同步到唯一事实源 [API.md](API.md)，完整 Dart/Rust 接口目录重新生成并通过新鲜度检查；发布范围与验收缺口见 [Beta.2 发布审计](_audit/2026-10-29-android-beta2-release.md)。

## 正确性与契约收口（2026-10-29 工作树）

退出登录的闸门超时补偿执行同一本地吊销与凭据清理；恢复型快照统一接受暂时性网络失败且继续拒绝认证回退；提醒整轮代次阻止超时后的旧签到/作业响应覆盖新计划。查询票在成功或失败落定后释放，主服务和更新 transport 仅缓存成功初始化并允许后续重建。

Dart 文件级 import/export/part 循环已消除并纳入架构门禁及自测。`FailureCode`、待办、提醒控制器和 workspace 导航值分别由叶子契约承载；目录与搜索显式共享 destinations。CGYY 七种写动作使用 sealed command，native 生成的学校 JSON 形状不变。逐项回归与未覆盖边界见 [正确性与契约整改记录](_audit/2026-10-29-correctness-and-contract-remediation.md)。这些改动未发布，未执行真实账号、物理设备或学校写入验收。

## 无障碍语义边界与模块级认证分层（2026-10-30 工作树）

页面缺少显式语义边界时，Flutter 会把整棵无自身属性的子树折叠成一个覆盖全宽的节点：校园卡“查询余额”按钮的节点覆盖整张卡片，作业行节点覆盖整个屏幕宽度，读屏与自动化会点错目标。`AppleSection` 现在是语义边界并使用显式子节点、标题标记 `header`；`AppleListTile` 每行一个节点，行尾控件另起节点，行本身的点击动作不被行尾动作覆盖。设备无障碍树复验：作业行收窄到卡片内，校园卡按钮节点收窄到按钮本身。

认证失败分层：CAS 登录页仍属全局会话失效；模块自己的拒绝（401/403、非 CAS 的 HTML、SPOC 信封 401/403）归为新的 `ModuleAuthRequired`，不触发全局静默重登，界面提示该服务需要重新验证身份且其他功能不受影响。学校跳转链本身未改动，真实凭据取证仍待完成。

“壳内文本输入触摸不聚焦”经设备取证确认为模拟器输入法配置所致，不是应用缺陷：输入框确实获得焦点并接受输入，软键盘被硬件键盘配置抑制。逐项证据见 [无障碍与认证范围记录](_audit/2026-10-30-accessibility-and-auth-scope.md)。这些改动未发布，未执行真实账号、物理设备或学校写入验收。

## 共享规则契约与页面分层清理（2026-10-30 工作树）

截止分类与签到窗口此前在 Rust（`ginkgo_domain::features::homework::classify_deadline`、`features::checkin::sign_in_window`）和 Dart（`homework_projection.dart`、`shared/reminder_rules.dart`）各有一份实现，Rust 侧的截止分类甚至无人调用。现在三处规则都只有领域实现：`fixtures/rules/` 的共享规则表锁定行为；`ginkgo_domain::features::reminders` 的 `plan_checkin_homework_reminders` 通过 `ReminderPlanningGateway` 注入；截止分类与签到窗口通过新的 `SchoolRules` 端口调用纯同步桥接命令，Dart 页面只做呈现。单元测试在 `flutter_test_config.dart` 注入 Dart 替身，替身与领域实现受同一张表约束，任一侧改出差异都会红。表覆盖跨零点、日期型与精确时刻型截止、无法解析的输入，以及签到窗口开放前一刻、开放瞬间、关闭瞬间、跨日与畸形时间。

页面分层：`infrastructure/service_factory.dart` 已删除。通知、待办、博雅、研究生教务四个页面不再在缺少注入服务时自行组装适配器——自行组装会让页面读到与工作区不同的账号绑定；博雅与研究生保留 loader 注入口，缺失时抛出明确错误。学习课程页、作业文件面板与设置维护页的默认实现也已上移：`MaintenanceService`、`AndroidDownload` 与文件读写端口迁到 `application/`，组合根（`main.dart`）绑定真实实现并经 `WorkspaceContext` 的 `PlatformActions` 传到页面，页面不再引用基础设施类型。架构门禁新增"`features/` 与 `workspace/`（组合根除外）不得导入 `infrastructure/`"，待迁移清单已清空。

## 研讨室入口与空教室呈现修复（2026-10-30 工作树）

预约聚合页现在把组合根解析出的 `CgyyBookingGateway` 继续传给研讨室页面，修复从“预约 → 研讨室与场馆 → 场馆”进入时预约按钮消失的问题；桌面/服务目录直达路径行为不变，演示模式仍不获得写能力。空教室仍一次读取学校完整结果并在本地每页 50 条懒加载，分页栏改为明确显示“本页范围 · 完整总数”；教室行直接列出排序、去重后的连续空闲区间，并保留空闲总数与最长连续节数，14 节状态矩阵留在详情页。连续区间合并、非连续/重复/乱序输入、320dp 2 倍字号和 600 间完整结果分页均有回归。真实账号与真实写入的验收边界见 [本轮记录](_audit/2026-10-30-classroom-and-cgyy-entry.md)。

## 学号字母大小写登录兼容（2026-10-30 工作树）

学号身份比较仅忽略 ASCII 字母大小写，兼容用户小写输入与 UC 返回大写 `schoolid` 的情况；不同学号仍 fail closed。内部账号和保险库键以 UC 规范学号为准，登录表单及密码不改写，旧大小写变体在保存成功或明确不保存时清理。手动登录与凭据恢复均有合成回归，真实账号复验边界见 [认证记录](_audit/2026-10-30-school-id-case.md)。

Alpha.9 在 Alpha.8 基础上带入连续左右翻页、SPOC 学习与资料保存、文件作业入口、验证码、学分地图、提醒、本人借阅、手机目录和视觉/无障碍修复。可选加密学习快照因尚缺人工安全审查，在公开 Release 中关闭。学校真实认证、借阅非空分页、校车余票和写操作仍未验收。

启动更新轻提示已进入 Alpha.7：真实入口首帧后非阻塞检查一次新版；查看进入更新页，稍后仅关闭本次提示，不自动下载或安装。错误诊断与最低版本门禁优先，失败静默放行；8 秒等待预算与迟到保护的历史实现证据见 [启动更新提示](_audit/2026-10-22-startup-update-hint.md)。

以下 10-22 小节保留各工作包的来源与历史边界，当前入口/行为以本节和 [功能索引](FEATURES-AND-PROTOCOLS.md) 为准，未完成任务只见 [TODO](MIRROR-TODO.md)。

## Android 工作台与外观精修（2026-10-22 工作树）

工作台移除首屏账户卡，保留页头设置；完整今日课程默认收起，下一节课与近期截止更早出现。待办保留本机完成主动作，编辑/删除移至可见更多菜单，已完成统一计数折叠，定位目标可展开；刷新移至页头次级菜单。常用服务由功能登记表提供候选，允许选择 0–4 项并按本机账号记忆；未知账号/演示仅内存，损坏读取拒绝覆盖、失败保存保留旧值，同账号重建时串行读写，避免旧保存覆盖新偏好。

显示设置扩为银杏绿、蓝、紫、湖水青、琥珀金、珊瑚橙、玫瑰红 7 组深浅强调色，提供选中标记、色样及无业务副作用的示例卡；不替换业务错误/警告色。10-22 的移动主栏目样板为 16px / 210ms；10-24 工作树改为整页宽纸感滑入、230ms、页缘阴影和书脊渐层，透明度恒为 1，保留原 Navigator、懒加载和浏览位置；不新增全屏横滑手势，系统/应用减少动态效果或进入非活跃状态时立即归位。Windows 继续共享源码，桌面保留原导航交互，Apple SwiftUI 不变。实现、合成验证及发布边界见 [体验精修记录](_audit/2026-10-22-android-workspace-polish.md) 与 [视觉语言记录](_audit/2026-10-24-android-visual-language.md)。

## Android 视觉语言与加载反馈（2026-10-24 工作树）

新增 `GinkgoIconTile`、`GinkgoBadge` 和 `GinkgoLoadingView` 原语；页面整页加载统一为固定银杏叶品牌色，局部 busy 使用小尺寸叶片，`flutter/lib/` 不再使用裸 `CupertinoActivityIndicator`。页头改为调用方显式提供 section/subtitle/icon，删除按标题字符串推断身份的表；服务目录、今日分区和快捷入口共用同一图标底座与徽标。

查书搜索区压缩并内嵌提交，馆藏按馆藏地、学校原始状态、索书号、册条码排序；校车首屏增加按北京时间推算的“下一班计划”，只展示静态计划和公布容量；图书馆与共享余量条降低视觉重量，未知余量继续用文字区分。主栏目切换仍是单时钟、单页绘制和独立返回栈，不复制 Navigator，也未实现保留旧页内容的真双页卷页。

源码、自动化、正常入口 APK、QEMU 实际只读截图及未覆盖边界见 [视觉语言记录](_audit/2026-10-24-android-visual-language.md)。该记录不表示已发布、已做物理真机验收或已通过真实学校写入。

## 2026-10-24 复核与安全收口（工作树）

对 2026-10-24 综合评审的可复现项完成第一批修复，全部为源码改动；相关修复现已随 Alpha.8／9 公开：

- **认证与身份**：CAS 登录表单 action 白名单（https + `sso.buaa.edu.cn`，拒绝端口/userinfo，`fetch_login_page` 与 `complete_login` 双重校验）；`complete_login` 与 restore 首段校验 `account == profile.school_id`，`set_authenticated` 对不一致 fail closed 并清 Cookie；Android 保险库枚举失败不再折叠为空列表，显式退出在 Rust 侧重试删除并在 Dart 侧持久化标记（`display-preferences-v1.json` 新增 `explicitSignOut` 字段），阻止下次启动自动恢复。
- **读路径与缓存**：`SnapshotCache` 增加全局单调请求票据，全部 12 处 await 后写入改为 `insert_if_current`，迟到旧响应不能覆盖新结果、clear 后旧代次票据全部失效。
- **Dart 可感知修复**：课程范围读取失败锁定编辑直至显式重试；课表选择仅由成功响应确认；作业详情倒计时取最新详情状态、午夜提示改解析比较；APK 原生校验失败后清理文件并转入可重下载；更新门禁返回前仅显示启动页、`releasesUrl` 收窄官方发布域白名单；待办空态文案、通知确认空态、校车“下一班”按分钟重算。
- **刷新合流**：`RefreshSection.refresh` 与 `LibraryController` 增加强制刷新补跑，在途非强制读期间的 `force` 不再被合流吞掉。
- **FFI 健壮性**：`ginkgo_upstream`/`ginkgo_core` 三处手写 `unreachable!()` 改为 `AppError::changed()`（FRB 生成文件内的同类不在手改范围）。
- **UI 重做**：`ReservationActionButton` 去描边、48dp 最小高度、主题语义 tint、新增行内紧凑款（图书馆座位/预约操作/CGYY 日期共用）；查书目页改为结果卡片（题名/著录/索书号两级）、上一页/下一页 Wrap 分页器与 `AppleEmptyState` 空态/错误态；`ginkgoTheme` 补 `navActionTextStyle`，修复导航栏返回键回退系统蓝。

验证：Rust core/upstream 全量 `cargo test` 与 `-D warnings` Clippy 通过；受影响 Flutter 页面逐一补回归（auth 26+、session 268、refresh_section、library_books 16、schedule、android_update 等）并 `flutter analyze` 无告警；模拟器 ARM64 Debug 正常入口构建安装，演示模式实机截图核对预约按钮、查书目页与导航栏像素颜色（返回键区域蓝色像素为 0）。未执行真实账号登录、学校写操作与发布；模拟器数据为离线演示，查书结果卡片在演示数据下不可见、由合成 widget 测试覆盖。

### 2026-10-25 授权账号只读验收（Android 模拟器）

账号所有者提供本人研究生凭据（仅环境变量与设备端输入，不入库、不写文件、截图不附姓名学号），在 ARM64 模拟器正常入口包完成只读闭环：CAS 真实登录进入工作台 → 课表真实学期/周次/课程渲染 → SPOC 作业真实条目与截止倒计时 → 公开目录真实检索（13933 条、结果卡片、上一页/下一页翻页、第二页加载）→ 校车静态时刻表与下一班计划 → 设置页退出登录确认 → 冷启动显示登录页、无自动恢复。本次登录链路同时实证 2026-10-24 的 CAS 表单白名单与账号身份校验在真实环境放行正常登录。图书馆座位/研讨室预约与 SPOC 首次读取显示"学校会话已失效"属账号类型边界（研究生无对应本科会话），局部失败保留其余分区可读。智慧校车 ShiftsSearch 实测定证见 [API §6C](API.md)。当时零学校写操作；2026-10-26 最新实网登录仍需复验。

## Android 视觉精修（2026-10-22 工作树）

在首批功能不变的前提下，Today与作业/待办流程参考iOS原生insetGrouped重新分配字重、字号、留白、灰阶与动作强调；不改全局token、业务/刷新/持久化/学校接口。具体视觉取舍、深浅/大字截图及验证范围见 [本轮记录](_audit/2026-10-22-android-visual-refinement.md)，该记录不证明与 iOS 逐像素一致；该精修现随 Alpha.8 公开，公开范围以 [Alpha.8 记录](_audit/2026-10-25-android-alpha8-release.md) 为准。

## Android 功能体验迭代（2026-10-22 工作树）

当前 Android 主开发方向见 [开发设定](ANDROID-DEVELOPMENT.md)。今天页新增正在/下一节课程焦点、近期作业直达及独立个人待办分区；返回详情/待办或切回工作台时只更新本地待办，不增加启动全模块读取。10-22 / Alpha.7 的作业详情曾支持经用户确认转为本机待办（当前工作树已移除此入口，历史来源记录仍兼容读取）；待办支持无截止、日期及精确北京时间编辑，完成状态不代表学校已提交。旧 v1 待办只读不改写，有效修改原子保存为 v2；损坏内容保持拒绝覆盖。提醒初始化/恢复仅在前台建立既有轮询，迟到响应不在后台重启计时器。

以上为该工作包当时的源码实现；后续公开范围见 Alpha.7 发布记录，自动化、Android 模拟器与正常入口包证据及剩余边界见 [迭代记录](_audit/2026-10-22-android-product-iteration.md)。本轮未修改学校协议和 Apple UI，也未执行真实学校写入。

## Android 研讨室写操作闭环（2026-10-22 工作树）

CGYY 沿用已取证的直连签名、草稿、人工拼图、单次提交/取消和回查路径；补完整预约/取消摘要、表单校验、忙时返回与连点保护。预约受理/未知返回实际订单页；订单保留原码并增加审批与保守取消资格。结果待核实保护按账号独立、先写本机最小标记再派发请求，重新登录/重启仍保留；核对页必须显示本次强读的最近 20 条，用户确认后凭 120 秒内一次性 ID 解锁，后台读成功不能自动解锁。正常入口请求绑定发起账号，防迟到回调作用于新会话；读契约 v1 和 Apple SwiftUI 保持独立。

10-22 当轮未使用真实账号/学校写入、当时尚未发布（后来随 Alpha.7 公开）；实现、分层回归与人工预约→回查→取消验收规程见 [CGYY 写流程记录](_audit/2026-10-22-android-cgyy-write-flow.md)。

## Alpha.6 工作树增强

签到新增课前十分钟的双层时间门禁；作业截止前 48 / 24 小时提醒、按账号未读角标、脱敏错误 hint 和 CGYY 用户确认写流程已接入。新增 UI 逐项对照 `IOSCgyyView` 的分组、时段网格、表单、人数步进与确认语义。Android 使用非精确本地系统提醒；Windows 暂仅应用内提示。设备覆盖与真实写入边界见 [Alpha.6 记录](archive/mirror/MIRROR-ALPHA6.md)，公开包以对应 Release 资产为准。

## 本次评审落实

原评审由用户提供，署名 **Opus 5.5**；本次核实与实现由 Codex 完成。逐项定位、采纳理由、已过时结论及回归证据见 [评审落实记录](_audit/2026-10-21-opus-review-followup.md)。

本次落地：Swift 扩展共享解析契约、Rust 锁中毒恢复与统一身份、Flutter 图书馆状态容器、跨页面状态色，以及落地页最小字号修正。未以大规模重写替代平台特性；剩余解析器拆分、契约覆盖、无障碍和设备验收见待办。

随后根据用户真机反馈完成的 Alpha.4 收口见 [发布记录](archive/mirror/MIRROR-ANDROID-ALPHA4.md)：手机视觉层级、Android 返回手势、设置完整性、SPOC 助教课程分类、iClass 首次读取反馈与应用内更新。Opus 5.5 原评审中仍成立的结构性问题继续保留在待办，不把本轮修复扩大为三端完全对齐。

## 本轮本地收口（2026-10-23）

本轮核对发布冻结点与后续源码，修正现状/任务清单漂移，补校车读取/外链/gateway 生命周期、实际复制菜单及查书排序/迟到响应回归与 Rust 公开会话隔离验证。结果和验证限制见 [推进收口记录](_audit/2026-10-23-android-progress-closeout.md)。不扩大为真实学校业务或新发包验收。

## 工作树：本人借阅读取（2026-10-26）

“本人借阅”由不支持说明页改为用户主动读取的独立模块，包含当前账号 Cookie 认证入口、
有界分页、题名/著者/索书号及借出/应还原文，失败与确认空分开。
不使用公开馆藏或选座 token 冒充私人记录；无磁盘快照、到期通知或续借写接口。
认证入口补充为官方公开配置/静态证据，App 真实认证与非空/多页仍未验收。
实现、安全审查范围与自动化结果见 [接续记录](_audit/2026-10-26-library-loans-integration.md)，随 Alpha.9 公开；真实认证与非空分页仍未验收。

## 工作树：原会话全范围集成与视觉闭环（2026-10-26）

学习、文件提交、验证码、严格学分地图、课程/待办提醒、可选加密学习快照及借阅的逐项实现、合成设备和真实只读边界，统一见 [本轮集成记录](_audit/2026-10-26-module-integration.md)。前五类能力随 Alpha.9 公开；加密快照默认关闭，且在公开 Release 中不可启用，仅覆盖 SPOC 学习元数据，需人工安全审查；不代表完整离线数据库。功能密集页、借阅和校车已做深浅色/窄屏大字的截图→修正→复拍，校车演示空数据误报已修，但本人借阅真实认证和实时余票仍未接通。

## 开发验证入口

工具版本和设备命令见 [Flutter README](../flutter/README.md)；Apple 构建与模拟器命令见 [TESTING](TESTING.md)。

```sh
bash scripts/check-mirror.sh
# 仅当桥接 API 变化
bash scripts/generate-mirror-bridge.sh
# Android 普通 main 入口（集成测试 APK 不能作为普通应用包）
cd flutter
flutter build apk --release --target-platform android-arm64 --target lib/main.dart
# 必须在 Windows 主机执行
flutter test integration_test/windows_test.dart -d windows
```

CI 入口为 [mirror.yml](../.github/workflows/mirror.yml)。本地通过不代表远端 CI 通过，平台结果只适用于记录中的环境与场景。稳定入口不手写测试/fixture 总数；某次运行的结果、环境和限制保存在带日期的验收记录中。

2026-10-22 模块拆分和边界防回退规则见 [MIRROR-ARCHITECTURE.md](MIRROR-ARCHITECTURE.md)；物理目录已调整，公开调用路径保留兼容导出。


## 工作树：SPOC 文件能力（2026-10-25）

独立业务端口、附件下载、更多提交信息、实验上传/确认/回查已接入，详见 [集成与分层测试](_audit/2026-10-25-spoc-homework-integration.md)。Alpha.9 普通构建开放个人文件上传/确认提交入口，先核对账号、能力及私有待确认记录，结果未知禁止重发。合成通路、Android 构建和未绑定账号的 FRB 设备通路不替代学校写入验收。

## 工作树：SPOC 学习只读能力（2026-10-26）

接续中断的课程、公告、资料、测验读取链路；Flutter 新增独立 gateway、业务类型与 native/demo 适配，失败旧快照携带 `stale/failure`，不丢弃或伪装新成功。`SPOC 学习` 为低频入口，不增一级标签；课程内分区独立读取与刷新，公告正文纯文本展示，当前工作树已接目录/面包屑/分页、本地搜索与显式多栏目选择，资料及公告附件可主动保存并打开；本轮增加被动接口状态说明和可选 Android 加密学习元数据快照。无标读、访问记录、考试开始/作答/提交请求，未实现能力不会因实现其他 gateway 隐式获得。

协议依据与证据等级见 [API §7.1.4](API.md#714-spoc-课程学习只读扩展2026-10-26静态证据与实测分开)，公开前端、真实只读及自动化结果分记于 [本轮记录](_audit/2026-10-26-spoc-learning-integration.md)。该学习能力随 Alpha.9 公开；本地构建与合成回归不替代真实非空公告/测验、下载和物理 Android 验收。

2026-10-26 用户补充准确官网入口后，校车外链由跳过认证的 indexPage 修为已验证的 HTTPS CASLogin，借阅官网由通用首页修为移动当前借阅页。仅外部浏览器入口修复，不宣称应用内余票或读者认证已打通；学校 CAS 的 HTTP service 回程未被 App 接管。证据见 [校车补充](_audit/2026-10-26-shuttle-auth-followup.md) 和 [移动借阅页复核](_audit/2026-10-26-library-loans-auth-followup.md)。

## Android Beta.1 工程收口与宣传重制（2026-10-27）

按 [接口索引](INTERFACE-INDEX.md) 的设计模式做了一轮跨层收口，并把仓库首页、GitHub Pages 主页与对外文案全部改成 Android 主推。

跨层改动：`edit_tasks` 不再因登录并发被丢弃（等待会话读锁，阻塞式 fsync 移到 `spawn_blocking`）；图书馆五处重复的令牌重建逻辑收敛为一个 `library_retry` 助手（行为不变，补回归测试）；upstream 删除 `pub use codecs as features` 别名，`features` 只指领域规则。

文档与门禁：`docs/INTERFACE-INDEX.md` 新增接口设计模式、返回形态与载荷契约、命令命名约定、自动化门禁四节，命令总数修正为 87；新增 `scripts/check-design-tokens.py`（硬编码视觉常量只许减不许增）与接口索引 `--check`，两者都接入本地基线与 CI。全量接口清单刷新为 36 个文件、1337 条记录。

宣传：新增 7 张真机尺寸 Android 截图与 1 段 20 秒离线演示录屏（`flutter/integration_test/promo_capture_test.dart` 在隔离模拟器上生成，仅合成数据），README 与主页换成 Android 素材与主推下载入口，`docs/PROMOTION.md` 全量重写。版本号提升为 `0.1.0-beta.1+11`，随后已随 Beta.1 公开，证据见 [Beta.1 发布与验收记录](_audit/2026-10-27-android-beta1-preparation.md)。

验证：全量 `check-mirror.sh` 通过（含 529 项 Flutter 测试、FRB 再生成零差异）；Android 模拟器上的离线演示截图与录屏驱动通过。真实账号、物理设备与学校写入仍未验收。

## CGYY UBAA 对照可用性修复（2026-10-27）

首页分为预约研讨室、我的预约和门锁密码。用途读取为空或允许降级的失败时使用 UBAA 十项内置用途并显示来源说明，认证失败不降级。新增 `order` / `lockCode` 两种只读查询：订单详情复用保守订单投影；门锁码按 UBAA `qrCode` / `dueDate` / `orderView` 白名单展示，无快照、无后台轮询，读取失败与无预约分开。保留手动拼图、单次写入、空档复核和待核实保护，未复制 UBAA 的写重试。分层 fixture 与 Flutter 页面回归覆盖用途、订单、门锁三态和大字号；真实预约、取消及门锁码读取仍未验收，相关源码已随 Beta.1 公开。

验证：59 项 CGYY Rust 专项与 52 项 CGYY Flutter 专项通过；完整 `check-mirror.sh` 通过（含 522 项 Flutter 测试及 FRB 再生成一致性）。ARM64 正常 main Debug APK 构建成功；`integration_test/cgyy_test.dart` 在 Android 17 ARM64 模拟器通过场馆、订单详情和门锁码真桥接演示链路。该设备结果为合成数据，不是物理设备或真实学校验收。

## 工作树：课表、研究生教务与 SPOC 使用体验（2026-10-27）

手机课表默认当日清单，提供七天星期切换；优先今天，其次首个有课日，宽屏仍默认周网格，搜索始终覆盖全周。研究生教务在同一页保留原概览、课程和学籍操作并嵌入严格学分地图，侧栏和移动目录不再重复出现“研究生学分图”，旧 ID 仅作兼容别名。SPOC 课程列表只保留一个刷新入口，空列表不显示搜索；课程详情改为资料/公告/测验分页，首次切页才读取对应分区，保留独立失败、旧快照、栏目、目录和下载上下文。

专项回归覆盖窄屏/宽屏课表、研究生单入口和学分语义、SPOC 懒加载、缓存、账号切换、下载及大字号触控目标。真实本科教务/学分地图仍未接入，未把研究生模型改名冒充；真实账号与物理设备验收边界不变。

## Android Beta.1 候选与宣传转化收口（2026-10-27，已发布）

项目主页进一步收口为 Android 下载与试用路径：首屏只保留一个主行动，新增三步安装、兼容性、Beta 已知边界、隐私和脱敏反馈，冻结平台退到页尾。发布前静态下载保持 Alpha.9，Release API 只在对应 Android 资产完整时同步版本、渠道与链接；API 失败和无 JavaScript 回退已验证。7 张页面截图新增 640px WebP，较原 PNG 减少 82.9%，另增 1200×630 社交分享卡。

最终完整门禁通过（当次 532 项 Flutter 测试）。正常入口签名 ARM64 Release 已核验版本、包名、证书、摘要、对齐与非调试边界；官方 Alpha.9 → Beta.1 模拟器覆盖升级保留首次安装时间和合成个人待办。GitHub prerelease、公开资产回下载与主页切换均已验证，完整证据见 [Beta.1 发布与验收记录](_audit/2026-10-27-android-beta1-preparation.md)。物理设备、真实账号与学校写入不因公开发布而标记验收。

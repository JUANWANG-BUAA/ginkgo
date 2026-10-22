# Rust + Flutter 镜像实施现状

更新：2026-10-23。功能与本地接口统一索引见 [功能和接口协议](FEATURES-AND-PROTOCOLS.md)。本页描述工作树；公开 APK 的内容以对应发布记录为准。模块差距只维护在 [功能对照](MIRROR-PARITY.md)，未完成事项只维护在 [待办](MIRROR-TODO.md)，过程与历次测试见 [历史证据索引](archive/mirror/README.md)。

## 产品与验收边界

| 平台 | 当前状态 | 证据与限制 |
| --- | --- | --- |
| macOS / iOS | 独立 SwiftUI 应用，共享 Swift 客户端、模型与工作区编排 | Apple 测试见 [TESTING](TESTING.md)；模拟器通过不代表真机、签名分发或真实写入通过 |
| Android | Rust + Flutter；公开包 Alpha.6（build 7），Alpha.7（build 8）发布准备中 | [Alpha.6](archive/mirror/MIRROR-ALPHA6.md)、[Alpha.7记录](_audit/2026-10-23-android-alpha7-release.md)；主要只读与CGYY主动写闭环已接入，真实写入未验收 |
| Windows | Rust + Flutter；公开包 Alpha.6（build 7），Windows 10 / 11 x64 单文件安装器 + 便携 ZIP | [首发记录](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)、[主机验证](archive/mirror/WINDOWS-2026-10-21.md)；系统保险库、宽屏侧栏、窄屏底部导航、键盘与返回栈基础通过；安装器未签名，物理 x64 / 干净系统运行依赖 / 真实学校业务仍未验收 |

既往真实账号只读检查已覆盖已接入模块，但最近一次集成登录失败；两次结果分别保留于 [验收记录](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md) 与 [认证异常诊断](_audit/2026-10-21-auth-redirect-incident.md)。不能把早先通过推广为当前所有网络均可用，也不能将工作树改动当作已经发布。

手机一级入口为工作台、签到、课表、作业、预约；桌面使用分组侧栏与独立目的地栈。`main.dart` 已按可用宽度 760px 选择手机或桌面布局。Android 保险库使用 Keystore；Windows Credential Manager 合成往返已通过，macOS 镜像保险库分支仍待验收。

Alpha.4 起，手机端使用 iOS 式大标题、分组卡片和触控尺寸；宽度达到 760px 后切换为 macOS 式“分区 / 标题 / 说明 / 操作”固定页头、较小圆角和桌面侧栏。Windows 首发包复用同一界面规则，在宽屏显示分组侧栏、窄窗口切换底部导航。系统返回一次先离开非工作台主页面，详情只退一层；工作台第一次返回只显示退出提示。显示与阅读、通知与后台、账号与隐私、UBAA 致谢和分享入口均已进入设置；未接入的后台提醒或品牌自启动能力在页面中明确说明。

2026-10-22 源码新增渐进加载样板：工作台的今日课程与个人课程作业分别读取、完成即显示，局部失败可单独重试；研究生教务保留学籍与执行报告的独立加载。两页参考原生 `IOSTodayView`、`IOSGraduateAcademicView` 的分组与局部状态，并沿用桌面的紧凑圆角及固定页头。加载使用主题色银杏叶轻微呼吸，首次内容出现时淡入；刷新时保留已有结果，不逐字输出课程或成绩。减少动态效果或所在标签页关闭 ticker 时停止呼吸动画；桌面支持 `Ctrl+R` / `⌘R` 刷新当前页。这些改动已进入 Android Alpha.5 公开包。

同日进一步优化大量结果浏览：座位与空教室每页 50 条、固定查询栏、按需构建、直接跳页；空教室增加楼栋选择与搜索输入合并，同一查询刷新保留页码和位置。课表固定节次轴、触摸横滑按天对齐、周次平滑定位与滑条、周次/星期直接选择。长页提供纵向滚动条及深处返回顶部入口。详见 [交互与更新边界](MIRROR-INTERACTION.md)；本地呈现分页不代表学校服务端分页或已接入远程代码补丁。同轮壳层收敛为功能登记表：移动端标签、桌面侧栏与今日快捷入口由同一条目派生，`main.dart` 只保留启动与登录状态机；登记仍是编译期静态表，不引入运行时插件加载。

同日补上最低版本门禁：客户端启动时读取 GitHub Pages 上的 [update-gate.json](update-gate.json)，已安装 build 低于 `minBuild` 时进入更新页并引导到 Releases；清单拉取失败、结构异常或无法读取版本时一律放行，保证离线可用。清单目前只做门禁，不包含签名、差分或灰度；维护方式见 [MIRROR-TODO](MIRROR-TODO.md)。

Android 更新检查仍读取 GitHub Releases，但 Alpha.4 起可在应用内下载官方 APK（Alpha.5 保留），支持暂停、断点续传、GitHub 发布与 API 两个官方入口、SHA-256、包名、版本和签名证书校验。安装始终交由 Android 系统确认。没有自控国内 CDN 时，直接下载速度仍取决于 GitHub 连通性；页面保留手动发布入口。

## 实现与维护边界

| 层 | 定位 | 职责 |
| --- | --- | --- |
| 领域 | [domain](../rust/crates/ginkgo_domain/src/) | 数据模型与纯规则；无网络、平台保险库和 Flutter 依赖 |
| 协议 | [adapters](../rust/crates/ginkgo_upstream/src/adapters/)、[codecs](../rust/crates/ginkgo_upstream/src/codecs/)、[auth](../rust/crates/ginkgo_upstream/src/auth/) | 上游请求、认证、Cookie、路由与响应分类 |
| 上游会话 | [services](../rust/crates/ginkgo_upstream/src/services/) | 学校/业务会话恢复、token、查询缓存、协议时序 |
| 应用 | [application](../rust/crates/ginkgo_core/src/application/) | 只依赖 domain 业务端口的应用命令、投影和本地待办 |
| 组装 | [runtime](../rust/crates/ginkgo_runtime/src/) | 连接 core 与真实学校/平台实现 |
| 桥接 | [bridge API](../rust/crates/ginkgo_flutter_bridge/src/api/) | 类型映射与粗粒度命令；生命周期 RwLock 排斥身份变更和进行中的读取 |
| 页面 | [Flutter lib](../flutter/lib/) | 导航、布局、无障碍、呈现状态；不解析上游协议 |
| 共享契约 | [fixtures](../fixtures/README.md) | 两种语言独立消费同一输入与期望领域投影；覆盖范围须明确 |

维护时遵守以下规则：

- 上游协议变化先记录 [API.md](API.md) 的证据及修订表，再修改适配器和版本化 fixture；结构漂移、业务拒绝与成功空结果保持区别。
- 同步锁不跨 `await`。可丢弃的内存状态中毒后整体重置；路线枚举保留完整值。持久化锁仍返回错误，不使用内存重置策略掩盖存储问题。
- 账号、profile、待续登录与业务 token 统一由 `ginkgo_upstream::services::SchoolClient.identity` 管理；增加身份字段时同时检查登录、退出、切路线及恢复路径。
- 安全 GET 的有界回退与认证恢复维持现有规则；写请求不自动重放。签到和图书馆操作须由用户确认、单次提交、回查；结果不明时禁止重复提交。
- Flutter 复杂异步页面先收拢快照、加载和回查状态。图书馆已有 `LibraryController`；选择器和导航等局部交互继续由页面管理。状态颜色通过 `AppleDesign.status*` 表达，颜色之外保留文字。
- 修改桥接 API 才重新生成 FRB 绑定；禁止手改生成文件。代码搜索和规模审查排除 `flutter/lib/src/rust/` 与 Rust `frb_generated.rs`。
- 真实网络、设备交互、人工视觉与自动化合成测试分别记录。演示入口不得访问真实账号；仓库不保存凭据、票据或个人内容。

## Android 下一版发包准备

当前工作树新增的产品与视觉内容拟作为 Alpha.7 发包，用户说明见 [草稿](releases/android-alpha7.md)，源码冻结、版本递增、签名 Release、checksums 与覆盖启动步骤见 [发包准备](_audit/2026-10-22-android-release-preparation.md)。当前 pubspec 仍为 `0.1.0-alpha.6+7`，既有 `android-v0.1.0-alpha.6` 标签不可复用。已交付的Debug包不能冒充发布更新；未执行新版本发布或提高minBuild。本文上方公开包信息按既往记录解释，本轮不依据本地tag推断远端状态。

## 启动更新轻提示（未发布工作树）

Android真实入口首帧后非阻塞检查一次新版，发现可用安装包时以hint提示；查看复用结果进入软件更新页，稍后关闭本次提示，不自动下载或安装。错误诊断与最低版本门禁优先，失败静默放行；8秒总等待预算与迟到结果保护见 [实现与20项定向验证](_audit/2026-10-22-startup-update-hint.md)。此前Debug包不含本次启动检查，发包须重建。用户版更新说明现按3–5条简短改进描述维护。

## Android 工作台与外观精修（2026-10-22 工作树）

工作台移除首屏账户卡，保留页头设置；完整今日课程默认收起，下一节课与近期截止更早出现。待办保留本机完成主动作，编辑/删除移至可见更多菜单，已完成统一计数折叠，定位目标可展开；刷新移至页头次级菜单。常用服务由功能登记表提供候选，允许选择 0–4 项并按本机账号记忆；未知账号/演示仅内存，损坏读取拒绝覆盖、失败保存保留旧值，同账号重建时串行读写，避免旧保存覆盖新偏好。

显示设置扩为银杏绿、蓝、紫、湖水青、琥珀金、珊瑚橙、玫瑰红 7 组深浅强调色，提供选中标记、色样及无业务副作用的示例卡；不替换业务错误/警告色。移动主栏目按索引方向轻移 16px、210ms 淡入，保留原 Navigator、懒加载和浏览位置；不新增全屏横滑手势，系统/应用减少动态效果或进入非活跃状态时立即归位。Windows 继续共享源码，桌面保留原导航交互，Apple SwiftUI 不变。实现、合成验证及发布边界见 [体验精修记录](_audit/2026-10-22-android-workspace-polish.md)。

## Android 视觉精修（2026-10-22 工作树）

在首批功能不变的前提下，Today与作业/待办流程参考iOS原生insetGrouped重新分配字重、字号、留白、灰阶与动作强调；不改全局token、业务/刷新/持久化/学校接口。具体视觉取舍、深浅/大字截图及验证范围见 [本轮记录](_audit/2026-10-22-android-visual-refinement.md)，不能视为已发布或与iOS逐像素一致。

## Android 功能体验迭代（2026-10-22 工作树）

当前 Android 主开发方向见 [开发设定](ANDROID-DEVELOPMENT.md)。今天页新增正在/下一节课程焦点、近期作业直达及独立个人待办分区；返回详情/待办或切回工作台时只更新本地待办，不增加启动全模块读取。作业详情可经用户编辑确认转为本机待办，保留来源、按账号防重复并定位已有条目；待办支持无截止、日期及精确北京时间编辑，完成状态不代表学校已提交。旧 v1 待办只读不改写，有效修改原子保存为 v2；损坏内容保持拒绝覆盖。提醒初始化/恢复仅在前台建立既有轮询，迟到响应不在后台重启计时器。

以上为源码实现，不表示公开包已更新；本轮自动化、Android 模拟器与正常入口包证据及剩余边界见 [迭代记录](_audit/2026-10-22-android-product-iteration.md)。本轮未修改学校协议和 Apple UI，也未执行真实学校写入。

## Android 研讨室写操作闭环（2026-10-22 工作树）

CGYY 沿用已取证的直连签名、草稿、人工拼图、单次提交/取消和回查路径；补完整预约/取消摘要、表单校验、忙时返回与连点保护。预约受理/未知返回实际订单页；订单保留原码并增加审批与保守取消资格。结果待核实保护按账号独立、先写本机最小标记再派发请求，重新登录/重启仍保留；核对页必须显示本次强读的最近 20 条，用户确认后凭 120 秒内一次性 ID 解锁，后台读成功不能自动解锁。正常入口请求绑定发起账号，防迟到回调作用于新会话；读契约 v1 和 Apple SwiftUI 保持独立。

本轮无真实账号/学校写入、未发布；实现、分层回归与人工预约→回查→取消验收规程见 [CGYY 写流程记录](_audit/2026-10-22-android-cgyy-write-flow.md)。

## Alpha.6 工作树增强

签到新增课前十分钟的双层时间门禁；作业截止前 48 / 24 小时提醒、按账号未读角标、脱敏错误 hint 和 CGYY 用户确认写流程已接入。新增 UI 逐项对照 `IOSCgyyView` 的分组、时段网格、表单、人数步进与确认语义。Android 使用非精确本地系统提醒；Windows 暂仅应用内提示。设备覆盖与真实写入边界见 [Alpha.6 记录](archive/mirror/MIRROR-ALPHA6.md)，公开包以对应 Release 资产为准。

## 本次评审落实

原评审由用户提供，署名 **Opus 5.5**；本次核实与实现由 Codex 完成。逐项定位、采纳理由、已过时结论及回归证据见 [评审落实记录](_audit/2026-10-21-opus-review-followup.md)。

本次落地：Swift 扩展共享解析契约、Rust 锁中毒恢复与统一身份、Flutter 图书馆状态容器、跨页面状态色，以及落地页最小字号修正。未以大规模重写替代平台特性；剩余解析器拆分、契约覆盖、无障碍和设备验收见待办。

随后根据用户真机反馈完成的 Alpha.4 收口见 [发布记录](archive/mirror/MIRROR-ANDROID-ALPHA4.md)：手机视觉层级、Android 返回手势、设置完整性、SPOC 助教课程分类、iClass 首次读取反馈与应用内更新。Opus 5.5 原评审中仍成立的结构性问题继续保留在待办，不把本轮修复扩大为三端完全对齐。

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

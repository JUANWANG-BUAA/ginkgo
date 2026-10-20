# Rust + Flutter 镜像实施与验收

> 2026-10-20 启动；2026-10-20 晚更新真实登录与只读链路。Android 以 iPhone SwiftUI 为视觉参照，Windows 以 macOS SwiftUI 为参照；按模块迁移，每个已迁移用例都要覆盖正常、空态、失败与恢复。完整产品范围见 RUST-FLUTTER-PORT.md。

## 当前边界

已创建 `rust/` Cargo workspace 与 `flutter/` Android/Windows 工程。Rust 核心、生成桥接、Flutter 页面形成真实进程内调用链，不是 Dart 仿造 Rust 返回值。应用启动后先恢复会话：没有已保存账号时进入登录页，也可以显式选择“先看看离线演示”。

认证与会话已经接入 bridge：

- Rust 进程内 Cookie jar、CAS 登录页解析与表单提交、手动重定向与错误分类、UC 激活/会话校验、自动/直连/WebVPN 路由隔离、过期会话单次恢复。
- 平台凭据保险库：Android 使用 Kotlin `CredentialVault` + Android Keystore AES-GCM + 私有 SharedPreferences，由 `JNI_OnLoad` 缓存类引用后从 Rust 调用；Windows 使用 Credential Manager，macOS 使用 Keychain，二者共用 `keyring` 适配。密码不以明文落盘，验证码答案不持久化。
- bridge 暴露 `login` / `restoreSession` / `signOut` / `sessionStatus`；Cookie、凭据和重定向链不进入 Dart。`verifyCredentialStorage` 是设备验收用的合成密钥往返诊断，不读写账号数据。
- 真实只读 bridge：空教室、课表、今天、成绩、课程签到、图书馆、SPOC作业、博雅、研究生教务、校园通知与CGYY。每类查询使用 5 分钟进程内快照；刷新失败保留旧结果；确认会话过期时仅静默重登并重试一次。账号切换、登出和路由变化都会清空快照。
- 课程签到与图书馆各自拥有独立的短生命周期业务会话：iclass 的 loginName 只在一次请求内使用、sessionId 只留在 Rust；booking.lib 的 CAS 票据只用于换取业务 token，token 只留在 Rust。两者都不会进入 Dart。
- 应用层在 WebVPN 自动回退后，会按需用平台保险库中的凭据建立网关自身的 CAS 会话；没有保存密码时明确返回需要重新登录，而不是反复重试直连。网关响应的 final URL 与 Location 统一还原为上游 URL（见 `auth/session.rs`）。
- `load_demo_*` 保留为明确的离线演示入口，页面脚注会区分“离线合成样例”和“真实账号只读数据”。

当前手机一级入口为工作台、签到、课表、作业、预约，次级服务按学业/个人与校园分类。设置有工作台首屏“账户与设置”和右上角齿轮，桌面设置固定在侧栏底部。模块与协议交叉核对见 [体验重设计](MIRROR-EXPERIENCE-DESIGN.md)。2026-10-20 已使用用户本机登录会话完成部分真实只读复验，具体见下文；不将合成 smoke 或非空 payload 等同完整体验验收。希冀和全部上游写操作关闭。

## 完成度快照（2026-10-20 晚）

| 能力 | 状态 | 证据 |
| --- | --- | --- |
| Rust workspace、FRB 桥接、Flutter Android/Windows 壳 | 完成 | `scripts/check-mirror.sh` 通过；Android debug APK 构建通过；`mirror.yml` 已入库 |
| 共享契约与 fixture | 35 类、108 份 | Rust runner全部通过；134 项 lib + 1 项契约测试 |
| 课程签到真实只读 | 已接入；真实只读响应通过 | iclass SSO/当天课程/signStatus 解析、重复记录合并与冲突归一、快照/失败保留/单次重建、WebVPN 网关会话回退；Android `checkin_test.dart` 通过 |
| 图书馆真实只读 | 已接入；真实只读响应通过 | booking.lib CAS、场馆/区域/时段/座位/当前预约解析、业务 token 单次重建、快照/失败保留；Android `library_test.dart` 通过 |
| 认证核心（Cookie/CAS/UC/WebVPN/恢复） | 完成（mock） | 认证单元/流程/mock HTTP 测试 |
| 真实传输（reqwest + rustls） | 编译与 Android 运行 | macOS 编译、Android aarch64 交叉检查、模拟器真实 FFI |
| 平台凭据保险库 | Android 已实测；Windows/macOS 代码完成 | Android `auth_test.dart` 两次密钥往返通过；Windows 尚未构建/实机 |
| bridge 登录/恢复/登出 | 完成 | `login` / `restoreSession` / `signOut` / `sessionStatus` |
| 空教室真实只读 | 完成（mock，Android 页面回归） | Rust 应用层恢复/缓存测试；完整 `mirror_test.dart` 仍有长流程未收敛 |
| 课表真实只读 | 完成（mock + 真实研究生账号） | BYXT 302 跟随、GSMIS 学期/周次/整学期课程；第 7 周真实读取 |
| 今天真实只读 | 完成（mock + 真实账号） | 研究生今天课程由 GSMIS 课表推导并合并相邻节次；BYXT mock + 快照/恢复测试 |
| 成绩真实只读 | 完成（mock + 真实账号空结果） | 学期发现、学期切换与 buaascore；真实账号当前/历史学期均无已发布成绩，不能据此验收非空成绩 |
| 作业 | 实际只读链路已接入 | SPOC CAS/token/课程学期/分页/详情；mock与Android合成smoke通过；真实响应已复验，逐项信息人工对照待验收 |
| Flutter 登录页与会话门禁 | 完成 | 6 项会话 widget 测试；Android 真实登录页启动验收 |
| 真实账号只读验收 | 已完成一次（只读） | 授权账号登录、今天/课表/空教室/成绩读取；未保存截图中的姓名学号，未执行写操作 |
| Windows 构建与实机 | 未开始 | 只有工程与 CI 入口；keyring Windows 分支未在本机编译 |
| BYKC、研究生教务、校园通知、CGYY | 实际只读链路已接入 | 各模块独立Android合成FFI smoke通过；真实响应已复验，Windows待验收 |
| 本地待办 | Rust持久化CRUD已接入 | 账号隔离/损坏保护与Android文件往返通过；无提醒与同步 |
| 签到/图书馆写操作 | 未开始（按设计关闭） | 页面只展示只读状态，不提供提交入口；写协议需独立评审、二次确认与回查 |
| 写操作与发布 | 未开始 | — |

### 距离目标还差什么（按阻塞顺序）

1. **签到/图书馆只读完善**：本机授权登录已验证当天课程及场馆/区域/时段/座位/当前预约的真实响应；历史、公共信息等仍需按对照表补齐。iclass 直连在当前网络不可达，WebVPN 网关回退需要在登录时保存密码（保险库）才能建立网关会话。
2. **既有模块真实只读复验**：CAS→UC、空教室/课表/今天/成绩的真实响应与错误分类；不执行写操作。
3. **验证码图片与交互**：当前 bridge 能返回 `captchaId`/`captchaImageUrl`，但 Rust 传输只保留文本响应，Flutter 也还没有图片展示；登录页只显示“需要验证码”的说明和输入框。
4. **Windows/macOS 凭据保险库验收**：Windows 主机构建并验证 Credential Manager 往返；macOS Keychain 在签名/未签名运行下的授权提示需要单独记录。
5. **课表/成绩剩余**：真实学期切换/搜索/详情对照与真实非空成绩；新课表UI、未缓存保留已通过合成设备smoke。
6. **新模块内容人工对照**：SPOC列表详情、BYKC、研究生教务、校园通知、CGYY目录/时段/订单的真实响应已通过，不等同信息全部齐全；希冀来源继续关闭。
7. **模块完善**：CGYY订单下一页、更多跨模块可访问性；目前只读链路均已接入。
8. **P4 本地能力**：提醒/同步及权限；待办CRUD、登出清快照和通知原文外链已接入。
9. **Windows 主机构建与实机验收**；当前没有任何 Windows 通过记录。
10. **视觉与可访问性闭环**：签到/图书馆新页面与登录页、真实/演示状态的固定视口浅色/深色/大字号截图、TalkBack/VoiceOver、减少动态效果。
11. **写操作**：签到、预约、取消、选课等，逐项协议证据、二次确认、提交后回查与“未知结果不重发”。
11. **发布**：Android/Windows 安装、升级、签名、隐私说明和发布流水线。

## 工程入口

| 层 | 路径 | 责任 |
| --- | --- | --- |
| 领域与基础规则 | `rust/crates/ginkgo_core/src/features/`、`foundation/` | 教室规则、BYKC 分类、IANA 上海时区、课表周次 |
| 应用会话 | `rust/crates/ginkgo_core/src/application/session_service.rs` | 登录/恢复/登出、账号身份、路由、快照生命周期 |
| 真实只读用例 | `.../application/classroom_service.rs`、`schedule_service.rs` | 空教室、课表、今天、成绩与失败保留 |
| 快照 | `.../application/cache.rs` | 5 分钟 TTL、容量上限、时间戳 |
| 凭据保险库 | `rust/crates/ginkgo_core/src/auth/platform/`、`flutter/android/.../CredentialVault.kt` | Android Keystore/JNI、Windows/macOS keyring |
| 桥接 | `rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs`、`live.rs` | DTO、稳定错误枚举、粗粒度用例 |
| Flutter 绑定 | `flutter/lib/src/rust/` | FRB 2.12.0 自动生成 |
| 登录与会话 | `flutter/lib/login_page.dart`、`main.dart` | 登录表单、会话门禁、真实/演示切换 |
| 页面与外观 | `flutter/lib/classroom_page.dart`、`classroom_detail.dart`、`schedule_page.dart`、`schedule_grid.dart`、`apple_widgets.dart`、`apple_design.dart` | 页面状态、导航、周网格/列表、样式和交互 |
| 设备测试 | `flutter/integration_test/auth_test.dart`、`mirror_test.dart`、`schedule_test.dart`、`today_test.dart`、`grades_test.dart`、`homework_test.dart` | 真实 Rust 动态库 + Flutter UI |
| 截图驱动 | `flutter/test_driver/integration_test.dart` | 保存 PNG；不把截图成功误报为相似度通过 |
| 认证 | `rust/crates/ginkgo_core/src/auth/` | `cas` 解析、`login` 登录链、`uc` 会话校验、`session` Cookie/路由 |
| 真实传输 | `rust/crates/ginkgo_core/src/adapters/reqwest_transport.rs` | 30 秒超时、禁用自动重定向 |

工具版本和运行命令见 [Flutter README](../flutter/README.md)。`scripts/check-mirror.sh` 运行 Rust 格式、Clippy、契约及 Flutter 检查；`scripts/generate-mirror-bridge.sh` 生成绑定。CI 配置见 `.github/workflows/mirror.yml`，远端结果必须单独确认。

## 用例覆盖矩阵

| 用例 | Rust | Flutter widget | Android 设备 |
| --- | --- | --- | --- |
| 共享契约，含正常/空结果/结构漂移/无效输入 | 35 类 108 份 fixture runner | — | 七个合成切片经过真实 FFI |
| 平台保险库写入/读回/删除 | Android JNI 适配 + MemoryVault 测试 | — | `auth_test.dart` 两次往返通过 |
| 无保存账号时进入登录页 | `restore` SignedOut | 会话门禁测试 | `auth_test.dart` 通过 |
| CAS 登录页/验证码/提示解析 | 2 份共享 auth fixture + 单元测试 | 验证码提示测试 | — |
| CAS→UC 登录、错误分类、重定向上限 | mock HTTP 流程测试 | 登录失败/验证码状态 | — |
| Cookie 域/路径/过期、直连与 WebVPN 隔离 | jar 与会话测试 | — | — |
| 会话过期单次恢复 | mock HTTP 端到端 | 失败提示 | — |
| 登录/登出/记住密码 | 应用会话测试 | 登录门禁测试 | 登录页启动；未用真实账号提交 |
| 空教室请求/解析/缓存/旧结果 | 应用层 mock 测试 | 旧结果提示测试 | `mirror_test.dart` 合成流程 |
| 校区 1/2/3、无效校区、无效日期 | 应用层校验测试 | 浮动校区菜单 | 查询范围流程 |
| 1–14 节、全部最少/连续空闲选项、三种排序 | shared fixtures + 应用层测试 | 最新结果优先 | 逐选项及组合流程 |
| 五分钟缓存、过期、强制刷新、账号隔离 | 应用层测试（受控 Transport） | 旧结果提示 | 刷新/旧结果流程 |
| 稳定错误码、重试、旧结果保留 | 无效 typed 请求 + 应用层测试 | 失败恢复、旧结果 | 原生错误与重试 |
| 课表门户/学期/教学周/课程/考试 | 7 份共享 fixture + mock HTTP + 应用层测试 | 课表页 widget 测试 | `schedule_test.dart` 通过 |
| 课表快照、未缓存周次、失败保留 | 应用层测试 | 课表页 widget 测试 | 周次切换流程 |
| 今天课程请求/解析/日期/失败保留 | 3 份 today fixture + mock HTTP + 应用层测试 | 今天页 widget 测试 | `today_test.dart` 通过 |
| 成绩学期发现/解析/汇总/学期切换 | 6 份成绩 fixture + mock HTTP + 应用层测试 | 成绩页 widget 测试 | `grades_test.dart` 通过（更多 → 成绩） |
| SPOC 分页加密/列表 | 黄金向量 + 契约测试 | 作业页筛选 | `homework_test.dart` 通过（仍为合成） |
| 课程签到 SSO/当天课程/状态归一/冲突 | 7 份 checkin fixture + mock HTTP + 应用层测试 | 签到页状态/空态/失败/旧结果/刷新 | `checkin_test.dart` 通过（合成） |
| 签到 WebVPN 回退与网关会话 | 会话域响应归一测试 + 端到端 mock | — | — |
| 图书馆 CAS/场馆/区域/时段/座位/当前预约 | 9 份 library fixture + mock HTTP + 应用层测试 | 图书馆层级、空态、错误 | `library_test.dart` 通过（合成） |
| 图书馆业务 token 失效单次重建 | 应用层 mock 测试 | — | — |
| 深色、放大文字、宽屏导航、页面过渡 | — | 外观、菜单语义、导航字体回归 | 深色放大文字流程（旧结果见视觉审查） |
| 真实账号只读 | — | — | 今天/课表/空教室/成绩已完成；签到/图书馆待用本机登录验收 |

设备执行结果、截图与视觉差异见 [视觉审查](MIRROR-VISUAL-AUDIT.md)。测试覆盖的是 mock、合成 fixture 与离线页面，不代表真实学校查询已验收。

## 整体迁移清单

| 模块 | 状态 | 下一步 |
| --- | --- | --- |
| 核心/桥接/Android 壳 | 已建立；真实会话与只读命令已接入 | 保持可重复生成、构建与设备回归 |
| 空教室 | 真实只读 use case + 缓存/恢复/旧结果；页面仍可演示 | 真实账号只读验收 |
| 学校时间 | 共享 fixtures 已对齐 | 扩展学期/教学周日期边界 |
| 课表 | 本科真实只读 + 周网格/列表/考试 + 缓存/恢复 | 研究生课表、学期切换、真实账号验收 |
| BYKC | 搜索与类别过滤规则 | 学期策略、客户端与页面 |
| 成绩 | 学期发现 + 真实只读 + 汇总 + 缓存/恢复 | 学期切换 UI、真实账号验收 |
| 今天 | 真实只读 + 时间线 + 缓存/恢复 | 跨北京时间午夜、真实账号验收 |
| CAS / UC / WebVPN | 登录链、UC 校验、路由、恢复、bridge 登录 | 验证码图片、真实账号只读验收 |
| 凭据与账号缓存 | Android Keystore 实测；Windows/macOS keyring 代码完成 | Windows 实机、账号切换 UI、缓存清理 |
| 学校作业 | SPOC 分页加密/列表解析 + 合成页面 | token/CAS、详情、希冀来源与真实只读 |
| 研究生教务（GSMIS） | 未移植 | 学期/周次/课表解析与页面 |
| 图书馆 | 真实只读（CAS/场馆/区域/时段/座位/当前预约）+ 页面层级 | 真实账号只读验收；写操作单独评审 |
| 课程签到 | 真实只读（iclass SSO/当天课程/signStatus/冲突归一）+ 页面 | 真实账号只读验收；签到写操作单独评审 |
| 研讨室 / 场馆 / 校园通知 | 未移植 | 按接口稳定度补只读路径与失败分类 |
| 本地待办 / 账号切换 / 通知 | 未移植 | 账号切换、通知权限与本地待办 |
| Windows | 工程与 CI 入口已创建 | Windows 主机构建/实测及 macOS 布局对齐 |
| 完整导航外壳 | iOS 五 Tab、更多分组、桌面分组、设置页、图书馆/签到真实页面 | 账号切换、视觉与可访问性闭环 |

预约、取消、选课、签到提交继续按 COLLABORATION.md 的独立写操作评审与人工触发规则执行。

## 已知工程限制

- 已完成一次用户授权的真实账号只读验收：登录、今天、课表、空教室、成绩空结果与登出；没有执行预约、签到、选课或其他写操作。真实姓名与学号没有写入仓库、文档或日志。
- 该账号为研究生，BYXT 门户不能提供本科课表/考试；GSMIS 已接入学期、周次与整学期课程。研究生考试、培养方案、学籍等仍未迁移。
- 真实成绩为空（当前学期与历史学期），非空成绩解析、汇总和 GPA 对照仍缺真实样本。
- 验证码只返回挑战对象；没有图片字节传输、图片展示或刷新，登录页只能提示并允许手动填写验证码。真实风控触发时仍可能无法完成登录。
- 记住密码保存失败不会阻止登录，bridge 返回 `remembered=false`；Flutter 目前没有单独提示用户“已登录但未能保存密码”。
- 快照只在进程内保存 5 分钟，不落盘、不读取 Apple 缓存；进程重启需要重新登录或依赖平台保险库静默恢复。
- 网络运行时和平台保险库在第一次异步 bridge 命令（通常是 `restoreSession`）时懒初始化。不要在 `init_app` 里预创建 `reqwest`/tokio 运行时：Android 实测会卡在启动画面。登录页在冷启动首次显示约需数秒，属于当前已知开销。
- 设置页已提供自动/直连/WebVPN 路线选择；切换路线会退出当前会话。遇到访问策略或直连传输失败时，安全 GET 由 `send_with_fallback` 单次切换到 WebVPN。
- iclass 直连在当前网络不可达（TLS 连接超时），签到只读实际依赖 WebVPN 网关。网关需要自己的 CAS 会话：只有在登录时保存了密码（平台保险库）时，应用才能自动建立；否则页面返回“需要重新登录”。该网关登录全链路目前只有 mock 覆盖，尚未对真实上游验收。
- `booking.lib` 的证书链在部分平台不被信任（API.md §5.4）；直连可能失败，WebVPN 转发路径同样未真实验收。
- 签到与图书馆的写操作没有实现：没有预约、签到入座、暂离、离馆或取消的提交入口；不要用“页面已展示座位/课程”推断写操作可用。
- Windows Credential Manager 与 macOS Keychain 分支未在本机完成构建/运行验收；Windows CI 结果必须单独确认。
- macOS Keychain 对未签名开发构建可能弹出授权，不能用“代码已写”替代实机记录。
- 作业仍是合成切片；真实 SPOC token/CAS、课程/学期上下文和详情未迁移。
- 课表已同时接入本科 BYXT 与研究生 GSMIS；GSMIS 不提供考试区，页面按门户隐藏。
- 空教室完整 `mirror_test.dart` 仍未全绿：查询/详情/排序项通过，校区/日期/缓存长流程在设备测试框架内长时间不收敛；不能宣称五 Tab 外壳下全部通过。真实账号空教室查询已读取 158 间/3 栋，筛选与详情仍需单独验收。
- 课程签到与图书馆已从骨架替换为真实只读页面，但只读验收尚未覆盖真实上游：签到需要 WebVPN 网关会话（依赖保存的密码），图书馆需要在当前网络下完成 CAS 往返。设备测试目前使用共享合成 fixture。
- 移动端为 iOS 的“今天 / 课表 / 作业 / 图书馆 / 更多”五 Tab；桌面侧栏按工作台/学习/校园/更多分组。空教室与成绩移到“更多”，图书馆是 Tab，课程签到在“更多 → 工作台”；设置页已接入账号、路线、缓存清理与登出。
- `verifyCredentialStorage` 是面向设备验收的诊断 bridge 命令，会写入并删除一个调用方提供的合成密钥；它不接受真实账号数据，也不应作为普通用户功能暴露。
- 视觉只完成了外壳、部分页面与登录页的启动检查；真实/演示状态的固定视口、深色、大字号与 TalkBack/VoiceOver 闭环仍未完成。

## 2026-10-20 真实账号只读验收与导航重构

用户在本机模拟器授权登录一次真实研究生账号；首次登录关闭“记住密码”，后续为加速迭代开启，验收结束已退出登录并清空保险库。没有把账号、姓名、Cookie 或课程数据写入仓库。

验收结果：

- 登录：CAS→UC 成功，进入工作区；之后为加速迭代曾打开“记住密码”，验收结束通过设置页退出登录，Android SharedPreferences 中保险库条目为空。
- 今天：显示“今天 1 节课”，由 GSMIS 当前周课表推导；相邻节次合并为一条课程，修复了重复 `Key` 导致的 Flutter 红屏。
- 课表：真实读取 2026-2027 学年第一学期、第 7 周及本周课程；周网格与考试区按研究生门户隐藏考试。
- 空教室：真实查询“学院路”当天返回 158 间 / 3 栋，来源标记“学校实时数据”。
- 成绩：学期选择器读取到 GSMIS 多学期；当前学期与选中的历史学期均显示“本学期暂无成绩”，无法验证非空分数、学分与 GPA，不能据此宣称成绩解析已真实通过。
- 登出：清除内存会话、平台保险库条目与快照，回到登录页。
- 没有执行任何预约、签到、选课、取消或写操作。

本次真实测试暴露并修复的缺陷：

1. BYXT/GSMIS 业务 GET 不跟随 SSO 302，导致误报“学校会话已失效/服务不可用”；新增有界 GET 重定向跟随，并在重定向环路上限为 10。
2. 研究生账号落到 BYXT HTML 时被误判为服务不可用；新增 `Unconfirmed` 并转 GSMIS，完成研究生学期/周次/课程解析。
3. 相邻节次课程未合并，今天页出现重复课程与重复 Widget Key；移植 Apple 的合并规则。
4. 成绩页没有学期切换；新增 GSMIS/BYXT 学期列表 bridge 与 iOS 风格学期选择器。
5. Flutter 外壳只有五个平铺功能页；改为 iOS 的“今天 / 课表 / 作业 / 图书馆 / 更多”五 Tab，桌面端按“工作台 / 学习 / 校园 / 更多”分组，并新增设置页。

本轮之前，图书馆和课程签到只是按 iOS 层级放入的导航骨架。第二轮已把两者替换为真实只读链路，见下节。

## 2026-10-20 晚（第二轮）：课程签到与图书馆只读

本轮把“课程签到 / 图书馆”从导航骨架替换为真实只读链路，写操作保持关闭。

### 课程签到（iclass）

- 领域：`features/checkin.rs` 只解析已记录字段；STATUS 成功为 "0"（容忍 200/success），STATUS "2" 仅对当天课程查询表示“无课”；其他业务状态是 `business_rejected`。`signStatus` 0/1 归一，未知值显示“待确认”。重复记录按 id 或可见课程时间合并，组内状态或时间冲突时整组转为 unknown。
- 适配：`adapters/checkin_http.rs` 手动跟随入口 3xx（最多 8 跳），只取 loginName 查询值；app login 使用文档参数；当天课程带 `sessionId` 头；登录页、401、结构漂移、业务拒绝分别分类。
- 应用：`application/checkin_service.rs` 持有内存 app session；业务拒绝或 401 时重建一次，仍失败且确认学校会话过期时静默重登一次；5 分钟快照、刷新失败保留旧结果；登出/账号/路线变化清空。
- WebVPN：`auth/session.rs` 统一把网关响应的 final URL 与 Location 还原成上游 URL；入口遇到网关登录页时返回 `webvpn_login_required`，应用层用平台保险库凭据建立网关 CAS 会话后重试一次。没有保存密码时直接要求重新登录，不循环重试。
- 页面：日期与星期、课程数、已签到/未签到计数、逐课程状态、合并与冲突提示、刷新、空态（STATUS=2）、错误与旧结果提示；没有签到按钮。
- 证据：7 份 fixture；6 项领域 + 8 项适配器 + 5 项应用测试；4 项 widget 测试；`checkin_test.dart` 在 Android 模拟器通过（真实 FFI + 合成数据）。

### 图书馆（booking.lib）

- 领域：`features/library.rs` 严格解析场馆/区域/时段/座位/当前预约；字段同时接受 snake_case 与 camelCase；空列表、结构漂移、业务拒绝分开；重复 id 视为结构问题。时段 id 由日期与上游 id 组合，预约展示不读取成员身份字段。
- 适配：`adapters/library_http.rs` 手动走 8 跳 CAS，cas 参数兼容 query 与 fragment 并百分号解码；登录后交换业务 token；业务请求使用 `Authorization: bearer<token>`（无空格）；401/403、登录失效文案、非 0/1 code、HTML 登录页分别处理。
- 应用：`application/library_service.rs` 业务 token 只存内存，失效时重建一次；场馆与当前预约 5 分钟快照、失败保留；区域/时段/座位按选择实时读取，页面保留上次列表。
- 页面：当前预约、场馆 → 区域 → 时段 → 座位四级推入；空态、错误、刷新；没有预约/签到/暂离/离馆/取消按钮。
- 证据：9 份 fixture；5 项领域 + 6 项适配器 + 3 项应用测试；3 项 widget 测试；`library_test.dart` 在 Android 模拟器通过（真实 FFI + 合成数据）。

### 本轮测试与边界

- `scripts/check-mirror.sh`：121 项 Rust lib 测试 + 1 项契约测试 + 24 项 Flutter widget 测试通过。
- Android aarch64 交叉 `cargo check` 通过；debug APK 构建、安装与 7 个设备测试（auth/today/schedule/grades/homework/checkin/library）通过。
- 未完成：签到/图书馆真实上游只读验收；写操作；Windows 实机；新页面的固定视口浅色/深色截图。
- 设备测试只证明真实 FFI 与页面渲染；不能替代真实学校查询。

维护边界、fixture 治理、桥接演进与各层证据要求见 [MIRROR-MAINTENANCE.md](MIRROR-MAINTENANCE.md)。

## 2026-10-20：课表优先重构

- 学期参数贯穿 Rust 用例、FRB 与 Dart；BYXT/GSMIS 命中指定学期，否则回退学校选中/首个学期，返回最终学期。缓存按 `(term_id, week)` 隔离，今天仍请求默认学期与周次。
- 手机使用按星期与日期分组的课程列表，时间/节次、色条、课名、地点和教师分层；推入课程详情。学期菜单、带日期的周条、本周快捷入口、课程/学期/考试分段与本地搜索已接入。学期列表不编造课程数；考试仅在已有数据时出现。
- 刷新与未缓存周失败保留旧课表并提示实际显示范围；请求序号保护快速切换。排序/过滤在数据或关键词变化时计算。宽屏保留七列网格并显示日期、今天列，放大文字改用列表。
- 验证：21 项 Rust 课表相关测试、122 项 workspace lib + 1 项契约、Clippy、Flutter analyze、25 项 widget 测试通过；Android `schedule_test.dart` 1 项真实 FFI + 合成 fixture smoke 通过。未运行已知不收敛的 `mirror_test.dart`；其重复课表用例已移除，保留独立 smoke。FRB stem 为 `ginkgo_flutter_bridge`。
- 模拟器合成课表已查看浅色、深色、1.8 倍字号截图（仅 `/tmp/ginkgo-schedule-*.png`，不入库）。保持 34pt 标题、16pt 页边与26pt分组圆角；字体/系统材质仍为 Flutter 近似，未宣称像素一致。真实账号学期切换仍待本机登录，Windows 未验收。

## 2026-10-20：SPOC 真实只读链路

- 已接通 SPA/CAS 完整回调、Token/RoleCode、当前学期/课程上下文、最多100页作业与正文/提交信息详情；全部走 Session 路由。真实入口不再调用 loadDemoHomework，离线演示仍独立保留。
- 列表/详情五分钟快照、账号/路线/登出清空、会话过期单次恢复、失败保留旧结果；正文仅显示纯文本。列表点击推入详情，缺正文/时间/分值明确显示未确认，不推断已提交。希冀与提交/上传仍关闭。
- 4份新增合成详情契约覆盖正常/空/漂移/业务拒绝，contracts router已登记；8项作业Rust测试、契约、Flutter analyze与25项widget通过。Android独立作业smoke含列表/详情/筛选，1项通过。真实上游验收待本机登录，不将合成FFI当作真实数据通过。

## 2026-10-20：博雅课程目录

- BYKC CAS token、随机 AES-ECB/PKCS7、RSA PKCS1 ak/sk、SHA1 与时间戳按 `BykcClient.swift` / `EDUCATION-DATA-MAP.md` §2 迁移；配置学期、课程分页只读接通。五分钟内存快照、失败保留、会话过期单次恢复与登出清理。
- 更多→博雅为独立列表，显示当前学期课程目录、类别与搜索；无选课按钮。正常/空/漂移/业务拒绝合成契约已入 router。Rust协议公钥/加密与缓存测试通过，Android独立smoke 1项通过（合成显示数据；不替代上游验收）。Windows及真实账号仍待验收。

## 2026-10-20：研究生学籍与培养方案执行报告

- GSMIS学籍白名单摘要与培养方案执行报告真实只读接通，报告严格使用 code==1，支持zxbg字符串/数组，逐类别/课组/课程展示要求、已获、待考核及状态；无硬编码类别学分。报告不可用时回退方案头部和课程池并明确提示，课程池不冒充毕业要求。
- 五分钟快照、单次会话恢复、失败保留；敏感学籍字段在Rust投影时丢弃，不进入桥接JSON。更多→研究生教务使用语义色与inset分组，长文字自然换行。4份执行报告合成契约与应用链路/白名单/缓存测试；真实账号与Windows仍待验收，不宣称像素一致。

- 验证：11项研究生相关Rust测试、fixture契约、Clippy、Flutter analyze通过；Android独立graduate_test.dart 1项真实FFI合成smoke通过，包含学籍摘要、报告总览与逐课程状态。

## 2026-10-20：本地待办

- Rust本机文件存储、标题/日期校验、增删改与完成状态；账号由Rust会话确定，散列文件名隔离账号，演示使用独立命名空间。应用支持目录由平台插件提供，写入sync后替换；损坏文件禁止覆盖。手机更多与桌面侧栏均已接入，不联网。
- 4份合成文档契约（正常/空/漂移/无效）、CRUD/账号隔离/损坏保护应用测试通过；Flutter analyze通过。Android独立smoke覆盖新增、编辑、完成、重建页面后读取及删除。无提醒/跨设备同步；Windows未实机验收。

- Android tasks_test.dart 1项本机文件真实FFI smoke已通过；初次构建暴露桥接越过用例访问私有账号方法，已改为SessionService用例；未运行mirror长流程。NDK插件提示28.2，项目Rust仍使用27并编译通过；Android路径插件固定2.2.22以避免额外JNI迁移。

## 2026-10-20：校园通知

- 按API §7.3既有5条证据与CampusNoticesClient迁移公开HTML列表，经Session路由读取、五分钟快照、失败保留。标题/日期/摘要/HTTPS同站原文白名单投影，详情显示摘要并可浏览器打开官网。无已证实空标记，空HTML按结构变化处理，不伪造空通知。
- 4份合成契约（正常/空HTML/漂移/拒绝页面）、公开读取+缓存+失败保留用例通过；Android单项FFI合成smoke覆盖列表到详情，外部浏览器往返仍待人工。镜像真实上游⚠️待验收，Windows未验收。

## 2026-10-20：CGYY教学楼场馆只读

- 公开场馆目录、独立直连SSO/业务Token、MD5签名、按场馆/日期查询时段、最近20条订单真实链路与页面已接入。全程Session显式直连，不改全局路线；GET会话失效最多重建一次；五分钟快照、刷新失败保留实际日期范围。公开目录不依赖登录成功。
- 12份合成契约覆盖场馆/时段/订单正常、空、漂移与业务拒绝；签名对齐Apple固定向量，应用mock覆盖登录→公开场馆→业务登录→时段→订单→缓存/失败保留，校验WebVPN偏好下仍直连。Android cgyy_test.dart独立FFI合成smoke 1项通过；真实账号与Windows仍待验收。
- 预约Token、手机号、参与人及门锁密码不进入桥接投影；没有预约、取消、滑块或其他写入口。桌面仍首次访问才构建，并补齐博雅/研究生/通知/研讨室侧栏入口。

### 本轮最终门禁

- scripts/check-mirror.sh通过：Rust fmt/Clippy、130项lib、1项契约（35类108份样例）、Flutter analyze、25项widget。最后补桌面入口后再次analyze/widget通过。Android NDK27 aarch64 bridge check通过；正常debug APK构建并安装，登录页等待用户本机输入。
- schedule/homework/bykc/graduate/tasks/notices/cgyy各保留一个独立Android设备smoke，本轮均通过；网络模块用合成fixture，待办用真实本机文件，均不冒充真实上游验收。未跑mirror_test.dart已知长流程。课表浅/深/大字号截图只在/tmp。Windows未验收。

### 无账号公开接口探测（2026-10-20）

- macOS host经Rust真实Session/reqwest只读GET：新闻网解析5条，CGYY签名公开场馆解析7个site，通过；只记录条数，未保存正文或网页。此结果仅证明当前网络下公开接口可读，不代表Android真实账号或CGYY登录/时段/订单已验收。临时probe已删除。
- 当前正常Android APK已安装并确认登录页，ginkgo_secure_credentials.xml不存在；本轮没有输入真实凭据。真实账号验收等待用户本机登录。

## 2026-10-20：源码对照、连接修复与体验重设计

### 协议与真实只读

- 固定核对 UBAA `e8a397f` 和 Ginkgo macOS：GSMIS 使用 skjcList 条目 JCFADM 匹配时间；WebVPN 同时映射 Origin/Referer；图书馆用异步锁保护 CAS 登录并在锁内检查 token。显式网关挑战不再被预登录 Cookie 阻止恢复。未改 TLS 信任策略。
- 图书馆认证失败也进入旧快照回退；新增并发登录只交换一次、认证失败保留、网关预登录 Cookie、请求头映射、时间方案层级回归。SPOC 应用用例兼容带来源前缀的详情 ID。
- Android 用户授权只读复验：图书馆场馆→区域→时段→座位、当前预约（确认空），iclass 当天课程，研究生课表（非空，起止时间字段完整），SPOC 列表，BYKC 目录，研究生报告，校园通知，CGYY 订单响应成功。BYKC/报告/订单只检查响应，不声称所有内容已逐字段人工比对。
- SPOC 详情探针错误传入来源命名空间，已补兼容并通过 mock，详情页面本就去前缀；真实详情仍待正确参数复验。CGYY 公开目录探针 kind 错用 sites，正确为 venues；没有把本地 invalidRequest 当上游失败。CGYY 时段仍待验收。
- 结束已退出；Android 保险库 XML 条目数为 0。未落盘真实数据、未截取真实页面、未执行上游写操作。正常主入口 APK 已恢复，等待本机再次登录。

### 界面

- 按完整模块清单重组五个入口与分组侧栏，Tab 各自导航栈；资源聚合页不预先触发所有认证。开发规则示例不再占正式侧栏入口。
- 工作台首屏账户与设置、齿轮、四项任务入口；学业/校园次级服务在同页分组。桌面设置固定底部。设置网络路线移到可换行次级行，避免窄屏溢出。
- 课表范围/视图/搜索分层；当前周日期突出，周条定位选中周；课程稳定多色和起止时间。网格按实际内容宽度选择，支持清单/周视图、明确滑动提示、冲突课程分栏；时间方案冲突不伪造统一作息。大字号优先清单。
- 作业突出课程、截止时间和提交状态，动态语义色；筛选在数据/筛选状态变化时预计算。技术实现说明从设置产品信息中移除。

### 验证

- Rust workspace 134 项 lib + 1 项契约通过，Clippy 无警告；新增来源前缀断言后作业 8 项再次通过。
- Flutter analyze 无问题，27 项 widget 通过；Android schedule_test.dart 单项合成 FFI smoke 通过。未重跑 mirror_test.dart，未宣称其全绿。
- Android NDK 27 aarch64 bridge cargo check 通过；正常应用入口重新构建安装。合成课表浅/深色及1.8倍字号截图仅在 /tmp 查看，未入库。
- Windows 仍未验收；完整模块无障碍、实际桌面交互、内容逐字段人工对照仍待继续。

### 第二次本机登录补验

用户再次登录后，正确上游ID读取 SPOC 详情成功；CGYY venues 目录和 day 当天时段读取成功。首轮探针传参问题已排除，未新增或猜测上游端点。前述“详情/时段待正确参数复验”由本条更新为只读响应已验证；页面往返、内容人工比对与Windows状态仍独立记录。


### Apple 风格组件与信息补齐

- 按用户确认保留周课表默认视图，顶部明确周课表/每日清单/学期/考试（条件展示）；窄屏横滑、可见滚动条、CupertinoButton课程块按压反馈，冲突分栏；大字号自动清单。
- Dart/Cupertino 实现：每 Tab 独立导航、系统分段/搜索/开关/详情推入；内容切换180ms淡入，分组220ms尺寸变化；桌面侧栏140ms悬停/焦点与选中背景，保留首次访问构建；自定义动画遵循减少动态效果。
- 作业增加本地搜索、截止/待确认快捷筛选、未知原始状态、详情发布时间/截止/分值回退与SPOC官网入口；图书馆增加座位编号搜索及只看空闲，本地过滤，不新增网络协议。
- [逐模块 macOS 对照](MIRROR-MACOS-PARITY.md) 明确签到历史、图书馆历史/公共统计、博雅已选/统计、SPOC教师等缺项，不宣称全功能迁移完成。
- 第二次真实会话页面操作：工作台→设置→返回；签到当天课程；课表清单→课程详情→返回；作业→详情→返回，无标准化错误提示。只检查界面状态，不打印或截图真实内容。

最终 `scripts/check-mirror.sh` 通过（134 lib + 1 contract、Clippy、analyze、27 widget）；Android独立schedule smoke更新后1项通过。大字号+减少动态效果检查发现零时长AnimatedSize布局重入，已改为直接跳过动画容器并回归通过；大字号显示方式改为两行选择器。第二次验收结束调用正式signOut返回signedOut，Android保险库XML确认不存在。


## 2026-10-20：课程签到历史日期查询

- 复用 API §7.2 的 `get_stu_course_sched.action` 与 `dateStr`，依据 Swift `loadOnDate`；保留当天入口，新增 bridge `loadCheckinOnDate`，不新增签到写接口。上海日期校验拒绝无效/未来日期，五分钟缓存按日期隔离，恢复仍有界。
- 页面从“历史日期查询”推入，Cupertino 日期滚轮（取消不查询、确定后读取）、前/后一天、日期标题与读取状态。快速切换只接受最后请求；失败保留实际日期结果并明确提示，不把旧日课程冒充新日，不把未签到/无课程推定缺勤。
- 正常/空/结构漂移/业务拒绝沿用既有 `checkin.course_schedule` 四类 fixture，历史没有新响应协议；新应用回归覆盖日期传参/缓存隔离/失效保留/无效输入不联网；一个 widget 覆盖乱序与失败保留。FRB 重新生成，stem保持 `ginkgo_flutter_bridge`。
- 验证：21项签到Rust测试、workspace Clippy、Flutter analyze、28项widget通过。真实历史日期尚未登录验收，先标⚠️；先前当天查询成功不替代本次历史验收。

签到历史设备验证：`checkin_test.dart` 独立Android smoke 1项通过（27秒），覆盖当天→历史→前一天→返回；workspace 135 lib + 1 contract通过。未跑mirror长流程（仅补接口实现以保持analyze通过）。

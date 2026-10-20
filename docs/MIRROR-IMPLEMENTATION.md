# Rust + Flutter 镜像实施与验收

> 2026-10-20 启动；2026-10-20 晚更新真实登录与只读链路。Android 以 iPhone SwiftUI 为视觉参照，Windows 以 macOS SwiftUI 为参照；按模块迁移，每个已迁移用例都要覆盖正常、空态、失败与恢复。完整产品范围见 RUST-FLUTTER-PORT.md。

## 当前边界

已创建 `rust/` Cargo workspace 与 `flutter/` Android/Windows 工程。Rust 核心、生成桥接、Flutter 页面形成真实进程内调用链，不是 Dart 仿造 Rust 返回值。应用启动后先恢复会话：没有已保存账号时进入登录页，也可以显式选择“先看看离线演示”。

认证与会话已经接入 bridge：

- Rust 进程内 Cookie jar、CAS 登录页解析与表单提交、手动重定向与错误分类、UC 激活/会话校验、自动/直连/WebVPN 路由隔离、过期会话单次恢复。
- 平台凭据保险库：Android 使用 Kotlin `CredentialVault` + Android Keystore AES-GCM + 私有 SharedPreferences，由 `JNI_OnLoad` 缓存类引用后从 Rust 调用；Windows 使用 Credential Manager，macOS 使用 Keychain，二者共用 `keyring` 适配。密码不以明文落盘，验证码答案不持久化。
- bridge 暴露 `login` / `restoreSession` / `signOut` / `sessionStatus`；Cookie、凭据和重定向链不进入 Dart。`verifyCredentialStorage` 是设备验收用的合成密钥往返诊断，不读写账号数据。
- 真实只读 bridge：空教室、课表、今天、成绩。每类查询使用 5 分钟进程内快照；刷新失败保留旧结果；确认会话过期时仅静默重登并重试一次。账号切换、登出和路由变化都会清空快照。
- `load_demo_*` 保留为明确的离线演示入口，页面脚注会区分“离线合成样例”和“真实账号只读数据”。

当前可执行的五个页面切片仍是今天、空教室、课表、作业、成绩。今天/空教室/课表/成绩已具备真实只读 use case；作业仍只使用共享合成 fixture，尚未迁移 SPOC token/CAS 与详情。所有真实账号验收都还没有执行，不能把 mock、编译或合成设备测试当作真实上游通过。

## 完成度快照（2026-10-20 晚）

| 能力 | 状态 | 证据 |
| --- | --- | --- |
| Rust workspace、FRB 桥接、Flutter Android/Windows 壳 | 完成 | `scripts/check-mirror.sh` 通过；Android debug APK 构建通过；`mirror.yml` 已入库 |
| 共享契约与 fixture | 16 类、58 份 | Rust runner 递归执行全部 fixture；74 项 lib 测试 + 1 项契约测试通过 |
| 认证核心（Cookie/CAS/UC/WebVPN/恢复） | 完成（mock） | 认证单元/流程/mock HTTP 测试 |
| 真实传输（reqwest + rustls） | 编译与 Android 运行 | macOS 编译、Android aarch64 交叉检查、模拟器真实 FFI |
| 平台凭据保险库 | Android 已实测；Windows/macOS 代码完成 | Android `auth_test.dart` 两次密钥往返通过；Windows 尚未构建/实机 |
| bridge 登录/恢复/登出 | 完成 | `login` / `restoreSession` / `signOut` / `sessionStatus` |
| 空教室真实只读 | 完成（mock，Android 页面回归） | Rust 应用层恢复/缓存测试；完整 `mirror_test.dart` 仍有长流程未收敛 |
| 课表真实只读 | 完成（mock，Android 页面回归） | 门户/学期/周/课程/考试 mock + 快照测试；`schedule_test.dart` |
| 今天真实只读 | 完成（mock，Android 页面回归） | BYXT mock + 快照/恢复测试；`today_test.dart` |
| 成绩真实只读 | 完成（mock，Android 页面回归） | 学期发现 + buaascore mock + 汇总测试；`grades_test.dart` |
| 作业 | 合成切片 | SPOC 分页加密/列表解析；真实来源未接入 |
| Flutter 登录页与会话门禁 | 完成 | 6 项会话 widget 测试；Android 真实登录页启动验收 |
| 真实账号只读验收 | 未执行 | 需要用户单独授权；不得用合成数据代替 |
| Windows 构建与实机 | 未开始 | 只有工程与 CI 入口；keyring Windows 分支未在本机编译 |
| 研究生课表、BYKC、图书馆/研讨室/场馆/通知 | 未开始 | 仅有 BYKC 纯规则与现有文档 |
| 本地待办/设置/账号切换/通知 | 未开始 | 登录页可登出，但没有设置页 |
| 写操作与发布 | 未开始 | — |

### 距离目标还差什么（按阻塞顺序）

1. **真实账号只读验收**：由用户授权后登录一次，验证 CAS→UC、空教室/课表/今天/成绩的真实响应与错误分类；不执行任何预约、签到、选课或写操作。
2. **验证码图片与交互**：当前 bridge 能返回 `captchaId`/`captchaImageUrl`，但 Rust 传输只保留文本响应，Flutter 也还没有图片展示；登录页只显示“需要验证码”的说明和输入框。
3. **Windows/macOS 凭据保险库验收**：Windows 主机构建并验证 Credential Manager 往返；macOS Keychain 在签名/未签名运行下的授权提示需要单独记录。
4. **课表/成绩剩余**：研究生 GSMIS、学期切换 UI、缓存周次刷新与旧快照保留的设备验收。
5. **作业剩余**：SPOC token/CAS 登录链、课程/学期上下文、只读详情；希冀来源继续关闭。
6. **P3 其余模块**：BYKC、图书馆、研讨室、场馆、校园通知（只读优先）。
7. **P4 本地能力**：本地待办、设置、账号切换、缓存清理、通知权限、外链与日志脱敏适配器。
8. **Windows 主机构建与实机验收**；当前没有任何 Windows 通过记录。
9. **视觉与可访问性闭环**：登录页、真实/演示状态的固定视口浅色/深色/大字号截图、TalkBack/VoiceOver、减少动态效果。
10. **写操作**：签到、预约、取消、选课等，逐项协议证据、二次确认、提交后回查与“未知结果不重发”。
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
| 共享契约，含正常/空结果/结构漂移/无效输入 | 16 类 58 份 fixture runner | — | 五个合成切片经过真实 FFI |
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
| 成绩学期发现/解析/汇总 | 6 份成绩 fixture + mock HTTP + 应用层测试 | 成绩页 widget 测试 | `grades_test.dart` 通过 |
| SPOC 分页加密/列表 | 黄金向量 + 契约测试 | 作业页筛选 | `homework_test.dart` 通过（仍为合成） |
| 深色、放大文字、宽屏导航、页面过渡 | — | 外观、菜单语义、导航字体回归 | 深色放大文字流程（旧结果见视觉审查） |
| 真实账号只读 | — | — | 未执行，等待用户授权 |

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
| 图书馆 / 研讨室 / 场馆 / 校园通知 | 未移植 | 优先只读数据与失败分类 |
| 签到 / 本地待办 / 设置 | 未移植 | 区分本地操作与上游写操作 |
| Windows | 工程与 CI 入口已创建 | Windows 主机构建/实测及 macOS 布局对齐 |
| 完整导航外壳 | 手机五 Tab 与桌面侧栏；登录/演示两种入口 | 图书馆/更多、设置与账号切换、视觉与可访问性闭环 |

预约、取消、选课、签到提交继续按 COLLABORATION.md 的独立写操作评审与人工触发规则执行。

## 已知工程限制

- 真实账号登录、空教室/课表/今天/成绩的真实上游验收尚未执行；没有用户授权前不得用任何真实学号或密码做自动化测试。
- 验证码只返回挑战对象；没有图片字节传输、图片展示或刷新，登录页只能提示并允许手动填写验证码。真实风控触发时仍可能无法完成登录。
- 记住密码保存失败不会阻止登录，bridge 返回 `remembered=false`；Flutter 目前没有单独提示用户“已登录但未能保存密码”。
- 快照只在进程内保存 5 分钟，不落盘、不读取 Apple 缓存；进程重启需要重新登录或依赖平台保险库静默恢复。
- 网络运行时和平台保险库在第一次异步 bridge 命令（通常是 `restoreSession`）时懒初始化。不要在 `init_app` 里预创建 `reqwest`/tokio 运行时：Android 实测会卡在启动画面。登录页在冷启动首次显示约需数秒，属于当前已知开销。
- 自动/直连/WebVPN 的路由选择仍固定为 `Automatic`；没有设置页切换入口。遇到访问策略时由 `send_with_fallback` 单次切换到 WebVPN。
- Windows Credential Manager 与 macOS Keychain 分支未在本机完成构建/运行验收；Windows CI 结果必须单独确认。
- macOS Keychain 对未签名开发构建可能弹出授权，不能用“代码已写”替代实机记录。
- 作业仍是合成切片；真实 SPOC token/CAS、课程/学期上下文和详情未迁移。
- 课表当前只迁移本科 BYXT；研究生 GSMIS 返回 `unsupported_portal`（页面提示切换到本科生账号）。
- 空教室完整 `mirror_test.dart` 仍未全绿：查询/详情/排序项通过，校区/日期/缓存长流程在设备测试框架内长时间不收敛；不能宣称五 Tab 外壳下全部通过。
- `verifyCredentialStorage` 是面向设备验收的诊断 bridge 命令，会写入并删除一个调用方提供的合成密钥；它不接受真实账号数据，也不应作为普通用户功能暴露。
- 视觉只完成了外壳、部分页面与登录页的启动检查；真实/演示状态的固定视口、深色、大字号与 TalkBack/VoiceOver 闭环仍未完成。

维护边界、fixture 治理、桥接演进与各层证据要求见 [MIRROR-MAINTENANCE.md](MIRROR-MAINTENANCE.md)。

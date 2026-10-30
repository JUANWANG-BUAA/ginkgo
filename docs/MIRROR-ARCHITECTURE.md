# Rust / Flutter 工程与上游隔离边界

更新：2026-10-29。本文描述当前源码的工程边界；学校协议事实仍以 [API.md](API.md) 为准，公开安装包与真实学校业务验收仍以 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md) 为准。末尾的“后续演进方向”是策略，不代表事项已实现。

## 隔离目标与当前结构

学校的 URL、HTTP 请求、CAS 表单与跳转、Cookie、学校/网关会话恢复、iClass/图书馆/CGYY token、成功码和响应字段解析，全部位于 `ginkgo_upstream`。应用核心不依赖这个 crate；修改学校协议实现时，不需要修改 core 或 Flutter。

这个隔离以业务契约稳定为前提：上游适配器负责将学校的新结构转换为既有业务模型。学校新增了客户端需要展示的新能力时，应显式扩展业务契约与产品界面；不能承诺接口语义任意变化都无需修改应用。

Rust 仍在设备进程内运行，不增加自建 HTTP 后端或中转服务器。

| crate | 职责 | 允许依赖的工程 crate |
| --- | --- | --- |
| `ginkgo_domain` | 纯规则、值类型、按功能拆分的业务端口与有类型的结果 | 无 |
| `ginkgo_core` | `Workspace<U>` 应用命令、博雅目录投影、账号隔离的本地待办 | domain |
| `ginkgo_upstream` | 学校协议、认证、业务 token、HTTP 与响应 codecs、学校查询快照、恢复策略、协议 fixture 测试 | domain |
| `ginkgo_runtime` | 组装 `Workspace<SchoolClient<真实传输, 平台保险库>>`，选择真实/演示适配，处理平台初始化 | core、upstream |
| `ginkgo_flutter_bridge` | FFI DTO 与命令映射、应用命令的读写排他 | core、runtime |

core 与 upstream 的依赖方向是分别指向 domain。`ginkgo_core::auth`、`adapters` 和经 upstream 转出的 `features` 兼容导出已移除；core 的 `features` 只暴露领域模型与纯规则。原先包含协议测试的 application 模块已迁入 upstream 的 `services/`，测试跟随实现迁移。

## 学校实现的维护位置

| 变化 | 实现位置 | 独立验证 |
| --- | --- | --- |
| CAS 登录页、execution、验证码、认证跳转 | `upstream/src/auth/{cas,login,redirect,uc}.rs` | `cargo test -p ginkgo_upstream auth::` |
| Cookie、直连/WebVPN、HTTP 行为 | `upstream/src/auth/session.rs`、`foundation/`、`adapters/reqwest_transport.rs` | auth、foundation、adapter 测试 |
| 学校会话恢复、失败冷却、身份和凭据生命周期 | `upstream/src/services/session_service.rs` | `services::tests::session` |
| iClass、图书馆、CGYY 业务 token 与业务会话 | 各 `upstream/src/services/*_service.rs`、`auth/iclass.rs` | 相应功能的 services 测试 |
| URL、参数、请求头、加密信封、返回成功码 | `upstream/src/adapters/<feature>_http.rs` | adapter 的合成请求/响应测试 |
| 响应字段、数据类型漂移、业务数据投影 | `upstream/src/codecs/<feature>.rs` | codecs 测试及 `upstream/tests/contracts.rs` |
| 官网入口和通知域名策略 | `upstream/src/endpoints.rs` 及通知 codec | URL 白名单与详情元数据回归 |
| 单次会话恢复、请求合并、失败快照回退 | `upstream/src/services/` | 逐功能时序与请求次数断言 |

以上 Cargo 命令在 `rust/` 执行。共享样例仍保存在仓库根目录的 `fixtures/`；协议修正需按 API.md 的证据及修订表维护。不会将未经证实的成功码统一成通用常量。

### 会话与缓存

`SchoolClient` 拥有学校 Cookie 会话、凭据保险库、待续 CAS 表单、账号身份、自动恢复状态和业务 token。`services/snapshots.rs` 拥有学校查询快照；core 不读取或操作其中的锁、token、时间戳和缓存键。

`SessionSource` 只提供登录、恢复、退出、路线偏好、清理查询快照、当前身份等业务操作。公开结果为 `UserProfile`、`SessionStatus`、`SessionOutcome` 和验证码展示信息。`LoginPage`、execution、`Credentials`、`IClassSession`、HTTP 请求与 Cookie 不进入业务端口。

保留原有语义：成功空结果覆盖旧数据；失败保留原值和原抓取时间，不延长 TTL；无旧数据则返回错误；各系统分别处理认证失效与业务拒绝；学校写请求单次提交，结果未知时要求回查，不自动重发。

FFI 的 `SESSION_ACCESS` 用于应用命令级排他，保证切账号、切路线和清理快照等待已经发出的命令结束。签到/图书馆另有功能读写排他。它们只协调应用操作，不包含学校认证字段、token 或恢复算法；学校登录与会话维护实现统一在 upstream。直接消费业务端口的其他宿主也需要协调账号生命周期操作。

## 按功能的稳定业务端口

`ginkgo_domain/src/ports/` 按 session、academic、classroom、checkin、library、bykc、graduate、homework、notices、cgyy、library_stats 拆分接口与结果值。core 的相应功能模块只依赖这些能力。

- `Workspace<U>` 按每个命令所需的 trait 提供方法；一个通知测试只需实现 `NoticeSource`，不需要伪造整套登录、课表或图书馆能力。
- `CheckInSource` / `CheckInMutationSource`、`LibrarySource` / `LibraryMutationSource` 分开。新增读取能力不会要求实现无关写操作，应用层也不增加隐式写重试。
- CGYY 使用 `CgyyQuery` 和 `CgyyData` 区分场馆、日期空档、订单；签到进度使用 `CheckInLoadProgress`，业务端口没有任意 JSON 信封返回值。
- 应用错误与保留的旧数据可以一起跨过接口，维持部分失败和陈旧状态的正确呈现。
- 平台保险库和真实 HTTP 的选择只出现在 runtime；第一次命令才建立实际客户端，保持 Android 启动时的惰性初始化。

上游直接实现这些端口，去掉了“公开固有方法再转调一次 trait”的重复转发。core 不提供取得原始上游客户端或 token 的访问器。

### 新增功能的路径

1. 在 domain 定义产品需要的值类型和单独的功能端口。
2. 在 upstream 添加该功能的 adapter、codec、必要的业务会话状态及端口实现。
3. 在 core 添加对应功能命令或应用规则；通过最小合成端口实现验证业务行为。
4. 在 bridge 添加 DTO/命令映射并重新生成绑定，在 Flutter gateway、native/demo adapter、导航中接入。
5. 上游协议测试归 upstream，应用用例测试归 core，页面测试注入 Flutter gateway。

仅更新已有学校接口时，通常只涉及第 2 步及协议 fixtures。新增功能仍需显式接入端口、命令和导航；当前工程采用静态组装，不宣称具备动态插件加载机制。

## Flutter 与 FFI

`application/contracts.dart` 显式导出生成的值类型，作为字段契约的单一来源。`application/mirror_service.dart` 声明按功能拆分的 gateway，`infrastructure/` 提供 native/demo 与平台适配。页面通过注入接口调用命令，不接触生成函数或 `RustLib`。

本机待办目录通过 `TaskStorageScope` 注入异步路径解析函数：组合入口接入 `infrastructure/task_storage.dart` 的平台实现，工作台和待办页只读取端口；测试可注入合成目录。目录解析失败时页面显示失败，不把失败当作空待办。`shared/reminder_controller.dart` 通过 `ReminderStore` 读写偏好、通过 `ReminderPlatform` 调度，`shared/reminder_scope.dart` 只负责控制器生命周期；`shared/reminders.dart` 仅作兼容导出。提醒刷新按整轮代次丢弃超时前的迟到结果，文件实现保留原账号摘要命名和原子替换，`GinkgoApp` 工作区组合入口注入适配器。

提醒作用域在服务实例或账号变化时隔离控制器代次，取消旧定时器与恢复等待；系统排程适配器串行处理跨控制器的替换和清理，避免旧清理晚于新排程。若平台调用一直不返回，队列不会越过它执行后续排程，以免失序；该情况不等于系统通知已更新。

提醒偏好文件按账号序列化读写，包括同账号控制器替换时已经提交的写入；读取完成前禁止修改，读取失败或损坏时保留文件并提供重试。队列仅协调当前进程，不能据此推断跨进程或设备级持久化验收。

FFI API 只处理应用参数与 DTO 映射。演示中的学校响应构造、fixture 选择和解析也已移入 upstream，通过 runtime 的演示入口访问。全部 89 个命令返回类型化 DTO，通用 `ReadOnlyResponse` 已删除，学校原始信封不得跨桥。CGYY 的 Dart 写调用使用 `application/cgyy_commands.dart` 的 sealed command；native 仅在附加账号与存储元数据后生成既有 JSON 契约，页面不组装裸 Map。

Flutter 中的学校网址常量和新闻域名白名单已收回上游；作业详情通过可空 `sourceUrl` 元数据提供官网入口，通知链接由上游验证后返回。页面只做通用 HTTPS URI 检查，功能导航继续传递同一个注入服务。作业详情 DTO 新增了可空字段，Rust/Dart 绑定需要同步使用；现有页面构造调用无需提供该可选字段。

图书馆分级页面、研究生/博雅展示组件与周次条仍按上一轮拆分维护。上游会话迁移不改变页面导航或真实写入授权流程。

### 渐进呈现与加载状态

工作台使用 `application/refresh_section.dart` 管理课程、作业各自的呈现快照、错误和进行中的任务；完成一个区域即更新该区域。重叠读取加入已有任务，刷新期间保留旧内容，失败后仅重试所选区域。作业列表与工作台共用 `homework_projection.dart` 的个人课程范围，避免助教课程混入摘要。更换服务或账号上下文时丢弃原有状态，迟到结果不能写回新页面；研究生页也按 provider 代次隔离迟到响应。

`loading_widgets.dart` 只负责主题色银杏呼吸、首次淡入、状态文字与桌面刷新快捷键，不包含学校请求或协议规则。动画不生成虚构百分比；关闭动态效果时静态显示，所在标签页的 `TickerMode` 关闭时停止 ticker。

本轮的“流式”指多个既有类型化业务命令分别完成后渐进显示；没有新增 FFI stream、轮询或学校请求协议。底层响应仍按完整业务结果跨过 FFI。暂时只将工作台和研究生页作为样板，其他页面继续按各自已有加载逻辑维护。

大量记录的浏览独立于加载协议：`CollectionWindow` 维护本地有界页与刷新锚点，公共查询工具栏管理搜索/范围/页码入口，页面继续消费原业务结果。座位和空教室已接入；课表横纵滚动控制器保持独立。组件约束、iOS 对照与热更新适用范围见 [MIRROR-INTERACTION.md](MIRROR-INTERACTION.md)。

### 工作区功能登记表

壳层与功能页之间以 `flutter/lib/workspace/workspace_catalog.dart` 为唯一登记点：每个功能登记稳定 id、标题、图标、桌面分组、移动端标签位置与页面构建器。移动端标签、桌面侧栏、今日快捷入口与返回栈都从该表派生，`main.dart` 只保留启动与登录状态机，`workspace_shell.dart` 只负责组合，移动/桌面实现由构建器注入。目录与搜索显式共享 destinations，不通过全局循环引用获取。

登记是编译期静态表：没有运行时插件加载、远程下发或动态符号查找；新增功能仍需显式登记、接入 gateway 并重新构建。桌面侧栏与目的地 key 使用功能 id（如 `desktop-sidebar-grades`），列表顺序调整不再影响测试与深链。`workspace_catalog_test.dart` 固定 id 唯一、移动端标签连续、分组非空与每个功能都有可达入口。

## 自动防回退与测试

`scripts/check-mirror-architecture.py` 与一组边界检查回归已接入 `check-mirror.sh` 和 CI：

- 拒绝 core 对 upstream/runtime 的正常或开发依赖，包括重命名的本地实现包。
- 拒绝 domain/core 引入指定的协议/平台库，以及核心源码接触 HTTP、Cookie、登录表单和学校 URL。
- 拒绝业务端口返回通用 JSON 信封；拒绝 FFI API 自行解析协议和学校 fixture。
- 拒绝 Flutter 页面直接导入 native 绑定、构造 native 服务或通过值契约导出 native 命令。
- 拒绝 Dart 文件级 import/export/part 循环及目录聚合图无法发现的隐式耦合。

本地/CI 分别执行 core 和 upstream 的独立测试，再执行 workspace 全量验证；core 的正常依赖图没有学校客户端、HTTP、平台保险库或 Tokio。core 的异步合成测试使用 Tokio 开发依赖。

独立验证命令：

```sh
cargo test --manifest-path rust/Cargo.toml -p ginkgo_core --no-default-features --locked
cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked
scripts/check-mirror.sh
```

Rust 的核心合成测试验证接口可替换、旧数据/失败一起返回、不确定写入不重发、本地待办根据注入身份隔离账号。上游保留原登录、验证码、学校/网关恢复、业务 token 失效、请求次数、查询缓存和写入回查测试。测试通过不替代真实账号与 Windows 主机验收。

## 后续演进方向（2026-10-29）

> 本节记录架构演进原则，不替代实现状态或待办清单；未完成事项、当前顺序与验收证据统一维护在 [MIRROR-TODO.md](MIRROR-TODO.md)。

目标不是继续增加抽象层，而是让现有模块化单体更可靠、更易验证。Rust 继续在设备进程内运行，保持明确依赖矩阵：domain 无本项目依赖，core 与 upstream 只依赖 domain，runtime 依赖 core 与 upstream，bridge 依赖 core 与 runtime；不引入自建后端或微服务。

1. **先收口正确性，再清结构债。** 按待办中的 P0 → P1 → P2 推进。优先验证认证与账号切换、异步读取上界、迟到响应与缓存语义，以及写操作单次提交和回查；每个问题都用能复现原风险的回归测试锁定，不通过放宽协议断言来消除失败。
2. **渐进收紧跨层契约。** 全部 FFI 命令使用类型化 DTO，不重新引入通用载荷逃生舱；写调用的输入也逐步改为 typed command，不能承载学校原始响应。稳定业务规则归 Rust domain，纯呈现格式留在 Dart；Flutter 页面依赖 application gateway，直接依赖 infrastructure 的旧路径随功能修改逐项收敛，不做全量重写。
3. **用端到端证据推动演进。** 新功能沿用本文件“新增功能的路径”，覆盖 upstream / core / bridge / Flutter gateway 与页面测试；Android 正常入口构建和设备验收单独记录。合成测试、授权真实只读和真实写入分别陈述，不互相替代。若补充诊断日志，先按 [COLLABORATION.md](COLLABORATION.md) 建立脱敏白名单并经人工安全审查。

开发范围仍以 [多平台路线](MULTI-PLATFORM-STRATEGY.md#当前开发范围2026-10-24-决策) 为准：Android 是唯一功能开发目标；Windows 保持可编译；macOS / iOS 冻结。除非出现具体需求和证据，不引入全局状态框架、动态插件系统或大规模跨层重写。

## 性能与精简范围

保留上一轮的固定正则 `LazyLock` 复用、空教室名称排序键预计算、公共结果映射、快照回退抽取及无引用页面清理。本轮进一步移除跨层兼容导出、重复上游接口转发和 FFI 中的协议样例解析。

本轮目标是限制学校变化的传播范围。拆 crate 不代表最终包体下降；未给出未经设备测量的内存、启动时间或端到端提速比例。最新验证证据见 [TESTING.md](TESTING.md)。

# Rust / Flutter 工程与上游隔离边界

更新：2026-10-22。本文描述当前源码的工程边界；学校协议事实仍以 [API.md](API.md) 为准，公开安装包与真实学校业务验收仍以 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md) 为准。

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

FFI API 只处理应用参数与 DTO 映射。演示中的学校响应构造、fixture 选择和解析也已移入 upstream，通过 runtime 的演示入口访问。通用 `ReadOnlyResponse` 仍是与现有 Flutter 兼容的序列化容器，其数据来自有类型的应用结果；这不允许返回学校原始信封。

Flutter 中的学校网址常量和新闻域名白名单已收回上游；作业详情通过可空 `sourceUrl` 元数据提供官网入口，通知链接由上游验证后返回。页面只做通用 HTTPS URI 检查，功能导航继续传递同一个注入服务。作业详情 DTO 新增了可空字段，Rust/Dart 绑定需要同步使用；现有页面构造调用无需提供该可选字段。

图书馆分级页面、研究生/博雅展示组件与周次条仍按上一轮拆分维护。上游会话迁移不改变页面导航或真实写入授权流程。

### 渐进呈现与加载状态

工作台使用 `application/refresh_section.dart` 管理课程、作业各自的呈现快照、错误和进行中的任务；完成一个区域即更新该区域。重叠读取加入已有任务，刷新期间保留旧内容，失败后仅重试所选区域。作业列表与工作台共用 `homework_projection.dart` 的个人课程范围，避免助教课程混入摘要。更换服务或账号上下文时丢弃原有状态，迟到结果不能写回新页面；研究生页也按 provider 代次隔离迟到响应。

`loading_widgets.dart` 只负责主题色银杏呼吸、首次淡入、状态文字与桌面刷新快捷键，不包含学校请求或协议规则。动画不生成虚构百分比；关闭动态效果时静态显示，所在标签页的 `TickerMode` 关闭时停止 ticker。

本轮的“流式”指多个既有类型化业务命令分别完成后渐进显示；没有新增 FFI stream、轮询或学校请求协议。底层响应仍按完整业务结果跨过 FFI。暂时只将工作台和研究生页作为样板，其他页面继续按各自已有加载逻辑维护。

大量记录的浏览独立于加载协议：`CollectionWindow` 维护本地有界页与刷新锚点，公共查询工具栏管理搜索/范围/页码入口，页面继续消费原业务结果。座位和空教室已接入；课表横纵滚动控制器保持独立。组件约束、iOS 对照与热更新适用范围见 [MIRROR-INTERACTION.md](MIRROR-INTERACTION.md)。

## 自动防回退与测试

`scripts/check-mirror-architecture.py` 与 5 项边界检查回归已接入 `check-mirror.sh` 和 CI：

- 拒绝 core 对 upstream/runtime 的正常或开发依赖，包括重命名的本地实现包。
- 拒绝 domain/core 引入指定的协议/平台库，以及核心源码接触 HTTP、Cookie、登录表单和学校 URL。
- 拒绝业务端口返回通用 JSON 信封；拒绝 FFI API 自行解析协议和学校 fixture。
- 拒绝 Flutter 页面直接导入 native 绑定、构造 native 服务或通过值契约导出 native 命令。

本地/CI 分别执行 core 和 upstream 的独立测试，再执行 workspace 全量验证；core 的正常依赖图没有学校客户端、HTTP、平台保险库或 Tokio。core 的异步合成测试使用 Tokio 开发依赖。

独立验证命令：

```sh
cargo test --manifest-path rust/Cargo.toml -p ginkgo_core --no-default-features --locked
cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked
scripts/check-mirror.sh
```

Rust 的核心合成测试验证接口可替换、旧数据/失败一起返回、不确定写入不重发、本地待办根据注入身份隔离账号。上游保留原登录、验证码、学校/网关恢复、业务 token 失效、请求次数、查询缓存和写入回查测试。测试通过不替代真实账号与 Windows 主机验收。

## 性能与精简范围

保留上一轮的固定正则 `LazyLock` 复用、空教室名称排序键预计算、公共结果映射、快照回退抽取及无引用页面清理。本轮进一步移除跨层兼容导出、重复上游接口转发和 FFI 中的协议样例解析。

本轮目标是限制学校变化的传播范围。拆 crate 不代表最终包体下降；未给出未经设备测量的内存、启动时间或端到端提速比例。最新验证证据见 [TESTING.md](TESTING.md)。

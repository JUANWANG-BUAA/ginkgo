# Beta.8 WebVPN 验证码登录源码对照

## 现场与范围

用户报告 Android Beta.8（build 18）选择“仅 WebVPN”，图片可显示，输入验证码点登录后立即显示“学校服务暂时不可用，请稍后重试”。用户同时确认：当前源码构建的 UBAA 与冻结的 macOS Ginkgo，在相同条件下使用验证码、仅 WebVPN 可以登录。这些是用户提供的现场事实，不是代理本轮执行的验收。

本轮遵照用户“不需要测试和验证”的最新指示，只读源码并修改工作树；不执行测试、构建、模拟器、应用启动、真实登录或学校请求。不要求用户重登，不使用真实凭据。本记录不宣称已唯一定位现场根因，也不将参考客户端的成功改称学校链路异常。

用户随后明确要求“直接对齐 UBAA”。以下当前实现以固定 UBAA 为认证主链的唯一行为参考；Beta.3/Swift 仅保留为历史差异说明，不再把它们的取页/表单目标策略混入当前实现。

参考固定为：

- Android 发布源码及冻结 Swift：Ginkgo `2fb79d8f0855d602ab8aaa6ab51477a65b59aed4`；本轮源码修改不在已发布 APK 中。
- 历史认证基线：Beta.3 `32b6a1d6`。
- UBAA：`e8a397fcb35a68147eee65a94c66ffb84e2f09fe`，本地参考工作树无修改。
- HTTP 库：锁定的 reqwest `0.12.28` 及其本地源码；UBAA Android 引擎为 OkHttp，当前依赖为 `5.3.2`。OkHttp 的默认协议列表依据该版本上游 `OkHttpClient.DEFAULT_PROTOCOLS`，不来自本轮连接实测。

## 已定位并修改的额外失败条件

`21f2957e` 在 `auth/uc.rs::activate_uc` 新增：对 UC 激活最终 HTTP 200 正文调用 CAS 的 `extract_error_text`，命中 `errorDiv`、`errors` 或 `tip-text` 就直接返回 `PreLoginTip`，不再执行 UC status。该解析器不判断元素是否隐藏，也不判断这是否为 CAS 表单；页面模板中的非空占位也会触发。

三份可用参考均没有这个额外条件：

- Beta.3 `32b6a1d6`：完成 UC 导航后查询 UC status。
- 冻结 Swift `CasClient.activateUc`：处理状态及跳转，不将 HTTP 200 导航页的 CAS 风格文案视为拒绝；随后 `validateSession` 验证身份。
- 固定 UBAA `LocalAuthServiceBackend.activateUcLogin`：GET 激活入口，随后 `validateLocalConnectionSession` 验证身份；没有在激活正文套用 `LocalCasParser`。

当前工作树移除这项额外检查。随后按用户要求继续对齐 UBAA：UC 激活的最终落地页状态也不替代 UC status，导航结束后仍查询 status；不再因落地页非 200 提前中断。UC 导航也不扫描 CAS 的 `exception.message`；该检查只在 CAS 提交链的最终 URL 进行。传输失败、不安全目标与有界跳转超限仍失败；CAS 最终明确拒绝保留。后续必须 `code == 0`、完整身份与输入账号匹配，不构造身份、不自动重发密码。

这是一处可由源码构造反例的错误拒绝条件，**不是已经证明现场响应包含该 HTML 的结论**。用户没有提供响应，本轮也没有采集；因此不能说它已唯一解释 Beta.8 的现场。

原 `uc_activation_error_body_stops_before_status_even_if_identity_would_validate` 把这项额外策略当成预期。且恢复完整服务票据消费后，其第三个 mock 响应实际由 CAS 服务回调取得，未到 UC 激活；旧断言不能证明 UC 行为正确。现将该测试源码改为直接调用激活与身份验证，分别检查普通/隐藏占位、有/无有效 UC 身份及实际请求 URL；这是依据三份固定参考明确修订预期，不修改 UBAA golden。本轮没有运行它，不声称旧实现已实际失败或新实现已通过。

## 撤回 HTTP/2 猜测性修改

继续比较完整历史后确认：Beta.3 与 Beta.8 的 `Cargo.lock` 相同，reqwest 都只启用 `rustls-tls` 与 `gzip`，均未开启 `http2`；底层执行、正文收取/解码及任务生命周期也没有此次回归所需的变化。HTTP/2 能力差异不能解释“Beta.3 可以而 Beta.8 不可以”。

已撤回此前自行增加的 `http2` feature、五项新增依赖及相关说明，恢复原依赖配置，不再以此作为本次修复。此前生成依赖锁的操作不是测试或构建证据。2026-11-02 的直连 UC HTTP/2 探测也不能代替本次 WebVPN 的因果证据。

## 按用户指示统一采用 UBAA

临时恢复 Safari UA、删除人工 Keep-Alive 的工作树修改已撤销；保持固定 UBAA Android OkHttp 捕获的默认 `ktor-client`、gzip 与 Keep-Alive。对应 loopback 测试、独立比较脚本及变异脚本也撤销临时浏览器策略，原 `ubaa-transport-wire.json` 完全不变，不把引擎默认值称为学校硬性要求。

从固定 `LocalAuthServiceBackend.login` 逐条移植到现有 upstream 边界的主链行为：

1. 验证码作答时先同路线 GET `/login`，响应 Cookie 先导入；优先使用随答案传入的 execution，不由新页覆盖，缺失时才取新页令牌。新页即使没有 execution，也可使用已传入的有效令牌。准备 GET 失败不发密码；GET 发现已有会话时不再发密码。
2. 密码 POST 固定为 `loginUrl()` 对应的逻辑 `/login`，之后由 Session 包装 WebVPN；不采纳页面 action 或其 service/query。验证码仍为原参考的固定八字段，普通表单仍使用原参考字段向量。
3. 密码到期确认取当前请求 URL、移除 query，不读取 form action；只提交新 execution 与确认事件一次。
4. 完整消费重定向/票据，随后 GET UC 激活入口，再 GET UC status。UC 最终导航页的状态和正文都不是身份判据；有效身份/账号匹配仍是 SignedIn 前提。
5. 初始 GET 返回任意 3xx 时，与 UBAA 一样不消费该 Location，也不解析其错误查询，直接激活并验证 UC；缺 Location 不增加失败条件。提交后的 3xx 仍消费完整票据链，两种分支不混淆。
6. CAS 提交链先消费跳转，再确认一次到期提示，最后判最终错误/401/参考字面表单标记；没有明确错误的 204、403、483、5xx 等终态不额外拦截，继续 UC。撤销此前将失败提交响应自动转成新验证码挑战的自定逻辑；下一次人工登录重新 GET。
7. Cookie 发送次序按 UBAA 的存储插入顺序，同名/域/路径替换后按新插入位置排序，不按路径长度重排。host-only、Domain 验证、路径段边界、Secure 与路线/账号隔离不放宽。

这是按固定参考统一实现，不是现场因果证明。本轮没有运行任何检查，也不宣称 Kotlin/reqwest 两种引擎、所有错误分类或 Cookie 策略逐字一致。

## Beta.3 到 Beta.8 的其余登录差异

| 改动 | 引入提交 | 与参考的关系及处置 |
| --- | --- | --- |
| Safari UA 改为 `ktor-client`、强制 Keep-Alive | `5f7b2d1` | 临时 Safari 回退已撤销，当前保持固定 UBAA 捕获的默认值，不再混用 Swift 配置 |
| 认证 GET/POST 加 JSON Accept、表单增加 charset；UC Accept 追加 JSON | `5f7b2d1` | 来自固定 UBAA 工厂默认协商；与 Beta.3/Swift 不同。没有服务端响应证据，不能仅凭这项差异认定拒绝原因，本轮保持 |
| 验证码提交从页面字段改成固定八字段 | `5f7b2d1` | 不再保留额外隐藏字段，但与 UBAA 验证码分支相同；两份可用参考本来不同，没有现场页面不能认定缺必填字段 |
| 密码到期确认从固定 `/login` 改为页面 action/当前 URL，保留 query | `21f2957e` | 当前撤销页面 action/query 策略，按 UBAA 对当前请求 URL 去 query；不假设用户本次必然进入该分支 |
| Cookie 拒绝不匹配 Domain、Max-Age 从响应到达计算 | `5f7b2d1` | 修正作用域/有效期，不以恢复 Beta.3 为由撤回隔离约束 |
| 路线固定、完整消费票据、UC 身份确认 | 多次修订，Beta.8 恢复完整票据链 | 保留，不能以 CAS 302 或输入学号伪造 SignedIn；显式 WebVPN 不走 Automatic 的迁移分支 |

WebVPN 主机编码及登录路径包装未见 Beta.3 到 Beta.8 的对应变化；空路径尾斜杠修正属于业务 Origin/Referer，不能套用来解释 `/login` 或验证码提交。

## 请求与状态机对照

| 环节 | 当前 Rust | 工作参考与结论 |
| --- | --- | --- |
| 验证码作答前取页 | 原路线重新 GET `/login`，保留随答案传入的 execution；响应 Cookie 先导入 | 按 UBAA 的 GET→优先传入 execution→POST 顺序，不沿用 Swift 的直接提交旧页 |
| 验证码表单 | `auth::cas::captcha_login_fields` 固定八字段；两个验证码字段填同一答案，正确编码 execution | 对齐 UBAA `buildCaptchaLoginParameters`；Swift 保留页面可提交字段后覆盖 execution。未发现 Rust 漏掉 UBAA 必填字段的源码证据 |
| 初次密码 POST 目标 | 固定逻辑 `/login`，再由 Session 包装 WebVPN | 对齐 UBAA `post(loginUrl())`，不向页面指定的其他主机发送凭据，不保留 action 上的 query |
| Cookie 作用域 | 按原始网关请求 URL 注入及接收 Cookie，之后才归一化响应 URL；直连与 WebVPN jar 隔离 | 未发现“先解包为 SSO URL 再存网关 Cookie”的实现错误。UBAA 使用按模式隔离的存储；其宽松路径前缀与 Rust 路径段边界的既有差异保留，Swift 也不是简单宽松前缀，不能据此放宽 Cookie 隔离 |
| 服务票据 | CAS 提交后继续逐跳 GET，消费非 CAS 回调；事务固定路线 | 对齐 Beta.3 与 UBAA 的完整票据链；不能为跳过失败而提前宣布登录成功 |
| 密码到期确认 | 当前请求 URL 去 query，忽略 action；只提交新 execution 与确认事件一次 | 对齐 UBAA `stripQuery`，仍只允许 CAS HTTPS 安全目标 |
| UC 成功条件 | 激活后以 UC status 的 code 0、非空身份且账号匹配确认成功 | 不以 CAS 302、Cookie 存在或登录页消失代替身份确认；本轮不放宽 |
| UC 激活落地页 | 不依据最终状态/正文判断身份，继续查询 UC status | 按 UBAA 的 `activateUcLogin`→`validateLocalConnectionSession`，不是遇任意落地页就发布身份 |
| WebVPN 成功后的额外直连密码事务 | 不执行 | UBAA 为 CGYY 建直连 SSO；发生在 WebVPN 已成功之后，不能解释最初的 WebVPN 登录失败，也不应复制额外密码提交 |

明确保留的边界：有界 HTTPS 重定向、有效身份非空及账号匹配、严格 Cookie 域/路径隔离、凭据加密和单次密码提交；不复制为 CGYY 另发直连密码。CAS 最终错误文本仍净化、解码一次并映射本项目类型，错误区域解析仍跳过空占位且支持实体；相对 URL 用既有结构化解析，不能写成任意 HTML/URL 与 Kotlin 逐字等价。此前保留的“初始已有会话额外消费票据”“提交终态非 200 提前失败”“UC 错误查询提前失败”“提交后自动新挑战”均已撤销。

测试源码按新策略同步：严格转录核对准备 GET 的 Cookie 与唯一 POST，新增直连/WebVPN 的验证码→票据→UC 成功转录；原页面复用测试改为核对新 GET 但不覆盖旧 execution；到期测试核对当前路径去 query、忽略恶意 action；UC 测试同时覆盖不同落地状态和有/无有效身份。网关作答使用相同入口，相关队列补入准备 GET。另修正旧 UC 5xx 测试缺失服务回调响应的问题，不依 mock 队列耗尽冒充覆盖。上述只写源码，没有执行结果，新增转录不是独立 Kotlin 捕获。

## 通用错误无法唯一定位失败阶段

Flutter `login_page.dart` 优先显示 `failureDetail`，否则映射类型化错误；本地异常的默认文案与用户提供的“学校服务暂时不可用”不同。该文本若来自默认映射，对应 `ServiceUnavailable`；但没有内部错误码，不能排除服务器原文通过 `failureDetail` 恰好显示同样文本，因此也不能仅凭文案排除 `PreLoginTip`。Rust 中，下列不同原因会收敛为同一个 `ServiceUnavailable`，且多处没有阶段或 HTTP 状态细分：

- `reqwest_transport` 构造请求、读取/解码正文、响应大小限制或任务失败；连接失败与超时另有 NetworkUnreachable 分类。
- 已发布 Beta.8 的 `auth::login` 中 CAS 提交/服务跳转的部分 HTTP 错误；本轮撤销该额外终态 HTTP 拦截，初始 GET 的非 200/3xx 仍失败。
- 已发布 Beta.8 `auth::uc` 的 UC 激活或 status 非 200 响应；当前源码只以 status 响应作身份判断，不再有最终激活页状态提前失败。

因此该文案不能证明“学校停服”，也不能区分 CAS POST、回调、UC 或传输失败；“瞬间”只是用户提供的耗时观察，不足以推出某一个分支。Beta.8 不具备能从这条提示反推出具体失败点的证据。

## 先前离线证据的明确缺口

静态阅读 `scripts/ubaa-reference/src/jvmTest/kotlin/cn/edu/ubaa/api/ReferenceSessionProbeTest.kt` 后确认：

- 三个完整认证请求对照场景为直连票据、直连 UC 不可用、无验证码 WebVPN；没有完整 WebVPN 验证码成功链。
- 初始 CAS GET 即发放合成认证 Cookie；CAS POST mock 不依执行令牌、验证码、Cookie 和路线判定是否允许成功。
- UC 成功由共享 `callbackSeen` 布尔值驱动，不是按路线隔离、经 Cookie 验证的会话。比较捕获请求仍有局部价值，但不能证明服务端状态机真正接受了这些请求。
- 既有 captcha 严格转录中的 `session_protocol_captcha_uses_original_execution_cookie_and_route_once` 以传输失败结束，能限定原令牌、路线和单次提交，不能当作完整成功链的独立参考。
- 本机 socket 对照使用 HTTP/1.1，没有 TLS/ALPN 协商；不能据此宣称与 Android OkHttp 的传输能力完全一致。

历史执行结果保留，但结论不能外推到上述未覆盖路径。本轮源码对照阶段未运行测试、构建或学校请求，未改独立 UBAA golden。用户随后明确要求收尾发包，允许必要的格式化、编译、协议索引同步和产物核验；`cargo check -p ginkgo_upstream --tests --offline --locked` 已成功，只证明主代码和测试源码可编译，没有执行测试用例。Beta.9 的构建/公开结果另记 [发布审计](2026-11-03-beta9-publication.md)，不刷新旧验收为通过，readiness 仍 blocked，真实故障继续作为 P0 保留于唯一 [MIRROR-TODO](../MIRROR-TODO.md)。

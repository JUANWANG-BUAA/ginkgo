# 2026-11-02 校外真实账号认证与 WebVPN 验收

## 范围与隐私

账号本人提供凭据并要求真实全功能、全视觉测试。测试仅覆盖登录和学校只读路径；未提交签到、预约、取消、作业或其他学校写操作。使用独立 API 37 ARM64 AVD，凭据只经一次性 loopback 通道进入真实登录表单，不写入仓库、命令行、构建参数或聚合报告。含账号画面的临时 PNG 已删除；报告只保留阶段、耗时和通用错误类别。

## 网络事实

- 宿主与 Android 浏览器均可打开 SSO 登录页；宿主请求返回 HTTP 200。
- 宿主和 Android 浏览器访问 `https://uc.buaa.edu.cn/api/uc/status` 均复现 HTTP/2 协议错误；Android 显示 `ERR_HTTP2_PROTOCOL_ERROR`，宿主 curl 报告 HTTP/2 stream 未正常关闭。不能把该阶段的失败描述成密码错误。
- WebVPN 首页可返回 302 到 `/login`。专用 AVD 最初有 IPv6 连通性异常，关闭 Wi-Fi 后模拟移动网络的 SSO IPv4 ping 恢复；这只属于本机模拟器环境修正，不是放宽 TLS 或学校认证策略。

## 登录结果

1. 自动路线首次在约 13.6 秒后显示网络不可达，未建立会话；没有自动重试密码。
2. 修正模拟器网络后，自动路线取得一次图形验证码并只提交一次答案，约 87 秒后仍显示网络不可达。同期浏览器和宿主的 UC HTTP/2 错误提示存在链路异常，但未取得应用请求级关联证据，不能确认它就是本次失败原因，也不能据此判断凭据是否有效。
3. 显式 WebVPN 的一次早期运行中，截图仍显示“自动”，且脚本未检查 `setRoute` 返回值，证据不足，已废弃其路线归因。
4. 修正验收脚本后，`setRoute(webVpn)` 无失败，登录页截图明确显示“仅 WebVPN”，新验证码只提交一次；约 67.6 秒后应用显示“账号或密码错误”。未保留上游拒绝正文，且客户端对登录表单重显存在统一映射，不能把应用提示写成学校明确拒绝。此前另一次新挑战也显示该提示，随后停止真实登录。

各次 `finally` 均确认本地退出成功。受保护模块读取和真实数据页面未开始，不能宣称真实全功能或全视觉验收通过。

## 验收管线修正

`live_acceptance_test.dart` 现在对强制路线检查 `setRoute` 失败值，并把同一临时路线偏好注入登录页。Rust 退出状态的 `SessionResponse.route` 固定为 `null`，不能用于证明实际路线；页面偏好、Rust 路线和截图必须分别核对。修正后的文件通过 `flutter analyze integration_test/live_acceptance_test.dart`。

## 后续边界

真实账号所有者需先人工确认凭据及学校验证码流程，才能继续受保护只读和真实数据视觉验收。当前工作树的离线全页面视觉证据另记，不能替代本文件的真实认证结果。未执行任何学校写入，未保存密码，未提高发布门禁或发布 APK。


## 用户再次授权的 WebVPN 登录复核

2026-11-02 晚，按用户“请你测试 webvpn 登录的情况”的新指令，在 `GinkgoLiveReadOnly20261102` / `emulator-5580` 以当前工作树构建真实 Rust bridge 集成入口。`GINKGO_LIVE_WEBVPN=true` 设置路线且检查无失败；登录页截图明确显示“仅 WebVPN”，记住密码关闭。新图形验证码可以获取、显示及填写，答案仅提交一次；总耗时 68178ms 后，`signedIn=false`，应用显示“账号或密码错误，请检查后重试”，测试按未建立会话失败。未自动重试，不读取课表、成绩等业务模块，不执行学校写入。

本次没有采集上游认证响应正文或请求级阶段跟踪。代码复核发现 `auth/login.rs` 在响应含 execution、无可检测验证码配置时直接返回 `InvalidCredentials`；因此本次证据无法区分真实凭据拒绝、验证码未通过或页面分类问题，不能宣称密码错误，也不能宣称 WebVPN 登录已修好。后续需要脱敏的阶段诊断及官方页面对照，避免继续用真实密码试探。

新增 `GINKGO_LIVE_AUTH_ONLY=true` 使验收成功登录后立即进入 finally 清理，不再继续遍历模块；失败时也不再额外探测新验证码。finally 确认退出和后续恢复均为 signedOut，未保存密码。临时凭据接收进程、adb reverse、含账号截图及临时报告均已清理；凭据只通过隐藏终端输入和一次性 loopback 内存交付。集成测试包随后用正常 main 入口 Debug 重建，未发包。


## 追加：官方匿名入口对照与宿主 Rust 阶段测试

按用户“请你继续测试为什么 webvpn 不行”的指令，使用当前工作树 `46f5f7f` 的 Rust `ReqwestTransport`、`Session(WebVpn)`、`fetch_login_page` / `complete_login` 做认证专用测试。环境为宿主 macOS，用户报告校园网连接代理；未改变系统代理、TLS、路由配置。此证据不代替 Android 模拟器或物理设备结果。

匿名 GET 对照（Cookie 仅在各自内存 jar）：

- 官方 `https://d.buaa.edu.cn/login` 返回 302 到 CAS 登录地址，带 service；随后返回 200，含 execution，未检测到验证码配置。
- 应用逻辑入口是没有 service 的 CAS /login，通过 d 网关代理；返回 200，含 execution 和验证码配置。
- UBAA 固定提交 `155e8b56ae76348e67c70414e3a9ab7fa54f2dda` 的 `LocalConnectionAuth.kt::loginUrl` 同样代理 CAS /login，并非先打开官方网关入口。因此两种入口的差异尚不足以认定本项目路由错误，不据此改写认证路线。

随后只提交一次真实密码和一次人工读取的验证码答案，无自动重试：

| 阶段 | HTTP / 结果 | 耗时 | 脱敏结构 |
| --- | --- | --- | --- |
| 经 WebVPN 获取 CAS 登录页 | 200 | 3248ms | execution=true，captcha=true，无已知错误文本 |
| 同一 Session 获取验证码图片 | 200 | 500ms | 请求携带 Cookie，PNG/JPEG 图片通过魔数检查 |
| 经 WebVPN 提交 CAS 表单 | 401 | 666ms | 请求携带 Cookie；响应含 execution、新验证码配置和非空错误提示 |
| Rust 结果 | PreLoginTip | — | 未进入 UC 激活/身份校验，无 SignedIn |

诊断输出只记录阶段枚举、状态、耗时、结构布尔值和固定错误类别。该次错误提示归于 `other_tip`：未命中有限的两个凭据拒绝原文，亦未含“验证码”关键词；没有保留提示原文，故无法区分其他账号状态提示、其他措辞的凭据拒绝等具体原因。验证码答案正确性也没有独立证明。不能据此宣称密码错误、网关不可达、UC 故障或已修复真实拒绝。本次响应形状与 CAS 一致，但未获得网关内部证据，不断言 401 的内部生成节点。

此次明确排除“当前宿主完全无法打开 WebVPN”，并把本次失败定位到凭据 POST 阶段；此前 Android 耗时约 68 秒的失败仍缺少同等级请求关联证据，不能视为完全同因。后续诊断必须先准备不泄露个人信息的提示分类/人工复核方式，再决定是否需要一次新尝试；当前不继续重复密码请求。

测试结束清空内存 Cookie；未写平台保险库，未读取受保护业务、未执行学校写入。临时诊断源文件及验证码图片已删除；保留的匿名报告无 Cookie、execution、完整跳转参数或凭据。下一次发包仍阻断。


## 用户要求持续推进后的 UBAA 逐项对照

参考固定提交仍为 `155e8b56ae76348e67c70414e3a9ab7fa54f2dda`，本轮只读副本 `/tmp/ginkgo-webvpn-ubaa-review`，没有运行 UBAA App 或向其统计/中转服务发送凭据。源码可见一条实现链，不是“该账号今天在同一网络用 UBAA WebVPN 成功”的实验证据。

| 环节 | 固定 UBAA 实现 | Ginkgo / 本轮结论 |
| --- | --- | --- |
| 模式与入口 | `ConnectionRuntime.availableModes` 当前本地平台只开放 DIRECT/WEBVPN；`LocalConnectionAuth::loginUrl` 在 WEBVPN 下代理 CAS /login，不先打开网关首页 | 相同入口策略；遗留 SERVER_RELAY 后端虽仍存在，不能将其 `/api/v1/auth/*` 当学校接口，亦不能假定用户成功依靠中转 |
| 网关编码 | `LocalWebVpnSupport`：公开 AES-CFB 主机编码、保留 query/fragment/端口 | 本项目同类路由；当前登录页与图片均返回 200，不因“官方入口带 service”就贸然切换路线 |
| 验证码表单 | `buildCaptchaLoginParameters` 固定 username/password/captcha/captchaResponse/execution/_eventId/submit/type 八字段 | 本次用同一实际页面、替换合成用户名/密码/答案后，对两种构造结果的字段/值多重集合比较为 true；忽略字段顺序，不比较 HTTP/TLS 全链，也不证明真实凭据或验证码正确 |
| 验证码上下文 | UBAA 提交前再次 GET 页面，可沿用传入 execution；新客户端共享路线 CookieStore | Ginkgo 保留当前挑战原表单和 execution，通过同一 Session 取图/POST；不照搬额外 GET，避免潜在刷新挑战 |
| Cookie | `PersistentLocalCookieStorage` 按 ConnectionMode 保存，按 domain/path/secure 发送；不同 Ktor client 共享存储 | Ginkgo 按路线隔离 jar，同一 Session 图片与 POST 均携带 Cookie；这里只证明存在，尚未证明网关内部接受每项 Cookie；不照搬较宽松 domain/path 匹配或明文持久化 |
| 拒绝解析 | `findLoginError` 识别 div#errorDiv、div/p/span.errors 和 tip-text；401 也会失败 | 发现 Ginkgo 缺 p.errors 且空占位可遮蔽后续错误，已补回归并修正；不将“返回 UC 有效身份”覆盖明确拒绝 |
| 成功证明 | `activateUcLogin` 后 `validateLocalConnectionSession` 要求 UC code=0 和 user | 本项目还要求有效身份匹配输入账号；本次 401 前已停止，未到此环节 |
| 成功后 CGYY | WEBVPN 登录成功后尝试建立额外直连 SSO | 不可能解释当前 WebVPN 首次登录 POST 的 401；不为排查而自动再发一次密码 |
| 网络栈 | Android 使用 Ktor OkHttp；本地客户端无此处显式 Safari UA 配置 | Ginkgo 为 Reqwest/rustls，配置 Safari UA。属于仍未做控制实验的变量，不据此更换 TLS 或伪称已确认风控 |

源码定位：[LocalConnectionAuth.kt](https://github.com/BUAASubnet/UBAA/blob/155e8b56ae76348e67c70414e3a9ab7fa54f2dda/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalConnectionAuth.kt)、[LocalWebVpnSupport.kt](https://github.com/BUAASubnet/UBAA/blob/155e8b56ae76348e67c70414e3a9ab7fa54f2dda/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalWebVpnSupport.kt)、[ConnectionRuntime.kt](https://github.com/BUAASubnet/UBAA/blob/155e8b56ae76348e67c70414e3a9ab7fa54f2dda/shared/src/commonMain/kotlin/cn/edu/ubaa/api/ConnectionRuntime.kt)。

### 本轮唯一一次新密码提交

使用新增显式宿主认证诊断工具，当前库认证实现为 `07727dd`，仅诊断 wrapper 在工作树新增；学校账号沿用用户授权，凭据经隐藏终端输入/匿名管道传递，未写文件/命令行参数/环境变量/平台保险库。只人工填写一次图片答案，无自动重试，无业务模块查询或学校写操作。

| 阶段 | 状态 / 时间 | 固定元数据 |
| --- | --- | --- |
| WebVPN CAS 登录页 GET | 200 / 2798ms | execution=true，captcha=true，Set-Cookie 数量 3 |
| UBAA 表单比较 | true | 与上述八字段/值多重集合一致，使用合成凭据替代实际值 |
| 验证码图片 GET | 200 / 740ms | Cookie 存在，无 Set-Cookie，图片魔数通过 |
| 登录 POST | 401 / 1176ms | Cookie 存在，无 Set-Cookie；execution=false，captcha=false，error_present=true |
| 登录结果 | PreLoginTip | 未发布身份，未到 UC；内存 Cookie 已清空 |

此次诊断初版只有中文关键词，非空提示未命中，错误原文未保留，故不能确定其语言或具体原因；与上一轮含新表单的 401 结构也不同，不能当作同一拒绝。该诊断盲点已补中英固定标签及 `unclassified_tip` 标记、隐私回归；标签未命中保持未知，不继续用真实密码试探。不能宣称字段对齐补丁、p.errors 修复或换 UA 能解决此次实网拒绝。下一步有效证据仍是经过隐私处理的具体学校提示/同环境 UBAA WebVPN 成功对照；不以更多相同失败尝试替代它。

### 复跑方式与数据边界

先构建非生产 example：

```sh
cargo build --manifest-path rust/Cargo.toml -p ginkgo_upstream --example auth_stage_probe --features network --locked
GINKGO_MANUAL_LIVE_NETWORK=1 rust/target/debug/examples/auth_stage_probe --webvpn
```

以上默认仅 GET，不接收真实凭据、不发密码。真实认证须明确加 `--submit`，标准输入为匿名管道中的三行（账号、密码、验证码答案），禁止将值写入脚本、命令行、环境或普通文件；调用方应通过隐藏交互读取。验证码图片仅显式 `--captcha-file <绝对路径>` 时以 create_new 临时写入（Unix 0600），正常结束/180 秒超时删除；强制终止时维护者须清理。此次临时图片已删除，保留报告仅白名单元数据 `/tmp/ginkgo-stage-current-metadata.jsonl`。工具默认 Direct；必须传 `--webvpn` 才是本表路线，不使用自动回退。主 App 不调用该工具。

诊断只输出固定阶段、HTTP 状态、耗时、错误关键词标签、Cookie 数量/存在及表单布尔值，拒绝正文、URL/参数、Cookie、execution 和身份不进入输出。标签不用于产品凭据错误分类。三个合成测试覆盖隐私哨兵、大小写英文与未知提示、八字段比较对额外隐藏字段/类型漂移的识别。未完成物理设备、Android 关联阶段或真实成功登录；发布继续 blocked。


## 追加：宿主隧道路由的实时核查

用户询问是否由本设备及代理导致。本轮只读核查，不提交密码、不修改系统代理/隧道/路由。环境变量未检测到 HTTP/HTTPS/ALL_PROXY/NO_PROXY，macOS 系统 HTTP、HTTPS、SOCKS 和 PAC 代理均未启用；这些事实不能排除 TUN 层接管。

对 CAS /login 与 WebVPN /login 分别执行匿名 curl GET，指定 `--noproxy '*'`、连接超时 6 秒/总超时 12 秒，并分别使用默认协议协商及强制 HTTP/1.1。四次请求均 curl exit=28，耗时约 6 秒，HTTP status=0，尚未取得响应。解析目标地址和实际连接目标的路由均显示 `utun5`，没有输出或保留具体 IP。连接未完成时的 TLS 校验状态不作为证书失败证据。

结论：当前学校请求仍经过虚拟隧道，`--noproxy` 没有绕过它；本次环境确实不能当作纯校园直连基线。尚未确认 utun5 所属应用，不能仅凭接口名认定是哪款代理。此前真实 POST 已返回 401，而本次匿名请求在获得 HTTP 响应前超时，两者不同，不将当前隧道问题直接回溯为所有历史认证失败原因。有效对照应保持设备/候选不变，在明确退出代理 TUN 后先验证匿名入口，再决定是否进行一次受控认证；另以 Android 物理设备独立网络隔离宿主/模拟器因素。尚未执行该对照，不宣称关闭代理即可修复登录或允许发布。

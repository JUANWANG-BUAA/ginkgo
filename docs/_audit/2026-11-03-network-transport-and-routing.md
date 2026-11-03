# 网络传输与自动业务选路修复（2026-11-03）

发布后源码修订：用户指定认证主链直接采用固定 UBAA，临时 Safari/连接头回退已撤销，默认传输配置与本记录一致；验证码、固定 POST 目标、到期确认和 UC 导航策略另有源码修改。独立捕获不改，不能沿用下述历史结果宣称当前通过或现场原因已锁定；本轮按用户要求未执行检查，见[源码对照](2026-11-03-webvpn-captcha-source-comparison.md)。

本轮获准继续修复并执行本地合成测试。没有使用真实凭据、访问学校、启动应用/模拟器或执行学校写入。公开 Maven/Gradle 依赖只在准备阶段解析；UBAA 执行阶段使用 offline + macOS sandbox，仅允许本机网络。

## 当前改动与已确认缺陷

### 自动业务选路

修复前严格转录测试实际返回 NetworkUnreachable，无法采用目标路线已有效的同账号会话。现在保留 Automatic 偏好与已认证实际路线的区别：

- 仅安全业务 GET 的网络不可达/访问策略拒绝触发一次候选路线验证；SSO/UC、含服务票据的 GET 和 POST 排除。
- WebVPN UC 校验在 Cookie 副本进行。确认同一账号、认证代次和路线未变化后，才提交 Cookie 与实际路线，清理旧 iClass/图书馆 token/GSMIS 来源记忆并保存快照。
- 并发直连失败共享一次目标验证；失败冷却 60 秒。账号/路线变更与迟到响应按代次拒绝，迟到 Set-Cookie 不写回；失败验证的 Cookie 副本不导入。
- 目标未认证、身份不符、503、结构变化和网络错误均保留原身份。该入口不读取密码、不调用 CAS 登录；目标尚无有效网关会话时需用户显式选择 WebVPN 后登录。它没有承诺新直连会话能凭空取得 WebVPN 身份。
- 显式 Direct/WebVPN 不自动迁移；学校写入和未知提交不重放。界面诊断不再绝对声称模块认证失败永远不需要重新登录，改为提示检查账号连接路线。

新增完整签到回归在入口、app login、首次课程读取及已缓存业务会话四个位置分别注入直连不可达。修复前实际捕获旧 `phone=direct-login` 被重放到 WebVPN app login，和预期重新进入 SSO 入口不符；现返回内部路线变更信号，由签到编排至多重建一次业务认证，不携带旧 sessionId/loginName。目标 UC 过期且保险库有合成密码的完整签到回归只允许两次 GET，不发 CAS 密码请求。对应红灯日志 `/tmp/ginkgo-route-module-before.log`。

这是客户端策略，区别于 Beta.3 先修改共享路线后再建立网关会话，也区别于固定 UBAA 的显式连接模式；不称为两者逐字一致。原历史标签输入/断言保留，当前工作树允许在目标 UC 同账号验证后回退。完整签到历史探针的网关入口是故意不完整 HTML，当前到达入口后正确报 ChangedResponse，不伪造签到成功。

### Cookie Domain 与有效期

1. **不匹配 Domain 被错误发回**：旧 CookieJar 遇到 `Domain=other.invalid` 时忽略该属性并退成主机 Cookie。本机真实 HTTP 回归实际看到 `bad=wrong-domain` 被发回来源；UBAA 不发回它。当前直接拒绝该 Cookie。
2. **请求耗时消耗 Max-Age**：旧 Session 在发送前记录时间，并用于响应 Cookie 的有效期。本机服务器延迟 250ms，再返回 Max-Age=1 秒；旧实现到响应后第 900ms 已丢 Cookie，回归实际失败。当前从响应到达计算，和固定 UBAA 的存储时刻一致。
3. **Cookie 头归会话所有**：移除调用方提供的任意大小写 Cookie，再按当前隔离 jar 注入，防止大小写变体混入其他会话。变异测试恢复旧行为检查检出情况。

这些是已复现的条件性源码缺陷。没有用户设备对应的 Set-Cookie/时序证据，不把它们写成真实掉线的唯一原因。

## 参考平台与真实 socket 证据

固定参考为 UBAA `e8a397fcb35a68147eee65a94c66ffb84e2f09fe`。仍未确认该提交与用户在用安装包的对应关系。

`ReferenceTransportProbeTest` 调用原文私有 `buildLocalUpstreamClient`、原 `PersistentLocalCookieStorage`，使用两种真实引擎连接 IPv4 HTTP loopback：

- JVM 原 `ApiClient.jvm.kt::getDefaultEngine` 使用 CIO。
- Android 原 `ApiClient.android.kt:6` 使用 OkHttp；本轮在 JVM 执行同版本 Ktor OkHttp 引擎。这覆盖请求/Cookie 行为，不覆盖 Android OS TLS/Keystore/JNI。

17 个共同输入场景覆盖重复 query/form、加号/斜杠/中文表单编码、多 Set-Cookie、路径/删除/过期/轮换/Secure、GET 和 POST 的 302/303/307/308 不自动跟随、UTF-8 与二进制响应、模块显式 User-Agent。采集本机服务器收到的实际方法、request-target、HTTP 版本、全部请求头和原始 body 的 Base64，并比较状态、正文 bytes、Location 与 Set-Cookie。

仅规范化本机随机端口、头名和 Cookie 顺序。请求头白名单不用于静默忽略差异。

- 初始 CIO 对照捕获 48 处字段差异（默认 UA、gzip、错误 Domain）；记录 `2026-11-03-transport-wire-before.json`。CIO 不是 Android 参考引擎，gzip 差异不能直接定为产品 bug。
- 进一步原 Android OkHttp 对照确认：默认 UA 为 `ktor-client`，引擎添加 gzip 和 `Connection: Keep-Alive`。中间配置的 35 处差异见 `2026-11-03-android-transport-wire-before.json`；这是中间工作树，不是公开 Beta.7 的逐字产物对照。
- 当前 reqwest 对齐 Android OkHttp 的默认 UA/gzip/连接头，保留模块显式 UA；连接/请求/读取超时按原工厂为 10/30/30 秒。禁止 reqwest 隐式重试；TLS 验证、证书宿主范围和匿名隔离未放宽。
- 明确保留一处 Cookie 路径策略差异：固定 UBAA `PersistentLocalCookieStorage::pathMatches` 的前缀规则会将 `/cookies` Cookie 发到 `/cookies-other`；Rust 要求路径段边界，不发这条 Cookie。golden 与比较脚本精确列出这一个 case/字段/双方值，任何其他差异或这条规则消失均失败。该项仍需人工安全审查；`full_parity=false`。

独立 golden `ubaa-transport-wire.json` 来自实际 Kotlin/OkHttp 捕获，常规 Rust 测试只读；它不由当前实现自动重写。额外原生 socket 回归覆盖请求超时、Future 取消后 socket 关闭、Content-Length/chunked 超限、正文截断、丢失响应 POST 单次提交，以及上述 Cookie 响应时刻。超时/取消测试使用缩短的测试 deadline，执行同一生产 builder/execute/AbortOnDrop 链路。

## 非空签到与历史对照

原有六个业务 golden 场景逐项保持不变；实际 Kotlin 结果核对后增加直连/WebVPN 非空签到，共八场景、双方各 22 请求。新输入有两门课，包含字符串 STATUS、整数/字符串 signStatus；对齐 ID、名称、开始、结束、签到状态五字段。输入字段来自原 UBAA 测试，不访问学校，不扩展为任意业务/DTO 完全相等。

新旧 Kotlin 原客户端结果、Rust 请求和明确策略差异保存在 `2026-11-03-network-reference-evidence.json`。历史 Beta.3–7 仍用原标签源码执行，其失败矩阵与旧证据保留；当前自动回退新增同账号 UC 验证阶段，不通过修改旧标签输入制造一致。

## 本轮检查

交接后的续跑已完成；前次被中断的日志不作为完整通过证据。

- `check-ubaa-reference.py`：退出 0。固定参考的 31 项原测试与探针通过；八个业务读取场景、双方各 22 请求在比较范围内零字段差异。实际 Android OkHttp-on-JVM/reqwest 的 17 个 loopback 场景无未解释差异，仅保留上述 Cookie 路径策略差异；两种引擎采集与历史标签探针执行完成。生成结果已保存到 `2026-11-03-network-reference-evidence.json`，日志为 `/tmp/ginkgo-resume-reference.log`。
- `CARGO_NET_OFFLINE=true bash scripts/check-mirror.sh`：退出 0。架构、文档、协议锁、格式、严格 Clippy、core/upstream/workspace 测试通过；18 种能编译的错误变体全部被回归检出；Flutter analyze、761 项单元/widget 测试及 FRB 再生成零漂移通过。日志为 `/tmp/ginkgo-resume-mirror.log`。
- 交接续跑阶段尚未重新构建候选 APK。`2026-11-03-session-candidate-artifact.json` 记录的是此前候选，早于本轮网络修改，不能作为当前源码的产物证据。后续新候选见文末；两个产物的元数据分别保留。

未完成边界统一在 MIRROR-TODO。完整认证/Cookie 分支、Android 系统网络与安全存储、设备真实学校业务以及人工安全审查不由上述本机 HTTP 结果替代。未提交或发布，readiness 保持 blocked。

## 验证器自身复核与候选交付边界

用户追加要求验证不得省略，并说明开发机反复真实登录可能触发账号风控。后续继续禁止真实账号及学校请求；离线检查后先交付本地可安装候选，由用户手动实机验证。不将候选交付写成公开发布或真实验收通过。

本轮复核实际发现并收紧三处验证漏洞，未改变应用协议实现或原 UBAA 预期：

1. 历史执行原先只检查观察条数、失败名称及是否出现结果摘要，没有严格检查 cargo 退出状态与通过/失败/忽略计数。现精确核对场景名称、唯一性、完整摘要和退出码；被终止、零测试、漏测、重复观察或意外失败均拒绝通过。
2. UBAA 认证阶段对照原先打印当前工作树的 `DIFFER` 后仍可能退出 0。现当前工作树的两个阶段场景必须与原客户端的结果及有序请求阶段相等；历史标签的已知差异仍独立报告，不改写参考。
3. 双方采集同时删去业务场景原先可能通过。现要求固定八个业务场景完整、有序且唯一；HTTP 请求采集也必须覆盖共同输入的全部场景。

`scripts/check-session-verifiers-test.py` 提供反例自测，检查上述判定器拒绝删场景、改顺序、伪造摘要和异常退出等情况；已接入本地基线与 CI。该自测验证的是判定器，不替代真实 Kotlin/Rust 执行。

新增历史共同输入 `gateway_mismatch`：直连 UC 返回合成账号 sy2501001，网关 UC 返回另一个合成账号 sy2501002。要求业务回退失败且不发送网关业务请求、不修改原路线、不增加密码提交。这个新边界用于检查 Beta.3 本身的不足；原有三个公共场景与冷恢复场景保持原输入及断言。

本轮加严后实际执行结果：

- 验证器反例自测 7 项通过，已随完整门禁执行。
- 独立 UBAA 对照退出 0：31 项原测试与探针、八个业务场景、17 个实际 HTTP 请求场景及历史矩阵全部完成；当前认证阶段差异改为强制失败后仍通过。仅保留上述 Cookie 路径策略差异。日志 `/tmp/ginkgo-verifier-audit-reference.log`，合成 JSON 已更新。
- 历史矩阵单独保存逐版本请求及失败位置，退出 0；新增边界在 Beta.3/5/6/7 实际失败，Beta.4 不发送目标业务请求，当前工作树七个场景全部通过。见 [历史追加](2026-11-03-beta-history-offline-reproduction.md#追加验证器复核与-beta3-身份边界) 和 [原始合成输出](2026-11-03-history-verifier-evidence.txt)。
- 完整门禁首次因验证器源码变化被协议锁拒绝；核对本轮只加强判定条件、未修改应用协议后刷新锁，未变更 readiness。重跑 `CARGO_NET_OFFLINE=true bash scripts/check-mirror.sh` 退出 0：文档/架构/格式/严格 Clippy、Rust 分层与 workspace、18 种编译成功的错误变体、Flutter analyze、761 项 Flutter 测试、FRB 再生成零漂移全部通过。日志 `/tmp/ginkgo-verifier-audit-mirror.log`。

本轮仅收紧已说明的验证器漏洞并补充目标身份边界，不能称为所有 Beta.4–7 用户故障都已复现、任意协议输入均正确或设备验收完成。真实账号及学校请求保持暂停。

## 本地签名候选

本轮正常入口 Release 构建退出 0。完整门禁中的 Flutter 阶段在初次构建后重新生成了含 integration_test 的工作区注册表，产物归档前核对因此拒绝；门禁结束后再次用 `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub` 构建，确认生产注册表无测试插件后才归档。初次和最终 APK 摘要相同，未将工作区注册表变化推断为已打包 APK 错误。

- 路径：`flutter/build/network-candidate/Ginkgo-network-candidate-2026-11-03-arm64.apk`，44,282,189 bytes。
- SHA-256：`98fd60a5764cb70bcbb83150879000c4d0d76712e663169fd5b65809822df6af`。
- ARM64、非 debuggable、正常 main 入口、16KB zipalign 和签名验证通过。证书与既有 Beta.7 记录一致；包内 Rust 库与本次 stripped 构建产物摘要一致。
- 版本仍为 `0.1.0-beta.7+17`，这是包含工作树修复的本地候选，不是已公开 Beta.7 的同一产物，也没有创建新 Release。源码、协议契约、APK 与原生库摘要见 [候选元数据](2026-11-03-network-candidate-artifact.json)。

未安装、启动、使用真实账号、请求学校或执行写入；由用户手动实机验证。尚未完成的验收仍保留在唯一 MIRROR-TODO 和原 readiness，不能以本地候选交付解除公开发布阻断。

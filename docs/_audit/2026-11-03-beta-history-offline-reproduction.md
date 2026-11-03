# Beta.3 至 Beta.7 会话离线复现（2026-11-03）

## 范围和方法

本文前半部分保留早期执行时的观察；自动选路后续已有修复，当前结果见文末追加及[网络审计](2026-11-03-network-transport-and-routing.md)。不要将早期“当前工作树”的限制当成最新实现结论。

用户授权不使用真实账号的测试，要求解释 Beta.4 之后的失效。本次没有访问学校或使用真实凭据，也没有启动应用、模拟器或设备。`python3 scripts/check-history-session-probes.py` 从本地 Git 标签提取各版 Rust 源码与 fixture 到临时目录，向测试副本注入相同的内存 `HttpTransport`，以 `cargo test --offline --locked` 执行；业务实现没有为实验修改。当前工作树同样复制到临时目录运行。标签源码不单独证明用户设备上的 APK 二进制与该标签完全相同。

探针的“学校响应”都是构造的条件，不是对实际学校行为的新观测。每行 `OBS` 是实际执行到的请求阶段、路线和是否携带 Cookie；Cookie 内容及密码不输出。模拟对象不检查真实 WebVPN 认证是否能建立，也不证明 WebVPN 端业务可用。测试刻意将所要检查的行为写成断言，因此历史版本会输出 `FAILED` 和测试线程 `panicked`；它们是断言失败，**不是 Android 应用崩溃日志**。脚本退出 0 只表示观察结果与下表的已记录矩阵一致，不表示所有产品测试通过。

## 相同输入下的观察

| 源码版本与提交 | 三个公共场景的结果 |
| --- | --- |
| Beta.3 `32b6a1d604128cec39a93826da684d5054cb0ea6` | 服务票据被跟随；直连业务不可达时尝试 WebVPN；UC 503 返回错误。三项断言通过。 |
| Beta.4 `d9239139b51eda0b754873cb7df470c47a4399a2` | 没记住密码且未持有 WebVPN Cookie 时，直连业务不可达只返回错误，未尝试 WebVPN；其余两项通过。 |
| Beta.5 `3ac380db7ed4ac856073696eb5b0cdb2f50efb10` | UC 返回 503 时仍发布 `SignedIn`；其余两项通过。 |
| Beta.6 `5215a1bc96461f168ee228d32bd02e36cfc210df` | UC 503 仍发布 `SignedIn`；假定服务票据必须被消费的合成场景中未请求回调，随后 UC 返回 10600，结果为 `SessionExpired`。 |
| Beta.7 `21f2957e079760dba14376de3551c0b6352d6b0d` | UC 503 已返回错误；仍未请求上述合成服务票据回调。另见下方两项冷恢复。 |
| 当前未提交工作树 | 消费合成回调、UC 503 返回错误；与 Beta.3 不同，登录后固定直连，业务直连不可达时未自动尝试 WebVPN。另见下方签到调用链。 |

这里的票据实验假定服务回调必须被访问才能让 UC 生效，以检出跳转行为差异；尚无本次真实服务回调证据，不能将其认定为用户实际掉线原因。该输入下 Beta.6/7 在登录过程中即报错，并非证明登录成功后掉线。业务回退实验的 VPN 端只构造 HTTP 200，不能将一次传输成功解释成真实功能已认证。

## Beta.7 冷启动丢失会话

构造自动路线：CAS 直连不可达，WebVPN 登录及 UC 成功，WebVPN Cookie 仅对模拟网关有效。实际登录路线为 `WebVpn`，但 Beta.7 `persist_active_session` 保存的是用户偏好 `Automatic`。新建客户端冷恢复时先恢复 `Automatic` 并尝试直连 UC；模拟直连返回 `code=10600,data=null`。源码位置可用 `git show android-v0.1.0-beta.7:rust/crates/ginkgo_upstream/src/services/session_service.rs` 和同版本 `services/session_service/session_source.rs` 查看。

- 未记住密码：`login=SignedIn active_route=WebVpn saved_route=Automatic restored=SignedOut restore_requests=[UC_STATUS:direct:cookie=false] record_remaining=false`。恢复失败后清除了身份和保存的快照。
- 记住密码：相同首个 UC 请求后又执行 `CAS_GET:direct -> CAS_GET:vpn -> CAS_POST:vpn -> UC_ACTIVATE:vpn -> UC_STATUS:vpn`，模拟服务允许登录后才恢复 `SignedIn`。密码 POST 只发给内存模拟器；不能据此声称真实账号本次发生过重复提交或触发风控。
- 当前未提交工作树：两种记住密码设置均保存实际 `WebVpn` 路线，恢复仅请求 `UC_STATUS:vpn:cookie=true`，结果为 `SignedIn`，未提交密码。这是合成测试结论，不是发布或设备验收。

上述是有明确输入前提的可复现缺陷：仅能说明实际情况若满足这组条件，Beta.7 会发生怎样的行为。当前没有这次用户设备的启动阶段、路线、记住密码状态和脱敏响应链，不能断言它就是所有“刚打开就掉线”的唯一原因。

## 当前工作树的签到限制

用实际 `load_checkin_on_date` 调用链：模拟 CAS/UC 直连登录成功，签到入口直连返回 `TransportError::Unreachable`。结果为 `NetworkUnreachable`，请求只包含 `CHECKIN_ENTRY:direct`，没有 `CHECKIN_ENTRY:vpn`；此时 `SessionStatus` 仍有合成账号和身份。故这是业务不可达而非该实验中的学校会话丢失。当前采用的 UBAA 固定连接模式与 Beta.3 的业务期自动换路线不同；此前静态对齐记录已说明该产品行为变化。它需要进一步评估，不得把该候选描述成解决了所有自动路线问题，也不能只凭模拟的 VPN 200 决定直接切换已认证 CookieJar。

## 为什么已有源码仍发生回归

可由历史提交与测试本身确认的环节：

1. `2c85a6c` 假设 UC 只是姓名目录，在 UC 不可用时构造登录身份；`5215a1b` 为避免重入 CAS 提前停止非登录目标跳转。离线实验分别捕获了 Beta.5/6 的伪 `SignedIn` 和 Beta.6/7 的服务票据差异。提交动机可以从提交记录读取，但不能据此推断每次真实失败的原因或编写者心理。
2. 旧 `MockTransport` 按队列返回响应，缺少对方法、目标和顺序的严格校验；旧登录样例的跳转仍在 CAS 主机，不能检出跨服务目标提前中断。代码和预期同时修改时，测试可能与实现一起偏离参考。
3. 历史完整门禁和模拟设备测试覆盖各自范围，不等于真实学校账号及冷启动链路验收。Beta.7 发布记录仍标注 readiness blocked；已有发布事实不能替代未完成的协议、设备和人工安全审查。
4. 本次较早静态修改曾引入编译错误，后续离线编译才发现并修复；这是本次执行中可验证的失误。需要固定参考版本、对请求目的地和顺序建立独立预期、验证旧实现或错误变体确实失败，并把未覆盖部分保留在唯一 TODO。

UBAA 对照的实际执行范围、七项变异实验和既有离线测试结果见[前次离线审计](2026-11-03-offline-session-parity-and-agent-review.md)。其中 UBAA 全网络编排未执行，不能据此声称全部协议完全一致；有限离线测试也不能保证以后没有任何故障。仓库历史曾记录真实会话失效和 Beta.4 阶段的实测，见 [MIRROR-TODO](../MIRROR-TODO.md)；那些是不同时间的证据，不是本次实时复验。

若需区分用户实际这次故障，需要已有的脱敏启动阶段、连接偏好、记住密码开关、错误类型和应用进程崩溃堆栈等证据，不能包含账号、Cookie、票据、密码或原始敏感响应；未经新的明确授权，不执行学校请求。没有应用崩溃堆栈时，无法判断是否有进程崩溃及其原因。

## 追加：验证器复核与 Beta.3 身份边界

加严验证器后再次执行全部标签及当前源码，退出 0；逐版本输出保存在 [合成原始记录](2026-11-03-history-verifier-evidence.txt)。原三个公共场景和冷恢复的输入、断言未变，新增 `gateway_mismatch`，并严格检查完整场景集合、通过/失败/忽略数量、失败名称和 cargo 退出码。

新输入的直连 UC 为 sy2501001，目标网关 UC 为 sy2501002。要求不向未经同账号确认的网关发送业务 GET、保留原路线且不增加密码提交。此为账号隔离不变量检查，不是 UBAA 请求形状一致性要求。

| 版本 | 新增身份边界 | 本轮实际被触发的失败断言 |
| --- | --- | --- |
| Beta.3 | 不读取目标 UC 就切换 WebVPN 并返回业务成功 | gateway_mismatch |
| Beta.4 | 直接返回原请求错误，未切换路线 | fallback |
| Beta.5 | 不读取目标 UC 就切换 WebVPN 并返回业务成功 | gateway_mismatch、uc_unavailable |
| Beta.6 | 不读取目标 UC 就切换 WebVPN 并返回业务成功 | gateway_mismatch、ticket、uc_unavailable |
| Beta.7 | 不读取目标 UC 就切换 WebVPN 并返回业务成功 | gateway_mismatch、ticket、cold_boot、cold_boot_remembered |
| 当前工作树 | 请求目标 UC 后拒绝身份不符；保留 Direct，不发送目标业务 GET、不补交密码 | 无；七个场景均通过 |

Beta.3 因此不能被当作所有边界都正确的黄金标准。该合成输入证明缺少目标身份校验，不证明用户真实账号发生过串读。当前工作树的原 `fallback` 场景在网关 UC 确认同一账号后成功；完整签到探针仍以故意不完整的网关 HTML 验证 ChangedResponse，不冒充真实签到读取成功。

这份矩阵仅覆盖列出的源码条件。非认证页面生命周期等既有问题另见[本地生命周期回归](2026-11-03-non-auth-lifecycle-repair.md)；未取证的用户故障不能被本表称为“全部复现”。UBAA 原测试与字段对照、验证器反例检查及候选产物沿用[网络审计](2026-11-03-network-transport-and-routing.md)。

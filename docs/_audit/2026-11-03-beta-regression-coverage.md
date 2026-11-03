# Beta.3–7 与 UBAA 离线覆盖复核

用户要求覆盖 Beta.3 的不足、Beta.4–7 已记录问题及 UBAA 协议对照。本文是问题出处与执行证据矩阵，不是第二份 TODO；未完成事项仍在 [MIRROR-TODO](../MIRROR-TODO.md)。真实账号、学校请求、应用/模拟器启动和学校写入保持暂停。

## 范围清点

本轮输入为 Beta.3–7 标签、其间修复提交、各版发布记录、Beta.4 回归审计、Beta.7 协议审计、当前唯一 TODO 和上轮会话审计。不能把未取证的“闪退”“掉线”归因写成已复现；以下逐项区分源码条件、页面行为、真实现场和外部参考自身失败。

| 问题 | 版本/出处 | 当前回归与证据入口 |
| --- | --- | --- |
| 未核对目标身份即换业务路线 | Beta.3/5/6/7；历史 gateway_mismatch | `check-history-session-probes.py`；`services/tests/automatic_route.rs` |
| 直连失败后无密码即禁止回退 | Beta.4；bd97642 | 历史 fallback；目标 UC 同账号/失效/身份不符严格转录 |
| UC 故障仍构造 SignedIn | Beta.5/6；2c85a6c | 历史 uc_unavailable；`session_protocol_never_fabricates_identity_when_uc_fails_after_cas` |
| 未消费非 CAS 服务票据 | Beta.6/7；5215a1b | 历史 ticket；完整认证请求对照 |
| 偏好 Automatic 被当作实际路线持久化 | Beta.7 | 历史 cold_boot/cold_boot_remembered；两种密码选择的严格冷恢复 |
| 可选密码保险库失败阻断有效 Cookie 恢复 | Beta.7 后审查发现 | `session_protocol_valid_cookies_do_not_depend_on_optional_password_storage` |
| 学校与网关共用恢复失败冷却 | Beta.4；bd97642 | `school_and_gateway_failures_have_independent_cooldowns` |
| 网关拒绝/验证码后继续自动提交密码 | Beta.4；bd97642 | `services/tests/session.rs` 的短/长冷却和人工解锁回归 |
| 根登录缺少退避 | Beta.4；bd97642 | `auth_route_stability_test.dart`；重启仍重置的剩余限制保留于 TODO |
| 验证码按 local 类型白名单拒答 | Beta.4/5 修复链 | 历史 captcha_type：Beta.3/4 拒绝 char，Beta.5/6/7 及当前支持；验证单次 GET、回答后单次 POST 及两个验证码字段 |
| 网关挑战丢失、无作答入口 | Beta.4/5 修复链 | `gateway_challenge_test.dart`、`gateway_challenge_generation_test.dart`、Rust gateway 回归 |
| 提示/401/新验证码/旧 execution 错配 | Beta.4–7 修复链 | `auth/expiry_tests.rs`、`session_protocol.rs`；未知结果不重发 |
| 提醒轮询强制绕过新鲜缓存 | Beta.4；bd97642 | 本轮历史 UI 回放 B4-reminder-cache：旧源码失败、修复提交及当前通过 |
| 首页后台刷新加载行引起几何抖动 | Beta.4；bd97642 | `loading_widgets_test.dart`、`today_progressive_widget_test.dart` |
| 首页空区刷新时闪现 | Beta.4；bd97642 | 本轮历史 UI 回放 B4-empty-refresh：旧源码失败、修复提交及当前通过 |
| 更多末项被导航栏遮挡 | Beta.4；bd97642 | 本轮历史 UI 回放 B4-more-bottom：旧源码失败、修复提交及当前通过 |
| SPOC 无快照错误投影为本地异常 | Beta.4；bd97642 | `native_learning_failure_regression_test.dart` 通过公开 NativeMirrorService 验证四类失败、五个学习接口；同一测试在旧源码断言失败、修复提交及当前通过 |
| 测试管线漏注入 gateway/账号 | Beta.4 验收管线 | `auth_challenge_widget_test.dart`、`learning_context_test.dart`；属于测试缺陷，不是学校协议 |
| 打开首页隐式触发签到认证 | Beta.4，Beta.6 再次加入 | 本轮新回归在当前旧实现失败；恢复显式操作后读取，覆盖时间推进和服务替换 |
| 七天日期行周日不可达/按钮过窄 | Beta.5 修复链；34a6d61 | 本轮九组 320/360/430dp × 1/2/3.2 字号；修复前五组失败，修复后通过 |
| 日期行大字号固定高度溢出 | 本轮从 Beta.5 修复链继续发现 | 动态高度和至少 48dp 目标；同一九组回归 |
| 四项课表模式被裁切 | Beta.5；3750149 | 实际字体、320dp/1.4× 下旧源码文字宽度断言失败，修复提交及当前通过；当前另跑 15 组尺寸/字号和四项点击 |
| 演示作业列表与详情状态矛盾 | Beta.5；a65651e | 宿主实际 Rust bridge：列表逐项与带/不带 spoc 前缀的详情状态、日期、分值比较；历史旧代码失败，修复提交及当前通过 |
| 未记住密码的网关模块认证 | Beta.6；5215a1b | `services/tests/session.rs`、`session_protocol.rs`、`automatic_route.rs`；凭据仅内存、验证码不重放 |
| 北京墙钟被当成绝对时刻，偏移八小时 | Beta.6；5215a1b | `school_wall_clock_bridge_test.dart` 经实际宿主 Rust bridge 验证午夜截止和签到窗口；旧源码失败、修复提交及当前通过 |
| 空教室激活失败仍继续查询 | Beta.7 | `classroom_http.rs` 内测试、完整业务对照；不把策略拒绝归凭据失效 |
| 成绩首次失败后无法切换学期 | Beta.7 | 本轮历史 UI 回放 B7-grade-retry：Beta.6 失败，Beta.7/当前通过 |
| 设置保存、路线选择、旧恢复覆盖新选择 | Beta.7 | `preferences_consistency_test.dart`、`auth_route_stability_test.dart`、`non_auth_lifecycle_regression_test.dart` |
| 确认期间账号/服务替换、迟到写结果 | Beta.7 | 图书馆/签到 mutation context、学习快照生命周期回归 |
| 下载页只认 checksums.txt，忽略 APK sidecar | Beta.7 | `check-landing-test.cjs`；精确资产配对/恶意 URL/静态回退 |
| 登录占位文字对比不足 | Beta.7 | `login_placeholder_contrast_test.dart`；亮/暗背景混色检查 |
| 空教室/学习快照/通知/偏好实例切换竞态 | Beta.7 后续复核 | `non_auth_lifecycle_regression_test.dart` 的 12 项回归及原审计红灯 |
| Cookie 错误 Domain、过早过期、调用方头泄漏 | Beta.3 起的基础层审查 | 原生 HTTP loopback、响应到达时刻回归及变异检出 |
| 超时/取消后孤立 HTTP 任务、正文边界 | 网络基础层复核 | `transport_loopback.rs`、reqwest lifecycle tests 和变异检出 |
| 切路线后重放旧 iClass 凭据 | 网络路线复核 | 入口、app login、首次查询、缓存会话四阶段严格转录 |
| 博雅合法明文信封被拒绝 | 本轮固定参考复核发现 | 原 UBAA 保留明文 encodedPayload；Rust 新回归先红后绿，覆盖对象/字符串包装、业务拒绝、结构变化及一次请求 |

上述表格是覆盖入口，执行结果另列于下；没有对应用户现场输入的条目，不写“全部真实故障已复现”。

## 本轮实际新增修复

1. 日期条在 320/360dp 下低于 48dp，3.2× 字号下固定 68dp 容器溢出。新九组测试修复前五组失败，修复后及既有课表回归共 16 项通过。常规宽度可等分七列，放不下触控目标或大字时横向滚动；高度跟随文字缩放。
2. Beta.6 重加的首屏签到仍存在于当前实现，违背此前避免隐式认证的修复目标。新增测试先捕获初始读取次数为 1；现首次进入/服务替换/本机计时不读取，点击“查看课程签到”或显式刷新才读取。手动读取后的签到状态、旧快照和失败恢复仍保留；相关 35 项测试通过。旧“首屏读取”预期改为先断言零读取、再操作并断言一次读取，不删掉状态检查。
3. 成绩和空教室请求与实际 Ktor 工厂有头差异。独立 Kotlin 捕获后对齐成绩 Accept/表单字符集、空教室 UA/Accept。重定向保留 User-Agent/Accept/Accept-Language，其余凭据及来源头不转发；专门严格转录在旧实现失败后通过。
4. 博雅在固定参考允许的合法明文信封上误报结构变化。修复前实测返回 ChangedResponse，修复后仍验证成功状态和数据结构，业务拒绝不伪造成功，且不重放请求。测试最初有一次所有权编译错误，修正后才取得上述真实断言红灯，不把编译失败计作复现。

## UBAA 原测试与请求对照

固定参考仍为 `e8a397fcb35a68147eee65a94c66ffb84e2f09fe`，从 git archive 导出，原实现和原测试不改。自动发现全部 48 个 commonTest 测试类，再加四套独立探针；每套测试必须存在报告、至少一项、无跳过，并保存具体用例结果。

扩大执行后的实际结果为 209 项：204 通过，5 失败。五项均在 `LocalJudgeApiBackendTest`：固定样例从 2026-04-20 开始，原客户端按运行日的六个月界限过滤；原测试未固定时钟。新增 `ReferenceClockProbeTest` 调用原私有判定器，只通过既有 nowProvider 注入 2026-05-01 与 2026-11-03，分别证明同一作业不过期/过期；另一个探针在 2026-05-01 的既有时钟端口下直接调用五个未修改的原测试体，五个均通过。未调整系统时间、未改原测试预期，原五项运行日失败不被改称通过；脚本最终仍返回失败，并保留诊断证据。

业务对照由八场景扩到十二场景，新增直连/WebVPN 成绩和空教室。原八场景的独立 golden 逐项确认不变；新增 golden 来自实际 Kotlin 捕获。修复后比较范围内无未解释字段差异。保留一项显式业务策略：空教室激活的绝对 Location，UBAA 引擎在 WebVPN 模式转直连，Ginkgo 保持已认证路线；不为字面一致迁移 Cookie 路线。原 HTTP Cookie 路径边界差异仍独立保留。

认证从只对比阶段推进到完整方法/URL/头/表单/Cookie 捕获。修复前独立捕获发现 14 处请求头差异，补齐默认 JSON Accept、表单字符集及 UC AJAX Accept 后，三个场景无未解释字段差异。UBAA WebVPN 成功后额外直连密码事务继续作为已说明差异，不复制额外密码提交。十组 CAS 字段向量仍作为独立解析器对照。

## 本轮执行记录

- [九项 UI/实际 bridge 历史回放](2026-11-03-beta-flutter-history.json)：在不可变旧源码失败、修复提交与当前通过；脚本拒绝把编译错误/零测试/跳过当旧缺陷复现。四模式最初使用 1.0/1.3× 未抓住旧问题，没有计作复现；补足真实字体与 320dp/1.4× 边界后才取得断言红灯。测试滚动同步修正后，另保留[最终四模式历史回放](2026-11-03-beta-modes-history.json)。
- `/tmp/ginkgo-beta-expanded-session-history.log`：Beta.3–7 与当前的认证历史矩阵；当前八场景通过，旧版按预先记录矩阵出现对应缺陷。
- `/tmp/ginkgo-school-day-before.log`、`/tmp/ginkgo-school-day-after.log`：日期条五组真实红灯及修复后 16 项通过。
- `/tmp/ginkgo-today-implicit-before.log`、`/tmp/ginkgo-today-passive-final.log`：首屏隐式签到真实红灯及相关 35 项通过。
- `/tmp/ginkgo-redirect-negotiation-before.log`、`/tmp/ginkgo-redirect-negotiation-after.log`：完整头转发边界先红后绿。
- [最终固定参考执行记录](2026-11-03-beta-expanded-reference.json)：原测试逐例结果、完整认证、十二场景业务请求、十七场景实际 HTTP 和受控时钟原测试体。扩大后的 UBAA 结果保持失败，不能沿用此前“31 项通过”表示全部原测试通过。
- `/tmp/ginkgo-final-cas-parity.log`：原 Kotlin 解析器十组字段向量对照通过。
- `/tmp/ginkgo-schedule-real-font-final.log`：15 组真实字体课表模式回归通过。第一次完整门禁发现大字号动作表测试滚动后未等待布局，补足测试同步后重跑；不把测试时序失败写成产品修复。

`bash scripts/check-mirror.sh` 最终退出 0，日志 `/tmp/ginkgo-beta-final-mirror.log`。严格 Clippy、Rust 分层及 workspace 测试、架构/协议/接口文档门禁、八项验证器反例、22 个已编译错误变体检出、Flutter analyze、789 项 Flutter 测试和 FRB 重新生成零漂移均通过。宿主真实 Rust bridge 的演示详情和墙钟测试实际执行，未跳过。第一次门禁的课表动作表测试同步失败已修正，最终整套重跑通过；生成器写入中途的一次 `git diff --check` 曾看到未格式化中间文件，等待生成完成后的独立检查通过，未手工修改生成物。

旧 network-candidate APK 早于本轮新增修复，不能冒充本轮产物。build 17 的中间候选见 [产物记录](2026-11-03-comprehensive-candidate-artifact.json)；随后将实现版本递增为 Beta.8/build 18 并发布，最终 APK 与门禁例外记录见 [Beta.8 发布记录](2026-11-03-beta8-publication.md)。两个包均未用于登录或学校请求。

## 仍不能作出的结论

- 不能宣称 Beta.3–7 的全部未知现场问题均已复现；矩阵只覆盖已记录且具有输入的条件。
- 根登录退避仍为内存状态，重启即重置；凭据错误与风控拒绝的可区分证据仍不足，保留于唯一 TODO。
- UBAA 原套件在运行日仍有五项失败；受控时钟下通过不改写原套件结果。合成请求覆盖不等于所有上游响应和系统 TLS/JNI 一致。
- 当前候选尚无 Windows CI、Android 物理设备、真实会话冷恢复、学校写入和人工安全审查结果；公开发布门禁继续 blocked。

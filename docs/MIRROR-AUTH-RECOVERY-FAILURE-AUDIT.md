# 自动恢复登录失败合并审计（2026-10-21）

本记录基于 `01cb3c0`，在独立 `/tmp` worktree 完成，只使用合成账号与 transport，Cargo 设置离线模式。没有学校网络请求、真实凭据、设备操作、主工作树改动或发布。用户报告多个平台与官方入口提交凭据后 HTTP 500；其他同学是否受影响未知。本审计不能判定全校故障、账号限制或其归因。

## 源码事实

- Rust `auth/mod.rs::complete_login`：新表单且无需未填写的验证码时，调用一次 `Session.send` 提交账号密码；已有会话或尚缺验证码时不提交密码。`auth/login.rs::follow_redirects_and_check_error` 收到 HTTP 500 立即返回 `ServiceUnavailable`，不重试密码 POST。200 密码过期提示最多额外提交一次 `execution + ignoreAndContinue`，不包含密码。
- `auth/session.rs::send_with_fallback` 仅允许 GET 在自动路线遇传输失败或访问策略拦截时转 WebVPN；POST 不经该回退重投。跳转后请求为 GET。HTTP 500 本身不是普通 GET 回退条件，但若正文同时匹配访问策略字符串，GET 可走该既有回退；密码 POST 仍不回退。
- Dart 登录页 busy 状态禁止重复点击；bridge 的 `SESSION_ACCESS.write` 串行显式登录与 restore。账号去首尾空白、密码原样进入 Rust；`cas::login_fields` 替换同名字段并进行表单编码，与 Swift `CasFormParser` 一致。这只确认数据流，不能证明真实输入的密码正确。
- 启动 restore 无循环定时器；最多遍历 5 个已存账号，只有 `InvalidCredentials` 才继续下一个。500 立即返回，不继续其他账号。静默恢复仅在业务报告失效/明确网关登录挑战时调用，不是每个业务读取都提交密码。
- reqwest 0.12.28 默认支持特定协议 NACK 重试，但本项目禁用默认特性，仅启用 rustls/gzip，未启用 http2/http3，对应 NACK 分支被 cfg 排除；HTTP 500 响应不属于默认重试条件。未修改 TLS 或客户端超时。

Swift 对照：`CasClient.submitLogin`（原始行 221–251）只调用一次 send；`followRedirectsAndCheckError`（297）对 5xx 立即抛错；密码过期提示（308–319）仅额外发送无密码继续表单。`AuthViewModel.performLogin`（118–130）只在访问策略错误时允许整轮重试一次，500 不匹配。成功主登录后（111–115）可能再调用 `AppState.prepareWebVPNSession`，由 `CasClient.establishWebVPNSession`（97–106）按网关页面决定是否额外提交一次密码；这是独立网关认证，不能把一次 UI 操作绝对说成全平台永远只有一次密码提交。Swift `AppState.restoreSession`（49–112）每实例仅启动一次，验证暂时错误直接返回，不把 500 当会话失效重登。

## 已复现的失败放大

`SessionService::silent_login` 和 `ensure_webvpn_session` 原先使用互斥 gate 与成功 generation 合并并发恢复；generation 只在成功时递增。首个自动登录失败后，等待者仍看到旧 generation，可能依次重复同一失败登录。每个业务调用内部有界，但多个业务调用可放大密码 POST；没有跨调用的失败共享或冷却。

新增纯合成 transport 让两个空教室查询都返回 401，再让 CAS 密码 POST 返回 500。旧实现下两次业务读取都失败，密码 POST 次数实际为 2，违反期望 1，回归明确失败。这证明放大路径存在，不证明它在真实账号上发生过，更不证明账号限制由此产生。

## 独立修复

学校与网关自动恢复共用 60 秒、仅内存的失败结果。锁内先检查失败结果，等待者与短期后续自动调用返回原错误，不当作成功、不继续读取、不提交密码，也不延长既有冷却。60 秒后只允许下一次调用重新尝试，不设置自动重试定时器。成功恢复清除此状态。

用户显式登录绕过自动恢复冷却；失败仍返回失败，成功后清除旧失败。退出、账号切换、路线变化的身份清理同时清除此状态。没有修改登录字段、路由/TLS、上游端点、密码过期提示处理或业务写入策略。

新增 4 项回归覆盖：两个真实用例入口的失效并发只发一次密码 POST；学校/网关共用失败与显式登录恢复；冷却过期/身份隔离；网关首次失败后不被学校恢复再次提交。合成 transport 同时断言账号/密码字段正确且编码一次。既有成功并发恢复合并回归继续保留。

该修复只减少故障期间自动认证请求的放大；不能修复上游 HTTP 500，也不构成真实认证恢复或账号未受限制的证明。

离线验证：旧实现上述并发回归明确失败（实际 2 次密码 POST，期望 1）；修复后 workspace 169 项核心、1 项契约遍历、1 项桥接生命周期、1 项 doc-test 全通过，fmt、全目标/全特性严格 Clippy 与 diff-check 通过。未构建或安装 APK，未 cherry-pick 到主工作树。

## 已知 CAS GET 跳转的 HTTPS 修正

后续以 `b61cb56` 为基础，在同一独立 worktree 追加此项修正。依据是根任务提供的用户授权一次诊断结果：HTTPS SSO 表单 GET 200、密码 POST 302、UC 首页 200；UC 激活 GET 返回 302，Location 为 `http://sso.buaa.edu.cn/login?service=…`；继续 HTTP 会落到登录页，UC status 为 code 10600、data 非对象。匿名激活也出现相同 HTTP 跳转，同 service 的 HTTPS 页面可达。Cookie jar 未向 HTTP 发送 Secure Cookie，符合预期。这些事实定位了已观察到的协议降级与会话丢失路径，不证明整个上游故障、账号限制或所有登录问题的原因。本代理没有复做任何真实请求。

新增 `auth::redirect::resolve_get`，用于 CAS、UC、通用 GET 跳转及签到/图书馆手动 CAS 跳转。仅当 HTTP Location 的原始 authority 是 `sso.buaa.edu.cn`（不含用户信息或显式端口），原始路径恰好为 `/login` 时，仅替换 scheme 为 HTTPS。保留 service 的百分号编码、大小写、重复查询键、顺序与 `+`。不接受 `/cas/login`、其他路径、端口、相似域名或其他协议；未知不安全目标在发出下一请求前返回固定 `ChangedResponse/insecure_redirect`，错误不包含 URL、service 或票据。已有 HTTPS 目标及图书馆既有主机白名单不放宽，WebVPN 仍使用原路由编码，Secure Cookie 与 TLS 规则不变。此函数仅处理下一跳 GET，不修改密码表单 action 或新增密码 POST，不自动重登。

离线回归先在旧实现失败：合成 UC 激活响应指向已知 HTTP CAS 地址，下一请求实际为 HTTP，违反预期 HTTPS。修正后完整合成登录链恰好一次密码 POST，已升级 CAS GET 携带 Secure Cookie，最终以 UC status 成功对象确认会话；断言所有请求为 HTTPS。另覆盖 CAS 入口/通用 GET、WebVPN Location、查询字节保留、未知 HTTP 在下一请求前拒绝、表单 action 不变与 Cookie jar 不向 HTTP 发送 Secure Cookie。

Swift 仅对照：`Features/Auth/CasClient.swift::redirectURL` 原始行 443–448 将 `target.scheme != https` 与缺失 Location 合并为 `missingRedirectLocation`，因此真实存在的上述 HTTP Location 会触发误导文案。建议 Apple 后续在该 GET 跳转边界实施相同精确 authority/path 检查与只改 scheme 的规则，并区分未知不安全跳转和真正缺失 Location；不能修改通用 Cookie/TLS 策略或任意升级 HTTP。本次没有改动 Swift 或 Xcode 工程。

最终离线门禁：workspace 175 项核心、1 项契约遍历、1 项桥接生命周期、1 项 doc-test 全通过，fmt、全目标/全特性严格 Clippy 与 diff-check 通过。现有 Alpha2 APK 不含此修正；没有构建、安装、发布或真实登录验收。根任务另维护脱敏事件审计与 API 修订 #62。

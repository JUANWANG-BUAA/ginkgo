# 认证跳转异常：只读诊断记录

时间：2026-10-21，约 13:40–13:50（北京时间）。本记录不包含账号、密码、Cookie、票据或完整查询参数。

## 现象与范围

用户报告多个客户端和官方页面登录失败，最初出现 HTTP 500；SPOC 返回 `{"code":0,"msg":"未知异常错误","msg_en":null,"content":null}`，随后 SPOC 网页恢复，而 Ginkgo / UBAA 仍提示学校会话失效；macOS Ginkgo 提示“认证服务的跳转地址缺失”。其他账号是否受影响未知。

## 单次真实登录结果

经用户明确授权，仅提交一次密码，使用当前 Rust 认证实现及正常直连路线，无自动重试、无业务接口读取。诊断传输层只输出方法、无查询参数的域名/路径、状态、耗时和固定错误标志；会话只在进程内存中，结束后释放。

| 请求 | HTTP | 观察 |
|---|---|---|
| GET `https://sso.buaa.edu.cn/login` | 200 | 普通 CAS 登录页，无锁定或策略禁止提示 |
| POST `https://sso.buaa.edu.cn/login` | 302 | 56/29 ms（前一 GET / 本 POST）；没有复现 500 |
| GET `https://uc.buaa.edu.cn/` | 200 | 登录重定向落点 |
| GET `https://uc.buaa.edu.cn/api/login` | 302 | 跳向 **HTTP** SSO `/login`，带 service 查询参数 |
| GET `http://sso.buaa.edu.cn/login` | 200 | 返回 CAS 登录表单，未完成 UC 认证 |
| GET `https://uc.buaa.edu.cn/api/uc/status` | 200 | 业务码 `10600`，没有有效用户数据；Rust 返回 SessionExpired |

之后无账号独立 GET UC 激活地址，同样观察到 `Location` 的 scheme 为 http、host 为 `sso.buaa.edu.cn`、path 为 `/login`；其中嵌套 service 仍指向 HTTPS UC `/api/login`，因此异常 scheme 在外层 SSO 跳转。不带账号访问相同 service 的 HTTPS SSO 地址也返回 200，证明该 HTTPS 入口存在，不证明已完成真实认证。SPOC 静态页 200，CAS 入口 302 到 HTTPS SSO；它与 UC 使用的回调链不同。没有尝试业务写入。

## 已定位与未定位

1. **桌面错误文案的直接来源已定位**：`BUAA-Assistant/Features/Auth/CasClient.swift` 的 `redirectURL` 要求解析后的 `target.scheme == "https"`，HTTP Location 同样落入 missingRedirectLocation。因此该提示不能证明上游缺少 Location。本次 UC 确实返回了可解析但 scheme 为 HTTP 的地址。
   `git blame` 显示 HTTPS guard 来自 2026-10-15 的 `55568911`，并非今日新增。当前没有历史响应头样本证明学校何时开始返回 HTTP，不能把“近期才出现”直接写成“学校今日改了配置”。
2. **镜像会话失效与该链路吻合**：Rust 跟随 HTTP SSO 后落回登录表单，最终 UC status 无有效用户数据。Cookie jar 按 Secure 属性拒绝向 HTTP 发送安全 Cookie；不应为了兼容跳转放宽此规则。是否还存在独立的学校后端故障，仍需修复后的单次完整登录或学校日志确认。
3. **不能将早前 500 等同本次会话失败**：本次未复现任何 HTTP 500；SPOC 通用 JSON 没有异常类别或账号封禁信息，且缺少对应请求路径。不得声称已证明全校故障、永久封禁或由本项目测试导致限制。
4. **确有独立的客户端请求放大隐患**：并发业务恢复在首次认证失败后，等待者原先仍可能各自尝试认证。已以纯合成响应复现并开发失败合并修复；这不构成实际触发学校限流或锁定的证据。

## 修复边界

对已确认的 `http://sso.buaa.edu.cn/login` GET 重定向，窄范围提升到同主机 HTTPS，原样保留 service 等编码；其他不可信或未知 HTTP 认证重定向明确拒绝。保持 Secure Cookie、TLS 验证和 POST 不重放。真实密码提交已结束，不为验证修复自动再次登录。自动恢复失败合并单独处理，不将失败当成功，不定时重试。

参考：协议依据见 [API.md §1](../API.md)；Secure Cookie 规则见 [RFC 6265 §4.1.2.5](https://httpwg.org/specs/rfc6265.html#the-secure-attribute)。

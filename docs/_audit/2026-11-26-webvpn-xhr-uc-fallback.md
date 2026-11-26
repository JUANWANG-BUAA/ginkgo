# 2026-11-26 WebVPN XHR UC 探针误判修复

## 授权与范围

2026-11-26，用户在窗口模拟器（`emulator-5554`，自动路线锁定直连，本机存在 TUN 代理出口）反馈 SPOC 作业（20021 ms）与 iClass 签到（10002 ms）均报“数据格式无法识别”。排查确认根因并向用户报告冻结文件影响后，用户明确回复“没问题”授权本项最小修复。

- **冻结基线保持不变**：`android-v0.1.0-beta.9` / `c4afc0c3f5edad5cded1352da5b536001edb430a`，`docs/network-freeze.json` 中原始 `files` 哈希未修改。
- **唯一获准修订的冻结源文件**：`rust/crates/ginkgo_upstream/src/auth/uc.rs`（SHA-256: `3c3657f974ffb7d7275c241dd7cdc83efc973a2d9fc88774145780860a48707d`）。CAS、验证码、Cookie、密码提交、`reqwest_transport`、`automatic_route` 状态机均未改动。

## 根因证据

1. 模拟器裸 TCP 探测显示 `sso.buaa.edu.cn:443`（533 ms）与 `d.buaa.edu.cn:443`（539 ms）可达，而 `spoc.buaa.edu.cn:443` 与 `iclass.buaa.edu.cn:8346/8347` 超时不可直连，命中 `connect_timeout = 10s` 返回 `NetworkUnreachable`。
2. `automatic_route.rs` 随后使用空 WebVPN Cookie 罐向 `d.buaa.edu.cn` 发送带 `X-Requested-With: XMLHttpRequest` 的 `uc/status` 探针。匿名实测该网关 XHR 请求返回 `HTTP 200 OK` 与 JSON `{"message":"您的会话已经过期，请重新登录","success":false,"url":"/login"}`（而非 302）。
3. `uc::parse_uc_status` 反序列化 `UcStatus { code, data }` 失败，将其误归类为 `ErrorCode::ChangedResponse` 并被 `automatic_route` 缓存 60 秒，导致客户端将“直连不可达、需 WebVPN 会话”误报为“数据格式无法识别”。

## 修复内容

- `rust/crates/ginkgo_upstream/src/auth/uc.rs`：新增窄范围识别 `is_webvpn_xhr_login_required`，仅当 JSON 同时满足 `success == false` 且 `url` 为 `/login` 或 `https://d.buaa.edu.cn/login` 时返回 `SessionExpired`，交由既有 `automatic_route.rs` 映射为 `ModuleAuthRequired("webvpn_route_login_required")`；HTML、未知业务码、外域 URL 与 `success == true` 均保持 `ChangedResponse`。
- 非冻结层配套改进：`homework_http::authenticate` 预热遇 `NetworkUnreachable` / `ModuleAuthRequired` / `AccessPolicyDenied` 立即短路，避免 2×10s 重复等待；`homework.rs` 透传 `failure_detail`；Flutter `failureMessage` 对 `webvpn_route_login_required` 给出明确的切线/校园网指引。

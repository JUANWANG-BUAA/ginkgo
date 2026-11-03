# 完整离线会话生命周期与本地候选（2026-11-03）

用户要求尽量在本地解决“上机立即可用”的问题。本轮继续修改实现、执行真实 SchoolClient 的合成事务并构建正常入口 APK；不使用真实凭据，不访问学校，不启动应用或模拟器，不执行学校写入，也不发布。

## 本轮实际找到并修复的缺陷

`SessionSource::restore` 在已用 Cookie 向 UC 验证同一账号后，仍通过 `vault.load(account)?` 读取可选保存密码。独立密码条目读取故障会使整个恢复返回 `CredentialStore`；Flutter 启动恢复会收到错误，即使 Cookie 可用也无法进入工作区。冷恢复、同进程恢复、同进程保留已验证身份的 UC 暂时故障分支都有这项耦合。

新增测试先于修复执行，实际失败：

```text
session_protocol_valid_cookies_do_not_depend_on_optional_password_storage ... FAILED
route=Direct cold=true unavailable=false:
Err(AppError { code: CredentialStore, detail: None })
test result: FAILED. 0 passed; 1 failed
```

随后修改三个分支：可选密码读取失败只使 `remembered=false`，不阻断有效身份，不删除密码或枚举其他账号，不提交密码。新增 fake vault 对这些额外操作直接 panic。直连/WebVPN 各覆盖冷恢复、同进程恢复、同进程 UC 暂时错误，共六个条件。新登录或冷恢复的 UC 验证仍不能跳过。该故障是本地故障注入确认的源码问题；没有证据说用户设备发生过密码条目读取故障，不能把它冒充实际掉线的唯一原因。

## 把模块组合在同一个会话中运行

`services/tests/session_lifecycle.rs` 使用生产 SchoolClient、Session、CookieJar、服务编排、缓存和解析器，仅替换 HttpTransport 与保险库。按系统划分的严格请求队列允许模块并发，但每个请求的方法、完整 URL、全部模型请求头、Cookie、请求体及系统内顺序必须先匹配才返回响应。

正向事务：

1. 应用偏好 → CAS 表单与密码单次提交 → 消费服务票据 → UC 激活与身份确认。
2. 同一客户端并发读取完整周课表和考试、签到课程、图书馆场馆。返回非空数据：2 门课、2 项考试、1 门签到课程、1 个场馆。
3. 各系统设置独立路径的模块 Cookie，断言不会污染其他系统；UC Cookie 轮换写回持久化记录，认证生命周期起点不改变。
4. 销毁客户端。新客户端执行与 SessionGate 相同的启动操作顺序：设置偏好 → 恢复保存的实际路线和 Cookie → UC 校验。
5. 并发重新读取三类业务，必须携带恢复后的模块 Cookie；iClass session 和图书馆 token 重新取得，恢复阶段和后续读取没有 CAS 密码提交。

路线组合为显式直连、自动选中直连、显式 WebVPN、直连登录页不可达后自动选中 WebVPN，分别覆盖记住/不记住密码，共八种完整生命周期。它执行 Rust 真实服务组合，没有执行 Flutter/FRB/JNI 或 Android 网络引擎。

负向事务：直连/WebVPN × 签到/图书馆单模块 × 503/网络不可达，共八种条件。失败模块返回明确错误；课表及另一个模块仍返回非空数据；UC 身份、实际路线和持久化会话保留，不增加 CAS 密码提交。

课表与考试使用已有 `fixtures/schedule` 合成契约；非空签到结构取固定 UBAA 原测试的合成响应；图书馆场馆与已执行 UBAA 差分的合成结构相同。这里扩展的是生命周期组合覆盖，不把新增流程写成完整 UBAA 请求等价证明。此前六个独立 UBAA 请求 golden 及其来源不变。

## 验证记录

- 定向 `cargo test --manifest-path rust/Cargo.toml --offline --locked -p ginkgo_upstream --no-default-features --lib session_protocol -- --nocapture`：11 项通过，包含上述循环内条件；日志 `/tmp/ginkgo-session-lifecycle.log`。
- 变异检查新增 `optional-password-blocks-cookie-restore`：把冷恢复改回旧的 `?` 读取，编译成功且回归断言失败。完整门禁实际捕获 10/10 项变异，未把编译错误当作成功抓回归。
- `CARGO_NET_OFFLINE=true bash scripts/check-mirror.sh`：退出 0，包含架构/文档/接口索引、fmt、严格 Clippy、core/upstream/workspace 测试、变异检查、Flutter analyze、761 项 Flutter 单元/widget 测试及 FRB 再生成零漂移。日志 `/tmp/ginkgo-session-candidate-mirror.log`。Cargo 离线；该完整脚本仍会运行公开包仓库的依赖解析，不称为绝对断网执行。
- `check-ubaa-reference.py` 对固定 `e8a397fcb35a68147eee65a94c66ffb84e2f09fe` 再执行：25 项原测试 + 4 项探针通过，六个读取场景共 16 个请求，规范化比较字段零差异；历史标签阶段探针结果符合已归档矩阵。该执行在拒绝外网连接的 sandbox 中完成，记录更新到 `2026-11-03-ubaa-wire-evidence.json`；日志 `/tmp/ginkgo-session-candidate-reference.log`。

## 正常入口本地候选

`CARGO_NET_OFFLINE=true flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub` 退出 0，日志 `/tmp/ginkgo-session-candidate-apk.log`。使用既有外部签名配置，不修改版本、不创建 tag、不公开发布。

- APK：`flutter/build/session-candidate/Ginkgo-session-fix-2026-11-03-arm64.apk`，44,187,325 字节；同目录 `checksums.txt` 使用 basename。
- SHA-256：`bd7edf96091fb0d704a59eb23e53969f378dafd3e8ddc54e82e1f93c60c041ce`。
- 版本仍为 `0.1.0-beta.7+17`，这是当前工作树的本地候选，不是已发布 Beta.7 的原 APK；不得仅凭版本号判断代码内容。包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`。
- 签名校验通过，证书 SHA-256 与已归档 Beta.7 发布记录一致：`451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`。这只是签名一致，不代表已实际覆盖升级。
- 非 debuggable、仅 `arm64-v8a`、正常 main 入口、插件注册表不含 integration_test，16 KB zipalign 校验通过。
- 原生核心编译时间晚于本轮会话修复源码时间，APK 中核心 SHA-256 与此次构建的 stripped 库一致，避免把旧产物当成本轮结果。该检查不等于设备加载验证。
- 候选源码摘要 `0329519efb756b572125f4fe3d8461c84aa315922bca80ade4fd70b7b34c2783`；协议契约摘要 `8f78d1a2ab8d67059aa3a17aad4c8875518b607c748fc605db2512c44a4d533b`。完整元数据及各原生库摘要见 `2026-11-03-session-candidate-artifact.json`。

未安装、未启动候选，未验证覆盖升级或真实学校业务；发布 readiness 未改为 ready。

## 仍保留的具体边界

- Beta.3 业务期自动切 WebVPN 与固定 UBAA 的显式连接模式不同，不能声称同时逐字复制两者。当前按固定 UBAA 的模式边界，登录选路后固定；直接访问 CAS 成功但业务系统直连不可达时，该业务仍失败并保留学校身份。尚未实现经独立身份确认的业务期自动换路，也没有为了让测试变绿把路线重新改回共享可变状态。此项继续在 MIRROR-TODO 维护。
- 旧 Beta.7 Automatic 快照没有有效路线，仍需一次手动登录；不猜 Cookie 所属路线、不后台重复提交密码。
- Android 网络引擎、Keystore/JNI、物理设备和真实学校响应未由这些离线测试覆盖。构建成功不等于启动或真实业务验收。认证/保险库的人工安全审查和发布阻断状态保持原样。

未完成项只维护在 `docs/MIRROR-TODO.md`，本记录不是第二份任务清单。

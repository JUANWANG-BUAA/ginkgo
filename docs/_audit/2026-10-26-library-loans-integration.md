# 本人借阅读取接续（2026-10-26，工作树）

## 范围与证据

接续会话最后的“建议把借阅的读接口也实现”。此前说明入口不是读取实现。
本次新增 domain 独立值类型/端口、upstream 认证跳转与严格解析、core 命令、
FRB 命令、Flutter native/demo 适配及按需页面。没有续借、归还、预约或其他学校写入。

仅以系统默认 TLS 校验匿名获取下列官方公开资源，没有使用会话导出里的真实凭据、
浏览器 Cookie 或个人借阅响应；原始会话导出含敏感信息，不得提交。

| 证据 | 公开路径 | SHA-256 / 观察 |
| --- | --- | --- |
| E1 | `/space/js/space.35058fb9.js` | `a16c2eef370d190cf89cf67bb9744a5d9ab4f4f890e52cb7746568535ec8fbf9`；与 10-23 静态证据相同；模块 6237 读取 search_confs，00ce 提供 loans，e650 将 HTTP 401 作为认证失效 |
| E2 | `/space/user/config/app.config.js` | `5833a9cb82d97f97b86f33c7e2f51913902bbcd977a1d8224d40669045156bfd`；baseUrl=/meta-local |
| E3 | `/meta-local/opac/search/search_confs` | 本次匿名 HTTP 成功且数值 code=0；仅摘录公开配置：loginType=1，casUrl=https://sso.buaa.edu.cn，spaceUrl=https://space.lib.buaa.edu.cn:443/meta-local/opac/cas/rosetta，space.cas.pc.target.url=https://space.lib.buaa.edu.cn/space/casBoard |
| E4 | `/space/js/chunk-2d0a3577.9bea817c.js` | `3e51358ee035b29e9ee7e4846ee9442f4af57e8b8d0ec4fa1d2f941f73a4a3a9`；CasBoard 依赖服务端 Cookie 后读用户信息；客户端无需复制其个人资料查询和 UI 操作 |

主机均为 `space.lib.buaa.edu.cn`。配置值与静态调用是认证入口证据，不是 App 成功登录实测。
沿用 API §6.2 已验证的 loans 成功空态；非空字段仍只有静态组件证据。
多页请求是客户端实现，服务端真实非空/第二页、类型兼容、读者资格仍待人工只读验收。
不请求 loan_info、续借上限或完整读者资料，不保存册条码、借阅状态编码及续借资格推测。

## 安全与失败边界

- 仅用户点击读取，使用当前绑定账号的学校 Cookie session；公开查书继续匿名隔离。
- 从已取证的固定 rosetta GET 入口开始，最多 10 次 HTTPS 跳转，仅允许学校 SSO 与 space.lib 默认 443；无密码提交、不静默重登、不手工拼 Cookie。遇 SSO 登录表单/HTTP 401 显示认证未完成，不清除全 App 登录。
- 查询限定 page 1–100、pageSize=100、响应 512 KiB；这些是客户端保护，不是学校容量承诺。分页字段矛盾、重复 ID、字段漂移不得显示成功空列表。总数为零时接受 totalPage=0 或 1，不猜造记录。
- HTTP 404/410 或解析漂移显示协议变化；超时/5xx 显示暂不可用，403 显示网络/权限限制。非零业务码统一按该 OPAC 契约作为业务拒绝，不猜其含义。没有主动批量探活。
- upstream 不存借阅快照，返回前复检账号与身份代次（含 A→B→A）；FFI 生命周期锁排斥切账号。
- Flutter 保留当前页的刷新失败旧值并标记非最新；认证失败清记录，确认空结果覆盖旧值。离开栏目、服务变更、销毁或进入后台清除页面值并废弃在途响应，返回不自动查询。
- 记录不写磁盘、不进入提醒计划、不新增系统权限或 TLS 例外。认证接线属于需人工安全审查的 diff。

## 自动化与未覆盖

借阅 codec/service 测试使用合成数据覆盖确认空、非空投影、结构漂移、业务拒绝、
缺身份、无效页、受限跳转、Cookie 使用、认证失败及账号 ABA；Flutter 测试覆盖主动触发、
分页、失败保留、认证清理、确认空覆盖、迟到响应和后台清理。

本机 macOS ARM64、固定 Rust/Flutter 工具链验证结果：

| 命令 | 结果 |
| --- | --- |
| `bash scripts/check-mirror.sh` | 通过：架构规则/自测、fmt、严格 Clippy、core/upstream/workspace 测试、Flutter analyze、全部 widget/unit 测试及 FRB 二次生成一致性 |
| `flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` | 通过，正常 main 入口；产物 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，仅开发测试 |
| `git diff --check` | 通过 |

首轮完整检查暴露既有学习目录竞态测试对未完成请求使用 `pumpAndSettle` 而超时：
仅在故意挂起的两次点击改用有界 pump，额外断言两次请求均已发出，保留乱序完成的原断言；
定向和完整复跑通过。没有禁用生产动画或削弱迟到响应隔离。

没有 Android 设备连接；未进行物理设备、Windows、真实账号只读/写入或签名发布验收。

## 同轮既有集成收口

核对并格式化前轮遗留的未收口 Rust 源码，修复作业能力 bridge 的 Clippy 冗余包装和
Flutter 作业测试 lint；FRB 按固定生成器重新生成，未手改绑定。
本地 FRB 漂移检查改为比较生成前后工作树，避免把合法未提交 API 变更与 HEAD 的差异误判成漂移。
其他前轮实现仍属于未发布工作树，不以此次借阅合成验证替代其真实验收。

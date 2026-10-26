# SPOC 作业文件能力集成与通路测试

## 交付范围

Android / Flutter + Rust 工作树实现，未发布，不开发冻结的 Apple 客户端。

- 作业详情增加独立“附件与提交”模块：教师附件、评分标准、允许方式/扩展名、提交次数、已提交文本/文件、退回状态及可用评阅附件。
- 附件有界二进制下载，经同一学校 Cookie / Token 会话。下载不跟随重定向，不向外部地址转交业务 token。Android 使用 ACTION_CREATE_DOCUMENT / SAF，由用户选择目标，无广泛存储权限；Windows 使用 file_selector 保存对话框。
- 文件选择、类型/大小校验、上传、明确确认、单次提交、回查及未知结果保护。客户端上限为 20 MiB，不代表学校上限；当前是有界内存传输，不宣称流式进度/后台续传。
- 普通构建可读取附件，**真实上传/提交默认关闭**。`experimental-homework-upload` Cargo feature 从 bridge → runtime → upstream 显式传递；实验功能仅支持明确个人作业、明确学生课程、开放期、次数已知及允许文件类型。演示实现不访问学校，可测试完整交互。
- 小组、文本/URL/录音/注释作答编辑暂不支持；已有文本/部分文件可读。附件元数据读取失败保留可识别条目，不伪称所有详情字段完整。

## 解耦结构

| 层 | 实现位置 | 边界 |
| --- | --- | --- |
| domain | `ports/homework_submission.rs` | HomeworkSubmissionSource、Workspace/Attachment/Receipt/Download 类型，无学校字段或 URL |
| core | `application/homework.rs` | 最小端口委托、文件限制、显式确认，不依赖 upstream |
| upstream adapter | `adapters/homework_files_http.rs` | 仅此处解释 SPOC 字段、认证头、form、multipart、文件 ID |
| upstream service | `services/homework_submission_service.rs` | 学生归属预检、账号/代次绑定、上传句柄、并发排他、提交前复读、写入日志与回查 |
| bridge | `api/live/homework.rs` | 账号预条件与 SESSION_ACCESS、时间预算、业务 JSON/二进制映射；不返回学校信封 |
| Flutter application | `application/homework_files.dart` | 独立 HomeworkFilesGateway，不把写接口强加给 AcademicGateway/已有假服务 |
| Flutter adapters | `infrastructure/*homework*`、Native/DemoMirrorService | native/demo 组装、业务模型解码、文件选择/保存平台适配 |
| Flutter UI | `homework_files_panel.dart` | 只消费业务字段，确认课程/作业/文件，账号或作业变化丢弃迟到结果 |

原 HTTP 文本请求继续兼容；新增 raw request bytes / binary response / response byte budget。reqwest 按响应块累计且检查上限；multipart 文件不经过 UTF-8 转码。请求 Debug 只显示字节数量，不输出 URL、headers 或文件内容。

## 写安全与限制

上传句柄仅在内存中存在，随机、绑定账号代次和作业、15 分钟有效；最多保留 8 条。上传成功不等于提交成功。最终提交前重新读取权限/次数，发送前先标记 Sent；超时、网络异常、调用取消后不能复用该句柄，待核实作业也禁止新上传。回查需文件 ID/方式匹配且 `ytjcs` 大于提交前计数，避免同一文件旧提交被误判为新提交成功。

这是进程内安全日志，不是持久化幂等协议。重启/重新登录/页面关闭后不能保证保留原回查句柄，必须先在官网核对，不能把“新上传可用”视为旧提交失败。上传取消可能产生孤儿文件，不猜测删除端点。教师在预检后即时改规则及跨设备并发由学校裁决。

## 协议证据与实验开关

上游证据仍以 API.md §7.1.1 及 [静态探查记录](2026-10-25-spoc-homework-submission-research.md) 为准。分片字段/尾片分组和响应分类为实验适配候选，合成测试只是明确约束本实现，**不提升为学校后端已验收事实**。本轮请求官网超时，没有新的真实写入证据。

开发环境显式检查实验构建：

```sh
cd rust
cargo check -p ginkgo_flutter_bridge --features experimental-homework-upload
```

普通 Android/Windows 打包不会自动带此 feature。正式放开前需授权的最终文件、指定作业、实际分片/合并/提交/回查脱敏验证，以及超时/格式/大小/权限失败验收。禁止使用空白占位作业验证写入。

## 已执行验证

- upstream homework_file 定向测试：12 项，含上传/合并/提交/回查、字节不变、尾片、账号/归属/扩展名拒绝、非法文件零请求、网络失败单次写、取消后句柄不重放、旧同文件计数不冒充成功、附件归属检查、WebVPN 不重发。
- 其中 1 项使用真实 ReqwestTransport + 本机 TCP socket，验证请求/响应的 `00 ff 0d 0a` 原样传输；不是外网 SPOC 验收。
- core 独立端口测试 1 项：只实现 HomeworkSubmissionSource 即可组装，未确认不调用上游。
- Flutter 新模块测试 6 项，含取消、未知结果回查及切换 gateway 后迟到文件选择不得上传。最终全量 Flutter 421 项通过。
- flutter analyze 通过；架构边界脚本与 git diff --check 通过；实验 feature 的 workspace 编译及相关 crate 全 targets clippy 通过。
- 最终 Android ARM64 Debug 正常入口 APK 构建通过（已在设备测试后重新构建，产物不是 integration_test 入口）。模拟器新增集成测试 1 项通过：实际加载 Rust/FRB 的读取、二进制上传参数、提交、回查、下载命令均安全拒绝未绑定账号且不发学校请求。这不是已登录成功写入测试。
- `cargo test --workspace` 存在一项非本次功能失败：`graduate_schedule_uses_gsmis_and_today_is_derived_from_the_snapshot` 预期第 7 周但实际第 8 周；未改该断言以掩盖失败。其他结果见命令输出，不宣称全 workspace 通过。
- 没有提交代码或发布版本；原有未提交修改保留。


## 后续真实只读验收（2026-10-26）

默认路线及 WebVPN 的 Rust 登录、列表、附件 workspace 与教师/已提交 PDF 下载已实测；修复错误沿用编辑页 `falg=xstj` 导致只读空内容问题，补回归后定向 13 项通过。详见 [验收记录](2026-10-26-spoc-live-read-acceptance.md)。真实上传/最终提交仍未执行，不改变实验开关边界。

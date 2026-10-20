# 镜像维护与耦合边界

> 2026-10-20。适用于 `rust/` 与 `flutter/` 镜像工程。Apple 端继续使用 SwiftUI，不引入 Rust 运行时；Apple 仍是产品与视觉参照。

## 1. 一个文件只承担一个变化原因

| 层 | 目录 | 只负责 | 不应出现 |
| --- | --- | --- | --- |
| 领域规则 | `rust/crates/ginkgo_core/src/features/` | 模型、筛选、合并、排序、错误语义 | HTTP、Cookie、UI 文案 |
| 基础能力 | `.../foundation/` | 时间、URL、Cookie、HTTP 抽象、WebVPN 编解码 | 业务模块分支 |
| 协议适配 | `.../adapters/` | 上游请求构造、传输实现、响应分类 | 页面状态、持久化 |
| 应用用例 | `.../application/` | 一次用户操作、会话、缓存/恢复/账号边界 | HTML 正则细节 |
| 认证 | `.../auth/` | `cas` 解析、`login` 登录链、`uc` 会话校验、`session` Cookie/路由、`platform/` 保险库 | 页面布局 |
| 桥接 | `rust/crates/ginkgo_flutter_bridge/src/api/` | DTO、稳定错误码、映射（`mirror.rs` 演示、`live.rs` 真实） | 业务规则、网络 |
| 页面 | `flutter/lib/`（`more_page`、`settings_page`、`library_page`、`checkin_page`、各功能页） | 布局、交互、可访问性、本地化 | Cookie、凭据、上游字段解析 |
| 设备验收 | `flutter/integration_test/` | 真实 FFI + 页面流程 | 领域规则断言以外的实现细节 |

约束：

- 新增模块按 `<module>.rs`（领域）、`adapters/<module>_http.rs`（协议）、`application/<module>_service.rs`（用例）、`bridge api/<module>.rs`（DTO）、`flutter/lib/<module>_page.dart`（呈现）拆分；任一文件接近 300 行或同时处理两个外部系统时先拆。
- 认证模块是模板：`cas.rs` 只解析登录页，`login.rs` 只走登录链与重定向，`uc.rs` 只做 UC 激活/校验，`session.rs` 只持 Cookie 与路由，`mod.rs` 只组合类型和用例。
- 共享测试桩放在 `rust/crates/ginkgo_core/src/test_support.rs`（`cfg(test)`），不要在每个适配器里重复 mock 传输。
- 桥接只暴露粗粒度用例。Dart 不得持有 Cookie、CASTGC、重定向链、iclass sessionId 或 booking.lib token，也不得复制筛选、时区、周次等规则。真实命令是 `login` / `restoreSession` / `signOut` / `sessionStatus` 与空教室/课表/今天/成绩/签到/图书馆只读查询；`verifyCredentialStorage` 只用于设备验收。
- WebVPN 路由下，`auth/session.rs` 负责把响应的 final URL 与 Location 还原成上游 URL；功能适配器只面对上游 URL。新增业务系统时不要自行 `unwrap` 响应或拼接网关地址，否则相对 Location 会被误判。
- 平台凭据保险库按平台拆文件：`auth/platform/android_vault.rs` 只做 JNI 调用，Kotlin `CredentialVault.kt` 只做 Keystore/SharedPreferences；`keyring_vault.rs` 只做系统钥匙串映射。不要把加密、账号解析或 UI 文案塞进桥接 DTO。

## 2. Fixture 与协议变更

1. 先改 [API.md](API.md) 的协议证据与修订表，再动实现。
2. 在 `fixtures/<domain>/` 新增版本化样例；`source` 只允许 `synthetic` 或 `redacted-upstream`，不得含真实学号、姓名、Cookie、票据或成绩。
3. 新契约先接入 `execute_contract`，让 `rust/crates/ginkgo_core/tests/contracts.rs` 递归执行；Swift 能读取的样例同时补 Swift 测试。
4. 结构漂移必须返回 `changed_response`，不得降级为空结果；上游业务错误与传输失败保持不同错误码。
5. 不允许为了通过测试直接改 `expected`；预期变化必须对应协议版本或明确的领域规则变更。

初始二十四类契约、76 份样例：`classroom.filter`、`classroom.parse_response`、`school_time.beijing_day`、`schedule.snapshot_retained_weeks`、`bykc.course_filter`、`auth.cas_login_page`、`auth.uc_status`、`schedule.terms`、`schedule.weeks`、`schedule.undergraduate_courses`、`schedule.exams`、`schedule.today_courses`、`grades.buaa_score`、`grades.term_parts`、`homework.spoc_page`、`homework.spoc_encrypt`、`checkin.app_login`、`checkin.course_schedule`、`library.login_user`、`library.venues`、`library.areas`、`library.slots`、`library.seats`、`library.bookings`。详见 [fixtures/README.md](../fixtures/README.md)。

## 3. 桥接维护

- 新字段优先做可加性扩展；删除/改义必须升级 contract 版本并同步 Swift 使用的黄金样例。
- 修改桥接 DTO 后必须运行 `scripts/generate-mirror-bridge.sh`，生成文件与 Rust/Dart 一起提交；禁止手改 `frb_generated.*`。脚本会拒绝 `stem: 'UNKNOWN'` 的生成结果（通常表示 codegen 的 `cargo metadata` 失败）。
- Android 端库名与 FRB 外部库 stem 必须保持一致（`ginkgo_flutter_bridge`）。`MainActivity` 先 `System.loadLibrary` 再初始化 Kotlin 保险库，`JNI_OnLoad` 负责缓存类引用；改动加载顺序必须重跑 `auth_test.dart`。
- 真实服务在第一次异步命令时懒初始化；不要在 `init_app` 中创建 `reqwest`/tokio 运行时。Android 上这样会卡在 Flutter 启动画面（2026-10-20 实测），`check-mirror.sh` 也不覆盖这一运行时行为。
- 错误只传稳定 `code` 与可选上游 `detail`；页面文案在 Flutter 本地化，Rust 不返回中文 UI 文案。
- 真实会话是 Rust 侧不透明对象；Flutter 只调“登录/查询/刷新/登出/路线/清缓存”等用户级命令。密码只在校验后的登录调用中瞬时经过 Form 状态，持久化由 `CredentialVault` 完成；成功登录后页面只保留会话摘要。
- 图书馆/签到现在是**只读**页面：真实只读用例 + 共享合成 fixture 的设备测试。禁止添加预约/签到/暂离/离馆/取消等提交入口，直到完成写操作评审（二次确认、提交后回查、未知结果不重发）；也禁止用页面上的只读数据推断写操作可用。

## 4. 证据分层

| 层级 | 证据 | 不能替代 |
| --- | --- | --- |
| L1 | Rust 领域/应用单元测试、mock HTTP | 设备与真实上游 |
| L2 | 共享 fixture 契约测试（Rust，必要时 Swift） | 真实页面 |
| L3 | Android 模拟器/真机 integration test（真实 FFI + UI） | Windows |
| L4 | Windows 主机构建与交互验收 | Android |
| L5 | 固定视口浅色/深色/大字号截图与交互复核 | 像素相似度结论 |
| L6 | 用户授权的真实账号只读验收 | 写操作验收 |

每条记录至少包含日期、命令/入口、结果和产物位置；构建成功不算 UI 通过，mock 通过不算真实上游通过。

## 5. 上游漂移与节奏

- 每个提交：`scripts/check-mirror.sh`；涉及桥接再跑生成脚本与 Flutter 集成测试。
- 每周：在模拟器跑一次 `flutter drive`，对比 `flutter/build/visual/` 的固定状态截图；检查 CAS/UC mock 是否仍覆盖新增分支。
- 每月：按 [API.md](API.md) 复核一次上游端点、字段与错误码；把变化先转到 fixture，再改两端实现。
- 新增模块完成定义：协议证据 + 领域/应用/桥接 + Android 与 Windows 验收 + 账号隔离/缓存/恢复测试 + 文档更新，缺一不可。

## 6. 推进顺序与依赖

1. **P1 认证 + 空教室真实只读**：`CredentialVault` 平台实现 → 真实会话 bridge → 空教室只读 bridge → 会话失效单次恢复。Android 已完成并实测；Windows/macOS 待实机。
2. **P2 课表/考试**：学期与教学周、本科课表/考试解析、真实只读与快照已完成 → 周网格 → 研究生课表 → 真实账号只读。
3. **P3 成绩、作业、BYKC、图书馆/签到、研讨室/场馆/通知**：成绩真实只读与页面已完成，学期切换/真实账号待补；签到与图书馆只读已完成（真实上游验收待用户本机登录）；作业仍为合成；其余按接口稳定度逐项迁移。
4. **P4 本地待办、设置、账号切换与平台适配**。
5. **P5 写操作**：签到、预约、取消、选课逐项协议评审，二次确认与“未知结果不重发”。

## 7. 风险与提前布局

- **真实上游验收仍不完整**：Android Keystore 与登录页已实测，2026-10-20 完成过一次真实今天/课表/空教室/成绩只读；签到/图书馆的真实只读尚未执行，验证码图片 UI 也未完成。把 mock 和合成设备测试当真实通过是明确红线。
- **iclass 依赖 WebVPN 网关会话**：直连 iclass 在当前网络 TLS 连接超时；网关 CAS 会话需要登录时保存的密码。没有保存密码时签到只读会要求重新登录，不能用无限重试掩盖。
- **Windows/macOS 钥匙串未实机**：`keyring` 适配已编译在 macOS，但 Windows 分支未在本机构建；macOS 未做签名/授权提示验收。Windows CI 通过也不能替代交互验收。
- **Windows 未实机**：CI 与工程入口已创建，但不能用 macOS/Android 结果替代；布局参照 macOS 时需固定窗口尺寸和最小宽度。
- **像素一致性**：Flutter 材质与 SF Symbols 存在不可共享差异；以固定状态、固定视口截图为证据，不宣称“100% 相似”。
- **上游漂移**：CAS 页面、UC 状态、WebVPN 编码都可能变化；认证 fixture 与 Swift/Rust 同源测试是提前量。
- **性能**：应用为 I/O bound；不因性能引入额外架构复杂度，但真实传输必须保持 30 秒超时、无自动重定向和单次恢复上限。
- **设备渲染**：headless + SwiftShader 的 Android 模拟器会让 integration_test 的 `pump` 长时间不返回；设备验收使用带窗口的硬件 GPU 模拟器（本机 `-gpu host`）。这属于测试环境问题，不应通过放宽业务断言绕过。

2026-10-20本轮扩展到35类108份：新增SPOC详情、BYKC信封/目录、研究生执行报告、待办文档、校园通知、CGYY场馆/时段/订单；均已登记contracts router，保留正常/空/漂移/拒绝或无效文档覆盖。设备每模块只运行独立smoke，不重跑已知mirror长流程。

公共统计新增独立短生命周期Session，只借用transport并复制用户原始路线偏好，不复制业务临时回退状态或登录Cookie；37类/118份合成契约。页面仅解码桥接JSON投影，不在build解析HTML；没有自动轮询或趋势持久化。

本轮工具记录：临时预览的flutter run若未分配TTY，stdin不可热重载；使用明确PID的SIGUSR1（reload）/SIGUSR2（restart）。main里的外观参数需要restart。Flutter测试必须以flutter/为工作目录；启动widget初次从仓库根误运行未执行，改目录后8项通过。均未放宽断言。

调试器评估可能在Flutter build栈中执行：直接调用submit触发setState during build，且在网络调用前终止。诊断操作应排入Future.microtask或正常UI事件，不把探针错误归因上游。真实输入仅通过无回显stdin进入正常表单，未放入文件/命令参数。

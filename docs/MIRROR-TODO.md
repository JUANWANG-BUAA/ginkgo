# Rust + Flutter 镜像迁移待办

> 更新时间：2026-10-20 晚。执行口径以 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) 和 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md) 为准；勾选必须有代码、测试或验收记录作为证据。真实账号验收必须由用户单独授权，自动化测试不得使用真实密码。

## 当前目标

今天/空教室/课表/成绩/作业五个离线切片已建立，今天/课表/成绩/作业已过 Android 真实 FFI 设备测试。真实登录链路已经落地：Android Keystore 保险库、bridge 登录/恢复/登出、Flutter 登录页与演示模式；空教室、课表、今天和成绩已接到真实只读 use case，作业仍为合成切片。当前主线转为“授权后的真实账号只读验收 + Windows 实机 + 剩余只读模块”；认证、Cookie 与 WebVPN 全程留在 Rust，Flutter 只保存页面状态和展示本地化结果。

## P0 · 基线与交付门禁

- [x] 读完 `ROADMAP.md`、`ARCHITECTURE.md`、`API.md`、`IOS.md`、`IMPROVEMENTS.md` 与镜像专项文档。
- [x] 建立 Rust workspace、共享 fixture runner、FRB 2.12.0 桥接和 Flutter Android/Windows 壳。
- [x] 完成空教室离线规则、筛选/排序、详情、缓存 TTL、错误与恢复的 Rust + Flutter 切片。
- [x] `scripts/check-mirror.sh` 本地通过：Rust format/clippy/test、Flutter analyze/widget test。
- [x] Android 模拟器运行真实 FFI 集成测试并保存设备结果（今天、课表、成绩、作业通过；空教室前 3 项通过）。
- [x] Android 新增 `auth_test.dart`：平台保险库两次写入/读回/删除往返、无账号时登录页启动，均通过。
- [ ] 补跑空教室剩余设备流程（校区/日期/缓存/错误/深色大字号）。
- [ ] Windows 主机构建与集成测试通过；macOS 结果不能替代 Windows 验收。
- [ ] 补齐当前空教室截图的固定视口视觉复核记录，区分“结构通过”和“像素近似”。

## P1 · 真实认证与空教室

- [x] 实现 Rust 进程内 Cookie 会话与 CAS/UC 登录用例；凭据经 `CredentialVault` 注入，不进入 Flutter。
- [x] 实现 UC 会话确认、自动/直连/WebVPN 路由和会话失效后的单次恢复（mock HTTP 验收）。
- [x] 实现 Android Keystore 的 `CredentialVault`（Kotlin AES-GCM + JNI），开放 bridge 登录/恢复/登出入口。
- [x] 实现 Windows Credential Manager / macOS Keychain 的 `keyring` 适配（代码完成；Windows/macOS 未实机）。
- [x] 将空教室 bridge 从合成仓库切换到真实只读用例，同时保留明确的离线演示入口。
- [x] 为应用层补齐 5 分钟快照、强制刷新、失败保留旧结果、账号切换/登出清空快照的 mock 测试。
- [ ] 为 mock HTTP 补齐超时、断网、认证跳转、旧结果保留和重试边界测试（认证跳转、5xx 保留 Cookie、单次恢复已覆盖；超时/断网仍待补）。
- [ ] 验证码图片与输入页面（当前只有挑战提示和手填输入框）。
- [ ] 经用户单独授权后进行真实账号只读验收；不执行任何预约、占用或写操作。

## P2 · 课表与考试

- [x] 扩充本科生学期、教学周、周课表、考试的共享 fixtures（含空结果与类型漂移）。
- [x] 在 Rust 迁移本科课表模型、解析与请求构造；Dart 不解析上游字段。
- [x] 实现移动端课表 Tab 与桌面端侧栏入口，覆盖加载、空周课表与未缓存周次。
- [x] 周网格/列表双视图与课程详情。
- [x] 课表真实只读 use case：门户探测、学期/周/课程/考试、快照、失败保留、单次恢复（mock 验收）。
- [ ] 研究生 GSMIS 解析与页面、学期切换 UI。
- [ ] 验证跨北京时间午夜、学期切换、缓存周次刷新和旧快照保留的设备验收。

## P3 · 其余只读模块

- [x] 成绩：GET/POST 请求、类型漂移解析、本科/研究生学期码归一化与汇总。
- [x] 成绩真实只读 use case：默认学期发现、缓存、失败保留、单次恢复（mock 验收）。
- [ ] 成绩：学期切换 UI、真实账号只读验收。
- [x] 学校作业：SPOC 分页加密、列表解析、状态筛选与合成页面。
- [ ] 学校作业：token/CAS 登录链、课程/学期上下文、只读详情；希冀来源在证据补齐前保持关闭。
- [ ] BYKC：学期策略、课程目录、搜索/类别规则与页面。
- [ ] 图书馆、研讨室、场馆和校园通知：按接口稳定度逐项补齐只读路径与失败分类。
- [x] 今天页：BYXT 当天课程解析、日期/星期与时间线页面（不复制筛选/周次规则）。
- [x] 今天页真实只读 use case：快照、失败保留、单次恢复（mock 验收）。
- [ ] 今天页：跨北京时间午夜、真实账号只读与空课确认。

## P4 · 本地功能与设置

- [ ] 本地待办、设置、账号切换和缓存清理。
- [ ] 平台凭据保险库的通知权限、外链与日志脱敏适配器。
- [x] 手机五 Tab（今天/空教室/课表/作业/成绩）与桌面侧栏入口。
- [x] Flutter 登录页、会话恢复门禁、退出登录与显式离线演示入口。
- [ ] 登录后“已登录但未能保存密码”的用户提示。
- [ ] 深色、大字号、TalkBack/VoiceOver 与减少动态效果的全模块闭环。

## P5 · 写操作与发布

- [ ] 签到、预约、取消、选课等写操作逐项做协议证据、二次确认、提交后回查与“未知结果不重发”测试。
- [ ] Android/Windows 安装、升级、签名、隐私说明和发布流水线验收。
- [ ] 更新 `MIRROR-IMPLEMENTATION.md` 的完成矩阵；只有双平台验收后才标记模块完成。

## 下一步

1. 由用户授权做一次真实账号只读验收，先空教室/今天，再课表/成绩；全程不触发写操作。
2. 补验证码图片链路（传输、缓存、Flutter 展示与刷新）。
3. 在 Windows 主机完成构建、Credential Manager 往返和页面验收；再补 macOS Keychain 记录。
4. 真实作业 SPOC token/CAS、详情与希冀来源关闭策略；随后研究生课表、BYKC 和图书馆只读。

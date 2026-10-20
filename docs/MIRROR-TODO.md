# Rust + Flutter 镜像迁移待办

> 更新时间：2026-10-20。执行口径以 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) 和 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md) 为准；勾选必须有代码、测试或验收记录作为证据。

## 当前目标

先把空教室从离线合成切片推进为可验证的真实只读用例，再按依赖顺序迁移课表/考试、成绩、作业、BYKC 和校园服务。认证、Cookie 与 WebVPN 全程留在 Rust；Flutter 只保存页面状态和展示本地化结果。

## P0 · 基线与交付门禁

- [x] 读完 `ROADMAP.md`、`ARCHITECTURE.md`、`API.md`、`IOS.md`、`IMPROVEMENTS.md` 与镜像专项文档。
- [x] 建立 Rust workspace、共享 fixture runner、FRB 2.12.0 桥接和 Flutter Android/Windows 壳。
- [x] 完成空教室离线规则、筛选/排序、详情、缓存 TTL、错误与恢复的 Rust + Flutter 切片。
- [x] `scripts/check-mirror.sh` 本地通过：Rust format/clippy/test、Flutter analyze/widget test。
- [ ] Android 模拟器运行真实 FFI 集成测试并保存设备结果。
- [ ] Windows 主机构建与集成测试通过；macOS 结果不能替代 Windows 验收。
- [ ] 补齐当前空教室截图的固定视口视觉复核记录，区分“结构通过”和“像素近似”。

## P1 · 空教室真实只读用例

- [x] 为上游响应补充正常、空结果、业务错误、缺字段和类型漂移共享 fixtures。
- [x] 迁移 SSO 激活与 `buaafreeclass/search1` 请求构造，使用可注入 HTTP transport 做 mock 测试。
- [x] 迁移响应校验：登录页/401/403、非零 `e`、JSON 结构变化、空 `kxsds` 与非法节次必须产生不同错误。
- [x] 实现 Rust 进程内 Cookie 会话与 CAS/UC 登录用例；凭据经 `CredentialSource` port 注入，不进入 Flutter。
- [x] 实现 UC 会话确认、自动/直连/WebVPN 路由和会话失效后的单次恢复（mock HTTP 验收）。
- [ ] 实现 Android Keystore / Apple Keychain 的 `CredentialSource`，并开放 bridge 登录入口。
- [ ] 将空教室 bridge 从合成仓库切换到真实只读用例，同时保留明确的离线演示入口。
- [ ] 为 mock HTTP 补齐超时、断网、认证跳转、旧结果保留和重试边界测试（认证跳转、5xx 保留 Cookie、单次恢复已覆盖，超时/断网仍待补）。
- [x] 补齐认证共享 fixtures：CAS 登录页（含验证码）与 UC 会话有效/无效/结构漂移。
- [ ] 经用户单独授权后进行真实账号只读验收；不执行任何预约、占用或写操作。

## P2 · 课表与考试

- [x] 扩充本科生学期、教学周、周课表、考试的共享 fixtures（含空结果与类型漂移）。
- [x] 在 Rust 迁移本科课表模型、解析与请求构造；Dart 不解析上游字段。
- [x] 实现移动端课表 Tab 与桌面端侧栏入口，覆盖加载、空周课表与未缓存周次。
- [ ] 周网格视图、研究生 GSMIS 解析与页面、学期切换 UI。
- [ ] 验证跨北京时间午夜、学期切换、缓存周次刷新和旧快照保留（周次切换与北京时间已有测试，其余待补）。

## P3 · 其余只读模块

- [x] 成绩：GET/POST 请求、类型漂移解析、本科/研究生学期码归一化与汇总。
- [ ] 成绩：学期切换 UI、缓存和真实账号只读验收。
- [ ] 学校作业：SPOC 分页、时间字段、只读详情；希冀来源在证据补齐前保持关闭。
- [ ] BYKC：学期策略、课程目录、搜索/类别规则与页面。
- [ ] 图书馆、研讨室、场馆和校园通知：按接口稳定度逐项补齐只读路径与失败分类。
- [x] 今天页：BYXT 当天课程解析、日期/星期与时间线页面（不复制筛选/周次规则）。
- [ ] 今天页：跨北京时间午夜、真实账号只读与空课确认。

## P4 · 本地功能与设置

- [ ] 本地待办、设置、账号切换和缓存清理。
- [ ] 平台凭据保险库、通知权限、外链与日志脱敏适配器。
- [ ] 手机五 Tab、桌面侧栏、深色、大字号、TalkBack/VoiceOver 与减少动态效果。

## P5 · 写操作与发布

- [ ] 签到、预约、取消、选课等写操作逐项做协议证据、二次确认、提交后回查与“未知结果不重发”测试。
- [ ] Android/Windows 安装、升级、签名、隐私说明和发布流水线验收。
- [ ] 更新 `MIRROR-IMPLEMENTATION.md` 的完成矩阵；只有双平台验收后才标记模块完成。

## 下一步

1. 完成 Android 设备验收（已定位：headless + SwiftShader 会使 Flutter live test 的 `pump` 卡住；改用带窗口硬件 GPU 模拟器）。
2. 实现平台凭据 store 与 bridge 登录入口，接通真实传输与会话对象。
3. 接通空教室真实只读 bridge，并继续 P2 的周网格/研究生课表。

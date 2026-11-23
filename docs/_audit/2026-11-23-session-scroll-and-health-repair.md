# 2026-11-23 会话恢复、全站滚动、并发合流与实时接口看板修复

## 1. 修复范围概览

本轮围绕 Android 客户端核心交互稳定性、会话生命周期、冷启动并发效率与实时接口可观测性完成全链路收敛：

1. **即时退出登录与无损重登通路**：
   - `main.dart` 的显式退出立即写入 `explicitSignOut`、清空内存遥测并切回登录页，不再等待慢速在途读锁释放，后台注销在后续登录前串行收尾；设置页拆分独立忙状态。
   - 新增 `SessionReauthScope`（`application/session_reauth.dart`）与 `GinkgoRoot.reauthenticate`：学校会话过期（`sessionExpired`）时，可从首页状态栏、实时接口看板或设置页一键返回登录页并保留系统安全存储中已记住的学号与密码。
2. **记住密码开关持久化与凭据回填**：
   - `display-preferences-v1.json` 新增 `rememberPassword` 布尔开关（不含任何凭据明文）；
   - 新增只读桥接 `load_saved_credential`（`SavedCredentialGateway`），未显式退出时自动回填学号与密码且不清空待作答验证码；`CredentialVault.kt` 增加密钥异常单次自愈。
3. **Android 全站下拉刷新与滚动防抖**：
   - `app/ginkgo_app.dart` 统一配置 `GinkgoScrollBehavior`（未开启减少动态效果时使用 `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`），修复 Android 下 `CupertinoSliverRefreshControl` 无法触发下拉刷新的问题；
   - 移除 `TodayPage`、`GradesPage` 与 `GraduatePage` 包裹长列表的 `SliverLayoutBuilder` 逐像素重算，消除滚动至底部的布局震荡。
4. **提醒开关门禁、冷启动并发合流与门禁超时收敛**：
   - `ReminderController.refresh` 补齐 `checkinEnabled` 与 `homeworkEnabled` 门禁及票据代次校验，关闭对应开关后不再发起轮询；
   - `native_command.dart` 与 `ginkgo_flutter_bridge/src/api/live/{academic,homework}.rs` 对并发非强制读取（`forceRefresh == false`）执行 Singleflight 合流，避免冷启动重复认证与 token 竞争；
   - `UpdateGate.fetch` 收紧连接超时与总墙钟上限至 `1.8s`，并与 `PackageInfo` 并行读取。
5. **本人借阅 WebVPN 重定向解包、本科课表错误透传与课程签到能力更新**：
   - `library_loans_http.rs` 复用 `auth::redirect::resolve_get` 解包 WebVPN `Location` 跳转并识别网关登录页，`library_loans_service.rs` 对 `"webvpn_login_required"` 执行单次网关会话恢复；
   - `schedule_service.rs` 在确认本科生门户（`Portal::Undergraduate`）后直接透传 BYXT 错误，不再误滑落至研究生 GSMIS；
   - 课程签到调整为按需获取实时签到码矩阵（支持单张覆写保存至系统相册）与状态只读回查。
6. **全局同步状态栏与实时接口可用性看板**：
   - 新增内存级 `ServiceHealthTracker` 被动记录 18 类学校与公开接口的状态、耗时与缓存命中（不含 URL、正文或账号标识）；首页顶部增加紧凑状态栏，网络诊断页支持实时总览与 13 项常用接口整体/单行测速。
   - 纳入已验证路线展示与设置页同账号验证后换线、冷启动备用路线恢复改进（经维护者明确授权同步网络冻结清单修订哈希）。

## 2. 验证证据

- `cargo fmt --check`、严格 `clippy -D warnings`、`ginkgo_core` / `ginkgo_upstream` / `ginkgo_flutter_bridge` 全量测试通过；
- `flutter analyze --no-pub`、全量 Flutter 单元与组件测试、FRB 零漂移校验、架构/设计 token/UI 语言/接口索引/架构快照/协议契约门禁全部通过；
- 正常入口 Android ARM64 构建通过。真实账号、学校写操作与物理真机仍按既有验收边界保留。

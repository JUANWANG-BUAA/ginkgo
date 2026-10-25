# Android Alpha.8 发布记录（2026-10-25）

## 范围与发布边界

版本 `0.1.0-alpha.8+9`，标签 `android-v0.1.0-alpha.8`；不移动 Alpha.7，不发布 Apple/Windows，不改 `docs/update-gate.json` 的 `minBuild`（仍 5）。

Alpha.7 tag 之后共 20 个提交，用户可见范围：图书馆公开查书与馆藏、校车时刻表官方入口、作业提交状态与倒计时修复、视觉语言与图书/校车页重做、导航强调色与预约按钮重做。本轮收口另含不改变用户可见行为但影响可靠性的修复（读超时上界、上游账号复检、刷新补跑、跨断点导航保活、CGYY 模块级写锁、解码收口重构、android-v* 构建校验 workflow）。

学校写操作仍逐次人工触发，本轮未使用真实学校账号、未发送任何预约/取消/签到。

## 全量门禁（首次覆盖整个测试集）

`bash scripts/check-mirror.sh` 完整通过：架构边界与自测、`cargo fmt --check`、严格 Clippy、core/upstream/workspace 测试（20 个 test result 全部 ok）、`flutter analyze` 零告警、`flutter test test` **383 项全部通过**。日志 `/tmp/ginkgo-alpha8-gate2.log`。

首轮门禁暴露 6 个**存量**失败（Alpha.7 之后的实现变更没有同步测试），全部定性为测试与实现脱节并修复，未放宽任何业务断言：

| 失败 | 根因 | 处理 |
|---|---|---|
| `reservation_components` ×2 | 视觉语言重做把按压目标从 0.97 改为 0.96、busy 叶片 17 改为 16 | 更新断言值 |
| `accent_theme` | 偏好快照新增 `explicitSignOut`（安全标记，非显示设置） | 期望键集补该键 |
| `library_progressive` | controller 改为「强制刷新链式补跑」，测试仍假设两次刷新合流 | 按分区独立补跑重写 |
| `refresh_audit` ×2 | `RefreshSection` 同上的语义变化导致 `await` 永不完成（挂死 10 分钟） | 按链式补跑重写并显式完成补跑请求 |
| `session_widget` ×2 | 偏好写入是真实平台通道，`testWidgets` 的 fake-async 中 `await` 永久挂起；tearDown 又 `await` 同一串行保存链 | 写入改用 `runAsync`，tearDown 只清内存标记 |

另给共享 `phone` helper 的 `pumpAndSettle` 加上限，坏页面不再伪装成十分钟静默等待。

## 签名产物与校验

`flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`（`--pub` 是刻意的：Alpha.7 曾因 `--no-pub` 生成引用 `integration_test` 的注册器而构建失败）。

实际核验：
- 包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName 0.1.0-alpha.8`、`versionCode 9`、仅 `arm64-v8a`、`minSdk 24`/`targetSdk 36`；
- `GeneratedPluginRegistrant` 零处引用 `integration_test`；
- 无 `application-debuggable` 标记；
- `zipalign -c -P 16 -v 4` 通过，`apksigner verify` 通过；
- 证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Alpha.6/7 官方一致；
- APK SHA-256 `08ce270e3490d0499e1d5305cc84926fac8c0d215f4060adaad7748bf5ee8712`（41.6 MB）。

## 签名包覆盖升级验收（模拟器，已通过）

基线为官方 Alpha.7（`android-v0.1.0-alpha.7` 资产，SHA-256 `7ae0a8f7…` 校验一致，41,267,072 字节）。模拟器原有包装的是非正式密钥，先卸载后装官方 Alpha.7，避免把「签名不一致」误判为产品缺陷。

实测结论：

| 项目 | 升级前（Alpha.7） | 升级后（Alpha.8） |
|---|---|---|
| versionCode | 8 | **9** |
| versionName | 0.1.0-alpha.7 | **0.1.0-alpha.8** |
| firstInstallTime | 2026-10-25 12:18:33 | **12:18:33（保留）** |
| lastUpdateTime | 2026-10-25 12:18:33 | 12:20:49（更新） |

应用数据保留：升级前在离线演示创建本机待办 `ALPHA8-SENTINEL`，`adb install -r` 覆盖安装并冷启动后，工作台仍显示「个人待办 · 1 项未完成 / 无截止时间 / ALPHA8-SENTINEL / 个人事项 · 未完成」。这是签名包覆盖升级的真实往返，不是 widget 或 Debug 包代替。

截图保存在本机 `~/artifacts/local/android-alpha8/`（只含合成数据，不入库）。

## 仍未覆盖（不得当作已验收）

- 物理设备（本机仅有 ARM64 模拟器）：TalkBack、预测返回、大字号/深浅色、长列表帧率、厂商省电与通知恢复。
- 真实学校账号的写操作（签到、图书馆预约/取消、CGYY 预约/取消）与真实非空订单未在本轮验收。
- 校车动态余票维持不接入（`docs/API.md` §6C）。

## 公开

标签与 GitHub prerelease 在维护者本机执行提交后推送；公开时间与资产摘要以 GitHub Release 为准，不在文档中预写。

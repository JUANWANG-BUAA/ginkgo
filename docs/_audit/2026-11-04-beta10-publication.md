# Android Beta.10 发布记录

## 用户指令与发布方式

2026-11-04（America/Los_Angeles），用户明确纠正“不是为什么不发？不是说了现在不能做真实账号测试了，这些都不要了吗”。本次按用户指令执行手动发布例外：继续暂停真实账号和学校请求，不再以这些未执行项目推迟公开测试版。未完成的物理设备、学校写入与安全人审不冒充已验收，正式 readiness 保持 blocked；不修改发布门禁，不解冻网络与认证链，不提升 minBuild。

版本 `0.1.0-beta.10+20`，正常 `lib/main.dart`、Android ARM64、现有外部发布证书；标签 `android-v0.1.0-beta.10`。已于 2026-11-05T04:58:58Z 公开 prerelease。签名产物、覆盖安装、公开回下载、CI 和 Pages 的实际结果在下方分别记录。

## 候选范围与既有证据

统一页面信息层级、分组、图标、深色与大字号适配及按压回弹；修正博雅与 CGYY 服务替换后的旧响应隔离；包含此前尚未公开的后台提醒、恢复提示和非认证生命周期修复。共享认证/HTTP/Cookie/路线实现保持冻结；仅按具体授权修复无效 UBAA 回归测试。完整范围见[代码与视觉审计](2026-11-04-beta10-code-and-visual.md)。

版本升级前的最终完整本地门禁通过，含 Rust fmt/Clippy/workspace、22/22 已知错误变体、Flutter analyze/854 项测试、文档及 FRB 零漂移。21 个工作区目的地、101 个基础场景、704 张四模式系统截图及 18 张动效过程截图已复看，设备合成业务/导航与后台闭环通过。版本号提升不改变 UI 组件和学校实现；本次签名构建及远端 CI 单独记录，不将旧日志写成本次远端或真实账号结果。

## 已知问题

本人借阅仍可能提示认证、权限或服务错误，本版尚未修复读者认证根因。仅改进恢复指引与脱敏诊断，不建议反复重新登录。真实账号、学校写入和物理设备验收继续未执行；周期后台任务不保证实时通知。

## 签名产物与公开元数据

- 发布标签指向 `da3e65b25092be0906016451b1803304cb6e51b5`；发布为非 draft 的 prerelease，三个资产均 uploaded。
- 版本提升后的候选源码摘要 `492b351ab3087d19e7ffa9f5cae0e478a473a29f2af501b9545e7bd4888c4615`；协议摘要 `e18b925e1603938ab8fbcdf4c61fa5d91710575a7d7b1870f9adeb03c592ac19` 不变。
- 正常 `lib/main.dart --pub` ARM64 Release 构建通过（`artifacts/local/beta10-review/release-build.log`）。aapt 确认 versionCode 20 / versionName 0.1.0-beta.10、MainActivity、非 debuggable、仅 arm64-v8a；生产注册表无 integration_test。zipalign 16KiB、apksigner 验证通过。
- APK 44,566,129 字节；SHA-256 `08db1ee482c2cde8805d4f6e06d762240395803a6a3b3a049245860ddf42bd25`。外部签名证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与公开 Beta.9 一致，无 Debug 签名回退。
- 隔离 `emulator-5580` / API 37 / 飞行模式：从公开 Beta.9 安装，进入离线演示设置深色与蓝色后，`adb install -r` 覆盖 Beta.10 成功；UID 保持、versionCode 19→20、冷启动正常，再进显示页确认蓝色和深色保留。截图已复看，证据 `artifacts/local/beta10-release/upgrade.json` 与 `beta10-upgrade-preferences.png`。该结果仅为无账号模拟器覆盖升级，不代表物理设备或真实账号数据迁移。
- 首次升级脚本使用旧 Android dumpsys 的 userId 字段未找到而停止，尚未安装新包；改用 `cmd package list packages -U` 的当前字段后重新完成上述检查，没有将脚本失败记为产品失败或通过。

## 远端检查

PR #6 的 Mirror run `41970163465`：contracts、Android、FRB bindings 已通过，Windows 集成检查运行中。macOS run `41970163455`、iOS run `41970163523` 通过。

Tag Android Release run `41971104700` 按保留的正式 readiness 在签名前失败。本次产物来自本机既有外部证书手动签名，未称为 CI 签名通过，未修改门禁。完整 readiness 和缺失证据继续保留，用户的真实账号暂停指令不被记作真实通过。

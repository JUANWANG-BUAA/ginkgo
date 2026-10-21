# Android Alpha 安装与验收

> **历史归档（2026-10-21 收敛）**：本文保留当时的实现、计划或验收证据，文内“当前”与计数仅适用于原记录。最新状态见 [实施现状](../../MIRROR-IMPLEMENTATION.md)、[待办](../../MIRROR-TODO.md)、[功能对照](../../MIRROR-PARITY.md)。普通文字中的源码路径仍以仓库根目录为基准。

> 当前新版已发布：[Android Alpha.2](MIRROR-ANDROID-ALPHA2.md)。本文以下保留 Alpha.1 的历史发布记录。

版本：`0.1.0-alpha.1`（build 2），GitHub tag `android-v0.1.0-alpha.1`。
适用：Android arm64，Android 7.0+（minSdk 24）。此包不适用于 Windows/iOS/macOS。

本文件描述已公开的 Alpha.1 包，以下“未迁移 / 关闭”不代表后续工作树状态；2026-10-21 源码更新与验收见 [本轮验收](MIRROR-ACCEPTANCE-2026-10-21.md)，不据此宣称更新包已发布。

## 下载与安装

在手机浏览器访问 [Android Alpha 发布页](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.1)，下载 `Ginkgo-0.1.0-alpha.1-android-arm64.apk`，打开后按 Android 系统提示安装。无需 adb。`checksums.txt` 提供 SHA-256；应用本身不会自动下载安装。

本版使用独立 Android Alpha 签名。若装过 adb debug 签名包，系统不允许直接覆盖，需要先保存个人待办再卸载旧包；卸载会清除本地数据。以后 Alpha 使用同一签名并递增 build，即可覆盖升级。密钥保存在维护者本机仓库外，务必安全备份（见 MIRROR-MAINTENANCE）。

## 本版变化

- Cupertino 设置分组、缓存说明、真实安装版本、退出防重复。
- 运行自检：Rust桥接、本机目录写读删除、安全存储合成条目写读删除；可选图书馆公开网络，不读取密码、不上传诊断。
- 软件更新：GitHub公开请求、独立Android语义版本、正式/预发布过滤、资产与可信来源检查、刷新失败保留旧结果、浏览器打开发布页。
- release启用必要网络权限，保留Rust JNI调用的安全存储类名，release构建强制使用外部签名。

## 验证与边界

本机门禁：143 Rust core lib、1契约、1 bridge；Clippy、Flutter analyze、38 Flutter测试通过。Android aarch64 bridge编译通过。签名release与设备验证结果如下。

本次没有登录真实账号。此前的只读学校接口验收范围见 MIRROR-FULL-AUDIT；本科账号、非空成绩、Windows及全模块无障碍未完成。没有“与macOS100%对齐”保证。

上游签到提交、预约/取消/离馆、BYKC选退课、作答与上传全部关闭。统计趋势、SPOC教师/附件、BYKC已选/完成统计、研究生学分地图、提醒/验证码等仍有差距。macOS应用内下载校验和自动安装不等于Android已实现。

### 设备结果

`settings_test.dart` 最终单项 smoke 72秒通过：设置浅/深/1.8倍字号、自检三项真实文件/JNI/桥接往返、GitHub公开实网更新查询。初次测试定位Key与导航root处理失败，文件自检曾发现不存在目录createTemp的问题并修复；未修改既有mirror_test或放宽断言。安全存储自检执行删除后再次读取确认不存在；测试框架结束后移除了测试安装，adb确认包不存在，因此其私有保险库也不保留。该smoke无真实账号，公开更新请求不是学校账号验收。


### 发布结果

2026-10-20（UTC）已公开 [android-v0.1.0-alpha.1](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.1)，源码提交 `2da161e`。APK 39,414,232字节，arm64-v8a/minSdk24/targetSdk36，versionCode2，正常main入口；无debuggable标志，INTERNET权限存在，APK v2签名验证通过。

- APK SHA-256：`63c5cf474d1a0c0f339d3b3d65c83214095dd4292e62710f4417420a5ef75bea`，GitHub资产digest一致。
- 签名证书SHA-256：`451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`。
- 实际安装该release包：登录入口→离线演示→设置→自检，Rust/文件/Keystore三项通过（验证R8保留JNI类）；发布后从该release包检查更新，识别Android 0.1.0-alpha.1并显示“当前已是最新 Android 版本”。无账号登录、无上游写操作。
- 浅色设置、深色自检、系统1.8字号自检已查看合成截图，均仅存/tmp；恢复字号1.0与浅色。冷启动恢复正常登录页。release不可run-as读取私有XML；自检已通过删除后复读不存在，无真实凭据输入。
- Flutter首次release引擎下载限速；同一Google官方源分段获取并匹配官方MD5，临时本地Maven仅供应此官方引擎，构建54秒完成；未修改仓库依赖源。使用Android Studio JBR，未使用系统不兼容的Java27。

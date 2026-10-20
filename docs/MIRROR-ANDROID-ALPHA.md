# Android Alpha 安装与验收

版本：`0.1.0-alpha.1`（build 2），GitHub tag `android-v0.1.0-alpha.1`。
适用：Android arm64，最低系统版本以 APK manifest 为准。此包不适用于 Windows/iOS/macOS。

## 下载与安装

在手机浏览器访问 [Android Alpha 发布页](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.1)，下载 `Ginkgo-0.1.0-alpha.1-android-arm64.apk`，打开后按 Android 系统提示安装。无需 adb。`checksums.txt` 提供 SHA-256；应用本身不会自动下载安装。

本版使用独立 Android Alpha 签名。若装过 adb debug 签名包，系统不允许直接覆盖，需要先保存个人待办再卸载旧包；卸载会清除本地数据。以后 Alpha 使用同一签名并递增 build，即可覆盖升级。密钥保存在维护者本机仓库外，务必安全备份（见 MIRROR-MAINTENANCE）。

## 本版变化

- Cupertino 设置分组、缓存说明、真实安装版本、退出防重复。
- 运行自检：Rust桥接、本机目录写读删除、安全存储合成条目写读删除；可选图书馆公开网络，不读取密码、不上传诊断。
- 软件更新：GitHub公开请求、独立Android语义版本、正式/预发布过滤、资产与可信来源检查、刷新失败保留旧结果、浏览器打开发布页。
- release启用必要网络权限，保留Rust JNI调用的安全存储类名，release构建强制使用外部签名。

## 验证与边界

本机门禁：143 Rust core lib、1契约、1 bridge；Clippy、Flutter analyze、38 Flutter测试通过。Android aarch64 bridge编译通过。设备结果与签名/文件校验待当次构建结束补记。

本次没有登录真实账号。此前的只读学校接口验收范围见 MIRROR-FULL-AUDIT；本科账号、非空成绩、Windows及全模块无障碍未完成。没有“与macOS100%对齐”保证。

上游签到提交、预约/取消/离馆、BYKC选退课、作答与上传全部关闭。统计趋势、SPOC教师/附件、BYKC已选/完成统计、研究生学分地图、提醒/验证码等仍有差距。macOS应用内下载校验和自动安装不等于Android已实现。

### 设备结果

`settings_test.dart` 最终单项 smoke 72秒通过：设置浅/深/1.8倍字号、自检三项真实文件/JNI/桥接往返、GitHub公开实网更新查询。初次测试定位Key与导航root处理失败，文件自检曾发现不存在目录createTemp的问题并修复；未修改既有mirror_test或放宽断言。安全存储自检执行删除后再次读取确认不存在；测试框架结束后移除了测试安装，adb确认包不存在，因此其私有保险库也不保留。该smoke无真实账号，公开更新请求不是学校账号验收。

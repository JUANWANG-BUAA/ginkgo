# Android Alpha 2 候选包验收

候选版本 `0.1.0-alpha.2`（build 3），尚未公开发布。最终下载与校验和以正式发布记录为准。

独立候选分支 `release/android-alpha-2-candidate`：主工作区存在并行进行的BYKC/研究生修改，本次仅打包已提交修复。最终APK SHA-256 `a7a023807048dc57e669afa898e022f785354339804ef819a64cc80cdd995e98`；签名与Alpha1一致，已覆盖安装。亲自查看浅色与深色1.8倍字号签到画面：状态/详情/按钮不再重叠，未签到文字和圆圈在深色可辨。模拟器恢复浅色、字号1.0和正常登录入口，无真实账号输入。

## 本轮变化

- 普通 Wi-Fi 自动路线的并发回退修复：另一请求已切 WebVPN 时，本次失败读取仍能执行自己的单次回退；成功的认证恢复合并，连接等待上限6秒，主要只读链路总预算45秒。
- 图书馆场馆/当前预约和研究生学籍/报告分区显示，先完成的部分先更新；失败保留旧结果。
- 手动课程签到、图书馆座位预约/取消/入座/暂离/离馆入口，逐次确认、未知结果不重发、提交后回查；预约回查同步原页面。
- 登录输入与按钮对齐、密码显隐、签到状态布局与深色对比度、研究生学分进度、SPOC教师与BYKC目录详情。
- 官网提供可选第三方APK加速入口。

## 验收边界

本轮Rust完整基线151 core lib +1契约 +1 bridge、Clippy通过；Flutter完整44项通过后追加写操作和延迟渲染定向测试，最终相关回归单独通过，未重复跑已知不收敛的mirror设备测试。签到/预约独立设备合成smoke通过；真实账号尚未登录本轮候选包，不把合成或编译通过等同上游验收。

仍需普通Wi-Fi、自动路线下真实账号测量首次加载、缓存返回、强制刷新与页面即时更新。并发回退遗漏和预约回查未发布已有回归证据；用户“切页才刷新”的全部现象尚未真实复现。真实写操作由用户在确认页手动触发后验收，开发代理未执行真实签到或预约。

CGYY预约、BYKC选退课、附件上传、提醒、验证码图片、统计趋势、Windows实机及完整macOS对齐均未完成。

---

以下为已发布 Alpha 1 历史记录，功能范围不代表 Alpha 2：

# Android Alpha 安装与验收

版本：`0.1.0-alpha.1`（build 2），GitHub tag `android-v0.1.0-alpha.1`。
适用：Android arm64，Android 7.0+（minSdk 24）。此包不适用于 Windows/iOS/macOS。

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

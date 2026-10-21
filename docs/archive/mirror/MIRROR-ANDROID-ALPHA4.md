# Android Alpha.4 发布与升级记录

2026-10-21，版本 `0.1.0-alpha.4+5`，源码标签 [android-v0.1.0-alpha.4](https://github.com/JUANWANG-BUAA/ginkgo/tree/android-v0.1.0-alpha.4)。Android 7.0+ / arm64-v8a。

下载 [正式 APK](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-android-arm64.apk)、[SHA-256](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.4/checksums.txt)；[发布说明](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.4)。最新范围见 [实施现状](../../MIRROR-IMPLEMENTATION.md)。

> 评审来源：用户提供的代码、视觉与功能长评审由 **Opus 5.5** 撰写。本轮只采纳经源码和运行结果仍成立的部分；原评审中过时或不能由当前证据确认的结论未直接写成事实。逐项定位见 [Opus 5.5 评审落实](../../_audit/2026-10-21-opus-review-followup.md)，课程归属证据见 [SPOC 只读审计](../../_audit/2026-10-21-spoc-course-roles.md)。

## 用户可见改动

- 手机端统一到 iOS 式层级：大标题、分组卡片、触控尺寸、状态语义色和深浅色保持一致；桌面宽度使用 macOS 式分区 / 标题 / 说明 / 固定操作栏与更紧凑的卡片圆角。
- Android 返回手势增加一层工作区保护：从签到、课表、作业或预约等主页面返回时先回工作台；详情页面仍按导航栈逐层返回；工作台第一次返回只显示提示，退出提示窗口结束或切换页面后失效。
- 设置补齐显示与阅读、通知与后台、账号与隐私、软件更新、关于与致谢、UBAA 链接及系统分享。未接入的定时通知、后台签到轮询和品牌自启动不伪装成可用开关。
- SPOC 登录角色优先选择名称明确为“学生 / 本科生 / 研究生”的账号角色；按学校 SPA 的同系统学生 / 助教课程列表分类。已确认的助教课程默认收起，且不增加个人待完成统计；未知归属保留，并支持按账号隐藏课程。
- iClass 首次读取显示认证、应用会话、课程查询阶段和等待时间；隐藏课程只影响当前账号的本机列表，不修改学校状态。阶段信息只含本地耗时，不含账号、课程名、URL、Cookie 或 token。
- Android 更新页可在应用内下载安装包，支持暂停、断点续传、官方 GitHub 发布 / API 入口切换、SHA-256、包名、版本号与签名证书校验。安装仍由 Android 系统确认；没有自控国内 CDN 时，下载速度仍取决于 GitHub 连通性。
- 修复桌面各目的地返回栈被外层拦截的问题；宽屏目的地保留独立历史，再次选择当前目的地会回到该模块根页。

## 发布包

以普通 `lib/main.dart` 构建签名 Release，非 integration_test 入口：

```sh
cd flutter
flutter build apk --release --target-platform android-arm64 --target lib/main.dart
```

| 项目 | 结果 |
| --- | --- |
| 文件 | `Ginkgo-0.1.0-alpha.4-android-arm64.apk` |
| 文件大小 | 40,350,260 字节 |
| APK SHA-256 | `80d78ffb9e1a9bbcb768d73e9c6d827e8cda26c47f3c5c3dd13b94cd9fdd73f6` |
| 签名证书 SHA-256 | `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Alpha.1 / Alpha.2 / Alpha.3 相同 |
| versionCode | 5 |
| 最低 / 目标 SDK | 24 / 36 |
| 验证 | `apksigner`、`aapt`、16 KB `zipalign` 检查通过；无 debuggable |

## 验证边界

Android API 37 arm64 模拟器从已安装的 Alpha.3 正式包直接执行 `adb install -r`，成功覆盖为 Alpha.4，未卸载或清除本机数据。实际安装后验证：

- 离线工作台、预约页与设置可打开；深色外观、强调色和文本偏好保留。
- 从“预约”使用系统返回键或屏幕边缘返回手势，一次进入“工作台”；在工作台再返回只出现“再返回一次退出 Ginkgo”，应用没有立即退出。返回手势验证前后 `MainActivity` 始终为前台 Activity。
- 登录页、工作台、设置、显示与阅读页面无横向溢出；入口和实验能力文案与实际状态一致。

Flutter 静态分析、widget 测试、Rust Clippy / workspace 回归、Swift macOS 回归，以及 PD Windows 11 上的 Windows widget / 集成 / Release 构建均单独运行。上述结果不等于真实学校账号当前可登录，也不等于签到、预约或更新安装的学校侧写入已验收。发布后仍需在真实 Android 设备上从 Alpha.3 检查更新、允许未知来源、完成覆盖安装，并复验 GitHub 网络中断后的续传。

## 发布后复核

GitHub Release 的两个资产均为 `uploaded`；公开 APK 的 API 摘要与本地 APK、`checksums.txt` 均为 `80d78ffb9e1a9bbcb768d73e9c6d827e8cda26c47f3c5c3dd13b94cd9fdd73f6`，大小 40,350,260 字节。落地页在 390px 宽度自动读取到 `0.1.0-alpha.4`，APK、校验和与发布说明链接均指向本次标签，`scrollWidth == 390`，无横向溢出。

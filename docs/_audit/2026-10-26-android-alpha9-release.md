# Android Alpha.9 发布记录（2026-10-26）

## 版本与范围

版本 `0.1.0-alpha.9+10`，标签 `android-v0.1.0-alpha.9`；实现冻结提交 `987b4e5`。不移动 Alpha.8，不发布 Apple / Windows，不改 `docs/update-gate.json` 的 `minBuild`（仍为 5）。

本版从 Alpha.8 带入页面左右翻页、SPOC 学习只读、课程资料保存、个人文件作业入口、验证码挑战、研究生学分地图、课程／待办提醒、本人借阅、手机目录补齐和服务列表误报修复。课表控制区、周次大字号和已提交作业状态也完成设备复测。

本轮没有使用真实学校账号，没有签到、预约、取消、上传或提交。真实非空学习协议、本人借阅认证、校车实时余票和学校写操作仍未被此发布验证。

## 验证

`bash scripts/check-mirror.sh` 通过：架构规则与自测、Rust 格式与严格 Clippy、core / upstream / workspace 测试、Flutter 分析、**513 项 Flutter 测试**以及 FRB 重生成零差异。测试数量只属于本次运行。

Android ARM64 模拟器上的合成设备测试均通过：

| 测试 | 结果 |
| --- | --- |
| `integration_test/auth_test.dart` | 平台保险库合成往返与无账号启动登录页通过 |
| `integration_test/homework_files_test.dart` | 未绑定账号文件读取／上传／提交／回查／下载均拒绝且不联网 |
| `integration_test/learning_snapshots_test.dart` | Debug 构建的 Android Keystore AES-GCM 合成往返与清除通过 |
| AES-GCM host-JVM contract | 篡改、截断、大小边界、随机 nonce 与明文不出现在密文中通过 |

完整测试日志在维护者本机 `/tmp/ginkgo-alpha9-gate.log`、`/tmp/ginkgo-alpha9-auth_test.log`、`/tmp/ginkgo-alpha9-homework_files_test.log` 与 `/tmp/ginkgo-alpha9-learning_snapshots_test.log`。

## 安全收口

Android 可选加密学习快照的实现与合成设备往返已验证，但仓库要求的人工安全审查尚未完成。因此：

- Release 设置页不显示启用入口，Dart store 在 profile 构建中报告不支持；
- Android 原生通道在不可调试包中拒绝 `enable`、`load` 和 `save`，`enabled` 固定返回 false；
- Debug 合成能力与测试保留，方便后续审查和继续验证；
- 普通查询缓存、个人待办和凭据保险库行为不变。

高置信度令牌／私钥扫描覆盖 1,063 个可见文本文件，零命中。会话导出文件名加入 `.gitignore`，不随发布推送。

## 签名产物与校验

构建命令：

```sh
cd flutter
flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub
```

产物核验：

- 包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName 0.1.0-alpha.9`、`versionCode 10`；
- `minSdk 24`、`targetSdk 36`、仅 `arm64-v8a`，正常 `MainActivity` 入口；
- 无 `application-debuggable` 标记，`classes.dex` 未发现 `integration_test`；
- `zipalign -c -P 16 -v 4` 通过，`apksigner verify` 通过 v2；
- 证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Alpha.6／7／8 一致；
- APK SHA-256 `1909e88d874311e07950268e1da9fe80fc03044b213411eccf3738be97bd2d40`，`43,190,653` 字节。

公开资产名为 `Ginkgo-0.1.0-alpha.9-android-arm64.apk`，Release 同时提供 `checksums.txt`。

## 覆盖升级验收

在 `Ginkgo_Alpha7_Release_QA` ARM64 模拟器上，以官方 Alpha.8 签名包为基线。先创建仅含合成内容的个人待办 `ALPHA9-SENTINEL`，再执行 `adb install -r` 覆盖安装 Alpha.9：

| 项目 | Alpha.8 | Alpha.9 |
| --- | --- | --- |
| versionCode | 9 | **10** |
| versionName | 0.1.0-alpha.8 | **0.1.0-alpha.9** |
| firstInstallTime | 2026-10-26 21:53:46 | **21:53:46（保留）** |
| lastUpdateTime | 2026-10-26 21:53:46 | 21:55:24 |

冷启动重新选择离线演示后，工作台仍显示 `ALPHA9-SENTINEL`；设置页只保留普通“清除查询快照”，未暴露加密学习快照入口。该往返验证签名兼容、版本升级和本机待办保留，不代表真实学校业务验收。

## 仍未覆盖

- 物理 Android 设备、完整 TalkBack、预测返回、厂商省电与后台提醒恢复；
- 真实学校账号的学习非空公告／后页／测验、本人借阅认证、校车实时余票；
- 真实签到、图书馆预约、CGYY 预约、作业上传或学校提交；
- Windows 主机构建与集成测试；本版公开范围只有 Android。

## 公开

2026-10-26 14:05:26 UTC（北京时间 22:05:26），源码 `d8ab68c` 已推送 `main` 与 `feat/rust-flutter-mirror`，并创建 `android-v0.1.0-alpha.9` tag 与 [GitHub prerelease](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.9)。

公开资产：

- `Ginkgo-0.1.0-alpha.9-android-arm64.apk`，`43,190,653` 字节；GitHub API 记录的 SHA-256 摘要为 `1909e88d874311e07950268e1da9fe80fc03044b213411eccf3738be97bd2d40`，与本地签名包一致；
- `checksums.txt`，远端内容与上述 APK 摘要一致；
- GitHub Pages 首页已显示 `0.1.0-alpha.9`，下载、代理、校验和与 Release 链接均已切换。

标签触发的 `Android Alpha Release` workflow 在“Materialize external signing configuration”步骤失败，原因仍是仓库未配置四个 Android 签名 secret。这是 workflow 的 fail-closed 行为；本轮发布使用维护者本机外部签名配置构建并完成上述证书、摘要、对齐与覆盖升级核验，没有把 Debug 或未签名 APK 作为发布资产。

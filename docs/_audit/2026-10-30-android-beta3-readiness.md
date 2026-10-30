# Android Beta.3 候选准备与验收边界（2026-10-30）

## 范围与状态

候选版本 `0.1.0-beta.3+13`，计划标签 `android-v0.1.0-beta.3`。本轮是可靠性与体验修复版：兼容含字母学号的小写输入，恢复研讨室预约入口，优化空教室展示，修复验收端口漏注入和独立能力替换后的旧响应。当前仅构建并核验本地候选，**尚未推送标签或公开发布**。

## 自动化与设备证据

- `bash scripts/check-mirror.sh` 最终通过：Rust 格式、严格 Clippy、core/upstream/workspace 测试、架构与接口索引、FRB 零漂移、Flutter 分析和 647 项 Flutter 测试均通过。
- 新增研讨室写状态、学分地图、待办来源替换回归均先验证旧实现失败，再转绿；另证明替换学校来源服务不会取消本机待办读取。
- `flutter test integration_test/cgyy_test.dart integration_test/academic_learning_ux_test.dart -d emulator-5554` 两项通过。研讨室实际进入合成场馆、时段、订单和门锁页；学分地图实际渲染。测试后重新构建并安装正常 `main` Debug APK，设备未停留在测试驱动等待页。
- 正常入口启动只恢复到登录页；当前进程环境没有真实账号凭据，也没有可恢复的真实会话。因此小写研究生学号登录、真实非空数据和真实页面链路**本轮尚未复验**。没有执行学校写操作。

## Release 候选产物

构建命令：`flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`，使用本机既有外部签名配置，未回退 Debug 签名。

产物：`artifacts/local/android-beta3/Ginkgo-0.1.0-beta.3-android-arm64.apk`。

- 大小：43,835,741 字节。
- SHA-256：`847074a996020fc23a26eafaabc90d4a285f447cdb8694aad15d683440e48e05`。
- 包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName=0.1.0-beta.3`、`versionCode=13`，仅 `arm64-v8a`，非 debuggable。
- `GeneratedPluginRegistrant.java` 不含 `integration_test`；使用 `--pub` 和正常 `main` 构建。
- `zipalign -c -P 16 -v 4`、`apksigner verify` 和本地 `shasum -a 256 -c checksums.txt` 通过。
- 签名证书 SHA-256 为 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Beta.2 候选证书一致。

## 未完成的发布门禁

尝试以 `Ginkgo_Beta2_Release_QA` 独立模拟器验证 Release 覆盖升级；QEMU 冷启动反复报告主循环/CPU 线程无响应后以段错误退出，`emulator-5556` 未上线。这与 Beta.2 的干净 AVD 启动限制一致。因此 **Beta.2 Release → Beta.3 Release 覆盖升级、个人待办保留和 Release 启动仍未验收**，没有用卸载 Debug 应用来绕过签名差异或牺牲本机数据。

物理 Android 设备、TalkBack、大字号、厂商后台行为、真实账号只读、真实学校写入、远端 CI、公开资产回下载均未在本轮完成。公开发布前需由账号本人完成小写学号与核心页面复验，并在可用设备上执行同签名覆盖升级。学校写入仍须本人逐次指定对象并确认，代理不自动试单。`docs/update-gate.json` 未修改；新资产可下载前不得提高 `minBuild`。

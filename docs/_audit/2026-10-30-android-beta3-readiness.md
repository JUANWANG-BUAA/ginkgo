# Android Beta.3 发布与验收记录（2026-10-30）

## 范围与状态

公开版本 `0.1.0-beta.3+13`，标签 `android-v0.1.0-beta.3`。本轮是可靠性与体验修复版：兼容含字母学号的小写输入，恢复研讨室预约入口，优化空教室展示，修复验收端口漏注入和独立能力替换后的旧响应，并收敛跨页诊断提示和加载图标比例。标签与主分支已推送，GitHub Beta prerelease 已公开。

## 自动化与设备证据

- `bash scripts/check-mirror.sh` 最终通过：Rust 格式、严格 Clippy、core/upstream/workspace 测试、架构与接口索引、FRB 零漂移、Flutter 分析和 649 项 Flutter 测试均通过。
- 新增研讨室写状态、学分地图、待办来源替换回归均先验证旧实现失败，再转绿；另证明替换学校来源服务不会取消本机待办读取。诊断回归证明 `null` 不产生日志、页面错误只记录脱敏日志而不弹全局 Hint；加载图标回归证明非正方形紧约束下仍按正方形绘制。
- `flutter test integration_test/cgyy_test.dart integration_test/academic_learning_ux_test.dart -d emulator-5554` 两项通过。研讨室实际进入合成场馆、时段、订单和门锁页；学分地图实际渲染。测试后重新构建并安装正常 `main` Debug APK，设备未停留在测试驱动等待页。
- 账号本人随后使用小写研究生学号完成真实登录。正常入口中，工作台显示真实作业，课表切换到有课程的日期，作业列表显示待处理/截止，研究生教务显示学籍与学分地图；空教室返回 158 间、4 页，第二页范围 51–100；研讨室真实场馆、时段与预约表单均可达。未触发任何学校写确认或提交。
- 前一会话的作业详情曾复现 `moduleAuthRequired`；覆盖安装优化包并重新登录后，同一真实作业详情已完整显示说明、发布与提交信息，强制刷新也无全局 Hint。该结果表明认证反弹具有间歇性，不能据此宣称学校跳转链已修复。
- 优化后视觉闭环通过：研究生学分地图正常且无跨页 Hint；真实刷新中银杏叶仅改变透明度和整体缩放，保持宽高比；研讨室真实时段页显示“预约研讨室”；空教室显示 158 间、4 页及连续空闲信息。未触发学校写操作。

## Release 候选产物

构建命令：`flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`，使用本机既有外部签名配置，未回退 Debug 签名。

产物：`artifacts/local/android-beta3/Ginkgo-0.1.0-beta.3-android-arm64.apk`。

- 大小：43,835,741 字节。
- SHA-256：`182d4563dc04e85b4b0654c2527b6710a7e1cc843e5dafdf0a5b7da6728eb688`。
- 包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName=0.1.0-beta.3`、`versionCode=13`，仅 `arm64-v8a`，非 debuggable。
- `GeneratedPluginRegistrant.java` 不含 `integration_test`；使用 `--pub` 和正常 `main` 构建。
- `zipalign -c -P 16 -v 4`、`apksigner verify` 和本地 `shasum -a 256 -c checksums.txt` 通过。
- 签名证书 SHA-256 为 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Beta.2 候选证书一致。

## 公开发布与回下载

- Git 提交 / 标签：`32b6a1d604128cec39a93826da684d5054cb0ea6` / `android-v0.1.0-beta.3`，已推送。
- [GitHub Beta prerelease](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.3) 已公开，APK 与 `checksums.txt` 均处于 uploaded 状态。
- APK 公开资产大小为 43,835,741 字节，GitHub 资产摘要与本地 SHA-256 均为 `182d4563dc04e85b4b0654c2527b6710a7e1cc843e5dafdf0a5b7da6728eb688`。
- 首次回下载因网络 `no route to host` 中断；随后直接公开 URL 回下载成功，APK 与 checksums 逐字节对比本地候选一致，`shasum -a 256 -c checksums.txt` 通过。
- [Android Release workflow](https://github.com/JUANWANG-BUAA/ginkgo/actions/runs/41041524421) 在“Materialize external signing configuration”因缺少 4 个 Android 签名 secrets 失败，构建与上传步骤未运行。公开资产使用上述本机外部签名候选，未改变 fail-closed 规则。

## 发布后仍未覆盖的验收边界

尝试以 `Ginkgo_Beta2_Release_QA` 独立模拟器验证 Release 覆盖升级；QEMU 冷启动反复报告主循环/CPU 线程无响应后以段错误退出，`emulator-5556` 未上线。因此 **Beta.2 Release → Beta.3 Release 覆盖升级、个人待办保留和 Release 启动仍未验收**，没有用卸载 Debug 应用来绕过签名差异或牺牲本机数据。

物理 Android 设备、TalkBack、大字号、厂商后台行为、完整真实账号只读和真实学校写入仍未完成；间歇性模块认证问题继续跟踪，不能由一次成功复验推断永久修复。学校写入仍须本人逐次指定对象并确认，代理不自动试单。`docs/update-gate.json` 的 `minBuild` 仍为 5，未随本次发布提高。

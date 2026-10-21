# Android Alpha.3 发布与升级记录

2026-10-21，版本 `0.1.0-alpha.3+4`，源码标签 [android-v0.1.0-alpha.3](https://github.com/JUANWANG-BUAA/ginkgo/tree/android-v0.1.0-alpha.3)。Android 7.0+ / arm64-v8a。

下载 [正式 APK](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.3/Ginkgo-0.1.0-alpha.3-android-arm64.apk)、[SHA-256](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.3/checksums.txt)；[发布说明](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.3)。最新范围见 [实施现状](../../MIRROR-IMPLEMENTATION.md)。

## 改动与限制

- 包含 Alpha.2 之后的认证跳转兼容、迟到凭据失效与并发恢复修复；源码及合成测试已验证，最近实网登录异常仍待用户复验，不据此保证学校认证恢复。
- 可丢弃的 Rust 内存锁中毒后安全重建，账号与业务凭据统一管理；退出、切路线与身份替换回归通过。
- 图书馆页面集中加载、失败保留与写后回查状态，保留逐次确认、单次提交和未知结果禁重发。
- 签到、作业、图书馆、场馆状态色统一，深浅色对比度有自动化检查。

签到和图书馆真实写入尚未验收，仍属实验功能。博雅选退课、CGYY 写入、作业提交 / 附件、后台提醒尚未迁移。此次未使用真实账号、未提交学校写操作，模拟器通过不能替代真机和真实业务验收。原评审及核实取舍见 [Opus 5.5 评审落实](../../_audit/2026-10-21-opus-review-followup.md)。

## 发布包校验

以普通 `lib/main.dart` 构建签名 Release，非 integration_test 入口：

```sh
cd flutter
flutter build apk --release --target-platform android-arm64 --target lib/main.dart
```

| 项目 | 结果 |
| --- | --- |
| 文件大小 | 39,949,068 字节 |
| APK SHA-256 | `aaef88e38f0b39a6a5b26b20eaea30458e68259c8affbe81bc91efb57641dd8f` |
| 签名证书 SHA-256 | `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Alpha.1 / Alpha.2 相同 |
| 签名 / 安装属性 | apksigner 验证通过；versionCode 4；无 debuggable |
| 16 KB 对齐 | zipalign 检查通过；Flutter / app ELF 为 64 KB，Rust ELF 为 16 KB |

## 本次设备与自动化证据

Android API 37 arm64 模拟器，普通 Release 包完成 Alpha.2（versionCode 3）→ Alpha.3（4）的 `adb install -r` 覆盖安装，未卸载旧正式包。打开登录、离线工作台、设置与运行自检，显示 `0.1.0-alpha.3 (4)`；Rust 桥接、本机文件及 Keystore 合成写入 / 读回 / 删除均通过，演示模式跳过学校网络。

同一源码的 Android `write_actions_test.dart` 合成集成测试 1 项、`auth_test.dart` 2 项通过；Flutter 单元 / widget 当次 91 项通过。Rust、Swift 契约与全部回归结果详见评审落实记录。集成测试会另编译测试入口，因此最后安装与发布的均为上述普通 main Release APK。

旧 Alpha.1 / Alpha.2 正式包可覆盖升级。若装的是不同签名的调试包，应先备份本地待办再自行卸载；卸载会清除本机数据。应用只打开浏览器下载，不自动安装。

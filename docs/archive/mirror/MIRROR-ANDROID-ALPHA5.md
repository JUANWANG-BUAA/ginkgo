# Android Alpha.5 发布与升级记录

2026-10-22，版本 `0.1.0-alpha.5+6`，源码标签 [android-v0.1.0-alpha.5](https://github.com/JUANWANG-BUAA/ginkgo/tree/android-v0.1.0-alpha.5)。Android 7.0+ / arm64-v8a。

下载 [正式 APK](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.5/Ginkgo-0.1.0-alpha.5-android-arm64.apk)、[SHA-256](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.5/checksums.txt)；[发布说明](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.5)。最新范围见 [实施现状](../../MIRROR-IMPLEMENTATION.md)。

## 用户可见改动

- 工作台与研究生教务改为按区域渐进加载：完成一个区域即显示，刷新保留旧结果，局部失败只重试该区域；加载使用主题色银杏呼吸与首次淡入，减少动态效果时静态显示。
- 座位与空教室改为有界分页浏览：每页 50 条、固定查询栏、直接跳页、按需构建；同一查询刷新保留当前页，空教室搜索按 250ms 合并。
- 课表固定左侧节次轴、触摸横滑按天对齐，周次与星期提供直达菜单；长页统一纵向滚动条与返回顶部。
- 工作区导航改由功能登记表派生（移动端标签、桌面侧栏、今日快捷入口一致），界面呈现不变。
- 新增启动时最低版本门禁：读取 GitHub Pages 上的清单，低于最低 build 时引导更新；清单拉取失败、结构异常或无法读取版本时一律放行。

## 发布包

以普通 `lib/main.dart` 构建签名 Release：

```sh
cd flutter
flutter pub get
flutter build apk --release --target-platform android-arm64 --target lib/main.dart
```

| 项目 | 结果 |
| --- | --- |
| 文件 | `Ginkgo-0.1.0-alpha.5-android-arm64.apk` |
| 文件大小 | 40,609,432 字节（较 Alpha.4 +259,172 字节，+0.64%） |
| APK SHA-256 | `34daf9ee1e6e9a97c10287437b1468eb17febea2ade3cf6a3fb8c955149ff6f9` |
| 签名证书 SHA-256 | `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`（与 Alpha.1–Alpha.4 相同） |
| versionCode / versionName | 6 / `0.1.0-alpha.5` |
| 最低 / 目标 SDK | 24 / 36 |
| ABI | arm64-v8a |
| 校验 | apksigner 证书、aapt badging、arm64-only 通过 |

## 验证边界

- Flutter analyze、132 项单元/widget 测试、架构边界检查与 Rust 全量门禁在发布前通过。
- API 37 arm64 模拟器：先安装公开 Alpha.4（SHA-256 与发布页一致），再用 `adb install -r` 覆盖安装 Alpha.5，`Success`，versionCode 5→6，`firstInstallTime` 保持、`lastUpdateTime` 更新，冷启动 1.3 s，无 Flutter 异常日志；未卸载、数据目录保留。
- 未在真实设备、真实学校账号或写操作上验收；未测读屏、厂商 ROM、不同 ABI/页面大小；本版仅 Android，Windows 保持 Alpha.4。
- 最低版本门禁的实际阻塞未验证：清单需合并到 `main` 并由 GitHub Pages 部署后才可读取，Alpha.4 及更早版本不包含该逻辑；门禁不下载代码、不承载学校协议参数，失败一律放行。
- 应用内从 Alpha.4 检查并下载 Alpha.5 的完整往返（含系统安装确认）仍未在本轮执行。

# Android 主线推进盘点与本地收口（2026-10-23）

## 范围与基线

- 用户要求：了解项目进展、分析任务清单、整理 TODO 并设置 goal 快速推进。
- 起点：`feat/rust-flutter-mirror` / `e149f90`，开始时工作树干净。本轮未提交 Git、未改版本、未发布、未提升最低版本门禁。
- 当前主线为 Android / Flutter + Rust；Windows 保持共享兼容，Apple SwiftUI 不改产品代码。唯一未完成任务入口为 [MIRROR-TODO](../MIRROR-TODO.md)，本文件仅记录过程、结论和证据，不另建待办。
- 公开 Android Alpha.7（build 8）冻结于 `545814a`，Windows 公开 Alpha.6；依据既有 [发布记录](2026-10-23-android-alpha7-release.md)，本轮没有重新访问远端 Release 验证资产。相同 pubspec 版本号不代表冻结点之后的源码已进入公开 APK。

## 盘点结论与优先级

已存在的后续源码包括截止判定/提交状态分离、工作台与在修学分呈现、CGYY 静态协议对齐、公开查书/馆藏与排序、应用内校车时刻表。`e149f90` 已移除作业详情“加入个人待办”，历史学校来源任务不删除，首页不重复预览。不能再按历史设计重新排这些已实现能力。

本轮设置有界 goal：对齐发布/源码/验收边界，先关闭当前可复现回归和本地验证缺口。后续优先级保留为：P0 认证与超时/断网等可靠性及人工真实写门禁，P1 Android 设备/只读数据核对和已明确需求的分包评审，P2 扩展与结构。真实学校写入、物理设备和新的写能力不以自动化代验收。

## 已完成的文档纠偏

- 现状页不再写 Alpha.7“准备发布”或当前 alpha.6+7；10-22 发包准备和审计仍保留当时原文，10-23 入口说明后来发布的范围。
- 当前功能索引与对照表区分“公开 Alpha.7 曾支持作业转待办”与“后续源码撤入口”；增补公开查书/馆藏与应用内校车，不扩大为本人借阅/实时余票/购票。
- 唯一 TODO 移出已完成的 Package 描述，保留真正未验收项与后续需求；不将阳光打卡明确需求弱化为无期限候选，也不绕过隐私和单写门禁。
- 根指令与 README 补 Android 开发入口，Swift 架构/命令明确为 Apple 范围。第五个手机标签仍是“预约”，未实施方案中的“预约→服务”改栏。
- API 修订表记录校车客户端范围变化；没有新增上游接口、成功码、认证/TLS 策略或实网协议断言。

## 可复现问题与实现

### 校车页

首次执行 `bash scripts/check-mirror.sh` 在架构检查退出，原因为 `shuttle_page.dart` 硬编码学校 URL。独立 Rust 格式检查也发现多个新增模块声明/调用未符合 rustfmt。

修复：学校来源地址仍由上游投影给 DTO，Flutter 移除 fallback 常量，仅检查通用 HTTPS、非空主机和无 userinfo；未拿到有效地址时明确提示刷新，不伪造来源。浏览器返回 false/抛错时提供可选择复制的地址。代价是初次读取失败且没有来源时不能凭客户端常量打开官方页。

原页面还缺少 gateway 更新处理，旧读取可能覆盖新 service 的页面。新增 `didUpdateWidget` 清旧状态并读取，请求代次同时保护成功、失败和 finally，不让旧结果覆盖当前数据或提前解除当前忙状态。刷新失败保留旧表，成功空清旧表。

18 项合成 widget 测试首次在原页面为 9 过 / 9 失败；修复后 18/18。中间一次失败为测试对 pending spinner 使用 `pumpAndSettle` 超时，改为有限 pump，未删除旧 Future 异常回归、未吞异常。

### Rust 校车读端口

新增 7 项 adapter 合成回归和 2 项 parser 回归（连同既有 2 项共 11 项通过）。覆盖隔离公开会话不携带签入 Cookie、不污染共享会话/路线、公开响应 Cookie 不跨次保留、同站重定向、非 200/非官方或不安全最终地址、畸形 URL/HTML 与坏行过滤。

保留既有安全 GET 有界路线回退：Direct / WebVPN 网络失败发送一次；Automatic 最多两次，第二次严格走 WebVPN，不消费第三次响应。未将写请求不重放规则误用为禁止公开 GET 路线回退，未改共享 Session 或校车生产协议语义。Rust 其余改动仅 rustfmt。

### 查书排序与 gateway 隔离

补 4 项合成回归：三种排序和升降序切换均从第一页查询、失败或无效 JSON 保留已显示页及条目、更换 gateway 后旧成功/旧异常不能覆盖当前请求或提前解锁。初次原页面测试为 6 过 / 2 失败，定位到缺少 provider 更新与迟到结果保护；新增代次检查和 `didUpdateWidget` 清旧查询/结果/排序，用户仍手动发起新查询，不增加自动学校读取。修复后 `flutter test --no-pub test/library_books_test.dart` 8/8 通过。馆藏详情 gateway 重用与更极端布局不在本轮扩展范围。

### 复核追加：复制菜单实际操作

代码复核指出 `SelectableText` 默认 Material 复制菜单与生产 Cupertino-only 本地化不兼容。追加真实长按菜单合成回归先复现 `No MaterialLocalizations found`；仅为该链接提供 `CupertinoAdaptiveTextSelectionToolbar`，不改全局本地化。修后校车 19/19 通过，断言长按、点击 Copy 实际触发 mock `Clipboard.setData`，不只检查控件存在。

中间一次检验因在 widget fake-async 中直接等待平台剪贴板读取而挂起，约 5 分钟后工具终止，未当作通过；改为拦截并验证平台写调用，保留复制主路径。另一次全量后台进程被工具终止（exit 143，未完成），不复用其结果；最后独立子进程重跑完整基线与构建，以下最终结果为准。

## 验证记录

环境：macOS 27.0.1 / Apple Silicon，Rust 1.99.0、Flutter 3.47.0、Dart 3.13.0。

| 验证 | 结果与边界 |
| --- | --- |
| 首次 `bash scripts/check-mirror.sh` | 失败，架构检查阻断于校车页 URL；保留失败事实，不称基线原本全绿 |
| `cargo fmt --manifest-path rust/Cargo.toml --all --check`（首次） | 失败，后按 rustfmt 修正；无手改生成绑定 |
| `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream shuttle --locked` | 11 过 / 0 失败，全为合成数据，无学校网络 |
| `flutter test --no-pub test/shuttle_page_test.dart` | 修复后 18 过 / 0 失败；官方外链全部 MethodChannel mock，不启动真实浏览器 |
| `cargo test --manifest-path rust/Cargo.toml --workspace --locked` | 通过；不代表学校实网或其他平台设备验收 |
| `bash scripts/check-mirror.sh`（校车修复后） | exit 0；架构检查、5 项门禁测试、fmt、全工作区 clippy、core 无默认特性、upstream/workspace 测试、Flutter analyze 和 291 项 Flutter 测试通过。含依赖解析，不称纯离线 |
| 正常入口 ARM64 Debug APK（首轮） | `cd flutter && flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` exit 0；产物 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，不是 integration-test APK，不是 Release/发包证明 |

最终冻结后再次执行 `bash scripts/check-mirror.sh`：**exit 0**；包含校车复制菜单与查书修复，Flutter **296 过 / 0 失败**、analyze 无问题，Rust / 架构 / fmt / clippy 全部通过。完整日志为 `/tmp/ginkgo-progress-check/complete-baseline.log`。首次 291 项结果只是中途基线，不作为最终代码的唯一验证。

最终正常入口 ARM64 Debug APK 也已重建：**exit 0**，`assembleDebug` 33.3 秒（构建输出，不含全量检查）；产物仍为 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，231,174,713 bytes，SHA-256 `e09705e3a7fa9e638aa0648c9edcab27f0d36c5fd6682504293965ad1e548efa`。日志 `/tmp/ginkgo-progress-check/final-apk.log`。这是本地 Debug 构建，未安装、未做物理设备验收，不是已发布签名 Release。构建报告了 Gradle native-access 与不可用 nightly 工具链跳过警告，但最终使用可用工具链完成，未为消警告改运行环境。最终 `git diff --check` 通过。

日志在本机 `/tmp/ginkgo-progress-check/`；校车定向日志 `/tmp/ginkgo-shuttle-final.log`。这些是临时文件，不是长期交付件，本审计保留命令、结果和限制。

## 验收边界

未使用凭据，未执行学校登录/查询、预约、取消、上传、续借、购票或打卡；未修改 TLS、凭据存储、认证流程、FRB API 或生成文件。物理 Android 的 TalkBack、预测返回、帧率、真实浏览器和官方班次仍需人工验收。Windows/Apple 未运行设备构建或测试，不把共享代码编译成功扩展为这些平台已验收。

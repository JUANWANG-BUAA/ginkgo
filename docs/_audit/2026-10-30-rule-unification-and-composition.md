# 规则归口与页面分层收口（2026-10-30 第二批）

## 范围

在 `2026-10-30-rule-contract-and-layering.md` 的基础上，把剩余架构债继续收敛：稳定业务规则只剩领域实现、平台动作只在组合根绑定、死代码移除、图书馆写结果判定显式化。只做分层与归口，不改变学校协议，不使用真实凭据，不执行学校写操作。

## 规则只剩一份实现

三处规则的来源与归口：

| 规则 | 生产实现 | Dart 使用方式 |
| --- | --- | --- |
| 签到/作业提醒 | `ginkgo_domain::features::reminders::plan_checkin_homework_reminders` | 经 `ReminderPlanningGateway` 注入；`shared/reminder_rules.dart` 的 `checkinReminders`/`homeworkReminders` 已删除 |
| 作业截止分类 | `ginkgo_domain::features::homework::classify_deadline` | `SchoolRules.homeworkDeadline`，纯同步桥接命令 `classify_homework_deadline` |
| 签到窗口 | `ginkgo_domain::features::checkin::sign_in_window`（写路径同源） | `SchoolRules.checkinWindowOpen`，纯同步桥接命令 `checkin_sign_in_window` |

`fixtures/rules/` 现在有四张共享规则表：作业截止（15 组）、签到窗口（12 组）、提醒计划（5 组）、图书馆写结果（10 组）。Rust 侧作为权威接入契约 runner；Dart 侧 `rules_parity_test.dart` 用同一份 `expected` 断言自己的实现或替身。

单元测试无法加载原生库，因此在 `flutter_test_config.dart` 注入 `DartSchoolRules`（含截止分类与签到窗口的 Dart 实现）与 `ReminderRuleDouble`（提醒计划）。这些替身受同一张表约束，改出差异即红。装配点：`main.dart` 在启动时安装 `NativeSchoolRules`。

提醒计划还有一处刻意保留的语义差异：已开始的课程不再排提醒（与领域既有课程/待办规则一致），而不是像旧 Dart 那样对已开课场次也排程；`ReminderController.plans` 仍会过滤已过期的计划。

## 平台动作只在组合根绑定

- `MaintenanceService`、`InstalledVersion`、`UpdateResult`、`AndroidDownload` 迁到 `application/maintenance.dart`；`platform/` 的下载控制器引用该值类型。
- 文件读写端口（`HomeworkFilePicker`、`HomeworkFileSave`、`FileSaveResult`、`FileOpenStatus`）迁到 `application/file_actions.dart`；`cross_file` 作为直接依赖声明。
- 新增 `application/platform_actions.dart`：`main.dart` 绑定真实实现，`WorkspaceContext.platformActions` 传到移动壳、桌面壳、服务目录与登记页。
- 学习课程页、作业文件面板与设置维护页不再以基础设施实现作为默认参数值；设置页的自检与软件更新入口在没有维护能力时隐藏而不是崩溃。

## 门禁

- 架构门禁新增并保留"`features/` 与 `workspace/`（组合根除外）不得导入 `infrastructure/`"，待迁移清单已清空；自测 24 项通过，含清单固定与组合根豁免。
- `SnapshotBook` 及其所在的 `foundation/snapshot_persistence` 模块删除：查询快照按分层归 upstream，该模块无人使用。
- 图书馆写结果判定改为显式命名策略（成功码集合、会话失效措辞、拒绝措辞），语义与冻结的 Apple 参考实现（`LibraryClient.validate`）保持一致；`fixtures/rules/library-mutation-v1.json` 固定边界，包括"成功码与拒绝措辞矛盾"这一已知脆弱点。

## 验证

- 完整 `bash scripts/check-mirror.sh` 通过（Rust 全量、严格 Clippy、格式、架构门禁与自测、design token 预算、接口索引同步、FRB 二次生成零漂移、636 项 Flutter 测试）。
- 正常 `lib/main.dart` 入口的 Android ARM64 Debug APK 构建成功。

## 未覆盖边界

- 真实账号、物理设备与学校写入未执行；规则表全部为合成样例。
- 提醒规则、图书馆写结果判定的 Swift 侧接入未做（Apple 已冻结，Swift runner 按既有约定跳过未登记契约）。
- `flutter_test_config.dart` 的替身是测试专用实现，生产只用领域实现；若新增页面绕过 `SchoolRules`/`ReminderPlanningGateway` 直接写规则，门禁不会自动发现，需要按同一模式接入。

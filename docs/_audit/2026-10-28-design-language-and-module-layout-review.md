# 设计语言 token 化、模块归属与目录层级审查（2026-10-28）

范围：`flutter/lib/` 全量 Dart 源码。承接 [架构边界审查](2026-10-28-architecture-boundary-review.md)，本篇聚焦三件事：

1. **设计语言没有 token 化**（可抽象未抽象、该抽象没抽象）；
2. **不同模块被放进同一个模块**（归属错置）；
3. **工程目录层级不明确**（命名口径、依赖方向、插件落位）。

本轮只读，未修改业务代码。

---

## 1. 设计语言：token 化缺口

### 1.1 ✅ 已修复（2026-10-28）设计 token 清理与存量迁移

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) D-01。字阶完整导出，15/16 存量已迁移并纳入门禁，零引用 token 已清理，重复状态色已合并为别名。


`design/tokens/` 共 6 个文件、定义约 81 个常量。实测**零引用**的有 31 个：

```
colors.dart     windowBackground, groupedBackground, borderLight, panelBorder
typography.dart caption2
radii.dart      borderRadiusPill, borderRadiusBadge, borderRadiusButton,
                borderRadiusNavigationItem, borderRadiusPanel, borderRadiusGroup
spacing.dart    xxs, xs, sm, lg, xxxl, desktopPageInset,
                edgeInsetsListTileCompact, edgeInsetsSidebarItem,
                edgeInsetsSidebarItemInner
layout.dart     wideBreakpoint, mobileTabBarHeight, headerIconSize,
                contentMaxWidth, todayContentMaxWidth
motion.dart     fast, deliberate, curveFast, curveNormal, curveSnappy
```

> `statusUncertain` 与 `statusInactive` 逐字节相同（都是 `0xff4a4f58` / `0xffc4c8d0`），是同一 token 被复制成两个名字，不是两个语义。

根因与 `MIRROR-TODO` P2 的判断一致：**门面过窄**。`design/apple_design.dart` 只有 44 行、19 个 `static`，只暴露约 16 个 token；`design/tokens.dart` 虽然 `export` 了全部 6 个 token 文件，但页面习惯走 `AppleDesign.` 门面。

**两条取 token 的路径并存**：

| 路径 | 引用文件数 | 例 |
| --- | --- | --- |
| `AppleDesign.` 门面 | 39 | `AppleDesign.pageInset`、`AppleDesign.statusSuccess` |
| 直接 `Ginkgo*` | 20 | `GinkgoSpacing.edgeInsetsPage`、`GinkgoColors.label` |

同一语义有两个入口，改名要同时改两处。

### 1.2 ✅ 已修复（2026-10-28）字阶越界：11 档硬编码（最高频两档恰好没有 token）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) D-02。字阶新增 `bodyCondensed`(16) 与 `callout`(15)，门面同步暴露；存量 35 处迁移并入 D-01 分批处理。


token 字阶只有 9 档：`34 / 26 / 22 / 17 / 17 / 14 / 13 / 12 / 11`。实际使用：

| fontSize | 出现次数 | 状态 |
| --- | --- | --- |
| 13 / 14 / 17 / 12 / 11 / 26 / 22 / 34 | 162 | ✓ 在字阶内 |
| **15** | **19** | ✗ 无对应 token |
| **16** | **13** | ✗ 无对应 token |
| 28 | 5 | ✗ |
| 18 | 5 | ✗ |
| 24 | 4 | ✗ |
| 20 | 4 | ✗ |
| 32 | 3 | ✗ |
| 21 / 19 / 40 / 10 | 各 1–2 | ✗ |

`15` 和 `16` 是正文与次级正文的实际用量最大的两档，**字阶表里却没有**；这不是「页面偷懒」，是**token 表缺档**。典型位置：`desktop_workspace_sidebar.dart:58`（15）、`design/academic_widgets.dart:71`（16）。

### 1.3 圆角越界：7 档

token 圆角 `2 / 7 / 8 / 10 / 12 / 18 / 26`。越界值：`14`(4)、**`24`(4)**、`16`(3)、`3`(2)、`6`(2)、`4`(1)、`5`(1)。

`24` 尤其可疑：`GinkgoRadii.group` 是 `26`，但代码里多处写 `24` —— 像是「想用 group 圆角但记错了值」的近似。`classroom_page.dart:312` 即属此类。

### 1.4 间距越界：16 档

token 间距 `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48`。越界值：`14`(16)、`6`(14)、`10`(9)、`3`(7)、`18`(6)、`5`(4)、`28`(4)、`7`(3)、`13`(2)、`9`(2)、`11`、`1`、`22`、`36`、`80`。

`80` 出现在 `edgeInsetsDesktopPage`（`spacing.dart` 自己定义的 token 里就已越界）。

### 1.5 完全没有 token 的设计维度

以下视觉决策全部散落硬编码，token 表里**没有对应维度**：

| 维度 | 现状 | 出现规模 |
| --- | --- | --- |
| **图标尺寸** | 14 档并存：11/14/15/16/17/18/20/22/24/25/30/34/44/56 | 17×37、24×25、16×23、14×16、20×16、22×13、15×13… |
| **字重** | `w400`(6) / `w500`(24) / `w600`(76) / `w700`(11) | 117 处，字阶 token 只在特定字号里隐含字重 |
| **触控目标最小尺寸** | AGENTS.md 要求 ≥48dp，代码里无 token、无统一约束 | `ApplePickerTile`、`AppleGlassButton`、各 feature 按钮各自实现 |
| **内容底部留白** | `SizedBox(height: 96)` 出现 **19 次**（给底部标签栏让位） | 无 token，每页手写 |
| **分割线宽度** | `thickness: 3` / `5` 各 1 处 | 无 token |
| **阴影 / elevation** | 6 处 `BoxShadow` / `blurRadius`，无 token | 无 token |
| **透明度层级** | `withValues(alpha: 0.16 / 0.10 / 0.22 / 0.12 / 0.28 …)` | 散落各处，无层级命名 |

### 1.6 共享组件自身不遵守 token

`widgets/apple_surfaces.dart` 是被共享设计系统 barrel（`widgets/apple_widgets.dart`，被 85 个文件引用）导出的核心组件，内部硬编码：`EdgeInsets.symmetric(vertical: 36, horizontal: 16)`（:147）、`size: 44`（:155）、`fontSize: 20`（:162）、`fontSize: 15`（:169）、`fontSize: 15`（:196）、`EdgeInsets.fromLTRB(32, 0, 32, 10)`（:194）、`BorderRadius.circular(AppleDesign.panelRadius(context))`。

`design/ginkgo_visuals.dart` 同样硬编码 `BorderRadius.circular(12)`、`BorderRadius.circular(10)`、`fontSize: compact ? 11 : 12`。

**结果**：token 预算检查（`scripts/check-design-tokens.py`）统计的是全仓硬编码数，连共享组件自己的硬编码也计入，却无法表达「这些值该不该有 token」。

### 1.7 同一视觉模式存在多套并行实现（可抽象未抽象）

| 模式 | 实现处 | 数量 |
| --- | --- | --- |
| **加载 / 空 / 错误三态** | `widgets/loading_widgets.dart`(`GinkgoLoadingView`/`SectionFeedback`)、`features/schedule/schedule_widgets.dart`(`ScheduleLoadingSection`/`ScheduleEmptySection`)、`features/library/library_widgets.dart`(`LibraryEmptyState`/`LibrarySectionStatus`)、`features/cgyy/cgyy_widgets.dart`(`CgyyStatusSection`)、`features/classroom/classroom_status.dart`(`ClassroomMessageState`/`ClassroomLoadingState`/`ClassroomRefreshingState`)、`features/today/today_presentation.dart`(`TodayVisualSection`) | **6 套** |
| **页头（标题+副标题+图标+刷新）** | `ApplePageHeader`、`LibraryPageHeader`、`CgyyPageHeader`，外加 career / campus / notices 三页内联 | **3 套 + 3 处内联** |
| **状态徽标 / 标签** | `AcademicBadge`、`GinkgoBadge`、`_ScoreBadge`、`TodayCourseEmptyBadge`、`GraduateCourseBadges`、`ShuttleRunChip`、`HomeworkStatusBadge`、`ReminderBadge` | **8 套** |
| **指标 / 统计卡** | `AcademicMetric`(+Grid)、`ResourceMeter`、`GraduateStatRow`、`GraduateCreditBar`、`GraduateCreditProgress`、`HomeworkSummaryMetrics`、`BykcStatisticsCard`、`LibraryVenueMeter`、`LibraryCampusStats` | **9 套** |
| **键值行 / 条目行** | `AppleListTile`、`ScheduleDetailLine`、`ScheduleChevronRow`、`AcademicFactRow`、`LibraryNoteText`、`BykcMetadata`、`BykcLabel`、`GraduateCategoryRow`、`CgyyTileContent`、`CheckinCourseRow`、`HomeworkItemTile`、`TaskRowCard`、`ClassroomResultTile`、`LibraryBookCard`、`LibraryHoldingCard`、`TodayCourseRow`、`BykcCourseTile` | **17 套** |
| **折叠 / 展开** | `GraduateDisclosure`、`LibraryDisclosureToggle`、`SectionReveal`、`LibraryNoteText` | **4 套** |
| **确认对话框** | `widgets/mutation_dialog.dart`(`confirmMutation`)、`CgyyConfirmDialog`，外加 12 个文件内联 `CupertinoAlertDialog` | **2 套 + 12 处内联** |

`features/classroom/classroom_status.dart` 尤其典型：它把「加载中 / 刷新中 / 消息 / 提示」四个状态各写了一个 widget，而 `widgets/loading_widgets.dart` 已经有 `GinkgoLoadingView` 与 `SectionFeedback` 表达同一语义。

### 1.8 命名：833 行 `Apple*` 用于 Android-only 产品

`widgets/apple_controls.dart` / `apple_navigation.dart` / `apple_surfaces.dart` / `apple_widgets.dart` + `design/apple_design.dart` 合计 **833 行**，被 **102 个文件**引用。`apple_widgets.dart` 甚至还 `export` 了 `application/failure_message.dart`（把错误文案映射混进设计系统 barrel）。

`apple_surfaces.dart:4` import `shared/app_preferences.dart` 并在 `:304` 读 `AppPreferencesScope.of(context).compactLists` —— 共享设计组件依赖应用存储，脱离 scope 时行为不确定，也让该文件无法独立测试。

### 1.9 门禁只能挡数量，挡不住质量

`scripts/check-design-tokens.py` 当前预算：`fontSize 204/204`、`EdgeInsets 268/268`、`SizedBox 208/208`、`BorderRadius 42/42` —— **四项全部顶格**。这个门禁能防新增，不能驱动收敛，也无法表达「新增一个语义档位」。

---

## 2. 模块归属错置：不同模块被塞进同一个模块

### 2.1 ✅ 已修复（2026-10-28）最大的问题：两个 Dart 网关把互不相关的学校系统装在一起

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) D-08。八个独立端口已建立并迁移页面签名，兼容聚合接口不再包含跨域方法。

Rust 侧的端口是**按能力/系统正确拆分**的（`ports/` 下 22 个文件：`library.rs` 只含 booking.lib、`bykc.rs`、`graduate.rs`、`notices.rs`、`cgyy.rs`、`library_books.rs`、`library_loans.rs`、`library_stats.rs`、`shuttle.rs` …）。但 Dart 侧的网关**没有镜像这个边界**：

```dart
// lib/application/mirror_service.dart
abstract interface class LibraryGateway implements MirrorEnvironment {
  // —— booking.lib：座位预约 ——
  libraryStats / reserveLibrarySeat / performLibraryAction
  libraryVenues / libraryAreas / librarySlots / librarySeats
  libraryBookings / libraryHistory
  // —— OPAC：公开查书与馆藏 ——
  libraryBooks / libraryHoldings
  // —— 校车时刻表：学校公开页，与图书馆无关 ——
  shuttleTimetable();
}

abstract interface class CampusGateway {
  bykcPart(...)        // 博雅 BYKC
  graduatePart(...)    // 研究生教务 GSMIS
  notices(...)         // 新闻网
  cgyy(...)            // 研讨室 CGYY
  editTasks(...)       // ← 本机待办：纯设备本地操作，无学校系统
}
```

后果是 `CampusGateway` 必须收下 `editTasks`（本机文件写入），`LibraryGateway` 必须收下 `shuttleTimetable`（校车），否则页面拿不到方法。`CampusGateway` 甚至没有 `implements MirrorEnvironment`，而 `LibraryGateway` 有 —— 接口契约本身也不一致。

### 2.2 ✅ 已修复（2026-10-28）胖接口 + 运行期能力探测：25 次 `is` 探测、13 次强转

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) D-08/D-09。组合根新增 `application/service_capabilities.dart` 一次解析全部可选能力，学习域用 `application/learning_ports.dart` 表达端口二选一；页面改为接收类型化端口，页面层 `is`/`as` 探测归零。

因为新能力是「后加的独立 interface」，注入的却是单个 `MirrorService`，于是每个可选能力都在运行期探测：

| 位置 | 探测 |
| --- | --- |
| `workspace/workspace_catalog.dart:227,260` | `is LibraryLoansGateway` / `is CampusCardGateway` |
| `workspace/service_search_page.dart:170,249` | `is StudentServiceLinksGateway` |
| `features/career/career_events_page.dart:20` | `is CareerEventsGateway` |
| `features/campus/campus_activities_page.dart:20` | `is CampusActivitiesGateway` |
| `features/learning/learning_course_page.dart:64,141,160,178,321,339,425,462,490` | `is CourseLearningContextGateway` / `CourseAnnouncementGateway` / `CourseResourceGateway` / `CourseAssessmentGateway` |
| `features/learning/learning_announcement_page.dart:49,64` | 同上 |
| `features/learning/learning_page.dart:102` | `is LearningCourseGateway` |
| `features/graduate/graduate_page.dart:325`、`graduate_credit_map_page.dart:149` | `is GraduateCreditMapGateway` |
| `features/cgyy/cgyy_day_page.dart:100` | `is CgyyBookingGateway` |
| `features/library/library_loans_page.dart:159` | `is LibraryLoansOfficialGateway` |
| `features/tasks/tasks_page.dart:255` | `is AcademicGateway` |
| `features/settings/settings_page.dart:260` | `is LearningSnapshotGateway` |
| `shared/reminders.dart:51` | `is ReminderPlanningGateway` |

合计 **25 处 `is` 探测 + 13 处 `as` 强转**。这直接导致：

- `DemoMirrorService` 只 `implements` 6 个额外接口（`MirrorService`/`CampusCardGateway`/`HomeworkFilesGateway`/`StudentServiceLinksGateway`/`CareerEventsGateway`/`CampusActivitiesGateway`），其余能力在演示模式下全部退化为 `null` → 页面显示「当前服务不支持 X」；
- 「不支持 / 未支持」这一产品状态，是**架构缺口的副产品**，而不是显式建模的能力矩阵。

**这是本次审查发现的最大结构性缺陷：Rust 端口边界正确，Dart 应用边界错误。** 修法是让 Dart gateway 逐个镜像 Rust 端口（`LibrarySeatingGateway` / `LibraryCatalogGateway` / `ShuttleGateway` / `LocalTaskGateway` / `BykcGateway` / `GraduateGateway` / `NoticeGateway` / `CgyyGateway`），由组合根一次性装配并注入，页面不再做运行期探测。

### 2.3 具体错置清单

| 当前位置 | 内容 | 应归属 | 证据 |
| --- | --- | --- | --- |
| ✅ `features/academic/rules_page.dart` | `RulesPage` 读取 `AcademicGateway.rules()` 的**选课规则示例** | 已移到 `features/academic/`（D-10） | 唯一入口在 `features/classroom/classroom_page.dart`；与 tasks 无任何关系 |
| `features/schedule/course_visibility.dart` | 跨域共享状态（课程可见性，跨 schedule/checkin/homework/today） | `shared/` 或 `application/` | 被 `workspace_shell`、`today_page`、`today_homework_section`、`homework_projection`、`homework_page`、`checkin_page`、`shared/reminders`、`shared/reminder_scope` 共 8 处引用 |
| `features/reservations/` | 跨域聚合页（图书馆 + 研讨室 + 空教室入口） | `workspace/`（与 `service_directory.dart` 同层） | `reservations_page.dart` 只做导航聚合，import 三个 feature 页面 |
| `features/library/`（15 文件 3 028 行） | 混装 booking.lib 座位/历史/统计 + OPAC 查书/馆藏 + 本人借阅 | 至少拆 3 个子域 | `library_loans_page.dart` 用的是另一个 gateway（`LibraryLoansGateway`），`library_books_*` 用 `LibraryGateway.libraryBooks` |
| `features/cgyy/`（15 文件 3 159 行） | 混装只读（hub/day/orders/lockCode）+ 写（booking form/fields/slots/write）+ 验证码门禁 | 拆 `cgyy_read/` + `cgyy_write/` + `cgyy_challenge/` | `cgyy_gateway.dart` 自建服务定位器（见边界审查 §1.3） |
| `features/settings/`（5 文件 1 620 行） | 混装 设置主页 / 偏好 / 维护（更新+诊断）/ 网络诊断 / 主题预览 | 至少拆 `settings/` + `maintenance/` | `maintenance_pages.dart` 被 `platform/startup_update.dart:6` 反向 import |
| `features/graduate/`（8 文件） | 混装 教务（GSMIS）+ 学分图（独立 gateway、独立 upstream 服务） | 拆 `graduate/` + `graduate_credit_map/` | `GraduateCreditMapGateway` 与 `GraduateSource` 是两套端口 |
| `features/homework/` | 混装 列表 / 详情 / 文件提交面板 / 截止规则投影 | 规则投影上移 | `homework_projection.dart` 被 `shared/reminders.dart` 引用 |
| `features/learning/` | 混装 课程 / 公告 / 资料 / 测验 / 本机快照 | 快照移出 | `learning_snapshots_page.dart` 走 `LearningSnapshotGateway`（本机） |
| `shared/`（8 文件） | 混装 4 类职责：纯工具（`school_timestamp`/`today_time`）、业务规则（`reminder_rules`）、持久化（`app_preferences`）、平台集成（`reminders` 含 MethodChannel） | 至少拆 `shared/`（工具）+ `rules/`（规则）+ `storage/`（存储）+ `platform/`（平台） | `shared/reminders.dart:27` 定义 `MethodChannel('cn.edu.buaa.ginkgo/reminders')` |
| `shared/checkin_sessions.dart` | 签到场次去重规则（iClass 域内纯函数） | `features/checkin/` 或 domain | 被 `shared/reminder_rules.dart:2` 引用 |
| `application/`（21 文件） | 混装 5 类职责：gateway + 值类型 / UI 状态机（`refresh_section.dart`）/ 呈现映射（`failure_message.dart`）/ 本机存储（`local_tasks.dart`）/ 诊断（`diagnostic_log.dart`） | 至少拆 `application/` + `presentation/` + `storage/` | `application/collection_window.dart` 是纯 UI 概念；`application/local_tasks.dart:3` import `path_provider` |
| `platform/`（6 文件） | 混装 平台适配器（`android_update_controller`/`system_settings_service`）+ **呈现组件**（`update_download_section.dart` 100 行、`startup_update.dart` 234 行）+ **网络抓取**（`update_gate.dart` 179 行） | 呈现部分移出 | `platform/maintenance_service.dart` 是 **1 行纯 re-export** `infrastructure/maintenance_service.dart` |
| `design/academic_widgets.dart` | 共享组件（`AcademicBadge`/`AcademicFactRow`/`AcademicMetric`/`AcademicMetricGrid`） | `widgets/` | `design/` 与 `widgets/` 边界不清：`design/` 里有 widget，`widgets/` 里有 barrel |
| `lib/startup_page.dart`（264 行） | 启动页（页面） | `features/startup/` 或 `app/` | 位于 `lib/` 根目录，与 `main.dart`、`mirror_service.dart` 并列 |

### 2.4 目录命名三种口径混用

| 口径 | 目录 | 例子 |
| --- | --- | --- |
| **学校系统** | `cgyy` `library` `shuttle` `bykc` `classroom` | 研讨室 / 图书馆 / 校车 / 博雅 / 空教室 |
| **业务功能** | `homework` `learning` `grades` `tasks` `notices` `career` `campus_card` | 作业 / 学习 / 成绩 / 待办 / 通知 / 就业 / 校园卡 |
| **UI 角色** | `today` `reservations` `settings` `auth` `campus` | 工作台 / 预约 / 设置 / 登录 / 学术文化 |

同一层级混用三种口径，且 `campus`（学术文化）与 `campus_card`（校园卡）前缀相同语义无关。`today` 实际是「工作台」，`reservations` 实际是「资源聚合页」，`auth` 实际只有登录页。

### 2.5 目录粒度差异 15 倍

| 规模 | 目录 |
| --- | --- |
| 15 文件 | `library`(3 028 行)、`cgyy`(3 159 行) |
| 11–12 文件 | `today`(1 832)、`schedule`(2 172) |
| 6–8 文件 | `bykc`、`classroom`、`graduate`、`homework`、`learning`、`settings` |
| 1 文件 | `auth`(477)、`campus_card`(177)、`campus`(221)、`career`(279)、`grades`(401) |

### 2.6 文件命名后缀 7 种混用

`*_page` / `*_view` / `*_panel` / `*_section`(单) / `*_sections`(复) / `*_controls` / `*_widgets` / `*_models` / `*_tile` / `*_block` / `*_cards` / `*_list`。

典型不一致：

- `cgyy_day_page.dart` + `cgyy_day_view.dart` —— 同一功能两种后缀；
- `_view` 后缀共 3 处且语义不一：`bykc_statistics_view.dart`（页面）、`cgyy_day_view.dart`（页面视图）、`schedule_views.dart`（三个不同组件的合集）；
- `schedule_views.dart`（`_views` 复数，实为 `ScheduleCourseBrowser` + `ScheduleSemesterWeeks` + `ScheduleExamList` 三个不同组件的合集）；
- `today_presentation.dart` —— 实为 `todayCoursePlaceLabel()`（纯函数）+ `TodayVisualDivider` + `TodayVisualSection` + `TodaySectionHeader`，**函数与组件混在一个文件**；
- `classroom_sections.dart` / `graduate_sections.dart` —— 复数「合集文件」，内含 4–5 个互不相关的组件。

---

## 3. 目录层级与依赖方向

### 3.1 插件依赖落位（`pubspec` 插件出现在错误的层）

| 插件 | 出现层 | 判定 |
| --- | --- | --- |
| `path_provider` | **`application/local_tasks.dart:3`** | ✗ 应用层依赖平台插件 |
| `path_provider` | `shared/app_preferences.dart`、`shared/reminders.dart` | ✗ 共享层依赖平台插件 |
| `path_provider` | `features/schedule/course_visibility.dart` | ✗ 功能层依赖平台插件 |
| `crypto` | `shared/reminders.dart`、`features/schedule/course_visibility.dart` | ✗ 同上 |
| `url_launcher` | 8 个 feature 页面 | 可接受（呈现动作），但 8 处各自实现校验与失败提示 |
| `path_provider` | `workspace/workspace_shortcut_preferences.dart`、`platform/*`、`infrastructure/*` | ✓ 合理 |

`shared/app_preferences.dart` 与 `shared/reminders.dart` 各自读文件、算 sha256、写 JSON —— 这是**持久化实现**，应在 `infrastructure/`。

### 3.2 依赖方向倒置（4 处）

| 倒置 | 位置 |
| --- | --- |
| `platform/` → `features/settings/` | `platform/startup_update.dart:6` import `features/settings/maintenance_pages.dart` |
| `shared/` → `features/` | `shared/reminders.dart:15-16`、`shared/reminder_scope.dart:6` |
| `widgets/` → `shared/` | `widgets/apple_surfaces.dart:4` → `shared/app_preferences.dart` |
| `application/` → 平台插件 | `application/local_tasks.dart:3` → `path_provider` |

### 3.3 根目录职责

`flutter/lib/` 根目录只剩 3 个文件，但职责互不相同：

| 文件 | 性质 | 应归属 |
| --- | --- | --- |
| `main.dart`（262 行） | 组合根 + 启动/登录状态机 | ✓ 合理（但 `GinkgoRoot` 与 `app/ginkgo_app.dart` 的职责需明确切分） |
| `mirror_service.dart` | 兼容 barrel + 服务定位器工厂 | 应拆：类型 barrel 与工厂分离，工厂只允许组合根 import |
| `startup_page.dart`（264 行） | 页面 | `features/startup/` 或 `app/` |

### 3.4 `platform/` 的 1 行 re-export

`lib/platform/maintenance_service.dart` 全文只有：

```dart
export 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';
```

`platform/` 声明的是平台**端口**，`infrastructure/` 是**适配器**；现在 `platform/` 直接 re-export `infrastructure/`，依赖方向反了，且这一行没有任何价值。

### 3.5 ✅ 已修复（2026-10-28）`design/` 与 `widgets/` 边界

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) D-17。三个组件文件已移到 `widgets/`，`design/` 只保留 token、主题与门面。

| 目录 | 当前职责 |
| --- | --- |
| `design/` | token、主题与设计门面 |
| `widgets/` | 共享 UI 组件与少量呈现工具 |

建议合并为 `design/`（token + 主题 + logo）与 `ui/`（组件）两个目录，或把 `design/` 里的 4 个组件文件移入 `widgets/`。

---

## 4. 建议收敛顺序

**第一批：设计语言基础（不动功能，只补 token 表与门面）**

1. 补 token 档位：字阶加 `15`/`16`（正文/次级正文实际用量最大）；圆角加 `3/4/5/6/14/16/24` 或把越界值收敛到已有档；间距补 `6/10/14/18/22/28/36`。
2. 新增缺失维度：图标尺寸阶（`GinkgoIcons`）、字重（`GinkgoWeights`）、触控目标（`GinkgoTouch.minSize = 48`）、底部留白（`GinkgoSpacing.contentBottom = 96`）、分割线宽度、阴影/透明度层级。
3. 拓宽 `AppleDesign` 门面（或直接取消门面、统一走 `Ginkgo*`），**二选一**，消除双路径。
4. 删掉 31 个死 token 或补上引用；合并 `statusUncertain`/`statusInactive`。
5. `check-design-tokens.py` 增加「越界档位」维度（不只是数量预算）。

**第二批：组件收敛（消除 6 套三态 / 8 套徽标 / 17 套行）**

6. 在 `widgets/` 建立唯一的三态组件（加载 / 空 / 错误 + 旧快照提示），替换 `ScheduleEmptySection`、`LibraryEmptyState`、`CgyyStatusSection`、`ClassroomLoadingState`/`ClassroomRefreshingState`/`ClassroomMessageState`、`LibrarySectionStatus`、`TodayVisualSection`。
7. 统一页头（含刷新按钮）、徽标、指标卡、键值行、折叠区、确认对话框六类。
8. 共享组件自身改用 token（`apple_surfaces.dart` 的 36/16/44/20/15、`ginkgo_visuals.dart` 的 12/10/11）。

**第三批：模块归属与目录**

9. `features/tasks/rules_page.dart` → 新建 `features/academic/`。
10. `features/schedule/course_visibility.dart` → `shared/` 或 `application/`（连带解除 `shared/` → `features/` 倒置）。
11. `features/reservations/` → `workspace/`；`lib/startup_page.dart` → `app/`。
12. `features/library/` 拆 `library_seating/` + `library_catalog/` + `library_loans/`；`features/cgyy/` 拆读/写/验证码；`features/settings/` 拆 `settings/` + `maintenance/`。
13. `shared/` 按职责拆 4 份；`application/` 拆出 `presentation/`（`refresh_section`、`failure_message`）与 `storage/`（`local_tasks`）；`platform/` 移出呈现组件与网络抓取；`platform/maintenance_service.dart` 的 1 行 re-export 改为真正的端口定义。
14. `design/` 与 `widgets/` 边界确定（合并或移动 4 个组件文件）。

**第四批：网关边界（收益最大，改动最深）**

15. Dart gateway 逐个镜像 Rust 端口：`LibrarySeatingGateway` / `LibraryCatalogGateway` / `LibraryLoansGateway` / `ShuttleGateway` / `LocalTaskGateway` / `BykcGateway` / `GraduateGateway` / `GraduateCreditMapGateway` / `NoticeGateway` / `CgyyGateway` / `CgyyBookingGateway`。
16. 组合根一次性装配，页面不再做 `is XxxGateway` 探测（消除 25 处探测 + 13 处强转），「不支持」改为**显式能力矩阵**（`MirrorCapabilities`）而不是空 gateway。
17. `LibraryGateway` 移除 `shuttleTimetable`，`CampusGateway` 移除 `editTasks`。

**第五批：命名与文档**

18. `Apple*` → `Ginkgo*` 重命名（833 行 / 102 个引用，一次性机械替换 + 测试兜底）。
19. 目录命名统一到一种口径（建议「业务功能」，学校系统信息进 `application/career.dart` 这类 gateway 文件名与 `docs/API.md`）。
20. 文件后缀统一为 `_page` / `_section` / `_widget` / `_model` / `_controller` 五种，删除合集文件（`schedule_views.dart`、`today_presentation.dart`、`classroom_sections.dart`、`graduate_sections.dart`、`library_cards.dart`、`today_course_list.dart`）。
21. `docs/ARCHITECTURE-TOPOLOGY.md` 补「目录层级与归属规则」一节，把本篇的归属决策固化。

---

## 5. 结论

设计系统的**内容质量不差**（token 表本身有 4pt/8pt 间距、HIG 字阶、圆角阶、动效与 reduce-motion 适配），问题是**从未被真正采纳**：

- 81 个定义里 31 个是死 token，字阶缺 `15`/`16` 这两个用量最大的档位；
- 图标尺寸、字重、触控目标、底部留白、分割线、透明度这 6 个维度**根本没有 token**；
- 同一视觉模式平均有 3–17 套实现；
- 共享组件自己也在硬编码。

模块归属的根本缺陷是**Dart 网关没有镜像 Rust 端口边界**：`LibraryGateway` 里装着校车，`CampusGateway` 里装着本机待办；由此派生出 25 处运行期能力探测、13 处强转、演示模式能力缺失，以及「当前服务不支持 X」这种本应是显式建模却沦为架构副作用的产品状态。

目录层面，`features/` 24 个目录里混用了「学校系统 / 业务功能 / UI 角色」三种命名口径，粒度从 1 文件到 15 文件不等；`shared/`、`application/`、`platform/` 各自混装了 4–5 种职责；`design/` 与 `widgets/` 边界不清；`platform/` 反向依赖 `features/settings/`。

建议按 §4 的五批推进：第一、二批不改功能行为、可当天完成；第三批解决归属与目录；第四批（网关边界）收益最大但需要为「不支持」状态补产品级回归；第五批是机械重命名与文档固化。

本文只描述源码结构，不代表功能已发布或已通过真实账号验收。

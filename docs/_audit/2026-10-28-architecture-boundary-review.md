# 架构边界、重复逻辑与文档同步审查（2026-10-28）

范围：Android（Flutter + Rust）工作树全量业务代码。本轮只做**只读审查与文档核对**，未修改任何业务代码。

## 0. 审查基线

| 项 | 结果 |
| --- | --- |
| `bash scripts/check-mirror.sh` | 通过（架构门禁、design token 预算、接口索引、cargo fmt/clippy、Rust 全 workspace 测试、Flutter analyze、557 项 `flutter/test`、FRB 生成无漂移） |
| `git status` | 审查前后均干净；FRB 二次生成与工作树逐字节一致 |
| 文件级 Dart 依赖图 | **无强连通分量**（0 个文件级环） |
| 目录级 Dart 依赖图 | 29 个分组、158 条跨组依赖，其中 28 个分组落在同一个强连通分量内 |

> 与 [`ARCHITECTURE-TOPOLOGY.md`](../ARCHITECTURE-TOPOLOGY.md) §4.2 的表述有出入：该节把目录级环描述为「一条真实环」，实测**文件级依赖图是 DAG**，目录级环由「同目录内文件互相引用」放大而来（详见 §1.2）。

规模快照：

| 层 | 位置 | 行数 |
| --- | --- | --- |
| Flutter 页面与组件 | `flutter/lib/`（排除 `src/rust`） | 202 文件 / 35 543 行 |
| 其中功能域 | `flutter/lib/features/` | 24 409 行（占 69%） |
| Rust 业务代码 | `rust/crates/`（排除 `frb_generated.rs`） | ~39 000 行 |
| 领域层 | `ginkgo_domain` | 3 545 行（features + foundation + ports） |

---

## 1. 分层边界问题

### 1.1 根 barrel 把 infrastructure 泄漏给 43 个页面（P0）✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-01。37 处页面层 import 改指 `application/mirror_service.dart`；工厂移入 `infrastructure/service_factory.dart`；`grep` 验证页面层零 adapter/`src/rust` 引用。


`flutter/lib/mirror_service.dart` 同时做了两件事：

```dart
export 'package:ginkgo_mirror/application/mirror_service.dart';
export 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';  // ← 含 FRB 生成绑定
export 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
```

**43 个文件** import 这个 barrel（`features/` 35、`workspace/` 2、`application/local_tasks.dart` 1、`shared/reminder_scope.dart` 1、`main.dart` 1）。结果是所有页面在**编译期**都依赖 `src/rust` 生成绑定与演示服务，违反 AGENTS.md「页面只碰 ②」与 `ARCHITECTURE-TOPOLOGY.md` §1 的第 1 条硬规则。

实际运行时耦合只有 6 处调用 `mirrorServiceFor(demo:)`（`tasks_page.dart:44`、`graduate_page.dart:166`、`cgyy_gateway.dart:34`、`cgyy_day_page.dart:99`、`notices_page.dart:40`、`bykc_page.dart:75`），其余 37 处只用 gateway 类型。

**修法**：类型一律从 `application/mirror_service.dart` 直取；`lib/mirror_service.dart` 只保留 `mirrorServiceFor()` 工厂且**只允许 `main.dart` / `workspace/` import**。工厂调用点改为构造注入（壳层已经在 `WorkspaceContext.service` 里提供了服务）。

### 1.2 `shared/` 反向依赖 `features/`（P0，唯一真实的层间倒置）✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-02。`course_visibility` 拆为 `shared/` 状态 + `features/schedule/course_range_page.dart`；`personalHomeworkItems` 上移 `shared/homework_visibility.dart`；`shared/` 现零 `features/` 依赖。


```
lib/shared/reminders.dart:15        → features/schedule/course_visibility.dart
lib/shared/reminders.dart:16        → features/homework/homework_projection.dart
lib/shared/reminder_scope.dart:6    → features/schedule/course_visibility.dart
```

- `features/schedule/course_visibility.dart` 是**跨域共享状态**（课程可见性），却放在课表域内；它还 import `schedule_widgets.dart`（`ScheduleSection` / `ScheduleEmptySection`），把共享状态绑死在课表域组件上。
- `features/homework/homework_projection.dart`（截止分类规则）被 `shared/` 直接引用，等于「共享层反向依赖业务域规则」。

这条链是目录级环 `application → shared → features/schedule → application` 的唯一来源。

**修法**：`course_visibility.dart` 与 `homework_projection.dart` 中的**规则部分**上移到 `shared/` 或 `application/`，`features/` 只保留呈现；共享层不再 import 任何 `features/`。

### 1.3 `features/cgyy/cgyy_gateway.dart` 自建服务定位器并直出 FFI 载荷（P0）✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-03。去掉 `mirrorServiceFor` 回退，服务缺失时显式失败；`bookingGateway` 只取注入服务。


```dart
return (service ?? mirrorServiceFor(demo: demo)).cgyy(...);   // :34
Future<live.ReadOnlyResponse> cgyyRead({...})                  // :16
```

- 域内自建服务定位器，绕过 `application/` 契约层；
- 返回值是 FFI 传输信封 `ReadOnlyResponse`（`payload` + `stale` + `failure`），页面再在 `cgyy_models.dart` 解码 —— 契约侵蚀在 CGYY 域最严重。

### 1.4 `widgets/` 依赖持久化层（P1）

`flutter/lib/widgets/apple_surfaces.dart:4` import `shared/app_preferences.dart`，`AppleListTile` 在 `:304` 读 `AppPreferencesScope.of(context).compactLists`。呈现组件因此依赖应用存储，且脱离 `AppPreferencesScope` 时行为不确定。

`widgets/` 12 个文件中，`apple_surfaces.dart`、`apple_controls.dart`、`apple_navigation.dart`、`mutation_dialog.dart`、`reminder_badge.dart`、`day_scroll_physics.dart`、`diagnostic_hints.dart` **无任何测试文件直接引用**；只有 `loading_widgets.dart`（20 个测试文件引用）、`collection_toolbar.dart`（2）、`long_page_scroll.dart`（1）、`resource_meter.dart`（1）有覆盖。`apple_widgets.dart` 只是 7 行 barrel，其覆盖面被上表计入。

### 1.5 其它跨层引用（P2）✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-05。页面层 import 已全部改指应用契约；`features → infrastructure` 剩余 3 处文件 IO 助手见 B-05 备注。


| 位置 | 引用 | 说明 |
| --- | --- | --- |
| `features/homework/homework_files_panel.dart:6` | `infrastructure/homework_file_io.dart` | 平台文件 IO 助手下沉到 features |
| `features/learning/learning_page.dart:6`、`learning_course_page.dart:9` | `infrastructure/learning_file_actions.dart` | 同上 |
| `application/local_tasks.dart:6` | 根 `mirror_service.dart` | 应直取 `application/mirror_service.dart` |
| `features/*` 跨域 import 44 处 | 例：`today → homework/schedule/tasks`、`checkin → schedule`、`tasks → homework`、`shuttle → today`、`settings → graduate/learning` | 组合式引用与规则泄漏需分开判定 |

---

## 2. 重复代码与重复逻辑

### 2.1 ✅ 已修复（2026-10-28）页面异步状态机手写 7 份，`RefreshSection` 只覆盖 13 个文件

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-06/B-07。七页已迁移，就业活动与学术文化共用公开信息模板。

`application/refresh_section.dart` 已经实现了「重叠读取合流 / 强制刷新补跑 / 代次丢弃 / 失败保留旧值」，但只有 `today`、`learning`、`graduate`、`library_controller` 在用。下列 7 个文件各自手写了同一套 `busy + pendingRefresh + error` 状态机：

`notices_page.dart:20-61`、`career_events_page.dart:26-88`、`campus_activities_page.dart:26-81`、`cgyy_page.dart:27-73`、`library_stats_page.dart:23-82`、`homework_page.dart:37-174`、`homework_detail_page.dart:39-100`。

其中 `career_events_page.dart` 与 `campus_activities_page.dart` **行级相似度 0.661**（280 / 222 行），是同一模板的两份拷贝：同样的 `didUpdateWidget` 代次自增、同样的 `load({force})`、同样的三段错误 UI、同样的「无法打开官网」对话框。

代次守卫目前有 3 种写法并存：`today_page.dart:84` 的 `_generation`、`library_controller.dart:21-27` / `RefreshSection` 的 `_generation` + `invalidate()`、`career_events_page.dart` / `campus_activities_page.dart` 的 `requestGeneration`。语义相同、实现不同，迁移时必须统一到 `RefreshSection.invalidate()`。

### 2.2 ✅ 已修复（2026-10-28）空态 / 错误态包装组件 3 套 + 页面内联

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-08/B-09。统一为 `AppleStatusSection` 与 `AppleRefreshPageHeader`，旧别名已删除。

| 包装 | 位置 | 实际实现 | 使用点 |
| --- | --- | --- | --- |
| `ScheduleEmptySection` | `features/schedule/schedule_widgets.dart:220` | `AppleSection` + `AppleEmptyState` | 4 |
| `LibraryEmptyState` | `features/library/library_widgets.dart:56` | `AppleSection` + `AppleEmptyState` | 11 |
| `CgyyStatusSection` | `features/cgyy/cgyy_widgets.dart:51` | `AppleSection` + `AppleEmptyState` | 9 |

三者语义等价、参数一一对应（`title/description/action/onAction/error`），差别只有 `animateSize`。同时 `notices` / `career` / `campus` 三个页面把同样的 `AppleSection(children:[AppleEmptyState(...)])` 内联写了两遍。

同类还有页头包装 3 套：`ApplePageHeader`（`widgets/`）、`LibraryPageHeader`（`features/library/library_widgets.dart:14`，8 处）、`CgyyPageHeader`（`features/cgyy/cgyy_widgets.dart:36`，3 处）。

功能域 widget 合计 ~4 100 行（13 个 `*_widgets.dart`），与 `widgets/`（1 687 行）职责大面积重叠。

### 2.3 ✅ 已修复（2026-10-28）北京时间换算旁路 6 处

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-10。6 处全部改指 `todaySchoolNow()`；`Duration(hours: 8)` 现只存在于 `shared/` 的 3 个规范实现文件。


规范实现是 `shared/today_time.dart:5` 的 `todaySchoolNow()` 与 `shared/school_timestamp.dart:27`。以下位置各自重写 `toUtc().add(const Duration(hours: 8))`：

`career_events_page.dart:31`、`schedule_style.dart:63`、`schedule_style.dart:76`、`task_editor.dart:76`、`today_course_section.dart:192`、`library_stats_page.dart:54`。

（`MIRROR-TODO` P2 已登记 `checkin_page.dart` 与 `library_stats_page.dart`；实测应补齐上列 6 处。）

### 2.4 ✅ 已修复（2026-10-28）「打开官网」4 套实现

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-11。统一 URL 校验、外部打开和失败文案，并拒绝嵌入用户信息。

`career_events_page.dart:100-124`、`campus_activities_page.dart:93-116`、`service_search_page.dart:170-190`、`notices_page.dart:164-172`、`shuttle_page.dart:142`、`library_loans_page.dart:99`、`homework_detail_page.dart:354`、`learning_course_page.dart:311` —— 各自做 `https` + host 校验 + `launchUrl` + 失败提示，失败文案 4 种（「无法打开官网」/「无法打开原文」/「无法打开浏览器，请稍后重试」/「无法打开链接，请稍后重试」）。

### 2.5 ✅ 已修复（2026-10-28）Rust 侧「读配方」在 10 个 service 手写重复（P0）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) B-12。统一 `ReadSnapshot<T>`、`read_with_snapshot` 与账号检查版，全部读服务已收编。

同一条读路径模板在 upstream 服务层被逐份复制：

1. `let account = self.current_account()?;`
2. 命中新鲜缓存 → 返回 `from_cache: true, stale: false`
3. `let ticket = cache.lock().begin(&key);`
4. 网络读取 + `SessionExpired` 时 `silent_login()` 重试
5. `if self.current_account()? != account { return Err(AppError::session_expired()); }`
6. 成功 → `insert_if_current` → `from_cache: false, stale: false, failure: None`
7. 失败 → `cache.any(&key)` → `from_cache: true, stale: true, failure: Some(e)`；无快照则 `Err(e)`

涉及 `schedule_service.rs`、`classroom_service.rs`、`homework_service.rs`、`library_service.rs`（7 处）、`library_stats_service.rs`、`checkin_service.rs`、`career_service.rs`、`campus_activities_service.rs`、`notices_service.rs`、`graduate_service.rs`（用 `resolve_current` 变体）。证据：`insert_if_current` 非测试调用 21 处、`silent_login` 重试点 12 处、`stale: true` 构造 8 处。

`library_service.rs:84-97` 已有 `library_retry` 助手把 token 重建收敛成一次，但**其余 8 个 service 的会话重试仍是各自复制**。

### 2.6 ✅ 已修复（2026-10-28）根因：13 个 bespoke Outcome 字段不一致

> 字段一致的七类已改为 `ReadSnapshot<T>` 别名；带日期、统计或过滤结果的专用 Outcome 保留业务字段。

| Outcome | data | fetched_at | from_cache | stale | failure |
| --- | --- | --- | --- | --- | --- |
| `DataOutcome<T>` | ✓ | — | — | — | ✓ |
| `ScheduleOutcome` / `TodayOutcome` / `GradeOutcome` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ClassroomOutcome` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `CheckInOutcome` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `LibraryVenues/Bookings/HistoryOutcome` | ✓ | ✓ | ✓ | ✓ | ✓ |
| **`HomeworkOutcome`** | ✓ | ✓ | **—** | **—** | ✓ |
| **`LibraryStatsOutcome`** | ✓ | ✓ | ✓ | **—** | ✓ |
| **`CareerEventsOutcome`** | ✓ | **—** | **—** | **—** | ✓ |
| **`CampusActivitiesOutcome`** | ✓ | **—** | **—** | **—** | ✓ |

正因为没有统一信封，`MIRROR-TODO` P0 才需要单独记「作业结果已传递原成功时间」「首次与缓存返回的成功时间已统一」这类逐模块补齐项。

**修法**：在 `ginkgo_domain` 定义统一读信封（例如 `Snapshot<T> { data, fetched_at, from_cache, stale, failure }`），把 13 个 bespoke 结构改为 `type` 别名或直接替换；upstream 侧提供 `read_with_snapshot()` 统一实现 §2.5 的 7 步模板。

### 2.7 协议语义仍在 Dart（未随 Rust 迁移）

| 泄漏 | Dart 位置 | Rust 侧现状 |
| --- | --- | --- |
| CGYY 订单/审批状态码（`order_status` 1/2/3、`check_status`） | `features/cgyy/cgyy_models.dart:73-100` | `ginkgo_domain/src/features/cgyy.rs:33-35` 只传原始 int |
| 校车「今天适用」周次/星期区间规则 | `features/shuttle/shuttle_models.dart:43-75` | `ginkgo_domain/src/features/shuttle.rs:17-21` 只传 label 原文 |
| 签到窗口、提醒排程、截止分类、UTC+8「今天」 | `shared/reminder_rules.dart:18-96`（`checkinWindowOpen`、`checkinReminders`）、`features/homework/homework_projection.dart:44-70`（`classifyHomeworkDeadline`）、`features/library/library_stats_page.dart:48` | 未下沉 |

---

## 3. 协议分离现状（正面结论）

- `ginkgo_domain` 全层 **0 处 URL、0 处 `buaa.edu.cn`、0 处学校字段名** —— 领域层边界干净。
- `core` 只依赖 `ports`，学校实现由 `upstream` 从外部注入，依赖方向正确。
- 学校原始 JSON 不进 Dart：跨 FFI 的是 Rust 净化后的领域 JSON，且 `scripts/check-mirror-architecture.py` 强制解码只能发生在 `infrastructure/` 或 `*_models.dart`（实测 `lib/` 内 `jsonDecode` 共 **34** 处：`infrastructure/` 10、`features/` 19、`shared/` 2、`application/` 1、`platform/` 1、`workspace/` 1；除 `*_models.dart` 与 `infrastructure/` 外的 6 处全部是本机偏好/本机存储文件：`update_gate.dart:52`、`workspace_shortcut_preferences.dart:86`、`course_visibility.dart:72`、`app_preferences.dart:95`、`reminders.dart:92`、`local_tasks.dart:64`，没有一处是学校载荷）。
- **待改进**：`ginkgo_upstream/src/endpoints.rs` 名不副实 —— 只收 `HOMEWORK_PORTAL` 与 `NOTICE_PAGE` 两个常量，其余端点散落在 `adapters/`、`codecs/`、`services/`、`auth/`（`auth/session.rs:92,263-264`、`auth/redirect.rs:37+`、`codecs/shuttle.rs:12,188`、`codecs/updates.rs:7` 等）。协议虽未越层，但缺少统一台账，与 `API.md` 附录 A「已验证 URL 总表」无法机械对齐。

---

## 4. 文档同步与准确性

### 4.1 `ARCHITECTURE-TOPOLOGY.md` 数字过期 ✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) C-01。


| 位置 | 文档写的 | 实测 |
| --- | --- | --- |
| §1 五层图 `traits[...]` | 「26 个 trait」 | **29 个**（`ginkgo_domain/src/ports/*.rs`） |
| §4 依赖图快照 | 「26 个分组节点…143 条跨组依赖」 | **29 个分组、158 条跨组依赖**（`docs/interfaces/DEPENDENCY-GRAPH.md`） |
| §4.2 循环依赖 | 「25 个分组同属一个强连通分量」 | **28 个分组** |
| §6 能力地图 | 「24 项能力」 | **27 项**（`INTERFACE-INDEX.md` §2 能力总表 27 行） |

该文件的 §8 已声明「目录依赖图由 `scripts/generate-interface-index.py` 扫描 import 生成」，但 §4 的手写快照没有随生成物更新。

### 4.2 `INTERFACE-INDEX.md` §6.10 载荷信封清单漏 2 个命令 ✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) C-02。


实测（`flutter/lib/src/rust/api/live.dart` + `mirror.dart` + `live/auth_challenge.dart` 逐个方法解析）：

| 形态 | 文档写的 | 实测 |
| --- | --- | --- |
| 命令总数 | 89 | **89** ✓ |
| 类型化 DTO | 48 | **46** |
| `ReadOnlyResponse` 载荷 | 41 | **43** |

文档正文自己列出的清单有 **43 项**（表格里的 48/41 与清单自相矛盾），且清单**缺少 `loadCareerEvents` 与 `loadCampusActivities`** —— 两者是 2026-10-28 新增的能力（就业活动 / 学术文化），登记时没有回写接口索引。

### 4.3 `MIRROR-TODO.md` P2 的 FFI 数字同样过期 ✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) C-03。


原文：「实测 87 个 FFI 命令中 46 个返回类型化 DTO、41 个仍用载荷信封」—— 命令总数应为 89，载荷信封应为 43。

### 4.4 `API.md` 章节层级错乱 ✅ 已修复（2026-10-28）

> **修复记录**：见[整改台账](2026-10-28-review-remediation.md) C-04。


`docs/API.md` 的标题顺序为 `… §6E → §6F → §6D → §7 → §8 → §9 → ### 7.3 → ### 7.4 → 附录 A`。

- `### 7.3`、`### 7.4` 出现在 `## 8. 统一错误处理`、`## 9. 请求拦截器` 之后，脱离了 §7 父节；
- `§6D 阳光打卡` 排在 `§6F 学术文化` 之后；
- §7.4 的正文在 `---` 分隔线之后才补上「培养方案执行报告」表格，与小节标题分离。

锚点引用仍然可用（`INTERFACE-INDEX` 指向的 `#614-…` 等存在），但目录结构对读者不成立。

### 4.5 `docs/_audit/2026-10-25-engineering-debt-audit.md` 的复核结论

三天前的工程债审计中，多项已修复，部分已失效，部分仍然成立：

| 审计条目 | 当前状态 |
| --- | --- |
| §4.4 `lib/` 根目录承担过多职责（98 个文件） | **已修复**（根目录现仅 `main.dart`、`mirror_service.dart`、`startup_page.dart`） |
| §4.6 `cgyy_day_page.dart:106` 写死 `demo: false` | **已修复**（`:99` 改为 `demo: widget.demo`） |
| §5.5 48/73 测试文件直连 `src/rust` | **改善**（现 26/97） |
| §4.1 同一业务规则 4 种状态管理模式 | **未修复且已扩大**（新功能 `notices` / `career` / `campus_activities` / `campus_card` 继续新增第 5 种手写模式，见 §2.1） |
| §4.2 重复脚手架量化（按**命中文件数**口径） | **未修复且扩大**：`catch (_)` 41 → **61** 文件、`setState(` 40 → **60** 文件、`bool busy` 32 → **40** 文件、`String? error` 29 → **37** 文件、`GinkgoLoadingView(` 23 → **28** 文件、`AppleEmptyState(` 21 → **23** 文件、`AppleGlassButton(` 19 → **21** 文件；`GinkgoActivity(` 33 → 34 基本持平 |
| §1.3 表现层持有学校协议语义 | **未修复**（CGYY 状态码、校车周次规则，见 §2.7） |
| §1.1 bridge DTO 映射层无有效覆盖 | **部分改善**：bridge 侧 `#[test]` 由 4 处增至 11 处（`live/mapping.rs` 6、`live/learning_tests.rs` 2、`live.rs` / `live/utilities.rs` / `reminder_planning.rs` 各 1），`mapping.rs` 增至 596 行。但 93 个命令函数对应 11 个测试，载荷信封命令（43 个）仍无逐命令 DTO 回归 |
| §4.3 设计 token 被系统性绕过 | **未修复**（`scripts/check-design-tokens.py` 预算已用满：fontSize 204/204、EdgeInsets 268/268、SizedBox 208/208、BorderRadius 42/42，只许减不许增；`apple_design.dart` 44 行门面仍只暴露约 16 个 token） |

另有一处 TODO 登记已失效：`MIRROR-TODO` P2 「把稳定业务规则搬回 `ginkgo_domain`」写的是 `checkin_page.dart:54-57` 的 UTC+8「今天」，但 `checkin_page.dart` 现已无 `Duration(hours: 8)` 硬编码；该条应改为本文件 §2.3 的 6 处位置。

---

## 5. 建议收敛顺序（映射到 `MIRROR-TODO.md`，不新建清单）

**第一批（结构性、可立即执行、不改行为）**

1. 拆根 barrel：页面只 import `application/mirror_service.dart`；`mirrorServiceFor` 调用点收敛到壳层注入。（§1.1）
2. `shared/` 断开源依赖：`course_visibility` 与 `homework_projection` 的规则部分上移，`shared/` 不再 import `features/`。（§1.2）
3. 统一空态 / 页头组件：保留 `widgets/` 唯一实现，删掉 `ScheduleEmptySection` / `LibraryEmptyState` / `CgyyStatusSection` / `LibraryPageHeader` / `CgyyPageHeader` 五个别名包装，调用点改为直用共享组件。（§2.2）
4. UTC+8 只走 `todaySchoolNow()`。（§2.3）
5. 统一「打开官网」助手：URL 校验 + 失败提示收敛到一处。（§2.4）

**第二批（收敛重复逻辑，需补回归）**

6. 7 个手写异步状态机迁到 `RefreshSection`，`career` / `campus_activities` / `notices` 三页合并为一个「公开信息列表」页面模板。（§2.1）
7. `ginkgo_domain` 引入统一读信封 `Snapshot<T>`，替换 13 个 bespoke Outcome；upstream 引入 `read_with_snapshot()` 收编 §2.5 的 7 步模板，`silent_login` 重试推广到全部 service。（§2.5、§2.6）
8. CGYY 状态码、校车适用规则下沉到 `ginkgo_domain`，Dart 只渲染。（§2.7）

**第三批（契约与文档）**

9. `loadCareerEvents` / `loadCampusActivities` 补进 `INTERFACE-INDEX.md` §6.10 清单，纠正 46/43 计数。（§4.2）
10. `ARCHITECTURE-TOPOLOGY.md` 的 trait 数、分组数、依赖数、能力数改为从生成物读取或直接标注「见 `interfaces/DEPENDENCY-GRAPH.md`」。（§4.1）
11. `API.md` 章节重排：`6D` 前移到 `6C` 之后，`7.3`/`7.4` 移回 §7 之下。（§4.4）
12. `ginkgo_upstream/src/endpoints.rs` 扩成真实端点台账，与 `API.md` 附录 A 对齐。（§3）

---

## 6. 结论

工程底座是可靠的：门禁全绿、文件级依赖无环、领域层零协议泄漏、FRB 无漂移、桥接契约受脚本强制。

当前的主要风险不在「能不能跑」，而在**同一份语义被复制了 3–10 份**，分布在 Dart 页面层与 Rust 服务层两侧：

- 页面侧：异步状态机 7 份、空态包装 3 份、页头 3 份、时间换算 7 份、外链打开 4 份；
- Rust 侧：读配方 10 份、Outcome 信封 13 种字段组合。

这些副本在 2026-10-28 新增的 `notices` / `career` / `campus_activities` / `campus_card` 四个功能里继续增加，说明缺的不是纪律而是**收敛点**：`RefreshSection` 已有但没人强制用，`Snapshot<T>` 还没有。

建议按 §5 的三批推进：第一批不改行为、可当天完成并立刻消除 5 处层间倒置；第二批需要为每处收敛补「失败保留旧快照 / 刷新合流 / 迟到响应丢弃」回归；第三批只改文档与登记。

本文只描述源码结构与文档现状，不代表功能已发布或已通过真实账号验收。

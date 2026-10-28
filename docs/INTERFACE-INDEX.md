# Ginkgo 接口索引

更新：2026-10-29。本文是 **Android（Flutter + Rust）全链路接口的单一索引**：按层次列出每个接口的标识、功能、输入、输出、副作用与源码位置，用于快速定位「某个能力从界面一路走到学校协议」的完整路径。

本文只做索引与契约说明，不重复上游协议事实。URL、参数、成功码、证据等级以 [API.md](API.md) 为唯一来源；用户能做什么、读写边界与本机数据见 [FEATURES-AND-PROTOCOLS.md](FEATURES-AND-PROTOCOLS.md)；分层职责见 [MIRROR-ARCHITECTURE.md](MIRROR-ARCHITECTURE.md)。

## 1. 怎么读这份文档

本文是**手工维护的总览**：讲清分层、能力归属与跨层不变量。

配套阅读：[架构拓扑与数据流](ARCHITECTURE-TOPOLOGY.md) 用图说明七段调用拓扑、读写时序、写入状态机与数据 IO 形状；本文用表说明每个接口的签名、位置与契约。

**全量接口清单**（每个公开类型、函数、方法、字段，含签名与源码行号）由生成器产出在 [interfaces/](interfaces/README.md)，不要手工编辑：

```sh
python3 scripts/generate-interface-index.py   # 改完接口后重新生成
```

一次调用穿过四层，每层都有明确的输入输出与禁止事项：

```text
Flutter 页面
  → Dart gateway            应用层接口，页面只看这一层
  → FRB 命令                 FFI 边界，粗粒度、跨语言
  → Rust 业务端口（core 编排）
  → Rust 上游适配（学校协议）
```

| 层 | 接口形态 | 总览章节 | 全量清单 |
| --- | --- | --- | --- |
| 上游协议 | HTTP 端点、Cookie、token、成功码 | [§3](#3-上游协议层) | [API.md](API.md)（唯一事实源） |
| 上游适配 | 请求构造与响应解析 | [§3.3](#33-适配器与协议模块) | [rust-upstream-adapters](interfaces/rust-upstream-adapters.md)、[rust-upstream-codecs](interfaces/rust-upstream-codecs.md) |
| 认证会话 | 登录页、表单、凭据、会话验证 | [§3](#3-上游协议层) | [rust-upstream-auth](interfaces/rust-upstream-auth.md)、[rust-upstream-services](interfaces/rust-upstream-services.md) |
| 业务端口 | `ginkgo_domain::ports` 的 trait | [§4](#4-rust-业务端口层) | [rust-domain-ports](interfaces/rust-domain-ports.md) |
| 领域值 | 数据结构与纯规则 | [§4.4](#44-关键输入输出类型) | [rust-domain-features](interfaces/rust-domain-features.md) |
| 应用编排 | `ginkgo_core` 命令与持久化 | [§5](#5-应用编排层) | [rust-core-application](interfaces/rust-core-application.md) |
| 组装 | 真实/演示适配与平台保险库 | — | [rust-runtime](interfaces/rust-runtime.md) |
| FFI 命令 | `ginkgo_flutter_bridge` 导出函数 | [§6](#6-ffi-命令层) | [rust-bridge](interfaces/rust-bridge.md) |
| 应用接口 | `flutter/lib/application` 的 gateway | [§7](#7-flutter-应用接口层) | [dart-application](interfaces/dart-application.md) |
| 平台适配 | native/demo、持久化实现 | [§7.15](#713-平台服务) | [dart-infrastructure](interfaces/dart-infrastructure.md) |
| 共享状态 | 跨域复用的状态与值 | — | [dart-shared](interfaces/dart-shared.md) |
| 设计系统 | token 与共享组件 | — | [dart-design](interfaces/dart-design.md)、[dart-widgets](interfaces/dart-widgets.md) |
| 壳层与导航 | 功能登记表、布局壳 | [§2](#2-能力总表) | [dart-workspace](interfaces/dart-workspace.md)、[dart-app](interfaces/dart-app.md) |
| UI 页面 | 各功能域页面与域内组件 | [§2](#2-能力总表) | [dart-feature-*](interfaces/README.md)（按域拆分） |
| 反向查找 | 从源码文件回查接口 | — | [REVERSE-INDEX](interfaces/REVERSE-INDEX.md) |
| 依赖拓扑 | 目录依赖图与循环检测 | [拓扑 §4](ARCHITECTURE-TOPOLOGY.md#4-模块依赖图生成) | [DEPENDENCY-GRAPH](interfaces/DEPENDENCY-GRAPH.md) |

查找某个功能时，先在 [§2 能力总表](#2-能力总表) 找到它的行，再顺着该行的链接进入各层细节；需要具体签名时进 `interfaces/` 对应文件。

### 1.1 接口设计模式

本仓库的接口不是逐个拍脑袋设计的，而是沿用同一组模式。新增任何接口（端口、FFI 命令、gateway、页面）都应落到下表某一模式；找不到合适模式时，先扩展模式再写代码。

| 模式 | 解决什么 | 具体形态 | 反例（禁止） |
| --- | --- | --- | --- |
| **信封模式** | 区分「本次成功 / 旧快照 / 失败」 | 读结果统一为 `DataOutcome<T>`：`data` + `failure` + `fetched_at` / `from_cache` / `stale` | 用空值同时表达「没有数据」和「请求失败」 |
| **端口模式** | 让编排不依赖学校实现 | `ginkgo_domain::ports` 定义 trait，`ginkgo_core` 只依赖 trait | core 直接引用 `HttpTransport`、Cookie、token |
| **纯规则模式** | 让稳定业务规则可单测 | 领域层纯函数：截止分类、签到窗口、提醒排程 | 把规则留在 Dart/页面里，或在解析时读设备时区 |
| **粗粒度命令模式** | 不把协议细节泄露到 UI | 一个 FFI 命令 = 一个用户可见动作（读一页、提交一次、核对一次） | 把分页参数、Cookie、表单字段透传到 Dart |
| **写状态机模式** | 写操作不确定时不误报 | 写结果只有四态：`accepted` / `rejected` / `notSubmitted` / `uncertain` | 把未知当失败（用户会重发）或当成功 |
| **三件套模式** | 写操作可回查 | 用户明确触发 → 单次提交 → 回查；`uncertain` 只允许回查 | 超时后自动重发、自动补发 |
| **账号绑定模式** | 防止跨账号串数据 | 账号由 Rust 会话派生；网络 await 后复检；代次不匹配丢弃 | 由 Dart 传账号 ID，或把旧响应写回新账号 |
| **投影模式** | 页面不接触原始响应 | Rust 输出领域 JSON → Dart `*_models.dart` 解码为类型 | 页面 `jsonDecode`、`Map<String, dynamic>` 传进组件 |
| **演示同形模式** | 演示模式不碰真实数据 | demo 与真实适配器共享返回类型 | 演示页用另一套假结构，或演示读真实账号 |
| **门禁登记模式** | 新入口可达且可查 | 新页面在 `workspace_catalog.dart` 登记；改公开接口后重生成索引 | 页面存在但无入口；接口改了不刷新索引 |

各模式的落点：

- 信封 / 端口 / 纯规则 / 写状态机 → [§4](#4-rust-业务端口层)、[§5](#5-应用编排层)。
- 粗粒度命令 → [§6](#6-ffi-命令层)。
- 投影 / 演示同形 → [§7](#7-flutter-应用接口层)、[§7A](#7a-flutter-ui-层接口约定)。
- 门禁登记 → [§11](#11-维护方法)。

### 1.2 接口的四个问题

每个接口都应能回答这四个问题；回答不了就说明设计还没收口。

1. **输入**：参数是领域值还是协议值？协议值（URL、表单、Cookie）不得越过 upstream。
2. **输出**：成功、空结果、旧快照、失败分别长什么样？四者必须可区分。
3. **副作用**：是否改学校系统、是否写本机数据、是否清会话？
4. **失败与重试**：失败后能不能重试？重试是否安全？（写操作默认不安全）

## 2. 能力总表

`读/写` 列区分学校副作用：**读** 表示不改学校记录（可能用 POST 只是协议需要）；**写** 表示会修改学校系统，必须用户确认、单次提交、结果回查。

| 能力 | id | 读/写 | 学校系统 | 应用接口 | FFI 命令 | 端口 | 协议 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 会话与认证 | `session` | 写（认证） | CAS / UC | [`SessionGateway`](#71-sessiongateway) | [`restore_session`](#61-会话)、`login`、`sign_out`、`set_route`、`clear_cache` | `SessionSource` | [§1](API.md#1-统一认证sso--uc) |
| 登录验证码 | `auth-challenge` | 写（认证） | CAS | [`AuthChallengeGateway`](#76-authchallengegateway) | [`load_login_challenge`](#61-会话) | `SessionSource::login_challenge` | [§1.3](API.md#13-验证码旧版文档缺失本节补全) |
| 今天 | `today` | 读 | BYXT / GSMIS | [`AcademicGateway.today`](#72-academicgateway) | `load_today` | `TodaySource` | [§2.5](API.md#25-今日课表) |
| 课表 | `schedule` | 读 | BYXT / GSMIS | [`AcademicGateway.schedule`](#72-academicgateway) | `load_schedule` | `ScheduleSource` | [§2.4](API.md#24-周课表核心)、[§3.3](API.md#33-课表数据核心) |
| 考试 | `exams` | 读 | BYXT | 随 `schedule` 返回 | `load_schedule` | `ScheduleSource` | [§2.6](API.md#26-考试安排) |
| 成绩 | `grades` | 读 | buaascore | [`AcademicGateway.grades`](#72-academicgateway) | `load_grades`、`load_grade_terms` | `GradeSource` | [§4](API.md#4-成绩buaascore) |
| 学校作业 | `homework` | 读 | SPOC | [`AcademicGateway.homework`](#72-academicgateway) | `load_homework`、`load_homework_detail` | `HomeworkSource` | [§7.1](API.md#71-bbaa-原版作业实现对照2026-10-15) |
| 作业附件与提交 | `homework-files` | **写** | SPOC | [`HomeworkFilesGateway`](#77-homeworkfilesgateway) | `upload_homework_file`、`submit_homework_file`、`reconcile_homework_file`、`download_homework_file` 等 | `HomeworkSubmissionSource` | [§7.1](API.md#71-bbaa-原版作业实现对照2026-10-15) |
| SPOC 学习 | `learning` | 读 | SPOC | [`LearningCourseGateway` 等](#78-learning-系列-gateway) | `learning_courses`、`course_announcements` 等 | `Learning*Source` | [§7.1.4](API.md#714-spoc-课程学习只读扩展2026-10-26静态证据与实测分开) |
| 课程签到 | `checkin` | **写** | iClass | [`CheckInGateway`](#73-checkingateway) | `load_checkin_today`、`load_checkin_on_date`、`submit_checkin` | `CheckInSource`、`CheckInMutationSource` | [§7.2](API.md#72-iclass-签到状态与手动提交写协议尚待真实验收) |
| 图书馆座位 | `library` | **写** | booking.lib | `LibrarySeatingGateway` | `reserve_library_seat`、`perform_library_action`、`load_library_*` | `LibrarySource`、`LibraryMutationSource` | [§5](API.md#5-图书馆座位bookinglib-v4) |
| 公开查书 | `library-books` | 读 | OPAC | `LibraryCatalogGateway.libraryBooks` | `load_library_books`、`load_library_holdings` | `LibraryCatalogSource` | [§6](API.md#6-图书目录馆藏与本人借阅2026-10-23-部分只读验证) |
| 本人借阅 | `library-loans` | 读 | OPAC | [`LibraryLoansGateway`](#79-libraryloansgateway) | `load_library_loans` | `LibraryLoansSource` | [§6.2](API.md#62-本人借阅与隐私) |
| 图书馆人数 | `library-stats` | 读 | 图书馆公开站 | `LibrarySeatingGateway.libraryStats` | `load_library_stats` | `LibraryStatsSource` | [§5.5](API.md#55-官网实时空间数据公开只读) |
| 空教室 | `classroom` | 读 | 空教室系统 | [`AcademicGateway.classrooms`](#72-academicgateway) | `load_classrooms` | `ClassroomSource` | [§6A](API.md#6a-空教室源码已核对真机待验收) |
| 研讨室 CGYY | `cgyy` | 读 + **写** | CGYY | `CgyyGateway.cgyy`、`CgyyBookingGateway` | `load_cgyy`、`execute_cgyy` | `CgyySource`、`CgyyMutationSource` | [§6B](API.md#6b-教学楼研讨室cgyy前端ubaa-协议移植真实写操作未验收) |
| 博雅 | `bykc` | 读 | BYKC | `BykcGateway.bykcPart` | `load_bykc`、`load_bykc_chosen`、`load_bykc_statistics` | `BykcSource` | [§7.3](API.md#73-2026-10-18-教育系统只读数据盘点) |
| 研究生教务 | `graduate` | 读 | GSMIS | `GraduateGateway.graduatePart`、[`GraduateCreditMapGateway`](#710-graduatecreditmapgateway) | `load_graduate_part`、`load_graduate_credit_map` | `GraduateSource` | [§7.4](API.md#74-培养方案执行报告结构化类别课组) |
| 校园通知 | `notices` | 读 | 新闻网 | `NoticeGateway.notices` | `load_notices` | `NoticeSource` | [§7.3](API.md#73-2026-10-18-教育系统只读数据盘点) |
| 校园卡余额 | `campus-card` | 读 | 航财通 | [`CampusCardGateway`](#714-campuscardgateway) | `load_campus_card_balance` | `CampusCardBalanceSource` | [§6E](API.md#6e-校园卡余额官方前端与脱敏结构真实-app-验收中) |
| 就业活动 | `career-events` | 读 | 学校就业网 | `CareerEventsGateway` | `load_career_events` | `CareerEventsSource` | [§6G](API.md#6g-就业活动公开月历工作树只读) |
| 学术文化 | `campus-activities` | 读 | 学校公开页 | `CampusActivitiesGateway` | `load_campus_activities` | `CampusActivitiesSource` | [§6F](API.md#6f-学术文化公开列表工作树只读) |
| 校车时刻表 | `shuttle` | 读 | 学校公开页 | `ShuttleGateway.shuttleTimetable` | `load_shuttle_timetable` | `ShuttleSource` | [§6C](API.md#6c-智慧校车脚本静态本人查询页面观察未购票) |
| 个人待办 | `tasks` | 本机写 | 无 | `LocalTaskGateway.editTasks` | `edit_tasks` | （core `tasks_store`） | 无上游协议 |
| 学习快照 | `learning-snapshots` | 本机写 | 无 | [`LearningSnapshotGateway`](#711-learningsnapshotgateway) | `export_learning_snapshots`、`import_learning_snapshots` | `LearningSnapshotSource` | 无上游协议 |
| 提醒规划 | `reminders` | 本机 | 无 | [`ReminderPlanningGateway`](#712-reminderplanninggateway) | `plan_course_task_reminders` | （core 纯规则） | 无上游协议 |
| 应用更新 | `updates` | 读 | GitHub Releases | [`MaintenanceService`](#713-平台服务) | `check_android_update`、`verify_credential_storage` | （runtime） | [更新源](API.md#android-镜像更新源2026-10-20) |

## 3. 上游协议层

学校端点、Cookie、token、成功码与证据等级**只在 [API.md](API.md) 维护**。本节给出「协议章节 ↔ 适配器 ↔ 能力」的对照，便于从代码反查协议证据。

| 协议章节 | 适配器 | 主要端点常量 | 服务 |
| --- | --- | --- | --- |
| [§1 统一认证](API.md#1-统一认证sso--uc) | `auth/`、`auth/cas.rs` | 登录页、`/login`、会话验证 | `session_service` |
| [§2 本科课表](API.md#2-课表--本科生byxt) | `adapters/schedule_http.rs` | `PORTAL_URL`、`TERMS_URL`、`WEEKS_URL`、`COURSES_URL`、`EXAMS_URL`、`TODAY_URL` | `schedule_service` |
| [§3 研究生课表](API.md#3-课表--研究生gsmis) | `adapters/graduate_schedule_http.rs`、`codecs/schedule/graduate.rs` | GSMIS 学期/课表查询 | `schedule_service` |
| [§4 成绩](API.md#4-成绩buaascore) | `adapters/grades_http.rs` | `GRADE_URL` | `session_service`/成绩读取 |
| [§5 图书馆座位](API.md#5-图书馆座位bookinglib-v4) | `adapters/library_http.rs` | `/api/login`、`/api/reservation/day/info`、`/api/orders/*`、`/api/front/website/venues` | `library_service`、`library_mutation_service` |
| [§6 图书目录与借阅](API.md#6-图书目录馆藏与本人借阅2026-10-23-部分只读验证) | `adapters/library_books_http.rs`、`library_loans_http.rs` | `/meta-local/opac/search`、`/bibs/`、`/users/loans` | `library_books_service`、`library_loans_service` |
| [§6E 校园卡余额](API.md#6e-校园卡余额官方前端与脱敏结构真实-app-验收中) | `adapters/campus_card_http.rs` | `/api/campus_cards`、`/api/campus_card/balance` | `campus_card_service` |
| [§6F 学术文化](API.md#6f-学术文化公开列表工作树只读) | `adapters/campus_activities_http.rs` | `/index/xswh1.htm`、`/index/xswh1/<page>.htm` | `campus_activities_service` |
| [§6G 就业活动](API.md#6g-就业活动公开月历工作树只读) | `adapters/career_http.rs` | `/f/recruitmentFair/ajax_calendar_list?time=YYYY-MM` | `career_service` |
| [§6A 空教室](API.md#6a-空教室源码已核对真机待验收) | `adapters/classroom_http.rs` | `ACTIVATION_URL`、`CLASSROOM_BASE`、`/kc/queryXskcListPage` | `classroom_service` |
| [§6B CGYY](API.md#6b-教学楼研讨室cgyy前端ubaa-协议移植真实写操作未验收) | `adapters/cgyy_http.rs` | `/api/reservation/*`、`/api/orders/*`、`/api/captcha/check` | `cgyy_service`、`cgyy_booking_service` |
| [§6C 校车](API.md#6c-智慧校车脚本静态本人查询页面观察未购票) | `adapters/shuttle_http.rs` | 学校公开页面 | `shuttle_service` |
| [§7.1 作业](API.md#71-bbaa-原版作业实现对照2026-10-15) | `adapters/homework_http.rs`、`homework_files_http.rs` | `SPOC_BASE`、`/jxkj/*`、`/kczy/*` | `homework_service`、`homework_submission_service` |
| [§7.1.4 学习](API.md#714-spoc-课程学习只读扩展2026-10-26静态证据与实测分开) | `adapters/learning/` | SPOC 栏目/公告/资料/测验 | `learning_service` |
| [§7.2 签到](API.md#72-iclass-签到状态与手动提交写协议尚待真实验收) | `adapters/checkin_http.rs` | `ENTRY_URL`、`APP_LOGIN_URL`、`COURSE_SCHEDULE_URL` | `checkin_service` |
| [§7.3 博雅与通知](API.md#73-2026-10-18-教育系统只读数据盘点) | `adapters/bykc_http.rs`、`notices_http.rs` | BYKC 查询、新闻列表 | `bykc_service`、`notices_service` |
| [§7.4 研究生教务](API.md#74-培养方案执行报告结构化类别课组) | `adapters/graduate_http.rs` | GSMIS 学籍/执行报告 | `graduate_service` |
| [更新源](API.md#android-镜像更新源2026-10-20) | `adapters/updates_http.rs` | GitHub Releases | `updates_service` |

### 3.3 适配器与协议模块

| 目录 | 职责 | 禁止 |
| --- | --- | --- |
| `adapters/*_http.rs` | 请求构造、认证会话 Header/Cookie 注入、响应分类；公开只读请求走 `Session::send_anonymous`，不发送认证头/Cookie、不保存响应 Cookie，也不改共享路由 | 不放业务规则，不写日志落盘 |
| `codecs/*.rs` | 响应结构解析为 domain 值 | 不推断缺失字段，不改成功码语义 |
| `auth/` | 登录页解析、表单提交、凭据、会话验证 | 不接触业务端点 |
| `endpoints.rs` | 官方浏览器目标地址 | 不含 token 或会话状态 |

## 4. Rust 业务端口层

端口是 `ginkgo_domain` 定义的稳定能力边界，`ginkgo_core` 只依赖它们，不依赖具体学校实现。所有查询结果统一使用 `DataOutcome<T>` 信封。

### 4.1 统一信封

```rust
// ports/outcome.rs
pub struct DataOutcome<T> {
    pub data: T,
    pub failure: Option<AppError>,
}
```

读取类结果通常还带 `fetched_at`、`from_cache`、`stale`，用来区分「本次成功」「旧快照」「失败但保留旧值」。**失败不会清空旧数据，也不延长原成功时间。**

### 4.2 错误语义

`ErrorCode`（`domain/lib.rs`）是唯一的错误分类，序列化为 `snake_case`：

| 码 | 含义 | 调用方应做 |
| --- | --- | --- |
| `invalid_request` | 参数或筛选不合法 | 提示调整条件，不重试同样输入 |
| `changed_response` | 响应用法/结构变化 | 提示重试；持续出现说明协议漂移 |
| `unsupported_contract` | 数据版本不支持 | 提示更新应用 |
| `session_expired` | 学校会话失效 | 引导重新登录，不自动重放写操作 |
| `service_unavailable` | 学校服务不可用 | 保留旧数据，稍后重试 |
| `captcha_required` | 需要验证码 | 进入挑战流程，禁止绕过 |
| `invalid_credentials` | 凭据错误 | 提示核对，不保存明文 |
| `pre_login_tip` | 登录前置提示页 | 展示提示，需人工确认 |
| `access_policy_denied` | 访问策略拒绝 | 说明限制，不重试 |
| `redirect_limit` | 重定向超限 | 报错，不继续跟随 |
| `unsupported_portal` | 门户类型不支持 | 说明不支持 |
| `credential_store` | 平台保险库操作失败 | 提示本机存储问题 |
| `business_rejected` | 业务端点明确拒绝 | **不是登出**；按业务提示处理 |

写操作的终态由 `MutationState`（`features/mutation.rs`）表达，序列化为 `camelCase`：

| 状态 | 含义 |
| --- | --- |
| `accepted` | 回查确认目标已生效 |
| `rejected` | 学校明确拒绝，未生效 |
| `notSubmitted` | 前置条件不满足，未发出请求 |
| `uncertain` | 结果未知，只允许回查，禁止自动重发 |

未知状态或桥接失败必须保守处理，不推断成功。

### 4.3 端口清单

| 端口 trait | 方法 | 文件 |
| --- | --- | --- |
| `SessionSource` | `login_challenge`、`status`、`set_route`、`sign_in`、`restore`、`sign_out`、`clear_snapshots`、`account` | `ports/session.rs` |
| `ScheduleSource` | `load_schedule` | `ports/academic.rs` |
| `TodaySource` | `load_today` | `ports/academic.rs` |
| `GradeSource` | `load_grades`、`load_grade_terms` | `ports/academic.rs` |
| `HomeworkSource` | `load_homework`、`load_homework_detail` | `ports/homework.rs` |
| `HomeworkSubmissionSource` | `configure_homework_recovery`、`pending_homework_submissions`、`homework_capabilities`、`homework_workspace`、`upload_homework_file`、`submit_homework_file`、`download_homework_file`、`reconcile_homework_file` | `ports/homework_submission.rs` |
| `LearningCourseSource` | `learning_courses` | `ports/learning.rs` |
| `CourseAnnouncementSource` | `course_announcements`、`course_announcement_detail`、`course_announcement_attachment` | `ports/learning.rs` |
| `CourseResourceSource` | `course_resources`、`course_resource_download` | `ports/learning.rs` |
| `CourseAssessmentSource` | `course_assessments` | `ports/learning.rs` |
| `CourseLearningContextSource` | `course_learning_columns`、`course_announcements_in`、`course_announcement_detail_in`、`course_announcement_attachment_in`、`course_assessments_in`、`course_resources_at`、`course_resource_download_at`、`course_learning_capabilities` | `ports/learning.rs` |
| `CheckInSource` | `checkin_load_progress`、`load_checkin`、`load_checkin_on_date` | `ports/checkin.rs` |
| `CheckInMutationSource` | `submit_checkin` | `ports/checkin.rs` |
| `LibrarySource` | `load_library_history`、`load_library_venues`、`load_library_areas`、`load_library_slots`、`load_library_seats`、`load_library_bookings` | `ports/library.rs` |
| `LibraryMutationSource` | `reserve_library_seat`、`perform_library_action` | `ports/library.rs` |
| `LibraryCatalogSource` | `search_books`、`book_holdings` | `ports/library_books.rs` |
| `LibraryLoansSource` | `library_loans` | `ports/library_loans.rs` |
| `LibraryStatsSource` | `load_library_stats` | `ports/library_stats.rs` |
| `ClassroomSource` | `load_classrooms` | `ports/classroom.rs` |
| `CgyySource` | `load_cgyy` | `ports/cgyy.rs` |
| `CgyyMutationSource` | `execute_cgyy` | `ports/cgyy.rs` |
| `BykcSource` | `load_bykc`、`load_bykc_chosen`、`load_bykc_statistics` | `ports/bykc.rs` |
| `GraduateSource` | `load_graduate`、`load_graduate_execution`、`load_graduate_part` | `ports/graduate.rs` |
| `NoticeSource` | `load_notices` | `ports/notices.rs` |
| `CareerEventsSource` | `load_career_events` | `ports/career.rs` |
| `CampusActivitiesSource` | `load_campus_activities` | `ports/campus_activities.rs` |
| `CampusCardBalanceSource` | `load_campus_card_balance` | `ports/campus_card.rs` |
| `ShuttleSource` | `load_shuttle_timetable` | `ports/shuttle.rs` |
| `LearningSnapshotSource` | `export_learning_snapshots`、`import_learning_snapshots` | `ports/query_snapshots.rs` |

### 4.4 关键输入/输出类型

| 类型 | 字段 | 说明 |
| --- | --- | --- |
| `ScheduleQueryInput` | `term_id: Option<String>`、`week: Option<i32>`、`force_refresh: bool` | 空值表示沿用当前学期/当前周 |
| `ScheduleData` | `terms`、`weeks`、`term_id`、`week_number`、`courses`、`exams` | 研究生的 `exams` 为空是既定事实，不伪造 |
| `TodayOutcome` | `date`、`courses`、`fetched_at`、`from_cache`、`stale`、`failure` | 日期为学校当地日期 |
| `GradeOutcome` | `term_id`、`courses`、`summary`、`fetched_at`、`from_cache`、`stale`、`failure` | `summary` 为本地汇总，不是学校学业结论 |
| `CheckInOutcome` | `date`、`courses`、`fetched_at`、`from_cache`、`stale`、`failure` | `date` 为 `yyyy-MM-dd` |
| `CheckInLoadProgress` | `phase`、`elapsed_ms`、`stages[]` | 阶段进度，未知阶段不伪造完成 |
| `SessionStatus` | `account`、`profile`、`route` | `account` 与 `profile` 同时有值才算已登录 |
| `SessionOutcome` | `SignedIn{profile, remembered}` / `CaptchaRequired(challenge)` / `SignedOut` | 三态互斥 |
| `LoginChallengeData` | `challenge_id`、`challenge_type`、`text_supported`、`image: Vec<u8>` | 图像仅内存，不落盘、不作身份凭证 |
| `CgyyQuery` | `Venues` / `Day{site_id, date}` / `Orders` / `Order{order_id}` / `LockCode` | 只读查询；订单详情与门锁码不走快照 |
| `RoutePreference` | `Automatic` / `Direct` / `WebVpn` | 路线切换会重建会话 |

## 5. 应用编排层

`ginkgo_core` 负责账号隔离、命令编排与本机持久化，只依赖端口。它不比学校协议多做解释，但承担三类硬约束：

| 关注点 | 实现位置 | 接口影响 |
| --- | --- | --- |
| 账号隔离 | `Workspace<U>` 应用命令 | 旧响应不写回新账号；切换账号后丢弃代次不匹配的结果 |
| 本机待办 | `ginkgo_core/src/tasks_store.rs` | 按 `tasks-<SHA-1(account)>.json` 保存；v1 只读，有效修改升级 v2，损坏拒绝覆盖 |
| CGYY 写保护 | `cgyy_pending_store.rs` | marker 只存版本+布尔值，无自动过期；不确定状态必须先核对再解锁 |

CGYY 的本地 JSON 契约（`action`、参数约束、`state` 语义、TTL 与持久保护）已在 [FEATURES-AND-PROTOCOLS §4](FEATURES-AND-PROTOCOLS.md#4-cgyy-本地-json-契约) 完整定义，本文不再复制。

## 6. FFI 命令层

`ginkgo_flutter_bridge` 导出 **89 个命令**，是 Dart 唯一可见的 Rust 面。Dart 侧只允许 [contracts.dart](../flutter/lib/application/contracts.dart) 以类型形式引用生成绑定，命令本身只能由 `NativeMirrorService` 调用。

命令计数口径：`flutter/lib/src/rust/api/**` 生成的 Dart 命令函数（`live` 77 + `live/auth_challenge` 1 + `mirror` 10 + `reminder_planning` 1）。改命令后该数字会变，改完请同步本行与 [§6.10](#610-返回形态与载荷契约)。

### 6.1 会话

| 命令 | 输入 | 输出 | 副作用 |
| --- | --- | --- | --- |
| `init_app` | — | — | 初始化运行时；不在启动时预热网络 |
| `restore_session` | — | `SessionResponse` | 可能触发保存凭据的自动登录 |
| `login` | `account`、`password`、`captcha?`、`remember` | `SessionResponse` | 可能写平台保险库 |
| `load_login_challenge` | `expectedId?`、`refresh` | 挑战 DTO | 重新拉取登录页 |
| `sign_out` | — | `SessionResponse` | 清理会话与保存凭据 |
| `set_route` | `route` | `SessionResponse` | 重建 Cookie 罐 |
| `clear_cache` | — | `bool` | 清查询快照，不动凭据与本机待办 |
| `verify_credential_storage` | `account`、`secret` | `bool` | 合成密钥探针，不读写真实凭据 |

### 6.2 学业

`load_today`、`load_schedule`、`load_grade_terms`、`load_grades`、`load_homework`、`load_homework_detail`、`load_classrooms`、`load_query_dates`、`load_rule_examples`。全部只读，返回序列化后的领域投影。

### 6.3 学校作业提交（写）

`configure_homework_recovery`、`pending_homework_submissions`、`homework_capabilities`、`homework_file_workspace`、`upload_homework_file`、`submit_homework_file`、`reconcile_homework_file`、`download_homework_file`。上传不等于提交；结果未知时只允许 `reconcile_homework_file`。

### 6.4 学习

`learning_courses`、`course_announcements`、`course_announcement_detail`、`course_announcement_attachment`、`course_resources`、`course_resource_download`、`course_assessments`、`course_learning_columns`、`course_learning_capabilities`，以及带 `_in` / `_at` 后缀的显式路径变体（逐层复核目录，未知层级拒绝）。`export_learning_snapshots` / `import_learning_snapshots` 管本机加密快照。

### 6.5 签到（写）

`load_checkin_today`、`load_checkin_on_date`、`checkin_load_progress`、`submit_checkin`。结果须回查，未知不重发。

### 6.6 图书馆

只读：`load_library_stats`、`load_library_venues`、`load_library_areas`、`load_library_slots`、`load_library_seats`、`load_library_bookings`、`load_library_history`、`load_library_books`、`load_library_holdings`、`load_library_loans`、`library_loans_portal_url`、`load_shuttle_timetable`。

写：`reserve_library_seat`、`perform_library_action`（签到、暂离、返回、离馆、取消）。

### 6.7 校园

`load_cgyy`（`kind` 为 `venues` / `day` / `orders` / `order` / `lockCode`；`order` 时 `site_id` 传订单 ID）、`execute_cgyy`（写）、`load_bykc`、`load_bykc_chosen`、`load_bykc_statistics`、`load_graduate_part`、`load_graduate_credit_map`、`load_notices`、`load_campus_card_balance`（校园卡只读）、`edit_tasks`（本机写）、`plan_course_task_reminders`（纯规则）。

### 6.8 演示数据

`load_demo_*` 系列返回合成数据，与真实适配器共享返回类型，保证页面在演示模式下不接触真实账号。

### 6.9 返回值约定

| 形态 | 字段 | 说明 |
| --- | --- | --- |
| `ReadOnlyResponse` | `payload: String?`、`stale: bool`、`failure: FailureCode?` | **类型名不代表无副作用**；`payload` 是领域 JSON 字符串 |
| `MutationResponse` | `state`、`message` | 写入结果，见 [§4.2](#42-错误语义) |
| 结构化 DTO | 各字段 | 课表、成绩、签到等直接映射为 Dart 类型 |

成功 = `payload` 有值且 `failure` 为空；解析/会话/存储错误可以表现为 `payload=null` 加 `failure`。不能只看 JSON 里的 `state` 判定错误。

### 6.10 返回形态与载荷契约

89 个命令按返回形态分为两类：

| 形态 | 数量 | 含义 | 解码位置 |
| --- | --- | --- | --- |
| 类型化 DTO | 47 | 命令直接返回结构体（`SessionResponse`、`ScheduleResponse`、`CheckInResponse`、`MutationResponse` …） | 无需 JSON 解码 |
| `ReadOnlyResponse` 载荷 | 42 | 命令返回领域 JSON 字符串 + `stale` + `failure` | 只能在 `infrastructure/` 或各域 `*_models.dart` 解码 |

使用载荷信封的 42 个命令：

`checkAndroidUpdate`、`checkinLoadProgress`、`configureHomeworkRecovery`、`courseAnnouncementDetail`、`courseAnnouncementDetailIn`、`courseAnnouncements`、`courseAnnouncementsIn`、`courseAssessments`、`courseAssessmentsIn`、`courseLearningCapabilities`、`courseLearningColumns`、`courseResources`、`courseResourcesAt`、`editTasks`、`executeCgyy`、`homeworkCapabilities`、`homeworkFileWorkspace`、`importLearningSnapshots`、`learningCourses`、`loadBykc`、`loadBykcChosen`、`loadBykcStatistics`、`loadCampusActivities`、`loadCgyy`、`loadDemoBykc`、`loadDemoBykcChosen`、`loadDemoBykcStatistics`、`loadDemoCgyy`、`loadDemoGraduate`、`loadDemoGraduateStatus`、`loadDemoLibraryStats`、`loadDemoNotices`、`loadGraduateCreditMap`、`loadGraduatePart`、`loadLibraryBooks`、`loadLibraryHoldings`、`loadLibraryLoans`、`loadLibraryStats`、`loadNotices`、`loadShuttleTimetable`、`pendingHomeworkSubmissions`、`uploadHomeworkFile`。

载荷契约要求如下；架构门禁只检查部分依赖与解码位置，不能证明载荷字段或失败语义正确：

1. `payload` 应是 **Rust 净化后的业务投影**，不是学校原始响应；部分历史投影仍沿用如 `space_id` 的学校字段名称，需在 DTO 迁移时消除这类耦合。
2. 解码只允许在 `infrastructure/` 或 `*_models.dart`；页面与共享组件不得出现 `jsonDecode`。
3. 载荷解码失败按“解析失败”处理（`FormatException` → 失败态），不得降级为空结果。

新增命令时优先返回类型化 DTO；确需载荷信封时，同步在 [FEATURES-AND-PROTOCOLS](FEATURES-AND-PROTOCOLS.md) 的本机/投影约定中登记，并保持解码位置在模型层。

## 7. Flutter 应用接口层

页面只依赖这一层的 `application/` 接口，注入 fake 即可脱离 Rust 测试。

### 7.1 SessionGateway

| 方法 | 输入 | 输出 |
| --- | --- | --- |
| `restoreSession()` | — | `SessionResponse` |
| `login({account, password, captcha, remember})` | 凭据与是否记住 | `SessionResponse` |
| `signOut()` | — | `SessionResponse` |
| `setRoute(RouteChoice)` | 自动/直连/WebVPN | `SessionResponse` |
| `clearCache()` | — | `bool` |
| `verifyBridgeContract()` | — | `bool` |

### 7.2 AcademicGateway

`dates(instant)`、`classrooms(scope, query)`、`rules()`、`schedule({termId, week, forceRefresh})`、`gradeTerms()`、`grades({termCode, forceRefresh})`、`today({forceRefresh})`、`homework({forceRefresh})`、`homeworkDetail(id, {forceRefresh})`。

### 7.3 CheckInGateway

`checkin({forceRefresh})`、`checkinOnDate(date, {forceRefresh})`、`submitCheckin(courseId)`、`checkinProgress()`。

### 7.4 LibrarySeatingGateway / LibraryCatalogGateway / ShuttleGateway

`LibrarySeatingGateway`：`libraryStats`、`libraryVenues`、`libraryAreas`、`librarySlots`、`librarySeats`、`libraryBookings`、`libraryHistory`、`reserveLibrarySeat`、`performLibraryAction`。

`LibraryCatalogGateway`：`libraryBooks`、`libraryHoldings`。`ShuttleGateway`：`shuttleTimetable`。`LibraryGateway` 仅作为座位与书目能力的兼容聚合，不再包含校车。

### 7.5 CampusGateway 与 LocalTaskGateway

`CampusGateway` 聚合 `BykcGateway.bykcPart`、`GraduateGateway.graduatePart`、`NoticeGateway.notices`、`CgyyGateway.cgyy`；各页面按实际能力注入独立端口。

`LocalTaskGateway.editTasks(command)` 是本机待办端口，不属于学校校园服务。`CgyyBookingGateway.executeCgyy(Map<String, Object?>)` 写能力单列，不因具备 `cgyy` 只读能力就自动获得。

### 7.6 AuthChallengeGateway

`AuthChallengeGateway.loginChallenge({expectedId, refresh})` → `LoginChallenge`。

### 7.7 HomeworkFilesGateway

`homeworkFiles(assignmentId)`、`pendingHomeworkSubmissions()`、`homeworkCapabilities(assignmentId)`、`uploadHomeworkFile(...)`、`submitHomeworkFile(handle)`、`reconcileHomeworkFile(handle)`、`downloadHomeworkFile(...)`。

### 7.8 Learning 系列 gateway

`LearningCourseGateway`、`CourseAnnouncementGateway`、`CourseResourceGateway`、`CourseAssessmentGateway`、`CourseLearningContextGateway`。读取统一返回 `LearningRead<T>`（携带旧快照与失败元数据）；下载返回 `LearningDownload`。

### 7.9 LibraryLoansGateway

`libraryLoans({page})` → `LibraryLoansRead`。独立接口，不复用选座会话。

### 7.10 GraduateCreditMapGateway

`graduateCreditMap({forceRefresh})` → `GraduateCreditMapRead`。未知指标不补零，分层不累加。

### 7.11 LearningSnapshotGateway

`learningSnapshotStatus()`、`setLearningSnapshotsEnabled(bool)`。

### 7.12 ReminderPlanningGateway

`planReminders({...})` → `ExtendedReminderPlans`。纯规则，不访问网络。

### 7.13 平台服务

| 接口 | 方法 | 说明 |
| --- | --- | --- |
| `MaintenanceService` | `supportsUpdates`、`version`、`checkUpdate`、`openReleases`、`checkBridge`、`checkStorage`、`checkVault` | 更新检查与本地诊断 |
| `SystemSettingsService` | `notificationPermission`、`requestNotifications`、`openNotifications`、`openAppSettings`、`shareProject` | 平台系统设置 |
| `ReminderPlatform` | `replace(plans)` | 系统通知调度 |

### 7.14 CampusCardGateway

`campusCardBalance()` → `CampusCardBalanceResponse`。独立只读接口，用户主动触发；金额以整数分返回，不包含卡号、银行卡或消费明细，不写通用查询快照。

## 7A. Flutter UI 层接口约定

页面与组件同样有稳定契约，只是形式不是 RPC。全量清单见 [dart-feature-*](interfaces/README.md) 与 [dart-widgets](interfaces/dart-widgets.md)。

### 7A.1 页面构造契约

每个功能域页面都是无状态入口 + 内部 `State`，构造参数遵循同一套约定：

| 参数形态 | 含义 | 约束 |
| --- | --- | --- |
| `service` / `gateway` | 注入的应用接口 | 目标是必填或显式表示能力缺失；部分独立页面仍允许为空并经工厂兜底，待迁移 |
| `accountId` / `account` | 账号隔离键 | 可空；用于本机数据命名与代次校验 |
| `forceRefresh` / `initialFilter` 等 | 一次性初始状态 | 可空；不承载跨页持久状态 |
| `onXxx` 回调 | 上抛导航或确认动作 | 页面不直接改壳层状态 |
| `now` / `clock` | 时间注入 | 仅测试用，生产走 `todaySchoolNow` |
| `saveFile` / `picker` | 平台能力注入 | 可空；为空时页面必须降级提示而非崩溃 |

页面不得直接调用 `jsonDecode`；部分既有页面仍接收 `ReadOnlyResponse.payload` 并交给模型解码器，不能称为完全类型化。架构门禁检查直接解码和部分裸 Map 使用，但不能证明所有页面参数和字段都已消除字符串载荷。

### 7A.2 组件契约

共享组件（`widgets/`、`design/`、各域 `*_widgets.dart`）遵守：

- 输入是值对象或回调，不接收 `Map<String, dynamic>`。
- 不发起网络请求，不读写平台存储。
- 状态色用 `AppleDesign.status*`，且颜色之外必须同时有文字。
- 触控目标不小于 48dp；大字号下允许换行而不是截断。

### 7A.3 状态与刷新契约

复杂异步页面复用三件共享设施，它们本身也是接口：

| 设施 | 文件 | 契约 |
| --- | --- | --- |
| `RefreshSection<T>` | `application/refresh_section.dart` | 重叠读取合流、刷新保留旧值、失败带错误、dispose 后丢弃迟到结果 |
| `LibraryController` | `features/library/library_controller.dart` | 分页与分区快照、账号/服务代次变化后丢弃旧状态 |
| `CollectionWindow` | `application/collection_window.dart` | 本机分页；页码随结果变化重置，不代表上游分页 |

就业活动使用 `CareerEventsResponse` 类型化 DTO；学术文化仍使用 JSON 信封，缺少必需投影字段或字段类型错误归为结构变化。两者均可同时返回有效旧快照与失败码；页面切换月份或页码后不复用上一查询的可见数据。

### 7A.4 导航与登记

`workspace/workspace_catalog.dart` 的 `WorkspaceDestination` 是**壳层与功能页之间唯一的登记点**：移动标签、桌面侧栏、今日快捷入口与返回逻辑都由 `workspaceDestinations` 派生。新增页面必须在这里登记，否则不可达；这是编译期静态表，不是运行时插件系统。

### 7A.5 命令与能力的命名约定

命名是接口契约的一部分：看到名字就能判断读/写、本机/学校、是否幂等。

| 前缀 | 含义 | 例子 | 约束 |
| --- | --- | --- | --- |
| `load_*` / `*_load_*` | 读学校或本机状态 | `load_schedule`、`load_today`、`checkin_load_progress` | 只读；允许返回旧快照与失败元数据 |
| `search_*` / `*_list_*` | 读列表或检索 | `search_books`、`pending_homework_submissions` | 只读；分页属本机或上游，不混用 |
| `submit_*` / `execute_*` / `reserve_*` / `perform_*` | 改学校系统 | `submit_checkin`、`execute_cgyy`、`reserve_library_seat` | 必须用户确认、单次提交、结果回查；结果不明不重发 |
| `reconcile_*` | 回查未知结果 | `reconcile_homework_file` | 只读学校状态，不再次写入 |
| `edit_*` | 改本机数据 | `edit_tasks` | 不触达学校；账号命名空间来自 Rust 会话 |
| `export_*` / `import_*` | 本机快照出入 | `export_learning_snapshots` | 导入失败不部分生效 |
| `plan_*` | 纯规则计算 | `plan_course_task_reminders` | 不访问网络、不读设备状态 |
| `verify_*` / `check_*` | 本机诊断 | `verify_credential_storage`、`check_android_update` | 不读写真实凭据 |
| `load_demo_*` | 演示合成数据 | `load_demo_cgyy` | 与真实实现共享返回类型 |

能力 id（[§2](#2-能力总表) 第一列）与 FFI 命令不是一一对应：一个能力可以拆成多个命令（如 `cgyy` 含只读查询与写入两类命令），但**读能力不得隐含写能力**——写能力必须单列 gateway（如 `CgyyBookingGateway`）。

## 8. 模块 IO 契约

按功能域列出「输入 → 输出 → 失败态 → 本机副作用」。这是排查「某模块到底碰了什么」时最快的入口；全量签名见 `interfaces/` 对应文件。

约定：**读**结果失败时保留旧快照（`stale=true` 且 `failure` 非空）；**写**结果只有四种终态（[§4.2](#42-错误语义)）。

| 模块 | 输入 | 输出 | 失败态 | 本机副作用 |
| --- | --- | --- | --- | --- |
| `session` | 账号、密码、验证码、记住开关、路线 | `SessionResponse{state, account, name, route, failure}` | `invalid_credentials`、`captcha_required`、`pre_login_tip`、`credential_store` | 平台保险库写入（仅勾选记住时）；Cookie 在 Rust 内存 |
| `auth-challenge` | `expectedId`、`refresh` | `LoginChallenge{challengeId, challengeType, textSupported, image}` | `session_expired`、`invalid_request` | 无；图像只在内存 |
| `today` | `forceRefresh` | `TodayResponse{date, courses[], fetchedAt, fromCache, stale}` | 读失败保留旧值 | 进程快照（TTL 300s） |
| `schedule` | `termId?`、`week?`、`forceRefresh` | `ScheduleResponse{terms[], weeks[], termId, weekNumber, courses[], exams[]}` | 读失败保留旧值 | 进程快照 |
| `grades` | `termCode?`、`forceRefresh` | `GradeResponse{termId, courses[], summary, fetchedAt}` | 读失败保留旧值 | 进程快照 |
| `homework` | `forceRefresh`、`id`（详情） | `HomeworkResponse{items[], termName}` / 详情 | 读失败保留旧值 | 进程快照；课程可见性偏好 |
| `homework-files` | `assignmentId`、文件字节、`handle` | `HomeworkFileWorkspace`、`HomeworkFileReceipt`、`MutationResponse` | `uncertain` → 只允许回查 | 待确认提交记录（不含文件内容） |
| `learning` | 课程 ID、栏目、目录路径、分页 | `LearningRead<T>`（含旧值与失败）、`LearningDownload` | 分区独立失败，各自保留旧值 | 可选加密学习元数据快照（默认关闭） |
| `checkin` | 日期、课程 ID | `CheckInResponse{date, courses[]}`、`MutationResponse` | 写 `uncertain` → 只回查 | 日期隔离快照；提醒已读摘要 |
| `library` | 馆/区/时段/座位 ID、动作 | 各 `*Response`、`MutationResponse` | 写 `uncertain` → 只回查 | 分区/分页快照 |
| `library-books` | 关键词、排序、分页、`bibId` | `ReadOnlyResponse`（领域投影） | 读失败保留旧值 | 进程快照 |
| `library-loans` | `page` | `LibraryLoansRead{pages, records[]}` | 读失败与确认空分别呈现 | **不持久化**；离开页面即清 |
| `library-stats` | `forceRefresh` | `ReadOnlyResponse`（校区人数） | 读失败保留旧值 | 进程快照 |
| `classroom` | 校区、日期、节次、楼栋、搜索 | `ClassroomResponse{rows[], buildings[]}` | 读失败保留旧值 | 进程快照；本机每页 50 条 |
| `cgyy`（读） | `kind`（`venues`/`day`/`orders`/`order`/`lockCode`）、`siteId`、`date` | `ReadOnlyResponse`（领域投影） | 读失败保留旧值；门锁码失败不误报无预约 | 既有查询进程快照；订单详情和门锁码无快照 |
| `cgyy`（写） | `action` + 参数（见 [FEATURES-AND-PROTOCOLS §4](FEATURES-AND-PROTOCOLS.md#4-cgyy-本地-json-契约)） | `CgyyActionResult{state, message, options?, challenge?, review?}` | `uncertain` → 只回查 | pending marker（版本+布尔值，无过期） |
| `bykc` | `part`（catalog/chosen/statistics） | `ReadOnlyResponse` | 三部分独立失败 | 进程快照 |
| `graduate` | `part`、`forceRefresh` | `ReadOnlyResponse`（学籍/报告/学分地图） | 读失败保留旧值 | 进程快照 |
| `notices` | `forceRefresh` | `ReadOnlyResponse` | 读失败保留旧值 | 进程快照 |
| `shuttle` | — | `ReadOnlyResponse`（分方向班次） | 读失败保留旧值 | 进程快照 |
| `campus-card` | 用户主动查询 | `CampusCardBalanceResponse{balanceMinor, fetchedAt, failure}` | 失败仅保留本页旧值并标注可能过期 | **不持久化**；离页/后台/换账号清除，默认遮挡，无轮询或资金写操作 |
| `tasks` | `action` + 任务字段 | 本机任务列表 | 损坏拒绝覆盖 | `tasks-<SHA-1(account)>.json`，v1→v2 原子升级 |
| `learning-snapshots` | `enabled` / 导出字节 | `LearningSnapshotStatus` | 导入失败不部分生效 | 可选加密快照文件 |
| `reminders` | 课程、作业、待办、签到快照 | `ExtendedReminderPlans` | 规划失败不影响主流程 | 已读摘要与开关（按账号） |
| `updates` | 当前版本 | `UpdateResult{latest, available, apkAvailable, download}` | 拉取失败放行 | 下载临时文件与校验结果 |

## 9. 四条完整链路（按此走通即理解架构）

新人不必逐层读源码，按下面四条链路各走一遍即可掌握全部关键模式。每条给出真实文件与函数名，可直接跳转。

### 9.1 只读查询：课表

```text
features/schedule/schedule_page.dart          页面持有 RefreshSection<ScheduleResponse>
  → AcademicGateway.schedule()                application/mirror_service.dart
  → NativeMirrorService                        infrastructure/native_mirror_service.dart
  → load_schedule                              bridge/api/live/academic.rs
  → Workspace 命令编排                         core/src/application/
  → ScheduleSource::load_schedule               domain/src/ports/academic.rs
  → schedule_service                           upstream/src/services/schedule_service.rs
  → ScheduleOutcome{data, fetched_at, stale}   ← 向上逐层收窄到 Dart DTO
```

要点：返回值一路是**同构信封**（`stale` + `failure`），页面只需判断「有无旧值」与「是否失败」，不必理解协议。

### 9.2 会话与认证

```text
features/auth/login_page.dart                 提交账号密码或验证码
  → SessionGateway.login()                    application/mirror_service.dart
  → login                                      bridge/api/live/session.rs
  → SessionSource::sign_in                     ports/session.rs
  → session_service/session_source.rs          登录、恢复、退出实现
  → auth::complete_login                       upstream/src/auth/
  → SessionOutcome{SignedIn|CaptchaRequired|SignedOut}
```

要点：三态互斥；`CaptchaRequired` 不是失败，是要走 `AuthChallengeGateway` 的挑战流程。

### 9.3 写入：CGYY 预约（最复杂的路径）

```text
features/cgyy/cgyy_booking_page.dart          用户填写并确认
  → CgyyBookingGateway.executeCgyy()           application/mirror_service.dart
  → execute_cgyy                               bridge/api/live/utilities.rs
  → core/src/application/cgyy.rs               校验 action、写 pending marker
  → CgyyMutationSource::execute_cgyy           ports/cgyy.rs
  → cgyy_booking_service.rs                    prepare / submit / cancel 时序
  → cgyy_booking_service/protocol.rs           表单、加密、验证码坐标
  → adapters/cgyy_http.rs                      实际 HTTP
```

要点：`prepare` 可能已创建学校草稿，所以**不是只读**；`uncertain` 只允许 `reconcile`，marker 不自动过期。

### 9.4 本机数据：个人待办

```text
features/tasks/tasks_page.dart
  → LocalTaskGateway.editTasks()               application/mirror_service.dart
  → edit_tasks                                 bridge/api/live.rs
  → core/src/tasks_store.rs                    按账号命名、v1→v2 原子升级
```

要点：没有上游协议；清查询缓存不影响它。

## 10. 跨层不变量

这些约束任何一层改动都必须保持，越界即视为缺陷：

1. **协议不出 upstream**：学校 URL、表单、Cookie、token、成功码只属于 `ginkgo_upstream`。
2. **页面不解析响应**：Dart 页面不调用 `jsonDecode`，不接收 `Map<String, dynamic>`；解码只允许在 `*_models.dart`。
3. **命令只走一个入口**：生成绑定只由 `contracts.dart`（类型）与 `NativeMirrorService`（命令）引用。
4. **失败不伪造成功**：失败保留旧快照与原成功时间；空结果可以覆盖旧数据；未知状态一律保守。
5. **写操作三件套**：用户明确触发、单次提交、结果回查；结果不明禁止自动重发。
6. **账号绑定**：读写的归属由 Rust 已认证会话派生，不由调用方指定的账号决定。
7. **本机数据隔离**：清查询缓存不删个人待办；账号摘要只用于命名隔离，不是加密。

其中 1–3 有 [`check-mirror-architecture.py`](../scripts/check-mirror-architecture.py) 的部分静态检查及自测；规则不覆盖所有依赖形式、字段语义或载荷流向，不能据此证明三项约束已完全满足。

## 11. 维护方法

- 新增能力：先在此表登记能力与 id，再按 domain 端口 → upstream 适配 → core 编排 → FRB 命令 → Dart gateway 的顺序落地；缺一层就不要在总表标注为可用。
- 新增接口前先在 [§1.1](#11-接口设计模式) 选模式：信封、端口、纯规则、粗粒度命令、写状态机、三件套、账号绑定、投影、演示同形、门禁登记。
- 改上游协议：先在 [API.md](API.md) 补证据与修订，再改适配器与 fixture，最后回来更新 [§3](#3-上游协议层) 的对照行。
- 改 FFI 命令：必须重新生成 FRB 绑定（`bash scripts/generate-mirror-bridge.sh`），并同步 [§6](#6-ffi-命令层)、[§6.10](#610-返回形态与载荷契约) 与 [§2](#2-能力总表)。
- 改任何公开接口后：运行 `python3 scripts/generate-interface-index.py` 刷新 [interfaces/](interfaces/README.md)；`--check` 模式可校验索引是否过期，CI 用它做防回退。
- 自动索引是源码导航而非完整语义契约：它按语法启发式提取，包含 Dart 顶层函数及 Rust 测试模块之后的公开条目，但无法证明所有成员、条件编译分支或副作用均已覆盖；变更时仍须人工核对具体签名、读写语义和协议证据。
- 每个接口的读写属性以业务副作用为准：认证与查询可能用 POST，仍算读；只有会改变学校记录的才算写。
- 本文档描述源码现状，不代表已发布或已通过真实账号验收。真实设备、账号只读与真实写入的证据分别记录在发布与审计文档中。

## 12. 自动化门禁

| 门禁 | 命令 | 拦住什么 |
| --- | --- | --- |
| 分层与边界 | `python3 scripts/check-mirror-architecture.py` | 跨层依赖、页面解析响应、页面传裸 Map、目录归类、文件体积上限 |
| 门禁自测 | `python3 scripts/check-mirror-architecture-test.py` | 门禁本身被改坏（规则失效仍通过） |
| 接口索引 | `python3 scripts/generate-interface-index.py --check` | 改了公开接口但没刷新文档 |
| 接口索引自测 | `python3 scripts/generate-interface-index-test.py` | 测试模块截断及 Dart 顶层函数遗漏等生成器回归 |
| 设计 token 采纳 | `python3 scripts/check-design-tokens.py` | 硬编码字号/间距/圆角重新回潮 |
| Rust 质量 | `cargo fmt --check` / `cargo clippy -D warnings` | 格式与告警 |
| 全量基线 | `bash scripts/check-mirror.sh` | 以上全部 + Flutter 分析与测试 + FRB 再生成一致性 |

门禁只拦可机器判定的问题。真实账号、物理设备、TalkBack 与大字号观感仍需人工验收，证据按日期归档在 [审计记录](_audit/) 与 [发布记录](releases/)。

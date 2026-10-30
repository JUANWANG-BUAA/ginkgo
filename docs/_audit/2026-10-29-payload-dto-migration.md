# 2026-10-29 工程债务与体验修复批次

本批次处理四类工作：网络失败分类、更新页 Release 正文渲染、公开信息页网络中断体验、API 接口文档同步门禁，并推进 R-19 载荷信封迁移。全部改动为工作树源码，**未发布、未做真实账号或物理设备验收**。

## 1. 网络失败分类跨层贯通

**问题**：`TransportError` 只有一个 `Unavailable` 变体，DNS 失败、连接被拒、TLS 握手失败、请求超时、响应超限和任务 abort 全部坍缩为 `ErrorCode::ServiceUnavailable`，Dart 侧因此对手机离线的用户说「学校服务暂时不可用」。用户被告知去等一个从未被连上的服务器。

**改动**：

| 层 | 文件 | 变化 |
| --- | --- | --- |
| domain | `rust/crates/ginkgo_domain/src/lib.rs` | 新增 `ErrorCode::NetworkUnreachable` 与 `AppError::network_unreachable()` |
| upstream | `foundation/http.rs` | `TransportError` 拆为 `Unreachable` / `Unavailable`，并实现 `From<TransportError> for AppError` |
| upstream | `adapters/reqwest_transport.rs` | `classify()` 把 `is_connect()` / `is_timeout()` 归为 `Unreachable` |
| upstream | `auth/session.rs` | 传输错误改用 `AppError::from`，不再统一 `unavailable()` |
| bridge | `api/mirror.rs` | 新增 `FailureCode::NetworkUnreachable` 与一对一映射 |
| Flutter | `application/failure_message.dart` | 输出「无法连接网络，请检查手机网络或校园网后重试」 |

**保留的既有行为**：匿名公开读取在传输失败后仍会做一次有界 WebVPN 回退。学校在校园网外静默丢包时连接阶段同样失败，正是 `NetworkUnreachable`；去掉回退会让所有校外读者直接失败。因此本次只改分类与文案，不改回退时序，并由回归锁定「两次请求即止」。

**回归**：upstream `network_failure_classification_tests`（2 项，含回退次数上界）；bridge `every_domain_error_code_keeps_its_own_failure_code`（新码不得与既有码折叠）；Dart `failure_message_test` 断言离线文案不得出现「学校服务」，并与 `serviceUnavailable` 互异。

## 2. 更新页 Release 正文渲染

**问题**：`maintenance_pages.dart` 用裸 `Text(result.notes)` 显示 GitHub Release 正文，用户看到的是 `# 标题`、`- 列表` 和 `**加粗**` 原文；`notes` 直接来自 `release.body`，**无长度上界**，且 `maintenance_test.dart` 完全没有覆盖。

**改动**：新增 `flutter/lib/widgets/release_notes_view.dart`（零新依赖），按仓库文案体例解析标题、`-` 列表、段落、`**加粗**` 与 `[文本](链接)`。安全约束：

- 解析前截断到 8192 字符；
- 图片只取 alt 文本，**永不加载远程图片**（避免跟踪像素）；
- 只有 `https://github.com/JUANWANG-BUAA/ginkgo…` 可点；相对文档链接、其他仓库、近似域名、http 和带凭据 URL 一律降级为纯文本。

校园域名白名单**没有**放进该组件：`check-mirror-architecture.py` 禁止 `flutter/lib/` 出现 `buaa.edu.cn` 字面量（学校目的地属于 upstream 策略）。收紧为仅本项目 GitHub 后，规则与语义同时成立。

**回归**：`release_notes_view_test.dart` 11 项（体例子集、百分号标记不外泄、加粗为 span 属性、连续行合段、白名单正反例、图片降级、长度上界、空源）；`maintenance_test.dart` 新增「渲染为列表而非 md 原文」。

## 3. 公开信息页网络中断体验

**问题**：就业活动、学术文化、校园通知、校车在首次读取失败时统一提示「请重试或前往官网」——离线用户按此操作必然再次失败；校车页更把失败码整个丢弃，硬编码为「时刻表读取未完成」。

**改动**：

- `SectionResult` / `RefreshSection` 新增可选 `failure`，页面不再需要从本地化文案反推失败类型；
- 文案收敛到 `failureAdvice({hasStaleValue, failure})` 单一来源：有旧值→「正在显示上次结果。」；离线→「手机当前连不上网络，恢复网络后重试。」；其他→「请稍后重试，或在服务目录中打开官网。」
- 校车页对有类型码的失败改用 `failureMessage`，仅无码异常保留校车专属文案；
- 重试沿用当前月份/页码，不重置查询。

**回归**：career / campus / notices / shuttle 四页各增离线用例；career 另增「重试保留查询月份并强制刷新」。

## 4. API 与接口文档同步门禁

**问题**：`docs/interfaces/*` 有 `--check` 新鲜度门禁，但 `docs/API.md`、`docs/FEATURES-AND-PROTOCOLS.md` 和 `INTERFACE-INDEX.md` 的手写部分完全靠人肉同步。目录重组后链接指空、新增适配器不登记、载荷信封清单过期都无人拦截。

**改动**：新增 `scripts/check-api-doc.py`（`--report` 只统计）与 `scripts/check-api-doc-test.py`（7 项自测），接入 `scripts/check-mirror.sh` 与 `.github/workflows/mirror.yml`，登记于 INTERFACE-INDEX §12。三项检查：

1. **内部链接可达**：`README.md` 与 `docs/**/*.md` 的相对链接必须指向存在的文件，`#锚点` 必须命中目标文档真实标题（GitHub slug 规则：去标点、保留 CJK 字母、空格转连字符）。先剥离代码块与行内代码，否则正则字符类会被当成链接。
2. **协议适配器已登记**：`adapters/*_http.rs` 每个都必须在 FEATURES-AND-PROTOCOLS 或 INTERFACE-INDEX 中按文件名出现。
3. **§6.10 与生成绑定一致**：从 `flutter/lib/src/rust/api/**` 重算命令总数与 `ReadOnlyResponse` 清单，比对手写清单、计数表和总数。

**上线即发现并修复的真实漂移**：10 处断链——`2026-10-27-android-beta1-preparation.md` 的 6 处 `docs/INTERFACE-INDEX.md` 少写 `../`；`2026-10-26-page-turn-and-protocol-followup.md` 的 3 处 `_audit/` 自指；`MIRROR-PARITY.md` 与 `2026-10-21-opus-review-followup.md` 引用 Flutter 目录重组前的旧路径。另有 `library_stats_http.rs` 未在接口索引登记，已补 §5.5 行。

## 5. R-19 载荷信封迁移（第一批）

**已完成 42 个命令**（89 个命令中 DTO 47→89、信封 42→0，逃生舱类型已删除）：

| 命令 | 变化 |
| --- | --- |
| `load_campus_activities` | 新增 `CampusActivitiesResponse` / `CampusActivitiesDto` / `CampusActivityDto`；删除 Dart `CampusActivity.fromJson`、`CampusActivities.fromJson` 与 `page < 1` 守卫（page 上界已由 upstream `validate_page` 保证） |
| `check_android_update` | 新增 `UpdateResponse` / `UpdateSummaryDto` / `AndroidDownloadDto`；`size` 以 `i64` 跨桥（上游已限定 `1..=268_435_456`）；删除 `UpdateResult.fromJson`、`AndroidDownload.fromJson`，保留 `isValid`——下载路径 `download()` 仍 fail-closed 校验 |
| `load_notices` | 新增 `NoticesResponse` / `NoticeDto`；`NoticeGateway.notices` 返回类型从桥接类型 `ReadOnlyResponse` 改为 `NoticesRead`，删除 `features/notices/notices_models.dart` 与 `noticeList` |
| `load_demo_notices` | 同步类型化，与 native 共用 `decodeNotices`，两侧不会漂移 |
| 作业文件 5 个（`homeworkFileWorkspace`、`uploadHomeworkFile`、`configureHomeworkRecovery`、`pendingHomeworkSubmissions`、`homeworkCapabilities`） | 新增 `HomeworkFileWorkspaceResponse` / `HomeworkUploadResponse` / `HomeworkRecoveryResponse` / `HomeworkPendingResponse` / `HomeworkCapabilitiesResponse` 及 Workspace/Attachment/Receipt/PendingSubmission/CapabilityEvidence DTO；能力状态由 FRB 枚举承载而呈现层保留学校原文措辞。u64 尺寸字段放宽为 i64（20 MB 上限保证无损）；`native_mirror_service` 的 `_homeworkPayload` JSON 解码器删除。写路径语义不变：busy 后备仍报 `InvalidRequest`，上传/提交仍单次不重试 |
| SPOC 学习 12 个（`learningCourses`、`courseAnnouncements[In]`、`courseAnnouncementDetail[In]`、`courseResources[At]`、`courseAssessments[In]`、`courseLearningColumns`、`courseLearningCapabilities`、`importLearningSnapshots`） | 新增 `LearningCoursesResponse` / `CourseAnnouncementsResponse` / `CourseAnnouncementDetailResponse` / `CourseResourcePageResponse` / `CourseAssessmentsResponse` / `LearningColumnsResponse` / `LearningCapabilitiesResponse` / `SnapshotImportResponse` 及 Column/ColumnKind/CapabilityState/Capability DTO。`learning_payload.dart` 的整套 JSON 解码器（含重复栏目 ID、无效状态与「目录兼文件」校验）删除：栏目与能力状态由 FRB 枚举承载，目录/文件互斥由 Rust 保证。快照协调器的 `read` 泛型化为 `read<R>(account, fetch, failureOf)`，安全快照对任意类型化响应可用；`learning_models.dart` 的呈现类型原样保留 |
| `load_graduate_credit_map` | 新增 `GraduateCreditMapResponse` 与 Map/Node/Metrics/Row DTO，学分状态由 FRB 生成的 `GraduateCreditStateDto` 枚举承载（unknown/noMinimum/incomplete/requirementMet）。旧信封解码器在 Dart 侧拒绝负数与超 1 的比例，那是 Rust core `valid()` 过滤的重复实现，随 DTO 化一并删除 |
| 博雅 6 个（`load_bykc*` / `load_demo_bykc*`） | 新增 `BykcCatalogResponse` / `BykcChosenResponse` / `BykcStatisticsResponse` 及 Semester/Course/CourseDetails/ChosenRecord/Statistics DTO；模型迁到 `application/bykc.dart`，`BykcPart` 改为 `BykcPartRead` sealed 联合，页面按返回类型分发而不是按请求参数。未公布的考勤/通过状态保持 `null`，无有效学期区间时选课列表仍是 `null` 而不是空 |
| `load_graduate_part` / `load_demo_graduate` / `load_demo_graduate_status` | 新增 `GraduateResponse` 与 Row/Section/Progress/AcademicData DTO；模型迁到 `application/graduate.dart`（`earnedRatio`/`pendingRatio`/`remaining` 派生逻辑不变）。未知成绩保持 `None`，待考核学分不计入已获 |
| `load_library_books` | 新增 `BookPageResponse` / `BookPageDto` / `BookHitDto`；`BookPage`/`BookHit` 从 `features/library/library_books_models.dart` 迁到 `application/library_books.dart`，旧模型文件删除。可借册数缺失时保持 `None`，不伪造 0 |
| `load_library_loans` | 新增 `LibraryLoansResponse` / `LibraryLoanPageDto` / `LibraryLoanDto`；本人借阅的可选字段保持 `null` 而非空字符串，解码器从 `infrastructure/native_library_loans.dart` 移除 `jsonDecode` |
| `load_library_stats` / `load_demo_library_stats` | 新增 `LibraryStatsResponse` 及 CountPair/ReadingRoom/CampusStats/LibraryStats DTO。模型从 `features/library/library_stats_models.dart` 迁到 `application/library_stats.dart`；缺席的座位/研讨间/寄存柜保持 `None`，绝不报 0 |
| `edit_tasks` | 新增 `LocalTasksResponse` / `LocalTaskDto`；`source` 由 `Option<TaskSource>` 投影为 `source_assignment_id`，本机待办记录不再跨桥传 JSON。`LocalTaskRecord.fromJson` 与 `parseLocalTasksPayload` 随后一并删除——Rust 存储读取已做校验，Dart 侧不再有第二套解析 |
| `load_library_holdings` | 新增 `BookHoldingsResponse` / `BookHoldingDto`；只读公开馆藏，status 保留学校原文。FRB 把 `library` 字段生成为 `library_`（`library` 是 Dart 关键字），Dart 解码器按生成名接收 |
| `checkin_load_progress` | 新增 `CheckinLoadProgressResponse`，契约收窄为 `phase` + `elapsed_ms`（Dart 只消费这两项，`stages` 从未显示）；本地 `u128` 毫秒在桥接处转为 `i64`，未启动计时时保持 `None` 而不是 0 |
| `load_shuttle_timetable` | 新增 `ShuttleTimetableResponse` 及 Run/Section/Table/Timetable DTO；值类型与 `ShuttleGateway` 从 `features/shuttle/shuttle_models.dart` 迁到 `application/shuttle.dart`（`appliesToday`/`minuteOfDay`/`todayRuns` 逻辑不变）；`MirrorEnvironment` 下沉到 `application/environment.dart`，避免 gateway 迁出后形成 application 内部循环导入 |
| CGYY 3 个（`load_cgyy`、`execute_cgyy`、`load_demo_cgyy`） | 新增 `CgyyLoadResponse`（`venues`/`day`/`orders`/`order`/`lockCode` 五个互斥可空形状字段）与 `CgyyActionResultResponse` 及 Site/Slot/Space/Day/Order/LockCode/BookingChoice/Purpose/BookingOptions/Challenge/Review/ActionResult 共 12 个 DTO；演示端 `load_demo_cgyy` 复用合成契约 codec，与真实端共享返回类型。Dart 侧 `cgyy_models.dart` 的全部 `fromJson` 载荷构造器删除，新增 `infrastructure/cgyy_decode.dart` 承接 DTO → 呈现模型投影；`native_mirror_service.executeCgyy` 对硬失败显式抛错，忙碌后备（`CGYY_WRITE` try_lock 失败 → `ServiceUnavailable`）永不呈现为 `uncertain`。同批删除 `ReadOnlyResponse` 结构、mapping.rs 的 `read_only_response`/`read_only_value` 及其两个信封回归测试——信封逃生舱自此不存在 |

同批把 `public_payload_contract_test.dart` 更名并重写为 `public_read_contract_test.dart`：`load_campus_activities` 迁移后「缺字段/非法 page 是协议错误」的前提消失（形状由 Rust 保证），该组断言删除，改为 DTO 字段投影与空成功/失败区分。

**迁移收口**：载荷信封逃生舱已整体删除，89 个 FFI 命令全部返回类型化 DTO；`scripts/check-api-doc.py` 持续比对 §6.10 清单与计数，重新引入信封即门禁失败。CGYY 的输入侧 JSON 契约（Dart → Rust `executeCgyy` 命令参数）按设计保持不变，不在本次范围。

## 验证

`bash scripts/check-mirror.sh` 通过；含架构与门禁自测、design-token 预算（edge_insets 预算随改动从 268 下调到 267）、接口索引新鲜度、`cargo fmt --check`、严格 Clippy、Rust 全量测试、`flutter analyze` 与全量 Flutter 测试、FRB 二次生成无漂移。`git diff --check` 通过。

**未覆盖**：无物理 Android 设备、无真实学校账号、无学校写操作；新失败码的真实网络分支（离线、DNS 失败、TLS 失败）只在合成传输上验证，未经真机复现。更新页 markdown 渲染只经 widget 测试，未在真机大字号/深色下目测。

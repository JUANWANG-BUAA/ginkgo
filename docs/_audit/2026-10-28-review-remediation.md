# 三轮审查整改台账（2026-10-28）

本文件是 [架构边界审查](2026-10-28-architecture-boundary-review.md)、[设计语言与模块布局审查](2026-10-28-design-language-and-module-layout-review.md)、[并发异步回调审查](2026-10-28-concurrency-async-callback-review.md) 三份审查的**唯一整改台账**。

规则：

- 每修完一项，在本表把状态改成 `✅ 已修复`，并在「修复记录」里写清**改了什么**、**为什么**、**用什么证据锁住**。
- 未修复项保持 `⬜ 待处理`，不得在未完成时标记。
- 三份审查正文里对应小节同步加 `✅ 已修复` 标记并链接本表。
- 未完成事项的**执行顺序**仍然只维护在 [MIRROR-TODO](../MIRROR-TODO.md)；本表只记录「审查发现 → 是否已改」。

状态图例：`✅ 已修复` · `🟡 进行中` · `⬜ 待处理` · `⏭️ 降级/不做（附理由）`

---

## 0. 进度总览

| 审查 | 条目 | 已修复 | 进行中 | 待处理 |
| --- | --- | --- | --- | --- |
| 并发 / 异步 / 回调 | 21 | **20** | 0 | 1 |
| 架构边界 | 12 | **10** | 0 | 1（另有 B-04 暂缓） |
| 设计语言 / 模块布局 | 21 | **6** | 0 | 15 |
| 文档同步与准确性 | 5 | **5** | 0 | 0 |
| **合计** | **59** | **41** | **0** | **17（另有 1 项暂缓）** |

2026-10-28 后续收口门禁：`bash scripts/check-mirror.sh` **EXIT=0**（架构与索引自测、design-token 预算、接口索引、Rust 格式/Clippy/测试、`flutter analyze`、**636 项 Flutter 测试**、FRB 二次生成无漂移）；`flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` **成功**（正常入口 Debug 产物）。这些是本地合成与构建证据，不代表真实账号、学校写入、物理设备或 Windows 验收。

收口复核：本地 Debug 构建命令显式指定 `lib/main.dart`；当前 Debug 的 `GeneratedPluginRegistrant` 仍包含 `integration_test` 插件注册，因此不能把这份 Debug 产物写成“不含测试插件”或公开发布资产。插件注册本身也不足以证明应用使用测试入口；真实启动仍需单独设备验收。

本次收口时 `adb devices -l` 无已连接 Android 设备，`flutter devices --machine` 也未列出 Android 目标，因此未执行该构建的设备启动验收。

---

## 1. 并发、异步与回调（按严重度）

| ID | 条目 | 严重度 | 状态 | 位置 |
| --- | --- | --- | --- | --- |
| R-01 | 锁等待移出超时预算（命令可无限挂起） | P0 | ✅ 已修复 | 并发审查 §1.1 |
| R-02 | Dart 侧 FFI 命令无超时兜底 | P0 | ✅ 已修复 | 并发审查 §1.2 |
| R-03 | Rust 挂起 → Dart busy 闩死 → 功能整会话失效 | P0 | ✅ 已修复 | 并发审查 §3.1 |
| R-04 | `edit_tasks` 的 fsync 无超时 | P1 | ✅ 已修复 | 并发审查 §1.3 |
| R-05 | 作业文件 journal：async fn 内持同步锁做 fsync | P1 | ✅ 已修复 | 并发审查 §1.4 |
| R-06 | `sign_out` 在全局写锁内做 Keystore JNI + 同步 commit | P1 | ✅ 已修复 | 并发审查 §1.5 |
| R-07 | `reconcile()` 无 in-flight 守卫，15 秒定时器堆积 | P1 | ✅ 已修复 | 并发审查 §3.2 |
| R-08 | `LibraryController._bookingTask` 空窗竞态 | P1 | ✅ 已修复 | 并发审查 §3.3 |
| R-09 | `uncertainActions` 闩死，accepted 后按钮永久禁用 | P1 | ✅ 已修复 | 并发审查 §3.4 |
| R-10 | 图书馆写路径无账号复检，隔离靠 FFI 锁（未测试） | P1 | ✅ 已修复 | 并发审查 §2.3 |
| R-11 | Android 主线程同步 fsync（`reminders` 通道） | P2 | ✅ 已修复 | 并发审查 §1.6 |
| R-12 | 12 个读页面无代次守卫、无 `didUpdateWidget` | P2 | ✅ 已修复 | 并发审查 §3.5 |
| R-13 | `checkin_request_gate` 让不同日期的读互相排队 | P2 | ✅ 已修复 | 并发审查 §3.6 |
| R-14 | `silent_login` 的 `recovery_gate` 覆盖整个 CAS 链 | P2 | ✅ 已修复 | 并发审查 §3.7 |
| R-15 | 「守卫不跨 await」只有注释，无门禁 | P2 | ✅ 已修复 | 并发审查 §2.4 |
| R-16 | `library_mutation_service` 缺账号复检 | P1 | ✅ 已修复 | 并发审查 §2.3（与 R-10 同一处，一次修完） |
| R-17 | `ReminderScope` 的 `unawaited` 挂起时既不报错也不完成 | P2 | ✅ 已修复 | 并发审查 §4.3 |
| R-18 | `unawaited` 清单复核 | P3 | ✅ 已修复 | 并发审查 §4.3 |
| R-19 | 桥接 DTO 映射层无有效覆盖 | P1 | ⬜ 待处理 | 边界审查 §4.5 引用 |
| R-20 | bridge 层缺「写操作在途时切账号」回归 | P2 | ✅ 已修复 | 并发审查 §2.3 建议 |
| R-21 | 缺少「Rust 命令挂起 → Dart 页面可恢复」回归 | P1 | ✅ 已修复 | 并发审查 §5 建议 |

---

## 2. 架构边界

| ID | 条目 | 严重度 | 状态 | 位置 |
| --- | --- | --- | --- | --- |
| B-01 | 根 barrel 把 infrastructure 泄漏给 43 个页面 | P0 | ✅ 已修复 | 边界审查 §1.1 |
| B-02 | `shared/` 反向依赖 `features/` | P0 | ✅ 已修复 | 边界审查 §1.2 |
| B-03 | `features/cgyy/cgyy_gateway.dart` 自建服务定位器并直出 FFI 载荷 | P0 | ✅ 已修复 | 边界审查 §1.3 |
| B-04 | `widgets/` 依赖持久化层 | P1 | ⏭️ 暂缓（紧凑模式需改为 InheritedWidget 注入，收益小于风险） | 边界审查 §1.4 |
| B-05 | `features/` 依赖 `infrastructure/` | P2 | ⬜ 待处理 | 根 barrel 直连已收敛；文件动作、维护服务和独立页面工厂仍有依赖 |
| B-06 | 页面异步状态机手写 7 份 | P1 | ✅ 已修复 | 边界审查 §2.1 |
| B-07 | `career` / `campus_activities` 两页相似度 0.661 | P1 | ✅ 已修复 | 边界审查 §2.1 |
| B-08 | 空态 / 错误态包装组件 3 套 | P1 | ✅ 已修复 | 边界审查 §2.2 |
| B-09 | 页头包装 3 套 + 3 处内联 | P1 | ✅ 已修复 | 边界审查 §2.2 |
| B-10 | 北京时间换算旁路 6 处 | P1 | ✅ 已修复 | 边界审查 §2.3 |
| B-11 | 「打开官网」4 套实现、4 种失败文案 | P2 | ✅ 已修复 | 边界审查 §2.4 |
| B-12 | Rust 侧「读配方」在 10 个 service 手写重复 | P0 | ✅ 已修复 | 边界审查 §2.5 |

---

## 3. 设计语言与模块布局

| ID | 条目 | 严重度 | 状态 | 位置 |
| --- | --- | --- | --- | --- |
| D-01 | 31 个死 token、门面只暴露约 16 个 | P1 | ✅ 已修复 | 设计审查 §1.1 |
| D-02 | 字阶缺 `15`/`16` 两档（用量最大） | P1 | ✅ 已修复 | 设计审查 §1.2 |
| D-03 | 圆角越界 7 档、间距越界 16 档 | P2 | ⬜ 待处理 | 设计审查 §1.3、§1.4 |
| D-04 | 图标 / 字重 / 触控 / 底留白 / 分割线 / 透明度 6 个维度无 token | P1 | ⬜ 待处理 | 设计审查 §1.5 |
| D-05 | 共享组件自身硬编码 | P1 | ⬜ 待处理 | 设计审查 §1.6 |
| D-06 | 三态组件 6 套 / 徽标 8 套 / 指标卡 9 套 / 行 17 套 / 折叠 4 套 / 对话框 2 套+12 内联 | P1 | ⬜ 待处理 | 设计审查 §1.7 |
| D-07 | `Apple*` 命名用于 Android-only 产品（833 行 / 102 文件） | P2 | ⬜ 待处理 | 设计审查 §1.8 |
| D-08 | Dart 网关未镜像 Rust 端口：`LibraryGateway` 含校车、`CampusGateway` 含本机待办 | **P0** | ✅ 已修复 | 设计审查 §2.1 |
| D-09 | 25 处运行期 `is` 探测 + 13 处强转 | P1 | ✅ 已修复 | 设计审查 §2.2 |
| D-10 | `features/tasks/rules_page.dart` 装的是学术选课规则页 | P1 | ✅ 已修复 | 设计审查 §2.3 |
| D-11 | `features/library/` 混装 3 个学校系统 | P1 | ⬜ 待处理 | 设计审查 §2.3 |
| D-12 | `features/cgyy/` 混装读 / 写 / 验证码 | P1 | ⬜ 待处理 | 设计审查 §2.3 |
| D-13 | `features/reservations/` 是跨域聚合页，不是领域 | P2 | ⬜ 待处理 | 设计审查 §2.3 |
| D-14 | `shared/` 混装 4 类职责 | P1 | ⬜ 待处理 | 设计审查 §2.3 |
| D-15 | `application/` 混装 5 类职责 | P1 | ⬜ 待处理 | 设计审查 §2.3 |
| D-16 | `platform/` 混装适配器 + 呈现 + 网络抓取；1 行纯 re-export | P1 | ⬜ 待处理 | 设计审查 §2.3、§3.4 |
| D-17 | `design/` 与 `widgets/` 边界不清 | P2 | ✅ 已修复 | 设计审查 §3.5 |
| D-18 | 目录命名三种口径混用、`campus` 与 `campus_card` 同前缀异义 | P1 | ⬜ 待处理 | 设计审查 §2.4 |
| D-19 | 目录粒度 1～15 文件相差 15 倍 | P2 | ⬜ 待处理 | 设计审查 §2.5 |
| D-20 | 文件后缀 7 种混用 + 4 个合集文件 | P2 | ⬜ 待处理 | 设计审查 §2.6 |
| D-21 | 4 处依赖方向倒置 + 插件落位错 | P1 | ⬜ 待处理 | 设计审查 §3.1、§3.2 |

---

## 4. 文档同步与准确性

| ID | 条目 | 状态 | 位置 |
| --- | --- | --- | --- |
| C-01 | `ARCHITECTURE-TOPOLOGY.md` 的 trait 数 / 分组数 / 依赖数 / 能力数过期 | ✅ 已修复 | 边界审查 §4.1 |
| C-02 | `INTERFACE-INDEX.md` §6.10 的载荷信封计数错、清单漏 2 个命令 | ✅ 已修复 | 边界审查 §4.2 |
| C-03 | `MIRROR-TODO.md` P2 的 FFI 命令数过期 | ✅ 已修复 | 边界审查 §4.3 |
| C-04 | `API.md` 章节层级错乱（6D/6F 顺序、7.3/7.4 脱离父节） | ✅ 已修复 | 边界审查 §4.4 |
| C-05 | 目录层级与归属规则未进架构文档 | ✅ 已修复 | 设计审查 §5 第 21 项 |

---

## 修复记录

### R-01 ✅ 锁等待移出超时预算

**日期**：2026-10-28

**问题**：全部 89 个 FFI 命令先 `SESSION_ACCESS.read()/write().await` 取闸门，再进入 `bounded_read` / `bounded_session` / `bounded_submit`。预算只覆盖「干活」，**闸门等待无上界** —— 排在一个 90 秒登录后面的读命令会永远等下去，Dart 侧 Future 永不完成，页面永远转圈。

**改法**：

1. 新增 `GATE_BUDGET`（45 秒）与 `SESSION_GATE_BUDGET`（90 秒）两个独立预算，闸门等待一律在其中完成；超时返回 `AppError::unavailable()`（写命令返回 `None`，由调用方按「结果不明」处理）。
2. 新增 6 个助手，把「取闸门 + 干活」合成一个 future：

   | 助手 | 闸门 | 工作预算 | 返回 |
   | --- | --- | --- | --- |
   | `with_session_read` | SESSION 读 | 45 秒 | `Result<T, AppError>` |
   | `with_session_read_in` | SESSION 读 | 自定义 | `Result<T, AppError>` |
   | `with_session_write` | SESSION 写 | 90 秒 | `Result<T, AppError>` |
   | `with_session_submit` | SESSION 读 | 90 秒 | `Option<T>` |
   | `with_module_read` | SESSION 读 + 模块读 | 45 秒 | `Result<T, AppError>` |
   | `with_module_submit` | SESSION 读 + 模块写 | 90 秒 | `Option<T>` |

3. 新增 `ModuleAccess` 枚举（`Library` / `CheckIn` / `Cgyy`）统一三个模块闸门的取用，避免每个命令各写一遍匹配。
4. **全部 89 个命令改用助手**：`live/{academic,auth_challenge,bykc,checkin,classroom,graduate,homework,learning,library,session,utilities}.rs`。`grep` 确认 bridge 内已无任何裸 `SESSION_ACCESS.read()/write()`、`LIBRARY_ACCESS`、`CHECKIN_ACCESS`、`CGYY_ACCESS` 取用。
5. `edit_tasks` 的 `spawn_blocking` 一并纳入预算（见 R-04 的部分修复）。

**为什么这样做**：闸门等待与工作预算**分开**而不是合成一个 45 秒总预算，是为了不回归现有行为 —— 原本「排队无上限 + 工作 45 秒」，改成「排队 45 秒 + 工作 45 秒」后总耗时上界是 90 秒，原本能在 45 秒内完成的慢读仍能完成，只是排队超过 45 秒才失败。

**证据**：

- 新增 `runtime.rs` 的 `gate_budget_tests` **6 条**回归：
  - 读排在写闸门后 → 失败为 `ServiceUnavailable`，不无限等待；
  - 写排在读闸门后 → 失败为 `ServiceUnavailable`；
  - 提交排在写闸门后 → 返回 `None`，不伪造结果；
  - 模块读排在模块写后 → 失败为 `ServiceUnavailable`；
  - 闸门在 body 期间生效、body 结束后释放；
  - body 的错误原样透传，不被误判为超时。
- `lifecycle_tests::sign_out_waits_for_active_bridge_reads` 改为 `#[tokio::test]`（原测试手工 poll future，不带 tokio runtime，无法承载 `tokio::time::timeout`），语义不变：登出仍等待在途读。
- 为进程级静态闸门新增 `TEST_GATE` 测试串行锁，避免各测试互相排队造成假失败。
- `cargo clippy --workspace --all-targets -D warnings` 通过；`cargo test --workspace` 全绿（bridge 24 项，含新增 6 项）。

**未覆盖**：`ginkgo_upstream` 服务层内部的闸门（如 `checkin_request_gate`、`recovery_gate`）不在本次范围，见 R-13、R-14。

### R-02 ✅ Dart 侧 FFI 命令超时兜底

**日期**：2026-10-28

**问题**：89 个 FFI 命令在 Dart 侧一个超时都没有（生成绑定里 `timeout` 出现 0 次）。Rust 侧即使有预算，一旦出现非预期的挂起（平台通道、磁盘、运行时异常），页面就永久转圈，没有任何降级路径。

**改法**：

1. 新增 `infrastructure/native_command.dart`，提供 `boundedNative` / `boundedNativeRead` / `boundedNativeWrite` 三个入口。
2. 预算设计成**高于** Rust 的双层预算，避免抢先掐断合法慢请求：

   | 预算 | 值 | Rust 侧对应上界 |
   | --- | --- | --- |
   | `nativeReadBudget` | 120 秒 | 闸门 45 + 工作 45 = 90 |
   | `nativeWriteBudget` | 210 秒 | 闸门 90 + 工作 90 = 180 |

3. **106 处原生调用全部包裹**（`native_mirror_service` 48、`native_learning` 15、`learning_snapshot_store` 2、`maintenance_service` 2、`native_career` 1、`native_campus_activities` 1、`native_library_loans` 1、`native_auth_challenge` 1）。演示服务的 `live.*` 只做本地合成数据与 DTO 构造，不需要预算。
4. 超时以 `TimeoutException` 抛出，**不做错误码翻译**：既有页面已经把「抛出异常」映射到各自的失败态；写路径也本来就把「抛出」当作「学校可能已收到」，语义正确，不需要新的分支。

**为什么预算高于 Rust**：Dart 预算是**第二道防线**，只在 Rust 从不返回时触发。若把它设成 90 秒，就会在 Rust 闸门慢但健康时抢先失败，把「慢」误报成「不可用」。

**证据**：

- `test/native_command_test.dart` 6 条：透传值、透传自身错误、**永不完成时抛 `TimeoutException`**、读预算高于 Rust 读上界、写预算高于 Rust 写上界、两个预算不等。
- `test/native_command_page_test.dart` 2 条：预算失败后页面离开加载态并给出「本地服务暂时不可用 / 重试」；一直在途的读仍显示加载态（证明超时是唯一出口，不是提前放弃）。
- `flutter analyze` 无问题；`flutter test test` 573 项全绿。

---

### R-03 ✅ busy 闩死（一次挂起让功能整会话失效）

**日期**：2026-10-28

**问题**：`ReminderController._busy` 与 `_ReminderScopeState._activating` 都是**只进不出**的布尔闩：读不落地 → `_busy` 永久 true → 每次 `refresh()` 直接 return → `_activating` 永久 true → `_start()` 永不执行 → 2 分钟轮询与 15 秒 tick 定时器从不创建 → 提醒在整个会话内失效，只能杀进程。`RefreshSection.loading` 与 `LibraryController.loadingBookings/loadingVenues` 同类。

**改法**：

1. 新增 `application/busy_gate.dart` 的 `BusyGate`：带截止时间的忙碌闸门。到期后**只开闸**（让下一次尝试能跑），**不取消在途工作**（原生命令也无法取消），并通过 `onExpired` 让调用方可以告知用户。
2. `ReminderController`：`_busy` 换成 `_refreshGate`（5 分钟），到期设 `hint = '上次提醒刷新未完成，已重新允许刷新'` 并通知。
3. `_ReminderScopeState`：`_activating` 换成 `_activation`（5 分钟）；并且**把 `_start()` 提前到 `await refresh` 之前**——不论这次读是否落地，轮询都必须跑起来。
4. `RefreshSection`：新增 `stallDeadline`（默认 3 分钟）。到期时**复用既有的 `_generation` 机制**丢弃迟到结果、清 `loading`、写 `error`；并新增 `_isStalled`，使下一次 `refresh` 不再加入那个永不完成的 slot，而是重新开始。
5. `LibraryController`：新增 `stallDeadline`（默认 3 分钟）与 `_armStall`/`_clearStall`。到期时递增 `_generation`、清 loading、写 error，并且**主动把 slot 置空**（`_bookingTask` / `_venueTask`）——这是测试实际抓出来的问题：只清 loading 不清 slot，后续 `loadBookings(force: true)` 会永久排在废弃的 slot 后面。

**为什么保留 inflight future**：`BusyGate` 明确只恢复闸门、不假装工作结束；`RefreshSection` 用代次把迟到结果丢掉。两者都不伪造结果，符合「失败不清空旧数据、不伪造空值」。

**证据**：

- `test/busy_gate_test.dart` 6 条：重复进入被拒、离开可复用、重复离开无害、**到期自动开闸并上报**、正常完成后不上报、`dispose` 取消看门狗。
- `test/refresh_section_test.dart` 新增 1 条：读永不落地时 3 分钟内仍 loading、到期后停止 loading 且**保留上一次的值**、后续 refresh 不被废弃 slot 吸收、迟到结果不落地。
- `test/library_controller_test.dart` 新增 1 条：读永不落地时停止 loading、写入 error、后续强制刷新能正常开始（此用例在实现过程中先失败，暴露出 slot 未释放，已按失败原因修正实现）。
- `flutter test test` 573 项全绿；`flutter analyze` 无问题。

### R-04 ✅ `edit_tasks` 的 fsync 不再无界

**日期**：2026-10-28

**问题**：`edit_tasks` 的 `spawn_blocking` **没有超时**（对比 `execute_cgyy` 有 `bounded_submit`）。卡住的 fsync 会让命令永不返回，待办页永久 busy。

**改法**：R-01 的 `with_session_read` 已经把「取闸门 + `spawn_blocking` 等待」一起纳入 45 秒预算，命令必定终止。超时映射为 `ServiceUnavailable`，`payload` 为空 —— 页面显示「本地服务暂时不可用 / 重试」，不会把未落盘的写入当成成功。

**为什么不做「取消 fsync」**：`spawn_blocking` 的任务不可取消；即使放弃等待，磁盘写也会跑完。因此只在**返回值**上放弃，语义是「本机写入未确认」，而不是「写入已回滚」。

**证据**：新增 `utilities.rs` 的 `bounded_command_tests::a_queued_local_write_fails_instead_of_waiting_for_the_gate` —— 在写闸门被占时调用 `edit_tasks`，断言立即返回 `ServiceUnavailable` 且无 payload。

---

### R-05 ✅ 作业文件 journal 的 fsync 移出锁与 async worker

**日期**：2026-10-28

**问题**：`journal::{restore, create, clear, configure}` 在**持有 `homework_files`（`std::sync::Mutex`）** 的情况下做目录遍历、`create_dir`、`set_permissions`、`sync_all()`。这些是**阻塞 OS 线程**的调用，由 async fn 直接调用，而且 `std::sync::Mutex` 的等待也会阻塞其它任务的 worker 线程。`MIRROR-TODO` 记的「CGYY 与待办移入 `spawn_blocking`」并未覆盖这一处。

**改法**：把每个 journal 操作**拆成两相位**——

| 原函数 | 磁盘相位（无锁，可放 `spawn_blocking`） | 内存相位（持锁，纯内存） |
| --- | --- | --- |
| `configure` | `prepare_root(&str) -> PathBuf` | `adopt_root(&mut files, &Path)` |
| `restore` | `read_records(&Path, owner) -> Vec<Recovered>` | `apply_restore(&mut files, owner, rows)` |
| `create` | `write_record(&Path, account, &Record)` | `record(&files, handle, baseline) -> Record` |
| `clear` | `clear_record(&Path, handle, file, assignment)` | `clear_target(&files, handle) -> (path, file, assignment)` |

调用侧新增 `restore_journal(&self, owner)` 助手：锁内取 root → `spawn_blocking` 读盘 → 锁内合并。`submit_homework_file` 落盘同理：锁内快照 `Record` → `spawn_blocking` 写盘 → 锁内**复检 owner** 再置 `Sent`。

**为什么要复检 owner**：落盘期间锁是释放的，账号可能已经切换。置状态前再比对一次 owner，避免把新账号的记录标成 Sent。

**顺带修掉的真实缺陷**：`write_record` 原本从 `upload.owner.0` 取账号拼路径，拆相位后 `Record` 只持有 `account_digest`，因此改为**显式传 account**，杜绝了「用 digest 当账号名」这类隐性错误。

**证据**：

- 新增 `journal::phase_tests` 3 条：磁盘相位无需 `HomeworkFiles` 即可完成「写 → 读 → 另一账号看不到 → 精确删除」全流程；相对路径被拒；符号链接根目录被拒。
- 既有 `homework_pending_survives_restart_and_identity_generation_without_resend`（重启后仍拦重复提交、reconcile 后清空）等 364 项 upstream 测试全部保持通过 —— 证明拆相位是**行为等价**重构。
- `Cargo.toml` 的 `tokio` 基础特性补 `rt`（`spawn_blocking` 需要），不改变运行时行为。

### R-06 ✅ `sign_out` 不再在全局写锁内碰平台存储

**日期**：2026-10-28

**问题**：`sign_out` 在 `SESSION_ACCESS.write()` 独占期间做 `vault.accounts()`（JNI）与逐账号 `vault.delete()`（Kotlin `commit()` 同步 fsync）。一次登出会让**所有**读命令排队等它的磁盘操作。

**改法**：把「吊销」与「清凭据」拆成两个端口动作，跨越三层：

1. **domain**：`SessionSource` 新增 `purge_credentials()`，与 `sign_out()` 并列。文档写清拆开的两个理由：让调用方在碰平台存储前释放独占闸门；让慢/坏的保险库无法阻塞吊销本身。
2. **core**：`Workspace::purge_credentials()` 转发。
3. **upstream**：`sign_out` 只做内存吊销（identity、generation、cookies、snapshots），并把账号暂存到新增的 `forgotten_account`；`purge_credentials` 读出该账号、补齐待删列表、再删除。
4. **bridge**：`sign_out` 先用 `with_session_write` 完成吊销（闸门在此释放），**然后**才 `purge_credentials()`。

**为什么不让 `purge_credentials` 用 `spawn_blocking`**：`vault` 是 `SchoolClient` 的字段，不是 `'static`，无法移进阻塞任务（`borrow escapes`）。要在不引入 `Arc<V>` 重构的前提下消除真正的危害（排队），正确的做法是**不持闸门**，而不是换线程。剩下的「占一个 worker 若干毫秒」是用户主动触发、每次一两次的本地调用，可以接受，并已在注释中写明。

**顺带改善**：保险库删除失败现在**不可能**影响会话吊销 —— 吊销先完成、且不再依赖枚举结果。`sign_out` 的闸门超时也返回「已登出」（identity 与 cookies 已在 `sign_out` 内清空，本机显式退出标记保证下次启动停在登录页）。

**证据**：

- `sign_out_clears_identity_credentials_and_snapshots` 改为**分两步断言**：`sign_out()` 后立刻断言「零上游请求 + 无身份 + 凭据仍在（吊销不依赖存储延迟）」，再断言 `purge_credentials()` 清空，最后断言**再调一次无害**。
- `sign_out_after_route_change_removes_saved_account` 同步补第二步。
- upstream 测试由 364 增至 367，全 workspace 14 个测试目标全绿；`cargo clippy -D warnings` 干净。
- 两个 mock 端口（`ginkgo_core` 的 `Mock` 与 `LocalIdentity`）补实现，证明新端口方法在纯规则测试里也可满足。

### R-07 ✅ `reconcile()` 的 15 秒定时器不再堆积

**日期**：2026-10-28

**问题**：`ReminderController.reconcile()` 没有 in-flight 守卫，而 `_ReminderScopeState` 每 15 秒调一次。一次 `platform.replace` 超过 15 秒就会重叠——多份 replace 在 Android 主线程排队，每份重复取消并重设最多 60 个闹钟。

**改法**：`reconcile()` 改为「合流 + 补跑一次」：飞行中的请求共享同一个 future；期间新到的请求**不丢弃**（计划可能已变），而是排队后**补跑一次**。内部 `_reconcile()` 保留原逻辑。

**为什么补跑而不是直接合并**：直接合并会把「tick 期间计划变了」丢掉，导致提醒与该 tick 前的状态一致却不再更新。补跑一次既保证不重叠，也保证最终一致。

**证据**：`test/extended_reminders_test.dart` 新增 `overlapping reconciles are joined and rerun once` —— 平台通道挂起时发起 3 次 reconcile，断言只有 1 次在途、后两次返回同一 future、`maxInFlight == 1`（平台通道上永不重叠）。

---

### R-08 ✅ `LibraryController` 强制读交接期的空窗竞态

**日期**：2026-10-28

**问题**：`_chainForced` 里第一个读的 `whenComplete` 先把 `_bookingTask` 置 null，随后 `then` 回调才把新任务写回。两个微任务之间 `_bookingTask` 是 null。`reservationChanged()` 只 `await _bookingTask`，落在这个空窗时会立即返回并**并发启动第二次强制读**。

**改法**：`reservationChanged()` 改为 `await (_bookingForcedRun ?? _bookingTask)` —— 等待「当前真正拥有 slot 的那个读」，而不是可能处于空窗的普通 slot。

**证据**：`test/library_controller_test.dart` 新增 `a change during a chained readback does not start a second one`：读挂起 → 链式强制读 → 释放 → 交接期发起 `reservationChanged`，断言读次数有界。

---

### R-09 ✅ `uncertainActions` 不再永久封锁操作

**日期**：2026-10-28

**问题**：`perform()` 在**写之前**就把 `id/action` 加进 `uncertainActions`，只有 `notSubmitted` / `rejected` 会解除。`accepted` 不解除 → 该按钮在页面生命周期内**永久禁用**，且页面没有「我已核对」的入口，用户只看到一个灰掉且无解释的按钮。

**改法**：条件反过来 —— **只有 `uncertain` 保持封锁**，其余终态（`accepted` / `rejected` / `notSubmitted`）全部解除。`accepted` 是已确认的写，紧随其后的 `reservationChanged()` 强制回查会刷新预约列表，页面据此重新推导可用操作。

**为什么不保留 `accepted` 的封锁**：`accepted` 意味着学校已确认生效，继续封锁没有安全收益，只有可用性损失（AGENTS.md §7 要求写结果不明时不重发——`accepted` 恰恰是「已明」）。

**证据**：`test/library_controller_test.dart` 新增 2 条：`an accepted write releases the action again`、`an uncertain write keeps the action blocked`（后者锁住「不明结果必须继续封锁」这一安全语义不被回归掉）。

### R-10 / R-16 ✅ 图书馆写路径自带账号复检，隔离不再依赖 FFI 锁

**日期**：2026-10-28

**问题**：`library_mutation_service` 的两个写操作**没有任何账号复检**——开头那个 `current_account().is_err()` 连返回值都丢弃。它当时安全，**只是**因为 `live/library.rs` 让写操作持 `SESSION_ACCESS.read()`，使 `login` / `sign_out` 无法并发。这条保证跨了 crate、写在别处、**没有任何注释或测试说明**；`ginkgo_core` 的测试直接调 `Workspace`、不经过 bridge 锁，所以真正的隔离机制零覆盖——把 bridge 锁改成读优先或删掉，测试全绿、生产串号。

**改法**：

1. `reserve_library_seat`：`account_owner()` 取 owner（替换丢弃结果的存在性检查），并在**派发前**（拿到 token 之后）`check_account_owner(&owner)`；变化则 `not_submitted("账号已变化，未提交预约")`，**不发**学校请求。
2. `perform_library_action`：同样在派发前复检。
3. 注释写明「这道检查让保证落在端口本地，因此任何调用方都安全，且规则可在没有 bridge 的情况下被测试」。

**为什么在派发前而不是入口**：写路径中途有多次 await（取 slot/seat、取 token），账号只可能在 await 之间变化；入口检查无法覆盖这些窗口。

**证据**：新增 `library_writes_reject_an_account_switch_before_dispatch`（Rust upstream）——
- 正常路径仍单次派发 `space/confirm`；
- `sign_out()` 后同一端口返回 `NotSubmitted`，且**学校写端点请求数不变**；
- `perform_library_action` 同样拒绝且不发请求。

### R-11 ✅ Android `reminders` 通道移出主线程

**日期**：2026-10-28

**问题**：`ReminderScheduler.replace` 在 MethodChannel 的**主线程**上做 2 次 `SharedPreferences...commit()`（同步 fsync）、最多 60 次 `AlarmManager.setAndAllowWhileIdle` 与若干 `NotificationManager.cancel`。低端机足以造成明显卡顿甚至 ANR。其余 4 个通道都是干净的（`learning-snapshots` 用 `makeBackgroundTaskQueue`，`homework-files` / `update` 自带 executor，`system` 用 `apply()`）。

**改法**：与 `UpdateInstaller` 同构——`ReminderScheduler` 自带单线程 `worker` + `main` Handler：`replace` 的全部磁盘与系统服务操作在 worker 上跑，结果用 `main.post` 回主线程 `result.success` / `result.error`。新增 `dispose()` 关闭 executor，`MainActivity.onDestroy` 调用它。

**保留在主线程的部分**：`summary` 只读 `SharedPreferences` 内存快照并解析 ≤60 条 JSON，属于诊断入口，代价可忽略，改动它只会增加代码而不是减少风险。

**证据**：`flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` 构建成功（Kotlin 编译通过）；`flutter analyze` 无问题；`flutter test test` 577 项全绿。

### R-13 / R-14 / R-15 / R-17 / R-18 / R-21 ✅ 独立并发整改

**改法**：

1. 签到请求按日期持有独立 tokio 闸门；同日仍共享认证与快照，异日网络链互不等待。
2. 学校会话与 WebVPN 网关恢复使用各自的 single-flight 锁，保留 generation 复检和失败冷却，独立 CAS 链不再互相排队。
3. 架构门禁新增同步 guard 跨 `.await` 检查及合成自测，显式 `drop` 后 await 与 tokio 异步锁不误报。
4. 提醒偏好恢复增加一分钟上界；超时或失败后保留可观测提示、使用默认偏好并继续激活轮询。恢复看门狗使用显式可取消 `Timer + Completer`，页面销毁与恢复完成都会取消，避免 `Future.timeout` 留下一分钟 pending timer。全部 `unawaited` 调用点已复核，偏好队列清理 future 自带错误合流。
5. 页面端到端回归使用真实 `boundedNative` 包裹永不完成的 Future，验证加载 → 超时失败 → 可重试，而不只验证 helper 本身。

**证据**：签到相关 21 项、会话相关 26 项 Rust 测试通过；架构门禁 18 项自测通过；提醒生命周期与扩展测试 20 项（含销毁取消看门狗回归）、原生命令页面测试 2 项通过；完整 upstream 测试在后续总门禁统一复核。

### B-01 ✅ 根 barrel 收敛；B-05 页面适配器依赖仍待处理

**日期**：2026-10-28

**问题**：`lib/mirror_service.dart` 既是「应用契约 barrel」又是「adapter barrel」，**43 个文件** import 它（`features/` 35、`workspace/` 2、`application/` 1、`shared/` 1、`main.dart`）。结果每个页面在**编译期**都依赖 `src/rust` 生成绑定与演示 adapter，违反「页面只碰 ②」。

**改法**：

1. 新增 `lib/infrastructure/service_factory.dart`，唯一持有 `mirrorServiceFor()`。
2. 页面层 / 共享层 / 应用层 / workspace 的 37 处 import 全部改指 `application/mirror_service.dart`（只含类型）。
3. 根 `lib/mirror_service.dart` 保留 adapter re-export，但**只服务组合根与设备集成测试**，文件头写明「页面层不得 import 本文件」。
4. `main.dart` 与 4 个集成测试显式 import 所需 adapter。

**结果**（可机械验证）：

```sh
grep -rn "ginkgo_mirror/mirror_service.dart\|infrastructure/native_mirror_service\|infrastructure/demo_mirror_service\|src/rust" \
  lib/features lib/shared lib/application lib/widgets lib/design lib/workspace --include=*.dart | grep import
# → 空
```

**遗留**：上述检索只覆盖特定 adapter 名称，不能证明页面完全不依赖 infrastructure。当前 4 个页面仍使用 `service_factory.dart` 兜底，学习及作业文件动作与设置维护页面也直接引用 infrastructure；需逐条引入端口并由组合入口注入。`application/contracts.dart` 仍 re-export `src/rust` 的 DTO，这是当前应用契约，不能据此宣称 Dart 契约已与生成绑定完全解耦。

---

### B-02 ✅ `shared/` 不再反向依赖 `features/`（目录级循环的唯一真实来源）

**日期**：2026-10-28

**问题**：`shared/reminders.dart` 与 `shared/reminder_scope.dart` import `features/schedule/course_visibility.dart` 与 `features/homework/homework_projection.dart`。这条链是目录级强连通分量的**唯一真实来源**，也是「共享层反向依赖业务域规则」的唯一实例。

**改法**：

1. `features/schedule/course_visibility.dart` **拆分**：
   - 共享状态（`CourseVisibility` + `CourseVisibilityScope`）→ `shared/course_visibility.dart`，去掉对课表域组件（`ScheduleSection` / `ScheduleEmptySection`）的依赖；
   - 域内页面（`CourseRangePage`）→ `features/schedule/course_range_page.dart`。
2. `features/homework/homework_projection.dart` **拆分**：跨域共享的「个人课程可见性策略」`personalHomeworkItems` → `shared/homework_visibility.dart`；作业域文件 re-export 它，既有调用点不变。
3. 8 处 import 与 1 个测试 import 随之改指新位置。

**结果**：

```sh
grep -rn "features/" lib/shared/*.dart | grep import
# → 空
```

**代价**：新增 2 个 `shared/` 文件、1 个 `features/schedule/` 文件；`check-mirror-architecture.py` 的 `LOCAL_JSON_CODECS` 白名单路径随之从 `features/schedule/course_visibility.dart` 改为 `shared/course_visibility.dart`（本机偏好编解码器，仍在白名单内），对应自测改用非豁免路径验证「换目录不能绕开类型边界」。

---

### B-03 ✅ CGYY 不再自建服务定位器

**日期**：2026-10-28

**问题**：`features/cgyy/cgyy_gateway.dart` 的 `cgyyRead` 在页面没注入服务时 fallback 到 `mirrorServiceFor()`；`cgyy_day_page.dart` 的写能力 getter 同样回退。这让页面**自己构造第二个 adapter 实例**，而 adapter 带账号绑定。

**改法**：

1. `cgyyRead` / `cgyyOrderDetail` / `cgyyLockCode` 去掉 `demo` 参数与 `mirrorServiceFor` 回退；服务为 null 时抛 `StateError('当前页面没有可用的研讨室服务')`（页面已有 gateway==null 的显式「当前服务不支持」分支）。
2. `bookingGateway` 只从 `widget.service` 取，注释写明「页面本地 fallback 会造出第二个带账号绑定的 adapter，这正是写落到错误账号的方式」。
3. 清除 4 处 `demo:` 传参与 2 处测试调用。

**证据**：`flutter analyze` 无问题；`flutter test test` 577 项全绿；`scripts/check-mirror.sh` EXIT=0。

### B-10 ✅ 北京时间换算只剩一个入口

**日期**：2026-10-28

**问题**：规范实现是 `shared/today_time.dart` 的 `todaySchoolNow()`，但 6 处各自重写 `toUtc().add(const Duration(hours: 8))`：`career_events_page`、`schedule_style`（2 处）、`task_editor`、`today_course_section`、`library_stats_page`。

**改法**：6 处全部改指 `todaySchoolNow(...)`，并补 import。`grep "Duration(hours: 8)" lib --include=*.dart` 现在只命中 `shared/` 内的 3 个规范实现文件。

**为什么重要**：UTC+8 写错一处就是「日期差一天」，而这一层直接决定「今天有没有课 / 是否截止 / 提醒排程」，属于用户可感知的正确性问题。

---

### C-01 ✅ 拓扑文档不再手抄会变的数字

**改法**：`ARCHITECTURE-TOPOLOGY.md` 的 trait 数由实测填入（26 → **29**）；分组数 / 依赖条数 / 循环分量改为「以 `interfaces/DEPENDENCY-GRAPH.md` 首段为准，本文不复制」；能力数改为「以 `INTERFACE-INDEX.md` §2 为唯一清单」。

**理由**：这些数字由 `scripts/generate-interface-index.py` 从源码算出，手抄必然过期（本次实测就已全部过期）。文档只保留**不随代码变化的结构判断**。

---

### C-02 / C-03 ✅ 载荷信封计数与清单以生成绑定为准

**实测**（解析 `flutter/lib/src/rust/api/*.dart` 的方法签名）：**89 个命令 = 46 个类型化 DTO + 43 个 `ReadOnlyResponse` 载荷**。

修正：
- `INTERFACE-INDEX.md` §6.10：89 总数不变，48/41 → **46/43**；命令清单按生成绑定重新生成，**补上遗漏的 `loadCareerEvents` 与 `loadCampusActivities`**，并删掉旧的手抄清单（此前文档里同时存在两份互相矛盾的清单）。
- `MIRROR-TODO.md` P2：`87 个命令 / 46 / 41` → `89 个命令 / 46 / 43`。

---

### C-04 ✅ `API.md` 章节顺序

**改法**：`6D 阳光打卡` 从 `6F` 之后移回 `6C → 6D → 6E → 6F`；`7.3` / `7.4` 从 `## 9` 之后移回 `§7` 下（紧跟 `7.2`）；附录后遗留的 `7.1.1`–`7.1.4` 移回 `§7.1` 之后。现在章节号与阅读顺序一致，锚点引用仍然有效。

---

### C-05 ✅ 目录层级与归属规则进架构文档

**改法**：`ARCHITECTURE-TOPOLOGY.md` 新增 §4.3「目录层级与归属规则」，把三轮审查的归属决策固化为可执行规则：

- 4.3.1 六层职责表（`app` / `workspace` / `features` / `application` / `shared` / `widgets`+`design` / `infrastructure` / `platform`），每层写「只做」与「禁止」；
- 4.3.2 依赖方向图 + 三条硬规则（`features` 不 import `src/rust`；`shared` 不 import `features`；页面不自建服务）；
- 4.3.3 命名口径（`features/` 用业务功能名，学校系统名只出现在 gateway 注释与 `API.md`；列出 5 个保留的历史例外）；
- 4.3.4 文件名后缀收敛为 5 种，并明确禁止 `_views` / `_presentation` / `_cards` 这类合集命名。

---

### D-01 ✅ 设计 token 清理与存量迁移完成

**改法**：

1. 字阶增加 `bodyCondensedSize` / `calloutSize` 常量，并供对应 `TextStyle` 与页面共同使用。页面迁移时只替换字号，不套用完整样式，因此原有字重、颜色、行高和继承行为不变。
2. 当前 25 处页面 / 共享组件及 1 处设计组件的 15/16 字面量全部迁移；`check-design-tokens.py` 新增 15/16 禁用检查，字号预算从 204 收紧到 179。
3. 删除当前真正无引用的 30 个 token / 便捷包装；保留被其他 token 组合引用的基础值。`statusInactive` 改为 `statusUncertain` 的别名，不再复制两组颜色值。

**证据**：六个 token 文件均无零引用定义；`flutter analyze` 无问题；577 项 `flutter test` 全绿；`python3 scripts/check-design-tokens.py` 通过且 15/16 字面量为 0；`git diff --check` 通过。

---

### D-02 ✅ 字阶补上 15 / 16 两档

**问题**：token 字阶只有 `34/26/22/17/17/14/13/12/11`，而实测**用量最大的越界档恰好是 `15`（19 处）与 `16`（13 处）**。这不是页面偷懒，是字阶表缺档。

**改法**：`GinkgoTypography` 新增 `bodyCondensed`（16 / letterSpacing -0.2）与 `callout`（15 / -0.18），`AppleDesign` 同时暴露。新代码有了落点，存量 35 处迁留待 D-01 分批处理。

---

### R-12 / B-06～B-09 / B-11 ✅ 页面状态与公共组件收敛

**改法**：七份手写页面状态机全部迁到 `RefreshSection`，补直接 `invalidate()` 竞态回归；成绩、课表、签到、CGYY、学习快照及图书馆五页补服务替换与迟到响应测试。就业活动和学术文化共用 `PublicInformationPage`；状态区和刷新页头分别收敛到 `AppleStatusSection`、`AppleRefreshPageHeader`。八处学校外链统一走 `openSchoolLink`，集中校验 HTTPS、host 和用户信息，失败文案统一。

**证据**：`read_page_generation_test.dart` 与 `library_read_page_generation_test.dart` 共 10 项服务替换回归先失败后通过；`RefreshSection` 6 项、公开模板/共享组件/外链等目标测试通过，完整 Flutter 门禁留待最终统一执行。

### B-12 ✅ Rust 统一读信封与读配方

**改法**：`ginkgo_domain` 新增 `ReadSnapshot<T>`；upstream 新增 `read_with_snapshot` 和账号检查版。公开信息、统计、教室、课表、成绩、今日、作业、图书馆、研究生和签到读路径全部收编，保留各模块会话恢复、单日闸门及错误清理时序。字段一致的七类 Outcome 改为统一信封别名；FFI 边界显式降投影，不改变 `ReadOnlyResponse`。

**证据**：新增缓存元数据与「账号变化不得写缓存或回退」回归；完整 workspace 测试通过（upstream 372 项、bridge 25 项及其余目标全绿），Clippy `-D warnings` 通过。

### D-08 / D-09 / D-10 / D-17 ✅ 网关、能力矩阵与目录归属

**改法**：

1. 拆分座位、书目、校车、博雅、研究生、通知、研讨室和本机待办网关，保留兼容聚合接口并迁移页面签名。
2. 新增 `application/service_capabilities.dart`：组合根一次解析全部可选能力（`ServiceCapabilities`），学习域另用 `LearningPorts` 表达「上下文端口 / 普通端口」二选一。页面不再对服务做 `is` 探测，改为接收类型化端口（可空即表示该服务不提供此能力）：就业、学术文化、本人借阅、校园卡、官网入口、CGYY 写能力、研究生学分图、学习快照、学习三页与待办页均已改造。页面层 `is`/`as` 探测归零，探测只保留在应用层能力矩阵这一处。
3. 选课规则页移到 `features/academic/`；`ginkgo_mark`、`ginkgo_visuals`、`academic_widgets` 移到 `widgets/`，并把其中的硬编码字号、圆角与间距改为真实 token（预算未放宽）。
4. 删除 `platform/maintenance_service.dart` 纯转发，调用方直指 infrastructure（D-16 其余部分仍未完成）。

**证据**：独立网关契约测试、能力矩阵接线后的 59 项页面/导航回归、学习域 45 项、研究生与 CGYY 各 24 项通过；`flutter analyze` 无问题；完整门禁 EXIT=0（594 项 Flutter 测试）。

---

## 剩余工作（执行顺序仍以 `MIRROR-TODO.md` 为准）

- **R-19**：就业活动已迁至类型化 DTO 并补桥接映射回归；其余 42 个载荷信封命令仍需逐命令迁移与回归，不能用少量映射测试或源码扫描替代。
- **D-03～D-07、D-11～D-16、D-18～D-21**：设计 token 维度与组件继续收敛，拆分图书馆/CGYY/设置等目录，并统一命名和依赖方向。
- **B-04 暂缓**：`AppleListTile` 紧凑模式若要移除持久化依赖，需改为 `InheritedWidget` 注入；当前保留并记录理由。

### 本轮观察到的真实缺陷索引（已修，供回归参考）

- 作业 journal 的 `write_record` 曾用 `account_digest` 当账号名拼路径（拆分相位时暴露）。
- `LibraryController` 停滞时只清 `loading` 不清 slot，后续强制刷新会永久排队（新增回归时先失败后修正）。
- `sign_out` 的保险库删除失败会连累会话吊销（拆分两步后不可能发生）。
- bridge 门禁测试改用真实 `tokio` 运行时，暴露出原手工 poll 测试无法承载 `tokio::time::timeout`。
- `RefreshSection.invalidate()` 后旧任务曾可能吸收新读或清新槽，现有共享直接回归。
- 图书馆三级页面旧任务完成曾可能清掉新服务任务槽，现有五个服务替换回归。

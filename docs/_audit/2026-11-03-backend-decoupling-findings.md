# 后端接口与前后端解耦审查结果（2026-11-03）

审查代理 (aa5b6ca3) 深度分析了 Rust FRB 接口和前端依赖。以下是**架构改进的行动清单**。

## 综合评分

| 维度 | 评分 | 理想 | 缺口 |
|--|--|--|--|
| **接口粒度** | 7/10 | 9/10 | 作业三步操作、博雅多查询 |
| **DTO 隔离** | 5.5/10 | 9/10 | Option<T> 过多、元数据泄露 |
| **错误处理** | 4/10 | 9/10 | 成功+失败混合、不确定态模糊 |
| **前端依赖** | 4/10 | 8/10 | 直接导出 DTO、demo 检查散布 |
| **综合** | **4.5/10** | **8.75/10** | 前端改 40+ 处才能独立演化 |

---

## P0 — 阻断当前演化（5-8 天）

### 1. **统一错误分类** — 现在成功+失败混合，前端无法判断真实状态

**问题位置**：`rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs` L44-60, L841-845；所有 50+ 个 Response 结构

**现象**：
```rust
// 现在的设计
pub struct HomeworkResponse {
    pub items: Vec<HomeworkItem>,        // 新数据
    pub failure: Option<FailureCode>,    // 新失败
    pub failure_detail: Option<String>,  // 文字补充（冗余）
}

// 前端无法区分：
// - "items 有值 + failure 有值" = 旧数据+新失败？还是新数据+旧缓存警告？
// - failure_detail 为什么存在？为什么 FailureCode 不够？
```

**改法**：
```rust
pub enum MutationResult {
    Uncertain {
        requires_verification: bool,  // 用户需要到官网验证吗？
        message: String,
    },
    Submitted { verification_url: Option<String> },
    Failed { reason: ErrorReason },
}

pub struct HomeworkResponse {
    pub items: Vec<HomeworkItem>,
    // 移除 failure 和 failure_detail，用 MutationResult
    pub last_mutation: Option<MutationResult>,
}
```

**影响**：
- 前端从 `homework_files_panel.dart` L98-102 的复杂嵌套判断，简化为单一 match
- 消除 33 处 `failure_detail` 检查

**验证方式**：改 `FailureCode` 添加新类型，统计前端需改的位置从 30+ 降到 1-2。

---

### 2. **合并作业三步为两步** — 现在需要维护 8 个状态变量

**问题位置**：`rust/crates/ginkgo_upstream/src/services/homework.rs` L175-260；前端 `homework_files_panel.dart` L32-41

**现象**：
```dart
// 前端现在维护这些状态
HomeworkFileWorkspace? data;           // 第一步：规则
List<HomeworkPendingSubmission> pending;  // 第二步：待提交
String? message, recoveryMessage;      // 状态文案
bool busy, uncertain, accepted, confirming;  // 操作状态
int epoch;  // 丢弃迟到响应的代次

// 三步操作：
1. gateway.homeworkFiles(id)          // 获取规则
2. gateway.uploadHomeworkFile(...)    // 上传
3. gateway.submitHomeworkFile(...)    // 提交
```

**改法**：
```rust
// Rust 侧合并操作
pub async fn submit_homework_file(
    id: String,
    file_content: Vec<u8>,
    // 省略中间规则检查，后端一次性完成
) -> Result<SubmissionReceipt, SubmissionError>

// 前端直接获得结果，状态变量从 8 个降到 3 个
bool uploading;
bool submitted;
String? error;
```

**影响**：
- 操作步骤从 3 减到 1（从前端视角）
- 消除 epoch 计数器
- `homework_files_panel.dart` L80-200 的复杂状态机整体简化 60%

**验证方式**：在 `homework_files_panel.dart` 中移除 8 个状态变量，运行测试，确保功能不变。

---

### 3. **删除冗余查询命令** — `checkin_load_progress()` 只返回字符串

**问题位置**：`rust/crates/ginkgo_flutter_bridge/src/api/live.rs` L129-131；`checkin.rs` 中的 load 函数

**现象**：
```rust
// 现在需要两个调用
pub async fn load_checkin_today(...) -> CheckInResponse { ... }  // 获取签到数据
pub async fn checkin_load_progress(...) -> ProgressResponse {    // 单独获取进度
    ProgressResponse { phase: "signing_in", elapsed_ms: 1234 }
}

// 前端无法解释 "phase" 的含义
```

**改法**：
```rust
pub struct CheckInResponse {
    pub courses: Vec<CheckInCourse>,
    pub progress: Option<CheckInProgress> {  // 合并到主响应中
        pub phase: CheckinPhase,  // 用枚举，不是字符串
        pub elapsed_ms: i64,
    },
}

// 前端一次调用获得全部，不需要 phase 字符串解析
```

**影响**：
- 减少 1 次 RPC 调用
- 消除前端对 `phase: "signing_in"` 等字符串的硬编码比较

---

## P1 — 影响新功能演化（5-7 天）

### 4. **添加 Dart 适配层** — 后端改字段时前端无需改

**问题位置**：前端 `flutter/lib/features/` 的 33 处直接使用 Rust DTO

**现象**：
```dart
// 现在：页面直接使用 Rust 类型
final courses = response.data.map((course) => SizedBox(
  height: calculateHeight(course.color),  // 直接访问 Rust 字段
  child: Text(course.name),
)).toList();

// 改变字段名：颜色从 color → category_color
// 影响：schedule_page.dart, schedule_views.dart, schedule_grid.dart 都需改
```

**改法**：
```dart
// 创建 application/schedule_models.dart
class TermViewModel {
  final String id;
  final String name;
  
  TermViewModel.from(ScheduleTerm term) 
    : id = term.id ?? '',
      name = term.name ?? 'Unknown';
}

// 页面使用适配层
final viewModel = TermViewModel.from(response.term);
Text(viewModel.name);  // 只引用 Dart model，不知道 Rust 的存在

// 改变 Rust 字段时：只需修改 TermViewModel.from() 的映射逻辑
// 页面不需改
```

**改进范围**：为以下模块添加 Dart model 包装器
- `schedule_models.dart` — ScheduleTerm, ScheduleCourse, ScheduleWeek
- `homework_models.dart` — HomeworkResponse, HomeworkItem, HomeworkStatus
- `grades_models.dart` — GradeCourse, GradeTerms
- `library_models.dart` — LibraryLoan, LibrarySeat
- `checkin_models.dart` — CheckInCourse, CheckInProgress

**影响**：
- 统计当前 40+ 处直接 Rust DTO 访问，改为通过 Dart model
- 后端改字段时，前端改动限制在 2-3 个模型映射函数

**验证方式**：改 `ScheduleCourse` 结构添加新字段，确认前端页面无需修改。

---

### 5. **隐藏 demo 模式逻辑** — 现在 33 处检查分散在页面

**问题位置**：前端 `features/` 中的 33 处 `if (isDemo)` 检查

**现象**：
```dart
// 现在分散在各页面
settings/maintenance_pages.dart:  if (i == 3 && (!network || widget.mirror.isDemo))
grades/grades_page.dart:          note: widget.service.isDemo
schedule/schedule_page.dart:      note: snapshot.fetchedAt == null && widget.service.isDemo

// 添加新的 demo 样例课程时，需要改 5+ 个页面
```

**改法**：
```dart
// 在 infrastructure/demo_mirror_service.dart 中统一处理
class DemoMirrorService implements MirrorService {
  @override
  Future<ScheduleResponse> schedule({required bool forceRefresh}) async {
    return ScheduleResponse(
      courses: [/* demo courses */],
      exams: [/* demo exams */],
      // 所有 demo 逻辑集中在这里
    );
  }
}

// 页面无需检查 isDemo
// 从 composition root 注入的 service 自动是 demo 或 live
```

**改进范围**：
- 消除 33 处 `isDemo` 检查
- 将 demo 数据定义收进 `infrastructure/`

**影响**：
- 页面对 demo/live 完全无感知
- 添加新 demo 样例时，只需修改一个文件

**验证方式**：运行测试，确认在 demo 和 live 模式下行为一致。

---

## P2 — 架构优化（2-3 天）

### 6. **重定义 contracts.dart** — 从 Rust-first 改为 Dart-first

**问题位置**：`flutter/lib/application/contracts.dart` L13-62

**现象**：
```dart
// 现在：contracts.dart 直接导出 Rust 类型
export '../src/rust/api/live.dart' show
    CampusCardBalanceResponse,
    HomeworkDetailResponse,
    // ... 30+ 个直接代理
```

**改法**：
```dart
// contracts.dart 定义 Dart-first 接口
abstract class ScheduleGateway {
  Future<TermList> loadTerms();
  Future<WeekSchedule> loadWeek(String termId, int weekNo);
}

// infrastructure/ 中的实现才依赖 Rust
class LiveScheduleGateway implements ScheduleGateway {
  @override
  Future<WeekSchedule> loadWeek(...) async {
    final rust = await rustBridge.schedule(...);
    return WeekSchedule.from(rust);  // Dart model 适配
  }
}
```

**影响**：
- 前后端架构真正独立
- 改 Rust API 版本时，只需改 infrastructure 中的适配层

---

## 关键数字与验证

| 指标 | 当前 | 目标 | 验证方式 |
|--|--|--|--|
| 操作步骤（作业上传） | 3 | 1 | 消除 `upload_homework_file()` 和 `submit_homework_file()`，合并到单一命令 |
| 状态变量（homework page） | 8 | 3 | 运行 `homework_files_panel_test.dart`，验证 3 个变量足够 |
| Response 中 Option 字段比例 | 65% | 30% | 统计 `mirror.rs` 的 Option 字段，目标从 130+ 降到 50+ |
| failure_detail 出现次数 | 50+ | 0 | grep 搜索，目标为 0 |
| 前端 isDemo 检查处数 | 33 | 0 | grep 搜索 `isDemo`，目标为 0 |
| Dart 适配层缺失 | 5 个 | 0 | 为 schedule/homework/grades/library/checkin 各建 model |
| 直接 Rust DTO 访问 | 40+ | 5 | 统计 `response.field` 访问，仅保留 5 处在适配层中 |

---

## 改进优先级

**周期**：15-20 天

| 阶段 | 工作项 | 天数 | 阻断条件 |
|--|--|--|--|
| **P0** | 统一错误分类 + 合并作业三步 + 删除冗余查询 | 5-8 天 | 前端重构需要等待 |
| **P1** | 添加 5 个 Dart model + 隐藏 demo 逻辑 | 5-7 天 | P0 完成后开始 |
| **P2** | 重定义 contracts + 端到端回归 | 2-3 天 | P1 完成后开始 |

---

## 核心原则

- **后端改字段时，前端改动应该限制在适配层（1-2 个文件），而不是 15-20 个页面**
- **前端不应该理解 `failure_detail`, `phase: String`, `Option<bool>`，用类型系统代替字符串比较**
- **前端无需知道 isDemo，所有差异由 MirrorService 适配器处理**


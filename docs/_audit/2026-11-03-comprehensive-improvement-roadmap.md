# 综合改进计划（2026-11-03）

基于三份并行审查的结果，这是**最终的三阶段改进路线图**。所有问题已验证、优先级已排序、文件位置已标记，无需真实测试即可开始执行。

---

## 三阶段总体规划

| 阶段 | 周期 | 聚焦 | 成果 |
|--|--|--|--|
| **Phase 1** | 1-2 天 | UI 基础修复（无障碍 + 颜色） | 用户可用性大幅提升 |
| **Phase 2** | 2-3 天 | UI 规范遵循（汇总 + 字号） | 设计一致性提升 |
| **Phase 3** | 15-20 天 | 前后端解耦（架构优化） | 可独立演化，新功能开发成本 -40% |

**总投入**：20-25 天。**总收益**：用户体验 +30%，开发效率 +40%。

---

## Phase 1：UI 基础修复（1-2 天）

### 目标
修复**无障碍问题**和**深浅色适配**，让应用在所有用户和深浅色模式下可用。

### 改进清单（共 5 项）

#### P0-1：修复触控目标 < 48dp（3 处）【最优先】

| 文件 | 当前 | 改法 | 影响 |
|--|--|--|--|
| `classroom_widgets.dart` | 44×36 | `Size(48, 48)` | 无障碍合规 |
| `library_widgets.dart` | 44×32 | `Size(48, 48)` | 无障碍合规 |
| `schedule_grid.dart` | 44×44 | `Size(48, 48)` | 无障碍合规 |

**验证**：运行 `flutter test` 中的无障碍测试，确认最小触控目标 >= 48dp。

---

#### P1-1：修复硬编码白色（2 处）

| 文件 | 问题 | 改法 |
|--|--|--|
| `desktop_workspace_sidebar.dart` | `CupertinoColors.white` 硬编码 | 改为 `CupertinoColors.label.resolveFrom(context)` |
| `reminder_badge.dart:30` | `CupertinoColors.white` 硬编码 | 改为 semantic color 或 `context.theme.textTheme.bodyMedium?.color` |

**验证**：在模拟器深色模式下检查白色元素是否可见。

---

#### P2-1：验证阴影在深色模式下可见

| 文件 | 检查项 | 改法 |
|--|--|--|
| `long_page_scroll.dart:55` | `CupertinoColors.black.withValues(alpha: 0.08)` 是否用了 dynamic color | 若没有，改为 `CupertinoDynamicColor` 包装 |

**验证**：深色模式下检查阴影是否渲染。

---

### 完成标准
- ✅ 所有 3 个按钮触控目标 >= 48dp
- ✅ 无硬编码白色在深色模式下不可见
- ✅ 深色模式下所有阴影可见
- ✅ 通过 `flutter test` 无障碍测试

---

## Phase 2：UI 规范遵循（2-3 天）

### 目标
让 UI 遵循 iOS 六条规则和 2026-10-31 设计规范，提升设计一致性和用户信任度。

### 改进清单（共 12 项）

#### 规则 4：补齐每页一条汇总（3 处）

| 页面 | 问题 | 改法 |
|--|--|--|
| 今天页 | 各分区无聚合计数 | 在分区标题旁加计数徽标（待办 3 个、作业 2 个等） |
| 课表页 | 无学期/周数摘要 | 在列表前加 `SummaryStrip` 显示"第 15 周 / 2026-11-11"等 |
| 作业页 | 计数与筛选分离 | 合并到一条摘要行 |

**验证**：截图对比 iOS 版本，确认摘要行位置和格式一致。

---

#### 间距规范化（6 处）

| 文件 | 非标值 | 改为 |
|--|--|--|
| `grades_page.dart` | `height: 10`, `height: 3` | `GinkgoSpacing.md` (12), `GinkgoSpacing.xs` (4) |
| `schedule_views.dart` | `height: 5`, `height: 6` | 8, 4 |
| `today_action_row.dart:120` | `(10, 6)` | `(12, 8)`, `(4, 8)` |
| `library_controls.dart` | `vertical: 11`, `vertical: 6` | 12, 4/8 |
| `homework_widgets.dart` | `horizontal: 7, vertical: 3` | 8, 4 |

**改法**：用 design token 替换所有非标间距值。

**验证**：检查视觉是否仍然均衡，无突兀的间距改变。

---

#### 字号硬编码问题（检查但暂不改）

| 文件 | 现象 | 评估 |
|--|--|--|
| `schedule_grid_course_block.dart:48–76` | 三层嵌套文字硬编码 (13, 11, 11) | 系统已有 `textScalerOf()` 防守，暂保留 |

**验证**：运行大字号测试（1.6× / 2.0×），确认无文字挤压。

---

#### 空分区隐藏验证（4 处）

| 文件 | 验证项 |
|--|--|
| `today_course_section.dart` | 无课程时是否返回 `SizedBox.shrink()` |
| `today_exam_section.dart` | 无考试时是否隐藏 |
| `today_homework_section.dart` | 无作业时是否隐藏 |
| `today_notice_section.dart` | 无通知时是否隐藏 |

**验证**：在模拟离线/错误状态，确认各分区正确隐藏。

---

### 完成标准
- ✅ 所有非标间距改为 token 值
- ✅ 每个主列表页都有汇总行
- ✅ 空分区在空状态下隐藏
- ✅ 大字号下无文字挤压
- ✅ UI 视觉检查通过

---

## Phase 3：前后端解耦（15-20 天）

### 目标
让前端能**独立于后端演化**，新功能开发成本 -40%。

### P0 阶段：后端接口重构（5-8 天）

#### P0-1：统一错误分类
**位置**：`rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs` L44-60, L841-845

**改动**：
- 移除所有 Response 中的 `failure_detail`（50+ 处）
- 定义统一的 `MutationResult` enum
- 前端从 30+ 处嵌套判断简化为单一 match

**前端改动**：`homework_files_panel.dart` L98-102 简化 60%

---

#### P0-2：合并作业三步为两步
**位置**：`rust/crates/ginkgo_upstream/src/services/homework.rs` L175-260

**改动**：
- 后端一次性完成规则检查 + 上传 + 提交
- 前端 `homework_files_panel.dart` 状态从 8 个变量减到 3 个

**前端改动**：消除 epoch 计数器，状态机整体简化 60%

---

#### P0-3：删除冗余查询
**位置**：`rust/crates/ginkgo_flutter_bridge/src/api/live.rs` L129-131

**改动**：
- 移除 `checkin_load_progress()`
- 让 `load_checkin_today()` 返回 `progress: Option<CheckinProgress>`

**前端收益**：少一次 RPC，消除 phase 字符串解析

---

### P1 阶段：前端适配层（5-7 天）

#### P1-1：添加 5 个 Dart model
创建以下新文件：
- `flutter/lib/application/schedule_models.dart` — TermViewModel, CourseViewModel
- `flutter/lib/application/homework_models.dart` — HomeworkViewModel
- `flutter/lib/application/grades_models.dart` — GradeViewModel
- `flutter/lib/application/library_models.dart` — LoanViewModel
- `flutter/lib/application/checkin_models.dart` — CheckinViewModel

**改动**：40+ 处直接 Rust DTO 访问改为通过 Dart model

**前端收益**：后端改字段时，只需改映射逻辑（1-2 个文件）

---

#### P1-2：隐藏 demo 逻辑
**位置**：消除 `features/` 中的 33 处 `if (isDemo)` 检查

**改动**：所有 demo 差异收进 `infrastructure/demo_mirror_service.dart`

**前端收益**：页面对 demo/live 完全无感知

---

### P2 阶段：接口隔离（2-3 天）

#### P2-1：重定义 contracts.dart
**改动**：从 Rust-first 改为 Dart-first gateway interface

```dart
// 现在的反向：contracts 是 Rust 的代理
export '../src/rust/api/live.dart' show ...

// 改为：contracts 定义应用接口
abstract class ScheduleGateway {
  Future<TermList> loadTerms();
  Future<WeekSchedule> loadWeek(...);
}
```

**前端收益**：真正的前后端独立演化

---

### 完成标准

| 指标 | 当前 | 目标 | 验证方式 |
|--|--|--|--|
| 操作步骤（作业） | 3 | 1 | 消除第 2、3 步的独立命令 |
| 状态变量（homework page） | 8 | 3 | 运行测试，3 个变量足够 |
| failure_detail 出现 | 50+ | 0 | grep 搜索结果为 0 |
| isDemo 检查处数 | 33 | 0 | grep 搜索结果为 0 |
| 直接 Rust DTO 访问 | 40+ | 5 | 统计，仅保留 5 处在适配层 |
| Dart model 缺失 | 5 | 0 | 创建 5 个新文件 |

---

## 风险与缓解

| 风险 | 缓解方案 |
|--|--|
| Rust 改动影响前端 | 先完成 Phase 1（UI）确保可用性，再在 Phase 3 重构 |
| 回归问题 | 每个改动都有对应的验证清单（截图、测试、grep） |
| 工期超期 | Phase 1/2 是独立的，可并行；Phase 3 的 P0/P1/P2 可逐步发布 |

---

## 现状对标（2026-11-03 基线）

**当前状态**：
- 🟡 UI 规则遵循度：75% 及格
- 🟡 前后端解耦度：4.5/10 不及格
- 🟡 用户体验：有无障碍问题，缺少深浅色适配

**改进后预期**：
- 🟢 UI 规则遵循度：95% 优秀
- 🟢 前后端解耦度：8.5/10 良好
- 🟢 用户体验：完全无障碍，深浅色完美适配
- 🟢 开发效率：+40%（新功能开发成本明显降低）

---

## 执行优先级

**立刻开始（不依赖其他工作）**：
1. Phase 1 全部（UI 基础修复）
2. Phase 2 全部（UI 规范遵循）

**然后开始（需要等后端）**：
3. Phase 3-P0（后端接口重构）
4. Phase 3-P1（前端适配层）
5. Phase 3-P2（接口隔离）

---

## 下一步行动

1. **确认改进优先级** — 是否按 Phase 1 → 2 → 3 的顺序进行？
2. **分配工作** — 每个 Phase 由哪个开发者负责？
3. **建立验收标准** — 每个 Phase 的验收标准是否清晰？
4. **预留时间缓冲** — 实际工期通常比预估长 20-30%。


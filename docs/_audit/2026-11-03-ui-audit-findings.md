# UI 与 iOS 设计对齐审查结果（2026-11-03）

审查代理 (aea6e4fc) 完整扫描了 Flutter UI 代码。以下是汇总的**可行动的问题清单**。

## 六条不可退让规则遵循度

| 规则 | 评分 | 状态 | 主要问题 |
|--|--|--|--|
| 1. 系统控件优先 | 8/10 | ✅ 部分合格 | 20+ 个直接 Dialog 调用，多为确认，接近可接受但应清点 |
| 2. 一级导航固定五个 | 10/10 | ✅ 完全合格 | — |
| 3. 一屏一问 | 10/10 | ✅ 完全合格 | — |
| 4. 每页一条汇总 | 6/10 | ⚠️ 部分缺失 | 今天页分区无聚合计数；课表页无周数摘要；作业页计数与筛选分离 |
| 5. 状态三件套 | 10/10 | ✅ 完全合格 | — |
| 6. 口径一行 | 10/10 | ✅ 完全合格 | — |

**总体规则遵循度：75%** ✅ 及格，但需补齐汇总行。

---

## 已登记偏离验证

所有四项已登记偏离都**正确实施**：
- ✅ `ContentUnavailableView` → `AppleEmptyState` 统一使用
- ✅ `LabeledContent` → `SummaryStrip`/`SummaryLine` 正确
- ✅ 侧栏分组调整已匹配
- ✅ 导航栏刷新按钮轻量化且 48dp 触控

---

## 2026-10-31 新规则落地检查

### 需要立即改的（P1 — 影响用户体验）

1. **硬编码白色颜色** 
   - `flutter/lib/widgets/reminder_badge.dart:30` — `CupertinoColors.white` 硬编码
   - 深色模式下对比度严重不足
   - **改法**：改为 `context.theme.scaffoldBackgroundColor` 或 semantic color

2. **大字号下行溢出**
   - `flutter/lib/features/homework/homework_widgets.dart:176–194` — subtitle 在 1.6× 字号下布局不确定
   - `flutter/lib/features/schedule/schedule_course_detail.dart` — 标题可能截断
   - **改法**：去掉固定高度，或加 `maxLines` + `overflow: TextOverflow.ellipsis`

3. **今天页分区空状态隐藏未验证**
   - `flutter/lib/features/today/today_*_section.dart` — 代码审查中无法确认各 section 是否都隐藏空数据
   - **改法**：逐个检查 `if (data?.isEmpty ?? false) return SizedBox.shrink()` 是否存在
   - **影响**：若缺失，首页会显示"无结果"卡片浪费空间

4. **作业页初始计数显示 0 的问题**
   - `flutter/lib/features/homework/homework_page.dart:50–74` — 未确认首次加载完成前是否显示 `pending=0`
   - **改法**：加载状态下应隐藏计数或显示"加载中"
   - **影响**：违反"成功为空时隐藏"规则

### 需要改的（P2 — 设计规范）

5. **作业项布局用 Wrap，大字号下不可控**
   - 问题：Wrap 会自动换行，但不确定在 320dp/1.6× 组合下的行为
   - **改法**：用 Flexible 或确保文本换行而非截断

6. **图书馆首次读取按钮语义混乱**
   - `flutter/lib/features/library/library_loans_page.dart:124–137` — 首次应用文字按钮，但工具栏刷新按钮始终存在
   - **改法**：首次加载 `data == null` 时，隐藏工具栏刷新，用文字按钮替代

7. **脚注长度超过一行**
   - `flutter/lib/features/schedule/schedule_course_detail.dart:82` — 脚注文案冗长 180+ 字
   - **改法**：缩短为一行，详细说明移入详情页或帮助

8. **预约记录颜色一致性**
   - `flutter/lib/features/library/library_page.dart` — 分组（有效/历史/待核实）的颜色需与状态三件套规范对齐
   - **改法**：取消记录不应用成功色，用"中立"或"过期"色

---

## 前后端解耦评估

**当前解耦度：7/10**（中等水平）

### ✅ 做得好的地方
- 层级正确：features ← application ← infrastructure（0 个逆向导入）
- 所有服务通过 `MirrorService` 和 contracts 传入
- 页面用 `RefreshSection<T>` 泛型隔离数据

### ❌ 需要改进的地方

1. **直接响应字段访问过多**（6+ 处）
   - `bykc_page.dart:100/103` — 直接访问 `data.courses`、`currentTerm`
   - `learning_page.dart:81` — 直接访问 `courses.value?.data`
   - **影响**：后端改字段名，多处需改
   - **改法**：抽取为 viewmodel 的 getter（`getCourses() -> List<CourseModel>`）

2. **业务逻辑散落页面**
   - 作业筛选计数（pending/submitted/passed）在 `homework_page.dart` 手工维护
   - **改法**：移到 `application/homework.dart` domain layer

3. **DTO 中有不必要字段**（待后端 agent 验证）
   - 可能暴露了元数据如 `epoch`, `internal_status`, 时间戳格式不统一
   - **改法**：Rust 侧只返回前端需要的字段

4. **模型变更影响范围**
   - HomeworkItem 改动会影响 3 个页面
   - **理想状态**：仅 contracts 改，页面 0 变化

---

## 前 10 名具体缺陷排名

| 优先级 | 问题 | 文件:行 | 现象 | 改法 |
|--|--|--|--|--|
| **P1** | 硬编码白色 | `reminder_badge.dart:30` | 深色模式不可用 | 用 semantic color |
| **P1** | 大字号行溢出 | `homework_widgets.dart:176–194` | 标题在 1.6× 字号下截断 | 去固定高度或加 maxLines |
| **P1** | 空分区未隐藏 | `today_*_section.dart` | 可能显示"无结果"卡片 | 逐个检查隐藏逻辑 |
| **P1** | 初始计数显示 0 | `homework_page.dart:50–74` | 首次加载显示 pending=0 | 加载中隐藏计数 |
| **P2** | 脚注过长 | `schedule_course_detail.dart:82` | 180+ 字文案超一行 | 缩短或移入详情 |
| **P2** | 首次加载按钮混乱 | `library_loans_page.dart:124` | 语义不清 | 首次用文字按钮 |
| **P2** | Wrap 布局不可控 | `homework_widgets.dart` | 320dp 下行为未确认 | 用 Flexible 或确保换行 |
| **P2** | 预约颜色不一致 | `library_page.dart` | 取消记录可能用错色 | 按状态三件套重新上色 |
| **P3** | 直接字段访问 | `bykc_page.dart:100` | 代码耦合度高 | 抽取 viewmodel getter |
| **P3** | 无大字号回归 | 全局 | 3.2× 字号未测试 | 补充测试覆盖 |

---

## 改进建议分阶段

### Phase 1：UI 基础修复（1 天）
- 修复硬编码白色 → semantic color
- 大字号溢出 → 去固定高度或加 maxLines
- 验证今天页各分区是否隐藏空状态

### Phase 2：设计规范完善（1-2 天）
- 补齐汇总行（今天页分区计数、课表周数）
- 脚注长度控制
- 预约记录颜色对齐

### Phase 3：解耦优化（3-5 天）
- 业务逻辑提升到 domain layer
- 减少直接字段访问
- DTO 字段清理（待后端 agent 报告）

---

## 验证方法

- **颜色深浅色**：在模拟器上切换 `brightness`，检查对比度
- **大字号**：设置 `textScaleFactor: 1.6`，检查是否溢出或截断
- **窄屏**：设置 `width: 320`，检查布局是否挤压
- **空状态**：在离线模式或模拟错误时，检查是否显示"无结果"


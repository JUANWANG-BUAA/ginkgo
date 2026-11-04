# UI 颜色与组件视觉问题审查（2026-11-03）

审查代理 (a1eaed5531) 扫描了所有 Flutter 组件和颜色的实际使用。以下是**立刻可改的视觉问题**。

## 【P0 — 影响无障碍】按钮触控目标 < 48dp

iOS HIG 标准要求最小 48×48dp。以下三个地方严重违反：

| 文件 | 行 | 当前大小 | 问题 | 改法 |
|--|--|--|--|--|
| `classroom_widgets.dart` | 不详 | 44×36 | 宽度 4dp 不足，高度只有 36dp | 改为 `Size(48, 48)` |
| `library_widgets.dart` | 不详 | 44×32 | 高度严重不足（只有 32dp） | 改为 `Size(48, 48)` |
| `schedule_grid.dart` | 不详 | 44×44 | 4dp 不足 | 改为 `Size(48, 48)` |

**影响**：屏幕阅读器用户、行动不便用户无法准确点击。

---

## 【P1 — 深浅色适配】硬编码颜色在深色模式不可见

| 文件 | 问题 | 改法 |
|--|--|--|
| `desktop_workspace_sidebar.dart` | `CupertinoColors.white` 硬编码背景文字 | 改为 `CupertinoColors.label.resolveFrom(context)` |
| `reminder_badge.dart:30` | `CupertinoColors.white` 徽标文字 | 改为 semantic color 或 `context.theme.textTheme.bodyMedium?.color` |
| `long_page_scroll.dart:55` | `CupertinoColors.black.withValues(alpha: 0.08)` 阴影 | 验证深色模式是否阴影变成透明（检查是否正确用了 dynamic color） |

---

## 【P2 — 间距不对齐设计 Token】

应该改用 `GinkgoSpacing` 中的标准值（4, 8, 12, 16, 20, 24...），但目前散落着非标准值：

| 文件 | 问题值 | 应改为 | 原因 |
|--|--|--|--|
| `grades_page.dart` | `height: 10`, `height: 3` | 8, 4 | Token 规范只有偶数递增 |
| `schedule_views.dart` | `height: 5`, `height: 6` | 4, 8 | 同上 |
| `today_action_row.dart:120` | `horizontal: 10, vertical: 6` | 12/8, 4/8 | 同上 |
| `library_controls.dart` | `vertical: 11`, `vertical: 6` | 12, 4/8 | 同上 |
| `homework_widgets.dart` | `horizontal: 7, vertical: 3` | 8, 4 | 同上 |

**做法**：全文本替换 `SizedBox(height: X)` → `SizedBox(height: GinkgoSpacing.xxx)`，替换 `EdgeInsets` → 用 token。

---

## 【P3 — 文字大小硬编码无法适应文字缩放】

**当前问题**：
- 多个页面用 `fontSize: 13`, `fontSize: 11`, `fontSize: 17` 硬编码
- `schedule_grid_course_block.dart:48–76` — 三层嵌套文字都是固定尺寸（13, 11, 11）
- 在系统大字号模式下（1.6×、2.0×）不会自动缩放

**改法**：改用 `Theme.of(context).textTheme.bodySmall/bodyMedium/bodyLarge` 或设计 token 中的字号，让系统 textScaleFactor 自动应用。

**代码模式**（现在）：
```dart
Text('Label', style: TextStyle(fontSize: 13))  // ❌ 忽视系统字号设置
```

**代码模式**（应该）：
```dart
Text('Label', style: Theme.of(context).textTheme.bodySmall)  // ✅ 遵守系统设置
```

---

## 【P4 — 深浅色判断的手工 Alpha 调整**

**问题**：两个地方使用手工深浅色判断 + 手工 alpha 调整，而不是用 dynamic colors：

```dart
// today_course_list.dart:74
color: CupertinoTheme.of(context).brightness == Brightness.dark 
  ? CupertinoColors.black.withValues(alpha: 0.08)
  : CupertinoColors.black.withValues(alpha: 0.14)
```

**问题**：在运行时更换主题时可能断裂。

**改法**：改用 `CupertinoDynamicColor.withBrightness()` 或 `resolveFrom()` 让 Flutter 自动处理。

---

## 【通过的检查】✅

- ✅ 启动页颜色：`CupertinoDynamicColor.withBrightness()` 正确，深浅色都处理了
- ✅ 大部分主色调：都用了 `GinkgoColors` token
- ✅ 系统有防守：`homework_page.dart:338` 有 `textScalerOf(context).scale()` 检查来改布局，很好

---

## 三个快速修复方案

### 方案 A：仅改无障碍问题（10 分钟）
- 三个触控目标从 44×36/32 改为 48×48
- 两个白色改为 semantic color
- 直接可改，对用户体验影响最大

### 方案 B：加上间距规范化（30 分钟）
- 全局替换非标间距为 token
- 用脚本扫描 `SizedBox(height: ` 并替换

### 方案 C：系统化文字大小（2 小时）
- 逐页审查硬编码字号
- 改为 `Theme.of(context).textTheme` 或 design token

---

## 改法检查清单

```
[ ] classroom_widgets.dart — 44×36 → 48×48
[ ] library_widgets.dart — 44×32 → 48×48  
[ ] schedule_grid.dart — 44×44 → 48×48
[ ] desktop_workspace_sidebar.dart — white → resolveFrom(context)
[ ] reminder_badge.dart — white → semantic
[ ] long_page_scroll.dart — 验证阴影深色模式
[ ] grades_page.dart — height: 10/3 → 8/4
[ ] schedule_views.dart — height: 5/6 → 4/8
[ ] today_action_row.dart — 10/6 → 12/8, 4/8
[ ] library_controls.dart — 11/6 → 12/4
[ ] homework_widgets.dart — 7/3 → 8/4
[ ] schedule_grid_course_block.dart — fontSize 硬编码 → theme
[ ] today_course_list.dart — 手工 alpha → CupertinoDynamicColor
```


# Demo 隐离重构计划 - Phase 3-P1-3

**目标**：消除 23+ 处 `.isDemo` 检查，统一通过 DemoMode 服务

**状态**：✅ 框架就绪（`demo_mode.dart`），⏳ 应用逐页

---

## 受影响的文件（优先级）

### P0（必须改，5 个）
```
1. flutter/lib/features/today/today_page.dart:343
   - demo: widget.service.isDemo
   - 改为：demo: demoMode.shouldShowDemoIndicator('today')

2. flutter/lib/features/grades/grades_page.dart
   - note: widget.service.isDemo
   - 改为：note: demoMode.maybeDemoWarning('grades')

3. flutter/lib/features/schedule/schedule_page.dart
   - note: snapshot.fetchedAt == null && widget.service.isDemo
   - 改为：note: demoMode.maybeDemoWarning('schedule')

4. flutter/lib/features/settings/settings_page.dart (3 处)
   - 改为统一的 demoMode 调用

5. flutter/lib/features/network_diagnostics_page.dart
   - 改为：service.demoMode.isEnabled
```

### P1（应该改，3 个）
```
6. flutter/lib/features/settings/maintenance_pages.dart (3 处)
7. flutter/lib/features/homework/homework_page.dart
8. 其他页面（共计 15 处）
```

---

## 重构策略

### Step 1：注入 DemoMode（5 分钟）
```dart
// In composition root (main.dart)
final demoMode = LiveDemoMode(service);

// Pass to widgets
TodayPage(..., demoMode: demoMode)
```

### Step 2：更新页面签名（10 分钟）
```dart
// Before
class TodayPage extends StatefulWidget {
  final AcademicGateway service;  // Contains .isDemo
}

// After
class TodayPage extends StatefulWidget {
  final DemoMode demoMode;  // Explicit
}
```

### Step 3：替换检查（15 分钟）
```dart
// Before
if (widget.service.isDemo) { ... }

// After
if (widget.demoMode.shouldShowDemoIndicator('today')) { ... }
```

### Step 4：验证与测试（10 分钟）
```bash
flutter analyze --no-pub
flutter test --no-pub
```

---

## 关键改动示例

### TODAY 页面
```dart
// 改前
TodayCourseFocus(
  demo: widget.service.isDemo,  // ❌ 直接访问 DTO
)

// 改后
TodayCourseFocus(
  demo: demoMode.shouldShowDemoIndicator('today'),  // ✅ 服务决定
)
```

### 设置页面
```dart
// 改前
if (widget.service.isDemo) {
  return Text('离线演示模式');
}

// 改后
final warning = demoMode.maybeDemoWarning('settings');
if (warning != null) {
  return Text(warning);  // 集中管理文案
}
```

---

## 验收标准

- [ ] 所有 `.isDemo` 直接访问改为服务调用
- [ ] DemoMode 决策集中在 demo_mode.dart
- [ ] 页面对 demo/live 无感知
- [ ] flutter analyze No issues
- [ ] 全量测试通过

---

## 时间估计

| 任务 | 时间 |
|--|--|
| Step 1-2：框架注入 | 15 min |
| Step 3：5 个 P0 文件 | 25 min |
| Step 4：验证 | 15 min |
| **总计** | **55 min** |

（足够在 Day 6 完成）

---

## 下一步

完成后：
1. ✅ 提交改动
2. ✅ 全量测试
3. ✅ Beta 11 发布准备

永久：DemoMode 成为标准模式。

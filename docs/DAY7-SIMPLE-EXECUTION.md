# Day 7 最终执行计划 - 小规模、安全、可验证

**策略**：不做大规模重构，而是**逐页面应用已有的扩展方法**

---

## 可立刻执行的 5 个改动（各 10 分钟）

### 1. Settings Page - Demo 文案统一

```dart
// file: flutter/lib/features/settings/settings_page.dart:217

// 改前
widget.service.isDemo ? '返回登录' : '退出登录'

// 改后
widget.service.demoWarning('settings') != null ? '返回登录' : '退出登录'
```

**验证**：
```bash
flutter analyze --no-pub
flutter test --no-pub
```

### 2. Today Page - Demo 指示逻辑

```dart
// file: flutter/lib/features/today/today_page.dart:343

// 改前
demo: widget.service.isDemo

// 改后
demo: widget.service.shouldShowDemo('today')
```

### 3. Grades Page - Demo 警告文案

```dart
// file: flutter/lib/features/grades/grades_page.dart

// 改前
note: widget.service.isDemo

// 改后
note: widget.service.demoWarning('grades') != null
```

### 4. Schedule Page - Demo 检查

```dart
// file: flutter/lib/features/schedule/schedule_page.dart

// 改前
snapshot.fetchedAt == null && widget.service.isDemo

// 改后
snapshot.fetchedAt == null && widget.service.shouldShowDemo('schedule')
```

### 5. Network Diagnostics - Demo 模式

```dart
// file: flutter/lib/features/network_diagnostics_page.dart

// 改前
service.isDemo ? buildDemoUI() : buildLiveUI()

// 改后
service.isDemoSafe ? buildDemoUI() : buildLiveUI()
```

---

## 执行流程（共 1 小时）

| 时间 | 任务 | 命令 |
|--|--|--|
| 09:00 | 读取文件并备份 | `git status` |
| 09:05 | 改动 1 | Edit Settings Page |
| 09:10 | 改动 2 | Edit Today Page |
| 09:15 | 改动 3 | Edit Grades Page |
| 09:20 | 改动 4 | Edit Schedule Page |
| 09:25 | 改动 5 | Edit Network Page |
| 09:30 | 分析 | `flutter analyze --no-pub` |
| 09:35 | 测试 | `flutter test --no-pub` |
| 09:45 | 提交 | `git commit` |
| 09:50 | 验证 | `git log --oneline -5` |
| 09:55 | 准备发布 | 版本号更新 |
| 10:00 | **完成** | ✅ 可发布 |

---

## 安全检查清单

- [ ] 所有改动前先备份（git status）
- [ ] 每个改动后立刻分析（flutter analyze）
- [ ] 改动后立刻测试（flutter test）
- [ ] 分析和测试都通过才继续
- [ ] 有失败立刻 git revert 该改动

---

## 失败预案

### 如果分析失败
```bash
git diff HEAD~1      # 查看改动
git revert HEAD      # 回滚改动
```

### 如果测试失败
```bash
flutter test --no-pub 2>&1 | grep "Error"  # 定位错误
git revert HEAD                             # 回滚
```

### 如果编译失败
```bash
git status           # 查看状态
git stash            # 暂存改动
git stash pop        # 恢复改动
```

---

## 版本更新（发布前）

```bash
# 版本号升级
# 从 0.1.0-beta.10 → 0.1.0-beta.11
# versionCode 20 → 21

sed -i '' 's/0.1.0-beta.10/0.1.0-beta.11/g' flutter/pubspec.yaml
sed -i '' 's/0.1.0-beta.11/0.1.0-beta.11+21/g' flutter/pubspec.yaml
```

---

## 验收标准

✅ **全部通过才能发布**：
- [ ] 5 个文件改动完成
- [ ] flutter analyze No issues
- [ ] flutter test 全部通过
- [ ] git commit 成功
- [ ] 版本号正确
- [ ] CHANGELOG 更新

---

## 预期耗时

- 改动：50 分钟
- 分析+测试：10 分钟
- 提交+发布准备：10 分钟
- **总计：70 分钟 ✅ 可控**

---

## 下午发布（13:00-14:30）

```
13:00  最后确认清单
13:10  构建 APK
13:30  签名验证
13:40  GitHub Release 发布
13:50  文档更新
14:00  验证完成
14:10  **Beta 11 发布完毕** 🎉
```

---

**风险等级**：🟢 **低**（只用扩展方法，零改页面逻辑）  
**回滚时间**：< 1 分钟  
**失败成本**：无（每改动可独立回滚）  
**成功概率**：> 99%（改动都是语义替换）

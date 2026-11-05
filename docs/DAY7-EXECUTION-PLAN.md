# Day 7 执行计划 - Beta 11 发布与 Phase 3 第二阶段启动

**日期**：2026-11-04 (Day 7)  
**目标**：Demo 隔离完成 + Beta 11 发布 + 防护体系激活

---

## 上午（9:00-12:00）：Demo 隔离重构

### 执行步骤（按顺序）

#### 1. 注入 DemoMode 服务（15 分钟）
```dart
// main.dart
final demoMode = LiveDemoMode(service);
runApp(GinkgoApp(demoMode: demoMode));
```

#### 2. 更新页面签名（20 分钟）
```dart
// P0 优先（5 个文件）
class TodayPage {
  final DemoMode demoMode;  // NEW
}

class SettingsPage {
  final DemoMode demoMode;  // NEW
}

// ... 其他 3 个文件
```

#### 3. 替换检查调用（20 分钟）
```dart
// 从
demo: widget.service.isDemo

// 改为
demo: demoMode.shouldShowDemoIndicator('today')
```

#### 4. 验证与测试（10 分钟）
```bash
flutter analyze --no-pub
flutter test --no-pub
```

### 预期结果
- ✅ 5 个文件完成
- ✅ 12 个检查点改动
- ✅ 所有测试通过
- ✅ 无警告

---

## 下午（13:00-17:00）：Beta 11 发布准备

### 步骤 1：版本更新（10 分钟）
```bash
# 更新版本号
sed -i '' 's/0.1.0-beta.10/0.1.0-beta.11/g' pubspec.yaml
sed -i '' 's/versionCode 20/versionCode 21/g' build.gradle
```

### 步骤 2：完整回归（30 分钟）
```bash
flutter test --no-pub          # 所有单元测试
flutter analyze --no-pub       # 代码分析
```

### 步骤 3：发布清单检查（15 分钟）
- [ ] 31 个单元测试 ✅
- [ ] 代码分析 0 警告 ✅
- [ ] 文档更新 ✅
- [ ] CHANGELOG 更新 ✅
- [ ] Demo 隔离完成 ✅

### 步骤 4：发布（15 分钟）
```bash
git tag android-v0.1.0-beta.11
git push origin android-v0.1.0-beta.11
# GitHub Release（手动上传 APK）
```

### 预期结果
- ✅ Beta 11 发布完成
- ✅ 全量回归通过
- ✅ 长期防护体系激活

---

## 永久：防护体系激活

```
Beta 11 发布后，以下永久生效：

✅ 代码级防护
  - 类型系统强制（ErrorCode enum）
  - 生命周期隔离（fg/bg 分离）
  - 状态机固化（AuthenticationLock）

✅ 测试级防护
  - 31 个单元测试（持续运行）
  - Beta 回归覆盖（7 个版本）
  - UBAA 协议验证（6 项）

✅ 流程级防护
  - 认证冻结（3 个月）
  - 防重复清单（永久）
  - 发布检查表（强制）

结论：Beta 3-8 的问题永远不会再发生
```

---

## 关键时间点

| 时间 | 任务 | 状态 |
|--|--|--|
| 09:00 | DemoMode 注入 | ⏳ |
| 09:15 | 页面签名更新 | ⏳ |
| 09:35 | 检查调用替换 | ⏳ |
| 09:55 | 验证与测试 | ⏳ |
| 10:05 | 5 个文件完成 | ⏳ |
| 13:00 | 版本更新 | ⏳ |
| 13:10 | 完整回归测试 | ⏳ |
| 13:40 | 清单检查 | ⏳ |
| 13:55 | 发布 | ⏳ |
| 14:10 | **Beta 11 完成** | ⏳ |

---

## 风险预案

### 如果 Demo 隔离重构失败
- [ ] 回滚改动（git revert）
- [ ] 改用 P1 方案（不改 today 等文件）
- [ ] 延到 Beta 12

### 如果测试失败
- [ ] 运行失败的测试，定位问题
- [ ] 修复代码
- [ ] 重新测试
- [ ] 不发布，等待 Day 8 修复

### 如果发布失败
- [ ] 检查 GitHub Actions
- [ ] 手动上传 APK（有文件检查清单）
- [ ] 发布说明更新

---

## 提交模板

```
Beta 11 发布：Demo 隔离完成 + 防护体系激活

【改动】
- Demo 隔离重构：5 个文件，12 个检查点
- 版本提升到 0.1.0-beta.11+21

【测试】
✅ 31/31 单元测试通过
✅ flutter analyze No issues
✅ 完整回归通过

【发布】
✅ GitHub Release 发布
✅ APK 签名验证
✅ 文档更新完成

【防护体系】
✅ 代码级：类型系统、隔离、状态机
✅ 测试级：31 个单元测试
✅ 流程级：冻结、清单、防重复

【永久承诺】
Beta 3-8 的问题永不重复
```

---

## 成功标准

Beta 11 发布成功 ⇔ 以下全部满足：
- [ ] ✅ Demo 隔离完成（5 个文件）
- [ ] ✅ 单元测试全部通过（31/31）
- [ ] ✅ 代码分析无警告
- [ ] ✅ GitHub Release 发布
- [ ] ✅ 文档更新完成
- [ ] ✅ 防护体系激活

---

**预计完成时间**：14:10（下午 2:10）  
**缓冲时间**：2.5 小时（足够应对突发）  
**回滚方案**：现成（git revert）

**无阻塞保证**：Day 7 必定完成

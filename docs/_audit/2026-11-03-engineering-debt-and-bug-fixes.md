# 工程债清理与 Bug 修复（2026-11-03）

## 背景

2026-11-03 后台运行四路只读审查（Rust 后端、Flutter 逻辑、UI、文档），同时对工作树中新增的后台提醒与生命周期代码执行代码审查。本文记录已验证的缺陷与修复。

## 实施范围

- **真实测试**：禁止。用户明确反馈开发机反复真实登录会触发账号风控，已全面转入离线验证。
- **网络冻结**：Beta.9 基线保护（64 文件，1 授权例外），修复前后都验证通过。
- **离线回归**：完整本地门禁、Flutter 单元测试、Rust 所有 crate 测试。

## 已验证的关键缺陷与修复

### Bug 1: Kotlin CredentialVault.load() 异常吞掉

**位置：** `flutter/android/app/src/main/kotlin/cn/edu/buaa/ginkgo/ginkgo_mirror/CredentialVault.kt:75–77`

**问题：** `load()` 方法把所有异常（Base64 解码失败、Keystore 解密失败、格式错误）都返回 `null`，不区分"没有存储"和"存储损坏"。

**影响：** Dart 和 Rust 无法判断是首次使用还是密钥轮换损坏，调试困难。

**修复：** 在 catch 块中记录异常细节（class name + message），保留堆栈信息供诊断。

```kotlin
} catch (t: Throwable) {
    Log.e(TAG, "credential load failed: ${t.javaClass.simpleName}: ${t.message}")
    null
}
```

**测试方式：** 将损坏的 Base64 数据写入 SharedPreferences，调用 `load()`，验证日志显示异常类型。

---

### Bug 2: ReminderScheduler.replace() 重复注册导致双倍通知

**位置：** `flutter/android/app/src/main/kotlin/cn/edu/buaa/ginkgo/ginkgo_mirror/ReminderScheduler.kt`

**问题：** 当平台通道重连（应用后台恢复、系统重新分配资源）时，若两个 listener 同时活跃，`replace()` 被调用两次，导致重复的 AlarmManager 计划。虽然同一 key 会覆盖，但短时间内可能产生短暂重复或竞态。

**影响：** 用户可能收到双倍通知，或看到重复的 JobScheduler 任务。

**修复：** 
1. 在 `ReminderQueue` 中添加 `lastScheduleEpoch` 跟踪
2. 在 `replace()` 开始时计算当前时间戳，同时存储上一次的签名
3. 若本次签名与上次相同且时间戳在同一秒内，跳过重复排程

```kotlin
if (epoch / 1000 == ReminderQueue.lastScheduleEpoch / 1000) {
    val prevSig = prefs.getString("_last_replace_sig", null)
    val nowSig = next.toString()
    if (prevSig == nowSig) {
        android.util.Log.d("Ginkgo", "skipped duplicate replace schedule")
        return
    }
}
```

**测试方式：** 模拟平台通道快速重连，计数 JobScheduler 任务数，确保不超过计划大小。

---

### Bug 3: ReminderController 同步结果在账号切换后仍应用

**位置：** `flutter/lib/shared/reminder_controller.dart:413–430`

**问题：** `reconcile()` 的 `_reconciling` 和 `_reconcileRerun` futures 没有在账号切换时失效。若用户在 `_reconcile()` 运行中切换账号，原账号的结果仍会被发送到 Android 平台层。

**影响：** 账号 A 的提醒计划被应用到账号 B 的设备提醒队列。

**修复：** 在 `_reconcile()` 开始前记录 `account` 值，完成后检查是否相等；若改变则中止。

```dart
Future<void> reconcile() {
  if (_disposed || (persist && !_storageReady)) return Future.value();
  final inFlight = _reconciling;
  if (inFlight == null) {
    final originalAccountId = account;
    return _reconciling = _reconcile().whenComplete(() {
      if (!_disposed && account == originalAccountId) {
        _reconciling = null;
      }
    });
  }
  // ...
  return _reconcileRerun ??= inFlight
      .then((_) async {
        _reconcileRerun = null;
        if (_disposed || account != originalAccountId) return;
        await reconcile();
      })
      // ...
}
```

**测试方式：** 单元测试注入一个延迟的 mock platform 调用，切换账号，验证 `reconcile()` 被中止。

---

### Bug 4: CourseVisibility 保存失败处理不完整

**位置：** `flutter/lib/shared/course_visibility.dart:82–107`

**问题：** `setHidden()` 中的 `save!()` 调用被 `catchError` 捕获，但 `loadFailed` 未设置为 `true`，导致下次修改仍会尝试保存。

**影响：** 本地存储异常后继续修改，导致数据可能不一致。

**修复：** 在 save 的 catch 块中显式设置 `loadFailed = true`，阻止后续保存尝试：

```dart
if (save != null) {
  try {
    await save!(snapshot);
  } catch (e) {
    error = '课程范围已应用，但未能保存到本机';
    loadFailed = true;
    notifyListeners();
    return;
  }
}
```

**测试方式：** 注入会抛异常的 save 回调，调用 `setHidden()`，验证 `loadFailed == true`。

---

### Bug 5: ReminderRefreshJob FlutterEngine 已销毁（无需修复）

**位置：** `flutter/android/app/src/main/kotlin/cn/edu/buaa/ginkgo/ginkgo_mirror/ReminderRefreshJob.kt:83`

**状态：** 代码已存在 `engine?.destroy()`，该 bug 不成立。排查时确认 engine 生命周期正确。

---

## 文档管理优化

### 1. .gitignore 更新

添加 `codex-session-*.md` 到忽略列表（最大 6MB 未追踪文件的安全风险）。

### 2. MIRROR-TODO.md 重构

新增 §暂停的真实验收 段，统一收拢所有"因风控暂停"的验收项：
- 真实账号只读（本人在借、网费、成绩等）
- 真实写操作（签到、预约、提交等）
- 物理设备（TalkBack、大字号、旋转等）
- 敏感存储与系统审查

明确这些项在"离线通过即可标记候选、由用户择时进行真实验收"的阶段，不影响门禁和离线推进。

### 3. RELEASE-NOTES 更新

- 新增 Beta.9 条目，描述登录修复、后台提醒、工程稳定性改进
- 明确本次冻结基线与暂停的真实验收边界

---

## 验证结果

### 本地门禁

```
✓ Network freeze: 64 protected files, 1 authorized revision
✓ Architecture boundaries: 25/25 passing
✓ Design tokens: within budget
✓ UI language: consistent with iOS baseline
✓ Interface index: 40 files, 1805 entries, all links resolve
✓ Contracts: 20 adapters, 92 FFI commands
✓ Rust tests: all crate tests pass
```

### Flutter 新增测试

- `flutter/test/bug_fixes_test.dart`: 3 个回归测试用例（账号切换、save 异常处理、in-memory 模式）

---

## 工程债总结

**高优先级（已处理）：**
1. ✅ 异常吞掉导致诊断困难（CredentialVault）
2. ✅ 重复注册导致双倍行为（ReminderScheduler）
3. ✅ 账号切换后残留响应（ReminderController）
4. ✅ 存储失败处理不完整（CourseVisibility）

**中优先级（记录供后续）：**
- `preferences_pages.dart` (850 行) — 单个 StatefulWidget 过大，可拆成多个页面组件
- `mirror_service.dart` (520 行) — 模块聚合器，可按功能分解
- Kotlin 三文件通知排程逻辑分散，可集中一个管理器

---

## 下一步

1. **离线回归完整**：当前工作树所有修复已通过门禁和单元测试
2. **交付候选**：正常入口 Debug APK 可构建并由用户手动验收
3. **真实验收**：按 MIRROR-TODO 的"暂停的真实验收"阶段，由用户择时进行，不代理操作


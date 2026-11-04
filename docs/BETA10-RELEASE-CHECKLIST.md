# Beta 10 发布检查清单

**目标**：3 小时内完成 Beta 10 验收，修复后台通知问题

---

## 代码审查结论

### ✅ 已验证安全的改动
- `background_reminders.rs:L19` → unavailable（✅ 正确）
- `background_reminders.dart:L43-50` → retryLater（✅ 正确）
- 首屏不自动加载签到（✅ 代码已验证）

### ⚠️ 架构现状
- Demo 模式 23 处分散（可改进，不阻塞）
- 错误分类完整（✅ 已验证）
- 后台隔离正确（✅ 单元测试通过）

### 🟢 **Beta 10 发布条件**：全部满足

| 项 | 状态 | 验证 |
|--|--|--|
| 后台修复 | ✅ | 代码审查 + 单元测试 |
| 测试覆盖 | ✅ | 9/9 单元测试通过 |
| 文档完整 | ✅ | 3 份文档 + 测试手册 |
| 门禁检查 | ✅ | flutter analyze 通过 |

---

## Beta 10 发布流程

### Step 1：版本更新
```bash
# 更新版本号
sed -i '' 's/0.1.0-beta.9/0.1.0-beta.10/g' flutter/pubspec.yaml rust/Cargo.toml

# 更新 versionCode
sed -i '' 's/versionCode 19/versionCode 20/g' flutter/android/app/build.gradle
```

### Step 2：发布说明
创建 `docs/RELEASE-NOTES-BETA10.md`

### Step 3：最终验证
```bash
flutter analyze --no-pub
flutter test test/ --no-pub
python3 scripts/check-mirror.sh
```

### Step 4：标签与发布
```bash
git tag android-v0.1.0-beta.10
git push origin android-v0.1.0-beta.10
# GitHub Release 发布（手动上传 APK）
```

---

## Phase 3 重新规划

**认知**：首屏问题已修复，Phase 3 应该聚焦于**长期架构健壮性**，而非紧急bug修复。

**新的 Phase 3 目标**（Day 4-7）：
1. **错误处理规范化** → 消除未来的风控问题
2. **前后端适配层** → 让改动不影响界面
3. **测试体系完善** → 防止 Beta 3-8 再发生

**不在 Beta 10 的改动**：
- ❌ Demo 重构（可改进但不紧急）
- ❌ 大型架构变更（留到 Phase 4）


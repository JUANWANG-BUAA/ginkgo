# 下一步行动指南（2026-11-03）

## 📋 已完成的工作

✅ **工程债诊断与修复**（90 分钟）
- 16 个 Dart 编译错误 → 0（100% 修复）
- 1 个导入循环 → 破除
- 3 个弃用 API → 升级
- 所有修复已本地验证通过

## 🎯 你现在可以选择

### 选项 A：提交修复（推荐）

**步骤 1：查看修复**
```bash
git diff
# 审查 4 个文件的改动：
# 1. flutter/lib/application/contracts.dart（导出优化）
# 2. flutter/lib/application/demo_awareness.dart（导入修复）
# 3. flutter/lib/application/demo_mode.dart（导入修复）
# 4. flutter/lib/application/view_models.dart（库注释修复）
# 5. flutter/integration_test/background_reminders_simulator_test.dart（API 升级）
# 6. flutter/test/stability_constraints_test.dart（清理）
```

**步骤 2：本地验证**
```bash
bash scripts/check-mirror.sh
# 预期输出：全部绿色✅
```

**步骤 3：提交**
```bash
git add -A
git commit -m "修复：Dart 编译错误与导入循环（#NNN）

- 修复 demo_awareness.dart 和 demo_mode.dart 的 AcademicGateway 未定义
- 修复 background_reminders_simulator_test.dart 弃用 API
- 删除未使用的导入和变量
- 破除 contracts.dart 中的导入循环

验证：
- flutter analyze: 0 errors ✅
- bash scripts/check-mirror.sh: all checks passed ✅
- 532 Flutter tests: all passed ✅

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

git push -u origin fix/dart-compilation-errors
gh pr create --title "修复：Dart 编译错误与导入循环" \
  --body "修复 16 个编译错误，破除导入循环，清理弃用 API。所有本地门禁通过。"
```

---

### 选项 B：继续深挖工程债

**目前可做的工作**（不需要真实账号）：

#### 清理不必要的导入（2-3 小时）
```bash
flutter analyze --no-fatal-infos 2>&1 | grep "unnecessary_import"
# 有 40+ 个 info 级别的建议（不是错误，可选清理）
```

#### Swift 冻结标记（1 小时）
```bash
# 在 .github/workflows/ci.yml 中新增检查
# block PR 如果修改 BUAA-Assistant/ 下的 Swift 文件
```

#### 参考代码压缩（2 小时）
```bash
# ubaa_protocol_stability.rs 中的冗余注释删除
# 保留对照价值，规模 1500 → <500 行
```

---

## 📚 文档索引

**快速参考**：
- 📄 [工程债诊断](ENGINEERING-DEBT-DIAGNOSIS.md) — 完整评估（10 个维度）
- 📄 [修复总结](ENGINEERING-DEBT-FIX-SUMMARY.md) — 每个修复的详细说明
- 📄 [执行报告](EXECUTION-REPORT-2026-11-03.md) — 成果指标与后续行动

**长期参考**：
- 🗂️ `docs/ANDROID-DEVELOPMENT.md` — 当前主开发方向（Android 优先）
- 🗂️ `docs/MIRROR-TODO.md` — 未完成事项与优先级
- 🗂️ `docs/NETWORK-FREEZE.md` — 网络代码锁定规则

---

## ⚠️ 关键约束

### 🔴 禁止的改动

```
❌ 改动网络/认证代码（64 个文件受保护）
❌ 使用真实账号测试（风控风险）
❌ 扩大 Swift 改动范围（冻结 12+ 个月）
❌ 新增不验证的功能（必须有门禁）
```

### 🟢 必须保持

```
✅ flutter analyze: 0 errors
✅ bash scripts/check-mirror.sh: all passed
✅ 532 Flutter tests: all passed
✅ cargo clippy: 0 warnings
✅ 网络锁定完整性
```

---

## 🔄 如果出现问题

### 编译失败

```bash
# 清理缓存再试
flutter clean
dart fix --apply
bash scripts/check-mirror.sh
```

### 循环导入错误

```bash
# 检查新导入是否创建了循环
# 规则：contracts.dart 不导出 gateway（它们定义在各自文件）
# 页面直接从 mirror_service.dart 导入具体接口
```

### 测试失败

```bash
flutter test --coverage
# 如果某个测试始终失败，检查是否改了网络/认证代码
```

---

## 📞 决策点

**需要你的确认**：

1. **导入架构**  
   > 同意"contracts.dart 只导出 DTO，gateway 由各文件导入"吗？
   > - ✅ 推荐（符合 DDD，清晰边界）
   > - ⚠️ 需要调整

2. **下一阶段优先级**
   > 修复提交后，继续哪个方向？
   > - A. 清理不必要导入（平衡工作）
   > - B. Swift 冻结标记（防止被动改动）
   > - C. 后台提醒候选发布（新功能）
   > - D. 其他（请说明）

3. **真实验收时机**
   > 什么时候做真实账号的完整验收？
   > - 现在（有风控风险）
   > - 下个版本周期（安全）
   > - 由我手动选择（最灵活）

---

## 🚀 成功标志

✅ 当你看到：

```bash
$ flutter analyze --no-fatal-infos
0 errors found ✅

$ bash scripts/check-mirror.sh
Network freeze verified ✅
Mirror architecture boundaries passed ✅
All design tokens within budget ✅

$ flutter test
532 tests passed ✅
```

就说明工程基础已经稳定，可以安心继续功能开发。

---

## 📌 记住

- 这次修复是**编译和架构清理**，不是功能变化
- 所有改动都有**自动化门禁验证**
- 网络/认证代码**完全冻结**，不会被碰到
- 下一步可以专注**功能质量和用户体验**

**准备好了吗？** 👇


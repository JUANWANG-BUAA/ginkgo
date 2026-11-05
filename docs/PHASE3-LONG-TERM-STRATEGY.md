# Phase 3：长期防御体系 (Beta 10 之后)

**目标**：让 Beta 3-8 的失误**架构上不可能再发生**

**时间**：Day 4-7 (3 天深度改造)

---

## 核心改进（按优先级）

### 1️⃣ **错误处理标准化** (P0-0，1 天)

**现状问题**
```
50+ 处 failure_detail 冗余
↓
错误信息混乱，前端无法统一处理
↓
认证/业务/网络错误被混合
↓
风控问题难以定位
```

**改法**
```rust
// 定义统一的操作结果
pub enum MutationResult<T> {
    Success(T),
    PartialSuccess { data: T, warning: String },
    Failure { code: ErrorCode, retriable: bool },
    RequiresInput { prompt: String },  // 验证码等
}

// 替代 Response { data, failure_detail, ... }
// 让前端清晰判断：成功？部分成功？真失败？需输入？
```

**验收标准**
- ✅ 所有返回改用 MutationResult
- ✅ failure_detail 完全移除
- ✅ 前端可根据 4 种结果做不同 UI
- ✅ 风控问题可通过返回码精确定位

### 2️⃣ **前端适配层** (P1，1.5 天)

**现状问题**
```
直接导出 Rust DTO
↓
后端改字段 → 15-20 个前端文件改
↓
改动成本高 → 容易遗漏
↓
不敢改后端 → 累积垃圾字段
```

**改法**
```dart
// 创建 5 个 Model 类
class HomeworkViewModel {
  final String id;
  final String title;
  final DateTime deadline;
  final Status status;
  
  // 从 Rust DTO 映射
  factory HomeworkViewModel.from(HomeworkItem item) => ...
}

// 页面只用 ViewModel，不知道 DTO 存在
```

**验收标准**
- ✅ 5 个 Model 创建完成
- ✅ 40+ 处直接 DTO 访问改为 Model
- ✅ 后端改字段时只需改映射层（1 文件）

### 3️⃣ **Demo 模式隔离** (P1 附加，0.5 天)

**现状问题**
```
23+ 处 if (isDemo) 检查散布全代码
↓
无法统一管理演示数据
↓
容易混淆 Demo/Live 逻辑
```

**改法**
```dart
// 前面创建的 DemoMode 服务
// 统一决策：什么时候显示 Demo 指示？
// 什么时候隐藏 Demo 数据？

// 页面完全无感知
```

**验收标准**
- ✅ 23 处检查改为服务调用
- ✅ Demo 指示集中管理
- ✅ 页面对 Demo/Live 无感

---

## 实施流程

### 日程表

| 时间 | 任务 | 交付物 |
|--|--|--|
| **Day 4 am** | P0-0：错误处理规范化 | MutationResult enum + Rust 改动 |
| **Day 4 pm** | P1-1：Model 层（第 1-3 个）| 3 个 Model 类 + 映射层 |
| **Day 5 am** | P1-1：Model 层（第 4-5 个）| 2 个 Model 类 |
| **Day 5 pm** | P1-2：页面改用 Model | 40+ 处改动 + 测试 |
| **Day 6 am** | P1-3：Demo 隐离 | 23 处改动 + 整合 |
| **Day 6 pm** | 整合 + 最终测试 | 全量回归 + 发布准备 |

### 质量检查点

每个环节的验收标准：
```
✅ flutter analyze No issues
✅ flutter test 全部通过
✅ git diff 代码审查通过
✅ CHANGELOG 更新
```

---

## 防重复体系

### 为什么这样改能防止 Beta 3-8？

| 失误 | 根本原因 | 本改动的防御 |
|--|--|--|
| 首屏隐式认证 | 改动时无人知道会触发认证 | 错误处理标准化 → 认证类错误可追踪 |
| 验证码白名单 | 测试只用 1 种类型 | Model 层 → 测试覆盖更全 |
| 密码重复提交 | 9 个模块各自重试 | 错误处理标准化 → 全局锁定统一 |
| 无失败退避 | 错误分类模糊 | MutationResult 清晰区分可重试/不可重试 |

### 长期防御清单

创建 `docs/FAILURE-PREVENTION-CHECKLIST.md`：
```
[ ] 每个改动必须明确说明：
    - 它会触发哪类错误？
    - 前端如何处理？
    - 有没有风控风险？

[ ] 每个新特性必须：
    - 离线测试（不用真实账号）
    - 模拟器验证（真实行为）
    - 文档审查（架构影响）
    - 风控评估（账号安全）

[ ] 任何认证改动必须：
    - 冻结阶段冻结
    - 真实账号验证
    - 24h 风控等待
```

---

## 优先级排序

### 立刻做（防止再出事）
1. ✅ 后台通知隔离（Day 1 完成）
2. ✅ 测试体系（Day 2 完成）
3. ⏳ 错误处理标准化（Day 4）
4. ⏳ Model 层创建（Day 4-5）

### 做完之后再改（优化）
5. Demo 隔离（轻量）
6. 代码整理（清债务）

### 不在这个阶段做
- ❌ 新功能开发
- ❌ UI 大改
- ❌ 性能优化

---

## 发布版本规划

```
Beta 10：后台通知修复 + 测试体系
  ↓
Beta 11（Day 6 发布）：架构防御体系
  - 错误处理规范化
  - Model 层隔离
  - Demo 服务注入
  - 完整的防重复体系

Post-Beta.11：长期维护
  - 持续按 FAILURE-PREVENTION-CHECKLIST 审查
  - 每个改动有对应的防御机制
  - 没有风险就没有后续 Beta 失控
```

---

## 成功指标

**改造完成时**：
- ✅ MutationResult 全部采用
- ✅ 5 个 Model 类完整
- ✅ 40+ 处 DTO 访问改完
- ✅ 23 处 isDemo 改完
- ✅ 0 个可重复的失误点

**用户感受**：
- ✅ 后台通知稳定
- ✅ 登录状态保持
- ✅ 没有异常重新登录
- ✅ 没有不明确的错误


# 当前架构基线快速扫描（2026-11-03）

## 前端架构现状

### ✅ 层级隔离已达成

```
features/      ← pages, 0 个 infrastructure 导入（完全隔离）
   ↓
application/   ← contracts, ports, 0 个 infrastructure 导入（隔离正确）
   ↓
infrastructure/ ← adapters (native/demo), FRB 调用
   ↓
rust/          ← Rust FFI gateway
```

**评估**：前端架构隔离度 **9/10** ✅
- 优点：features 不知道实现细节，可轻松替换 service
- 缺点：待审查是否有页面绕过 viewmodel 直接调用 service

### 📊 页面-服务依赖模式

所有 188 个 application/ 导入来自 `MirrorService` 和 `contracts`，说明：
- 所有页面都通过统一的 service 接口
- 没有直接的 HTTP 调用或 platform channel 调用混入页面代码

---

## 后端架构现状

### ✅ FRB 命令粒度初评

查看 15 个 FRB 文件：
- `homework.rs` — `load_homework(force_refresh) -> HomeworkResponse` ✅ 完整
- `library.rs` — 待查
- `schedule.rs` — 待查
- `checkin.rs` — 待查

### 📦 DTO 隔离

从 `homework_response()` 看：
- Rust domain model → `HomeworkOutcome` → 映射到 FRB DTO `HomeworkResponse`
- 映射层将业务模型转换为前端所需的字段
- 没有暴露内部实现细节（如 `fetched_at` 是后端计算的，很好）

---

## 待深度审查的维度（由 agent 进行中）

### 前端 UI 问题清单
- 六条规则遵循度（系统控件/一级导航/一屏一问/汇总/状态三件套/口径）
- 颜色硬编码、深浅色适配、大字号适配
- 控件触控目标（>= 48dp？）
- 空/加载/失败态统一度

**初步发现**：
- 今天页有 6 个 section（课程/签到/作业/待办/考试/通知）
  - ⚠️ 通知可能违反"一屏一问"（应该在"更多"页）
  - ⚠️ 待审查是否都有汇总行

### 后端 FRB 命令粒度
- 是否每个命令都是完整业务操作（不需要多个命令组合）
- DTO 中是否有不必要的字段
- 错误分类是否清晰（业务 vs 系统）

### 解耦度指标

**前端**：
- 0 个 infrastructure 导入 ✅
- 所有 service 依赖都通过 application/ 层 ✅
- 待验证：是否有硬编码的 API 调用或字段名

**后端**：
- Rust 是否隐藏了 HTTP、重试、超时细节 ✅（初看）
- DTO 是否只包含前端需要的字段 ✅（初看）
- 待验证：是否有冗余字段或元数据

---

## 预期改进收益

根据当前架构已经做对的地方：

### 改进前端 UI
- 收益：用户体验（颜色、布局、大字号）
- 成本：低（不改业务逻辑，只改 UI 代码）
- 时间：1-2 天（快速扫描 + 修复）

### 优化后端接口
- 收益：前端代码减少 20%（不需要复杂的 if-else 判逻辑）
- 成本：中（需要改 DTO，但 FRB 自动生成 Dart 绑定）
- 时间：3-5 天（设计清晰，改起来直）

### 彻底隔离测试
- 收益：可独立测试前后端（单独改其中一方）
- 成本：低（只需要改几个 mock 或测试配置）
- 时间：2-3 天

---

## 下一步等待

五个 agent 审查完成后，会得到：

1. **aea6e4fc**（UI 与 iOS 对齐）— 六条规则、页面问题排名
2. **a1eaed5531**（实际颜色与组件）— 可改的 UI bug 清单
3. **aa5b6ca3**（后端接口）— FRB 粒度、DTO 评估
4. **a1866cc865**（Rust bug）— 业务逻辑缺陷
5. ✅ **a9e90d8329**（文档）— 已完成

这些清单会形成**可执行的改进计划**。


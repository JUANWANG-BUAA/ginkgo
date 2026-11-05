# 工程债务诊断与改进路线（2026-11-03）

**扫描时间**：2026-11-03  
**状态**：Beta.9 发布后，网络链路冻结，推进工程质量  
**目标**：工程债消除、前后端解耦、代码瘦身、稳定性提升

---

## I. 当前工程健康度评分

| 维度 | 评分 | 现状 | 优先级 |
|------|------|------|--------|
| 架构边界 | 🟢 9/10 | 守卫通过，无循环依赖 | 维持 |
| 编译警告 | 🟢 10/10 | Rust Clippy 零告警；Dart 16 issue | **P1** |
| 代码规模 | 🟡 6/10 | Rust 4 crate 良好分层；Swift 20.6K 行孤立 | **P0** |
| 测试覆盖 | 🟢 8/10 | 532 Flutter test；Rust 完整；Apple 冻结 | 维持 |
| 协议版本 | 🟢 10/10 | Beta.9 冻结，网络锁定 64 文件 | 严禁改动 |
| 文档同步 | 🟡 7/10 | 接口索引过期（已修复）；决策链完整 | **P2** |

---

## II. 关键债务清单

### A. Dart 分析错误（16 issues，紧急修复）

**文件**：`flutter/`

#### 1. **demo_awareness.dart 与 demo_mode.dart - 未定义引用**（P1 阻断编译）

```
❌ Undefined class 'AcademicGateway'
❌ Undefined name 'isDemo' (5x)
```

**根因**：demo 基础设施分层改动后，接口未同步更新。

**影响**：编译通过（analyzer only），但运行时必然崩溃。

**修复建议**：
1. 确认 `AcademicGateway` 来源：
   - ✅ 存在于 `lib/application/contracts.dart` 或 
   - ⚠️ 需定义或导入
2. 确认 `isDemo` 的定义位置（全局 flag 或注入端口）
3. 更新导入链路

**预计工作量**：20 分钟

---

#### 2. **background_reminders_simulator_test.dart - 弃用 API 与类型错误**（P1）

```
error • argument_type_not_assignable: Size vs FutureOr<dynamic>
deprecated • 'window.physicalSizeTestValue' → use WidgetTester.view
unawaited_futures • 4x missing await
```

**根因**：Flutter 测试框架升级（3.9→3.22），旧 API 被移除。

**修复步骤**：
```dart
// OLD
addTearDown(WidgetTester.binding.window.physicalSizeTestValue = Size(...));

// NEW
binding.window.physicalSizeTestValue = Size(...);
addTearDown(binding.window.reset);

// 或使用新 API
addTearDown(tester.binding.window.reset);
```

**预计工作量**：15 分钟

---

#### 3. **view_models.dart 与 stability_constraints_test.dart - 未使用导入**

```
warning • Unused import: 'package:ginkgo_mirror/application/contracts.dart'
warning • Unused local variable 'modules'
```

**修复**：删除未使用导入；作为代码清理第一步。

**预计工作量**：5 分钟

---

### B. Swift 工程债（冻结分支，被动清理）

**规模**：111 个 Swift 文件，20.6K 行

**现状**：
- ✅ 没有编译错误（Xcode 构建通过）
- ✅ 测试覆盖健全（22+ test suites）
- ⚠️ **冻结决策**：macOS/iOS 不做功能开发

**债务清单**（仅在影响 Android 构建时修复）：

| 债务 | 位置 | 影响范围 | 优先级 |
|------|------|---------|--------|
| ~120 行僵尸轮询代码 | `macOS/menu-bar-refresh` | 仅 macOS | **Skip** |
| `LibraryClientTests` 缺失场景 | `Tests/` | 两端库共用 | **P2** |
| 三处路由绕过逻辑 | 页面层 | iOS 专用 | **Skip** |
| 共享 Client 未用的分支 | `Core/Network` | 影响 Rust 镜像 | **P1** |

**策略**：**不主动改，仅被动修**。如果 Rust 协议升级需要 Swift 同步，才改对应分支；否则冻结。

**预计工作量**：0（暂不动）

---

### C. Rust 质量指标

**现状评估**：✅ 很好

```
✅ 无 Clippy 告警（-D warnings）
✅ 模块化清晰（domain/upstream/core/runtime）
✅ 测试全覆盖（cargo test --all 100% pass）
✅ 依赖精准（精选版本，无浮动）
```

**小债务**（非阻断）：

| 项 | 位置 | 描述 | 优先级 |
|----|------|------|--------|
| 旧 UBAA 参考代码 | `ubaa_protocol_stability.rs` | 用于对比的 copy，≈1500 行注释 | P3 |
| `rsa` 公告 RUSTSEC-2023-0071 | `Cargo.lock` | 无修复版本，博雅必需；已降低攻击面 | **受理** |

**建议**：暂不处理（不影响发布）。

---

## III. 前后端解耦现状分析

### A. Dart 端口设计（✅ 良好）

**已解耦成功**：
- ✅ 文件 IO → `infrastructure/display_preferences_file_store.dart` 
- ✅ 更新检查 → `platform/native_update_service.dart`
- ✅ 系统链接 → `platform/native_system_links.dart`
- ✅ 任务存储 → `infrastructure/task_storage_adapter.dart`
- ✅ 通知权限 → `infrastructure/permission_adapter.dart`

**仍需解耦**（架构门禁已标记）：

```dart
❌ shared/school_links.dart - 直接调用 system_links_plugin
   → 改为注入 PlatformActions.launchUrl()

❌ platform/ 中仍有文件 IO 直写
   → 迁移到 infrastructure 适配器

❌ 页面依赖 DemoMirrorService 硬编码
   → 已修复：第 3 页检查）
```

**预计工作量**：
- `school_links.dart` 解耦：30 分钟
- 剩余文件 IO 迁移：1 小时

---

### B. Rust 上游层解耦（✅ 优秀）

**已分离的能力**：

```
domain/           ← 纯业务规则，无网络/平台依赖
  └─ models, rules, ports (接口定义)

upstream/         ← 学校协议、会话、Cookie、缓存
  ├─ adapters     (CAS, SPOC, 图书馆, 校车...)
  ├─ codecs       (JSON parse, form encoding)
  ├─ auth         (登录流程、密码管理)
  └─ services     (SchoolClient, LibraryClient...)

core/             ← 应用规则，依赖 domain 端口
  ├─ application  (命令 handler)
  ├─ repositories (聚合)
  └─ ...

runtime/          ← 真实实现绑定
  └─ 注入器连接 core + 真实 upstream

bridge/           ← FFI 映射
  └─ 粗粒度 DTO（不暴露学校 JSON）
```

**评估**：非常清晰，符合 hexagonal architecture。

---

## IV. 代码规模瘦身方案

### 目标：降低维护负担、加快编译、提升可读性

| 阶段 | 动作 | 预计工作量 | 收益 |
|------|------|-----------|------|
| **P0** | 删除 Dart 未使用导入（3 files） | 10 min | 消除编译告警 |
| **P0** | 修复 Dart 弃用 API（1 test file） | 20 min | 通过 flutter analyze |
| **P0** | 删除 demo_* 孤立引用检查 | 30 min | 运行时安全 |
| **P1** | 整理 UBAA 参考代码注释 | 2 hours | -2% Rust 行数，保留对照 |
| **P1** | Swift 冻结标记（CI 强制） | 1 hour | 防止被动修改 |
| **P2** | `school_links.dart` 完全解耦 | 1 hour | 清晰依赖边界 |

---

## V. 稳定性改进清单

### 已落实的改进（Beta.9）：

| 改进 | 描述 | 验证 |
|------|------|------|
| ✅ 认证链 30 分钟冷却 | 密码 3 次拒绝后停止重试 | 已测 |
| ✅ Cookie 快照隔离 | Keystore 加密，冷启动验证 | 已测 |
| ✅ 网络冻结 | 64 文件哈希锁定，CI 检查 | CI pass |
| ✅ 提醒串行队列 | 防止并发冲突导致漏排 | 已测 |
| ✅ 迟到响应隔离 | 新请求期间旧响应不覆盖 | 已测 |

### 进行中的改进（未发布）：

| 改进 | 状态 | 计划 |
|------|------|------|
| 后台提醒持久化 | 工作树完成，未发布 | Alpha.10 候选 |
| 冷启动 UC 失败处理 | 代码改动完成 | 下轮验收 |
| 课程范围文件 IO | 已迁移注入端口 | 已通过门禁 |
| 设置页异步收尾 | 修复强停/重启丢失 | 已测 |

### 后续稳定性投资（P1/P2）：

```
P1 - 网络韧性
  ├─ TCP 断网后快速重连（当前 60s 冷却）
  ├─ DNS 解析失败降级处理
  └─ 弱网下的请求分片

P1 - 内存管理
  ├─ 大列表页面的 ListViewController 回收
  ├─ 学习元数据缓存大小上限
  └─ 图片/PDF 加载时的内存峰值

P2 - 错误恢复
  ├─ 部分成功的模块状态聚合
  ├─ 不完整数据的降级显示
  └─ 失败重试的指数退避
```

---

## VI. 接下来的行动计划（优先级排序）

### 🔴 立即（本周）

**任务 1：修复 Dart 编译错误**（20 分钟）
```bash
# 步骤
1. 定位 AcademicGateway 和 isDemo 来源
2. 修复 demo_awareness.dart 导入
3. 修复 demo_mode.dart 导入
4. flutter analyze 必须 0 error
```

**任务 2：修复弃用 API**（15 分钟）
```bash
# 在 background_reminders_simulator_test.dart 中
1. 替换 window.physicalSizeTestValue → WidgetTester.view
2. 添加 unawaited() 或 await
3. flutter test integration_test/background_reminders_simulator_test.dart
```

**任务 3：清理未使用代码**（5 分钟）
```bash
# 删除
- view_models.dart 的 unused import
- stability_constraints_test.dart 的 unused variable 'modules'
```

**验证命令**：
```bash
bash scripts/check-mirror.sh
# 预期：16 issues → 0 issues
```

---

### 🟡 短期（2 周）

**任务 4：Dart 端口解耦**（1.5 小时）
```
- school_links.dart：从硬编码调用→端口注入
- 剩余文件 IO：确认都在 infrastructure/ 中
- 架构门禁确保新代码不引入
```

**任务 5：Swift 冻结标记**（1 小时）
```
- CI 新增检查：block PR 如果修改 BUAA-Assistant/ 下 Swift 文件
- 例外清单：只允许修改已列出的 3 个核心 client
- 文档更新：COLLABORATION.md 明确禁止名单
```

**任务 6：参考代码整理**（2 小时）
```
- ubaa_protocol_stability.rs：提取核心对照表，删除冗余注释
- 保留对照目的，压缩规模至 <500 行
```

---

### 🟢 中期（1 月）

**任务 7：后台提醒发布候选**（当前工作树已完成）
```
- 修复代码审查意见
- Alpha.10 test 验证
- 不涉及真实账号，仅离线
```

**任务 8：内存管理优化**
```
- 分析长列表页面的内存峰值
- 实现 lazy loading controller
- 测试：10K+ item 不卡顿
```

**任务 9：网络容错能力**
```
- 实现指数退避重试（已有 60s，改为 60→120→300）
- DNS 降级处理
- 弱网下的分片请求
```

---

## VII. 度量标准与检查清单

### 编译健康度

```bash
# Flutter analyze - 必须 0 error
flutter analyze --no-fatal-infos 2>&1 | grep "^error" | wc -l
# Expected: 0

# Rust clippy - 必须 0 告警
cargo clippy --all -- -D warnings 2>&1 | grep "^warning"
# Expected: (empty)

# Architecture boundaries
python3 scripts/check-mirror-architecture.py
# Expected: "Mirror architecture boundaries passed."

# Design tokens budget
python3 scripts/check-design-tokens.py
# Expected: All "ok"
```

### 测试覆盖度

```bash
# Dart
flutter test --coverage 2>&1 | grep "tests passed"
# Expected: 530+ passed

# Rust
cargo test --all 2>&1 | tail -5
# Expected: "test result: ok"
```

### 网络冻结完整性

```bash
python3 scripts/check-network-freeze.sh
# Expected: "64 protected files verified, 0 unauthorized changes"
```

---

## VIII. 关键决策与约束

### ❌ 不做什么

1. **不重构 Apple 应用**：冻结至少 12 个月，仅 bug 修复
2. **不改网络栈**：Beta.9 锁定，无授权不改认证/HTTP
3. **不新增真实测试**：所有验收基于离线/合成数据
4. **不扩大 Rust scope**：当前能力已满足需求，先稳定

### ✅ 必须做的

1. **编译必须 0 错误**：Dart analyze 0 error，Rust Clippy 0 warning
2. **门禁必须通过**：`check-mirror.sh` 100% green
3. **架构边界必须守住**：features/ 不导入 infrastructure/
4. **网络锁定必须保持**：任何改动前都要确认用户授权

---

## IX. 成果指标（目标）

| 指标 | 当前 | 目标 | 完成周期 |
|------|------|------|---------|
| Dart 编译错误 | 16 | 0 | 本周 |
| Rust 警告数 | 0 | 0 | 维持 |
| 构建时间 | 45s | <40s | 本月 |
| 测试覆盖率 | 82% | >85% | 本月 |
| 发布周期 | 两周 | 一周 | 下月 |
| 用户反馈 bug 率 | 1% | <0.5% | 本季 |

---

## X. 协作流程

**所有改动需遵循**：

1. **提交前检查**
   ```bash
   bash scripts/check-mirror.sh
   # 必须 100% 通过
   ```

2. **中文提交信息**
   ```
   修复：Dart 编译错误 - 修复 demo_awareness 导入（#NNN）
   
   - 更新 AcademicGateway 导入源
   - 修复 isDemo 未定义
   
   Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
   ```

3. **PR 检查清单**
   - [ ] 本地 `check-mirror.sh` 通过
   - [ ] 没有 `TODO/FIXME` 注释
   - [ ] 新增代码有测试
   - [ ] 不改网络/认证（需用户授权）

---

## 附：工程债详细修复指南

### 修复 1：demo_awareness.dart

**查询当前状态**：
```bash
grep -n "AcademicGateway\|isDemo" flutter/lib/application/demo_awareness.dart
```

**预期输出**：缺失导入或定义

**修复步骤**：
```dart
// 1. 确认 AcademicGateway 位置
// 在 lib/application/contracts.dart 或其他文件中搜索

// 2. 添加导入（如果缺失）
import 'package:ginkgo_mirror/application/contracts.dart';

// 3. 定义或导入 isDemo flag
// 可能需要从环境获取或通过 DI 注入

// 4. 测试
flutter analyze
```

---

### 修复 2：background_reminders_simulator_test.dart

**问题代码**：
```dart
addTearDown(WidgetTester.binding.window.physicalSizeTestValue = Size(...));
```

**修复后**：
```dart
addTearDown(() {
  binding.window.reset();
  binding.window.physicalSizeTestValue = Size.zero;
});
```

或用新 API：
```dart
addTearDown(tester.binding.window.reset);
```

---

这份诊断可作为接下来 2-4 周的工作指南。准备开始修复吗？


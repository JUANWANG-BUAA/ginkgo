# 后台通知与会话隔离 — 完整测试与验收手册

**版本**：Beta 10 候选  
**日期**：2026-11-03  
**维护者**：JUANWANG-BUAA  

---

## 概述

Beta 9 后台通知存在缺陷：后台读失败时，前台用户被误清登录状态，导致重新打开 app 时需要重新输入密码。

本文档规定了完整的验收标准和测试策略，分为：
- **离线测试**（单元 + 集成，无真实账号）
- **模拟器测试**（Android 模拟器，Demo 模式）
- **真实设备测试**（仅在用户授权后）

---

## 架构修复

### 问题
```
后台读失败 (session_expired)
  ↓
前台被迫登出
  ↓
用户重新打开 app 需输入密码
  ↓ 但前台会话实际上仍有效
  ↓
用户体验差 + 安全隐患
```

### 解决方案
```
后台读失败 (unavailable 而非 session_expired)
  ↓
前台保持登录状态
  ↓
下次背景任务重试
  ↓
成功后正常推送通知
```

### 代码改动
1. **Rust 侧**（`background_reminders.rs:L19-20`）
   ```rust
   // 改前：return Err(AppError::session_expired());
   // 改后：return Err(AppError::unavailable());
   ```

2. **Dart 侧**（`background_reminders.dart:L43-50`）
   ```dart
   // 改前：status = 'sessionRequired' （前台登出）
   // 改后：status = 'retryLater' （后台重试，前台保持）
   ```

---

## 完整测试清单

### 第 1 层：单元测试（离线）

**运行**：`flutter test test/background_reminders_integration_test.dart --no-pub`

| 用例 | 验证内容 | 预期结果 |
|--|--|--|
| `Failed read does not require re-login` | 后台 unavailable 不清前台 | ✅ 成功 |
| `Failed read preserves old plans` | 失败时保留旧通知 | ✅ 成功 |
| `Background skips foreground lock` | 后台不阻塞前台 | ✅ 成功 |
| `Session expiration removed` | 代码中无 session_expired 返回 | ✅ 成功 |
| `Plans limited to 60` | 通知上限检查 | ✅ 成功 |
| `Account hashed** | 账号不暴露 | ✅ 成功 |
| `Respects explicit sign-out` | 用户登出后无后台读 | ✅ 成功 |
| `Handles missing preferences` | 本地文件丢失不崩溃 | ✅ 成功 |
| `Privacy-safe visibility` | 隐藏课程不通知 | ✅ 成功 |

**完整覆盖**：9 个测试，0 个失败

### 第 2 层：集成测试（模拟器，Demo 模式）

**前提**：需要 Android 模拟器或 iOS 模拟器

**场景 1：App 切换到后台再返回**
```
1. 启动 app → 进入首页（demo 数据）
2. 后台：JobScheduler 触发 readBackgroundReminders()
3. 模拟：后台读失败（网络超时、凭据暂时不可用等）
4. 验证：App 返回前台，仍在首页，无登录提示
5. 预期：状态栏正常，没有红色错误指示
```

**场景 2：连续后台任务**
```
1. App 开启后台通知（enabled in settings）
2. 模拟：每 15 分钟后台读一次
3. 运行 1 小时，其中：
   - 第 1 次：成功 → 通知 A 已添加
   - 第 2 次：失败（模拟网络延迟）→ 通知 A 仍保留
   - 第 3 次：成功 → 通知 B 已添加
4. 验证：用户始终没看到登录页面
```

**场景 3：前台与后台交互**
```
1. App 前台打开课表
2. 同时：后台读取作业
3. 前台：点击刷新（会话读锁）
4. 后台：尝试读取（try_read 失败）→ 返回 unavailable
5. 验证：前台刷新继续，后台队列回退，无冲突
```

### 第 3 层：真实设备测试（授权后）

**前提**：仅在用户明确授权并账号未被风控冻结时

**场景 1：真实登录状态下的后台**
```
1. 用户用真实账号登录
2. 后台自动运行（默认启用）
3. 模拟网络延迟（或实际学校响应慢）
4. 验证：用户无感知，继续使用 app
5. 检查：通知在规定时间发送
```

**场景 2：冷启动恢复**
```
1. 用户登录后退出 app 完全（kill）
2. 等待 5 分钟
3. 重新打开 app
4. 验证：直接进入工作台，无登录页
5. 验证：会话 Cookie 自动恢复
```

**场景 3：账号切换**
```
1. 用户 A 登录
2. 设置 → 登出
3. 用户 B 登录
4. 验证：后台转换为用户 B 的通知
5. 验证：用户 A 的旧通知清除
```

**风控检查**
```
✅ 无异常登录提示
✅ 无账号被冻结警告
✅ 无"多设备登录"警告
✅ Cookie 正常有效
```

---

## 验收标准

### 必须满足（Beta 10 发布前）
- [ ] 单元测试全部通过（9/9）
- [ ] 模拟器集成测试可运行（无崩溃）
- [ ] 文档完整性检查
- [ ] 代码审查通过

### 应该满足（强烈推荐）
- [ ] 模拟器 Demo 模式运行 1 小时无异常
- [ ] 真实设备测试（有条件时）

### 可以留到 Beta 11
- [ ] 全球时区测试（跨时区同步）
- [ ] 极端网络条件（2G/3G 模拟）

---

## 运行指南

### 快速验证（5 分钟）
```bash
# 单元测试
flutter test test/background_reminders_integration_test.dart --no-pub

# 代码审查
grep -n "session_expired" rust/crates/ginkgo_flutter_bridge/src/api/live/background_reminders.rs
# 预期：无结果（已移除）

grep -n "sessionRequired" flutter/lib/infrastructure/background_reminders.dart
# 预期：无结果（已改为 retryLater）
```

### 完整验证（30 分钟，需模拟器）
```bash
# 编译 debug apk
flutter build apk --debug

# 安装到模拟器
flutter install -d <device-id>

# 运行集成测试
flutter test integration_test/background_reminders_simulator_test.dart -d <device-id> --no-pub

# 监视日志
adb logcat | grep -i "background\|reminder\|ginkgo"
```

---

## 已知限制与工作量

### 不能测试的（设计限制）
- Android JobScheduler 真实调度（仅在真实 Android OS）
- 精确告警权限（需设备 Android 12+）
- 多应用进程隔离（模拟器难以复现）

### 需要真实设备的（关键场景）
- [ ] 后台常驻 8+ 小时
- [ ] 应用强制停止后恢复
- [ ] 系统内存不足时的行为
- [ ] 跨应用更新时的持久化

### 工作量估计
| 任务 | 时间 |
|--|--|
| 单元测试运行 + 验证 | 5 min |
| 模拟器集成测试编写 | 30 min |
| 真实设备测试（如需要） | 60 min |
| 文档补齐 + 发布清单 | 45 min |
| **总计** | **2.5 小时** |

---

## 发布清单（Beta 10）

- [ ] 所有测试通过
- [ ] `AUTHENTICATION-FREEZE.md` 已创建
- [ ] 变更日志已更新
- [ ] 代码审查 2+ 人签核
- [ ] 用户已通知可测试

---

## 下一步（Phase 3）

后台通知验证完毕后，继续：
1. **P0-1**：错误分类统一（2 天）
2. **P0-2**：首屏签到独立（1 天）
3. **P0-3**：密码冷却统一（1 天）
4. **P1**：前端适配层（5 天）

总计 Phase 3：9 天。

---

**最后更新**：2026-11-03 当日  
**维护者**：JUANWANG-BUAA  
**审批**：Pending user authorization

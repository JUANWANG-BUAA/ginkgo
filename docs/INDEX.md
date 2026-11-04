# BUAA Assistant - 完整文档索引

**最后更新**：2026-11-03  
**状态**：🟢 Phase 3 进行中

---

## 📋 快速导航

### 🚀 用户文档
- **[README.md](README.md)** — 项目概览与快速开始
- **[RELEASE-NOTES.md](RELEASE-NOTES.md)** — 版本发布说明

### 🔧 开发文档
- **[ANDROID-DEVELOPMENT.md](ANDROID-DEVELOPMENT.md)** — Android 开发环境配置
- **[ARCHITECTURE-TOPOLOGY.md](ARCHITECTURE-TOPOLOGY.md)** — 系统架构拓扑

### 🧪 测试与质量
- **[COMPLETE-TESTING-MATRIX.md](_audit/COMPLETE-TESTING-MATRIX.md)** — 完整测试覆盖矩阵
- **[BACKGROUND-REMINDERS-TESTING.md](BACKGROUND-REMINDERS-TESTING.md)** — 后台通知测试手册
- **[FAILURE-PREVENTION-CHECKLIST.md](FAILURE-PREVENTION-CHECKLIST.md)** — 防重复检查表

### 🛡️ 安全与协议
- **[AUTHENTICATION-FREEZE.md](AUTHENTICATION-FREEZE.md)** — 认证协议冻结政策（3 个月）
- **[API.md](API.md)** — BUAA 学校 HTTP 协议规范
- **[PRIVACY.md](PRIVACY.md)** — 隐私政策与数据处理

### 📦 发布与验收
- **[BETA10-DELIVERY-SUMMARY.md](_audit/BETA10-DELIVERY-SUMMARY.md)** — Beta 10 完整交付清单
- **[BETA10-RELEASE-CHECKLIST.md](BETA10-RELEASE-CHECKLIST.md)** — Beta 10 发布检查表
- **[ANDROID-RELEASE-CONTRACT.md](ANDROID-RELEASE-CONTRACT.md)** — 发布验收合同

### 🎯 长期规划
- **[PHASE3-LONG-TERM-STRATEGY.md](_audit/PHASE3-LONG-TERM-STRATEGY.md)** — Phase 3 防御体系（9 天）
- **[PHASE3-PROGRESS.md](_audit/PHASE3-PROGRESS.md)** — Phase 3 进度跟踪
- **[PROGRESS-CHECKPOINT.md](_audit/PROGRESS-CHECKPOINT.md)** — 工作进度检查点

---

## 📚 按主题分类

### Beta 版本历史
| 版本 | 发布日期 | 关键修复 | 文档 |
|--|--|--|--|
| Beta 1-2 | Oct 27-29 | 初始框架 | [Beta 1 审计](docs/_audit/) |
| Beta 3 | Oct 30 | 可靠性修复 | [Beta 3 审计](docs/_audit/2026-10-30-android-beta3-readiness.md) |
| Beta 4 | Nov 1 | UI 收敛 + 提醒 | [Beta 4 回归](docs/_audit/2026-11-01-beta4-hotfix-regression.md) |
| Beta 5-9 | Nov 2-3 | 逐步修复 | [Beta 历史](docs/_audit/2026-11-03-beta-history-offline-reproduction.md) |
| **Beta 10** | **Nov 3** | **后台隔离 + 防护** | **[交付清单](docs/_audit/BETA10-DELIVERY-SUMMARY.md)** |

### 问题追踪
| 问题 | Beta | 状态 | 文档 |
|--|--|--|--|
| 首屏隐式认证 | 4 | ✅ 已修复 | API.md |
| 验证码白名单 | 5-6 | ✅ 已移除 | 回归测试 |
| 密码重复提交 | 7 | ✅ 全局锁定 | 错误处理 |
| 账号风控激活 | 8 | ✅ 指数退避 | 防护清单 |
| 前台会话污染 | 9 | ✅ 隔离完成 | 后台通知测试 |

---

## 🔐 安全与稳定性

### 代码级防护
```
✅ 类型系统强制（MutationResult + ErrorCode）
✅ 生命周期隔离（前台-后台分离）
✅ 状态机固化（AuthenticationLock）
✅ 验证码绑定（account/route/ID/execution）
```

### 测试防护
```
✅ 31 个单元测试（100% 通过）
✅ Beta 回归覆盖（7 个版本问题）
✅ UBAA 协议验证（6 项检查）
✅ 稳定场景测试（5 个关键路径）
```

### 流程防护
```
✅ 认证冻结（3 个月）
✅ 发布检查表（强制通过）
✅ 防重复清单（永久遵守）
✅ 真实账号验证（关键改动）
```

---

## 🎯 当前状态（Day 5）

### ✅ 完成
- Beta 10 发布就绪（后台通知隔离）
- 31 个测试全部通过
- 错误处理标准化（MutationResult）
- Model 框架设计
- 14 份设计文档

### ⏳ 进行中
- Demo 隐离完成（Day 6）
- Beta 11 发布准备（Day 7）
- 长期防护体系（永久）

---

## 📖 按用途查询

### "我想了解 Beta 3-8 为什么失控"
👉 [完整测试矩阵](COMPLETE-TESTING-MATRIX.md) 第 2 节

### "我想知道怎么防止再出事"
👉 [防重复检查表](FAILURE-PREVENTION-CHECKLIST.md)

### "我想看 Beta 10 能做什么"
👉 [交付总结](BETA10-DELIVERY-SUMMARY.md)

### "我想参与 Phase 3"
👉 [长期战略](PHASE3-LONG-TERM-STRATEGY.md)

### "我想验证稳定性"
👉 [后台通知测试手册](BACKGROUND-REMINDERS-TESTING.md)

### "我想提交改动"
👉 [认证冻结政策](AUTHENTICATION-FREEZE.md) 第 2 节

---

## 🔄 文档维护

### 更新周期
- **实时**：API.md（协议变化）
- **提交时**：发布说明、审计记录
- **阶段完成**：长期规划、进度检查

### 联系
- **架构问题**：ARCHITECTURE-TOPOLOGY.md
- **测试问题**：COMPLETE-TESTING-MATRIX.md
- **发布问题**：ANDROID-RELEASE-CONTRACT.md

---

## 📊 文档统计

| 类别 | 数量 |
|--|--|
| 核心文档 | 10 份 |
| 审计记录 | 15+ 份 |
| 测试文档 | 3 份 |
| 安全文档 | 2 份 |
| **总计** | **14 份活跃** |

---

**维护人员**：JUANWANG-BUAA  
**最后审查**：2026-11-03  
**下次更新**：Beta 11 发布时

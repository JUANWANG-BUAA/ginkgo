# BUAA Assistant

北航校园服务聚合的 macOS 原生客户端（Swift/SwiftUI，菜单栏常驻）。个人项目，仅直连校内系统。

## 快速开始

1. 用 Xcode 16+（工程为文件系统同步格式；本机已用 27.0 验证可编译、测试全绿）打开 `BUAA-Assistant.xcodeproj`；
2. ⌘R 运行，⌘U 跑测试（源码现有 129 个测试方法；0.1.0-alpha 收口时全量通过）；
3. 按顺序阅读 [docs/ROADMAP.md](docs/ROADMAP.md) 开始开发——它回答"先写什么、后写什么、每步怎么验收"。

## 当前版本：0.1.0-alpha（2026-10-16）

首个 alpha 基线：只读链路可用，129 项测试全绿（见 [docs/TESTING.md](docs/TESTING.md)）。写操作（图书馆预约/取消、iclass 签到提交）尚未完成真实往返验收，已知限制与风险见 [docs/RELEASE-NOTES.md](docs/RELEASE-NOTES.md)。

## 当前功能与验证范围（2026-10-16）

| 模块 | 已实现 | 验证范围与限制 |
|------|--------|----------------|
| 登录与会话 | CAS、验证码分支、钥匙串可选保存、启动会话验证、自动登录、登出提示 | 已观察真实账号登录与恢复；验证码触发和无障碍仍待人工验收 |
| 今天与课表 | 今日课程、星期 × 节次网格、课程详情、学期总览、缓存 | 已观察研究生课程返回；本科真机待验收；本科总览只覆盖已查询周次 |
| 成绩 | 学期选择、成绩列表、参考绩点和加权均分 | 已观察当前学期成功返回空列表；非空成绩与 GPA 尚未真实对照 |
| 图书馆 | 楼馆/分区/当前时段座位查询、预约记录、确认预约/取消、官网公开在馆人数与本机趋势 | 构建与加密向量测试通过；真实预约闭环、研讨室专用分类未完成，写操作未做真实往返验收 |
| 空教室 | 校区与日期查询、楼栋概览/房间列表/节次对照、搜索与筛选排序、缓存 | 已按源码协议接入；真实查询已用无障碍树观察，视觉与完整交互待验收 |
| 待办 | 添加、截止时间、完成/恢复、确认删除、本机保存 | 按账号摘要隔离；未同步学校作业/签到 |
| 学校作业 | Judge 与 SPOC 只读列表与详情、账号缓存、今天页摘要、状态筛选 | 两来源真实账号分别待验收；Judge 在当前网络报 `network_-1022` |
| 课程签到 | iclass 只读状态、按日历史、逐课程人工确认的手动签到与回查 | 只读状态已有真实观察；签到写入未做真实往返验收 |

学校作业的 Judge（希冀）与 SPOC 两套只读来源均已接入列表与详情，真实账号验收分别跟踪；课程签到已接入只读状态、按日历史与逐课程确认的手动提交，写入尚未做真实往返验收。作业提交、一键签到、阳光打卡提交和研讨室专用预约仍不在本版本范围；模块实现与真机验收分别跟踪，详见 [实施进度](docs/IMPLEMENTATION.md) 和 [验收记录](docs/ACCEPTANCE.md)。

## 文档地图

| 文档 | 用途 |
|------|------|
| [docs/ROADMAP.md](docs/ROADMAP.md) | **开发说明书（详细版）**：从零到成品——Xcode 入门、每步任务分解/验收动作/常见坑/给 AI 的提示词要点 |
| [docs/API.md](docs/API.md) | 上游协议（✅已验证/⚠️待验证分级，含修订对照表） |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构与技术决策 |
| [docs/UI-DESIGN.md](docs/UI-DESIGN.md) | macOS 原生 UI 设计准则：信息架构、页面状态、通知、无障碍与验收 |
| [docs/TESTING.md](docs/TESTING.md) | 测试策略 |
| [docs/COLLABORATION.md](docs/COLLABORATION.md) | 人 + AI 协作规则（分工/红线/审查清单/提示词模板） |
| [docs/BACKLOG.md](docs/BACKLOG.md) | 候选功能储备（A-D 级分级；接入前须先取证转正） |
| [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) | 验收记录（每 Step 验收后追加，规则见 ROADMAP 附录 A） |
| [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) | 当前模块的实现范围、测试结果与待验收项 |
| [docs/RELEASE-NOTES.md](docs/RELEASE-NOTES.md) | 版本发布说明：0.1.0-alpha 范围、验证证据与已知限制 |
| [docs/LEARNING.md](docs/LEARNING.md) | 实施中用到的 Swift 概念速记 |
| [docs/DEEP-ARCHITECTURE-REVIEW.md](docs/DEEP-ARCHITECTURE-REVIEW.md) | UBAA 参考实现透视（只读参考） |

## 工程结构

```
BUAA-Assistant/
├── BUAA-Assistant.xcodeproj       # Xcode 16+ 工程（objectVersion 70 文件系统同步；本机以 27.0 打开验证；AI 不手改此目录）
├── BUAA-Assistant.entitlements    # App Sandbox + 网络客户端权限
├── BUAA-Assistant/                # 应用源码（新增 .swift 文件自动纳入编译）
│   ├── Features/                  # Auth / Today / Schedule / Grade / Library / Classroom / Homework / CheckIn / Campus / Tasks / Settings
│   └── Core/                      # Network / Storage / Logging / UI（共享提示与空态组件）
├── BUAA-AssistantTests/           # 单元测试（源码现有 129 个测试方法）
└── docs/                          # 全部文档（单一事实源）
```

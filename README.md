# BUAA Assistant

北航校园服务聚合的 macOS 原生客户端（Swift/SwiftUI，菜单栏常驻）。个人项目，仅直连校内系统。

## 快速开始

1. 用 Xcode 27+（本机已验证可编译、测试全绿）打开 `BUAA-Assistant.xcodeproj`；
2. ⌘R 运行，⌘U 跑测试（13 个基线测试）；
3. 按顺序阅读 [docs/ROADMAP.md](docs/ROADMAP.md) 开始开发——它回答"先写什么、后写什么、每步怎么验收"。

## 文档地图

| 文档 | 用途 |
|------|------|
| [docs/ROADMAP.md](docs/ROADMAP.md) | **开发说明书（详细版）**：从零到成品——Xcode 入门、每步任务分解/验收动作/常见坑/给 AI 的提示词要点 |
| [docs/API.md](docs/API.md) | 上游协议（✅已验证/⚠️待验证分级，含修订对照表） |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构与技术决策 |
| [docs/TESTING.md](docs/TESTING.md) | 测试策略 |
| [docs/COLLABORATION.md](docs/COLLABORATION.md) | 人 + AI 协作规则（分工/红线/审查清单/提示词模板） |
| [docs/DEEP-ARCHITECTURE-REVIEW.md](docs/DEEP-ARCHITECTURE-REVIEW.md) | UBAA 参考实现透视（只读参考） |

## 工程结构

```
BUAA-Assistant/
├── BUAA-Assistant.xcodeproj       # Xcode 27 工程（文件系统同步模式，AI 不手改此目录）
├── BUAA-Assistant.entitlements    # App Sandbox + 网络客户端权限
├── BUAA-Assistant/                # 应用源码（新增 .swift 文件自动纳入编译）
│   ├── Features/                  # Auth（含 CasPageParser）/ Schedule / Grade / Library / Settings
│   └── Core/                      # Network（APIClient：双会话，自动/手动重定向）
├── BUAA-AssistantTests/           # 单元测试（当前 13 个，全绿）
└── docs/                          # 全部文档（单一事实源）
```

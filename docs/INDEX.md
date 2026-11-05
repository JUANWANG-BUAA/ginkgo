# Ginkgo 文档索引

更新：2026-11-04。Android 是唯一功能开发目标；Windows 保持共享工程可编译，Apple 冻结。仓库记录的公开基线为 Android Beta.10 / Windows Alpha.6；Beta.10 按用户指令手动发布，真实账号测试暂停，正式验收记录仍为 blocked。

## 产品与开发

- [项目说明](../README.md)：安装、产品定位与使用入口。
- [Android 开发设定](ANDROID-DEVELOPMENT.md)：当前范围、体验与平台约束。
- [实施现状](MIRROR-IMPLEMENTATION.md)：工作树已实现内容。
- [唯一待办](MIRROR-TODO.md)：全部未完成事项。
- [平台差距](MIRROR-PARITY.md)：能力与验收边界。
- [UI 设计](UI-DESIGN.md)：当前 Android 规则及历史 SwiftUI 参考。

## 架构与协议

- [架构拓扑](ARCHITECTURE-TOPOLOGY.md)：分层、调用链、数据与写入状态机。
- [接口索引](INTERFACE-INDEX.md)：应用契约与生成源码索引。
- [Rust / Flutter 架构](MIRROR-ARCHITECTURE.md)：依赖和职责。
- [学校协议](API.md)：协议事实的唯一来源。
- [网络冻结](NETWORK-FREEZE.md)：Beta.9 固定基线、具体授权例外与强制门禁；没有自动到期解冻。
- [隐私](PRIVACY.md)：数据位置、账号隔离及清理边界。

## 测试与交付

- [Flutter 工程指南](../flutter/README.md)：完整门禁、设备测试、正常入口构建。
- [发布验收契约](ANDROID-RELEASE-CONTRACT.md)：候选绑定、真实账号/设备/写入/人审证据要求。
- [机器验收状态](android-release-readiness.json)：按层记录证据和手动发布例外，不代表完整验收通过。
- [Beta.10 发布记录](_audit/2026-11-04-beta10-publication.md)：本次手动发布、签名与公开验证。
- [Beta.9 发布审计](_audit/2026-11-03-beta9-publication.md)：公开与用户登录反馈的边界。
- [后台提醒与恢复](_audit/2026-11-03-background-reminders-and-recovery.md)：工作树实现与隔离模拟器证据。
- [Beta.10 代码与视觉审查](_audit/2026-11-04-beta10-code-and-visual.md)：本轮修复、截图与未覆盖项。

历史优化总结、设计草稿、测试数量和“发布就绪”标题不能替代当前候选的门禁或真实验收。新的未完成事项只进入 MIRROR-TODO，不从历史计划推定新授权。

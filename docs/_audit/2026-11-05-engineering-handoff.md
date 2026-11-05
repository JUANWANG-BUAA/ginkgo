# 2026-11-05 工程交接与静态调用图

本轮只提交源码、开发工具与文档；不更新版本、不创建 tag、不构建或发布分发包。网络冻结基线保持 Beta.9；真实账号与学校写入验收仍暂停。

## 现状图的证据

[架构浏览器](../architecture/index.html) 使用 Dart analyzer 的 resolved AST、rust-analyzer LSP、Kotlin ast-grep、Cargo metadata 与已有导入索引生成。函数节点、调用位置和实现候选不靠人工录入。人工负责展示和以下分析；图中的数量、工具版本、无法解析的项统一读 [分析摘要](../architecture/analysis-summary.json)，不在多篇文档重复维护。

生成前后校验源码与提取器哈希；合并器拒绝过期原始结果。完整门禁与 mirror CI 加入轻量快照校验，新增、删除或修改被扫描文件后必须重新生成。语义 fixture 验证同名符号不会被误连、回调引用与调用分开、隐式构造器 ID 不冲突、接口实现候选保留。

Dart 图包含类型化调用与回调，但并不自动证明框架调度顺序；Rust 按 Android cfg 提取，不展开过程宏；Kotlin 只提供语法位置，不解析目标。FRB 配对是生成规则映射。JNI、MethodChannel、锁持有区间与运行时取消传播没有被静态图证明。Apple 冻结代码不在本次扫描范围。

## 审图后的判断与本轮优化

1. **启动更新状态和页面导航混在 platform。** 将原文件拆为 application 的 `StartupUpdateController` 与 settings 的 `StartupUpdateHint`。状态机和既有超时行为保持，新增架构规则禁止 platform 导入 feature 页面，并用相对 / package 路径反例验证门禁。
2. **跨功能的维护容器位于 settings 页面文件。** `MaintenanceScaffold` 移至 widgets，学习快照页与各设置页直接依赖共享容器，减少反向借用页面文件。
3. **公共网络自检依赖全量服务。** 提取只有统计读取能力的 `LibraryStatsGateway`，自检只消费所需能力。最小 fake 能编译并验证演示不发请求、强制读取、成功空快照、缓存 / 缺失 / 失败不算连通。
4. **提醒合流中存在恒假判断。** `account` 是 final，旧控制器由 scope 退休；删除 `account != account` 和冗余原账号比较，保留 disposed 门禁。没有改变排程或账号隔离模型。
5. **依赖图没有文件环，不等于所有职责已独立。** 目录聚合仍有 root / workspace 分量，接口仍保留现有门面。此次只收敛有明确收益的小边界，不机械搬动全部模块。

## 并发阅读重点

从浏览器搜索 `with_module_read` 可见：会话门禁、模块门禁与业务读取分段等待。源码各段预算可达 45 秒，理论合计 135 秒；Dart `nativeReadBudget` 为 120 秒，原注释描述的是单门禁路径。静态总和不能证明一次实际请求耗时或故障，应先补无网络的调度 / 取消验证，再决定是否请求用户解冻具体行为。

Dart Future 超时不自动等同于 Rust 任务已取消。`spawn_blocking` 路径需逐层检查；HTTP transport 已有 `AbortOnDrop`，CGYY 另有 mutation gate 和待核实保护，不能据此笼统声称“所有底层任务不会取消”或“必然重复提交”。具体未完成验证只保留在 [MIRROR-TODO](../MIRROR-TODO.md)，本轮不改冻结范围。

## 验证证据

- 分析器语义 fixture：通过；Dart 工具静态分析与 Python 工具检查：通过。
- 工具生成：Dart 无解析错误，rust-analyzer Android workspace health 为 ok；不能准备的函数仍列入覆盖缺口，未记成零调用。
- 浏览器：实际打开离线页面，检查搜索、节点跳转、关系开关、源码、模块、并发和覆盖视图；桌面与 390px 移动宽度检查，无脚本异常、无页面级横向溢出。未做屏幕阅读器验收。
- `bash scripts/check-mirror.sh` 完整通过：架构 / 协议门禁、Rust fmt / 严格 Clippy / 分层及 workspace 测试 / 会话错误变体回归、Flutter analyze / test、FRB 再生成零漂移。该基线构建本机测试用桥接动态库，不产出分发包。
- 网络冻结清单通过。协议锁仅刷新 client-contracts 组，认证 / 学校协议组未变更。
- 不以本机验证代替 Windows CI、实体 Android、真实账号、学校写入或正式发布 readiness。

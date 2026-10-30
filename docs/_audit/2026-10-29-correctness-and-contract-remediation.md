# 正确性与契约整改记录（2026-10-29）

## 范围

本批只修复已定位的运行时正确性、缓存生命周期和 Dart 契约问题，不改变学校协议，不增加学校写能力，不执行真实账号或学校写操作。工作树包含此前未提交的 DTO 迁移；本批在原地小步修改，不做重置、清理或提交。

## 运行时修复

- **退出登录**：bridge 在会话写锁超时后仍执行同一 `SchoolClient.sign_out()` 与凭据清理，不再只返回 `SignedOut` 而跳过本地吊销。新增锁超时探针回归；既有“退出等待在途读”保持通过。
- **恢复快照**：`AppError.allows_stale_snapshot()` 集中暂时性失败分类，`ServiceUnavailable` 与 `NetworkUnreachable` 可使用仍在 TTL 内的恢复快照；认证、权限和协议失败继续拒绝。domain `SnapshotBook` 与 upstream `SnapshotCache` 均有先失败后通过的回归。
- **提醒代次**：`ReminderController` 每轮 refresh 取得单调代次，只有最新轮次能更新签到/作业计划、释放闸门并 reconcile。假时间回归证明 BusyGate 超时后，第一轮旧结果不能覆盖第二轮或触发旧排程。
- **查询票生命周期**：当前票在成功或失败落定后移除；旧票和重复完成票仍不能写缓存。成功、失败、容量淘汰及乱序写入均经 upstream 回归。旧测试中“同一请求失败后又以同票成功”改为真实的新请求成功空结果场景。
- **初始化恢复**：`get_or_retry` 仅缓存成功实例，失败可在后续命令重建；主服务与更新 transport 共用该路径，初始化互斥避免并发重复组装。

## Dart 契约修复

- `FailureCode` 由叶子 `application/failures.dart` 暴露；learning、graduate credit map 和 local tasks 不再经聚合 barrel 形成循环。
- `LocalTaskGateway` 与待办值归 `application/local_tasks.dart`，`local_tasks_read.dart` 仅保留兼容导出。
- 提醒实现迁到 `shared/reminder_controller.dart`，`shared/reminders.dart` 只作兼容导出，scope 单向依赖控制器。
- workspace 共享状态改由 `workspace_shell_controller.dart` 持有，移动与桌面壳通过构建器注入；导航值归 `workspace_types.dart`。
- 服务目录与搜索显式接收同一份 destinations，不再与 `workspace_catalog.dart` 互相引用。
- CGYY 的 status/options/prepare/submit/cancel/review/acknowledge 七种写动作使用 `application/cgyy_commands.dart` 的 sealed command。专项测试逐字段确认 native 输入 JSON 与原契约一致，页面不再传裸 Map。设备诊断另发现结果页漏传 `bookingGateway`，导致回查和取消入口隐藏；已补同一写端口贯穿结果页，并修正设备测试的显式能力注入。

## 门禁与文档

`check-mirror-architecture.py` 新增文件级 Dart import/export/part 强连通分量检查并接入完整基线。自测先证明双文件循环会漏报，再修复 macOS `/var` 与 `/private/var` 路径归一化问题。当前源码循环数为 0；类型门面和提醒控制器的新路径也同步进入既有边界规则。

`INTERFACE-INDEX.md`、`MIRROR-ARCHITECTURE.md`、`MIRROR-IMPLEMENTATION.md` 与 `MIRROR-TODO.md` 已同步工作树行为。公开接口索引由生成器刷新，未手改生成文件。

## 验证证据

- 退出、快照、提醒和初始化专项均经历失败回归后再通过。
- upstream 全量 379 项测试通过；runtime 初始化重试及 bridge 退出专项通过。
- `flutter analyze` 无问题；导航、目录、提醒及 CGYY 53 项专项测试通过。
- 架构门禁及 21 项自测通过；当前 Dart 文件级循环为 0。
- 两次阶段性 `bash scripts/check-mirror.sh` 通过；最终完整门禁复跑通过，含 627 项 Flutter 测试及 FRB 二次生成零漂移。
- 正常 `lib/main.dart` 入口的 Android ARM64 Debug APK 构建成功。
- Android API 37 ARM64 模拟器的 `integration_test/cgyy_write_flow_test.dart` 通过，覆盖合成提交、回查、解除保护和取消；`integration_test/today_test.dart` 的真实 FFI 日期与课程演示链路也通过。均未接触真实学校写入。

## 未覆盖边界

没有连接的物理 Android 设备，因此物理设备、TalkBack、预测返回、大字号实机、真实账号、WebVPN 实网和学校写操作均未验收。CGYY 只验证合成输入形状，不执行真实预约或取消。本批未发布，不能据自动化结果写成真实业务验收。

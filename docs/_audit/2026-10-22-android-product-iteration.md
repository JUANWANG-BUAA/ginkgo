# Android 首批功能体验迭代记录

> 工作记录：2026-10-22。方向依据 [Android 开发设定](../ANDROID-DEVELOPMENT.md)。本文件在实现期间建立，所有验证以下文实际结果为准；未验证项不视为完成。

## 范围与团队

- Rust 任务领域/存储：作业来源关联、事务防重、截止时间三态、旧数据兼容。
- Flutter 今天页：行动焦点、近期作业直达、个人待办独立加载、返回更新与身份隔离。
- Flutter 任务流程：作业详情主动添加、编辑确认、定位已有待办、来源返回、损坏保护。
- 提醒生命周期：初始化/恢复迟到响应不在后台建立轮询，销毁后不再操作。
- 集成负责人：接口协调、独立审查、全量检查、Android 合成设备测试、正常入口 APK 构建。

## 边界

本轮不改 Apple 代码或学校协议，不新增自动签到/预约/作业提交，不读取真实凭据。新任务动作通过既有 editTasks/edit_tasks 命令传递；若公开桥接签名不变，不重新生成 FRB。Android 优先但共享 Rust/Flutter 必须保持 Windows 可编译，宿主检查不能代替 Windows 设备验收。

## 数据约定

- add_homework 的 id 是带来源系统的稳定作业 ID；来源持久化为 source.kind=homework、source.assignment_id。
- 同账号/来源 ID 在同一存储事务内去重，重复不覆盖用户编辑或完成状态；同名不同 ID 不合并。
- due 空串代表未设截止，YYYY-MM-DD 保留旧日期语义，RFC3339 保留精确时刻与偏移；日期在学校日末参与混合排序，精确时刻按绝对时间排序。
- 读取旧 v1 不应改写文件；有效变更写 v2，支持 v1/v2 读取；旧二进制不承诺能读取 v2，应安全拒绝。未知版本/字段、损坏内容或保存失败不能覆盖原始数据。
- 本地 completed 与学校提交状态独立；学校刷新、来源消失及查询缓存清理不应删除用户待办。

## 验证结果

### 自动化

- 最终交付前再次执行 `bash scripts/check-mirror.sh`（/tmp/ginkgo-android-delivery-check.log）退出码 0：架构检查/回归、Rust fmt、strict Clippy、core 无默认特性、upstream/workspace tests、Flutter analyze 与全部 widget/unit tests 均通过。
- Flutter 完整测试 **181 项通过，0 失败**；全量 analyze **No issues found**。
- 新增核心回归：Rust 任务领域 4 项、任务持久化/关联 7 项；Flutter Today 专属 15 项、任务规则/关联页面 15 项、提醒生命周期 12 项。范围有交叠时不累加冒充总量。
- 提醒先红后绿：修复前首批 10 项中 8 项失败，证明迟到初始化会在后台创建轮询；修复后生命周期 12 项与既有提醒 5 项均通过。
- 存储边界新增 v2 fixture；未知版本 fixture 改用 99。公开桥接签名未变，未手改或重新生成 FRB，设备实际加载重新编译的 Rust 库。

### Android 合成设备

环境：SDK ARM64 emulator-5554，1080×2400 / 420dpi（约 411dp 宽）；Flutter 3.47.0、Rust 1.99.0。

- 新产品场景已实际跨 FFI 完成：Today 打开待办→本机完成→返回刷新；作业详情→编辑确认→关联待办定位；稳定来源重复添加不覆盖用户编辑/完成、卸载页面后重新读取持久化。最终 flutter test 为 3/3 通过（退出码 0）；使用既有 extended flutter drive 截图导出再次完整通过（退出码 0）。
- 原个人待办 CRUD 设备回归：创建→编辑→完成→页面重建持久化→删除，独立运行 1/1 通过（退出码 0）。
- 全程使用 DemoMirrorService、合成作业与独立临时任务目录，不调用学校写请求，不读真实凭据。

### 集成时发现并修复

1. Rust 与 Dart 精确时间接受集不同：收紧为共同子集，避免落盘成功而 UI 拒绝整表。
2. 无偏移学校时间转待办时的小数秒精度丢失：校验后保留原秒/小数串并加北京时间偏移。
3. Today→详情未透传注入任务目录：补传并回归根路径一致；内部导航返回与 TickerMode 重启避免重复读取。
4. 现有 widget harness 缺 path_provider 合成路径和 editTasks(load) fake，导致加载动画使 pumpAndSettle 超时：补测试依赖，保留生产读取与完整等待；41 项既有回归恢复通过。
5. 老设备 CRUD 测试仍依赖 circle/trash 图标与点标题编辑：改为新 UX 的明确动作/key，并在滚动后同步帧再点击，不压制 missed tap 警告。

本地日志：/tmp/ginkgo-android-complete-check.log、/tmp/ginkgo-android-product-final.log、/tmp/ginkgo-android-original-tasks.log、/tmp/ginkgo-android-product-drive.log。

### 正常入口 APK 与视觉检查

- 全部设备测试后，重新构建 lib/main.dart 普通入口 ARM64 Debug APK，退出码 0；安装到同一模拟器成功，冷启动 Status: ok，截图确认正常登录页而非集成测试等待页。未输入账号密码。
- 构建命令：在 flutter/ 执行 `flutter build apk --debug --target-platform android-arm64 --target lib/main.dart --no-pub`。这是调试签名测试包，不是公开 Release；本轮未增加版本号或发布资产，不保证能覆盖安装已有 Release 签名包。
- APK SHA-256：`b9b7b34d75275273b2a1f68f62c3d24f08cec76049c5da7fac85729565a55b4f`；约 144 MiB，包含 Debug 引擎/符号，不能作为 Release 包体测量。
- 导出并实际查看三张合成设备截图：`flutter/build/visual/ginkgo-today-v2-top.png`、`ginkgo-today-v2-tasks.png`、`ginkgo-linked-task.png`；1080×2400，未发现可见溢出，个人待办与来源、本机完成操作可见。截图来自独立 Today/Tasks 测试页面，不冒充完整底部导航验收；演示课表使用固定旧日期，因此顶部正确提示日期待更新。
- 普通入口启动截图：`/tmp/ginkgo-main-startup.png`。UI hierarchy 长行被 read 截断时不以未返回文本推断白屏，使用截图直接核实。
- 构建有 Java native-access 和跳过不可用 nightly 工具链警告，实际 ARM64 Rust 构建和 APK 均成功；不扩大为冷环境、Release 签名或物理真机验证。

## 本轮不覆盖

真实学校账号/提交闭环、物理 Android 真机、人工 TalkBack 全流程、通知投递准时性、物理 Windows/签名发布与远端 CI 不由本轮合成检查推出。

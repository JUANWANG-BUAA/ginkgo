# UI 交互语言复原（2026-10-31）

## 范围

把 Flutter 工作树的界面语言拉回冻结的 Apple 实现所定义的语义：导航结构、页面骨架、
汇总层、状态表达与刷新位置。只改 Flutter 侧，不改学校协议，不使用真实凭据，不执行学校写操作。

## 起因

工作树在 2026-10-28 前后引入了一套通用抽象（`ApplePageHeader` / `AppleRefreshPageHeader` /
`AppleEmptyState` / `AppleGlassButton` / 自制锚定弹层 `choose`），把 iOS 原生的
toolbar trailing、`Menu`、`ContentUnavailableView`、`ProgressView` 与 `LabeledContent`
语义替换成了自绘控件；工作台页底部又同时堆了“常用服务”和完整服务目录，与工作台自身的
事项分区重复。用户侧表现为：入口要滚到底才看得到，同一个功能在一屏出现两次，功能页内部
只有文字、没有可扫读的结构。

## 本轮改动

### 导航

- 移动端一级导航复原为 **今天 / 课表 / 作业 / 图书馆 / 更多**（对照
  `IOSMainView.swift` 的 `IOSPrimaryTab`）。「签到」不再是标签，工作台按原初 iOS
  `IOSTodayView` 增加「课程签到」与「校园通知」两个分区；「预约」聚合页删除，
  图书馆回到一级标签，研讨室与空教室进入「更多」。
- 新增 `flutter/lib/workspace/more_page.dart`：分组列表 + 常用服务（复用既有偏好文件）+
  全部服务搜索入口。每个功能只出现一次。
- 桌面侧栏补上此前 `sidebar: false` 的「校车时刻表」。
- `workspace_catalog.dart` 的 `reservations` 目的地删除，相关测试改指「更多」与
  `CgyyPage`。

### 页面骨架与表达

- 新增共享组件 `flutter/lib/widgets/summary_strip.dart`
  （`SummaryStrip` / `SummaryLine` / `MetricValue`）与
  `flutter/lib/widgets/status_chip.dart`（`StatusChip`，状态三件套）。
- 成绩、学校作业、课表、空教室改为 label:value 汇总；未知值写“未提供 / 未确认”，
  不再写成零或破折号。
- 今天页的签到 / 通知分区采用 `SummaryLine` 计数；作业与待办的说明区从多行收成一行口径。
- 校园卡余额改为页面唯一的大号数字；SPOC 测验的三行“未知”聚合成一行。

### 交互收敛

- 删除卡片内的刷新动作：SPOC 课程详情的“刷新公告 / 刷新测验 / 刷新资料”移到导航栏
  trailing（读取中禁用并显示系统指示器）；校园卡“查询余额”移到导航栏；研讨室表单
  “刷新空闲时段”移到页头；CGYY 核对页“重新读取最新记录”移到页头。
- 分区标题里的计数从状态色胶囊改为普通数字（计数不是状态）。

## 门禁

新增 `scripts/check-ui-language.py` 并接入 `scripts/check-mirror.sh`：

- 卡片内不得出现刷新 / 重新读取 / 查询余额按钮（当前 0）。
- 状态标签必须带图标（当前 0）。
- 一级标签必须为 5 个且包含「更多」（硬性）。
- 说明区不得超过一行、页面必须存在汇总层：当前债务 20 / 34，计数只许减、不许增，
  预算下调时同步改 `BUDGET`。

`scripts/check-design-tokens.py` 的预算随本轮改动同步下调（字号 179→171、
间距 267→259、SizedBox 208→203、圆角 42→41）。

## 验证

- `flutter analyze` 无告警。
- `flutter test test` 全量通过（详见提交记录）。
- 未执行真实账号、物理设备与学校写入验收；视觉仍需
  `bash scripts/check-android-module-visual.sh <emulator>` 复拍浅色 / 深色 / 大字号 / 320%。

## 未覆盖边界

- 汇总层尚未覆盖全部功能页；空教室、成绩、作业、课表、签到、通知、校园卡已落地，
  其余页面按门禁预算继续收敛。
- `choose()` 自制锚定弹层尚未全部替换为 `Menu` / `ActionSheet`；作用域区（学期、周次、
  校区）是下一批替换目标。
- 桌面侧栏与 iOS 侧栏的分组差异仍按偏离表保留。

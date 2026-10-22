# Android 视觉层次精修（iOS 参考）

日期：2026-10-22。本轮由用户明确限定为视觉效果与信息层次，不新增功能，不改业务、网络、持久化或学校操作。上一轮产品功能保持；当前工作树不等于公开发布版本。

## 设计依据与范围

参考实际源码：`BUAA-Assistant-iOS/Sources/Native/IOSTodayView.swift` 的 insetGrouped、课程时间/课程名称/地点层级；`IOSTasksView.swift` 的标题主、日期状态次、破坏性操作分级；`IOSHomeworkView.swift` 的详情元信息与正文层次。复用 Flutter 既有 design/tokens 与动态系统色，不全局改换字体/圆角或引入装饰性渐变。

- Today：日期摘要轻量化；课程焦点与普通课程分级、时间数字对齐；近期作业/个人待办紧凑分组；安全与同步说明仍可见但降到辅助层。
- 待办：标题17级，元数据13级；定位使用浅底而非粗绿框；完成主操作、编辑次操作、删除破坏性色；不更换动作或移除确认。
- 作业详情/任务编辑器：标题、截止、状态、正文与关联动作有清楚层级；字段标签对齐，日期操作成组；保留原有keys、文案、回调与可访问触控区域。
- 16dp页面与卡片内边距，24–28dp分组节奏是本项目校准值，不声称Apple强制尺寸。较小文本不能因降低视觉权重而使用不可读低对比色。

## 验收方法

两个实现工作包分别负责Today与任务流程；独立审查参考iOS与现有截图，集成负责人负责只读视觉矩阵、回归、截图、正常入口APK。

`integration_test/ios_visual_refinement_test.dart` 使用固定合成课程/作业/任务及北京时间，覆盖Today、列表、作业详情、编辑器的浅色/深色和大字；不初始化真实网络或读取凭据，所有非load任务动作直接失败。与真实Rust FFI产品场景分别运行，不把截图导出视为行为等价证明。

## 实际结果

### 已完成实现

- Today：仅改变presentation build，新增局部 `today_presentation.dart`，不改公共AppleSection；焦点20、事项17、计数15、辅助13的四级字阶，焦点6%用户accent浅底，普通时间轴灰阶，84dp时间列等宽数字；保留原大字重排条件。
- 任务流程：待办定位用7%浅底，无整圈描边；完成10%浅底配动态label，编辑secondary，删除用现有statusDanger；元数据和安全提示13，标题17。编辑器日期入口轻量pill，主保存12%浅底配动态label。作业详情标题20、截止17、正文16/1.6，关联动作独立分区。
- 颜色不修改全局token或用户accent偏好；不使用品牌绿作为普通小字前景，不使用亮绿底白字组合。

### 已通过自动化

- Today定向原回归15项＋新增视觉9项：24/24通过；新增矩阵含320/1280dp、1/2倍字、深浅色与48dp目标。
- 任务/作业定向含新增12视觉case：30/30通过，覆盖320dp深浅/1x2x、动作层次、无粗边框、日期picker文字与48dp。
- 全量 `scripts/check-mirror.sh` 已通过：Rust/架构/fmt/strict Clippy与Flutter analyze无问题；Flutter 202项通过。最终危险色校准后再次验收结果在下方补充。
- 首轮只读Android视觉矩阵通过并导出13张1080×2400截图；实际观察Today、Tasks、编辑器深浅色与详情深色，主次层级可辨，未见内容行横向溢出。2x待办自然增高并可滚动，不用缩字或截断规避布局。

### 集成修正

1. SelectableText使用inherit:false token后缺textBaseline触发断言：只对正文style补alphabetic，不改正文/选择行为。
2. 新增视觉test一个if缺括号导致analyze非零：补括号，不改测试等待/断言。
3. 删除小字systemRed浅色对比不足：改既有语义危险色；主按钮使用tint+label组合，保留用户主题色。
4. initialTaskId将首条任务定位时会轻微滚动，截图可能采到大标题折叠中间状态；只在截图harness回顶拍摄，不改产品定位导航逻辑。

### 独立审查与最终可读性校准

独立只读审查使用轮次起始patch重建tracked源码后比较，4个tracked生产页面净变化为展示层；未见异步、导航、排序、keys、原文案变化，Rust/reminders等与起点相同。上一轮未追踪helper没有完整起始快照，仅能对照初审片段；不声称字节级完整性证明。

首轮图片中的13–15sp系统secondary灰在白底约3.44:1，关键日期/地点/来源与本机状态说明改本轮局部已有statusInactive动态灰（浅色#4a4f58白底约8.2:1、深色#c4c8d0在#1c1c1e卡片约10:1）。这不是全局AA或所有系统控件状态均已验收的承诺；装饰header、图标、分隔保留系统色。

产品模拟器回归在危险色补丁后通过4项（Today本机完成回读、详情关联编辑与定位、native bridge去重/持久化、原有待办CRUD），未触发真实学校写入。最终辅助文字色补丁通过Today 24项、任务流程30项及各自analyze。用户随后要求适当测试、不再扩测；因此停止新增检查和截图重拍，不重复全量设备测试。

最终危险色版13张截图保存在 `flutter/build/visual/ios-visual-*.png`，已实际核对，但截图仍是辅助文字动态深灰补丁之前，不能作为该最后色值补丁的实图证据；该补丁只由源码/定向测试验证。正常入口ARM64 Debug包另行构建，不交付integration入口。

### 正常入口交付包

- `flutter/build/app/outputs/flutter-apk/ginkgo-ios-visual-debug.apk`，ARM64 Debug，`lib/main.dart`，构建退出码0。未进行签名发布或新增安装验收。
- SHA-256：`e5fd30da175f02df745d76c6a256c6a2a289433ad08748d585f292a6fa974e9a`。

### 验证日志

- `/tmp/ginkgo-visual-delivery-check.log`：最后一次全量gate exit0，202项（最后辅助灰补丁前）。
- `/tmp/ginkgo-ios-visual-final-matrix.log`：13张只读视觉矩阵exit0。
- `/tmp/ginkgo-visual-product-regression.log`：设备原功能4项exit0。
- `/tmp/ginkgo-task-visual-contrast.log`：最后辅助灰补丁任务30项exit0；Today工作包24项exit0。
- `/tmp/ginkgo-visual-normal-apk.log`：正常入口构建。

## 边界

不改Swift Apple应用、Rust、FRB、学校协议或权限，不新增交互功能。模拟器截图/布局测试不等于物理真机TalkBack、全平台逐像素一致、真实账号或签名发布验收。

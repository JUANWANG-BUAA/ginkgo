# Android 工作台、主题与轻动效精修（2026-10-22）

## 结论与交付边界

本轮用户确认先实施“工作台首屏减负、待办列表精简、常用入口置顶并按账号记忆”，随后追加“更多主题色、小巧思及主页面左右翻页动画”。源码已实现；点击底部栏目播放按方向轻移的过渡，不增加整屏左右拖动，避免抢课表横滑或 Android 边缘返回。没有增加七天聚合、通知能力或学校写操作，没有修改 Apple SwiftUI、Rust/FRB 契约、认证、TLS、签名和版本号。

这是未发布工作树，不是公开 APK 或物理真机验收。Android 验证仅使用合成数据/演示服务；没有读取真实凭据或访问学校网络。合成测试构建产物使用 integration_test 入口，不能当作正常入口安装包交付；收尾另执行正常 lib/main.dart 入口的 ARM64 Debug 构建成功，不是签名 Release 或发布验收。

## 用户可感知变化

- 今天页去掉首屏账户卡，保留页头设置；全天课程默认折叠，保留正在/下一节焦点、完整课表入口和独立的作业/待办状态。刷新不重置本页展开状态，账号/服务变化重置。
- 待办保留本机完成主动作与来源，编辑/删除进入可见更多菜单；删除仍二次确认。已完成不再按有/无截止重复分组，统一“已完成（数量）”并默认收起；定位已完成任务时展开。刷新在页头更多菜单，失败重试仍就地显示。
- 常用服务从功能登记表提供候选，用户可选 0–4 项；取消不提交，恢复默认也须保存。普通字号可两列，大字号退单列，控件至少 48dp。移动端的成绩/待办等非一级栏目通过当前导航栈打开，不再只识别五个主栏目。
- 显示与阅读增加湖水青、琥珀金、珊瑚橙、玫瑰红，连同原银杏绿、蓝、紫共 7 组动态深浅强调色。名称、色样和选中标记直接展示，示例课程卡可试按并显示轻量文案；预览不创建课程/提醒。保留原 enum 名称和设备级偏好，不改变业务状态色。
- 移动主栏目索引增大/减小时，从右/左平移 16px、210ms easeOutCubic，透明度 .86→1；初次打开、重复选中静止。原 CupertinoTabScaffold、懒加载、Navigator、筛选和滚动状态保留，不使用复制导航栈的 AnimatedSwitcher。快速切换替换当前动效；系统/应用减少动态效果、停用 ticker 或非活跃生命周期时立即归位，不补播。

## 实现与可靠性

| 文件 | 职责 |
| --- | --- |
| flutter/lib/today_page.dart | 首屏层级、课程折叠、快捷入口集成 |
| flutter/lib/tasks_page.dart | 行菜单、折叠完成项、定位、局部 48dp 手机页头；桌面原页头保留 |
| flutter/lib/workspace_catalog.dart | 候选来自同一登记表，使用稳定 id，不按显示名称持久化 |
| flutter/lib/workspace_shortcuts.dart | 编辑草稿、保存/取消/默认、错误提示与 Sliver KeepAlive；账号变化丢弃旧草稿 |
| flutter/lib/workspace_shortcut_preferences.dart | 按账号 SHA-256 文件名隔离，版本 1 严格校验；未知 id 保留，损坏读锁定编辑；同文件系统暂存后 rename，不先删除旧文件 |
| flutter/lib/app_preferences.dart、preferences_pages.dart、accent_theme_preview.dart | 原偏好兼容、7 色动态配色与可访问预览 |
| flutter/lib/workspace_shell.dart、workspace_tab_transition.dart | 非一级目的地 push、独立单一动画时钟、稳定导航子树与生命周期保护 |

快捷入口演示/未知账号仅内存；不是同步或加密功能。真实账号保存为 workspace-shortcuts-<sha256>.json，SHA-256 只隔离文件名，不宣称加密。读取失败不能编辑，允许显式重试；写失败保留内存旧值与编辑草稿。采用进程内按账号/存储根串行读写，A→B→A 重建的新读取等待旧保存完成，再接受新保存，避免旧写覆盖新设置。该保证不扩展到多进程或任意路径别名写入。

## 实际验证

### 静态与 widget

- 最终 flutter analyze --no-pub：No issues found；flutter test --no-pub test：244 项全部通过，连同 git diff --check 命令链 exit 0。最终验证包含普通窄屏两列主题色样布局；新增色/大字/刷新保留定向 10 项也单独通过。
- 新用例涵盖首页首屏截止可见、展开不新增学校读取、刷新/账号重置、待办菜单与删除确认、完成目标定位、7 色 JSON 兼容与即时语义、320dp/大字深浅、系统/应用减少动态效果、切页方向/连点/生命周期/栈身份/筛选/实际课表横滑及横纵滚动保持。
- 常用入口测试 13 项通过，保留真实临时文件 fixture；包含 0/4 项、取消/默认、未知 ID、损坏读、写失败 UI 与重试、账号切换和 Sliver 离屏草稿/演示选择。额外磁盘串行化测试 1 项通过，受控延迟旧 A 写入→切 B→重建 A→新 A 保存后磁盘为新值。写失败 widget 用例制造目录冲突，证明 UI 保留旧值/可重试，不据此声称所有文件系统故障均已覆盖。
- python3 scripts/check-mirror-architecture.py 通过；check-mirror-architecture-test.py 5 项通过。git diff --check 通过。不修改 Rust，未为本轮重跑完整 Rust clippy/test gate；不能将 Flutter 全套等同完整 check-mirror.sh。

### Android ARM64 模拟器（Android 17 / API 37，emulator-5554）

执行命令（flutter 目录）：

	flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/workspace_polish_test.dart -d emulator-5554
	flutter test --no-pub integration_test/tasks_test.dart integration_test/android_product_iteration_test.dart -d emulator-5554

- 视觉场景 exit 0：合成今天/常用服务展示与编辑/待办/主题预览，浅色琥珀金、深色湖水青；VisualService 写调用断言 0。
- 本机任务与作业链接 4 场景全部通过、exit 0：创建/编辑/完成/重开保留/删除；今天定位待办及返回刷新；作业详情添加并查看关联任务；Rust 本地持久化/防重复且不执行学校写入。
- 正常入口构建 flutter build apk --debug --target-platform android-arm64 完成、exit 0；生成 app-debug.apk（Debug，不改版本/发布证书，未对该最终正常入口包另做覆盖升级验收）。合成调试构建、安装和 bridge 本地往返成功；Gradle/JDK 及跳过不可用 nightly 的警告存在但未阻止验证。模拟器 Debug/截图过程中有启动/GC掉帧日志，不据此宣称性能达标，也不把它视为 release 帧率测量。

截图在忽略目录 flutter/build/visual/，不提交；本轮直接查看合成截图：

- polish-today-light.png：首屏焦点、折叠入口、截止及待办内容，无重复全天课程卡。
- polish-tasks-light.png：本机完成/更多、单一完成数量折叠，不再常驻红色删除。
- polish-appearance-light.png、polish-theme-preview-dark.png：深浅色、两列色样/选中标记与示例卡，无文字溢出；当前不含字号放大的设备截图，大字由 widget 覆盖。
- polish-shortcuts-light.png、polish-shortcuts-dark.png：紧凑展示；polish-shortcuts-edit-*.png 为编辑清单，包含已选数量、原选项语义。局部截图可滚动，非声称全部控件一屏可达。

### 本轮发现并修复

1. 完整课程默认折叠后，历史课程/刷新测试需先展开，再断言原课程仍保留；没有删掉刷新合并/失败保留的断言。
2. Cupertino 原生导航条压缩 48dp 按钮为 44dp，改为待办局部固定手机页头；推入详情且 2x 字号时返回箭头字体固有宽超 48dp，保持按钮自然宽度，修复溢出。
3. widget fixture 在 fakeAsync 直接 await 文件 I/O 卡住：fixture 改同步、生产异步 I/O 用有界条件等待；ensureVisible 后先完成布局再点，启用 hitTest 警告致命检查。
4. 快捷入口旧实例可能在销毁后较晚写盘：独立审查发现后补进程内同账号读写队列及真实临时文件延迟用例。文件队列不阻止不同账号独立保存。

## 保留边界

没有发布、提高 minBuild、改签名/证书或做覆盖升级。Windows 保持共用 Flutter 兼容与既有合成导航回归，但本轮没有 Windows 实机/打包测试；Apple UI 没改。物理 Android 的 TalkBack、系统预测返回/边缘手势、真实刷新与通知、低端机帧率/长列表仍未验收，统一保留在 MIRROR-TODO.md。本机完成不是学校提交，状态与说明未合并。后续七天安排、完整待办提醒、日历导出不在本次范围。

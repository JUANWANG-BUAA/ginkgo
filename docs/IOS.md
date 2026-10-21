# Ginkgo iOS 子项目说明

## 1. 定位

`BUAA-Assistant-iOS/` 是 Ginkgo 的原生 iOS 子项目，目标不是另起一套校园客户端，而是：

1. 复用 macOS 主项目的 CAS、业务客户端、模型、解析器、缓存和 ViewModel；
2. 在保持功能语义一致的前提下，为 iPhone/iPad 提供触屏优先的信息架构；
3. 用 XcodeGen 声明工程，使 iOS 工程配置可审查、可重复生成；
4. 明确区分“已编译”与“真机已验收”，不把 macOS 经验当成 iOS 验收证据。

当前基线：iOS 17.0+，Xcode 16+，SwiftUI + URLSession + Keychain，无第三方运行时依赖。iOS 页面层已改为独立原生 SwiftUI，业务层与 macOS 共享。

> 本文只定义 Apple iOS 子项目的复用边界、原生交互和验收要求，不约束 Android/Windows 镜像项目的 Flutter 页面；后者见 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)。

## 2. 目录

```text
BUAA-Assistant-iOS/
├── project.yml                         # 工程唯一声明源
├── Ginkgo-iOS.xcodeproj                # XcodeGen 生成产物，可直接打开
├── Sources/
│   ├── GinkgoiOSApp.swift              # @main、通知代理
│   ├── IOSRootView.swift               # 会话恢复、登录态切换、toast
│   ├── IOSMainView.swift               # iPhone TabView / iPad SplitView
│   ├── IOSSettingsView.swift           # iOS 原生 Form 设置页
│   ├── IOSStoragePolicy.swift          # 本地缓存排除 iCloud 备份
│   └── Native/                         # 独立原生 iOS 页面层
│       ├── IOSLoginView.swift
│       ├── IOSTodayView.swift
│       ├── IOSScheduleView.swift
│       ├── IOSGradeView.swift
│       ├── IOSHomeworkView.swift
│       ├── IOSLibraryView.swift
│       ├── IOSClassroomView.swift
│       ├── IOSCheckInView.swift
│       └── IOSTasksView.swift
└── Resources/
    ├── Assets.xcassets                 # iOS AppIcon / AccentColor / LaunchBackground
    ├── PrivacyInfo.xcprivacy           # 隐私清单与 required-reason API
    └── Info.plist                      # 工程生成
```

共享代码仍位于仓库根目录 `BUAA-Assistant/`。业务代码不向 `BUAA-Assistant-iOS/` 复制，避免两端协议和修复漂移。

## 3. 跨平台边界

### 3.1 直接复用

- Core：`APIClient`、`WebVPNRouter`、日志、Keychain、Cookie 清理、`LocalStore`/`SnapshotCache`、`SchoolTime`、`JSONValue`、`HTMLText`、`FormURLEncoding`、`AESCipher`、`AutoRefreshGate`。
- Auth：CAS 客户端、表单/页面解析器、`AppState`、跨平台 `AuthViewModel`、响应式 `LoginView`。
- Features：课表、成绩、作业、图书馆、空教室、签到、校园通知的业务模型、客户端、解析器、缓存与 ViewModel。
- 本地待办业务存储。
- 平台无关的颜色/图片适配（`CrossPlatformSupport.swift`）、状态展示口径（`StatusPresentation.swift`）、Keychain、Cookie 与日志。
- 工作区编排：`WorkspaceHost` 创建 `WorkspaceCoordinator`，两个应用壳共用 `WorkspaceLifecycleModifier` 处理签到轮询、课程提醒、WebVPN、前后台/网络恢复刷新与账号切换。
- 共享 XCTest 源码；iOS test target 将 `BUAA-AssistantTests/` 作为测试源。

### 3.2 macOS 专属

以下文件从 iOS target 排除：

- `BUAAAssistantApp.swift`：包含菜单栏常驻、窗口默认尺寸与 macOS commands。
- `RootView.swift`、`MainView.swift`：以 `NavigationSplitView` 和 macOS 窗口假设为主的应用壳。
- `Features/Auth/LoginView.swift`：macOS 双栏登录页面；iOS 使用 `Native/IOSLoginView.swift`。
- macOS 功能 View（今天、课表/网格/考试、成绩、作业、图书馆、空教室、签到、待办、校园通知、博雅、研究生教务、CGYY）从 iOS target 整体排除；对应的 ViewModel、模型、解析器和缓存仍在共享源码中编译，由 iOS 页面使用 `Sources/Native/` 的 `List` / `Form` / `NavigationStack` 实现界面。
- `Core/UI/PageComponents.swift`、`Core/UI/MacViewModifiers.swift`：macOS 页面组件与指针交互修饰符；iOS 使用系统原生控件。
- `Core/Keyboard/GlobalShortcutController.swift`：Carbon 全局快捷键。
- `Core/LaunchAtLogin/LaunchAtLoginController.swift`：`SMAppService`。
- `Core/Notification/AppNotificationDelegate.swift`：`NSApp` 窗口路由。
- `Features/Settings/SettingsView.swift`：macOS 登录项、自更新、窗口背景等专属设置。
- macOS AppIcon 资源。

### 3.3 新增跨平台适配层

`Core/UI/CrossPlatformSupport.swift` 只保留两端都需要的内容：

- macOS/iOS 语义色：窗口、侧栏、卡片、输入框、分隔线。
- `NSImage` / `UIImage` 通过 `GinkgoPlatformImage` 和 `Image(ginkgoPlatformImage:)` 切换。

macOS 专属的 `onHover`、`onExitCommand`、`.buttonStyle(.link)`、页面内边距与弹层尺寸集中在 `Core/UI/MacViewModifiers.swift`，并从 iOS target 排除；不再用编译期空实现维持共享视图。

### 3.4 更新中心

`UpdateCenter` 保留可测试的下载源选择和 checksum 解析逻辑供两端测试复用，但只有 macOS 编译安装应用包、`Process`、`NSWorkspace` 等实现。iOS 端不提供应用内自更新；分发应走 App Store/TestFlight。

## 4. iOS 信息架构

### 4.1 iPhone

使用系统原生底部 `TabView`：

1. 今天
2. 课表
3. 作业
4. 图书馆
5. 更多

页面统一采用 `NavigationStack + List/Form + Section`；工具栏使用系统按钮和 Menu，列表支持 `.searchable`、`.refreshable`、`swipeActions` 和原生确认对话框。“更多”内的课程签到、成绩、空教室、待办、设置均有独立原生页面。

### 4.2 iPad / regular width

使用原生 `NavigationSplitView` 和可选 `List(selection:)` 侧栏，按「工作台 / 学习 / 校园 / 设置」分组展示十二个功能入口，并新增研究生教务、博雅和教学楼研讨室（CGYY）三个原生页面；CGYY 含预约、订单与门锁密码，图书馆“我的预约”含签到入座、临时离开与完全离开。选择侧栏后详情区立即切换，选中行使用系统 accent 高亮；详情区使用 `NavigationStack`，避免出现 iOS 双层导航样式。

### 4.3 登录

- iOS 使用原生 `Form`，系统键盘、密码自动填充提示与焦点链。
- 品牌标识放在 Form 顶部，不再复用 macOS 双栏/大卡片布局。
- 验证码图片在 Form 中展示；失败后清空 CAS execution 与验证码状态。
- Keychain 读取仍受 5 秒超时保护，避免启动阻塞。

## 5. 数据与隐私

- 密码只在用户勾选“记住密码”后写入 Keychain，使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。
- Cookie 与会话不写入明文文件；WebVPN 隔离 Cookie 仅在进程内。
- 课表、成绩、作业、座位、签到历史等查询快照保存于应用沙盒 `Application Support`，按账号 SHA-256 摘要隔离。
- 个人待办当前仍使用 `UserDefaults`；iOS 启动时把 Application Support 根目录标记为 `isExcludedFromBackup`，因此查询快照会排除系统备份，但 UserDefaults 中的待办/偏好尚未纳入该策略，需在统一存储层迁移后补齐。
- `PrivacyInfo.xcprivacy` 声明不跟踪、不收集数据，并列出 UserDefaults 与文件时间戳 required-reason API。
- 应用不经过第三方服务器；学校公开页面读取与上游业务请求均从设备直连。

## 6. 构建与验证

生成工程：

```sh
cd BUAA-Assistant-iOS
xcodegen generate --spec project.yml
```

编译 iOS：

```sh
xcodebuild build \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

编译 App + XCTest bundle：

```sh
xcodebuild build-for-testing \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

### 关于 `iPhone Duo`

这不是项目指定了 Duo，而是 Xcode 27.1 的 iOS 27.1 Runtime 的 `supportedDeviceTypes` 只注册了特殊多屏设备 `iPhone Duo`。普通 iPhone 17 Pro、iPhone SE 与 iPad 需要标准 iOS 27.0 Runtime（或与 Xcode 16 匹配的 iOS 18 Runtime）。执行 `xcrun simctl list runtimes --json` 可以核对每个 Runtime 支持哪些设备类型。

运行模拟器测试需要本机安装对应 Simulator Runtime：

```sh
# 先用 xcrun simctl list devices available 选择一个 UDID
xcodebuild test \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>'
```

### 6.1 当前验证证据

| 检查 | 结果 | 备注 |
|---|---|---|
| macOS Debug build | 通过 | Xcode 27.1 |
| macOS XCTest | 212 项 / 0 失败 | 网络路线、CAS 4xx/483、共享存储/解析与工作区回归 |
| iOS generic device build | 通过 | CODE_SIGNING_ALLOWED=NO |
| iOS build-for-testing | 通过 | 212 项单元测试源码成功编译 |
| iOS 模拟器 XCTest | 212 项 / 0 失败 | iOS 27.0 Runtime |
| iOS UI 测试 | iPhone 17 Pro / iPhone SE / iPad Pro 11 通过 | 登录、Tab/侧栏、博雅/研究生教务/CGY 入口与设置；1 项真实账号测试在未注入凭据时跳过 |
| iPhone 真机运行 | **未执行** | 模拟器不能替代真机 |
| iOS 写操作 | **未执行** | 预约/取消与签到必须真机逐项确认 |
| 真实账号会话 | 通过 | 直连 UC 被 483 拦截后自动切换 WebVPN，CAS 登录成功，`uc/status` 返回 `code == 0 + data` |
| WebVPN 只读业务 | 通过（Mac 集成测试 + iPhone live UI） | 研究生课表 30 周/7 门、博雅 74 门课程、研讨室 45 个空间、研究生教务 10 章方案/59 门课程、成绩服务、空教室、图书馆、通知、SPOC 与 iclass；Judge 仍待适配 |
| 隐私清单打包 | 通过 | 已检查 `Ginkgo.app/PrivacyInfo.xcprivacy` |
| AppIcon | 通过 | 产物含 iPhone/iPad 图标 |

> “构建通过”只证明编译与链接；“功能可用”必须在 iPhone/iPad 上和真实上游做人工验收。

### 6.2 原生 UI 对齐检查表

当前 iOS 页面层按 Apple HIG 使用系统组件，而不是给 macOS 页面换皮：

- **网络**：登录页 toolbar 与设置页使用原生 Menu/Picker 切换自动、直连、WebVPN；切换后清空旧会话并要求重新登录。
- **导航**：iPhone 用原生 `TabView`；iPad 用 `NavigationSplitView`；每个功能页用 `NavigationStack`。
- **内容**：列表/设置使用 `List`、`Form`、`Section`、`LabeledContent`、`ContentUnavailableView`；不使用桌面固定宽度卡片。
- **操作**：刷新使用 toolbar 按钮或 `.refreshable`；学期/筛选使用 Menu；危险操作使用 `confirmationDialog` / alert。
- **输入**：系统 TextField/SecureField/DatePicker，启用键盘类型、自动填充提示、焦点链和 `.scrollDismissesKeyboard`。
- **适配**：使用系统语义色、Dynamic Type 文本样式和 safe-area；不再依赖固定 500/600 pt sheet 宽度。
- **列表能力**：`.searchable`、`.swipeActions`、分页“显示更多”、原生空状态和错误状态。
- **无障碍**：所有图标按钮、写操作按钮和状态标记均提供可读标签；写操作保留二次确认。

“一比一对齐”的验收标准应是以上行为和系统组件的一致性，以及在小屏/Pro Max/iPad/动态字体/VoiceOver 下无截断和误触，而不是仅依赖像素截图。

## 7. 已知限制

1. 页面层已原生化，但还没有在真机执行最大动态字体、VoiceOver、横屏/分屏、Reduce Motion 与浅深色全流程验收。
2. UI 测试当前覆盖登录输入、五个主 Tab、更多页和 iPad 侧栏导航；尚未覆盖通知权限、缓存清理确认、搜索结果、分页、错误重试和写操作确认。
3. 已支持自动/直连/WebVPN，但没有移植 UBAA 的 ServerRelay（本项目不运行自建中转服务器）。
4. WebVPN 下登录、研究生课表、成绩、空教室、图书馆座位、校园通知、SPOC 与 iclass 只读链路已在 Mac 集成测试中验证；iOS 真机上的同链路仍需人工复测。Judge 课程列表结构仍待适配。
5. 应用内自更新、全局快捷键、登录项、菜单栏面板属于 macOS 专属能力。
6. 后台轮询不能保证：iOS 进入后台后签到轮询和官网人数刷新会暂停；当前没有 `BGTaskScheduler`、Push 或 Live Activity。
7. App Store 签名、TestFlight、隐私标签、审核说明和 iOS 发布流水线尚未配置。
8. 图书馆座位签到/临时离开/完全离开、CGYY 预约/取消/门锁密码尚未在 iOS 真机做真实往返验收；结果不确定时只回查，不自动重发。

## 8. 下一阶段出口标准

- 真机完成 iPhone SE、Pro Max、iPad 横竖屏、动态字体、VoiceOver 与浅深色验收。
- 在 iOS 真机的直连与 WebVPN 两种路线下复测课表、成绩、作业、图书馆只读链路。
- 图书馆预约/取消与签到写入逐项人工确认，并记录不自动重发证据。
- 扩展 UI Test：通知权限、缓存清理、搜索结果、分页、错误重试与确认对话框。
- `.github/workflows/ios.yml` 已在仓库中声明 iOS device build 与 Simulator XCTest；等待首次远端运行并固定 Runner/Xcode/Runtime 证据。
- TestFlight 内部测试包完成签名与至少一轮外部反馈。

## 2026-10-19 · 教务学分地图

研究生教务首页复用共享 `GraduateRequirementDashboard`，按类别/课组展开学校修读记录；支持窄屏排列、搜索与需关注筛选。课程池和方案原文移到单独标签页；缺口不抵扣在修或待考核。分项失败可见并保留缓存，来源成功时间单独保留。iPhone SE 模拟器相关 43 项回归通过，真实账号新页面交互仍待人工验收。

图书馆仅提供座位预约；教学楼研讨室使用 `IOSCgyyView`，历史 `IOSSeminarView` 不在产品导航中且提交已停用。

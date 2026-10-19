# Ginkgo iOS

Ginkgo 的 iOS 子项目：复用北航校园服务的客户端、模型、网络层、缓存和 ViewModel，并为 iPhone/iPad 提供完全原生的 SwiftUI 界面层。

## 快速开始

要求：

- Xcode 16+（当前已在 Xcode 27.1 / iOS 27.0 SDK 验证编译和模拟器测试）
- iOS 17.0+
- 重新生成工程时需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+

直接打开：

```sh
open BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj
```

选择 `Ginkgo-iOS` scheme 和任意 iPhone/iPad 模拟器运行。仓库保留了生成后的 `.xcodeproj`；修改 `project.yml`、增删文件后重新生成：

```sh
cd BUAA-Assistant-iOS
xcodegen generate --spec project.yml
```

命令行编译（无需签名）：

```sh
xcodebuild build \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

同时编译 App 与 XCTest bundle：

```sh
xcodebuild build-for-testing \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

在已安装 iOS Simulator Runtime 的开发机上执行测试：

```sh
# 先用 xcrun simctl list devices available 选择一个 UDID
xcodebuild test \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>'
```

当前环境已安装标准 iOS 27.0 Runtime，并已在 iPhone 17 Pro、iPhone SE (3rd generation) 和 iPad Pro 11 上完成 UI 冒烟测试。不要只安装 iOS 27.1 Runtime：当前 Xcode 27.1 的 27.1 Runtime 只注册了特殊多屏设备 `iPhone Duo`，普通 iPhone/iPad 应使用 27.0 Runtime。

## 信息架构

- **iPhone**：底部五个主标签为「今天 / 课表 / 作业 / 图书馆 / 更多」；「更多」中提供课程签到、研究生教务、博雅、成绩、研讨室、空教室、待办和设置。
- **iPad 与 regular width**：使用与 macOS 一致的 `NavigationSplitView` 侧栏，保留十二个功能入口。
- **登录**：原生 `Form`、系统键盘、密码自动填充提示、验证码图片和无障碍标签；不是 macOS 双栏页面的缩放版。
- **网络路线**：登录页工具栏与设置页可选择自动、直连或 WebVPN；自动模式在 UC 返回 HTTP 483 时切换 WebVPN 重试。
- **通知**：课程前提醒与签到状态提醒共用系统通知权限；iOS 通过 `UNUserNotificationCenterDelegate` 在应用前台显示 banner。

## 代码复用

iOS target 直接编译 `BUAA-Assistant/` 下的共享代码，同时排除仅适用于 macOS 的应用壳和系统集成：

- `BUAAAssistantApp.swift`、`RootView.swift`、`MainView.swift`
- 全部 macOS 功能页面（Today、Schedule、Grade、Homework、Library、Classroom、CheckIn、Tasks、CampusNotices、Bykc、GraduateAcademic、Cgyy）
- `Core/Keyboard`、`Core/LaunchAtLogin`、`Core/Notification`
- `Core/UI/PageComponents.swift`、`Core/UI/MacViewModifiers.swift`
- `Features/Settings/SettingsView.swift`
- macOS 专属 AppIcon 资源

两个壳共享 `WorkspaceHost`、`WorkspaceCoordinator` 与 `WorkspaceLifecycleModifier`：工作区持有全部 ViewModel，签到轮询、课程提醒、WebVPN 状态与前后台/网络恢复刷新只实现一次。

iOS 自己提供：

- `Sources/Native/IOSLoginView.swift`：原生 Form 登录页与键盘自动填充提示
- `Sources/IOSMainView.swift`：iPhone 原生 TabView / iPad `NavigationSplitView` 自适应壳
- `Sources/Native/IOSTodayView.swift`：`List`/`Section` 今日工作台
- `Sources/Native/IOSScheduleView.swift`：原生课表、考试与课程详情
- `Sources/Native/IOSBykcView.swift`：原生博雅课程库、已选课程、完成统计与课程详情
- `Sources/Native/IOSCgyyView.swift`：教学楼研讨室预约、订单与门锁密码；图书馆仅提供座位预约，图书馆研讨间代码已删除
- `Sources/Native/IOSGraduateAcademicView.swift`：共享原生学分地图、类别/课组缺口、课程与原文、成绩及学籍服务目录
- `Sources/Native/IOSGradeView.swift`：原生成绩列表、学期 Menu 与 searchable
- `Sources/Native/IOSHomeworkView.swift`：原生作业列表与 NavigationLink 详情
- `Sources/Native/IOSLibraryView.swift`：原生预约 Form/List、座位、预约记录与趋势详情
- `Sources/Native/IOSClassroomView.swift`：原生查询 Form、结果分组与教室详情
- `Sources/Native/IOSCheckInView.swift`：原生签到状态与历史查询
- `Sources/Native/IOSTasksView.swift`：原生待办 List、sheet 编辑与 swipeActions
- `Sources/IOSSettingsView.swift`：原生 Form 设置页；不支持 macOS 自更新与登录项
- `Sources/IOSStoragePolicy.swift`：将本地校园缓存排除出 iCloud/iTunes 备份

macOS 功能 View 只保留给 macOS；iOS 页面层全部是独立的原生 SwiftUI。业务 ViewModel、CAS、课表/成绩/作业/图书馆/空教室/签到客户端与数据模型继续共享。

## 平台差异

| 能力 | macOS | iOS |
|---|---|---|
| 导航 | 侧栏主窗口 + 菜单栏面板 | iPhone TabView；iPad 侧栏 |
| 登录与缓存 | 共享 | 共享 |
| 课程/成绩/作业/图书馆/空教室/签到 | 共享业务 | 独立原生 iOS 页面，共享业务与 ViewModel |
| 博雅 / 研讨室 / 研究生教务 | 共享只读客户端 | 独立原生 iOS List、Picker、searchable、DisclosureGroup 与空状态 |
| 网络路线 | 支持 | 自动 / 直连 / WebVPN，可在登录页和设置切换 |
| 课程提醒 | 本地通知 | 本地通知；前台 banner |
| 全局快捷键 / 登录项 / 应用内自更新 / 菜单栏 | 支持 | 不适用 |
| 数据位置 | Application Support + Keychain | Application Support + Keychain，备份排除 |
| 隐私清单 | 暂未配置 | `PrivacyInfo.xcprivacy` |

## 当前验证

- macOS：212 项 XCTest 全绿。
- iOS 单元测试：212 项、0 失败。
- iOS UI 测试：3 项中 2 项常规通过、1 项真实账号测试在未注入凭据时跳过。
- iPhone 17 Pro、iPhone SE (3rd generation)、iPad Pro 11：原生 UI 冒烟测试通过。
- 产物包含 iOS AppIcon、AccentColor、LaunchBackground、PrivacyInfo.xcprivacy。
- 真实账号会话测试：直连 UC 返回 HTTP 483「访问策略禁止」后，自动切换北航 WebVPN 并完成 CAS 登录，`uc/status` 返回 `code == 0 + data`，会话已验证有效。
- WebVPN 业务只读验证：研究生课表（30 周、7 门课程）、成绩、空教室、图书馆座位、校园通知、SPOC（13 项作业）与 iclass 均可访问。
- 新增页面 live UI 验证：博雅读回 74 门课程；研究生教务读回学籍摘要、培养方案与课程数据。图书馆研讨间只读链路已停止提供，教学楼 CGYY 写入待验收。

## 可选真实账号验收

`GinkgoSmokeUITests.testLiveSessionWhenCredentialsProvided` 默认跳过；只有维护者手动把账号与密码放入**模拟器进程环境**时才会执行。不要写入源码、shell 脚本、xcodebuild 参数、Simulator scheme 或版本库。

```sh
UDID="<SIMULATOR_UDID>"
xcrun simctl spawn "$UDID" launchctl setenv GINKGO_LIVE_USERNAME '<学号>'
xcrun simctl spawn "$UDID" launchctl setenv GINKGO_LIVE_PASSWORD '<密码>'

xcodebuild test \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:GinkgoiOSUITests/GinkgoSmokeUITests/testLiveSessionWhenCredentialsProvided

xcrun simctl spawn "$UDID" launchctl unsetenv GINKGO_LIVE_USERNAME
xcrun simctl spawn "$UDID" launchctl unsetenv GINKGO_LIVE_PASSWORD
xcrun simctl uninstall "$UDID" com.buaaassistant.app.ios
```

测试只会输入凭据并点击登录，不勾选“记住密码”，不执行签到、预约或其他写操作。`xcresult`、失败截图和录屏可能包含账号与个人数据，验收后应删除，不得提交仓库。

## 真机验收清单

1. CAS 登录、验证码、Keychain 记住密码与重启恢复。
2. 小屏 iPhone 的登录、动态字体、深色模式与横屏。
3. 课表/成绩/作业/图书馆密集页面的可读性、双指缩放取舍与滚动性能。
4. 签到/图书馆预约等写操作的用户确认、失败反馈与不自动重发。
5. 通知权限、课程提醒、签到状态通知与前台展示。
6. iPad 分栏、旋转、多任务窗口和键盘交互。
7. iCloud 备份中不出现本地缓存；卸载后 Keychain 行为符合预期。
8. App Store 分发前的隐私标签、签名、TestFlight 与审核说明。

更完整的架构说明和优先级见仓库 `docs/IOS.md` 与 `docs/IMPROVEMENTS.md`。

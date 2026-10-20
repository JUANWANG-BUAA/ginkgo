# BUAA Assistant - 架构设计文档

## 当前实现说明（2026-10-20）

本文件包含目标架构与历史设计示例，不能据此推断所有能力已经实现。当前模块为 Auth、Today、Schedule、Grade、Homework、Library、Classroom、CheckIn、Tasks、Settings，并新增 BYKC、GraduateAcademic 与研讨室只读数据模型；入口与全局状态仍在源码根目录。2026-10-17 新增 `BUAA-Assistant-iOS/` 子项目，2026-10-18 进一步将其页面层改为独立原生 SwiftUI：iOS 壳、资源、登录与十二个功能入口全部位于 `BUAA-Assistant-iOS/Sources/`，只共享 CAS、网络、模型、解析器、缓存和 ViewModel。跨平台语义色与平台图片适配集中在 `Core/UI/CrossPlatformSupport.swift`。Apple 两端当前仍是“共享源码 + target membership”的过渡结构；`GinkgoCore` Swift Package 是 Apple 工程内部可选的模块化改进，不是 Rust + Flutter 镜像项目的前置条件。跨语言边界以 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) 为准，优先级见 [IMPROVEMENTS.md](IMPROVEMENTS.md)。

- 网络：APIClient 提供共享 Cookie 的普通会话与禁止自动重定向的认证会话；CasClient、ScheduleClient、GradeClient、LibraryClient、ClassroomClient 分别接入上游。图书馆业务 token 仅保存在 LibraryClient 内存；官网实时空间数据由独立的 `LibraryPublicStatsClient` 通过无 Cookie ephemeral 会话只读获取。
- 状态：`WorkspaceHost` 创建 `WorkspaceCoordinator` 并持有全部模块 ViewModel，macOS `MainView` 与 iOS `IOSMainView` 通过共享的 `WorkspaceLifecycleModifier` 处理签到轮询、WebVPN 会话、课程提醒、前后台/网络恢复刷新与 UC 会话复核；切换页面不重建同步状态，账号切换时整个工作区随 `.id(account)` 释放。签到页将 iclass 业务拒绝与学校 CAS 失效分开，并限制 session 刷新回查次数。课表、考试、空教室、成绩、学校作业和 BYKC 已建立对应 Repository 边界，ViewModel 不再直接依赖上游客户端与磁盘缓存；签到、校园通知和研究生教务仍待收敛。
- 存储：凭据可选保存到钥匙串；课表、考试、成绩、作业、图书馆、空教室和签到快照使用 Codable JSON 文件，个人数据文件名按账号 SHA-256 摘要隔离；摘要不是内容加密。课表快照可含已查询周次，空教室最多保留 12 组校区/日期结果，考试最多保留 12 个学期，签到缓存当天状态和最多 180 个历史日期。校园通知缓存最近 5 条公开内容。图书馆最多缓存 2,000 个座位；图书馆分区余量与官网人数另按本机小时聚合，不含账号或座位标识，最多保存 60 天/4,000 条。设置可清理查询快照及图书馆聚合历史，不删除个人待办。尚未实现 SwiftData 或完整的多学期成绩仓库。
- 界面：NavigationSplitView 的导航为今天、课程签到、课表、成绩、研究生教务、学校作业、博雅、图书馆、研讨室、空教室、待办、设置。研究生教务与博雅只读展示白名单/课程数据；研讨室为教学楼 CGYY 预约、订单与门锁密码（自动滑块识别需用户确认）；图书馆研讨间代码已于 2026-10-19 瘦身时整体删除（协议资料仍见 API.md / EDUCATION-DATA-MAP）；图书馆“我的预约”分为进行中与历史并支持座位签到/暂离/完全离开。主窗口默认 1200 × 800 pt，最小 800 × 560 pt。课表网格使用 TimetableLayout 分配重叠课程栏位；同日同课、同教室的连续节次合并，保留教师差异供详情查看。周网格保留可读的最小日列宽，不够时横向滚动，SemesterOverview 显示查询覆盖范围。macOS 课表、成绩、学校作业和博雅统一使用 `AcademicPageHeader`、`AcademicSectionHeading` 与摘要/列表分层；详细视觉规则及未验收项见 [UI-DESIGN.md](UI-DESIGN.md)。
- 图书馆预约自动定位北航时区当前时段；预约端分区数据展示空闲/总座位并按本机历史估算不可预约座位数量。官网公开数据另提供两校区在馆人数和沙河特色阅览室人数；人数按校区/日期/小时采样，趋势及估算基于相同星期和时段的本机历史均值，不能推断官网未提供的楼层人数，也不等同于官方预测。
- 快捷键：全局快捷键由 Carbon `RegisterEventHotKey` 注册，⌃⌥B 用于恢复并聚焦主窗口；默认关闭，可从应用菜单启停，偏好保存在本机 UserDefaults。
- 启动：设置页使用 `SMAppService.mainApp` 注册或注销当前应用登录项；批准状态以 macOS Service Management 为准，可跳转系统登录项设置。
- 通知：课程前提醒默认关闭，由 `CourseReminderScheduler` 从已缓存周次安排未来 14 天的本地通知；本科只覆盖已查询周次。课程通知使用独立 identifier 前缀，刷新/关闭/登出仅清理本应用的课程提醒；通知正文不包含课程名和地点。点击时由 `AppWindowRouter` 聚焦已有主窗口，或在窗口关闭时重新打开主窗口。
- 边界：图书馆提交与取消、课程签到均需用户主动触发且不自动重发；签到写协议仅按 BBAA 源码移植，尚待真实上游往返验收。AppIcon 资源和 target 绑定已接入，Dock/Finder 显示仍待人工确认。学校作业同步、课程前通知和签到状态通知已接入，仍需分别做真实账号/通知投递验收；研讨室只读分类、45 个空间与逐时空档已接入；预约/取消等写路径和后台监测仍未完成。

构建与测试证据见 TESTING.md，真实观察和待验收范围见 ACCEPTANCE.md。

### 2026-10-19 · 瘦身与共享编排

图书馆研讨间未挂载的页面、ViewModel、解析器和只读 API 已删除，产品范围保持“图书馆仅座位预约”；协议资料保留在 API.md / EDUCATION-DATA-MAP。通用能力收敛到 `Core/`：`LocalStore`/`SnapshotCache`（11 个手写缓存）、`SchoolTime`、`JSONValue`、`HTMLText`、`FormURLEncoding`、`AESCipher`（4 处 AES 实现）、`AutoRefreshGate`、`CasPageParser.isLoginRedirect`、`StatusPresentation`、`GraduateCredit`。两个应用壳共用 `WorkspaceHost` / `WorkspaceCoordinator` / `WorkspaceLifecycleModifier`；iOS target 不再编译 macOS 功能页面、`PageComponents` 与 `MacViewModifiers`，其死代码式的紧凑布局分支随之删除。iOS 页面此前各自持有的博雅/研究生教务 ViewModel 改由工作区统一持有，设置页清理缓存补上这两个模块。macOS 与 iOS 测试 212 项通过。

### 2026-10-19 · 教务要求树与预约范围更正

研究生教务首页改为共享的 `GraduateRequirementDashboard`，基于 `GraduateRequirementBuilder` 保留“总要求 → 类别 → 课组 → 修读记录”的层级。每层分别计算要求减已获，不累加父子缺口，不将待考核/在修计入已获。校企课程与分阶段培养作为独立约束；合并要求保留原文。查询快照记录分项错误与成功时间，部分刷新失败保留对应旧数据。缓存使用原目录内的版本 2 envelope，旧语义快照不再读入，下次成功刷新覆盖。

图书馆产品范围仅为座位预约，维护者已验证可行；历史 seminar 提交已停用。教学楼 CGYY 补齐有界 WebVPN 登录与统一路由，认证后仅 GET 可重查；预约/取消结果未知时暂停重复操作，要求核对订单。真实 CGYY 写操作仍待人工验收。

### 2026-10-19 · 空教室数据边界拆分

默认仓库由共享工作区入口 `WorkspaceCoordinator` 组装，`ClassroomViewModel` 只接收仓库接口。

新增 `ClassroomRepository` 协议，由默认实现组合上游 `ClassroomServing` 与本地 `ClassroomCache`；`ClassroomViewModel` 通过仓库读取快照、查询、保存和清理缓存。搜索索引、筛选与排序移至独立的 `ClassroomResults.swift`，不依赖 SwiftUI 或数据获取。此处作为后续按功能迁移 Repository 边界的参考；缓存新鲜度和页面状态仍由 ViewModel 编排。

### 2026-10-19 · 成绩数据边界拆分

新增 `GradeRepository`，将学期发现、成绩查询和账号快照存取组合到默认仓库。`GradeViewModel` 只处理学期选择、刷新节流、页面状态与错误呈现；设置页通过 ViewModel 清理缓存。

### 2026-10-19 · 课表数据边界拆分

新增 `ScheduleRepository`，组合课表上游服务和账号快照读写。`ScheduleViewModel` 只依赖仓库；macOS/iOS 设置页及菜单栏摘要不再直接实例化 `ScheduleCache`。

课表快照的缓存周次选择与同学期已知周次保留提取为 `ScheduleSnapshot` 的纯值操作。ViewModel 负责加载状态、刷新并发与缓存提交，不再直接拼装快照内容；跨语言行为由 `fixtures/schedule/week-snapshot-v1.json` 固定。

### 2026-10-19 · 考试数据边界拆分

新增 `ExamRepository`，将考试上游查询、按账号/学期缓存与清理集中到仓库。`ExamViewModel` 只依赖仓库并保留缓存回退、新鲜度与页面状态编排。

### 2026-10-19 · 学校作业数据边界拆分

新增 `HomeworkRepository`，将作业快照读取/保存、上游加载、可选详情加载与账号缓存清理集中到默认仓库。`HomeworkViewModel` 只依赖仓库；macOS/iOS 设置页通过 ViewModel 清理缓存，不再直接创建 `HomeworkCache`。刷新节流、页面状态和错误呈现仍由 ViewModel 负责。

### 2026-10-19 · Rust + Flutter 镜像准备

按 Rust + Flutter 镜像方向开始整理跨语言边界；当前假设覆盖 Android/Windows，Apple 继续使用 SwiftUI。应用不运行自建 HTTP 后端：Flutter 经粗粒度绑定调用 Rust 完整用例，协议、Cookie 会话、缓存与业务规则留在 Rust core；API.md 仍是上游协议事实源。新增版本化 fixture 约定，并将空教室排序枚举改为稳定 wire code、将中文标题移至独立 presentation adapter。详细范围见 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)。

### 2026-10-20 · BYKC 数据与课程目录边界

新增 `BykcRepository` / `BykcServing`：仓库组合 BYKC 上游服务与按账号隔离的快照缓存，`BykcViewModel` 负责页面状态、缓存回退与账号生命周期；macOS 与 iOS 设置页都通过 ViewModel 清理 BYKC 缓存。上游 token、加密信封和请求解析仍留在 `BykcClient`，本次没有改变学校协议或快照存储格式。

课程目录过滤抽到无界面的 `BykcCourseCatalog`。`BykcCourseFilter` 使用 `all` / `named` / `unclassified` 类别选择，不把本地化标签作为规则值；分类计数、空类别归一化和定 locale 的大小写不敏感搜索都有确定性测试。`BykcSemesterPolicy` 将学期选择从网络 actor 分离；“全部/未分类”和人数格式移到 `BykcCoursePresentation`。共享合成契约见 `fixtures/bykc/course-filter-v1.json`，供未来 Rust 实现直接复用。

### 2026-10-20 · macOS 教务界面层级

新增 macOS 页面组件 `AcademicPageHeader`、`AcademicSectionHeading`、`AcademicMetricStrip` 和 `academicPanel`；它们使用语义色、轻分组和一致的标题层级，不引入跨平台 UI 依赖。成绩页按“学期/新鲜度 → 汇总指标 → 统计口径 → 课程成绩”组织；作业状态计数与状态筛选联动，结果采用连续行；博雅摘要不再将统计网格嵌入整个内容大卡片；课表把学期、周次控件放在同一分组。`ProgressiveList` 新增默认值兼容的行距参数。代码实现不代表浅/深色、窄窗口和 VoiceOver 的真实设备验收已经完成。

## 1. 项目概述

### 1.1 定位
北航校园服务聚合 macOS 原生客户端，提供菜单栏快捷访问、系统通知、快捷键等原生体验。

### 1.2 目标用户
北航在校学生（ primarily 研究生），使用 macOS 作为主力开发环境。

### 1.3 核心价值
- **原生体验**：菜单栏常驻、系统通知、快捷键、深色模式
- **轻量快速**：~5MB 包体，低内存占用
- **隐私安全**：本地存储凭据，不经过第三方服务器
- **可扩展**：模块化设计，易于添加新功能

---

## 2. 技术选型

### 2.1 核心技术栈

| 层级 | 技术 | 版本 | 理由 |
|------|------|------|------|
| UI 框架 | SwiftUI | 5.0+ | 声明式 UI，热重载快 |
| 最低系统 | macOS 14.0 | Sonoma | SwiftData 支持 |
| 语言 | Swift | 5.9+ | 类型安全，现代语法 |
| IDE | Xcode | 16+（工程为文件系统同步格式；本机 27.0 实测） | 官方工具链 |
| 本地存储 | SwiftData | - | 原生 ORM，与 SwiftUI 深度集成 |
| 网络 | URLSession | - | 系统原生，无需第三方依赖 |
| 凭据存储 | Keychain | - | 系统级安全存储 |

### 2.2 第三方依赖

**原则：最小依赖，优先使用系统框架**

| 依赖 | 用途 | 理由 |
|------|------|------|
| SwiftSoup | HTML 解析 | **按需引入**：CAS 登录页解析已由正则覆盖（`CasPageParser`，API.md §1.2）；仅当接入 HTML 重度解析功能（如 BACKLOG 希冀作业）时再引入 |
| KeychainAccess | Keychain 封装 | 简化 Keychain 操作（可选；当前计划用原生 Security API，见 §5.1） |

> 系统框架补充：**CommonCrypto**（AES-CBC，图书馆座位预约加密必需，见 API.md §5.3）。CryptoKit 只支持 GCM/ChaChaPoly，**不支持 CBC**，此处不能用 CryptoKit 替代。

### 2.3 不使用的技术

| 技术 | 理由 |
|------|------|
| Electron/Tauri | 非原生，包体大 |
| React Native | 非原生 macOS 体验 |
| KMP/Compose Multiplatform | 不是当前跨平台路线；历史选型说明见 [MULTI-PLATFORM-STRATEGY.md](MULTI-PLATFORM-STRATEGY.md) |
| Rust + Flutter | 尚未用于 Apple 应用；当前仅作为 Android/Windows 镜像项目的准备方向，边界见 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) |
| Core Data | SwiftData 更现代 |

---

## 3. 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                      Presentation Layer                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Menu Bar    │  │  Main Window │  │  Settings    │  │
│  │  View        │  │  Views       │  │  Views       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                      Business Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Schedule    │  │  Grade       │  │  Library     │  │
│  │  Service     │  │  Service     │  │  Service     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Auth        │  │  Notification│  │  Cache       │  │
│  │  Service     │  │  Service     │  │  Manager     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  BUAA API    │  │  SwiftData   │  │  Keychain    │  │
│  │  Client      │  │  Store       │  │  Store       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 3.2 模块划分（目标态）

> 以下是**规划的目标结构**，非现状。初始骨架曾为 12 个应用源码文件 + 1 个测试文件；当前入口/AppState/RootView/MainView 仍在 `BUAA-Assistant/` 根目录，已新增 `Core/Storage`、`Core/UI` 和 `Core/Logging` 等目录；测试在工程级 `BUAA-AssistantTests/` target；Info.plist 由 `GENERATE_INFOPLIST_FILE` 生成，entitlements 在仓库根目录。

```
BUAA-Assistant/
├── App/
│   ├── BUAAAssistantApp.swift          # 应用入口（当前含菜单栏面板，Step 7 可拆出 MenuBarManager）
│
├── Features/
│   ├── Auth/
│   │   ├── AuthService.swift           # 认证服务
│   │   └── LoginView.swift             # 登录界面
│   │
│   ├── Schedule/
│   │   ├── ScheduleService.swift       # 课表服务
│   │   ├── ScheduleView.swift          # 课表界面
│   │   ├── ScheduleRepository.swift    # 数据仓库
│   │   └── Models/
│   │       ├── Course.swift
│   │       └── Term.swift
│   │
│   ├── Grade/
│   │   ├── GradeService.swift          # 成绩服务
│   │   ├── GradeView.swift             # 成绩界面
│   │   ├── GPACalculator.swift         # GPA 计算
│   │   └── Models/
│   │       └── Grade.swift
│   │
│   ├── Library/
│   │   ├── LibraryService.swift           # 图书馆服务（座位：已验证协议）
│   │   ├── SeatBookingView.swift          # 座位查询/预约界面
│   │   ├── BorrowingView.swift            # 借阅界面（探索性目标，协议待验证）
│   │   └── Models/
│   │       ├── SeatBooking.swift
│   │       └── Borrowing.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift          # 设置界面
│       └── SettingsStore.swift         # 设置存储
│
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift             # 网络客户端
│   │   ├── APIEndpoint.swift           # 端点定义
│   │   ├── APIError.swift              # 错误定义
│   │   └── RequestInterceptor.swift    # 请求拦截器
│   │
│   ├── Storage/
│   │   ├── SwiftDataStore.swift        # SwiftData 封装
│   │   ├── KeychainManager.swift       # Keychain 封装
│   │   └── CacheManager.swift          # 缓存管理
│   │
│   ├── Notification/
│   │   ├── NotificationService.swift   # 通知服务
│   │   └── NotificationScheduler.swift # 通知调度
│   │
│   └── Utils/
│       ├── DateExtensions.swift        # 日期扩展
│       ├── StringExtensions.swift      # 字符串扩展
│       └── Logger.swift                # 日志工具
│
├── Resources/
│   └── Assets.xcassets                 # 资源文件（Info.plist 由构建系统生成；entitlements 在仓库根目录）
│
└── BUAA-AssistantTests/                # 工程级测试 target（当前 CasPageParserTests；UI 测试 target 于 Step 8 创建）
```

### 3.3 数据流

```
用户操作
    │
    ▼
View (SwiftUI)
    │
    │ @StateObject / @ObservedObject
    ▼
ViewModel / Service
    │
    │ async/await
    ▼
Repository
    │
    ├─────────────────┬─────────────────┐
    │                 │                 │
    ▼                 ▼                 ▼
API Client      SwiftData         Keychain
(网络请求)      (本地持久化)      (安全存储)
    │                 │                 │
    ▼                 ▼                 ▼
北航各系统      本地数据库        系统钥匙串
```

### 3.4 并发模型

```swift
// ViewModel 使用 @MainActor 确保 UI 状态在主线程更新
@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var state = ScheduleState()
    private let service: ScheduleService
    
    func loadSchedule() async {
        let courses = try await service.getSchedule()
        state.courses = courses
    }
}

// 服务层使用 actor 隔离可变状态
actor ScheduleService {
    private var cachedSchedule: [Course]?
    
    func getSchedule(forceRefresh: Bool = false) async throws -> [Course] {
        if !forceRefresh, let cached = cachedSchedule {
            return cached
        }
        let courses = try await repository.fetchSchedule()
        cachedSchedule = courses
        return courses
    }
}

// SwiftData 写入使用 ModelActor 隔离（ModelContext 非线程安全）
@ModelActor
actor ScheduleStore {
    func save(_ courses: [Course]) throws {
        // ... SwiftData 操作
        try modelContext.save()
    }
}
```

---

## 4. 核心设计决策

### 4.1 认证策略

**问题**：UBAA Server 中转不稳定，需要直连北航 SSO。

**方案**：
1. 直接对接 `sso.buaa.edu.cn` CAS 登录（表单提交 + 页面隐藏字段全量回传，勿硬编码字段清单）
2. CAS 票据（TGT/ST）流转完全由 Cookie + 重定向链自动完成，客户端**不手动管理票据**；唯一例外是图书馆，需手动从重定向 URL 提取 `cas` 令牌
3. 会话有效性以 `uc.buaa.edu.cn/api/uc/status` 为唯一判据，且业务系统报未登录时先复核再清会话（防上游 5xx 抖动误杀登录态）
4. 密码存 Keychain；业务 Cookie 交给 `HTTPCookieStorage`（CASTGC 是 HttpOnly，手拼 Cookie 头会丢失语义）
5. **会话恢复不依赖 Cookie 跨重启持久化**：`CASTGC`/`JSESSIONID` 均为无 Expires 的会话 Cookie，`HTTPCookieStorage` 只在进程内保留它们，App 重启即失。免登录恢复的设计是：启动 → `validateSession()` 复核 → 无效且 Keychain 存有密码（「记住密码」开启）→ **静默重登一次**；无密码则回登录页。Step 2 验收时实测 CASTGC 是否带 Expires（若实测带 Expires，则 CASTGC 可跨重启持久化，静默重登退为兜底），结论登记进 API.md §1.8
6. **WebVPN Cookie 不落盘**：直连与 WebVPN 使用隔离的 CookieStorage；WebVPN Cookie 仅驻留进程内。切换网络路线会清空旧会话，记住密码仍受用户显式开关控制。
7. **自动网络回退**：默认先直连；UC 返回非标准 HTTP 483 或访问策略页时，自动切换到 `d.buaa.edu.cn` WebVPN 并重试。WebVPN 是学校官方网关，不经过本项目自建中转服务器。

**流程**（与 UBAA `LocalConnectionAuth.kt` 在用实现逐行对齐，细节见 [API 接口文档](API.md) 第 1 节）：

```
1. GET /login（禁自动重定向）→ 3xx 即已有会话；200 则解析 execution / 验证码 / 预登录提示
2. （如需验证码）GET /captcha?captchaId=… 拉取 JPEG 图片
3. POST /login 表单：隐藏字段全量回传 + username/password/submit/_eventId=submit/type=username_password
   （验证码场景 captcha 与 captchaResponse 双字段填同一值）
4. 手动逐跳跟随重定向并检测错误特征；可能经过「密码过期」跳过页（_eventId=ignoreAndContinue，仅一次）
5. GET uc/api/login 激活 UC 会话 → GET uc/api/uc/status 验证（code==0 且 data 非空）
6. 各业务系统首次访问经 CAS 302 自动建立 JSESSIONID，无需逐系统登录
```

### 4.2 数据同步策略

**问题**：如何平衡实时性和离线可用性？

**方案**：Stale-While-Revalidate

```swift
func getSchedule() async throws -> [Course] {
    // 1. 立即返回缓存（如果有）
    if let cached = await store.getCachedSchedule() {
        return cached
    }
    
    // 2. 后台刷新
    Task {
        let fresh = try await apiClient.fetchSchedule()
        await store.saveSchedule(fresh)
        await notifyUpdate(fresh)
    }
}
```

### 4.3 错误处理策略

**分层错误处理**：

```swift
enum AppError: Error {
    case network(NetworkError)
    case auth(AuthError)
    case parsing(ParsingError)
    case storage(StorageError)
}

enum NetworkError: Error {
    case timeout
    case noConnection
    case serverError(Int)
    case rateLimited
}

// View 层统一处理
.errorAlert($viewModel.error) { error in
    switch error {
    case .network(.timeout):
        return "请求超时，请检查网络连接"
    case .auth(.sessionExpired):
        return "登录已过期，请重新登录"
    default:
        return "发生错误，请稍后重试"
    }
}
```

### 4.4 性能优化

1. **懒加载**：功能模块按需初始化
2. **图片缓存**：使用 NSCache 缓存头像等图片
3. **请求去重**：相同请求并发时只发一次
4. **后台刷新**：使用 BGTaskScheduler 定期刷新数据（需要 Background Modes entitlement，macOS 对后台任务调度有严格限制，不保证即时执行）

---

## 5. 安全设计

### 5.1 凭据存储

```swift
// 使用 Keychain 存储密码
class KeychainStore {
    func savePassword(_ password: String, for username: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: username,
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)  // Keychain 写失败必须显式暴露，禁止吞掉
        }
    }
}
```

### 5.2 网络安全

- 所有请求强制 HTTPS
- 证书校验不降级
- 敏感数据不写入日志

### 5.3 隐私保护

- 不收集用户数据
- 不上传到第三方服务器
- 本地存储所有数据

---

## 6. 可扩展性设计

### 6.1 插件式功能模块

```swift
protocol FeatureModule {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    
    func mainView() -> AnyView
    func menuBarView() -> AnyView?
}

// 注册功能模块
FeatureRegistry.shared.register(ScheduleModule())
FeatureRegistry.shared.register(GradeModule())
FeatureRegistry.shared.register(LibraryModule())
```

### 6.2 API 适配器模式

```swift
protocol AcademicAPI {
    func getSchedule() async throws -> [Course]
    func getGrades() async throws -> [Grade]
}

// 可以切换不同实现
class DirectAPI: AcademicAPI { ... }      // 直连北航
class ProxyAPI: AcademicAPI { ... }       // 通过代理
class MockAPI: AcademicAPI { ... }        // 测试用
```

---

## 7. 部署与分发

### 7.1 开发阶段
- Xcode 直接运行
- 使用开发证书

### 7.2 分发阶段
- Ad-hoc 分发（自用）
- 公证 (Notarization)（如需分发给他人）

### 7.3 自动更新
- 使用 Sparkle 框架（可选）
- 或手动检查 GitHub Releases

---

## 8. 里程碑

### Phase 1: 基础框架 (1 周)
- [x] 项目初始化
- [ ] 菜单栏应用
- [ ] 认证模块
- [ ] 基础 UI 框架

### Phase 2: 核心功能 (2 周)
- [ ] 课表查询
- [ ] 成绩查询 + GPA 计算
- [ ] 本地数据持久化

### Phase 3: 增强功能 (2 周)
- [ ] 图书馆座位（楼馆/分区/座位查询与预约——协议已验证，见 API.md §5；含 AES-CBC 加密与 TLS 证书链实测项）
- [ ] 系统通知
- [ ] 快捷键支持

### Phase 4: 优化完善 (1 周)
- [ ] 性能优化
- [ ] 错误处理完善
- [ ] 文档完善

> **探索性目标（不占任何里程碑）**：图书馆借阅查询——无参考实现，须先完成 API.md §6 的逆向验证清单并转正后才进入计划（COLLABORATION §6 的既定规则）。

---

## 9. UBAA 原项目架构反思

本节对 BUAASubnet/UBAA 的原始设计进行高标准审视，提炼教训以指导本项目的设计决策。反思基于对源码的逐模块审阅和实际端到端测试。

> **延伸阅读**：完整的底层架构透视（含 7 种加密方案细节、Redis 键模式、Cookie Jar 两阶段写入、18 步认证流程图、14 模块 API 对比表等）见 [DEEP-ARCHITECTURE-REVIEW.md](DEEP-ARCHITECTURE-REVIEW.md)。本文节侧重设计反思与决策教训，两份文档互为补充。

### 9.1 架构层面

#### 9.1.1 KMP 跨平台抽象的代价

> **历史选型记录**：以下评价针对早期“仅做 macOS 原生应用”的决策背景，不是当前多平台路线的总评，也不代表本项目仍然只做一个平台。当前方向已更新为 Apple 继续 SwiftUI、Android/Windows 准备 Rust + Flutter 镜像；见 [MULTI-PLATFORM-STRATEGY.md](MULTI-PLATFORM-STRATEGY.md)。

UBAA 选择 Kotlin Multiplatform + Compose Multiplatform 覆盖 6 个平台（Android/iOS/Desktop/Web Wasm/Web JS/Server）。这一选择的代价远大于收益：

| 问题 | 具体表现 | 教训 |
|------|----------|------|
| `expect/actual` 爆炸 | 每个平台需要为网络、存储、加密、Cookie 管理分别实现 `actual`，代码量膨胀 | 跨平台抽象只在真正共享 >70% 逻辑时才有价值；Mac 原生应用不需要这种妥协 |
| Compose UI 在 Desktop 不成熟 | JetBrains Compose for Desktop 的滚动、焦点、菜单、窗口管理均有缺陷，macOS 上字体渲染模糊 | 原生体验不能通过跨平台框架"近似"获得 |
| Wasm 目标限制严重 | Ktor client 在 Wasm 上不支持 Cookie jar、不支持 multipart、TLS 受限 | 不要为了覆盖一个边缘平台而污染整个架构 |
| 构建系统复杂度 | Gradle 多模块 + KMP 插件 + 6 平台 target，冷启动 >3 分钟，增量编译频繁失败 | 构建时间直接影响开发体验，Mac 原生项目用 Xcode + SPM 即可 |

**当时的决策（仅 macOS 阶段）**：使用 Swift + SwiftUI 做原生 macOS 客户端。2026-10-19 起，项目新增 Android/Windows Rust + Flutter 镜像准备方向；Apple 客户端仍维持 SwiftUI。该历史判断不再表达整个项目的当前平台范围。

#### 9.1.2 三层架构的边界模糊

UBAA 的 `shared` 模块同时承担了 API 层、业务层和部分表示层的职责：

```
shared/src/commonMain/kotlin/cn/edu/ubaa/api/
├── local/          # 直连实现（混合了网络、解析、业务逻辑）
├── relay/          # 中转实现
├── feature/        # 功能 API（但包含了大量解析逻辑）
└── core/           # 核心抽象（但经常泄漏具体实现）
```

**问题**：`LocalConnectionAuth.kt` 单文件 >800 行，同时处理 CAS 登录流程、Cookie 管理、WebVPN 隧道、错误重试和会话状态机。违反单一职责原则。

**教训**：
- 网络层只做 HTTP 请求/响应映射
- 解析层只做数据格式转换（HTML→DTO, JSON→DTO）
- 业务层做状态管理和编排
- 三层之间通过明确的接口通信

#### 9.1.3 连接模式抽象过度

UBAA 设计了三种连接模式（Direct/WebVPN/ServerRelay），导致：

- 代码量 ×2：每个功能需要 relay、local 两套实现（DIRECT/WEBVPN 共用 local 实现，仅 URL 重写不同），外加模式切换时的全量状态清理逻辑
- 测试矩阵 ×3：三种模式都需要独立验证
- WebVPN 模式的 HTTP 隧道实现复杂且脆弱（需要处理 JS 加密、动态端口、验证码弹窗）
- ServerRelay 模式依赖第三方服务器，该服务器当前处于不稳定状态

**本项目的修正决策（2026-10-18）**：原先“只直连、不实现全局模式”的取舍在校园公网 IP 被访问策略拦截时不成立。现在实现 **自动 / 直连 / WebVPN** 三种用户偏好：
- 自动模式先直连，遇到 UC 483/访问策略拦截后自动切换到 WebVPN 并重试；
- WebVPN 模式对所有北航上游 URL 使用 `d.buaa.edu.cn` 加密路由与独立 CookieStorage；
- `routedData` 只改写 URL、Host 相关头部与 `Referer/Origin`，必须原样保留 `URLRequest.httpBody`，并由同一个 URLSession Cookie 会话贯穿 SPA 预热、CAS 重定向与业务 POST；禁止重新序列化表单/JSON body 或手工覆盖网关 Cookie，否则研究生课表和 SPOC 角色接口会返回空数据或业务错误；
- 不实现 UBAA 的 ServerRelay，因为 Ginkgo 不运行自建中转服务器；
- 认证链保持逐跳重定向与 `uc/status` 成功判据，WebVPN 只改变传输路线，不降低会话校验标准。

### 9.2 安全层面

#### 9.2.1 P0 级安全问题

| 问题 | 位置 | 严重性 | 说明 |
|------|------|--------|------|
| 密码明文存储 | `CredentialStore` | **P0** | 密码以明文写入 Preferences/LocalStorage，任何能读取应用数据的人都能获取密码 |
| JWT 密钥硬编码回退 | `JwtUtil.kt` | **P0** | 当 `.env` 未配置 `JWT_SECRET` 时，回退到硬编码的默认密钥，生产环境所有 token 可被伪造 |
| 服务端会话 Cookie 日志泄漏 | `LocalConnectionAuth.kt` | **P1** | 调试模式下会输出完整 Cookie header，包含 TGT 和 JSESSIONID |

**本项目的对策**：
- 密码仅存储在 macOS Keychain（硬件加密，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）
- 无服务端组件，不存在 JWT 密钥问题
- 日志系统使用 `OSLog`，敏感字段标记为 `.private`，Release 构建自动脱敏

#### 9.2.2 凭据生命周期管理缺陷

UBAA 的凭据管理缺乏清晰的生命周期：

- 切换连接模式时清理不彻底：Cookie jar 清理了，但 `CredentialStore` 中的旧 token 可能残留
- 多账号支持缺失：只能存储一组凭据，切换账号需要手动清理
- Token 刷新竞态：多个并发请求同时检测到 session 过期时，会触发多次 refresh，导致 token 互相覆盖

**本项目的对策**（适用场景：图书馆 member token 等确需刷新的凭据；CAS 会话为纯 Cookie、无 token 可刷，见 §4.1）：
```swift
actor CredentialManager {
    private var refreshTask: Task<Void, Error>?
    
    func refreshTokenIfNeeded() async throws {
        // 双重检查 + 任务合并，避免并发刷新
        if let existing = refreshTask { return try await existing.value }
        refreshTask = Task { try await performRefresh() }
        defer { refreshTask = nil }
        try await refreshTask!.value
    }
}
```

### 9.3 并发与状态管理

#### 9.3.1 异步任务的生命周期管理

> 更正（2026-10-13）：本节旧版称「UBAA 在 shared 模块中使用 GlobalScope.launch」——**与源码不符**。经核对，UBAA 的 shared 与 server 主代码中没有 GlobalScope 的使用（ViewModel 用 viewModelScope，server 清理协程用带 SupervisorJob 的受管 CoroutineScope）。旧版 DEEP-ARCHITECTURE-REVIEW.md 第 13 节也自我矛盾地记录了这一点。

保留本节是因为教训本身仍然成立，只是指向的是**风险模式**而非 UBAA 的实际行为：脱离生命周期的后台任务（如 Kotlin 的 GlobalScope、Swift 的顶层 `Task {}`）会导致：

- 任务生命周期与应用/视图生命周期脱钩，界面销毁后任务可能仍在运行
- 异常未被捕获时静默丢失
- 测试时无法等待异步操作完成

**教训**：Swift Concurrency 的 `Task {}` 有同样的问题。本项目统一使用 `@MainActor` 标注 ViewModel，所有异步操作通过 `.task {}` modifier 绑定到 View 生命周期；确实需要应用级后台任务（如菜单栏数据刷新）的，集中到一个受管的 `TaskGroup` 并在 `applicationWillTerminate` 中取消。

#### 9.3.2 状态同步的分布式锁问题

UBAA Server 使用 Redis 分布式锁来防止并发登录，但锁的 TTL 计算存在缺陷：

```kotlin
// 原代码
val lockTtl = max(AUTH_LOGIN_TIMEOUT_MS, AUTH_PRELOAD_TIMEOUT_MS) + 2000
// 问题：如果 AUTH_LOGIN_TIMEOUT_MS 被配置为 18000ms，锁 TTL 为 20000ms
// 但登录实际可能因为网络延迟超过 20s，锁已释放，第二个请求获得锁并重复登录
```

**教训**：分布式锁的 TTL 必须包含足够的 buffer，或者使用续约机制。本项目无服务端组件，不存在此问题，但本地 SwiftData 写入仍需注意并发安全——SwiftData 的 `ModelContext` 不是线程安全的，必须通过 `ModelActor` 隔离。

### 9.4 API 设计反思

#### 9.4.1 上游接口的脆弱耦合

UBAA 对北航各系统的接口做了大量硬编码假设：

- CAS 登录页 HTML 的 `execution` 输入框结构变化会导致登录失败，没有降级策略
- 课表/成绩数据本身是 JSON，但字段名直接使用上游拼音缩写且大小写混杂（buaascore 的 `kcmc/xf/kccj`、GSMIS 的 `KCMC/ZCBH/JASMC`），没有独立的字段映射层；部分成绩字段（`xf/kccj`）类型在数字与字符串之间漂移
- 成绩查询依赖的 buaascore 页面（GET 激活页）是 HTML，会话判定依赖页面特征
- 图书馆系统的 API 版本在 URL 中硬编码（`/v4/`），升级后需要改代码

**本项目的对策**：
```swift
// 定义稳定的领域模型，与上游字段解耦
struct Course {
    let name: String
    let credit: Double
    let teacher: String
    let schedule: [TimeSlot]
}

// 每个系统有独立的 Adapter，负责将上游格式转换为领域模型
protocol ScheduleAdapter {
    func parseSchedule(from raw: Data) throws -> [Course]
}

class GsmisAdapter: ScheduleAdapter { ... }
class ByxtAdapter: ScheduleAdapter { ... }
```

#### 9.4.2 错误处理不一致

UBAA 的错误处理在三个层级之间不统一：

| 层级 | 错误表示 | 问题 |
|------|----------|------|
| 网络层 | 抛出 `IOException` | 不区分超时、DNS、SSL |
| API 层 | 返回 `Result<T, String>` | 用字符串表示错误，丢失结构化信息 |
| UI 层 | 显示 `Snackbar` | 错误信息是英文技术术语，用户无法理解 |

**本项目的对策**：统一的 `AppError` 枚举，从网络层到 UI 层保持一致的错误类型，UI 层负责将错误码翻译为用户友好的中文提示。

#### 9.4.3 缺乏版本协商

UBAA 假设上游接口永远不变。当北航某个系统升级 API 时（如图书馆从 v3 升级到 v4），客户端直接崩溃。

**本项目的对策**：
- 启动时探测上游 API 版本（通过响应头或特征字段）
- 维护多个 Adapter 版本，按探测结果选择
- 解析失败时降级到缓存数据并通知用户

### 9.5 测试策略反思

#### 9.5.1 测试覆盖的盲区

UBAA 的测试主要集中在 Mock 场景下的单元测试，缺乏：

- **端到端测试**：Mock 服务器的响应与真实上游不一致时，测试通过但实际功能失败
- **HTML 解析回归测试**：上游 HTML 结构变化后，没有自动化检测
- **并发压力测试**：多请求并发时的 token 刷新竞态未被测试覆盖
- **长时间运行测试**：Cookie 过期后的自动刷新路径未被验证

**本项目的对策**：见 TESTING.md，增加上游接口可达性巡检、HTML 快照回归测试和并发安全测试。

#### 9.5.2 Mock 与真实的鸿沟

UBAA 的 `commonTest` 中大量使用硬编码的 Mock 响应。这些 Mock 数据是某一时刻的快照，不能反映上游接口的实际变化。

**教训**：
- Mock 测试只能验证"代码逻辑是否正确"，不能验证"接口是否仍然可用"
- 需要定期（每周）运行真实接口的可达性测试
- 保存上游响应的 HTML/JSON 快照作为回归测试基准

### 9.6 总结：从 UBAA 学到的设计原则

| 原则 | UBAA 的做法 | 本项目的做法 |
|------|-------------|-------------|
| 平台选择 | 6 平台 KMP | Apple：SwiftUI；Android/Windows：Rust + Flutter 镜像准备 |
| 连接模式 | 三种模式 × N 个接口 | 自动 / 直连 / WebVPN；无 ServerRelay，统一 `routedData` 传输层 |
| 凭据存储 | 明文 Preferences | Keychain + Access Control |
| 并发模型 | 受管 CoroutineScope（viewModelScope 等；旧版误记 GlobalScope，更正见 §9.3.1） | Swift Concurrency + Actor 隔离 |
| 错误处理 | 混合风格 | 统一 AppError 枚举 |
| 上游耦合 | 硬编码假设 | Adapter 模式 + 版本探测 |
| 测试策略 | Mock 单元测试为主 | Mock + 上游巡检 + 快照回归 |
| 构建系统 | Gradle 多模块 | Xcode + SPM |

---

## 10. 原生 macOS UI 设计语言（历史草案）

> **设计准则已迁至 [UI-DESIGN.md](UI-DESIGN.md)，新功能与验收以该文档为准。**本节保留为早期视觉探索，下面的尺寸、颜色值、动画参数和代码示例并非全部出自 Apple HIG，也不构成实现约束；其中自制 Liquid Glass 内容卡片的建议已废弃。实现时优先使用系统组件，并以 Apple 当前文档及真机表现核对。

### 10.1 设计哲学

**核心关键词**：克制、通透、流动

- **克制**：不用装饰性元素，每个像素都有功能目的
- **通透**：大量使用半透明材质 (Material)，让背景内容渗透，营造层次感
- **流动**：所有状态变化都通过弹簧动画过渡，没有突兀的跳变

**Apple HIG 原则**：
- 材质仅用于功能性分层，不做装饰 (HIG: "Use materials to suggest visual hierarchy")
- 动画必须可中断、可重定向 (HIG: "Every animation must be interruptible")
- 颜色必须自适应深色模式 (HIG: "Embrace colors that adapt to the current appearance")

### 10.2 布局与间距（HIG Layout）

#### 10.2.1 窗口尺寸

| 属性 | 值 | 来源 |
|------|-----|------|
| 主窗口最小尺寸 | 800×560 pt | 侧边栏+内容区双栏布局需要 |
| HIG 推荐最小窗口尺寸 | 600×400 pt | HIG Windows |
| 标题栏高度 | 28pt (Retina @2x = 56px) | HIG Windows |
| 红绿灯按钮直径 | 15px (物理像素) | HIG Windows |
| 红绿灯按钮间距 | ~24px (~12pt) | HIG Windows |
| 窗口圆角 (macOS 26) | ~10pt (系统默认) | HIG Windows |

```swift
// 主窗口最小尺寸
.frame(minWidth: 800, minHeight: 560)

// 菜单栏弹出面板
.frame(width: 360)
```

#### 10.2.2 内容区域间距

| 属性 | 值 | 来源 |
|------|-----|------|
| 内容内边距 | 16pt (leading/trailing) | HIG Layout |
| 边缘最小间距 | 8pt | HIG Layout |
| 控件默认尺寸 (macOS) | 28×28 pt | HIG Layout |
| 侧边栏宽度 | Small/Medium/Large (用户可选) | HIG Sidebars |

```swift
enum Spacing {
    static let xs: CGFloat = 4     // 紧凑元素间距
    static let sm: CGFloat = 8     // 相关元素间距
    static let md: CGFloat = 12    // 控件间距
    static let lg: CGFloat = 16    // 内容内边距
    static let xl: CGFloat = 24    // 区域间距
    static let xxl: CGFloat = 32   // 大区域分隔
}
```

#### 10.2.3 侧边栏

```swift
NavigationSplitView {
    SidebarView(selection: $selectedSection)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
} detail: {
    DetailView(section: selectedSection)
}
```

**HIG 规则**：
- 侧边栏不在底部显示关键信息（窗口缩小时可能被隐藏）
- 使用 SF Symbols 作为侧边栏图标，跟随强调色
- 侧边栏样式: `.listStyle(.sidebar)`

### 10.3 颜色体系（HIG Color）

#### 10.3.1 语义色（自动适配深色模式）

**必须使用语义色，禁止硬编码 hex 值。**

| 用途 | API | 浅色模式 | 深色模式 |
|------|-----|----------|----------|
| 主文本 | `Color.primary` / `NSColor.labelColor` | rgba(0,0,0,1.0) | rgba(255,255,255,1.0) |
| 副文本 | `Color.secondary` / `NSColor.secondaryLabelColor` | rgba(0,0,0,0.85) | rgba(235,235,245,0.60) |
| 三级文本 | `NSColor.tertiaryLabelColor` | rgba(0,0,0,0.50) | rgba(235,235,245,0.30) |
| 四级文本 | `NSColor.quaternaryLabelColor` | rgba(0,0,0,0.25) | rgba(235,235,245,0.18) |
| 分隔线 | `NSColor.separatorColor` | rgba(0,0,0,0.12) | rgba(84,84,88,0.60) |
| 链接 | `NSColor.linkColor` | #007AFF | #0A84FF |
| 占位符 | `NSColor.placeholderTextColor` | rgba(0,0,0,0.25) | rgba(235,235,245,0.30) |

#### 10.3.2 系统色

| 颜色 | 浅色 | 深色 | 用途 |
|------|------|------|------|
| System Blue | #007AFF | #0A84FF | 强调色、选中态 |
| System Green | #34C759 | #32D74B | 成功状态 |
| System Red | #FF3B30 | #FF453A | 错误状态 |
| System Orange | #FF9500 | #FF9F0A | 警告状态 |
| System Gray | #8E8E93 | #98989D | 禁用状态 |

```swift
// 正确：使用语义色
Text("课程名称")
    .foregroundStyle(.primary)

// 正确：使用系统色
Circle()
    .fill(.green)  // 自动适配深色模式

// 错误：硬编码颜色
Text("课程名称")
    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))  // 深色模式下不可见
```

#### 10.3.3 自定义颜色

在 Xcode Asset Catalog 中创建 Color Set，分别配置 Any Appearance 和 Dark 变体：

```swift
extension Color {
    static let cardBackground = Color("CardBackground")  // Asset Catalog 中定义
    static let cardBorder = Color("CardBorder")
    static let accentGradientStart = Color("AccentGradientStart")
    static let accentGradientEnd = Color("AccentGradientEnd")
}
```

### 10.4 材质体系（HIG Materials）

#### 10.4.1 系统材质层级

| 材质 | API | 模糊度 | 用途 |
|------|-----|--------|------|
| Ultra Thin | `.ultraThinMaterial` | 最轻 | 浮动面板、菜单栏弹出 |
| Thin | `.thinMaterial` | 轻 | 工具栏、标签栏 |
| Regular | `.regularMaterial` | 中等 | 菜单、弹出框、侧边栏背景 |
| Thick | `.thickMaterial` | 重 | 模态对话框 |
| Ultra Thick | `.ultraThickMaterial` | 最重 | 高对比度覆盖层 |

#### 10.4.2 液态玻璃效果

macOS 26 (Tahoe) 引入 Liquid Glass。在 macOS 14+ 上通过材质叠加近似：

```swift
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var material: Material = .ultraThinMaterial
    var tintOpacity: Double = 0.03
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // 底层：系统材质（自动适配深色模式）
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)
                    
                    // 色彩叠加：微妙的色调
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(tintOpacity))
                    
                    // 高光边缘：模拟玻璃折射
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        material: Material = .ultraThinMaterial,
        tint: Double = 0.03
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, material: material, tintOpacity: tint))
    }
}
```

#### 10.4.3 材质使用规则（HIG Do's and Don'ts）

- **DO** 用材质创建层级深度（侧边栏 `.regularMaterial`，内容区不透明）
- **DO** 在浮动元素上使用 `.ultraThinMaterial`
- **DON'T** 在材质上方使用不透明背景色
- **DON'T** 装饰性使用材质（材质必须有功能目的）
- **DO** 尊重 `Reduce Transparency` 设置

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var cardBackground: some View {
    if reduceTransparency {
        return AnyView(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor)))
    } else {
        return AnyView(liquidGlass())
    }
}
```

### 10.5 排版体系（HIG Typography）

#### 10.5.1 字体

| 字体 | 用途 | API |
|------|------|-----|
| SF Pro | 系统 UI 字体 | `.font(.system(size:))` |
| SF Pro Text | <20pt 自动使用 | 系统自动选择 |
| SF Pro Display | ≥20pt 自动使用 | 系统自动选择 |
| SF Mono | 等宽、代码、数据 | `.font(.system(.body, design: .monospaced))` |
| New York | 衬线、阅读 | `.font(.system(.body, design: .serif))` |

#### 10.5.2 文本样式

**macOS 默认字号 13pt，最小 10pt。**

| 样式 | API | 用途 |
|------|-----|------|
| Large Title | `.font(.largeTitle)` | 大标题 |
| Title 1 | `.font(.title)` | 一级标题 |
| Title 2 | `.font(.title2)` | 二级标题 |
| Title 3 | `.font(.title3)` | 三级标题 |
| Headline | `.font(.headline)` | 标题、强调 |
| Body | `.font(.body)` | 正文 |
| Callout | `.font(.callout)` | 注释文本 |
| Subheadline | `.font(.subheadline)` | 副标题 |
| Footnote | `.font(.footnote)` | 脚注 |
| Caption 1 | `.font(.caption)` | 标准标注 |
| Caption 2 | `.font(.caption2)` | 小标注 |

```swift
// 正确：使用系统文本样式
Text("算法设计与分析")
    .font(.headline)

Text("新主楼A座101 · 周一 1-2节")
    .font(.subheadline)
    .foregroundStyle(.secondary)

// 错误：硬编码字号
Text("算法设计与分析")
    .font(.system(size: 16, weight: .semibold))  // 不支持 Dynamic Type
```

> 例外：`Image(systemName:)` 图标的尺寸允许固定 pt（如登录页/占位页的大图标用 `.font(.system(size:))`）——文本样式缩放约束的是 `Text`，图标只需跟随语义色与字重即可。

#### 10.5.3 Dynamic Type

```swift
// 支持 Dynamic Type 缩放
Text("课程名称")
    .font(.body)  // 自动跟随系统字号设置

// 自定义字体也要关联文本样式
Text("数据")
    .font(.custom("SF Mono", size: 14, relativeTo: .body))
```

### 10.6 圆角体系

```swift
enum CornerRadius {
    static let small: CGFloat = 6     // 按钮、标签、输入框
    static let medium: CGFloat = 10   // 卡片、菜单、弹出面板
    static let large: CGFloat = 16    // 窗口、大面板
    static let xlarge: CGFloat = 24   // 全屏 Sheet、模态对话框
    
    // 连续曲率圆角（squircle），与系统图标和窗口一致
    static func continuous(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
```

**规则**：
- 嵌套容器外层圆角比内层大 4pt（卡片 10pt，内部按钮 6pt）
- 使用 `.continuous` 风格（squircle），不使用 `.circular`
- 按钮圆角: `.buttonBorderShape(.roundedRectangle(radius: 10))`

### 10.7 动效体系（HIG Motion）

#### 10.7.1 弹簧动画参数

Apple HIG 规定弹簧是 SwiftUI 的默认动画类型。关键参数：

| 参数 | 含义 | 推荐范围 |
|------|------|----------|
| `response` | 类似持续时间（秒） | 0.3 - 0.8 |
| `dampingFraction` | 阻尼（0-1，越低弹跳越多） | 0.6 - 1.0 |

#### 10.7.2 动画预设

```swift
enum Motion {
    // 微交互：按钮按下、开关切换、悬停高亮
    // HIG: "Quick feedback" — response 0.3, damping 0.8
    static let micro = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    // 标准交互：卡片展开、列表项增删、面板切换
    // HIG: "Standard UI transition" — response 0.4, damping 0.7
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.7)
    
    // 宏观交互：窗口缩放、页面转场
    // HIG: "Slow settle" — response 0.8, damping 0.8
    static let macro = Animation.spring(response: 0.5, dampingFraction: 0.85)
    
    // 弹性交互：拖拽释放、通知弹出、成功确认
    // HIG: "Playful bounce" — response 0.5, damping 0.6
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // 流畅过渡：颜色变化、透明度渐变
    static let smooth = Animation.easeInOut(duration: 0.25)
}
```

#### 10.7.3 HIG 动效原则

1. **每个动画必须可中断**：使用弹簧动画，不用固定时长曲线
2. **从当前值开始**：永远从 presentation value 开始，不从 target value
3. **不锁定输入**：动画过程中用户仍可操作
4. **尊重 Reduce Motion**：

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation {
    reduceMotion ? .none : Motion.standard
}

// Reduce Motion 时用交叉淡入替代弹簧动画
.transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
```

#### 10.7.4 关键动效

**卡片展开**：
```swift
if isExpanded {
    content()
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
}
.animation(Motion.standard, value: isExpanded)
```

**列表项增删**：
```swift
ForEach(items) { item in
    ItemRow(item: item)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
}
.animation(Motion.standard, value: items)
```

**Hero 动画（matchedGeometryEffect）**：
```swift
@Namespace private var ns

// 列表中的卡片
CourseRow(course: course)
    .matchedGeometryEffect(id: course.id, in: ns)

// 展开后的详情
CourseDetail(course: course)
    .matchedGeometryEffect(id: course.id, in: ns)
    .transition(.asymmetric(
        insertion: .scale(scale: 0.9).combined(with: .opacity),
        removal: .opacity
    ))
```

**菜单栏弹出**：
```swift
MenuPanel()
    .transition(.asymmetric(
        insertion: .move(edge: .top)
            .combined(with: .opacity)
            .combined(with: .scale(scale: 0.95, anchor: .top)),
        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
    ))
    .animation(Motion.bouncy, value: isPanelVisible)
```

### 10.8 转场

#### 10.8.1 侧边栏切换

```swift
Group {
    switch selectedSection {
    case .schedule: ScheduleView()
    case .grade: GradeView()
    case .library: LibraryView()
    case .settings: SettingsView()
    }
}
.transition(.opacity.combined(with: .scale(scale: 0.98)))
.animation(Motion.standard, value: selectedSection)
```

#### 10.8.2 加载状态

```swift
ZStack {
    switch state {
    case .loading:
        ProgressView().transition(.opacity)
    case .loaded(let data) where data.isEmpty:
        EmptyStateView().transition(.opacity.combined(with: .scale(scale: 0.95)))
    case .loaded(let data):
        ContentList(data: data).transition(.opacity)
    case .error(let error):
        ErrorView(error: error).transition(.opacity)
    }
}
.animation(Motion.standard, value: state)
```

### 10.9 菜单栏应用 UI

```swift
MenuBarExtra {
    MenuBarContent()
} label: {
    Image(systemName: menuBarIcon)
        .symbolRenderingMode(.hierarchical)
        .contentTransition(.symbolEffect(.replace))
}

var menuBarIcon: String {
    switch connectionState {
    case .connected: "checkmark.circle.fill"
    case .connecting: "arrow.triangle.2.circlepath"
    case .disconnected: "xmark.circle.fill"
    case .idle: "graduationcap"
    }
}
```

**弹出面板布局**（宽度 360pt，符合 HIG 内容内边距 16pt）：

```
┌──────────────────────────────────────┐  ← .ultraThinMaterial 背景
│  🎓 BUAA Assistant          [⚙️]   │  ← 标题栏
├──────────────────────────────────────┤
│  ┌────────────────────────────────┐  │
│  │ 📅 今天：算法设计与分析 1-2节  │  │  ← .liquidGlass(cornerRadius: 12)
│  │    新主楼A座101 · 张三教授     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 📊 GPA: 3.82 / 4.0           │  │  ← .liquidGlass(cornerRadius: 12)
│  │    本学期 12 学分              │  │
│  └────────────────────────────────┘  │
├──────────────────────────────────────┤
│  [🔄 刷新]          [退出登录]      │  ← 底部操作栏
└──────────────────────────────────────┘
```

### 10.10 主窗口 UI

```swift
struct MainView: View {
    @State private var selectedSection: Section? = .schedule
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("学术") {
                    Label("课表", systemImage: "calendar").tag(Section.schedule)
                    Label("成绩", systemImage: "chart.bar.fill").tag(Section.grade)
                }
                Section("服务") {
                    Label("图书馆", systemImage: "books.vertical.fill").tag(Section.library)
                    Label("博雅课程", systemImage: "person.3.fill").tag(Section.bykc)
                }
                Section("系统") {
                    Label("设置", systemImage: "gearshape.fill").tag(Section.settings)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            DetailView(section: selectedSection)
        }
        .frame(minWidth: 800, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
```

### 10.11 无障碍（HIG Accessibility）

#### 10.11.1 对比度要求（WCAG AA）

| 文本类型 | 最小对比度 | 
|----------|-----------|
| ≤17pt 正文 | 4.5:1 |
| ≥18pt 大文本 | 3:1 |
| 粗体文本 | 3:1 |

#### 10.11.2 必须实现

```swift
// 所有图标按钮提供 accessibilityLabel
Button(action: refresh) {
    Image(systemName: "arrow.clockwise")
}
.accessibilityLabel("刷新数据")

// 尊重 Reduce Motion
@Environment(\.accessibilityReduceMotion) var reduceMotion

// 尊重 Reduce Transparency
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

// 键盘导航：所有交互元素必须可通过 Tab 键访问
// 焦点指示器：2-4px 可见焦点环（系统自动处理）
```

#### 10.11.3 性能约束

- `.drawingGroup()` 对复杂材质视图进行离屏渲染
- `List` 中避免 `.ultraThinMaterial` 背景（滚动掉帧）
- 弹簧动画 `response` 不超过 0.5s
- `matchedGeometryEffect` 同时活跃视图不超过 2 个

### 10.12 HIG Do's and Don'ts 速查

| Do | Don't |
|----|-------|
| 使用语义色 (`.primary`, `.secondary`) | 硬编码 hex 颜色值 |
| 使用系统文本样式 (`.body`, `.headline`) | 硬编码字号 `.system(size: 15)` |
| 使用系统材质 (`.ultraThinMaterial`) | 用半透明 `Color.white.opacity()` 模拟 |
| 使用弹簧动画 `Animation.spring()` | 用固定时长 `Animation.linear(duration:)` |
| 尊重 Reduce Motion/Transparency | 强制所有用户看动画 |
| 提供 `accessibilityLabel` | 假设 VoiceOver 能自动理解 |
| 使用 `.continuous` 圆角 | 使用 `.circular` 圆角 |
| 在 Asset Catalog 管理自定义颜色 | 在代码中写死颜色值 |

---

## 附录

### A. 术语表

| 术语 | 说明 |
|------|------|
| TGT | Ticket Granting Ticket，CAS 登录票据 |
| ST | Service Ticket，服务票据 |
| SSO | Single Sign-On，单点登录 |
| CAS | Central Authentication Service，中央认证服务 |

### B. 参考资料

- [SwiftUI 官方文档](https://developer.apple.com/xcode/swiftui/)
- [SwiftData 官方文档](https://developer.apple.com/documentation/swiftdata)
- [CAS 协议规范](https://apereo.github.io/cas/)

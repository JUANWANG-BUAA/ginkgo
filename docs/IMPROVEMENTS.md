# 项目改进点分析

> 基于 2026-10 当前代码、文档、测试和本次 iOS 子项目落地结果整理。优先级按“用户风险 / 返工成本 / 可验证性”排序，而不是按代码量。

## 0. 结论摘要

Ginkgo 已经越过“能查询”的阶段：CAS、课表、成绩、作业、图书馆、空教室、签到、待办都有实际实现。Apple 自动化证据按日期维护于 [TESTING](TESTING.md)。新增博雅、研讨室空档和研究生教务页面后，数据面已从基础教务扩展到课程素养、空间预约与培养过程。当前最大的改进空间不在继续堆功能，而在以下三条主线：

1. **把跨语言行为固定为可执行契约**：Swift / Rust 已共用规则样例和部分解析契约，下一步扩签到 / 图书馆 / 博雅等高风险模块；范围见 [fixtures](../fixtures/README.md)。
2. **维护 Rust + Flutter 的分层与验收边界**：Android Alpha.8 与 Windows Alpha.6 均已发布，主要只读链路和部分实验写路径已接入；真实写入、Windows 实机覆盖和最近认证异常仍待验收。当前事实只维护在 [镜像入口](MIRROR-IMPLEMENTATION.md)，Windows 发布边界见 [首发记录](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)，本次架构修复见 [Opus 5.5 评审落实](_audit/2026-10-21-opus-review-followup.md)。
3. **并行完成 Apple 产品质量闭环**：iOS 真机、可访问性、隐私生命周期和 CI 仍是 Apple 端自己的验收事项，不应被新平台准备取代。

## 1. P0：应先解决的工程与质量风险

### 1.1 iOS 自动化与真机验收缺口

**现状**：macOS 全量 XCTest 和 iOS 模拟器共享单元测试的最新结果见 [TESTING](TESTING.md)。此前已记录的 iPhone 17 Pro、iPhone SE 和 iPad Pro UI 冒烟及临时凭据 live UI 证据仍按原日期有效。仓库已新增 `.github/workflows/ios.yml`，但尚未取得 GitHub Actions 远端结果。此前真实账号直连被 HTTP 483 拦截后，客户端已自动切换到北航 WebVPN 并完成 CAS 登录，`uc/status` 返回 `code == 0 + data`；历史通过不保证当前上游可用。

**风险**：iOS 真机上的 Cookie 生命周期、后台挂起、Keychain 权限、横屏/动态字体和 VoiceOver 仍可能与模拟器不同。

**路由能力（已补）**：Ginkgo 现在提供自动/直连/WebVPN，并在 WebVPN 模式下对认证与业务请求统一使用 `d.buaa.edu.cn` 网关。直连遇到 UC 483 时会自动切换 WebVPN 重试；ServerRelay 仍不实现，因为本项目不运行自建中转服务器。

**建议**：

- 在 GitHub Actions 首次运行并固定 iOS Simulator Runtime/Xcode 版本，保留 `xcresult` 归档。
- 继续扩展 XCUITest：通知权限、缓存清理、失败态、旋转、动态字体和真实写操作确认。
- 在直连与 WebVPN 两种路线的 iPhone/iPad 真机上完成真实账号只读验收。
- 测试矩阵至少覆盖 iPhone SE、Pro Max、iPad 横竖屏和深色模式。

**完成标准**：CI 稳定通过；docs/ACCEPTANCE.md 有 iOS 真机记录；真实 UC 会话与只读业务链路验收有脱敏证据。

### 1.2 Apple 共享源码仍以“文件排除”方式复用；它不是跨语言核心

**现状**：iOS target 的 `project.yml` 直接包含 `../BUAA-Assistant`，再排除 macOS 应用壳。改动某个共享文件时会同时影响两端，但依赖边界主要由 Xcode target membership 隐式维护。

**风险**：

- 新文件默认进入 iOS 或根据扩展名/资源类型意外进入，平台专属依赖可能到编译期才暴露。
- 无法给共享核心单独版本、单元测试和 API 约束。
- 签到、校园通知和研究生教务已抽出 CheckInRepository / CampusNoticesRepository / GraduateAcademicRepository（2026-10-22），ViewModel 只依赖仓储协议；图书馆、CGYY 与认证仍直接组合客户端。已拆 Repository 的模块也仍是 Swift 进程内边界，不是跨语言 API。

**建议（Apple 工程内的独立改进，不是 Rust/Flutter 的前置条件）**：

- 若要给 Apple 两端提供显式模块边界，可新建本地 Swift Package `GinkgoCore`，至少拆为 `Core`、`Auth`、`Academic`、`Campus` 四个 target。它只服务 SwiftUI/macOS/iOS，不承载 Rust/Flutter 的跨语言契约。
- 以课表、考试、空教室、成绩和学校作业的 Repository 边界为迁移样例，逐功能把网络与缓存访问收进可注入的仓库接口；保持上游客户端只负责协议交互。
- 平台壳仅依赖 `GinkgoCore` + 各自资源；UI 共享组件使用 `#if` 或独立 `GinkgoUI` 子模块。
- 核心层禁止 import AppKit/UIKit；用协议注入通知、图片解码、外链打开等平台能力。

**完成标准**：macOS 与 iOS 应用 target 不直接编译业务源码；SwiftPM 测试可在 macOS 和 iOS 复用；新增平台专属文件不再依赖手工 exclude。

### 1.3 隐私与数据生命周期仍需系统化

**现状**：Keychain 使用 `WhenUnlockedThisDeviceOnly`，iOS 已将 Application Support 排除备份，并添加 Privacy Manifest。但查询缓存与签到历史写入 Application Support，而个人待办仍写入 UserDefaults；iOS 的备份排除只覆盖 Application Support。卸载 Keychain 行为、账号切换残留和数据保留期限也没有统一策略。

**风险**：账号切换或卸载后残留本地校园数据；iCloud 备份排除只覆盖启动后的根目录；文件保护等级默认值未逐文件评审。

**建议**：

- 建立统一 `CacheStore`/`LocalDataPolicy`：目录、文件保护等级、备份排除、容量上限、保留期、账号清理集中管理。
- 在写文件时设置 `NSFileProtectionCompleteUntilFirstUserAuthentication`（按实际读取时机选择）。
- 设置页增加“删除本机全部数据”与保留期说明；卸载/重装行为写入隐私文档。
- 对 `PrivacyInfo.xcprivacy` 与 App Store 隐私标签做自动检查。

**完成标准**：所有本地数据都能从统一策略追溯；退出登录/注销/卸载路径有测试或验收记录；备份中不出现查询缓存。

### 1.4 真实上游契约测试与解析器韧性

**现状**：CAS、课表、成绩、作业、图书馆等依赖 HTML/JSON 形状。Rust 递归执行共享 fixture，Swift 已覆盖规则样例及部分 CAS / 教务 / 加密解析契约；两端共享范围仍小于全部 Rust 契约，尚未形成系统的脱敏上游样本库。覆盖边界见 [fixtures](../fixtures/README.md)。

**建议**：

- 将已脱敏的合法上游样本固化为 fixture corpus，按协议章节和采集日期管理。
- 为每个解析器建立“空列表 / 字段缺省 / 类型漂移 / 业务错误 / 结构改版”矩阵。
- 引入 contract test 报告：上游响应不匹配时只提示结构变化，不解释为空数据。
- 对 HTML 正则解析逐步迁移到小型 tokenizer 或结构化 selector；不能引入重量依赖时至少封装字段选择器与诊断。

**完成标准**：每次真实结构变化都能通过 fixture 回归；错误文案区分“暂时不可用、结构变化、真实空列表”。

## 2. P1：体验、性能与可维护性

### 2.1 触屏信息密度与可访问性

**现状**：iOS 页面层已完全拆分为原生 `Form/List/Section/NavigationStack`，不再把 macOS 大卡片页面直接塞进手机。课表使用按日 `Section`，图书馆/空教室使用分组列表和 native detail 页面，iPad 使用真正的 `NavigationSplitView`。iPhone 17 Pro、iPhone SE 和 iPad Pro 11 的 UI 冒烟测试已通过。

**仍建议**：

- 真机验证 Dynamic Type、VoiceOver、横屏、分屏和后台恢复。
- 课表可进一步提供“今日/三日/整周”的显式切换。
- 对图书馆和空教室的列表继续进行真机滚动性能与触控目标检查。
- 增加 UI 测试覆盖确认对话框、空状态、搜索、分页和错误重试。

**完成标准**：三种屏幕尺寸 + 最大动态字体无横向截断；VoiceOver 可完成查询与只读浏览；所有写操作按钮有课程/座位专属标签和二次确认。

### 2.2 ViewModel 生命周期与重复刷新

**现状**：各页面 `.task(id: account)` 自行启动，应用壳又负责签到轮询和网络恢复刷新，已有 generation/pending 机制但入口较多。

**风险**：重复请求、状态重置竞争、页面不可见仍刷新耗电。桌面有针对性测试，但 iOS 后台挂起会放大该问题。

**建议**：

- 每个 feature 统一 `FeatureModel` 状态机（idle/loading/loaded/stale/failed）与单一 refresh coordinator。
- 用 `@Observable` / Observation 替代部分 `ObservableObject`，减少主线程对象广播。
- 将“可见性”显式传入刷新策略；页面不可见时取消轮询。
- 增加请求去抖、并发合并和取消的 iOS 测试。

**完成标准**：同一账号只存在一份数据模型；页面切换不触发重复网络；后台无持续轮询。

### 2.3 后台刷新与通知语义

**现状**：课程提醒依赖已缓存周次，签到状态轮询只在前台；iOS 进入后台后没有后台刷新承诺。共享通知文案已从 macOS 专有说法收敛为“系统通知”。

**建议**：

- 用 `BGAppRefreshTask` 只做轻量的只读刷新和通知重排，不自动执行任何写操作。
- 对课表缓存已覆盖周次做精确解释；未缓存周次继续不推测。
- 通知权限、提醒开关、实际排程数量在 iOS 设置页明确展示。
- 评估 Live Activity 展示下一节课，但默认关闭并遵守隐私（可配置是否显示课程名）。

**完成标准**：后台刷新可被系统调度时更新缓存且不写上游；通知正文不含敏感信息；用户能清楚知道哪些周次覆盖。

### 2.4 Apple 发布与 CI

**现状**：macOS 已有 build/test 与 Release 草稿；本次新增 iOS device build/simulator test workflow，但 iOS 归档、签名与 TestFlight 流程仍未配置，远端 workflow 也尚未实际跑通。

**建议**：

- 首次跑通 `.github/workflows/ios.yml`，随后纳入 macOS/iOS 并行状态检查；使用固定 Xcode 与 Simulator Runtime 版本。
- 添加 `ios-archive` job 与 TestFlight 上传（证书/API key 放 secrets，不进仓库）。
- Release notes 分平台；iOS 自更新策略固定为 App Store/TestFlight。
- 归档前执行 privacy manifest、app icon alpha、Info.plist、URL scheme 与敏感字符串扫描。

**完成标准**：tag 或手动 workflow 可生成签名 IPA；TestFlight 内部测试安装成功；两平台测试报告都归档。

### 2.5 错误体验与可观测性

**现状**：已有 PII 脱敏日志、结构化业务错误与失败保留缓存，但 toast、notice、errorMessage 的呈现仍有各页面自行组织的情况。

**建议**：

- 统一 `AppErrorCategory`：网络、认证、上游结构、权限、写操作未确认、速率限制、存储。
- 每个错误提供“可行动下一步”：重试、重新登录、打开系统设置、复制脱敏诊断。
- 指标只本地统计（请求阶段、耗时区间、失败类别），默认不上传；若未来加入遥测必须单独隐私评审。

**完成标准**：同类错误跨模块文案和操作一致；日志、UI、测试共用错误分类。

## 3. P2：后续产品机会

- **App Intents / 快捷指令**：查看下一节课、打开签到页、添加待办；所有查询走既有服务层。
- **Widget / Live Activity**：下一节课、作业临期、图书馆人数；默认隐私模式隐藏课程名。
- **Handoff / 多窗口**：iPad 上并行查看课表与作业；需要先完成核心模块化。
- **Swift 6 并发检查**：逐 target 开启 strict concurrency，修复 Sendable 边界，不靠 `@unchecked Sendable` 长期兜底。
- **性能基线**：用 Instruments 对启动、课表周网格、图书馆 2,000 座位筛选、空教室筛选建立基线。
- **国际化**：先将用户文案集中到 String Catalog；中英文和术语表同步。
- **无障碍自动化**：VoiceOver 标签快照、动态字体布局快照、对比度检查进入 CI。

## 4. 本次已落地

1. 新增 `BUAA-Assistant-iOS/` 子项目、XcodeGen 配置、iOS AppIcon、LaunchBackground、Privacy Manifest 和 iOS 测试 target。
2. iOS 页面层改为独立原生 SwiftUI：Form 登录、Today/Schedule/Grade/Homework/Library/Classroom/CheckIn/Tasks 页面，并新增 BYKC 课程库、研讨室空档、研究生教务三个原生 List/Picker/searchable/DisclosureGroup 页面；TabView / NavigationSplitView、toolbar、refreshable 与 swipeActions 保持原生交互；登录页和设置页均可切换自动/直连/WebVPN。
3. 功能视图与 `AuthViewModel` 跨平台化：语义色、平台图片、hover/Escape/link style 适配。
4. `UpdateCenter` 按平台隔离安装逻辑，保留跨平台可测试策略代码。
5. 用户可见文案去除不必要的 macOS 绑定；登录页加入 compact width 单栏布局。
6. iOS 将 Application Support 排除出系统备份。
7. 验证：macOS 本轮 193 项单元测试全绿（iOS 模拟器此前 167 项）；原生 UI 冒烟测试在 iPhone 17 Pro、iPhone SE 与 iPad Pro 11 通过；真实账号在直连 483 后自动切换 WebVPN 登录成功，`uc/status` 判据通过；WebVPN 下研究生课表（30 周、7 门）、SPOC（13 项作业）、成绩服务、空教室、图书馆、校园通知与 iclass 只读链路均已实测。博雅 74 门课程、研讨室 45 个空间、研究生教务 10 章方案和 59 门计划课程已在 live UI 读回。

## 5. 推荐执行顺序

1. 在无 UC 访问策略限制的网络与真机完成真实账号只读验收，并补写操作人工往返。
2. 扩充版本化跨语言 fixtures，固定时区/学期、wire code、错误分类和解析边界；Swift 测试直接读取 fixture。
3. 按 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) 创建 Rust workspace 后，先做 foundation 和只读用例，再接认证、Flutter bridge，写操作最后迁移。
4. Apple 侧独立推进本地数据策略、错误分类、真机 Dynamic Type/VoiceOver/横屏验收和 iOS CI/TestFlight。
5. 若 Apple 两端仍受源码排除边界阻碍，再抽 `GinkgoCore` Swift Package；这是 Apple 内部模块化，不是 Rust/Flutter 的前置条件。
6. 再评估后台刷新、Widget/Live Activity 等增强能力。

## 2026-10-19 · 本轮优化落地

研究生教务已改为层级学分地图；校企课程字段、执行报告成功语义、认定/待考核口径已修正。分项查询失败不再冒充空数据，保留旧分项与来源时间。CGYY 已补登录重定向与统一路由，POST 不重发，并固定提交上下文、复核空档、回查订单。图书馆仅提供已由维护者确认可行的座位预约。

仍需后续取证的范围：跨类别合并规则自动计算、学分认定/课程归属调整、开题/中期/专业实践等工作流；本轮不伪造接口或自动提交申请。CGYY 真实登录与写入往返仍需人工验收。

## 2026-10-19 · 瘦身与复用落地

- 删除图书馆研讨间未挂载代码（页面、ViewModel、模型/解析器、`LibraryClient` 只读 API 与 9 项测试），产品范围回到“图书馆仅座位预约”。
- 抽出共享基础设施：`LocalStore`/`SnapshotCache`、`SchoolTime`、`JSONValue`、`HTMLText`、`FormURLEncoding`、`AESCipher`、`AutoRefreshGate`、`StatusPresentation`、`GraduateCredit`，替换 11 个缓存、27 处时区/日期代码与重复的状态文案。
- 两个应用壳合并为 `WorkspaceHost` + `WorkspaceCoordinator` + `WorkspaceLifecycleModifier`；iOS target 排除全部 macOS 页面与 macOS 专属 UI 组件，删除不可达的紧凑布局分支。
- 修复：钥匙串以外被 `try?` 静默吞掉的缓存/刷新错误补日志；图书馆重登重试丢失 `extractData`；HTML 实体二次解码；图书馆日期未固定 locale；iOS 清理缓存遗漏博雅/研究生教务；两个既有过期测试。
- 验证：macOS 212 项、iOS 模拟器 212 项单元测试通过；两端构建通过；`git diff --check` 通过。

## 2026-10-19 · 空教室数据边界拆分

- `ClassroomViewModel` 改为只依赖 `ClassroomRepository`；共享工作区入口负责组装默认仓库，默认仓库组合上游客户端和本地缓存。
- 缓存读写、上游查询与页面状态编排边界明确；纯筛选/排序实现移入 `ClassroomResults.swift`。
- 后续优先将相同结构用于其他功能，再评估抽取 `GinkgoCore` Swift Package。

## 2026-10-19 · 学校作业数据边界拆分

- 新增 `HomeworkRepository`，封装上游快照加载、可选详情能力、账号缓存读写与清理；ViewModel 不再持有服务/缓存依赖，也不再通过类型转换探测详情支持。
- macOS 与 iOS 设置页统一经 `HomeworkViewModel.clearCache(account:)` 清理作业缓存，避免界面直接访问缓存实现。

## 2026-10-19 · 成绩数据边界拆分

- 新增 `GradeRepository`，封装学期发现、成绩获取和账号缓存读写；`GradeViewModel` 只依赖该接口。
- 设置页改用 `GradeViewModel.clearCache(account:)`，不再直接实例化 `GradeCache`。

## 2026-10-19 · 课表数据边界拆分

- 新增 `ScheduleRepository`，封装上游课表加载、账号快照读写与清理；`ScheduleViewModel` 不再直接依赖服务或缓存。
- 菜单栏摘要和两端设置页统一经仓库接口读取/清理课表快照。

## 2026-10-19 · 考试数据边界拆分

- 新增 `ExamRepository`，封装上游查询、按账号/学期缓存读写和清理；`ExamViewModel` 不再直接依赖考试服务或缓存实现。
- 考试视图模型继续负责缓存回退、刷新节流和页面状态，原有回归测试改为通过默认仓库注入 stub 服务。

## 2026-10-19 · Rust + Flutter 镜像准备

- 将空教室排序的枚举 wire code（`name` / `availability` / `consecutive`）放在结果层，中文标题移入独立 presentation adapter，避免 UI 文案进入跨语言契约。
- 新增 `fixtures/classroom/filter-v1.json`，Swift 测试直接消费版本化合成 fixture；未来 Rust 契约测试应复用同一文件。
- 新增 `fixtures/time/beijing-day-v1.json`，`SchoolTime` 契约测试读取同一版本化样例；此项仅固化既有北京时间语义。
- 将课表快照的缓存周次选择与同学期数据保留抽成 `ScheduleSnapshot` 纯值操作，由 ViewModel 调用；新增 `fixtures/schedule/week-snapshot-v1.json` 覆盖跨周刷新保留与切换。
- 新增 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)，明确 FFI 粗粒度用例边界、数据隐私要求、fixture 格式和分阶段迁移路线。Rust/Flutter 工程尚未创建，当前无协议行为变化。
- 清理 [MULTI-PLATFORM-STRATEGY.md](MULTI-PLATFORM-STRATEGY.md) 中已过时的 Kotlin/Compose 当前推荐；保留为历史评估，`GinkgoCore` 明确为 Apple 内部可选模块化工作。

## 2026-10-20 · Alpha 基线与镜像开发启动

- 完成 macOS 全量 XCTest 与 iOS 27.0 / iPhone 17 Pro 模拟器 XCTest；当前有 219 个 XCTest 方法。真实设备、真实账号写操作与签名公证仍独立验收。
- 发布目标推进至 `0.1.0-alpha.8` 草稿包，作为 Swift/SwiftUI 基线；GitHub Draft Release 生成后仍须人工核对资产，不自动公开。（注：此处 `0.1.0-alpha.8` 是 Apple 端草稿包；Android 同名 Alpha.8 已于 2026-10-25 公开发布，两者为不同产物。）
- 将镜像文档从原则性准备扩展为可执行里程碑：Rust workspace/fixture runner、classroom 纯逻辑垂直切片、只读真实用例、认证/WebVPN、扩大只读范围、写操作最后评审。
- 平台范围冻结为 Android + Windows；Apple 保持 SwiftUI。“镜像”按用户任务与数据语义对齐，不要求像素级复制系统控件。Rust/Flutter 工程仍未创建。

## 2026-10-22 · 功能登记表与剩余仓储边界

- Flutter 壳层改为功能登记表（`flutter/lib/workspace_catalog.dart`）：移动端标签、桌面侧栏、今日快捷入口与返回栈由同一条目派生，`main.dart` 只保留启动与登录状态机；登记为编译期静态表，不引入运行时插件加载。
- Apple 端抽出 `CheckInRepository` / `CampusNoticesRepository` / `GraduateAcademicRepository`，三个 ViewModel 只依赖仓储协议；缓存写入失败只记日志、失败保留旧值、签到单次提交与回查语义保持不变。
- 验证：macOS 232 项 XCTest、Flutter 127 项单元/widget 测试、Android arm64 Debug APK 与 iOS generic build 通过；证据见 [TESTING](TESTING.md)。
- 仍未完成：Library / CGYY / 认证仍直接组合客户端；移动端“个人与校园”快捷入口仍是精选清单；真实账号写操作与设备读屏未验收。

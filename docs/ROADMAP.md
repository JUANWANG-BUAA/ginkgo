# BUAA Assistant - 开发说明书（详细版）

> **本文档回答一个问题：从零到成品，每一步具体做什么、怎么做、怎么确认做对了。**
> 读者假设：你不熟 Swift 和 macOS 开发，AI 负责写代码，你负责决策、验收和把关。
> 严格按顺序推进，不跳步——每一步以前一步的**真机验收**为前提。
>
> 配套文档：协议细节查 [API.md](API.md)；界面实现与验收查 [UI-DESIGN.md](UI-DESIGN.md)；协作规则查 [COLLABORATION.md](COLLABORATION.md)；测试策略查 [TESTING.md](TESTING.md)；功能储备查 [BACKLOG.md](BACKLOG.md)。
>
> 版本：2026-10-13 详细版（初版纲要同日）；2026-10-14 勘误（Xcode 版本口径、objectVersion、骨架文件数、Step 2 会话恢复、execution 编码注意事项、arrangedList 拼写）；2026-10-15 更新扩展模块顺序；2026-10-16 更新实施状态。

---

## 当前推进位置（2026-10-16）

本文件保留从骨架开始的实施说明；下文 Step 0 的占位页面和测试数量是历史步骤，不是当前运行表现。当前代码状态以 [IMPLEMENTATION.md](IMPLEMENTATION.md) 为准；0.1.0-alpha 的收口状态与已知限制见 [RELEASE-NOTES.md](RELEASE-NOTES.md)。

| 步骤 | 当前状态 | 下一项验收 |
|------|----------|------------|
| Step 1–2 登录/会话 | 已实现，真实登录与自动恢复已有观察 | 验证码、断网、键盘与 VoiceOver |
| Step 3 本科课表 | 请求/解析/网格/缓存、考试安排入口与解析已实现 | 本科真实账号验收考试安排 |
| Step 4 研究生课表 | 周网格、全学期总览已实现，课程返回已有观察 | 单双周与教务页面对照、浅深色与窗口缩放 |
| Step 5 成绩 | 查询/归一化/列表/参考统计已实现 | 非空成绩与 GPA 手算对照 |
| Step 6 图书馆 | 当前时段预约、分区/座位统计、官网校区在馆人数和本机小时趋势估算已接入；研讨室日期/类型/校区筛选、45 个空间与逐时空档已接入；进行中预约、签到入座、临时离开、完全离开、按类型取消与研讨室 confirm/submit 表单已接入（macOS/iOS）；解析/加密/合成回归通过 | 座位预约→列表→取消、签到/暂离/完全离开真实闭环；研讨室真实预约/取消/参与人往返；官网没有楼层级人数 |
| 扩展 | Judge/SPOC 作业只读客户端及两来源详情、iclass 状态/手动签到/按日历史查询已接入；待办已实现 | 验收作业两来源和 iclass 原生直连；签到历史目前按日期查询，不是整学期汇总；SPOC 上传需先拿网页 HAR 取证；完成写操作往返与通知验收 |
| Step 7 增强 | 可选全局快捷键 ⌃⌥B、登录时自动启动、课前本地提醒均已接入 | macOS 登录项批准/注销验收；真实通知权限、投递/点击、休眠与课表覆盖验收 |
| Step 8 打磨 | 已补待办图标按钮辅助标签、启用彩色 AppIcon、设主窗口默认 1200×800 pt；重启构建后 CUA 确认窗口保持该尺寸，并削减空教室大结果分页的重复遍历和临时数组 | 窄窗口/浅色模式、全应用键盘/VoiceOver/Reduce Motion 验收；Instruments 记录启动和空闲内存；运行构建后确认 Dock/Finder 图标显示 |

当前课表/成绩缓存使用 actor + Codable JSON 文件，尚未采用下文规划的 SwiftData；本地待办使用按账号摘要命名的 UserDefaults 数据。

## 目录

- 第 0 部分：开始之前（准备、Xcode 第一课、代码阅读常识）
- 第 1 部分：骨架是怎么来的（从 0 复建工程的方法）
- 第 2 部分：通用开发循环（每个 Step 都重复的节奏）
- Step 0：首次运行与首次提交
- Step 1：CAS 登录全链路（最详细，第一座山）
- Step 2：会话与凭据管理
- Step 3：本科课表 + 菜单栏卡片
- Step 4：研究生课表
- Step 5：成绩 + GPA（含学期码归一化）
- Step 6：图书馆座位 + 研讨室
- Step 7：增强功能（通知/快捷键/自启动/储备收割）
- Step 8：打磨与分发
- 附录 A：验收记录表模板
- 附录 B：常见问题速查
- 附录 C：术语速查

---

## 第 0 部分：开始之前

### 0.1 你需要准备什么

| 项 | 要求 | 说明 |
|----|------|------|
| Mac | 可运行 Xcode 27 的机型 | 你当前机器已验证 |
| Xcode | 16+（工程格式要求；本机已装 27.0） | 免费，App Store 或 developer.apple.com |
| Apple ID | 可选 | 免费个人账号即可本机运行；分发他人才需要 $99/年（Step 8 才涉及） |
| 北航账号 | 你自己的学号密码 | 仅用于登录和验收，**任何时候不告诉 AI、不写进任何文件** |
| 网络 | 常规网络即可 | 2026-10-13 实测 6 个上游域名全部可达（见「网络环境前提」） |
| 终端 AI 代理 | ZCode 等 | 干活的"手" |

### 0.2 Xcode 第一课（10 分钟，跟着做一遍）

打开 `BUAA-Assistant.xcodeproj` 后认识五个东西：

1. **左侧导航区**（⌘0 开关）：文件树。我们的源码都在 `BUAA-Assistant/` 组下——这个组是"文件系统同步"的，磁盘上新增 .swift 文件会自动出现在这里并参与编译。
2. **顶部工具栏**：中间是 Scheme 选择器（应显示 `BUAA-Assistant → My Mac`）；右边 ▶️ 是运行。
3. **⌘R 运行**：编译并启动 App。第一次会编译较慢，耐心。
4. **⌘U 跑测试**：自动编译并运行全部单元测试，底部弹出 Test 导航显示绿勾/红叉。
5. **控制台**（⌘⇧Y 开关底部区域）：App 运行时的日志都打在这里。⌘. 停止运行。

另外两个进阶操作以后会用到：**断点**（点击代码行号左侧灰色区域出现蓝条，运行到该行会暂停，鼠标悬停变量可看值——调试网络返回值最有用）；**Previews**（Canvas 画布，⌥⌘↩ 打开，SwiftUI 视图可实时预览，不用跑整个 App）。

### 0.3 读代码的最小常识（看懂 AI 写的东西需要这些）

| 概念 | 一句话理解 |
|------|-----------|
| `struct` / `enum` / `class` | 值类型结构 / 枚举 / 引用类型类。SwiftUI 的 View 几乎都是 struct |
| `func foo() async throws` | 异步且可能抛错的函数，调用时要 `await`，错误用 `do-catch` 接 |
| `?` 和 `!` | 可选类型。`x?.y` 安全解包；`x!` 强制解包（为 nil 就崩溃，AI 滥用时要质问） |
| `guard let x = x else { return }` | "x 必须有值否则退出"，Swift 处理 nil 的标准姿势 |
| `@State` | 视图私有的可变状态，变了界面自动刷新 |
| `@EnvironmentObject` | 全局共享状态（我们的 `AppState`），任何视图都能读 |
| `@MainActor` | 标记"只能在主线程跑"——所有改 UI 的代码都需要 |
| `actor` | 编译器保证串行访问的并发单元，网络/存储服务用它防数据竞争 |
| `URLSession` | 系统的 HTTP 客户端，等价于你浏览器发请求的那一层 |

**读不懂某段代码时的标准动作**：把那段贴给 AI，说"用中文逐行讲解这段，我是 Swift 初学者"。讲解后仍含糊 → 要求换种写法或拆小。

### 0.4 网络环境前提

2026-10-13 从开发机实测：`sso` / `uc` / `byxt` / `gsmis` / `app` / `booking.lib` 六个域名 HTTPS 均可达（`byxt` 根路径 403 是未登录的正常应用层表现）。**多数网络环境可直连，不强制校园网**。换网络后若超时，先连学校 VPN；本项目仅直连，不内置隧道（ARCHITECTURE.md §9.1.3 既定决策）。

---

## 第 1 部分：骨架是怎么来的（从 0 复建的方法）

现在的工程骨架已就绪，这一部分**平时不需要动**，但当你想重建、或在别的机器上复建时按此执行。也是理解工程配置的速览。

1. **Xcode 工程**：`BUAA-Assistant.xcodeproj/project.pbxproj` 是手写的 Xcode 16+ 格式（objectVersion 70），关键决策：两个 target（App + 单元测试）、**文件系统同步组**（源码文件夹磁盘即真相）、测试通过 TEST_HOST 挂在 App 进程里跑。
2. **entitlements**（`BUAA-Assistant.entitlements`）：App Sandbox 开启 + `network.client`（出站网络权限）。这两条是 App 能联网的最低配置；以后加能力（通知不需要、文件访问需要）时在此追加。
3. **版本基线**：macOS 14.0（SwiftData 需要）、Swift 5 语言模式（避开 Swift 6 严格并发的迁移成本）。
4. **共享 Scheme**：`xcshareddata/xcschemes/` 里的 scheme 让终端 `xcodebuild` 和以后的 CI 能直接跑 build/test。
5. **源码骨架** 13 个文件（12 个应用源码 + 1 个测试文件）：入口（菜单栏+主窗口）、AppState、RootView、MainView（侧边栏）、LoginView/AuthViewModel（登录壳）、CasPageParser（第一块真实逻辑+13 测试）、APIClient（双会话）、四个占位页。
6. **铁律**（COLLABORATION §5.6）：`.xcodeproj` 工程文件 AI 永不手改；需要改工程配置（新 target、capability）时 AI 给步骤、你在 Xcode 界面点。

---

## 第 2 部分：通用开发循环（每个 Step 都重复的节奏）

```
① 确认依据：打开 API.md 对应章节，确认是 ✅ 已验证
② 派活：用 COLLABORATION §7.1 模板给 AI 下单（一次只派一个小任务）
③ AI 交付：代码 + 测试 + 用 §7.5 模板的中文讲解
④ 你验收：xcodebuild 全绿 + Xcode 里 ⌘R 亲手点一遍
⑤ 审查：过 COLLABORATION §4 清单（事实/安全/代码/文档四层）
⑥ 落盘：AI 更新 LEARNING.md；发现协议出入 → 以真实行为改 API.md 并登记 §0.0 对照表
⑦ 提交：git commit（中文一句话动机）
```

**节奏纪律**：一次一个小任务（一个解析器、一个界面、一段链路），不要让 AI 一次生成多个模块；每轮循环以真机点验收尾——Mock 全绿不算完，你亲手跑通才算完。

---

## Step 0：首次运行与首次提交（半小时）

1. 双击 `BUAA-Assistant.xcodeproj` 打开（首次询问信任选信任）。
2. Scheme 选 `BUAA-Assistant → My Mac`，**⌘R**。预期：出现登录窗口（学号/密码/登录按钮）；屏幕右上角菜单栏出现学位帽图标；点它弹出面板。
3. 点一下「登录」按钮：应弹出橙色提示"认证服务尚未接入：请按 docs/ROADMAP.md Step 1 实施"——这是预期行为（骨架不做假功能）。
4. **⌘U** 跑测试：预期 13 个测试全绿。
5. 首次提交（项目根目录终端）：
   ```bash
   git init
   git add -A
   git commit -m "项目骨架：菜单栏+主窗口+登录UI壳+CasPageParser及13个测试"
   ```
6. 建一个你自己的验收记录文件 `docs/ACCEPTANCE.md`（模板见附录 A），把 Step 0 的结果记进去并提交。

**验收标准**：第 2、3、4 步的预期全部符合。任何一步不符 → 停下，截图发给 AI 按附录 B 排查。

---

## Step 1：CAS 登录全链路（1-2 周，第一座山）

> **目标**：真实账号在 App 里登录成功，界面显示姓名学号，菜单栏图标变 ✓。
> **依据**：API.md §1（每一小步都有行号级参照）；参考实现 BBAA `LocalConnectionAuth.kt`。
> **为什么最难也最值得**：登录是所有功能的地基，且它把「网络层/解析层/状态层/UI 层」四个层面全部打通一遍——做完这个，后面的功能都是套模板。

### 1.0 准备（半天）

- 新建 `Core/Logging/AppLog.swift`：OSLog 统一封装。这是 DEEP-REVIEW §15 教训的第一落地——**从第一个网络模块起就要有日志**，禁止裸 `print`：
  ```swift
  import OSLog
  enum AppLog {
    static let auth = Logger(subsystem: "com.buaaassistant.app", category: "auth")
    static let network = Logger(subsystem: "com.buaaassistant.app", category: "network")
  }
  // 用法：AppLog.auth.info("登录页已获取，需验证码：\(hasCaptcha, privacy: .private)")
  // 注意：任何可能含学号/token 的值都用 privacy: .private 标记
  ```
- 新建 `Features/Auth/CasClient.swift` 空壳（actor），后续小步往里填方法。

### 1.1 登录页获取与解析（1-2 天）

**做什么**：`CasClient.fetchLoginPage()` → 用 `APIClient.shared.noRedirectSession` GET `https://sso.buaa.edu.cn/login`，返回结构体 `LoginPageInfo { execution: String?, captcha: CaptchaChallenge?, tip: String? }`。3xx → 走 1.4 的"已有会话"分支；200 → 用现成的 `CasPageParser` 解析。

**给 AI 的提示词要点**：依据 API.md §1.2 + §1.3；`CasPageParser` 已就绪勿重写；网络测试用 TESTING.md §3.0 的 `MockURLProtocol`；日志走 `AppLog.auth`。

**验收（你在 Xcode 做）**：临时在 LoginView 加一个 debug 按钮（验收后删）调 `fetchLoginPage()`，控制台打印 execution 非空；已登录状态（浏览器登录过）再点应打印"已有会话"。

**常见坑**：
- 用错会话：必须 `noRedirectSession`，自动跟随重定向会把 3xx"已有会话"信号吃掉；
-execution 值含 `+` `/` 字符——`URLComponents.queryItems` **不会**把 `+` 编成 `%2B`（`+` 在 query 中合法、原样保留，表单解码端当空格），组好后须对 `percentEncodedQuery` 再 `replacingOccurrences(of: "+", with: "%2B")`；手拼字符串同样必错（API.md §1.2 实测注记，2026-10-14 更正）。

### 1.2 登录表单构建与提交（1-2 天）

**做什么**：`buildLoginForm()` 按 API.md §1.4 的**通用收集策略**实现——解析登录页全部 `<input>`，hidden 全量回传 + `username/password/submit=登录/_eventId=submit/type=username_password`。验证码场景：`captcha` 与 `captchaResponse` **双字段填同一个用户输入值**（API.md §1.3）。`CasClient.submitLogin()` POST 表单。

**验收**：错误密码 → 控制台拿到上游错误文案或 401；正确密码 → 控制台出现 CASTGC Cookie 名（值打码 `AppLog` 输出 `***`）。验证码分支：让 AI 用 Mock 模拟带 `config.captcha` 的页面，真实触发留到 1.5 验收时如果风控出现再验。

**常见坑**：忘记把 1.1 拿到的**新鲜** execution 用进表单（页面 execution 是一次性的，旧值会失败）；hardcode 字段清单（上游加字段就断，必须走通用收集）。

### 1.3 重定向跟随与错误检测（1-2 天）

**做什么**：`followRedirectsAndCheckError()`——提交后用 noRedirectSession **手动逐跳** GET Location（相对路径按当前 URL 拼接，API.md §1.6），每跳后检查：最终 URL 含 `exception.message=`（取其后文本为错误消息）；HTTP 401 或页面重现 execution 输入框（账号密码错误）；`div#errorDiv`/`.errors`/`tip-text` 有内容。密码过期跳过页（`CasPageParser.isPasswordExpiryPage` 已就绪）：重新 POST `execution + _eventId=ignoreAndContinue`，**只跳一次**。

**验收**：故意输错密码，App 显示"账号或密码错误"（而不是闪退或无响应）；正确密码静默走完跳转链。

**常见坑**：跳转循环没有上限（设 10 跳上限防死循环）；把 3xx 当错误抛（3xx 是流程的一部分）。

### 1.4 UC 激活与会话验证（1 天）

**做什么**：`activateUc()` GET `https://uc.buaa.edu.cn/api/login?target=...`（API.md §1.7）；`validateSession()` GET `uc/api/uc/status` 带 Ajax 头，`code == 0 && data != null` → 成功，取 `schoolid/name` 构造 `UserData`。**5xx 是暂时错误，不得清会话**（API.md §1.8）。

**验收**：正确登录后控制台打印姓名学号；拔网线/断 Wi-Fi 再验证 → 显示网络错误而非"登录过期"。

### 1.5 LoginView 接线（1-2 天）

**做什么**：`AuthViewModel.login()` 替换真实调用链；状态机 `idle/loading/needCaptcha/error/success`；验证码出现时展示图片（LoginView 的 AsyncImage 已就绪）+ 输入框；登录成功 → `appState.isLoggedIn = true`，界面切换到 MainView，菜单栏图标变 ✓、面板显示姓名。

**验收（完整用户旅程）**：输错密码→看到明确错误；输对→进入主界面；再登出→回登录页（登出逻辑 Step 2 做，此时可以先重启 App 验证会话仍在）。

### 1.6 收尾

- 删掉所有 debug 按钮；过 COLLABORATION §4 四层清单；AI 讲解 + 更新 LEARNING.md；git 提交；验收记录进 `docs/ACCEPTANCE.md`。

---

## Step 2：会话与凭据管理（3-5 天）

**目标**：重启免登录、可登出、会话过期自动恢复。

任务分解：

1. **新建 `Core/Storage/KeychainManager.swift`**：save/read/delete 密码，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`（规范见 ARCHITECTURE.md §5.1；Keychain 是系统 API 无需取证）。「记住密码」开关控制存取；启动时预填。
2. **会话恢复**：App 启动 → `validateSession()` → 有效直接进主界面；无效且 Keychain 存有密码（「记住密码」开启）→ **静默重登一次**再进主界面；无密码则回登录页。注意：`CASTGC`/`JSESSIONID` 是会话 Cookie（无 Expires），`HTTPCookieStorage` **不会跨进程重启保留它们**——下面「重启免登录」的验收实际由静默重登达成，不是 Cookie 还在（设计依据 ARCHITECTURE.md §4.1 第 5 条；验收时顺带实测 CASTGC 是否带 Expires，结论登记 API.md §1.8）。
3. **两步确认**（API.md §1.8）：任何业务请求报未登录 → 先复核 `uc/status` → 确认无效才清 Cookie+会话回登录页。**5xx 永不清会话**。
4. **登出**：GET `sso/logout` → 清 Keychain → 清 HTTPCookieStorage → 回登录页。SettingsView 从占位页改为真实设置页（含退出按钮）。

**验收**：重启 App 免密自动进入主界面；手动登出后回登录页，且打开系统「钥匙串访问」App 搜 `com.buaaassistant` 无残留条目；把系统时间往后调几天（模拟过期）→ 正确回到登录页而不是报一堆错。

**常见坑**：清了 Keychain 忘清 Cookie（半登出状态最诡异）；登出请求失败也要清本地（BBAA 的做法，`LocalConnectionAuth.kt:613-622`）。

---

## Step 3：本科课表 + 菜单栏卡片（1 周）

**目标**：本科账号看到完整周课表，断网可用，菜单栏显示下一节课。

任务分解（顺序即依赖序）：

1. **门户探测** `ScheduleClient.probePortal()`：GET `currentUser.do`（API.md §2.1），按响应分类：未登录（走 Step 2 两步确认）/ 本科就绪 / 研究生门户（转 Step 4 逻辑）。
2. **学期/周次**：`schoolCalendars.do`（注意 URL 带 `student/` 段）→ `getTermWeeks.do?termCode=`。成功码是**字符串** `"0"`（API.md 附录 C，禁统一抽象）。
3. **周课表**：POST `student/getMyScheduleDetail.do`，表单 `termCode/type=week/week`；解析 `datas.arrangedList[]`。`datas.code` 是**学号**（PII，注意裁剪、不得当学期标识）。
4. **SwiftData 缓存**：新建 `Core/Storage/` 下课表实体（termCode/week 为键）+ ModelActor 隔离写入；读取走 Stale-While-Revalidate（先显缓存，后台刷新，ARCHITECTURE.md §4.2）。
5. **周视图 UI**：周次切换（上/下周按钮）、课程卡片（名称/地点/节次/颜色用上游 `color` 字段）、今日高亮。
6. **菜单栏卡片**：`teachingSchedule/detail.do?rq=今天&lxdm=student`（API.md §2.5）→ MenuBarPanel 显示「下一节课」。菜单栏是产品核心价值，**随本 Step 交付，不拖到最后**。
7. **已接入（BACKLOG A-1）**：本科考试安排 `exams.do`（API.md §2.6）；课表中提供卡片列表、刷新/失败状态及研究生隐藏入口。真实本科账号验收待进行。

**验收**：本科真实账号本学期课表完整正确（和教务网页对照两门课）；断网重启 App 仍能看缓存课表；菜单栏显示下一节课；周次切换流畅；考试页显示考场座位号。

**常见坑**：Referer 头（`homeapp/index.html`，exams.do 是多一级 `/home/` 的变体——直接抄 API.md 每节的头要求）；把 `datas.code` 当学期标识。

---

## Step 4：研究生课表（4-6 天）

**目标**：研究生账号（探测落在 GRADUATE_READY）也能看课表。

任务分解：

1. GSMIS 三请求：`*default/index.do` 探测 → `kfdxnxqcx.do`（POST 空体，成功码 `"0"`）→ `loadXskbData.do`（表单 `ZC=&XNXQDM=<20251>&XH=&XQDM=`，成功码 **`"1"`**——与上一接口不同，勿抽象）。全部依据 API.md §3。
2. 解析三数组：`jgList`（排课）/`rwList`（课程+学分+SCSKRQ）/`jcfaList[].skjcList`（节次方案）；字段对照 API.md §3.3 表格逐个核对。
3. **ZCBH 周次位图**（每字符 0/1，下标+1=周次）与**开学日期反推**（SCSKRQ − 最早排课偏移，须唯一且为周一）——算法在 API.md §3.3 有完整描述，BBAA `GsmisSchedule.kt:42-68` 可对照移植，**必须配单元测试**（含单双周用例）。
4. 复用 Step 3 的周视图渲染。

**验收**：研究生真实账号课表正确；找一门单双周课（ZCBH 非全 1）验证周次显示；与研究生教务网页对照。

---

## Step 5：成绩 + GPA（4-6 天）

**目标**：查成绩、算 GPA，研究生也能用。

任务分解：

1. **学期码归一化** `TermCodeNormalizer`（**研究生必做，原工程已知缺口**，API.md §4.2 注记）：`20251` ↔ `2025-2026-1` 双向转换 + 单元测试。
2. 成绩链路：GET 激活（HTML Accept 头）→ POST 同 URL 表单 `xq/year` → 解析 `e/m/d`（`e` 是 **Int** 0）。`xf/kccj` 类型漂移：先收原始 JSON 再转 `Double?`。
3. **等级绩点映射核对流程（人工步骤，不可跳过）**：去教务处/研究生院官网找官方等级制规定（百分制公式 `4-3(100-x)²/1600` 已确认是官方形态可直接用；优/良/中/及格的绩点**必须找到书面依据**），把来源 URL 记进 API.md §4 再让 AI 写映射——TESTING.md §2.2 的实证警告：UBAA 的等级映射就是没核对瞎定的，测试锁的也是错值。
4. 成绩列表 UI + 学期切换 + GPA/加权均分统计卡（纯计算独立成 `GradeStatistics.swift`，勿放 UI 文件——DEEP-REVIEW §15.2 教训 3）。
5. 菜单栏 GPA 卡片接入。

**验收**：成绩与教务网页一致；绩点抽两门课手算核对；「优/良/通过」等非百分制成绩不崩溃不计入或按官方规则计入（依第 3 步核对结果）；**研究生账号能查成绩**（归一化生效）；菜单栏 GPA 正确。

---

## Step 6：图书馆座位 + 研讨室（1 周）

**目标**：楼馆→分区→座位→预约→取消全链路。

任务分解：

1. **TLS 证书链实测（先做，人工步骤）**：终端跑 `curl -v https://booking.lib.buaa.edu.cn/ 2>&1 | grep -A3 "SSL"`；再在 App 里发一个探测请求。证书正常 → 继续；异常 → 把 curl 输出发给 AI 评估方案（JVM/Android 上 UBAA 做过仅限此域名的信任放宽，Darwin 是否需要实测才知道；**禁止静默全站放宽**，方案必须人工评审）。
2. CAS 链：GET `sso/login?service=.../v4/login/cas`（禁重定向）→ 手动跟最多 8 跳、正则 `[?&#]cas=([^&#]+)` 提取令牌（查询串和 fragment 都要兼容）→ POST `v4/login/user {"cas": token}` → 取 `data.member.token`。
3. 业务端点：全部 POST JSON（API.md §5.2 表），公共头带桌面 Chrome UA + `X-Requested-With` + Origin/Referer；鉴权头 **`Authorization: bearer<token>`（小写、无空格）**；成功码 `code ∈ {0,1}`；字段名 snake/camel 双变体都要接。
4. **预约加密**：CommonCrypto AES-CBC（密钥=日期 8 数字+反转，IV=`ZZWBKJ_ZHIHUAWEI`，CommonCrypto 开启 PKCS7，Base64）——先写**加密向量黄金文件测试**（TESTING.md §10）再写实现。CryptoKit 不支持 CBC，别让 AI 用错框架。
5. 失效重登：响应 message 含「登录失效/请重新登录/未登录」→ 清 token 重新 CAS，**重试一次**即止。
6. UI：楼馆列表→分区→当前开放时段自动定位→座位网格→预约弹窗→我的预约→取消；不要求用户选择预约日期和时段。分区/座位统计按空闲/总数呈现，不称为真实在馆人数；只在用户查询时采样本机历史，估算需至少 3 个同星期/小时样本。写操作按钮确认弹窗；失败保留“状态未确认”提示、**绝不自动重发**（API.md §9）。
7. 官网人数：只读请求 API.md §5.5 的公开空间页，分开展示校区与官网明确提供的阅览室人数；本机按校区/日期/小时采样，趋势使用历史均值，不能推断官网未提供的楼层人数。
8. **探索项（BACKLOG A-2）**：研讨室是否属于 `space/pick` 的 `boutiqueIds` 分类仍需真实页面请求证据，不猜测分区 ID。
9. **座位生命周期（API.md §5.6）**：当前预约改读 `index/subscribe`，按 `flag_in/flag_out/flag_leave/oksign` 展示签到入座、临时离开、完全离开与取消；操作二次确认、空 `points`、提交后回查、不自动重试。**真实写入待验收**。
10. **图书馆研讨室（API.md §5.7）**：在只读空档上增加参与人解析、提交前空档复核、`confirm/submit` 分支和按类型取消；`type_id == 5 && earlierPeriods == 3` 与要求附件的空间不提交。**真实写入待验收**。
11. **教学楼研讨室（API.md §6B）**：2026-10-19 按用户明确要求新增 CGYY 登录、MD5 签名、场馆/时段/订单/门锁密码与滑块自动识别；真实预约/取消/密码往返待验收。

**验收**：全链路真机走通（用本人账号，预约后**立即取消**）；取消后座位状态刷新。座位签到/暂离/完全离开与研讨室预约需另做真实往返并核对回查结果。

---

## Step 7：增强功能（弹性，按需排序）

1. **系统通知**（课程前 10 分钟提醒）：已接入独立开关和 `UNUserNotificationCenter` 本地调度；只使用未来 14 天内缓存且开课时间明确的课程周次，本科未查询周不推测，通知正文隐藏课程名/地点。点击通知会激活主窗口；仍需验收系统授权、真实投递/点击、休眠及课表覆盖。
2. **快捷键**：全局键用 Carbon `RegisterEventHotKey`；当前 ⌃⌥B 恢复并聚焦主窗口，可从应用菜单关闭。窗口内快捷键用 `.keyboardShortcut`。
3. **开机自启**：已接入 `SMAppService.mainApp.register()/unregister()`；设置页显示系统授权状态并可打开登录项设置。需在真实 macOS 用户会话中验收首次批准、注销和下次登录启动。
4. **扩展顺序**：Judge 与 SPOC 作业真实账号逐来源验收；iclass 状态查询与手动签到已接入，下一步需人工验收原生登录、真实写入往返、状态回查与通知。
5. **打卡成功确认**：手动提交仅在逐课程二次确认后执行。只有提交成功响应后重新读取上游状态并观察到已签到才显示“成功”；超时、断网或响应不明确显示“结果待确认”，提供立即回查入口，禁止自动重发。当前写协议仅参考 BBAA 源码，真实往返未验收。
6. **快速通知**：登录工作区当前以约 30 秒只读刷新、状态变化去重及应用内 toast 提示；请求失败后退避至 120 秒。用户可主动授权通用 macOS 通知；仍需验收通知投递、后台运行、授权关闭、休眠和上游限流行为，不能承诺秒级送达。
7. **写操作边界**：作业提交、阳光打卡提交（尤其照片 multipart）仍暂缓；原版 BBAA SPOC 接口当前只有列表/详情，没有上传实现。需由本人正常网页操作并提供脱敏 HAR 后取证，之后再实现预览、人工确认、单次提交和权威回查；iclass 签到写入仅可由用户逐项确认触发，在真实往返验证与安全审查前不得宣称已验收。
8. 探索项：借阅查询（先执行 API.md §6 验证清单：本人浏览器登录图书馆→我的借阅→导出脱敏 HAR→产出取证报告→人工确认）。

## Step 8：打磨与分发（1 周）

1. **HIG 自查**（ARCHITECTURE.md §10.11）：语义色无硬编码、所有图标按钮有 accessibilityLabel、Reduce Motion/Transparency 下界面可读、键盘可完整操作（Tab 遍历）。
2. **性能**：Xcode Instruments → Time Profiler 看启动（目标 <2s）；XCTMemoryMetric 看空闲内存（<50MB）；`List` 内不用重度材质。
3. **App 图标**：彩色 `Assets.xcassets/AppIcon.appiconset` 已准备，并已在 App target Debug/Release 配置中绑定 `AppIcon`。构建需确认生成 `Assets.car` 与 `CFBundleIconName`，运行后检查 Dock/Finder 显示。
4. **XCUITest UI 测试 target**：File → New → Target → UI Testing Bundle（**你在 Xcode 操作**，AI 写测试代码，TESTING.md §4 有 macOS 版用例）。
5. **分发**：自用 → `xcodebuild` 出 App 直接跑；发同学 → 需要 Developer Program（$99/年）+ Developer ID 签名 + `notarytool` 公证。具体步骤届时让 AI 按 Apple 最新文档出清单（公证流程年年在变，以官方文档为准，AI 引用时要求附来源）。

---

## 附录 A：验收记录表模板（`docs/ACCEPTANCE.md`）

```markdown
# 验收记录

| 日期 | Step | 账号类型 | 验收项 | 结果 | 备注/证据 |
|------|------|----------|--------|------|-----------|
| 2026-10-13 | 0 | - | App 运行/13 测试全绿/首提交 | ✅ | - |
```

规则：每 Step 验收完追加一行再提交；发现 bug 记录后先修再继续；**账号类型**必填（本科/研究生），同一功能两种账号都要验过的在备注注明。

## 附录 B：常见问题速查

| 症状 | 处理 |
|------|------|
| Xcode 运行报签名错误 | Xcode → Settings → Accounts 登录 Apple ID；Team 选个人团队；还不行让 AI 看 `CODE_SIGN_STYLE` 配置 |
| Xcode 行为怪异/索引错乱 | 让 AI 给清理命令；最后手段 `rm -rf ~/Library/Developer/Xcode/DerivedData/BUAA-Assistant-*`（安全） |
| AI 代码编译不过 | 整段报错贴回："解释这个错误，给最小修复，不要顺手改别的" |
| 请求行为与 API.md 不符 | 大概率上游变了 → 走 COLLABORATION §2.2 取证流（你抓 HAR） |
| Mock 测试过、真机不行 | 以真机为准；把真机响应（脱敏）存成新黄金文件，对比差异 |
| 换网络后全部超时 | 见 §0.4：连学校 VPN，跑 TESTING.md §9 巡检 |
| 登录总失败但密码对 | 九成是验证码被触发或 execution 过期：看控制台 `AppLog.auth` 输出对号入座 |
| 写操作结果不确定 | 不要重发！先回查状态（API.md §9 原则） |

## 附录 C：术语速查

| 术语 | 含义 |
|------|------|
| CAS / SSO | 学校统一认证：sso.buaa.edu.cn 的表单登录，票据靠 Cookie 流转 |
| CASTGC | CAS 的登录票据 Cookie，HttpOnly，登录态的根 |
| execution | 登录页隐藏字段，一次性令牌，提交表单必须带上 |
| UC | uc.buaa.edu.cn，用户中心；`/api/uc/status` 是会话有效性唯一判据 |
| noRedirect | 禁止自动跟随重定向的会话；认证链必须手动逐跳处理 |
| 黄金文件 | 上游响应的脱敏快照，用于回归检测上游结构变化 |
| SWR | Stale-While-Revalidate：先给缓存再后台刷新 |
| 学期码 | 本科 `2025-2026-1` / 研究生 `20251` / 成绩 `year+xq` 三套格式，见 API.md §4.2 归一化 |

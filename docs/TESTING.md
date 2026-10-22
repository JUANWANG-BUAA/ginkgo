# BUAA Assistant - 测试计划

Rust / Flutter 本轮跨语言、锁恢复和平台结果见 [Opus 5.5 原评审落实](_audit/2026-10-21-opus-review-followup.md)、[Android Alpha.4](archive/mirror/MIRROR-ANDROID-ALPHA4.md) 与 [PD Windows 11 主机验证](archive/mirror/WINDOWS-2026-10-21.md)；合成测试与真实业务验收分别记录。

## 已记录测试证据（2026-10-21）

本次本机运行：macOS 全量 XCTest **220 项通过**；iOS 27.0 / Ginkgo iPhone 17 Pro 模拟器的共享单元测试 **220 项通过**，均无失败（`xcodebuild test` 退出码 0，`xcresulttool get test-results summary` 确认）。iOS 工程由既有 `project.yml` 经 XcodeGen 重新生成以纳入新增共享测试；本次未跑 UI / live 测试。Xcode 的模拟器系统版本解析警告未阻止测试。数量只表示本次运行，不作为后续源码总数承诺。

新增 [SharedParserContractTests](../BUAA-AssistantTests/SharedParserContractTests.swift) 直接读取 Rust runner 使用的同一份 fixture，覆盖 9 类契约、17 份样例的 CAS / 教务 / 成绩 / SPOC 加密投影；原有共享规则样例继续执行。未覆盖到 Swift 的模块清单见 [fixtures](../fixtures/README.md)。本次未改 Swift 生产代码。

Rust workspace 测试、严格 Clippy、Flutter analyze / widget tests、Android arm64 调试包与落地页浏览器检查的结果和边界统一记录于 [评审落实](_audit/2026-10-21-opus-review-followup.md)。真实设备、网络写入和签名分发单独验收，不由模拟器或构建替代；此前真机证据按原日期保留。

现有覆盖包括共享日历 / 编码 / 缓存、刷新节流、筛选与状态呈现；图书馆生命周期、研究生学分、CGYY 加密 / 订单、签到目标匹配、认证 / 路由和学校解析器等。下表用于定位，不重复维护总数。

```sh
xcodebuild build -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
git diff --check
```

### iOS 子项目（2026-10-18）

iOS target 复用同一份 `BUAA-AssistantTests/`，页面层使用独立原生 SwiftUI。当前已在标准 iOS 27.0 Runtime 上完成：

- iPhone 17 Pro：212 项单元测试、0 失败；登录、自适应导航及博雅/研讨室/研究生教务入口 UI 测试通过。完整 XCTest 170 项中 169 项通过、1 项仅在未注入凭据时跳过。
- iPhone SE (3rd generation)：完整 UI 冒烟测试 3 项中 2 项通过、1 项凭据测试跳过；新入口在窄屏可滚动并成功打开。
- iPad Pro 11：完整 UI 冒烟测试 3 项中 2 项通过、1 项凭据测试跳过；侧栏新入口与详情切换正常。
- iPhone 17 Pro live UI：注入临时凭据后登录成功，并实际进入博雅、研讨室、研究生教务读回数据；测试通过。

```sh
xcrun simctl list devices available
xcodebuild test \
  -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj \
  -scheme Ginkgo-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'
```

当前 Xcode 27.1 的 iOS 27.1 Runtime 只注册 `iPhone Duo`，普通 iPhone/iPad 应使用标准 iOS 27.0 Runtime。仓库同时声明了 `.github/workflows/ios.yml`，但 GitHub Actions 首次远端运行尚未取得结果。真实账号验收中，直连 UC 被 HTTP 483 拦截后客户端自动切换 WebVPN，CAS 登录成功并通过 `uc/status` 的 `code == 0 + data` 判据；WebVPN 下研究生课表（20 学期、30 周、7 门课程）、成绩服务、空教室、图书馆座位、校园通知、SPOC（13 项作业）与 iclass 只读状态均已实测；博雅读回 74 门课程，研讨室读回 45 个空间，研究生教务读回学籍摘要、10 章培养方案和 59 门计划课程。Judge 课程列表仍待适配。详见 [ACCEPTANCE.md](ACCEPTANCE.md)。iOS 验证边界与真机清单见 [IOS.md](IOS.md)。

| 实际测试文件 | 覆盖范围 |
|---|---|
| CasPageParserTests / CasFormParserTests | 页面字段、验证码识别、隐藏表单与编码 |
| CasClientTests / AppStateSessionTests | 模拟认证响应、会话恢复、4xx/483 错误、WebVPN 显式路由与本地清理 |
| UpstreamRouteTests | 自动回退、URL/Cookie 隔离、Referer/Origin 重写、网关相对重定向与表单 action |
| BykcClientTests / BykcRepositoryTests / BykcCourseCatalogTests | BYKC 加密信封、纯学期规则、服务/账号缓存边界、共享课程筛选 fixture 与未分类类别语义 |
| SeminarParserTests | 研讨室筛选、空间列表、占用区间、空档扣除与详情轴数据 |
| GraduateAcademicClientTests | 学籍白名单映射、教务应用目录与培养方案课程格式 |
| ScheduleParserTests | 本科结构、研究生周次位图、开学日期、学期码缺省与节次合并 |
| GradeParserTests | 学期归一化、字段类型漂移、不及格计入与等级制排除 |
| TimetableAndLibraryTests | 交错课程分栏、CAS query/fragment、AES-CBC OpenSSL 固定向量 |
| ClassroomViewModelTests / ExamViewModelTests | 后台筛选/排序/计数一致性、分页可达性、账号磁盘缓存、考试解析与业务错误 |
| CheckInClientTests / CheckInViewModelTests | iclass 状态、重复行与并发刷新、WebVPN 回退、通知去重与权限提示 |
| JudgeHomeworkClientTests / SpocHomeworkClientTests / HomeworkViewModelTests | 两来源作业解析、详情归属、状态保留与缓存兼容 |
| LibraryPublicStatsParserTests / LibraryOccupancyHistoryTests / CampusNoticesClientTests / WorkspaceIntegrationTests | 官网人数解析、本机聚合历史、通知缓存、账号隔离与工作区重置 |
| GinkgoSmokeUITests | iOS 原生登录输入、主 Tab / iPad 侧栏、二级页导航与设置；真实账号 live test 在未注入凭据时跳过 |

尚无自动化证据：图书馆业务请求与真实预约闭环、空教室请求、待办存取交互、完整网络缓存失败路径、窗口快照及 VoiceOver。覆盖率尚未测量，iOS 真机矩阵、完整 UI 流程与黄金文件目录仍待补齐；iOS CI 工作流已声明但尚未取得远端运行结果。以下各节保留目标测试方案及示例，出现 AuthService、GPACalculator 等类型不表示工程已有这些实现；部分历史示例绩点映射也不代表当前规则。实际规则以 GradeModels.swift 与 GradeParserTests.swift 为准。

## 1. 测试策略概述

### 1.1 测试金字塔

```
        ┌─────────────┐
        │  E2E Tests  │  少量：关键用户流程
        ├─────────────┤
        │  UI Tests   │  中量：界面交互
        ├─────────────┤
        │Integration  │  中量：模块间协作
        │   Tests     │
        ├─────────────┤
        │  Unit Tests │  大量：纯逻辑测试
        └─────────────┘
```

### 1.2 测试覆盖率目标

| 层级 | 覆盖率目标 | 说明 |
|------|-----------|------|
| 单元测试 | ≥ 80% | 核心业务逻辑 |
| 集成测试 | ≥ 60% | API 调用、数据存储 |
| UI 测试 | 关键路径 | 登录、课表、成绩 |
| E2E 测试 | 核心流程 | 完整用户旅程 |

### 1.3 测试工具

| 工具 | 用途 |
|------|------|
| XCTest | 单元/集成/UI 测试框架 |
| XCUITest | UI 自动化测试 |
| Swift Testing | 新测试框架（可选） |
| Snapshot Testing | UI 快照测试 |

---

## 2. 单元测试

### 2.1 认证模块测试

> **建模口径修订（2026-10-14）**：旧版草案按 `AuthToken(tgt:)` 建模（login 返回 token、Keychain 存/刷 token），与既定认证设计矛盾——本项目为纯 Cookie 会话，客户端不持有任何 token（ARCHITECTURE.md §4.1）。本版重写：登录返回 `UserData`；Keychain 只存密码且受「记住密码」开关控制；会话判定 = `uc/status`（区分暂时失败与确认无效，API.md §1.8）；会话恢复 = 静默重登（会话 Cookie 不跨重启持久化）。旧草案的「登录失败自动重试 2 次」已删——登录 POST 属写操作，不自动重试（API.md §9）。

#### 测试文件：`AuthServiceTests.swift`

```swift
import XCTest
@testable import BUAA_Assistant

final class AuthServiceTests: XCTestCase {
    var sut: AuthService!
    var mockKeychain: MockKeychainStore!
    var mockAPI: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainStore()
        mockAPI = MockAPIClient()
        sut = AuthService(keychain: mockKeychain, apiClient: mockAPI)
    }
    
    override func tearDown() {
        sut = nil
        mockKeychain = nil
        mockAPI = nil
        super.tearDown()
    }
    
    // MARK: - 登录测试（纯 Cookie 会话：登录返回 UserData，无 token）
    
    func test_login_withValidCredentials_shouldReturnUserData() async throws {
        // Given
        sut.rememberPassword = true
        mockAPI.mockLoginResponse = .success(UserData(schoolid: "sy2501001", name: "李文"))
        
        // When
        let user = try await sut.login(username: "sy2501001", password: "validPassword")
        
        // Then
        XCTAssertEqual(user.schoolid, "sy2501001")
        XCTAssertTrue(mockKeychain.hasPassword(for: "sy2501001"))  // 「记住密码」开启才落 Keychain
    }
    
    func test_login_withRememberPasswordOff_shouldNotStorePassword() async throws {
        // Given
        sut.rememberPassword = false
        mockAPI.mockLoginResponse = .success(UserData(schoolid: "sy2501001", name: "李文"))
        
        // When
        _ = try await sut.login(username: "sy2501001", password: "validPassword")
        
        // Then
        XCTAssertFalse(mockKeychain.hasPassword(for: "sy2501001"))
    }
    
    func test_login_withInvalidCredentials_shouldThrowAuthError() async {
        // Given
        mockAPI.mockLoginResponse = .failure(.invalidCredentials)
        
        // When & Then
        do {
            _ = try await sut.login(username: "test", password: "wrong")
            XCTFail("Should throw error")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_login_withCaptchaRequired_shouldThrowCaptchaChallenge() async {
        // Given — 协议见 API.md §1.3
        let challenge = CaptchaChallenge(
            type: "local", id: "cap-123",
            imageURL: URL(string: "https://sso.buaa.edu.cn/captcha?captchaId=cap-123")!
        )
        mockAPI.mockLoginResponse = .failure(.captchaRequired(challenge))
        
        // When & Then
        do {
            _ = try await sut.login(username: "test", password: "test")
            XCTFail("Should throw error")
        } catch let error as APIError {
            if case .captchaRequired(let c) = error {
                XCTAssertEqual(c.id, "cap-123")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - 会话测试（uc/status 唯一判据 + 两步确认，API.md §1.8）
    
    func test_validateSession_withValidCookie_shouldReturnUser() async throws {
        // Given
        mockAPI.mockStatusResponse = .success(UserData(schoolid: "sy2501001", name: "李文"))
        
        // When
        let user = try await sut.validateSession()
        
        // Then
        XCTAssertEqual(user?.schoolid, "sy2501001")
    }
    
    func test_validateSession_withUpstream5xx_shouldNotClearSession() async throws {
        // Given — 5xx 是暂时性错误，不得清会话（API.md §1.8）
        mockAPI.mockStatusResponse = .failure(.upstreamError(502, nil))
        
        // When
        let outcome = try await sut.validateSessionOutcome()
        
        // Then — 区分「暂时失败」与「确认无效」，只有后者才清会话
        XCTAssertEqual(outcome, .transientFailure)
    }
    
    // MARK: - 会话恢复测试（会话 Cookie 不跨重启持久化 → 静默重登，ARCHITECTURE.md §4.1）
    
    func test_restoreSession_withRememberedPassword_shouldSilentlyRelogin() async throws {
        // Given
        mockKeychain.savePassword("validPassword", for: "sy2501001")
        mockAPI.mockStatusResponse = .failure(.sessionExpired)
        mockAPI.mockLoginResponse = .success(UserData(schoolid: "sy2501001", name: "李文"))
        
        // When
        let user = try await sut.restoreSession()
        
        // Then
        XCTAssertEqual(user?.schoolid, "sy2501001")
        XCTAssertEqual(mockAPI.loginCallCount, 1)  // 静默重登恰好一次
    }
    
    func test_restoreSession_withoutRememberedPassword_shouldNotAttemptLogin() async throws {
        // Given
        mockAPI.mockStatusResponse = .failure(.sessionExpired)
        
        // When
        let user = try await sut.restoreSession()
        
        // Then — 无凭据不发起登录，回登录页
        XCTAssertNil(user)
        XCTAssertEqual(mockAPI.loginCallCount, 0)
    }
    
    // MARK: - 登出测试（登出请求失败也清本地，API.md §1.9）
    
    func test_logout_shouldClearKeychainAndCookies() async throws {
        // Given
        mockKeychain.savePassword("test", for: "sy2501001")
        
        // When
        try await sut.logout()
        
        // Then — Keychain 与 Cookie 都要清（半登出状态最诡异，ROADMAP Step 2）
        XCTAssertFalse(mockKeychain.hasPassword(for: "sy2501001"))
        XCTAssertTrue(mockAPI.cookiesCleared)
    }
}
```

### 2.2 GPA 计算器测试

#### 测试文件：`GPACalculatorTests.swift`

```swift
import XCTest
@testable import BUAA_Assistant

final class GPACalculatorTests: XCTestCase {
    var sut: GPACalculator!
    
    override func setUp() {
        super.setUp()
        sut = GPACalculator()
    }
    
    // MARK: - 基本计算测试
    
    func test_calculateGPA_withSingleCourse_shouldReturnCorrectGPA() {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 92, gpa: 4.0, semester: "2025-2026-1")
        ]
        
        // When
        let result = sut.calculateGPA(from: grades)
        
        // Then
        XCTAssertEqual(result.gpa, 4.0, accuracy: 0.01)
        XCTAssertEqual(result.totalCredits, 4.0)
    }
    
    func test_calculateGPA_withMultipleCourses_shouldReturnWeightedAverage() {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 90, gpa: 4.0, semester: "2025-2026-1"),
            Grade(courseName: "操作系统", credit: 3.0, score: 85, gpa: 3.5, semester: "2025-2026-1"),
            Grade(courseName: "网络", credit: 3.0, score: 80, gpa: 3.0, semester: "2025-2026-1")
        ]
        
        // When
        let result = sut.calculateGPA(from: grades)
        
        // Then
        // (4.0*4 + 3.5*3 + 3.0*3) / (4+3+3) = (16+10.5+9) / 10 = 35.5/10 = 3.55
        XCTAssertEqual(result.gpa, 3.55, accuracy: 0.01)
        XCTAssertEqual(result.totalCredits, 10.0)
    }
    
    func test_calculateGPA_withEmptyGrades_shouldReturnZero() {
        // Given
        let grades: [Grade] = []
        
        // When
        let result = sut.calculateGPA(from: grades)
        
        // Then
        XCTAssertEqual(result.gpa, 0.0)
        XCTAssertEqual(result.totalCredits, 0.0)
    }
    
    func test_calculateGPA_withFailedCourse_shouldExcludeFromGPA() {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 90, gpa: 4.0, semester: "2025-2026-1"),
            Grade(courseName: "挂科", credit: 3.0, score: 55, gpa: 0.0, semester: "2025-2026-1")
        ]
        
        // When
        let result = sut.calculateGPA(from: grades, excludeFailed: true)
        
        // Then
        XCTAssertEqual(result.gpa, 4.0, accuracy: 0.01)
        XCTAssertEqual(result.totalCredits, 4.0)
    }
    
    // MARK: - 分类计算测试
    
    func test_calculateGPA_byCategory_shouldGroupCorrectly() {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 90, gpa: 4.0, semester: "2025-2026-1", category: .required),
            Grade(courseName: "通识", credit: 2.0, score: 85, gpa: 3.5, semester: "2025-2026-1", category: .general),
            Grade(courseName: "选修", credit: 3.0, score: 80, gpa: 3.0, semester: "2025-2026-1", category: .elective)
        ]
        
        // When
        let result = sut.calculateGPAByCategory(from: grades)
        
        // Then
        XCTAssertEqual(result[.required]?.gpa, 4.0, accuracy: 0.01)
        XCTAssertEqual(result[.general]?.gpa, 3.5, accuracy: 0.01)
        XCTAssertEqual(result[.elective]?.gpa, 3.0, accuracy: 0.01)
    }
    
    // MARK: - 学期计算测试
    
    func test_calculateGPA_bySemester_shouldGroupCorrectly() {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 90, gpa: 4.0, semester: "2025-2026-1"),
            Grade(courseName: "操作系统", credit: 3.0, score: 85, gpa: 3.5, semester: "2025-2026-1"),
            Grade(courseName: "网络", credit: 3.0, score: 80, gpa: 3.0, semester: "2025-2026-2")
        ]
        
        // When
        let result = sut.calculateGPABySemester(from: grades)
        
        // Then
        XCTAssertEqual(result["2025-2026-1"]?.gpa, 3.78, accuracy: 0.01)
        XCTAssertEqual(result["2025-2026-2"]?.gpa, 3.0, accuracy: 0.01)
    }
    
    // MARK: - 边界情况测试
    
    func test_calculateGPA_withZeroCredit_shouldNotCrash() {
        // Given
        let grades = [
            Grade(courseName: "零学分", credit: 0.0, score: 90, gpa: 4.0, semester: "2025-2026-1")
        ]
        
        // When
        let result = sut.calculateGPA(from: grades)
        
        // Then
        XCTAssertEqual(result.gpa, 0.0)
    }
    
    func test_scoreToGPA_withVariousScores_shouldMapCorrectly() {
        // Given & When & Then
        // ⚠️ 下述映射是假设的等级制，编码前必须先核对北航官方成绩等级规定，
        // 并确认目标用户（本科/研究生）的绩点制度差异。
        // 实证（2026-10-13，DEEP-REVIEW §15）：UBAA 的等级映射（优 4.0/良 3.5/中 2.8/及格 1.7）
        // 查无官方出处，其 GradeScreenLogicTest 只锁定了假设值；百分制公式 4-3(100-x)²/1600
        // 是官方已知形态可沿用。等级映射未核对前不得进入 GPA 计算。
        XCTAssertEqual(sut.scoreToGPA(95), 4.0)
        XCTAssertEqual(sut.scoreToGPA(90), 4.0)
        XCTAssertEqual(sut.scoreToGPA(85), 3.5)
        XCTAssertEqual(sut.scoreToGPA(80), 3.0)
        XCTAssertEqual(sut.scoreToGPA(75), 2.5)
        XCTAssertEqual(sut.scoreToGPA(70), 2.0)
        XCTAssertEqual(sut.scoreToGPA(60), 1.0)
        XCTAssertEqual(sut.scoreToGPA(59), 0.0)
    }
}
```

### 2.3 课表解析测试

> 更正（2026-10-13）：旧版此处把研究生课表当 HTML 表格解析、本科课表引用了不存在的 `courseTable.do` 响应结构。实际两套课表均为 JSON（GSMIS `loadXskbData.do` 返回 `jgList/rwList/jcfaList`；BYXT `getMyScheduleDetail.do` 返回 `datas.arrangedList`），真实结构见 [API.md](API.md) §2/§3。HTML 解析仅存在于 CAS 登录页（execution 提取）。

#### 测试文件：`ScheduleParserTests.swift`

```swift
import XCTest
@testable import BUAA_Assistant

final class ScheduleParserTests: XCTestCase {
    var sut: ScheduleParser!
    
    override func setUp() {
        super.setUp()
        sut = ScheduleParser()
    }
    
    // MARK: - 研究生课表（GSMIS，JSON）测试
    
    func test_parseGraduateSchedule_withValidJSON_shouldReturnCourses() throws {
        // Given — loadXskbData.do 响应结构（code == "1"，注意是字符串）
        let json = """
        {
          "code": "1",
          "jgList": [{
            "BJDM": "BJ001", "KCDM": "CS101", "KCMC": "算法设计与分析",
            "XNXQDM": "20251", "XQ": "1",
            "KSJCDM": "1", "JSJCDM": "2",
            "ZCBH": "1111111111111111",
            "JASMC": "新主楼A101", "JGJSXM": "张三",
            "JCFADM": "01"
          }],
          "rwList": [{
            "BJDM": "BJ001", "XNXQDM": "20251", "XNXQMC": "2025-2026学年第1学期",
            "XF": "4.0", "SCSKRQ": "2025-09-08"
          }],
          "jcfaList": [{
            "JCFADM": "01",
            "skjcList": [
              { "JCFADM": "01", "DM": "1", "KSSJ": "800", "JSSJ": "845" },
              { "JCFADM": "01", "DM": "2", "KSSJ": "850", "JSSJ": "935" }
            ]
          }]
        }
        """.data(using: .utf8)!
        
        // When
        let courses = try sut.parseGraduateSchedule(from: json, termCode: "20251")
        
        // Then
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(courses[0].courseName, "算法设计与分析")
        XCTAssertEqual(courses[0].teacher, "张三")
        XCTAssertEqual(courses[0].location, "新主楼A101")
        XCTAssertEqual(courses[0].weekDay, 1)
        XCTAssertEqual(courses[0].sections, [1, 2])
        XCTAssertEqual(courses[0].weeks, Array(1...16))   // ZCBH 位图全 1
    }
    
    func test_parseGraduateSchedule_withZCBHBitmap_shouldParseNonContinuousWeeks() throws {
        // Given — 位图 101100…：第 2、5、6 周等
        let json = Self.gsmisFixture(zcbh: "1011000000000000")
        
        // When
        let courses = try sut.parseGraduateSchedule(from: json, termCode: "20251")
        
        // Then
        XCTAssertEqual(courses[0].weeks, [1, 3, 4, 5])
    }
    
    func test_parseGraduateSchedule_withFailureCode_shouldThrow() {
        // Given — 成功码是 "1"（学期列表才是 "0"），上游自身不一致
        let json = Self.gsmisFixture(code: "0")
        
        // When & Then
        XCTAssertThrowsError(try sut.parseGraduateSchedule(from: json, termCode: "20251"))
    }
    
    // MARK: - 本科课表（BYXT，JSON）测试
    
    func test_parseUndergraduateSchedule_withValidJSON_shouldReturnCourses() throws {
        // Given — getMyScheduleDetail.do 响应结构（code == "0"）
        let json = """
        {
          "code": "0",
          "msg": null,
          "datas": {
            "arrangedList": [{
              "courseCode": "CS101", "courseName": "算法设计与分析",
              "courseSerialNo": "01", "credit": "4.0",
              "beginTime": "08:00", "endTime": "09:35",
              "beginSection": 1, "endSection": 2,
              "placeName": "新主楼A101", "weeksAndTeachers": "1-16周 张三",
              "teachingTarget": null, "color": "#4A90D9", "dayOfWeek": 1
            }],
            "code": "sy2501001",
            "name": "2025-2026学年第1学期",
            "sectionTimes": [{ "section": 1, "start": "08:00", "end": "08:45" }]
          }
        }
        """.data(using: .utf8)!
        
        // When
        let courses = try sut.parseUndergraduateSchedule(from: json)
        
        // Then
        XCTAssertEqual(courses?.count, 1)
        XCTAssertEqual(courses?[0].courseName, "算法设计与分析")
        XCTAssertEqual(courses?[0].sections, [1, 2])
        // datas.code 是学号不是学期码，不得用作学期标识
    }
    
    // MARK: - CAS 登录页（真正的 HTML 解析）测试
    
    func test_extractExecution_fromLoginPageHTML_shouldFindToken() {
        // Given
        let html = """
        <input type="hidden" name="execution" value="60569136-414e-46d2-87b1-example"/>
        """
        
        // When
        let execution = CasPageParser.extractExecution(from: html)
        
        // Then
        XCTAssertEqual(execution, "60569136-414e-46d2-87b1-example")
    }
    
    func test_detectCaptcha_fromLoginPageHTML_shouldParseConfig() {
        // Given
        let html = "<script>var config = {...}; config.captcha = { type: 'local', id: 'cap-123' };</script>"
        
        // When
        let captcha = CasPageParser.detectCaptcha(from: html)
        
        // Then
        XCTAssertEqual(captcha?.id, "cap-123")
    }
    
    // MARK: - 边界情况测试
    
    func test_parseGraduateSchedule_withEmptyArrays_shouldReturnEmpty() throws {
        let json = #"{"code": "1", "jgList": [], "rwList": [], "jcfaList": []}"#
            .data(using: .utf8)!
        
        let courses = try sut.parseGraduateSchedule(from: json, termCode: "20251")
        XCTAssertTrue(courses.isEmpty)
    }
    
    func test_parseGraduateSchedule_withHTMLBody_shouldThrowNotJson() {
        // Given — 未登录时上游返回 CAS 登录页 HTML
        let html = "<html><title>CAS Login</title></html>".data(using: .utf8)!
        
        // When & Then
        XCTAssertThrowsError(try sut.parseGraduateSchedule(from: html, termCode: "20251"))
    }
}
```

---

## 3. 集成测试

### 3.0 URLProtocol Mock 基础设施（网络单元测试的标准做法）

单测中 mock 网络的标准方案：自定义 `URLProtocol` 子类注入 `URLSessionConfiguration.protocolClasses`，所有走该 session 的请求都被拦截并返回预设响应（无需真实网络）。

```swift
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// 用法：构造测试用 APIClient 时注入
func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

CAS 登录链的测试（重定向、Set-Cookie、错误页）全部基于此设施；注意认证链要用「不跟随重定向」的会话配合 302 响应模拟每一跳。

### 3.1 API 客户端集成测试

#### 测试文件：`APIClientIntegrationTests.swift`

```swift
import XCTest
@testable import BUAA_Assistant

final class APIClientIntegrationTests: XCTestCase {
    var sut: APIClient!
    var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        sut = APIClient(session: mockSession)
    }
    
    // MARK: - 请求构建测试
    
    func test_fetchSchedule_shouldConstructCorrectRequest() async throws {
        // Given — 真实端点与参数见 API.md §3.3
        let expectedURL = URL(string: "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/bykb/loadXskbData.do")!
        mockSession.mockResponse = (
            HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            #"{"code": "1", "jgList": [], "rwList": [], "jcfaList": []}"#.data(using: .utf8)!
        )
        
        // When
        _ = try await sut.fetchGraduateSchedule(termCode: "20251")
        
        // Then
        XCTAssertEqual(mockSession.lastRequest?.url, expectedURL)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        // 表单体：ZC/XH/XQDM 全空串，仅学期码有值（格式 \d{4}[123]）
        let body = mockSession.lastRequest?.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(body, "ZC=&XNXQDM=20251&XH=&XQDM=")
    }
    
    // MARK: - Cookie 管理测试（Cookie 由 HTTPCookieStorage 自动管理，禁止手拼 Cookie 头，API.md §9）

    func test_fetchWithStoredCookie_shouldAttachCookieAutomatically() async throws {
        // Given — Cookie 写入共享存储（模拟登录后 Set-Cookie 的落点），不由 APIClient 手动注入
        let storage = HTTPCookieStorage.shared
        let cookie = HTTPCookie(properties: [
            .domain: "sso.buaa.edu.cn", .path: "/", .name: "CASTGC", .value: "TGT-test",
            .secure: "TRUE",
        ])!
        storage.setCookie(cookie)
        defer { storage.deleteCookie(cookie) }
        mockSession.mockResponse = (
            HTTPURLResponse(url: URL(string: "https://sso.buaa.edu.cn/test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            Data()
        )

        // When
        _ = try await sut.get("https://sso.buaa.edu.cn/test")

        // Then — 请求自动携带（.default 配置的 session 共享 HTTPCookieStorage.shared）
        let cookieHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Cookie")
        XCTAssertTrue(cookieHeader?.contains("CASTGC=TGT-test") ?? false)
    }
    
    // MARK: - 错误处理测试
    
    func test_fetch_withServerError_shouldThrowAPIError() async {
        // Given
        mockSession.mockResponse = (
            HTTPURLResponse(url: URL(string: "https://test.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
            Data()
        )
        
        // When & Then
        do {
            _ = try await sut.get("https://test.com")
            XCTFail("Should throw error")
        } catch let error as APIError {
            if case .upstreamError(500, nil) = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func test_fetch_withTimeout_shouldThrowTimeoutError() async {
        // Given
        mockSession.shouldTimeout = true
        
        // When & Then
        do {
            _ = try await sut.get("https://test.com")
            XCTFail("Should throw error")
        } catch let error as APIError {
            XCTAssertEqual(error, .timeout)
        }
    }
    
    func test_fetch_withSessionExpired_shouldThrowSessionExpiredError() async {
        // Given
        mockSession.mockResponse = (
            HTTPURLResponse(
                url: URL(string: "https://sso.buaa.edu.cn/login")!,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": "https://sso.buaa.edu.cn/login"]
            )!,
            Data()
        )
        
        // When & Then
        do {
            _ = try await sut.get("https://protected.buaa.edu.cn/api")
            XCTFail("Should throw error")
        } catch let error as APIError {
            XCTAssertEqual(error, .sessionExpired)
        }
    }
}
```

### 3.2 SwiftData 存储集成测试

#### 测试文件：`SwiftDataStoreIntegrationTests.swift`

```swift
import XCTest
import SwiftData
@testable import BUAA_Assistant

final class SwiftDataStoreIntegrationTests: XCTestCase {
    var sut: SwiftDataStore!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        // 使用内存数据库
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: CourseEntity.self, GradeEntity.self, configurations: config)
        sut = SwiftDataStore(container: container)
    }
    
    override func tearDownWithError() throws {
        sut = nil
        container = nil
    }
    
    // MARK: - 课表存储测试
    
    func test_saveCourses_shouldPersistToDatabase() async throws {
        // Given
        let courses = [
            Course(courseName: "算法", teacher: "张三", location: "A101", weekDay: 1, sections: [1, 2], weeks: [1...16]),
            Course(courseName: "操作系统", teacher: "李四", location: "B202", weekDay: 2, sections: [3, 4], weeks: [1...16])
        ]
        
        // When
        try await sut.saveCourses(courses, term: "2025-2026-1")
        
        // Then
        let saved = try await sut.getCourses(term: "2025-2026-1")
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(saved[0].courseName, "算法")
        XCTAssertEqual(saved[1].courseName, "操作系统")
    }
    
    func test_getCourses_withInvalidTerm_shouldReturnEmpty() async throws {
        // Given
        let courses = [Course(courseName: "算法", teacher: "张三", location: "A101", weekDay: 1, sections: [1, 2], weeks: [1...16])]
        try await sut.saveCourses(courses, term: "2025-2026-1")
        
        // When
        let saved = try await sut.getCourses(term: "2099-2100-1")
        
        // Then
        XCTAssertTrue(saved.isEmpty)
    }
    
    func test_updateCourses_shouldReplaceExisting() async throws {
        // Given
        let oldCourses = [Course(courseName: "旧课程", teacher: "旧教师", location: "旧教室", weekDay: 1, sections: [1], weeks: [1])]
        try await sut.saveCourses(oldCourses, term: "2025-2026-1")
        
        let newCourses = [Course(courseName: "新课程", teacher: "新教师", location: "新教室", weekDay: 2, sections: [2], weeks: [2])]
        
        // When
        try await sut.saveCourses(newCourses, term: "2025-2026-1")
        
        // Then
        let saved = try await sut.getCourses(term: "2025-2026-1")
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].courseName, "新课程")
    }
    
    // MARK: - 成绩存储测试
    
    func test_saveGrades_shouldPersistToDatabase() async throws {
        // Given
        let grades = [
            Grade(courseName: "算法", credit: 4.0, score: 92, gpa: 4.0, semester: "2025-2026-1")
        ]
        
        // When
        try await sut.saveGrades(grades)
        
        // Then
        let saved = try await sut.getGrades()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].courseName, "算法")
        XCTAssertEqual(saved[0].score, 92)
    }
    
    // MARK: - 并发测试
    
    func test_concurrentWrites_shouldNotCorruptData() async throws {
        // Given
        let expectations = (0..<10).map { i in
            Task {
                let course = Course(courseName: "课程\(i)", teacher: "教师\(i)", location: "教室\(i)", weekDay: 1, sections: [1], weeks: [1])
                try await sut.saveCourses([course], term: "2025-2026-1")
            }
        }
        
        // When
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exp in expectations {
                group.addTask { try await exp.value }
            }
        }
        
        // Then
        let saved = try await sut.getCourses(term: "2025-2026-1")
        // 最后一次写入应该保留
        XCTAssertEqual(saved.count, 1)
    }
    
    func test_concurrentReadWrite_shouldNotCrash() async throws {
        // Given
        let course = Course(courseName: "测试课程", teacher: "教师", location: "教室", weekDay: 1, sections: [1], weeks: [1])
        try await sut.saveCourses([course], term: "2025-2026-1")
        
        // When - 同时读写
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                if i % 2 == 0 {
                    group.addTask {
                        _ = try await self.sut.getCourses(term: "2025-2026-1")
                    }
                } else {
                    group.addTask {
                        let c = Course(courseName: "课程\(i)", teacher: "教师", location: "教室", weekDay: 1, sections: [1], weeks: [1])
                        try await self.sut.saveCourses([c], term: "2025-2026-1")
                    }
                }
            }
        }
        
        // Then - 不崩溃即可
        let saved = try await sut.getCourses(term: "2025-2026-1")
        XCTAssertFalse(saved.isEmpty)
    }
    
    func test_modelActor_concurrentAccess_shouldBeSerialized() async throws {
        // Given - 多个 Task 同时通过 ModelActor 访问
        let results = try await withThrowingTaskGroup(of: [CourseEntity].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await self.sut.getCourses(term: "2025-2026-1")
                }
            }
            var collected: [[CourseEntity]] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
        
        // Then - 所有读取结果一致
        let firstCount = results.first?.count
        XCTAssertTrue(results.allSatisfy { $0.count == firstCount })
    }
}
```

---

## 4. UI 测试

### 4.1 登录界面测试

#### 测试文件：`LoginUITests.swift`

```swift
import XCTest

final class LoginUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    // MARK: - 登录流程测试（macOS：tap() 换 click()，主界面判定用侧边栏元素）
    
    func test_login_withValidCredentials_shouldNavigateToMainView() {
        // Given
        let usernameField = app.textFields["username-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]
        
        // When
        usernameField.click()
        usernameField.typeText("sy2501001")
        passwordField.click()
        passwordField.typeText("validPassword")
        loginButton.click()
        
        // Then
        XCTAssertTrue(app.sidebarButtons["课表"].waitForExistence(timeout: 10))
    }
    
    func test_login_withEmptyUsername_shouldShowError() {
        // Given
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]
        
        // When
        passwordField.click()
        passwordField.typeText("password")
        loginButton.click()
        
        // Then
        XCTAssertTrue(app.alerts["请输入学号"].waitForExistence(timeout: 2))
    }
    
    func test_login_withInvalidCredentials_shouldShowError() {
        // Given
        let usernameField = app.textFields["username-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]
        
        // When
        usernameField.click()
        usernameField.typeText("wrongUser")
        passwordField.click()
        passwordField.typeText("wrongPass")
        loginButton.click()
        
        // Then
        XCTAssertTrue(app.alerts["登录失败"].waitForExistence(timeout: 10))
    }
    
    // MARK: - 验证码测试（协议见 API.md §1.3）
    
    func test_login_withCaptchaRequired_shouldShowCaptchaDialog() {
        // Given - 使用 Mock 服务器返回需要验证码
        let usernameField = app.textFields["username-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]
        
        // When
        usernameField.click()
        usernameField.typeText("sy2501001")
        passwordField.click()
        passwordField.typeText("password")
        loginButton.click()
        
        // Then
        XCTAssertTrue(app.images["captcha-image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["captcha-input"].exists)
    }
}
```

### 4.2 课表界面测试

> 更正（2026-10-13）：旧版此处使用了 iOS 惯用法（`swipeLeft/swipeRight` 手势、下拉刷新、`waitForNonExistence`——该 API 不存在）。macOS 上周次切换用按钮、刷新用工具栏按钮，等待消失需用 `NSPredicate` 自行实现。

#### 测试文件：`ScheduleUITests.swift`

```swift
import XCTest

final class ScheduleUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-schedule"]
        app.launch()
        
        // 等待课表内容出现（macOS 主窗口无 navigationBars 语义，用内容元素判定）
        XCTAssertTrue(app.staticTexts["算法设计与分析"].waitForExistence(timeout: 10))
    }
    
    // MARK: - 课表显示测试
    
    func test_scheduleView_shouldDisplayCurrentWeekCourses() {
        // 检查课程卡片
        let courseCards = app.groups.matching(identifier: "course-card")
        XCTAssertGreaterThan(courseCards.count, 0)
    }
    
    func test_scheduleView_shouldShowCourseDetails() {
        // Given
        let firstCourse = app.groups.matching(identifier: "course-card").firstMatch
        
        // When
        firstCourse.click()
        
        // Then
        XCTAssertTrue(app.staticTexts["算法设计与分析"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["新主楼A101"].exists)
        XCTAssertTrue(app.staticTexts["张三"].exists)
    }
    
    // MARK: - 周次切换测试（macOS 用按钮，不用滑动手势）
    
    func test_scheduleView_clickNextWeek_shouldIncrementWeek() {
        // Given
        let weekLabel = app.staticTexts["week-label"]
        let initialWeek = weekLabel.label
        
        // When
        app.buttons["next-week"].click()
        
        // Then
        XCTAssertNotEqual(weekLabel.label, initialWeek)
    }
    
    func test_scheduleView_clickPreviousWeek_shouldDecrementWeek() {
        let weekLabel = app.staticTexts["week-label"]
        let initialWeek = weekLabel.label
        
        app.buttons["previous-week"].click()
        
        XCTAssertNotEqual(weekLabel.label, initialWeek)
    }
    
    // MARK: - 刷新测试（工具栏按钮；macOS 无下拉刷新）
    
    func test_scheduleView_clickRefreshButton_shouldReloadData() {
        // Given
        app.buttons["refresh"].click()
        
        // Then — 用 NSPredicate 等待加载指示器出现并消失
        let spinner = app.activityIndicators["refresh-indicator"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 2))
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: spinner)
        waitForExpectations(timeout: 10)
    }
}
```

---

## 5. 端到端测试

### 5.1 完整用户旅程测试

#### 测试文件：`E2ETests.swift`

```swift
import XCTest

final class E2ETests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--e2e-testing"]
        app.launch()
    }
    
    // MARK: - 首次使用流程
    
    func test_firstLaunch_shouldShowLoginScreen() {
        // Then
        XCTAssertTrue(app.textFields["username-field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["password-field"].exists)
        XCTAssertTrue(app.buttons["login-button"].exists)
    }
    
    func test_completeOnboarding_shouldReachMainView() {
        // Given
        let usernameField = app.textFields["username-field"]
        let passwordField = app.secureTextFields["password-field"]
        let loginButton = app.buttons["login-button"]
        
        // When - 登录
        usernameField.click()
        usernameField.typeText("sy2501001")
        passwordField.click()
        passwordField.typeText("validPassword")
        loginButton.click()
        
        // Then - 进入主界面（macOS 侧边栏）
        XCTAssertTrue(app.sidebarButtons["课表"].waitForExistence(timeout: 15))
        
        // 验证课表数据加载
        let courseCards = app.groups.matching(identifier: "course-card")
        XCTAssertTrue(courseCards.firstMatch.waitForExistence(timeout: 10))
    }
    
    // MARK: - 核心功能流程（macOS：侧边栏切换，无 tabBars）
    
    func test_viewGrades_shouldCalculateGPA() {
        // Given - 已登录
        loginIfNeeded()
        
        // When - 切换到成绩页面
        app.sidebarButtons["成绩"].click()
        
        // Then
        XCTAssertTrue(app.staticTexts["GPA"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d\\\\.\\\\d\\\\d'")).firstMatch.exists)
    }
    
    func test_checkLibrarySeats_shouldShowLibraryList() {
        // Given - 已登录
        loginIfNeeded()
        
        // When - 切换到图书馆页面
        app.sidebarButtons["图书馆"].click()
        
        // Then — 座位视图（已验证协议）；借阅查询为探索性目标，验证后再补 UI 测试
        XCTAssertTrue(app.staticTexts["楼馆列表"].waitForExistence(timeout: 10))
    }
    
    // MARK: - 设置流程
    
    func test_changeSettings_shouldPersist() {
        // Given - 已登录
        loginIfNeeded()
        
        // When - 打开设置
        app.buttons["settings-button"].click()
        
        // 切换通知开关
        let notificationSwitch = app.switches["notification-switch"]
        notificationSwitch.click()
        
        // 返回
        app.buttons["back-button"].click()
        
        // 再次打开设置
        app.buttons["settings-button"].click()
        
        // Then - 设置应该保持
        XCTAssertEqual(notificationSwitch.value as? String, "1")
    }
    
    // MARK: - 辅助方法
    
    private func loginIfNeeded() {
        if app.textFields["username-field"].exists {
            let usernameField = app.textFields["username-field"]
            let passwordField = app.secureTextFields["password-field"]
            let loginButton = app.buttons["login-button"]
            
            usernameField.click()
            usernameField.typeText("sy2501001")
            passwordField.click()
            passwordField.typeText("validPassword")
            loginButton.click()
            
            _ = app.sidebarButtons["课表"].waitForExistence(timeout: 15)
        }
    }
}
```

---

## 6. 性能测试

### 6.1 启动时间测试

```swift
import XCTest

final class PerformanceTests: XCTestCase {
    func test_appLaunchTime_shouldBeUnder2Seconds() {
        // Given
        let app = XCUIApplication()
        
        // When
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        
        // Then - XCTApplicationLaunchMetric 会自动报告启动时间
        // 目标：< 2 秒
    }
}
```

### 6.2 内存占用测试

```swift
import XCTest

final class MemoryTests: XCTestCase {
    func test_idleMemoryUsage_shouldBeUnder50MB() {
        let app = XCUIApplication()
        app.launch()
        
        // 等待启动完成
        _ = app.windows.firstMatch.waitForExistence(timeout: 5)
        
        measure(metrics: [XCTMemoryMetric()]) {
            // 空闲 5 秒，测量内存基线
            Thread.sleep(forTimeInterval: 5)
        }
        // 目标：空闲 < 50MB
    }
    
    func test_dataLoadMemoryUsage_shouldBeUnder100MB() {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-large-dataset"]
        app.launch()
        
        XCTAssertTrue(app.sidebarButtons["课表"].waitForExistence(timeout: 10))
        
        measure(metrics: [XCTMemoryMetric()]) {
            // 加载大量数据后测量（macOS 侧边栏切换）
            app.sidebarButtons["成绩"].click()
            Thread.sleep(forTimeInterval: 3)
        }
        // 目标：加载数据后 < 100MB
    }
    
    func test_memoryLeak_navigateAllSections_shouldNotLeak() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.sidebarButtons["课表"].waitForExistence(timeout: 10))
        
        measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<5 {
                app.sidebarButtons["课表"].click()
                Thread.sleep(forTimeInterval: 1)
                app.sidebarButtons["成绩"].click()
                Thread.sleep(forTimeInterval: 1)
                app.sidebarButtons["图书馆"].click()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        // 如果内存持续增长，说明存在泄漏
    }
}
```

---

## 7. 测试数据管理

### 7.1 Mock 数据工厂

```swift
enum MockDataFactory {
    static func makeCourse(
        name: String = "测试课程",
        teacher: String = "测试教师",
        location: String = "测试教室"
    ) -> Course {
        Course(
            courseName: name,
            teacher: teacher,
            location: location,
            weekDay: 1,
            sections: [1, 2],
            weeks: Array(1...16)
        )
    }
    
    static func makeGrade(
        name: String = "测试课程",
        credit: Double = 4.0,
        score: Int = 90
    ) -> Grade {
        Grade(
            courseName: name,
            credit: credit,
            score: score,
            gpa: 4.0,
            semester: "2025-2026-1"
        )
    }
    
    static func makeSchedule(count: Int = 10) -> [Course] {
        (0..<count).map { i in
            makeCourse(name: "课程\(i)", teacher: "教师\(i)", location: "教室\(i)")
        }
    }
}
```

### 7.2 测试环境配置

```swift
// TestConfiguration.swift
enum TestEnvironment {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }
    
    static var isE2ETesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--e2e-testing")
    }
    
    static var mockServerURL: URL {
        URL(string: "http://localhost:8080")!
    }
}
```

---

## 8. CI/CD 集成

### 8.1 GitHub Actions 配置

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    # 工程为 Xcode 16+ 文件系统同步格式：runner 镜像须带新版 Xcode，
    # 默认版本过旧时需显式指定（本机验证环境为 Xcode 27.0）
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Unit Tests
        run: xcodebuild test -scheme BUAA-Assistant -destination 'platform=macOS' -only-testing:BUAA_AssistantTests
        
      # UI 测试 target 于 ROADMAP Step 8 创建，此前此步会因 target 不存在而失败：
      # Phase 1 建 CI 时先注释掉本步
      - name: Run UI Tests
        run: xcodebuild test -scheme BUAA-Assistant -destination 'platform=macOS' -only-testing:BUAA_AssistantUITests
        
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
```

### 8.2 测试报告生成

```bash
# 生成覆盖率报告
xcodebuild test -scheme BUAA-Assistant -enableCodeCoverage YES

# 导出报告
xcrun xccov view-report --output-format json build/Logs/Test/*.xccovreport > coverage.json
```

---

## 9. 上游 API 可达性测试

> 当前只读验收覆盖 SSO、UC、本科教务、研究生教务、成绩、空教室、图书馆座位、图书馆公开人数、校园通知、SPOC 与 iclass 等上游系统（见 [API.md](API.md) 附录 A）。博雅、操场、阳光打卡、iHome、评教等尚未在 Ginkgo 中实现，不能仅凭 UBAA 源码就宣称可用。

### 9.1 健康检查策略

```swift
/// 上游系统健康检查器
actor UpstreamHealthChecker {
    struct HealthStatus {
        let system: String
        let url: String
        let isReachable: Bool
        let latencyMs: Int
        let httpStatus: Int?
        let checkedAt: Date
    }
    
    private let systems: [(name: String, url: String)] = [
        ("SSO", "https://sso.buaa.edu.cn/login"),
        ("UC", "https://uc.buaa.edu.cn/api/uc/status"),
        ("本科生教务", "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/currentUser.do"),
        ("研究生教务", "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/*default/index.do"),
        ("成绩", "https://app.buaa.edu.cn/buaascore/wap/default/index"),
        ("图书馆座位", "https://booking.lib.buaa.edu.cn"),
    ]
    
    func checkAll() async -> [HealthStatus] {
        await withTaskGroup(of: HealthStatus.self) { group in
            for system in systems {
                group.addTask { await self.checkOne(system.name, url: system.url) }
            }
            var results: [HealthStatus] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func checkOne(_ name: String, url: String) async -> HealthStatus {
        let start = Date()
        do {
            var request = URLRequest(url: URL(string: url)!)
            // 用 GET 而非 HEAD：部分上游对 HEAD 返回 405；可达性判定只看状态码
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            return HealthStatus(
                system: name, url: url,
                isReachable: (200..<500).contains(httpStatus ?? 0),
                latencyMs: latency,
                httpStatus: httpStatus,
                checkedAt: Date()
            )
        } catch {
            return HealthStatus(
                system: name, url: url,
                isReachable: false,
                latencyMs: Int(Date().timeIntervalSince(start) * 1000),
                httpStatus: nil,
                checkedAt: Date()
            )
        }
    }
}
```

### 9.2 测试用例

```swift
final class UpstreamHealthTests: XCTestCase {
    func test_allUpstreamSystems_shouldBeReachable() async throws {
        let checker = UpstreamHealthChecker()
        let results = await checker.checkAll()
        
        for status in results where !status.isReachable {
            print("⚠️ \(status.system) 不可达: \(status.url)")
        }
        
        // 允许个别系统维护，但至少 80% 可达
        let reachableCount = results.filter { $0.isReachable }.count
        XCTAssertGreaterThan(Double(reachableCount) / Double(results.count), 0.8)
    }
    
    func test_ssoResponseTime_shouldBeUnder3Seconds() async throws {
        let checker = UpstreamHealthChecker()
        let results = await checker.checkAll()
        
        let sso = results.first { $0.system == "SSO" }
        XCTAssertNotNil(sso)
        XCTAssertLessThan(sso!.latencyMs, 3000)
    }
}
```

---

## 10. 快照回归测试（黄金文件）

> 更正（2026-10-13）：旧版把 GSMIS 课表和 buaascore 成绩当 HTML 做快照——两者实际都是 JSON。真正需要 HTML 快照的是 **CAS 登录页**（execution/验证码检测的正则依赖其结构）。使用**黄金文件（Golden File）**策略检测上游结构变化。

### 10.1 策略说明

```
┌──────────────┐     ┌──────────────────┐     ┌────────────────┐
│ 上游响应     │ ──→ │ Parser 解析      │ ──→ │ 结构化数据     │
│ (可能变化)   │     │ (Swift 代码)     │     │ (Course/Grade) │
└──────────────┘     └──────────────────┘     └────────────────┘
       │
       ▼
┌──────────────┐
│ 黄金文件对比 │  ← 如果解析结果变化，测试失败
│ (Golden File)│  ← 开发者确认变化合理后，更新黄金文件
└──────────────┘
```

### 10.2 黄金文件管理

```
BUAA-AssistantTests/
└── Resources/
    └── Snapshots/
        ├── cas_login_page_v1.html              # CAS 登录页（execution/验证码结构）
        ├── cas_login_page_v1.expected.json
        ├── gsmis_schedule_v1.json              # GSMIS 课表（loadXskbData.do 响应）
        ├── gsmis_schedule_v1.expected.json
        ├── byxt_schedule_v1.json               # BYXT 周课表（getMyScheduleDetail.do 响应）
        ├── byxt_schedule_v1.expected.json
        ├── buaascore_grade_v1.json             # 成绩（POST 响应，注意 xf/kccj 类型漂移样本）
        ├── buaascore_grade_v1.expected.json
        └── libbook_reserve_crypto_v1.json      # 座位预约加密向量（明文/密钥/IV → 密文）
```

快照文件必须脱敏：合成学号姓名、清空 Cookie/票据、截断正文（保留结构而非内容）。

### 10.3 测试实现

```swift
final class SnapshotTests: XCTestCase {
    private let snapshotDir = "BUAA-AssistantTests/Resources/Snapshots"
    
    /// 检测上游 JSON 结构是否发生变化
    func test_gsmisScheduleJSON_shouldMatchSnapshot() throws {
        let json = try loadSnapshot("gsmis_schedule_v1.json")
        let expected = try loadExpected("gsmis_schedule_v1.expected.json")
        
        let parser = ScheduleParser()
        let courses = try parser.parseGraduateSchedule(from: json, termCode: "20251")
        let actual = try JSONEncoder().encode(courses)
        let actualJSON = try JSONSerialization.jsonObject(with: actual) as! [String: Any]
        
        XCTAssertEqual(
            NSDictionary(dictionary: actualJSON),
            NSDictionary(dictionary: expected),
            "GSMIS 课表解析结果与黄金文件不匹配，上游可能已变更"
        )
    }
    
    /// CAS 登录页 HTML：execution 提取与验证码检测
    func test_casLoginPageHTML_shouldExtractExecutionAndCaptcha() throws {
        let html = try loadSnapshot("cas_login_page_v1.html")
        let expected = try loadExpected("cas_login_page_v1.expected.json")
        
        let execution = CasPageParser.extractExecution(from: html)
        let captcha = CasPageParser.detectCaptcha(from: html)
        
        XCTAssertEqual(execution, expected["execution"] as? String)
        XCTAssertEqual(captcha?.id, expected["captchaId"] as? String?)
    }
    
    /// 座位预约加密：固定明文 + 日期密钥 → 密文（上游算法不变的哨兵）
    func test_libBookReserveCrypto_shouldMatchKnownVector() throws {
        let vector = try loadExpected("libbook_reserve_crypto_v1.json")
        let cipher = LibBookCrypto.encryptReserveRequest(
            seatId: vector["seatId"] as! String,
            segment: vector["segment"] as! String,
            day: vector["day"] as! String
        )
        XCTAssertEqual(cipher, vector["cipherTextBase64"] as? String)
    }
    
    // MARK: - 辅助方法
    
    private func loadSnapshot(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: snapshotDir).appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
    
    private func loadExpected(_ name: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: snapshotDir).appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
```

### 10.4 快照更新流程

当上游确实发生了合理变更时：

1. 测试失败，CI 报告 `解析结果与黄金文件不匹配`
2. 开发者手动获取最新响应（脱敏后）保存为 `*_v2` 版本
3. 手动运行解析器，确认输出正确
4. 将正确输出保存为 `*_v2.expected.json`
5. 提交新的黄金文件，删除旧版本

---

## 11. 测试清单

### 11.1 功能测试清单

- [ ] 登录流程（成功/失败/验证码/密码过期页跳过，协议见 API.md §1）
- [ ] 课表查询（本科/研究生双门户判定、当前周/历史周/刷新）
- [ ] 成绩查询（GPA 计算/分类统计，xf/kccj 类型漂移容错）
- [ ] 图书馆座位（楼馆/分区/座位查询、预约加密、取消，见 API.md §5）
- [ ] 图书馆借阅（**探索性目标**——逆向验证完成前不编写测试）
- [ ] 设置（通知/主题/清除缓存）
- [ ] 登出（清除数据/返回登录）

### 11.2 非功能测试清单

- [ ] 启动时间 < 2 秒
- [ ] 内存占用 < 100MB
- [ ] 网络错误处理
- [ ] 离线模式
- [ ] 深色模式
- [ ] 键盘导航
- [ ] VoiceOver 支持

---

## 附录

### A. 测试命名规范

```
test_方法名_条件_预期结果

示例：
test_login_withValidCredentials_shouldReturnUserData
test_calculateGPA_withEmptyGrades_shouldReturnZero
```

### B. 测试数据文件

黄金文件统一放 `BUAA-AssistantTests/Resources/Snapshots/`（清单见 §10.2；课表/成绩均为 JSON，无 HTML 课表快照——需要 HTML 快照的只有 CAS 登录页）：

- `cas_login_page_v1.html`（CAS 登录页）
- `gsmis_schedule_v1.json` / `byxt_schedule_v1.json`
- `buaascore_grade_v1.json`
- `libbook_reserve_crypto_v1.json`（加密向量）

## 2026-10-19 · 学分地图回归

macOS 全量 210 项通过；iPhone SE（iOS 27.0）教务相关 43 项通过。相关组为 `GraduateRequirementsTests`、`GraduateAcademicClientTests`、`GraduateProgressTests`、`CgyyClientTests`、`LibraryBookingLifecycleTests`。

新增覆盖：总/类别/课组的独立缺口、最少门数、总学分满足但课组未满足、未知学分不报零、执行报告 JSON 字符串、结构变更、业务失败、认定学分与全部已修不互换、部分失败保留分项与时间、成功空结果覆盖旧数据、历史学期不推断在修、执行报告确认完成优先、CGYY POST 401 不重发/缺失状态待核实、快速切日丢弃旧上下文，以及停用图书馆 seminar 提交。

`GraduateRequirementsTests.testRequirementDashboardRendersAtDesktopAndPhoneWidths` 使用合成数据，macOS 下通过 NSHostingView 渲染，产物写入系统临时目录；布局目视检查记录在 ACCEPTANCE.md，不能将该测试通过等同于真实账号交互或可访问性验收。

最终补充检查：iOS generic-device build 通过；最后的文案调整后，macOS `GraduateRequirementsTests` 定向复跑通过；`git diff --check` 通过。


## 2026-10-22 · Rust / Flutter 分层重构

本轮结构及维护规则见 [MIRROR-ARCHITECTURE.md](MIRROR-ARCHITECTURE.md)。验证在宿主 macOS 完成，不调用真实学校业务接口。

| 检查 | 结果 |
| --- | --- |
| `scripts/check-mirror.sh` | 通过：架构依赖检查、fmt、Clippy（所有目标/feature，拒绝警告）、Rust workspace 测试、Flutter analyze 和测试 |
| Rust workspace | 192 项单元测试 + 1 项共享契约集成测试 + 1 项 doctest，共 194 项通过 |
| Flutter | analyze 无问题，108 项单元/widget 测试通过 |
| `scripts/generate-mirror-bridge.sh` | 重新生成绑定；最终重复生成的哈希一致 |
| `cargo machete --with-metadata rust` | 未发现未使用依赖；无 metadata 的 `md-5` 提示是 crate 导入名为 `md5` 的误报，已核对实际使用 |
| Android | `flutter build apk --debug --target-platform android-arm64 --no-pub` 通过，包含 Cargokit/Rust ARM64 链接 |
| `python3 scripts/check-mirror-windows-cmake.py` | 普通路径、Flutter 插件符号链接、Debug/Release 冷 CMake 和合成 DLL 拷贝通过 |
| `git diff --check` | 通过 |

新增回归：缓存失败保留数据与原时间戳/TTL、无缓存时错误透传、成功空快照覆盖旧数据、名称排序的 Unicode/大数字/前导零、FFI 序列化失败及陈旧数据携带刷新错误、BYKC 排队查询回查缓存/强制刷新、北京时间边界学期投影、Flutter 使用投影且不从原始学期列表自行推断。

基线分析曾发现 Flutter 23 个接口/导入错误，修复了服务测试替身与枚举导入，并补上签到加载组件的服务注入。页面导航、600 座位懒加载、周次自动定位、快速切换请求顺序、刷新保留旧状态等原有回归均继续通过。

本轮没有执行真实登录/签到/预约、Windows 主机构建或设备交互验收；Android APK 编译和合成 CMake 测试不能替代这些验收。尚无发布包体、设备内存、帧率或端到端提速比例的测量结论。


## 2026-10-22 · 学校协议、会话与业务端口隔离

在上一轮分文件基础上，切断 core 对 upstream 的编译依赖。当前结构和学校协议维护位置以 [MIRROR-ARCHITECTURE.md](MIRROR-ARCHITECTURE.md) 为准；旧 `core/application/*_service.rs` 的学校实现与协议测试已迁入 `upstream/services/`。

| 检查 | 本轮结果 |
| --- | --- |
| core 独立测试（无默认 feature） | 2 项单元测试、3 项仅使用合成业务端口的集成测试通过；正常依赖图无 upstream/HTTP/平台保险库 |
| upstream 独立测试 | 187 项协议、会话、恢复与查询测试 + 1 项共享 fixture 契约测试通过，无 core 依赖 |
| Rust workspace | 196 项单元/端口集成测试 + 1 项共享 fixture 测试 + 1 项 doctest，共 198 项通过 |
| 边界检查 | 检查通过；5 项防回退回归通过（含 core 开发依赖、实现包重命名、组装白名单、协议源码穿透、原始 JSON 端口） |
| `scripts/check-mirror.sh` | 通过：独立测试、workspace 测试、fmt、Clippy 拒绝警告、Flutter analyze 和 109 项单元/widget 测试 |
| 绑定生成 | 移除未使用的会话状态及研究生组合查询 FFI 命令；作业详情新增可空 sourceUrl，Rust/Dart 绑定同步生成，重复生成一致；协议样例解析从 FFI 移入 upstream |
| Android ARM64 Debug APK | 构建通过，验证新 runtime crate、上游实现和 JNI 保险库入口链接 |
| 依赖清理 | 删除 runtime 未使用的 serde_json 直接依赖；`cargo machete --with-metadata rust` 复核 |
| `git diff --check` | 通过 |

核心合成端口回归验证：只实现通知能力即可运行对应应用命令；旧数据和刷新错误一起保留；不确定的写入结果不会被应用层重发；本地待办按注入身份隔离账号、退出后拒绝访问。

学校响应解析、CAS/UC/网关、Cookie、业务 token 与恢复时序的旧断言保留在独立上游测试中。CGYY 的请求/结果和签到进度改为有类型的业务值，序列化后的既有页面数据形状保持兼容。学校通知的 HTTPS/域名限制由上游统一维护，并新增白名单回归；作业官网入口作为上游元数据返回。新增 Flutter 导航回归验证子页面继续使用注入的服务。没有改动学校成功码、TLS 信任规则或新增写重试，也没有向真实账号发送请求。

本轮未执行 Windows 主机构建、真实学校登录/写入或设备交互验收。APK 编译通过只证明构建与链接，不代替这些验收。

## 2026-10-22 · 工作台与研究生页渐进加载样板

参考原生 `IOSTodayView.swift`、`IOSGraduateAcademicView.swift` 的分组列表、局部状态及保留缓存呈现，以及 macOS `TodayView.swift` 的刷新快捷键。本轮只修改 Flutter 呈现与状态管理，Rust/FFI 和学校协议未改动。

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub test` | 117 项通过（原有 109 项，新增 8 项） |
| 架构边界检查及其回归 | 检查通过，5 项回归通过 |
| Dart 格式与 `git diff --check` | 通过 |
| Android ARM64 Debug APK | `flutter build apk --debug --target-platform android-arm64 --no-pub` 通过 |

新增回归覆盖：工作台作业先于课表完成即可显示；摘要排除助教课程、保留状态待确认提示；失败后保留原课程；局部重试不重读其他区域；切换工作台或研究生 provider 后拒绝旧请求迟到结果；重复刷新共享进行中的读取、成功空结果覆盖旧内容；桌面刷新快捷键；减少动态效果或关闭 ticker 后不再安排动画帧；320px 窄屏、双倍字体和深色环境的加载与内容布局。

既有刷新回归改为在完成模拟请求后同时等待两个刷新调用，以验证“加入已有读取并等待结束”的语义，避免测试在完成响应前等待自身的进行中任务。

另用临时 widget 渲染脚本检查合成的手机加载态、手机内容、桌面内容及研究生学分地图；这是宿主渲染检查，不是真机截图或真实账号验收。临时脚本和图像未纳入源码。尚未执行 Android 设备交互、Windows 主机运行、读屏或真实学校请求验收；未测量设备帧率及端到端速度。

## 2026-10-22 · 集合窗口、长页滚动与课表对齐

本轮仍只改 Flutter 呈现层：座位与空教室接入公共 `CollectionWindow` / `CollectionToolbar`，课表固定节次轴并支持按天对齐与周次 / 星期直达，长页统一纵向滚动条与返回顶部。交互约束、未完成项与热更新范围见 [MIRROR-INTERACTION.md](MIRROR-INTERACTION.md)；Rust、FFI 与学校协议未改动。

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub test` | 124 项通过 |
| 本轮 31 个 Dart 文件 `dart format --set-exit-if-changed` | 无改动 |
| `python3 scripts/check-mirror-architecture.py` 及其回归 | 通过 |
| Android ARM64 Debug APK | `flutter build apk --debug --target-platform android-arm64 --no-pub` 通过，包含 Cargokit / Rust ARM64 链接 |
| `git diff --check` | 通过 |

新增回归覆盖：刷新按原页首 ID 跟随（插入 50 条后仍落在第 251–300 条）、锚点消失收敛到有效页、空查询保持合法边界、换筛选显式回第一页；工具栏在 320px 宽、双倍字号下直接跳页（551–600）；长页深处显示返回顶部且不改变滚动位置；座位翻页后首条不被固定查询区遮挡；空教室搜索按 250ms 合并、同查询刷新保留当前页；课表横滑松手后落在整日边界、固定节次轴不随横向偏移移动、星期直达可跳到末尾；研究生页更换 provider 后丢弃迟到快照。

已知未完成：空教室刷新后 sliver 重排仍可能出现可见位置偏移（合成观察约 119px），未做精确像素锚定；设备滚动性能、读屏与真实账号未验收。

## 2026-10-22 · 工作区功能登记表（Flutter）

把移动端标签、桌面侧栏、今日快捷入口与返回栈收敛到 `flutter/lib/workspace_catalog.dart`；`main.dart` 只保留启动与登录状态机，`workspace_shell.dart` 负责移动/桌面两种布局。登记是编译期静态表，不引入运行时插件加载；Rust/FFI 未改动。

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub test` | 127 项通过（新增 3 项登记表不变量） |
| 本轮 8 个 Dart 文件 `dart format --set-exit-if-changed` | 无改动 |
| 架构边界检查及其回归 | 通过 |
| Android ARM64 Debug APK | `flutter build apk --debug --target-platform android-arm64 --no-pub` 通过 |
| `git diff --check` | 通过 |

新增回归：功能 id 唯一且可按 id 解析；移动端标签 0–4 连续且从工作台开始；每个侧栏分组非空、设置固定在页脚、每个登记项至少有一个可达入口。既有导航与窗口测试改为按功能 id 选择（`desktop-sidebar-grades` 等），标签数量、顺序与返回栈断言保持不变。壳层不再内置演示服务，具体实现只在 `main.dart` 组合根注入，架构边界检查同时覆盖这一点。

已知未完成：`service_directory.dart` 的移动端“个人与校园”快捷入口仍是精选清单（与登记表重复，但只是入口分组）；未实现运行时插件加载、远程下发或动态符号查找；未跑设备读屏与真机交互。

## 2026-10-22 · Apple 端剩余仓储边界

CheckIn / Campus / Graduate 三个 ViewModel 从“直接持有客户端 + 缓存”改为依赖仓储协议；网络、缓存读写与缓存失败日志进入仓储，通知权限、UserDefaults、generation、15 分钟新鲜度、`retainingSuccessfulData` 合并、签到回查与状态变更提示留在 ViewModel。上游协议、成功码判定与写操作语义未变。

| 检查 | 结果 |
| --- | --- |
| macOS `xcodebuild build`（CODE_SIGNING_ALLOWED=NO） | exit 0 |
| macOS `xcodebuild test` | 232 项通过，0 失败、0 跳过（xcresult 摘要） |
| `xcodegen generate --spec project.yml` | exit 0；工程仅新增 4 个文件引用，重复生成无差异 |
| iOS `generic/platform=iOS` build | exit 0（未跑模拟器/真机） |
| `git diff --check` | 通过 |

新增回归：缓存命中、仅当天写 today 缓存、历史写缓存、写缓存失败不影响返回、失败保留旧缓存、按账号清除、签到单次转发与 WebVPN 转发/探测不到时 no-op。原 CheckInViewModel 14 项用例改为注入仓储 stub，断言不变。

已知未完成：缓存写入改为网络成功后立即执行（在 ViewModel generation guard 前），账号重置瞬间可能多写一次该账号快照；按账号隔离且失败仅日志，不影响界面状态。真实账号签到写往返仍未验收；Library / CGYY / 认证仍直接组合客户端。

# BUAA Assistant - 测试计划

## 当前测试证据（2026-10-16）

源码现有 133 个 test 方法。0.1.0-alpha 收口后执行以下命令全部通过；另验证了 Release 配置构建。空教室筛选改为后台计算后，`ClassroomViewModelTests` 曾出现未等待结果的回归，已由 `ClassroomViewModel.waitForFilterUpdate()` 修复并重新纳入回归；`ScheduleParserTests` 新增研究生不可推算教学班跳过、全部无排课行拒绝与“只有一周标记本周”的回归；`HomeworkViewModelTests` 新增希冀来源暂时下线的配置回归。

```sh
xcodebuild build -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet
git diff --check
```

| 实际测试文件 | 覆盖范围 |
|---|---|
| CasPageParserTests / CasFormParserTests | 页面字段、验证码识别、隐藏表单与编码 |
| CasClientTests / AppStateSessionTests | 模拟认证响应、会话恢复、错误与本地清理 |
| ScheduleParserTests | 本科结构、研究生周次位图、开学日期、学期码缺省与节次合并 |
| GradeParserTests | 学期归一化、字段类型漂移、不及格计入与等级制排除 |
| TimetableAndLibraryTests | 交错课程分栏、CAS query/fragment、AES-CBC OpenSSL 固定向量 |
| ClassroomViewModelTests / ExamViewModelTests | 后台筛选/排序/计数一致性、分页可达性、账号磁盘缓存、考试解析与业务错误 |
| CheckInClientTests / CheckInViewModelTests | iclass 状态、重复行与并发刷新、WebVPN 回退、通知去重与权限提示 |
| JudgeHomeworkClientTests / SpocHomeworkClientTests / HomeworkViewModelTests | 两来源作业解析、详情归属、状态保留与缓存兼容 |
| LibraryPublicStatsParserTests / LibraryOccupancyHistoryTests / CampusNoticesClientTests / WorkspaceIntegrationTests | 官网人数解析、本机聚合历史、通知缓存、账号隔离与工作区重置 |

尚无自动化证据：图书馆业务请求与真实预约闭环、空教室请求、待办存取交互、完整网络缓存失败路径、窗口快照及 VoiceOver。覆盖率尚未测量，CI 与黄金文件目录仍属规划。以下各节保留目标测试方案及示例，出现 AuthService、GPACalculator 等类型不表示工程已有这些实现；部分历史示例绩点映射也不代表当前规则。实际规则以 GradeModels.swift 与 GradeParserTests.swift 为准。

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

> 本期接入范围只有 6 个上游系统（见 [API.md](API.md) 附录 A）；博雅/SPOC/操场/阳光打卡/iHome/空闲教室/评教/签到等系统不在直连范围内，不巡检。旧版巡检列表里的 `bykc.buaa.edu.cn/sscv/getUserProfile` 为未验证路径，已移除。

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

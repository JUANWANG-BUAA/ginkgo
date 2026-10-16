import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class AppStateSessionTests: XCTestCase {
  func test_restore_withValidCookie_usesExistingSession() async {
    let auth = FakeAuthClient()
    auth.statusResult = .success(UserData(schoolid: "sy2501001", name: "李文"))
    let credentials = FakeCredentialStore()
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: FakeCookieStore())

    await state.restoreSession()

    XCTAssertTrue(state.isLoggedIn)
    XCTAssertEqual(state.user?.name, "李文")
    XCTAssertEqual(state.toast, "学校会话已验证，登录成功")
    XCTAssertEqual(auth.fetchCount, 0)
    XCTAssertFalse(state.isRestoring)
  }

  func test_restore_withInvalidSessionAndSavedPassword_logsInOnce() async {
    let auth = FakeAuthClient()
    auth.statusResult = .failure(CasClientError.sessionInvalid)
    auth.pageResult = .success(.loginPage(LoginPageInfo(execution: "e-1", captcha: nil, html: "")))
    let credentials = FakeCredentialStore()
    credentials.saved = SavedCredential(username: "sy2501001", password: "synthetic-password")
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: FakeCookieStore())

    await state.restoreSession()
    await state.restoreSession()

    XCTAssertTrue(state.isLoggedIn)
    XCTAssertEqual(auth.loginCount, 1)
    XCTAssertEqual(auth.fetchCount, 1)
    XCTAssertEqual(state.rememberedCredential?.username, "sy2501001")
  }

  func test_restore_withCaptcha_waitsForManualLogin() async {
    let auth = FakeAuthClient()
    auth.statusResult = .failure(CasClientError.sessionInvalid)
    let captcha = CaptchaChallenge(type: "local", id: "c-1", imageURL: URL(string: "https://sso.buaa.edu.cn/captcha?captchaId=c-1")!)
    auth.pageResult = .success(.loginPage(LoginPageInfo(execution: "e-1", captcha: captcha, html: "")))
    let credentials = FakeCredentialStore()
    credentials.saved = SavedCredential(username: "sy2501001", password: "synthetic-password")
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: FakeCookieStore())

    await state.restoreSession()

    XCTAssertFalse(state.isLoggedIn)
    XCTAssertEqual(auth.loginCount, 0)
    XCTAssertTrue(state.notice?.contains("验证码") == true)
  }

  func test_restore_withServerError_doesNotRetrySavedPassword() async {
    let auth = FakeAuthClient()
    auth.statusResult = .failure(CasClientError.unexpectedStatus(503))
    let credentials = FakeCredentialStore()
    credentials.saved = SavedCredential(username: "sy2501001", password: "synthetic-password")
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: FakeCookieStore())

    await state.restoreSession()

    XCTAssertFalse(state.isLoggedIn)
    XCTAssertEqual(auth.fetchCount, 0)
    XCTAssertEqual(auth.loginCount, 0)
    XCTAssertTrue(state.notice?.contains("暂时无法验证") == true)
  }

  func test_confirmAuthFailure_withServerError_preservesSession() async {
    let auth = FakeAuthClient()
    auth.statusResult = .failure(CasClientError.unexpectedStatus(503))
    let cookies = FakeCookieStore()
    let state = AppState(authClient: auth, credentialStore: FakeCredentialStore(), cookieStore: cookies)
    state.acceptExistingSession(UserData(schoolid: "sy2501001", name: "李文"))

    do {
      _ = try await state.confirmSessionAfterAuthFailure()
      XCTFail("5xx 应保持为服务错误")
    } catch CasClientError.unexpectedStatus(let code) {
      XCTAssertEqual(code, 503)
    } catch {
      XCTFail("错误类型不正确")
    }
    XCTAssertTrue(state.isLoggedIn)
    XCTAssertEqual(cookies.clearCount, 0)
  }

  func test_confirmAuthFailure_withInvalidSession_clearsCookies() async throws {
    let auth = FakeAuthClient()
    auth.statusResult = .failure(CasClientError.sessionInvalid)
    let cookies = FakeCookieStore()
    let state = AppState(authClient: auth, credentialStore: FakeCredentialStore(), cookieStore: cookies)
    state.acceptExistingSession(UserData(schoolid: "sy2501001", name: "李文"))

    let valid = try await state.confirmSessionAfterAuthFailure()

    XCTAssertFalse(valid)
    XCTAssertFalse(state.isLoggedIn)
    XCTAssertEqual(cookies.clearCount, 1)
  }

  func test_completeLogin_respectsRememberPassword() throws {
    let credentials = FakeCredentialStore()
    let state = AppState(authClient: FakeAuthClient(), credentialStore: credentials, cookieStore: FakeCookieStore())
    let user = UserData(schoolid: "sy2501001", name: "李文")

    try state.completeLogin(user, username: "sy2501001", password: "synthetic-password", rememberPassword: true)
    XCTAssertNotNil(credentials.saved)
    try state.completeLogin(user, username: "sy2501001", password: "synthetic-password", rememberPassword: false)
    XCTAssertNil(credentials.saved)
    XCTAssertEqual(credentials.deleteCount, 1)
    XCTAssertEqual(state.toast, "登录成功，学校会话已验证")
  }

  func test_retryWebVPNSessionUsesSavedCredentialAndCanRecover() async throws {
    let auth = FakeAuthClient()
    let credentials = FakeCredentialStore()
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: FakeCookieStore())
    try state.completeLogin(
      UserData(schoolid: "sy2501001", name: "李文"),
      username: "sy2501001",
      password: "synthetic-password",
      rememberPassword: true
    )

    auth.webVPNError = CasClientError.unexpectedStatus(503)
    await state.retryWebVPNSession()
    XCTAssertEqual(state.webVPNSessionStatus, .unavailable)
    XCTAssertEqual(auth.webVPNPreparationCount, 1)

    auth.webVPNError = nil
    await state.retryWebVPNSession()
    XCTAssertEqual(state.webVPNSessionStatus, .ready)
    XCTAssertEqual(auth.webVPNPreparationCount, 2)
  }

  func test_retryWebVPNSessionWithoutRememberedCredentialDoesNotAttemptAuthentication() async {
    let auth = FakeAuthClient()
    let state = AppState(authClient: auth, credentialStore: FakeCredentialStore(), cookieStore: FakeCookieStore())
    state.acceptExistingSession(UserData(schoolid: "sy2501001", name: "李文"))

    await state.retryWebVPNSession()

    XCTAssertFalse(state.canRetryWebVPNSession)
    XCTAssertEqual(auth.webVPNPreparationCount, 0)
    XCTAssertTrue(state.toast?.contains("重新登录") == true)
  }

  func test_logout_withRemoteFailure_stillClearsLocalState() async {
    let auth = FakeAuthClient()
    auth.logoutError = CasClientError.unexpectedStatus(503)
    let credentials = FakeCredentialStore()
    credentials.saved = SavedCredential(username: "sy2501001", password: "synthetic-password")
    let cookies = FakeCookieStore()
    let state = AppState(authClient: auth, credentialStore: credentials, cookieStore: cookies)
    state.acceptExistingSession(UserData(schoolid: "sy2501001", name: "李文"))

    await state.logout()

    XCTAssertFalse(state.isLoggedIn)
    XCTAssertNil(state.user)
    XCTAssertNil(credentials.saved)
    XCTAssertEqual(cookies.clearCount, 1)
    XCTAssertNil(state.toast)
    XCTAssertTrue(state.notice?.contains("本机") == true)
  }
}

private final class FakeAuthClient: AuthSessionClient, WebVPNSessionPreparing {
  var statusResult: Result<UserData, Error> = .failure(CasClientError.sessionInvalid)
  var pageResult: Result<LoginPageResult, Error> = .failure(CasClientError.missingExecution)
  var loginResult: Result<UserData, Error> = .success(UserData(schoolid: "sy2501001", name: "李文"))
  var logoutError: Error?
  var webVPNError: Error?
  var fetchCount = 0
  var loginCount = 0
  var webVPNPreparationCount = 0

  func fetchLoginPage() async throws -> LoginPageResult {
    fetchCount += 1
    return try pageResult.get()
  }
  func login(page: LoginPageInfo, username: String, password: String, captchaText: String?) async throws -> UserData {
    loginCount += 1
    return try loginResult.get()
  }
  func loginWithExistingSession() async throws -> UserData { try loginResult.get() }
  func validateSession() async throws -> UserData { try statusResult.get() }
  func logout() async throws { if let logoutError { throw logoutError } }
  func establishWebVPNSession(username: String, password: String) async throws {
    webVPNPreparationCount += 1
    if let webVPNError { throw webVPNError }
  }
}

private final class FakeCredentialStore: CredentialStore {
  var saved: SavedCredential?
  var deleteCount = 0
  func read() throws -> SavedCredential? { saved }
  func save(_ credential: SavedCredential) throws { saved = credential }
  func delete() throws { saved = nil; deleteCount += 1 }
}

private final class FakeCookieStore: CookieClearing {
  var clearCount = 0
  func clearAll() { clearCount += 1 }
}

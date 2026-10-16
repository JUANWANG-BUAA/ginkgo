import Foundation
import XCTest
@testable import BUAA_Assistant

final class CheckInClientTests: XCTestCase {
  override func tearDown() {
    CheckInMockURLProtocol.handler = nil
    super.tearDown()
  }

  func testWebVPNSessionsShareAnIsolatedCookieStore() {
    let api = APIClient.shared
    let redirectStorage = api.webVPNNoRedirectSession.configuration.httpCookieStorage
    let automaticStorage = api.webVPNSession.configuration.httpCookieStorage

    XCTAssertNotNil(redirectStorage)
    XCTAssertTrue(redirectStorage === automaticStorage)
    XCTAssertFalse(redirectStorage === HTTPCookieStorage.shared)
  }

  func testWebVPNRouterMatchesUBAAHostCodecVector() throws {
    let upstream = URL(string: "http://i.buaa.edu.cn/web/#/login?type=0&token=fixture-token")!

    let wrapped = try WebVPNRouter.wrap(upstream)

    XCTAssertEqual(
      wrapped.absoluteString,
      "https://d.buaa.edu.cn/http/77726476706e69737468656265737421f9b94389263126557a1dc7af96/web/#/login?type=0&token=fixture-token"
    )
    XCTAssertEqual(WebVPNRouter.unwrap(wrapped), upstream)
  }

  func testWebVPNRouterEncodesIClassCustomPortAndResolvesRedirects() throws {
    let upstream = URL(string: "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter")!
    let loginURL = URL(string: "https://iclass.buaa.edu.cn:8346/?loginName=abc%2Bdef%2Fghi%3D#/MyCenter")!
    let wrappedLoginURL = try WebVPNRouter.wrap(loginURL)

    let wrapped = try WebVPNRouter.wrap(upstream)
    let resolved = WebVPNRouter.resolveRedirect(wrappedLoginURL.absoluteString, relativeTo: upstream)

    XCTAssertTrue(wrapped.path.hasPrefix("/https-8346/"))
    XCTAssertEqual(WebVPNRouter.unwrap(wrapped), upstream)
    XCTAssertEqual(resolved, loginURL)
  }

  func testWebVPNRouterPreservesGatewayOwnedRedirectsItCannotUnwrap() throws {
    let gatewayLogin = URL(string: "https://d.buaa.edu.cn/login?next=%2Fportal")!

    XCTAssertEqual(WebVPNRouter.unwrap(gatewayLogin), gatewayLogin)
    XCTAssertEqual(
      WebVPNRouter.resolveRedirect(gatewayLogin.absoluteString, relativeTo: URL(string: "https://iclass.buaa.edu.cn:8346/")!),
      gatewayLogin
    )
  }

  func testLoadTodayFallsBackToUBAAWebVPNRouteAfterDirectTLSFailure() async throws {
    let webVPNCookies = URLSessionConfiguration.ephemeral.httpCookieStorage!
    let gatewayCookie = HTTPCookie(properties: [
      .domain: "d.buaa.edu.cn",
      .path: "/",
      .name: "webvpn_session",
      .value: "synthetic-session",
      .secure: "TRUE"
    ])!
    webVPNCookies.setCookie(gatewayCookie)
    let directSession = makeSession(cookieStorage: makeCookieStorage())
    let directNoRedirectSession = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    let webVPNSession = makeSession(cookieStorage: webVPNCookies)
    let webVPNNoRedirectSession = makeSession(cookieStorage: webVPNCookies, noRedirect: true)
    let wrappedSigninURL = try WebVPNRouter.wrap(URL(string: "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter")!)
    XCTAssertTrue(webVPNCookies.cookies(for: wrappedSigninURL)?.contains(where: { $0.name == "webvpn_session" }) == true)
    XCTAssertTrue(webVPNSession.configuration.httpCookieStorage === webVPNCookies)
    XCTAssertTrue(webVPNNoRedirectSession.configuration.httpCookieStorage === webVPNCookies)
    defer {
      [directSession, directNoRedirectSession, webVPNSession, webVPNNoRedirectSession]
        .forEach { $0.invalidateAndCancel() }
    }

    var requests: [String] = []
    CheckInMockURLProtocol.handler = { request in
      guard let requestURL = request.url else { throw URLError(.badURL) }
      if requestURL.host == "iclass.buaa.edu.cn", requestURL.port == 8346 {
        throw URLError(.secureConnectionFailed)
      }

      XCTAssertEqual(requestURL.host, "d.buaa.edu.cn", "fallback traffic must use the WebVPN gateway")
      guard let upstreamURL = WebVPNRouter.unwrap(requestURL) else {
        throw URLError(.badURL)
      }
      requests.append(upstreamURL.absoluteString)

      if upstreamURL.port == 8346 {
        return (302, ["Location": "https://sso.buaa.edu.cn/login?service=iclass"], Data())
      }
      if upstreamURL.host == "sso.buaa.edu.cn", upstreamURL.path == "/login" {
        let redirect = URL(string: "https://iclass.buaa.edu.cn:8346/?loginName=abc%2Bdef%2Fghi%3D#/MyCenter")!
        return (302, ["Location": try WebVPNRouter.wrap(redirect).absoluteString], Data())
      }
      if upstreamURL.path == "/app/user/login.action" {
        let query = URLComponents(url: upstreamURL, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first(where: { $0.name == "phone" })?.value, "abc+def/ghi=")
        return (200, [:], Data(#"{"STATUS":"0","result":{"id":"user-1","sessionId":"session-1"}}"#.utf8))
      }
      if upstreamURL.path == "/app/course/get_stu_course_sched.action" {
        XCTAssertEqual(request.value(forHTTPHeaderField: "sessionId"), "session-1")
        XCTAssertEqual(request.httpMethod, "GET")
        return (200, [:], Data(#"{"STATUS":"0","result":[{"id":"course-1","courseName":"软件工程","classBeginTime":"08:00","classEndTime":"09:40","signStatus":1}]}"#.utf8))
      }
      throw URLError(.unsupportedURL)
    }

    let client = CheckInClient(
      session: directSession,
      noRedirectSession: directNoRedirectSession,
      webVPNSession: webVPNSession,
      webVPNNoRedirectSession: webVPNNoRedirectSession
    )
    let snapshot = try await client.loadToday(account: "synthetic-account")

    XCTAssertEqual(snapshot.items.map(\.id), ["course-1"])
    XCTAssertEqual(snapshot.items.first?.status, .signed)
    XCTAssertEqual(requests.count, 4)
    XCTAssertTrue(requests[0].hasPrefix("https://iclass.buaa.edu.cn:8346/"))
    XCTAssertTrue(requests[1].hasPrefix("https://sso.buaa.edu.cn/login"))
    XCTAssertTrue(requests[2].hasPrefix("https://iclass.buaa.edu.cn:8347/app/user/login.action"))
    XCTAssertTrue(requests[3].hasPrefix("https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action"))
  }

  func testLoadOnDateSendsSchoolLocalDateToIClassScheduleEndpoint() async throws {
    let directCookies = makeCookieStorage()
    let directSession = makeSession(cookieStorage: directCookies)
    let directNoRedirectSession = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    let webVPNCookies = makeCookieStorage()
    let webVPNSession = makeSession(cookieStorage: webVPNCookies)
    let webVPNNoRedirectSession = makeSession(cookieStorage: webVPNCookies, noRedirect: true)
    defer {
      [directSession, directNoRedirectSession, webVPNSession, webVPNNoRedirectSession]
        .forEach { $0.invalidateAndCancel() }
    }

    var requestedDate: String?
    CheckInMockURLProtocol.handler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.port == 8346 {
        return (302, ["Location": "https://sso.buaa.edu.cn/login?service=iclass"], Data())
      }
      if url.host == "sso.buaa.edu.cn" {
        return (302, ["Location": "https://iclass.buaa.edu.cn:8346/?loginName=synthetic-account#/MyCenter"], Data())
      }
      if url.path == "/app/user/login.action" {
        return (200, [:], Data(#"{"STATUS":"0","result":{"id":"user-1","sessionId":"session-1"}}"#.utf8))
      }
      if url.path == "/app/course/get_stu_course_sched.action" {
        requestedDate = URLComponents(url: url, resolvingAgainstBaseURL: false)?
          .queryItems?.first(where: { $0.name == "dateStr" })?.value
        XCTAssertEqual(request.value(forHTTPHeaderField: "sessionId"), "session-1")
        return (200, [:], Data(#"{"STATUS":"0","result":[{"id":"course-1","courseName":"历史课程","classBeginTime":"08:00","classEndTime":"09:40","signStatus":0}]}"#.utf8))
      }
      throw URLError(.unsupportedURL)
    }

    let client = CheckInClient(
      session: directSession,
      noRedirectSession: directNoRedirectSession,
      webVPNSession: webVPNSession,
      webVPNNoRedirectSession: webVPNNoRedirectSession
    )
    var schoolCalendar = Calendar(identifier: .gregorian)
    schoolCalendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let date = try XCTUnwrap(schoolCalendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))

    let snapshot = try await client.loadOnDate(account: "synthetic-account", date: date)

    XCTAssertEqual(requestedDate, "20261015")
    XCTAssertEqual(snapshot.schoolDate, "20261015")
    XCTAssertEqual(snapshot.items.first?.courseName, "历史课程")
    XCTAssertEqual(snapshot.items.first?.status, .notSigned)
  }

  func testLoadTodayMergesRepeatedSessionsAndDisablesAmbiguousSignIn() async throws {
    let directSession = makeSession(cookieStorage: makeCookieStorage())
    let directNoRedirectSession = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    let webVPNCookies = makeCookieStorage()
    let webVPNSession = makeSession(cookieStorage: webVPNCookies)
    let webVPNNoRedirectSession = makeSession(cookieStorage: webVPNCookies, noRedirect: true)
    defer {
      [directSession, directNoRedirectSession, webVPNSession, webVPNNoRedirectSession]
        .forEach { $0.invalidateAndCancel() }
    }

    CheckInMockURLProtocol.handler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.port == 8346 {
        return (302, ["Location": "https://sso.buaa.edu.cn/login?service=iclass"], Data())
      }
      if url.host == "sso.buaa.edu.cn" {
        return (302, ["Location": "https://iclass.buaa.edu.cn:8346/?loginName=synthetic-account#/MyCenter"], Data())
      }
      if url.path == "/app/user/login.action" {
        return (200, [:], Data(#"{"STATUS":"0","result":{"id":"user-1","sessionId":"session-1"}}"#.utf8))
      }
      if url.path == "/app/course/get_stu_course_sched.action" {
        return (200, [:], Data(#"{"STATUS":"0","result":[{"id":"course-1","courseName":"课程甲","classBeginTime":"08:00","classEndTime":"09:40","signStatus":0},{"id":"course-1","courseName":"课程甲","classBeginTime":"08:00","classEndTime":"09:40","signStatus":0},{"id":"course-3","courseName":"课程甲","classBeginTime":"08:00","classEndTime":"09:40","signStatus":0},{"id":"course-4","courseName":"课程甲","classBeginTime":"10:00","classEndTime":"11:40","signStatus":0},{"id":"course-2","courseName":"课程乙","classBeginTime":"12:00","classEndTime":"13:40","signStatus":0},{"id":"course-2","courseName":"课程乙","classBeginTime":"12:00","classEndTime":"13:40","signStatus":1}]}"#.utf8))
      }
      throw URLError(.unsupportedURL)
    }

    let client = CheckInClient(
      session: directSession,
      noRedirectSession: directNoRedirectSession,
      webVPNSession: webVPNSession,
      webVPNNoRedirectSession: webVPNNoRedirectSession
    )
    let snapshot = try await client.loadToday(account: "synthetic-account")

    XCTAssertEqual(snapshot.items.count, 3)

    let mergedSameSession = try XCTUnwrap(snapshot.items.first { $0.courseName == "课程甲" && $0.beginsAt == "08:00" })
    XCTAssertEqual(mergedSameSession.id, "course-1")
    XCTAssertEqual(mergedSameSession.status, .notSigned)
    XCTAssertEqual(mergedSameSession.mergedRecordCount, 3)
    XCTAssertFalse(mergedSameSession.signInAllowed, "Multiple upstream IDs make the write target ambiguous.")

    let separateMeeting = try XCTUnwrap(snapshot.items.first { $0.courseName == "课程甲" && $0.beginsAt == "10:00" })
    XCTAssertEqual(separateMeeting.mergedRecordCount, 1, "The same course at a different time remains a separate session.")
    XCTAssertTrue(separateMeeting.signInAllowed)

    let conflictingStatus = try XCTUnwrap(snapshot.items.first { $0.courseName == "课程乙" })
    XCTAssertEqual(conflictingStatus.status, .unknown)
    XCTAssertFalse(conflictingStatus.signInAllowed)
    XCTAssertEqual(conflictingStatus.mergedRecordCount, 2)
  }

  func testLoadTodayTreatsStatusTwoAsEmptyScheduleWithoutRefreshingSession() async throws {
    let webVPNCookies = URLSessionConfiguration.ephemeral.httpCookieStorage!
    let directSession = makeSession(cookieStorage: makeCookieStorage())
    let directNoRedirectSession = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    let webVPNSession = makeSession(cookieStorage: webVPNCookies)
    let webVPNNoRedirectSession = makeSession(cookieStorage: webVPNCookies, noRedirect: true)
    defer {
      [directSession, directNoRedirectSession, webVPNSession, webVPNNoRedirectSession]
        .forEach { $0.invalidateAndCancel() }
    }

    var loginRequests = 0
    var scheduleRequests = 0
    CheckInMockURLProtocol.handler = { request in
      guard let requestURL = request.url,
            let upstreamURL = WebVPNRouter.unwrap(requestURL) else {
        throw URLError(.badURL)
      }
      if upstreamURL.port == 8346 {
        return (302, ["Location": "https://sso.buaa.edu.cn/login?service=iclass"], Data())
      }
      if upstreamURL.host == "sso.buaa.edu.cn", upstreamURL.path == "/login" {
        let redirect = URL(string: "https://iclass.buaa.edu.cn:8346/?loginName=synthetic-login#/MyCenter")!
        return (302, ["Location": try WebVPNRouter.wrap(redirect).absoluteString], Data())
      }
      if upstreamURL.path == "/app/user/login.action" {
        loginRequests += 1
        return (200, [:], Data(#"{"STATUS":"0","result":{"id":"user-1","sessionId":"session-1"}}"#.utf8))
      }
      if upstreamURL.path == "/app/course/get_stu_course_sched.action" {
        scheduleRequests += 1
        return (200, [:], Data(#"{"STATUS":"2"}"#.utf8))
      }
      throw URLError(.unsupportedURL)
    }

    let client = CheckInClient(
      session: directSession,
      noRedirectSession: directNoRedirectSession,
      webVPNSession: webVPNSession,
      webVPNNoRedirectSession: webVPNNoRedirectSession
    )
    await client.setWebVPNRouteEnabled(true)

    let snapshot = try await client.loadToday(account: "synthetic-account")

    XCTAssertTrue(snapshot.items.isEmpty)
    XCTAssertEqual(loginRequests, 1)
    XCTAssertEqual(scheduleRequests, 1, "An explicit empty-schedule status must not clear or retry the iclass session")
  }

  func testManualSignInUsesUBAAFormAndReturnsConfirmedResult() async throws {
    let webVPNCookies = URLSessionConfiguration.ephemeral.httpCookieStorage!
    let directSession = makeSession(cookieStorage: makeCookieStorage())
    let directNoRedirectSession = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    let webVPNSession = makeSession(cookieStorage: webVPNCookies)
    let webVPNNoRedirectSession = makeSession(cookieStorage: webVPNCookies, noRedirect: true)
    defer {
      [directSession, directNoRedirectSession, webVPNSession, webVPNNoRedirectSession]
        .forEach { $0.invalidateAndCancel() }
    }

    var scheduleReads = 0
    CheckInMockURLProtocol.handler = { request in
      guard let requestURL = request.url else { throw URLError(.badURL) }
      if requestURL.host == "iclass.buaa.edu.cn", requestURL.port == 8346 {
        throw URLError(.secureConnectionFailed)
      }
      guard let upstreamURL = WebVPNRouter.unwrap(requestURL) else { throw URLError(.badURL) }

      if upstreamURL.port == 8346 {
        return (302, ["Location": "https://sso.buaa.edu.cn/login?service=iclass"], Data())
      }
      if upstreamURL.host == "sso.buaa.edu.cn" {
        let redirect = URL(string: "https://iclass.buaa.edu.cn:8346/?loginName=synthetic-login#/MyCenter")!
        return (302, ["Location": try WebVPNRouter.wrap(redirect).absoluteString], Data())
      }
      if upstreamURL.path == "/app/user/login.action" {
        return (200, [:], Data(#"{"STATUS":"0","result":{"id":"user-1","sessionId":"session-1"}}"#.utf8))
      }
      if upstreamURL.path == "/app/course/get_stu_course_sched.action" {
        scheduleReads += 1
        let status = scheduleReads == 1 ? 0 : 1
        return (200, [:], Data(#"{"STATUS":"0","result":[{"id":"course-1","courseName":"合成课程","classBeginTime":"08:00","classEndTime":"09:40","signStatus":\#(status)}]}"#.utf8))
      }
      if upstreamURL.path == "/app/common/get_timestamp.action" {
        return (200, [:], Data(#"{"timestamp":"fixture-time"}"#.utf8))
      }
      if upstreamURL.path == "/app/course/stu_scan_sign.action" {
        let query = URLComponents(url: upstreamURL, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "sessionId"), "session-1")
        XCTAssertEqual(query?.first(where: { $0.name == "courseSchedId" })?.value, "course-1")
        XCTAssertEqual(query?.first(where: { $0.name == "timestamp" })?.value, "fixture-time")
        XCTAssertEqual(self.bodyText(request), "id=user-1")
        return (200, [:], Data(#"{"STATUS":"0","result":{"stuSignStatus":"1"}}"#.utf8))
      }
      throw URLError(.unsupportedURL)
    }

    let client = CheckInClient(
      session: directSession,
      noRedirectSession: directNoRedirectSession,
      webVPNSession: webVPNSession,
      webVPNNoRedirectSession: webVPNNoRedirectSession
    )
    let initial = try await client.loadToday(account: "synthetic-account")
    XCTAssertEqual(initial.items.first?.status, .notSigned)

    let action = try await client.performSignIn(account: "synthetic-account", courseID: "course-1")

    XCTAssertTrue(action.succeeded)
    XCTAssertEqual(scheduleReads, 1, "The client does not silently issue a post-write status query; the view model owns confirmation.")
  }

  func testLoadTodayExplainsWebVPNGatewayResponseWithoutClaimingSuccess() async throws {
    let session = makeSession(cookieStorage: makeCookieStorage(), noRedirect: true)
    defer { session.invalidateAndCancel() }

    CheckInMockURLProtocol.handler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.host == "iclass.buaa.edu.cn" { throw URLError(.secureConnectionFailed) }
      if url.path.hasPrefix("/https-8346/") {
        return (302, ["Location": "https://sso.buaa.edu.cn/login"], Data())
      }
      return (200, ["Content-Type": "text/html"], Data("login".utf8))
    }

    let client = CheckInClient(
      session: session,
      noRedirectSession: session,
      webVPNSession: session,
      webVPNNoRedirectSession: session
    )
    do {
      _ = try await client.loadToday(account: "synthetic-account")
      XCTFail("A gateway login page must not be interpreted as a successful check-in response")
    } catch let error as CheckInError {
      XCTAssertEqual(error, .webVPNUnavailable)
      XCTAssertEqual(
        error.errorDescription,
        "iclass 未识别当前 WebVPN 登录态，签到状态未确认；请重新登录学校账号后重试"
      )
    }
  }

  private func makeSession(cookieStorage: HTTPCookieStorage, noRedirect: Bool = false) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CheckInMockURLProtocol.self]
    configuration.httpCookieStorage = cookieStorage
    configuration.httpShouldSetCookies = true
    configuration.httpCookieAcceptPolicy = .always
    if noRedirect {
      return URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }
    return URLSession(configuration: configuration)
  }

  private func makeCookieStorage() -> HTTPCookieStorage {
    URLSessionConfiguration.ephemeral.httpCookieStorage!
  }

  private func bodyText(_ request: URLRequest) -> String? {
    if let body = request.httpBody { return String(data: body, encoding: .utf8) }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var bytes = [UInt8](repeating: 0, count: 1_024)
    var data = Data()
    while stream.hasBytesAvailable {
      let count = stream.read(&bytes, maxLength: bytes.count)
      if count <= 0 { break }
      data.append(bytes, count: count)
    }
    return String(data: data, encoding: .utf8)
  }
}

private final class CheckInMockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    do {
      let (status, headers, data) = try handler(request)
      guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        return
      }
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

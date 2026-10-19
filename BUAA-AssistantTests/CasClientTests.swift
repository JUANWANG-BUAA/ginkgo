import Foundation
import XCTest
@testable import BUAA_Assistant

final class CasClientTests: XCTestCase {
  private var session: URLSession!
  private var client: CasClient!

  override func setUp() {
    super.setUp()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CasMockURLProtocol.self]
    session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
    client = CasClient(session: session)
  }

  override func tearDown() {
    CasMockURLProtocol.handler = nil
    CasMockURLProtocol.cookieStorage = nil
    session.invalidateAndCancel()
    client = nil
    session = nil
    super.tearDown()
  }

  func test_fetchLoginPage_withHTML_returnsParsedPage() async throws {
    CasMockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://sso.buaa.edu.cn/login")
      XCTAssertEqual(request.httpMethod, "GET")
      let html = #"<input name="execution" value="part+two/three"/><script>config.captcha = { type: 'local', id: 'cap-123' }</script>"#
      return (200, [:], Data(html.utf8))
    }

    let result = try await client.fetchLoginPage()
    guard case .loginPage(let page) = result else {
      return XCTFail("应返回登录页")
    }
    XCTAssertEqual(page.execution, "part+two/three")
    XCTAssertEqual(page.captcha?.id, "cap-123")
    XCTAssertTrue(page.html.contains("execution"))
  }

  func test_fetchLoginPage_withRedirect_returnsExistingSession() async throws {
    CasMockURLProtocol.handler = { _ in
      (302, ["Location": "/cas/continue"], Data())
    }

    let result = try await client.fetchLoginPage()
    guard case .existingSession(let url) = result else {
      return XCTFail("应识别已有会话")
    }
    XCTAssertEqual(url.absoluteString, "https://sso.buaa.edu.cn/cas/continue")
  }

  func test_fetchLoginPage_withTip_returnsUpstreamMessage() async throws {
    CasMockURLProtocol.handler = { _ in
      let html = #"<div class="tip-text">账号已锁定</div><input name="execution" value="e-1"/>"#
      return (200, [:], Data(html.utf8))
    }

    do {
      _ = try await client.fetchLoginPage()
      XCTFail("预登录提示应终止登录")
    } catch CasClientError.preLoginTip(let tip) {
      XCTAssertEqual(tip, "账号已锁定")
    }
  }

  func test_fetchLoginPage_withoutExecution_reportsPageChange() async throws {
    CasMockURLProtocol.handler = { _ in (200, [:], Data("<html></html>".utf8)) }

    do {
      _ = try await client.fetchLoginPage()
      XCTFail("缺少 execution 应报错")
    } catch CasClientError.missingExecution {
      // 预期错误
    }
  }

  func test_fetchLoginPage_withHTTP483_reportsAccessPolicy() async throws {
    CasMockURLProtocol.handler = { _ in (483, [:], Data()) }
    do {
      _ = try await client.fetchLoginPage()
      XCTFail("HTTP 483 应提示访问策略")
    } catch CasClientError.accessPolicyDenied {
      // 预期错误
    }
  }

  func test_fetchLoginPage_withServerFailure_reportsStatus() async throws {
    CasMockURLProtocol.handler = { _ in (503, [:], Data()) }

    do {
      _ = try await client.fetchLoginPage()
      XCTFail("5xx 应报暂时错误")
    } catch CasClientError.unexpectedStatus(let status) {
      XCTAssertEqual(status, 503)
    }
  }

  func test_login_followsRedirectAndValidatesUcStatus() async throws {
    CasMockURLProtocol.handler = { request in
      let url = request.url!.absoluteString
      if url == "https://sso.buaa.edu.cn/login" && request.httpMethod == "POST" {
        return (302, ["Location": "/cas/done"], Data())
      }
      if url == "https://sso.buaa.edu.cn/cas/done" {
        return (200, [:], Data("<html>完成</html>".utf8))
      }
      if url.hasPrefix("https://uc.buaa.edu.cn/api/login?") {
        return (200, [:], Data("ok".utf8))
      }
      if url == "https://uc.buaa.edu.cn/api/uc/status" {
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Requested-With"), "XMLHttpRequest")
        let json = #"{"code":0,"data":{"schoolid":"sy2501001","name":"李文"}}"#
        return (200, [:], Data(json.utf8))
      }
      XCTFail("意外请求：\(url)")
      return (404, [:], Data())
    }
    let page = LoginPageInfo(execution: "e-1", captcha: nil, html: #"<input type="hidden" name="execution" value="e-1">"#)

    let user = try await client.login(page: page, username: "sy2501001", password: "test", captchaText: nil)
    XCTAssertEqual(user, UserData(schoolid: "sy2501001", name: "李文"))
  }

  func test_login_withExpiryPage_skipsOnce() async throws {
    var postCount = 0
    CasMockURLProtocol.handler = { request in
      let url = request.url!.absoluteString
      if url == "https://sso.buaa.edu.cn/login" {
        postCount += 1
        if postCount == 1 {
          let html = #"<input name="execution" value="e-2"><form name="continueForm"><button id="ignoreAndContinue">继续</button></form>"#
          return (200, [:], Data(html.utf8))
        }
        return (302, ["Location": "/done"], Data())
      }
      if url == "https://sso.buaa.edu.cn/done" { return (200, [:], Data("ok".utf8)) }
      if url.hasPrefix("https://uc.buaa.edu.cn/api/login?") { return (200, [:], Data()) }
      if url == "https://uc.buaa.edu.cn/api/uc/status" {
        return (200, [:], Data(#"{"code":0,"data":{"schoolid":"sy2501001","name":"李文"}}"#.utf8))
      }
      return (404, [:], Data())
    }
    let page = LoginPageInfo(execution: "e-1", captcha: nil, html: #"<input name="execution" value="e-1">"#)

    _ = try await client.login(page: page, username: "sy2501001", password: "test", captchaText: nil)
    XCTAssertEqual(postCount, 2)
  }

  func test_login_withHTTP483_usesServerErrorMessage() async throws {
    CasMockURLProtocol.handler = { request in
      if request.httpMethod == "POST" {
        return (483, ["Content-Type": "text/html"], Data(#"<div id="errorDiv">账号或密码错误</div>"#.utf8))
      }
      return (500, [:], Data())
    }
    let page = LoginPageInfo(execution: "e-1", captcha: nil, html: #"<input name="execution" value="e-1">"#)

    do {
      _ = try await client.login(page: page, username: "sy2501001", password: "wrong", captchaText: nil)
      XCTFail("HTTP 483 应被拒绝")
    } catch CasClientError.preLoginTip(let message) {
      XCTAssertEqual(message, "账号或密码错误")
    }
  }

  func test_login_whenUcAccessPolicyDeniesNetwork_reportsActionableError() async throws {
    CasMockURLProtocol.handler = { request in
      let url = request.url!.absoluteString
      if url == "https://sso.buaa.edu.cn/login" && request.httpMethod == "POST" {
        return (302, ["Location": "/cas/done"], Data())
      }
      if url == "https://sso.buaa.edu.cn/cas/done" {
        return (200, [:], Data("<html>完成</html>".utf8))
      }
      if url.hasPrefix("https://uc.buaa.edu.cn/api/login?") {
        let html = "<h1>访问出错</h1><p>访问策略禁止您访问该网站，您(IP：192.0.2.1)，没有权限访问相应的资源</p>"
        return (483, ["Content-Type": "text/html"], Data(html.utf8))
      }
      return (404, [:], Data())
    }
    let page = LoginPageInfo(execution: "e-1", captcha: nil, html: #"<input name="execution" value="e-1">"#)

    do {
      _ = try await client.login(page: page, username: "sy2501001", password: "test", captchaText: nil)
      XCTFail("访问策略拦截不应被报告为登录成功")
    } catch CasClientError.accessPolicyDenied {
      XCTAssertEqual(
        CasClientError.accessPolicyDenied.errorDescription,
        "当前网络被学校访问策略拦截，请连接校园网或北航 VPN 后重试"
      )
    }
  }

  func test_validateSession_withServerFailure_doesNotReportInvalidSession() async throws {
    CasMockURLProtocol.handler = { _ in (503, [:], Data()) }
    do {
      _ = try await client.validateSession()
      XCTFail("服务端失败应单独呈现")
    } catch CasClientError.unexpectedStatus(let status) {
      XCTAssertEqual(status, 503)
    }
  }

  func test_login_withCaptchaAndEmptyAnswer_doesNotSendRequest() async throws {
    CasMockURLProtocol.handler = { _ in
      XCTFail("验证码为空时不能发请求")
      return (500, [:], Data())
    }
    let challenge = CaptchaChallenge(type: "local", id: "c-1", imageURL: URL(string: "https://sso.buaa.edu.cn/captcha?captchaId=c-1")!)
    let page = LoginPageInfo(execution: "e-1", captcha: challenge, html: "")
    do {
      _ = try await client.login(page: page, username: "sy2501001", password: "test", captchaText: nil)
      XCTFail("应提示验证码")
    } catch CasClientError.captchaRequired {
      // 预期错误
    }
  }

  func test_login_withCredentialError_doesNotActivateUc() async throws {
    CasMockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.host, "sso.buaa.edu.cn")
      let html = #"<div id="errorDiv">账号或密码错误</div><input name="execution" value="new-token">"#
      return (200, [:], Data(html.utf8))
    }
    let page = LoginPageInfo(execution: "e-1", captcha: nil, html: #"<input name="execution" value="e-1">"#)
    do {
      _ = try await client.login(page: page, username: "sy2501001", password: "wrong", captchaText: nil)
      XCTFail("错误密码应被识别")
    } catch CasClientError.preLoginTip(let message) {
      XCTAssertEqual(message, "账号或密码错误")
    }
  }

  func test_establishWebVPNSession_routesCASAndUCThroughGateway() async throws {
    var upstreamRequests: [String] = []
    CasMockURLProtocol.cookieStorage = session.configuration.httpCookieStorage
    let casDoneURL = try WebVPNRouter.wrap(URL(string: "https://sso.buaa.edu.cn/cas/done")!).absoluteString
    CasMockURLProtocol.handler = { request in
      guard let gatewayURL = request.url else {
        XCTFail("WebVPN authentication request has no URL")
        return (500, [:], Data())
      }
      XCTAssertEqual(gatewayURL.host, "d.buaa.edu.cn", "routed auth URL: \(gatewayURL.absoluteString)")
      guard
            let upstreamURL = WebVPNRouter.unwrap(gatewayURL) else {
        XCTFail("WebVPN URL must decode to its upstream URL")
        return (500, [:], Data())
      }
      upstreamRequests.append("\(request.httpMethod ?? "GET") \(upstreamURL.absoluteString)")

      if upstreamURL.host == "sso.buaa.edu.cn", upstreamURL.path == "/login", request.httpMethod == "GET" {
        let cookie = HTTPCookie(properties: [
          .domain: "d.buaa.edu.cn", .path: "/", .name: "webvpn_session", .value: "fixture-session", .secure: "TRUE"
        ])!
        CasMockURLProtocol.cookieStorage?.setCookie(cookie)
        return (
          200,
          ["Set-Cookie": "webvpn_session=fixture-session; Path=/; Secure"],
          Data(#"<input type="hidden" name="execution" value="webvpn-e1">"#.utf8)
        )
      }
      if upstreamURL.host == "sso.buaa.edu.cn", upstreamURL.path == "/login", request.httpMethod == "POST" {
        return (302, ["Location": casDoneURL], Data())
      }
      if upstreamURL.host == "sso.buaa.edu.cn", upstreamURL.path == "/cas/done" {
        return (200, [:], Data("done".utf8))
      }
      if upstreamURL.host == "uc.buaa.edu.cn", upstreamURL.path == "/api/login" {
        return (200, [:], Data("ok".utf8))
      }
      if upstreamURL.host == "uc.buaa.edu.cn", upstreamURL.path == "/api/uc/status" {
        return (200, [:], Data(#"{"code":0,"data":{"schoolid":"sy2501001","name":"李文"}}"#.utf8))
      }
      XCTFail("Unexpected routed CAS request")
      return (404, [:], Data())
    }

    try await client.establishWebVPNSession(username: "sy2501001", password: "synthetic-password")

    XCTAssertTrue(
      session.configuration.httpCookieStorage?.cookies(for: URL(string: "https://d.buaa.edu.cn/")!)?
        .contains(where: { $0.name == "webvpn_session" }) == true,
      "CAS bootstrap must retain gateway cookies in the session store"
    )
    XCTAssertEqual(upstreamRequests.count, 5)
    XCTAssertTrue(upstreamRequests[0].contains("sso.buaa.edu.cn/login"))
    XCTAssertTrue(upstreamRequests[1].contains("sso.buaa.edu.cn/login"))
    XCTAssertTrue(upstreamRequests[2].contains("sso.buaa.edu.cn/cas/done"))
    XCTAssertTrue(upstreamRequests[3].contains("uc.buaa.edu.cn/api/login"))
    XCTAssertTrue(upstreamRequests[4].contains("uc.buaa.edu.cn/api/uc/status"))
  }

  func test_establishWebVPNSession_doesNotSubmitWithoutItsOwnCaptcha() async throws {
    var postCount = 0
    CasMockURLProtocol.handler = { request in
      if request.httpMethod == "POST" { postCount += 1 }
      return (200, [:], Data(#"<input name="execution" value="e1"><script>config.captcha = { type: 'local', id: 'webvpn-captcha' }</script>"#.utf8))
    }

    do {
      try await client.establishWebVPNSession(username: "sy2501001", password: "synthetic-password")
      XCTFail("WebVPN-specific captcha must not be skipped or submitted with an unrelated answer")
    } catch CasClientError.captchaRequired {
      XCTAssertEqual(postCount, 0)
    }
  }
}

private final class CasMockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, [String: String], Data))?
  static var cookieStorage: HTTPCookieStorage?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let (status, headers, data) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

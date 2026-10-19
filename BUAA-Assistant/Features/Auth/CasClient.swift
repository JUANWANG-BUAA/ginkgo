import Foundation

/// 登录页及其原始 HTML。下一步提交表单时需要从同一页面收集隐藏字段。
struct LoginPageInfo {
  let execution: String
  let captcha: CaptchaChallenge?
  let html: String
  /// 登录表单 action。WebVPN 模式下必须保留其中的 service/网关查询串。
  let actionURL: URL?

  init(execution: String, captcha: CaptchaChallenge?, html: String, actionURL: URL? = nil) {
    self.execution = execution
    self.captcha = captcha
    self.html = html
    self.actionURL = actionURL
  }
}

enum LoginPageResult {
  case loginPage(LoginPageInfo)
  case existingSession(redirectURL: URL)
}

protocol AuthSessionClient {
  func fetchLoginPage() async throws -> LoginPageResult
  func login(page: LoginPageInfo, username: String, password: String, captchaText: String?) async throws -> UserData
  func loginWithExistingSession() async throws -> UserData
  func validateSession() async throws -> UserData
  func logout() async throws
}

protocol WebVPNSessionPreparing {
  func establishWebVPNSession(username: String, password: String) async throws
}

enum CasClientError: LocalizedError {
  case invalidResponse
  case missingRedirectLocation
  case unexpectedStatus(Int)
  case invalidPageEncoding
  case missingExecution
  case preLoginTip(String)
  case captchaRequired
  case invalidCredentials
  case redirectLimit
  case sessionInvalid
  case webVPNSessionCookieMissing
  case accessPolicyDenied

  var errorDescription: String? {
    switch self {
    case .invalidResponse: "认证服务返回了无效响应"
    case .missingRedirectLocation: "认证服务的跳转地址缺失"
    case .unexpectedStatus(let status): "认证服务暂时不可用（HTTP \(status)）"
    case .invalidPageEncoding: "无法读取认证页面"
    case .missingExecution: "认证页面格式已变化，请稍后重试"
    case .preLoginTip(let tip): tip
    case .captchaRequired: "请输入验证码后重试"
    case .invalidCredentials: "账号或密码错误，请检查后重试"
    case .redirectLimit: "认证服务跳转次数过多，请稍后重试"
    case .sessionInvalid: "认证未完成，请重新登录"
    case .webVPNSessionCookieMissing: "WebVPN 网关未保存签到认证会话，请重新登录后重试"
    case .accessPolicyDenied: "当前网络被学校访问策略拦截，请连接校园网或北航 VPN 后重试"
    }
  }
}

/// CAS 认证链。登录请求使用不自动跟随重定向的会话（API.md §1.2）。
actor CasClient: AuthSessionClient, WebVPNSessionPreparing {
  private let session: URLSession
  private let routeThroughWebVPN: Bool
  private let webVPNSession: URLSession?
  private let ignoreGlobalRoute: Bool
  private var lastSendUsedWebVPN = false
  private static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
  private let loginURL: URL
  private let ucActivationURL = URL(string: "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin")!
  private let ucStatusURL = URL(string: "https://uc.buaa.edu.cn/api/uc/status")!
  private let logoutURL = URL(string: "https://sso.buaa.edu.cn/logout")!

  init(
    session: URLSession = APIClient.shared.noRedirectSession,
    routeThroughWebVPN: Bool = false,
    webVPNSession: URLSession? = nil,
    loginURL: URL = URL(string: "https://sso.buaa.edu.cn/login")!,
    ignoreGlobalRoute: Bool = false
  ) {
    self.session = session
    self.routeThroughWebVPN = routeThroughWebVPN
    self.webVPNSession = webVPNSession
    self.loginURL = loginURL
    self.ignoreGlobalRoute = ignoreGlobalRoute
  }

  /// UBAA establishes the selected WebVPN-mode CAS session before using routed providers.
  /// The direct CAS session remains intact; routed requests use the isolated WebVPN cookie store.
  func establishWebVPNSession(username: String, password: String) async throws {
    let webVPNRequestSession = webVPNSession
      ?? (session === APIClient.shared.noRedirectSession ? APIClient.shared.webVPNNoRedirectSession : session)
    let webVPNClient = CasClient(session: webVPNRequestSession, routeThroughWebVPN: true)
    switch try await webVPNClient.fetchLoginPage() {
    case .existingSession:
      _ = try await webVPNClient.loginWithExistingSession()
    case .loginPage(let page):
      guard page.captcha == nil else { throw CasClientError.captchaRequired }
      _ = try await webVPNClient.login(page: page, username: username, password: password, captchaText: nil)
    }
    let checkInURL = try WebVPNRouter.wrap(URL(string: "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter")!)
    let gatewayCookies = webVPNRequestSession.configuration.httpCookieStorage?.cookies(for: checkInURL) ?? []
    guard !gatewayCookies.isEmpty else { throw CasClientError.webVPNSessionCookieMissing }
  }

  func fetchLoginPage() async throws -> LoginPageResult {
    var currentURL = loginURL
    var data = Data()
    var http: HTTPURLResponse?

    for hop in 0...8 {
      var request = URLRequest(url: currentURL)
      request.httpMethod = "GET"
      request.timeoutInterval = 30
      do {
        (data, http) = try await send(request)
      } catch {
        AppLog.network.error("获取 CAS 登录页失败：\(error.localizedDescription, privacy: .private)")
        throw error
      }
      guard let response = http else { throw CasClientError.invalidResponse }

      guard (300..<400).contains(response.statusCode) else { break }
      guard hop < 8 else { throw CasClientError.redirectLimit }
      let targetURL: URL
      do {
        targetURL = try redirectURL(from: response, relativeTo: currentURL)
      } catch {
        AppLog.auth.error("CAS 登录页跳转缺少有效的 HTTPS Location")
        throw CasClientError.missingRedirectLocation
      }

      // WebVPN 的入口会先把网关登录页 302 到 CAS 登录页；这是正常取页，
      // 不能误判为“已有会话”。只有跳向业务系统时才走 existingSession。
      if lastSendUsedWebVPN, isLoginPageTarget(targetURL) {
        currentURL = targetURL
        continue
      }
      AppLog.auth.info("CAS 登录页返回跳转，已有会话")
      return .existingSession(redirectURL: targetURL)
    }

    guard let http else { throw CasClientError.invalidResponse }
    guard http.statusCode == 200 else {
      AppLog.auth.error("CAS 登录页返回 HTTP \(http.statusCode)")
      if http.statusCode == 483 { throw CasClientError.accessPolicyDenied }
      throw CasClientError.unexpectedStatus(http.statusCode)
    }
    guard let html = String(data: data, encoding: .utf8) else {
      AppLog.auth.error("CAS 登录页无法按 UTF-8 解码")
      throw CasClientError.invalidPageEncoding
    }
    if let tip = CasPageParser.extractTipText(from: html) {
      AppLog.auth.notice("CAS 登录页有预登录提示")
      throw CasClientError.preLoginTip(tip)
    }
    guard let execution = CasPageParser.extractExecution(from: html) else {
      AppLog.auth.error("CAS 登录页缺少 execution 字段")
      throw CasClientError.missingExecution
    }
    let captcha = CasPageParser.detectCaptcha(from: html)
    let actionURL = CasPageParser.extractLoginFormAction(from: html)
      .flatMap { WebVPNRouter.resolveRedirect($0, relativeTo: http.url ?? currentURL) }
      ?? http.url
      ?? currentURL
    AppLog.auth.info(
      "CAS 登录页已获取，需验证码：\(captcha == nil ? "no" : "yes"), action=\(self.redactedURL(actionURL))"
    )
    return .loginPage(
      LoginPageInfo(execution: execution, captcha: captcha, html: html, actionURL: actionURL)
    )
  }

  private func isLoginPageTarget(_ url: URL) -> Bool {
    if WebVPNRouter.isGatewayURL(url) {
      return url.path == "/login" || url.path.hasSuffix("/login")
    }
    return url.host?.caseInsensitiveCompare("sso.buaa.edu.cn") == .orderedSame
      && url.path.hasSuffix("/login")
  }

  /// 使用同一张登录页提交，避免 execution/验证码因重新获取页面而失效。
  func login(page: LoginPageInfo, username: String, password: String, captchaText: String?) async throws -> UserData {
    try await submitLogin(page: page, username: username, password: password, captchaText: captchaText)
    try await activateUc()
    return try await validateSession()
  }

  /// 只完成指定 service 的 CAS 登录，不激活/校验 UC。
  /// 用于 CGYY 这类只需要 SSO Cookie、不需要 UC 业务会话的系统。
  func loginForService(
    username: String,
    password: String,
    captchaText: String? = nil
  ) async throws {
    switch try await fetchLoginPage() {
    case .existingSession(let redirectURL):
      var request = URLRequest(url: redirectURL)
      request.httpMethod = "GET"
      let (data, response) = try await send(request)
      try await followRedirectsAndCheckError(
        data: data, response: response, startingAt: redirectURL
      )
    case .loginPage(let page):
      try await submitLogin(page: page, username: username, password: password, captchaText: captchaText)
    }
    let cookies = HTTPCookieStorage.shared.cookies ?? []
    guard cookies.contains(where: { $0.name == "CASTGC" && $0.value.isEmpty == false }) else {
      throw CasClientError.sessionInvalid
    }
  }


  private func submitLogin(
    page: LoginPageInfo,
    username: String,
    password: String,
    captchaText: String?
  ) async throws {
    if page.captcha != nil && (captchaText?.isEmpty ?? true) {
      throw CasClientError.captchaRequired
    }
    var fields = CasFormParser.loginFields(
      html: page.html, username: username, password: password, captchaText: captchaText
    )
    fields.removeAll { $0.0 == "execution" }
    fields.append(("execution", page.execution))
    let body = FormURLEncoding.body(fields)
    AppLog.auth.info(
      "CAS 登录参数已准备 fields=\(fields.count) action=\(self.redactedURL(page.actionURL))"
    )
    var request = URLRequest(url: page.actionURL ?? loginURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    let (data, response) = try await send(request)
    AppLog.auth.info(
      "CAS 登录提交返回 status=\(response.statusCode) bytes=\(data.count) location=\(self.redactedURL(response.url)) action=\(self.redactedURL(request.url))"
    )
    try await followRedirectsAndCheckError(
      data: data,
      response: response,
      startingAt: request.url ?? loginURL
    )
  }

  /// 已有 CASTGC 时仍须激活 UC，并由 UC status 最终判定会话有效。
  func loginWithExistingSession() async throws -> UserData {
    try await activateUc()
    return try await validateSession()
  }

  func fetchCaptchaImage(for challenge: CaptchaChallenge) async throws -> Data {
    let (data, response) = try await send(URLRequest(url: challenge.imageURL))
    guard response.statusCode == 200 else { throw CasClientError.unexpectedStatus(response.statusCode) }
    return data
  }

  /// API.md §1.6：每跳检查错误和跳转地址，最多十跳；过期提示只跳一次。
  private func followRedirectsAndCheckError(
    data initialData: Data, response initialResponse: HTTPURLResponse, startingAt initialURL: URL
  ) async throws {
    var data = initialData
    var response = initialResponse
    var currentURL = initialURL
    var skippedExpiry = false
    for hop in 0...10 {
      AppLog.auth.info(
        "CAS 跳转 hop=\(hop) status=\(response.statusCode) at=\(self.redactedURL(currentURL)) location=\(self.redactedURL(self.redirectLocation(response)))"
      )
      if let message = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "exception.message" })?.value,
        !message.isEmpty {
        throw CasClientError.preLoginTip(message)
      }
      if response.statusCode == 401 { throw CasClientError.invalidCredentials }
      if (400..<500).contains(response.statusCode) {
        let html = String(data: data, encoding: .utf8)
        if let html, CasPageParser.isAccessPolicyDenied(html) {
          throw CasClientError.accessPolicyDenied
        }
        if let html, let message = CasPageParser.extractErrorText(from: html), message.isEmpty == false {
          throw CasClientError.preLoginTip(message)
        }
        if response.statusCode == 483 {
          throw CasClientError.accessPolicyDenied
        }
        throw CasClientError.unexpectedStatus(response.statusCode)
      }
      if (500..<600).contains(response.statusCode) { throw CasClientError.unexpectedStatus(response.statusCode) }
      if (300..<400).contains(response.statusCode) {
        guard hop < 10 else { throw CasClientError.redirectLimit }
        currentURL = try redirectURL(from: response, relativeTo: currentURL)
        let next = try await send(URLRequest(url: currentURL))
        data = next.0
        response = next.1
        continue
      }
      guard response.statusCode == 200 else { throw CasClientError.unexpectedStatus(response.statusCode) }
      guard let html = String(data: data, encoding: .utf8) else { throw CasClientError.invalidPageEncoding }
      if CasPageParser.isPasswordExpiryPage(html) {
        guard !skippedExpiry else { throw CasClientError.sessionInvalid }
        skippedExpiry = true
        guard let execution = CasPageParser.extractExecution(from: html) else { throw CasClientError.missingExecution }
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoding.body([("execution", execution), ("_eventId", "ignoreAndContinue")])
        let next = try await send(request)
        currentURL = loginURL
        data = next.0
        response = next.1
        continue
      }
      if let error = CasPageParser.extractErrorText(from: html) { throw CasClientError.preLoginTip(error) }
      if CasPageParser.extractExecution(from: html) != nil {
        AppLog.auth.error(
          "CAS 提交后仍返回登录页 at=\(self.redactedURL(currentURL)) status=\(response.statusCode)"
        )
        throw CasClientError.invalidCredentials
      }
      return
    }
    throw CasClientError.redirectLimit
  }

  private func activateUc() async throws {
    // API.md §1.7：激活请求也属于认证链，沿用不自动跳转的会话。
    var url = ucActivationURL
    for hop in 0...10 {
      let (data, response) = try await send(URLRequest(url: url))
      if (300..<400).contains(response.statusCode) {
        guard hop < 10 else { throw CasClientError.redirectLimit }
        url = try redirectURL(from: response, relativeTo: url)
        continue
      }
      if (400..<500).contains(response.statusCode) {
        let html = String(data: data, encoding: .utf8)
        if response.statusCode == 483
          || (html.map(CasPageParser.isAccessPolicyDenied) ?? false) {
          throw CasClientError.accessPolicyDenied
        }
        throw CasClientError.unexpectedStatus(response.statusCode)
      }
      guard response.statusCode == 200 else { throw CasClientError.unexpectedStatus(response.statusCode) }
      return
    }
    throw CasClientError.redirectLimit
  }

  /// API.md §1.8：仅 code 为整数 0 且 data 非空算成功。5xx 不清本地会话。
  func validateSession() async throws -> UserData {
    var request = URLRequest(url: ucStatusURL)
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    let (data, response) = try await send(request)
    if response.statusCode == 483
      || ((400..<500).contains(response.statusCode)
        && (String(data: data, encoding: .utf8).map(CasPageParser.isAccessPolicyDenied) ?? false)) {
      throw CasClientError.accessPolicyDenied
    }
    if (500..<600).contains(response.statusCode) { throw CasClientError.unexpectedStatus(response.statusCode) }
    guard response.statusCode == 200,
          let status = try? JSONDecoder().decode(UcStatus.self, from: data),
          status.code == 0,
          let user = status.data,
          !user.schoolid.isEmpty,
          !user.name.isEmpty
    else { throw CasClientError.sessionInvalid }
    return UserData(schoolid: user.schoolid, name: user.name)
  }

  /// API.md §1.9：上游登出失败也由调用方清理本地状态。
  func logout() async throws {
    let (_, response) = try await send(URLRequest(url: logoutURL))
    guard (200..<400).contains(response.statusCode) else {
      throw CasClientError.unexpectedStatus(response.statusCode)
    }
  }

  private func redirectLocation(_ response: HTTPURLResponse) -> URL? {
    guard let value = response.value(forHTTPHeaderField: "Location") else { return nil }
    return URL(string: value)
  }

  private func redactedURL(_ url: URL?) -> String {
    guard let url else { return "nil" }
    let queryKeys = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .map(\.name)
      .joined(separator: ",") ?? ""
    return "\(url.host ?? "nil")\(url.path)\(queryKeys.isEmpty ? "" : "?[\(queryKeys)]")"
  }

  private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      let usesStandardAuthSession = session === APIClient.shared.noRedirectSession
      let globalRouteRequiresWebVPN = !ignoreGlobalRoute
        && EffectiveUpstreamRoute.current == .webVPN
        && usesStandardAuthSession
      let shouldUseWebVPN = routeThroughWebVPN || globalRouteRequiresWebVPN
      lastSendUsedWebVPN = shouldUseWebVPN
      var prepared = request
      if prepared.value(forHTTPHeaderField: "User-Agent") == nil {
        prepared.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
      }
      if prepared.value(forHTTPHeaderField: "Accept-Language") == nil {
        prepared.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
      }
      let activeSession: URLSession
      let routedRequest: URLRequest
      if shouldUseWebVPN, let url = prepared.url {
        var copy = prepared
        copy.url = try WebVPNRouter.wrap(url)
        routedRequest = copy
        if let webVPNSession {
          activeSession = webVPNSession
        } else if routeThroughWebVPN && session !== APIClient.shared.noRedirectSession {
          activeSession = session
        } else {
          activeSession = APIClient.shared.webVPNNoRedirectSession
        }
      } else {
        routedRequest = prepared
        activeSession = session
      }
      let (data, response) = try await activeSession.data(for: routedRequest)
      guard let http = response as? HTTPURLResponse else { throw CasClientError.invalidResponse }
      return (data, http)
    } catch {
      AppLog.network.error("认证请求失败：\(error.localizedDescription, privacy: .private)")
      throw error
    }
  }

  private func redirectURL(from response: HTTPURLResponse, relativeTo url: URL) throws -> URL {
    guard let location = response.value(forHTTPHeaderField: "Location"),
          let target = WebVPNRouter.resolveRedirect(location, relativeTo: response.url.flatMap(WebVPNRouter.unwrap) ?? url),
          target.scheme == "https"
    else { throw CasClientError.missingRedirectLocation }
    return target
  }
}

private struct UcStatus: Decodable {
  let code: Int
  let data: UcUser?
}

private struct UcUser: Decodable {
  let schoolid: String
  let name: String
}

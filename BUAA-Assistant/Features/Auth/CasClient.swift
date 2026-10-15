import Foundation

/// 登录页及其原始 HTML。下一步提交表单时需要从同一页面收集隐藏字段。
struct LoginPageInfo {
  let execution: String
  let captcha: CaptchaChallenge?
  let html: String
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
    }
  }
}

/// CAS 认证链。登录请求使用不自动跟随重定向的会话（API.md §1.2）。
actor CasClient: AuthSessionClient {
  private let session: URLSession
  private let loginURL = URL(string: "https://sso.buaa.edu.cn/login")!
  private let ucActivationURL = URL(string: "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin")!
  private let ucStatusURL = URL(string: "https://uc.buaa.edu.cn/api/uc/status")!
  private let logoutURL = URL(string: "https://sso.buaa.edu.cn/logout")!

  init(session: URLSession = APIClient.shared.noRedirectSession) {
    self.session = session
  }

  func fetchLoginPage() async throws -> LoginPageResult {
    var request = URLRequest(url: loginURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 30

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      AppLog.network.error("获取 CAS 登录页失败：\(error.localizedDescription, privacy: .private)")
      throw error
    }
    guard let http = response as? HTTPURLResponse else {
      AppLog.auth.error("CAS 登录页返回非 HTTP 响应")
      throw CasClientError.invalidResponse
    }

    if (300..<400).contains(http.statusCode) {
      guard let location = http.value(forHTTPHeaderField: "Location"),
            let redirectURL = URL(string: location, relativeTo: loginURL)?.absoluteURL,
            redirectURL.scheme == "https"
      else {
        AppLog.auth.error("CAS 登录页跳转缺少有效的 HTTPS Location")
        throw CasClientError.missingRedirectLocation
      }
      AppLog.auth.info("CAS 登录页返回跳转，已有会话")
      return .existingSession(redirectURL: redirectURL)
    }

    guard http.statusCode == 200 else {
      AppLog.auth.error("CAS 登录页返回 HTTP \(http.statusCode)")
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
    AppLog.auth.info("CAS 登录页已获取，需验证码：\(captcha != nil)")
    return .loginPage(LoginPageInfo(execution: execution, captcha: captcha, html: html))
  }

  /// 使用同一张登录页提交，避免 execution/验证码因重新获取页面而失效。
  func login(page: LoginPageInfo, username: String, password: String, captchaText: String?) async throws -> UserData {
    if page.captcha != nil && (captchaText?.isEmpty ?? true) {
      throw CasClientError.captchaRequired
    }
    var fields = CasFormParser.loginFields(
      html: page.html, username: username, password: password, captchaText: captchaText
    )
    fields.removeAll { $0.0 == "execution" }
    fields.append(("execution", page.execution))
    var request = URLRequest(url: loginURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = CasFormParser.encodedBody(fields)
    let (data, response) = try await send(request)
    try await followRedirectsAndCheckError(data: data, response: response, startingAt: loginURL)
    try await activateUc()
    return try await validateSession()
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
      if let message = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "exception.message" })?.value,
        !message.isEmpty {
        throw CasClientError.preLoginTip(message)
      }
      if response.statusCode == 401 { throw CasClientError.invalidCredentials }
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
        request.httpBody = CasFormParser.encodedBody([("execution", execution), ("_eventId", "ignoreAndContinue")])
        let next = try await send(request)
        currentURL = loginURL
        data = next.0
        response = next.1
        continue
      }
      if let error = CasPageParser.extractErrorText(from: html) { throw CasClientError.preLoginTip(error) }
      if CasPageParser.extractExecution(from: html) != nil { throw CasClientError.invalidCredentials }
      return
    }
    throw CasClientError.redirectLimit
  }

  private func activateUc() async throws {
    // API.md §1.7：激活请求也属于认证链，沿用不自动跳转的会话。
    var url = ucActivationURL
    for hop in 0...10 {
      let (_, response) = try await send(URLRequest(url: url))
      if (300..<400).contains(response.statusCode) {
        guard hop < 10 else { throw CasClientError.redirectLimit }
        url = try redirectURL(from: response, relativeTo: url)
        continue
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

  private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw CasClientError.invalidResponse }
      return (data, http)
    } catch {
      AppLog.network.error("认证请求失败：\(error.localizedDescription, privacy: .private)")
      throw error
    }
  }

  private func redirectURL(from response: HTTPURLResponse, relativeTo url: URL) throws -> URL {
    guard let location = response.value(forHTTPHeaderField: "Location"),
          let target = URL(string: location, relativeTo: url)?.absoluteURL,
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

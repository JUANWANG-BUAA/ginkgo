import Foundation

/// 直连上游的 HTTP 客户端骨架。
/// Cookie 由系统 HTTPCookieStorage 自动管理（含 HttpOnly 的 CASTGC，
/// 禁止手拼 Cookie 头，见 API.md §9）。
///
/// 两个会话的分工（API.md §0.3）：
/// - `session`：业务数据请求，自动跟随重定向；
/// - `noRedirectSession`：认证链请求，重定向必须手动逐跳处理（API.md §1.6），
///   以便每一跳检查错误特征与 Location。
///
/// 请求方法（get/postForm 等）与错误映射在 ROADMAP Step 1 按需补充，
/// 骨架阶段只保留会话本身。
final class APIClient: @unchecked Sendable {
  static let shared = APIClient()

  let session: URLSession
  let noRedirectSession: URLSession
  let webVPNSession: URLSession
  let webVPNNoRedirectSession: URLSession
  let webVPNCookieStorage: HTTPCookieStorage
  private let noRedirectDelegate: NoRedirectDelegate

  private init() {
    self.session = URLSession(configuration: .default)
    let delegate = NoRedirectDelegate()
    self.noRedirectDelegate = delegate
    self.noRedirectSession = URLSession(
      configuration: .default,
      delegate: delegate,
      delegateQueue: nil
    )

    // UBAA keeps WebVPN cookies in a mode-scoped store. Do the same here so a
    // gateway login cannot be confused with (or overwritten by) direct SSO cookies.
    let webVPNConfiguration = URLSessionConfiguration.ephemeral
    let webVPNCookies = WebVPNCookieStore.storage
    webVPNConfiguration.httpCookieStorage = webVPNCookies
    webVPNConfiguration.httpShouldSetCookies = true
    webVPNConfiguration.httpCookieAcceptPolicy = .always
    self.webVPNCookieStorage = webVPNCookies
    self.webVPNSession = URLSession(configuration: webVPNConfiguration)

    let webVPNNoRedirectConfiguration = URLSessionConfiguration.ephemeral
    webVPNNoRedirectConfiguration.httpCookieStorage = webVPNCookies
    webVPNNoRedirectConfiguration.httpShouldSetCookies = true
    webVPNNoRedirectConfiguration.httpCookieAcceptPolicy = .always
    self.webVPNNoRedirectSession = URLSession(
      configuration: webVPNNoRedirectConfiguration,
      delegate: delegate,
      delegateQueue: nil
    )
  }
}

/// 阻止自动重定向的会话代理：认证链必须手动逐跳跟随（API.md §1.6）。
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

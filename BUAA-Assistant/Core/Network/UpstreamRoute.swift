import Foundation

/// 用户可选的校园服务网络路线。
///
/// `.automatic` 会先尝试直连；如果学校 WAF 明确返回访问策略拦截，
/// 登录状态机会把偏好切换为 `.webVPN` 并重试。用户之后可以在设置中改回。
enum UpstreamRoutePreference: String, CaseIterable, Identifiable {
  case automatic
  case direct
  case webVPN = "webvpn"

  static let storageKey = "upstreamRoutePreference"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .automatic: "自动"
    case .direct: "直连"
    case .webVPN: "WebVPN"
    }
  }

  var detail: String {
    switch self {
    case .automatic:
      "推荐：优先直连；检测到学校访问策略拦截时自动切换 WebVPN 并重试。"
    case .direct:
      "直接访问学校服务，适合校园网或未被限制的网络。"
    case .webVPN:
      "通过 d.buaa.edu.cn 网关访问，适合校外网络或公网 IP 被限制时。"
    }
  }

  static func current(in defaults: UserDefaults = .standard) -> UpstreamRoutePreference {
    defaults
      .string(forKey: storageKey)
      .flatMap(UpstreamRoutePreference.init(rawValue:))
      ?? .automatic
  }

  static var current: UpstreamRoutePreference { current() }

  @discardableResult
  static func activateAutomaticWebVPNFallback(in defaults: UserDefaults = .standard) -> Bool {
    guard current(in: defaults) == .automatic else { return false }
    defaults.set(UpstreamRoutePreference.webVPN.rawValue, forKey: storageKey)
    NotificationCenter.default.post(name: .upstreamRouteDidChange, object: nil)
    return true
  }
}

extension Notification.Name {
  static let upstreamRouteDidChange = Notification.Name("GinkgoUpstreamRouteDidChange")
}

/// 一次具体请求实际应采用的路线。
enum EffectiveUpstreamRoute: Equatable {
  case direct
  case webVPN

  static var current: EffectiveUpstreamRoute {
    UpstreamRoutePreference.current == .webVPN ? .webVPN : .direct
  }
}

/// WebVPN 会话 Cookie 与普通直连 Cookie 隔离保存。
enum WebVPNCookieStore {
  static let storage: HTTPCookieStorage = {
    guard let storage = URLSessionConfiguration.ephemeral.httpCookieStorage else {
      preconditionFailure("Ephemeral URLSession must provide an isolated cookie store")
    }
    return storage
  }()
}

/// 纯请求/响应映射，便于单元测试覆盖，也供 URLProtocol 统一复用。
enum UpstreamRequestRouting {
  static func shouldUseWebVPN(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    guard host == "buaa.edu.cn" || host.hasSuffix(".buaa.edu.cn") else { return false }
    return host != "d.buaa.edu.cn"
  }

  static func route(_ request: URLRequest, using route: EffectiveUpstreamRoute) throws -> URLRequest {
    guard route == .webVPN else { return request }
    var routed = request
    // Cookie 必须由目标会话按网关域名重新注入，不能把直连 Cookie 带到 WebVPN。
    routed.setValue(nil, forHTTPHeaderField: "Cookie")
    guard let url = request.url, shouldUseWebVPN(url) else { return routed }

    routed.url = try WebVPNRouter.wrap(url)
    for header in ["Referer", "Origin"] {
      guard let value = request.value(forHTTPHeaderField: header),
            let upstream = URL(string: value),
            shouldUseWebVPN(upstream),
            let wrapped = try? WebVPNRouter.wrap(upstream) else { continue }
      routed.setValue(wrapped.absoluteString, forHTTPHeaderField: header)
    }
    return routed
  }

  static func normalize(
    response: HTTPURLResponse,
    originalURL: URL
  ) -> HTTPURLResponse {
    let responseURL = response.url.flatMap(WebVPNRouter.unwrap) ?? originalURL
    var headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
      guard let key = item.key as? String else { return }
      result[key] = String(describing: item.value)
    }

    if let location = response.value(forHTTPHeaderField: "Location"),
       let resolved = WebVPNRouter.resolveRedirect(location, relativeTo: responseURL),
       WebVPNRouter.isGatewayURL(resolved) == false {
      headers["Location"] = resolved.absoluteString
    }

    return HTTPURLResponse(
      url: responseURL,
      statusCode: response.statusCode,
      httpVersion: nil,
      headerFields: headers
    ) ?? response
  }
}

extension URLSession {
  /// 按当前网络路线发送请求。
  ///
  /// WebVPN 模式显式把北航 URL 包装到 `d.buaa.edu.cn`，并使用独立的 WebVPN
  /// Cookie 会话。认证链通过 `noRedirect` 参数保持逐跳处理语义。
  func routedData(
    for request: URLRequest,
    noRedirect: Bool = false,
    allowWebVPN: Bool? = nil
  ) async throws -> (Data, URLResponse) {
    let appOwnedSession = self === APIClient.shared.session
      || self === APIClient.shared.noRedirectSession
      || self === APIClient.shared.webVPNSession
      || self === APIClient.shared.webVPNNoRedirectSession
    let webVPNAllowed = allowWebVPN ?? appOwnedSession
    guard webVPNAllowed, EffectiveUpstreamRoute.current == .webVPN else {
      return try await data(for: request)
    }

    let route: EffectiveUpstreamRoute = .webVPN
    let routed = try UpstreamRequestRouting.route(request, using: route)
    let target = noRedirect
      ? APIClient.shared.webVPNNoRedirectSession
      : APIClient.shared.webVPNSession
    let (data, response) = try await target.data(for: routed)
    if let http = response as? HTTPURLResponse {
      return (data, UpstreamRequestRouting.normalize(response: http, originalURL: request.url ?? http.url ?? routed.url ?? URL(fileURLWithPath: "/")))
    }
    return (data, response)
  }

  func routedData(
    from url: URL,
    noRedirect: Bool = false,
    allowWebVPN: Bool? = nil
  ) async throws -> (Data, URLResponse) {
    try await routedData(
      for: URLRequest(url: url),
      noRedirect: noRedirect,
      allowWebVPN: allowWebVPN
    )
  }


}

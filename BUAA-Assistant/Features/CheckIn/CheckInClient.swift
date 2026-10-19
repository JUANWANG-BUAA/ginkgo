import Foundation

protocol CheckInServing {
  func loadToday(account: String) async throws -> CheckInSnapshot
  func loadOnDate(account: String, date: Date) async throws -> CheckInSnapshot
  func performSignIn(account: String, courseID: String) async throws -> CheckInActionResult
}

protocol CheckInWebVPNRouting {
  func setWebVPNRouteEnabled(_ enabled: Bool) async
}

/// iclass status client. The short-lived iclass session stays in memory; writes are always user-triggered.
actor CheckInClient: CheckInServing, CheckInWebVPNRouting {
  private enum RequestStage: String {
    case ssoRedirect = "sso_redirect"
    case appLogin = "app_login"
    case courseSchedule = "course_schedule"
    case serverTimestamp = "server_timestamp"
    case signIn = "sign_in"
  }

  private struct IClassSession {
    let userID: String
    let sessionID: String
  }

  private struct CourseSessionKey: Hashable {
    let courseName: String
    let beginsAt: String
    let endsAt: String
  }

  private struct DisjointSet {
    private var parents: [Int]

    init(count: Int) {
      parents = Array(0..<count)
    }

    mutating func root(of index: Int) -> Int {
      var root = index
      while parents[root] != root { root = parents[root] }

      var current = index
      while parents[current] != current {
        let next = parents[current]
        parents[current] = root
        current = next
      }
      return root
    }

    mutating func join(_ lhs: Int, _ rhs: Int) {
      let leftRoot = root(of: lhs)
      let rightRoot = root(of: rhs)
      if leftRoot != rightRoot { parents[rightRoot] = leftRoot }
    }
  }

  private enum Route {
    case direct
    case webVPN
  }

  private let session: URLSession
  private let noRedirectSession: URLSession
  private let webVPNSession: URLSession
  private let webVPNNoRedirectSession: URLSession
  private var cachedAccount: String?
  private var iclassSession: IClassSession?
  private var route = Route.direct
  private var prefersWebVPN = false

  init(
    session: URLSession = APIClient.shared.session,
    noRedirectSession: URLSession = APIClient.shared.noRedirectSession,
    webVPNSession: URLSession = APIClient.shared.webVPNSession,
    webVPNNoRedirectSession: URLSession = APIClient.shared.webVPNNoRedirectSession
  ) {
    self.session = session
    self.noRedirectSession = noRedirectSession
    self.webVPNSession = webVPNSession
    self.webVPNNoRedirectSession = webVPNNoRedirectSession
  }

  func loadToday(account: String) async throws -> CheckInSnapshot {
    prepareAccount(account)
    return try await loadOnDate(schoolDate: Self.schoolDateString(from: Date()), allowSessionRefresh: true)
  }

  func loadOnDate(account: String, date: Date) async throws -> CheckInSnapshot {
    prepareAccount(account)
    return try await loadOnDate(schoolDate: Self.schoolDateString(from: date), allowSessionRefresh: true)
  }

  func setWebVPNRouteEnabled(_ enabled: Bool) async {
    prefersWebVPN = enabled
    route = enabled ? .webVPN : .direct
    iclassSession = nil
    AppLog.network.notice("iclass route selected route=\(enabled ? "webvpn" : "direct", privacy: .public) reason=webvpn_session_state")
  }

  func performSignIn(account: String, courseID: String) async throws -> CheckInActionResult {
    prepareAccount(account)
    let activeSession = try await currentSession()

    let timestampURL = URL(string: "https://iclass.buaa.edu.cn:8347/app/common/get_timestamp.action")!
    var timestampRequest = URLRequest(url: timestampURL)
    timestampRequest.timeoutInterval = 20
    let timestampData: Data
    let timestampResponse: URLResponse
    do {
      (timestampData, timestampResponse) = try await requestData(
        for: timestampRequest, using: session, stage: .serverTimestamp
      )
    } catch {
      AppLog.network.error("iclass request failed stage=server_timestamp outcome=transport_failure")
      return CheckInActionResult(succeeded: false, message: "暂时无法取得学校服务器时间，未提交签到")
    }
    guard let timestampHTTP = timestampResponse as? HTTPURLResponse,
          timestampHTTP.statusCode == 200 else {
      AppLog.network.error("iclass request failed stage=server_timestamp outcome=invalid_http_response")
      return CheckInActionResult(succeeded: false, message: "暂时无法取得学校服务器时间，未提交签到")
    }
    guard let timestampPayload = try? Self.jsonObject(from: timestampData),
          let timestamp = Self.string(timestampPayload["timestamp"]) else {
      AppLog.network.error("iclass request failed stage=server_timestamp reason=unrecognized_response_format")
      return CheckInActionResult(
        succeeded: false,
        message: "学校服务器时间响应格式无法识别，接口可能已调整；未提交签到",
        responseFormatUnrecognized: true
      )
    }

    var components = URLComponents(string: "https://iclass.buaa.edu.cn:8347/app/course/stu_scan_sign.action")!
    components.queryItems = [
      URLQueryItem(name: "courseSchedId", value: courseID),
      URLQueryItem(name: "timestamp", value: timestamp)
    ]
    if let query = components.percentEncodedQuery {
      components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
    }
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue(activeSession.sessionID, forHTTPHeaderField: "sessionId")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = "id=\(activeSession.userID)".data(using: .utf8)

    let (data, response) = try await requestData(for: request, using: session, stage: .signIn)
    guard let http = response as? HTTPURLResponse else {
      AppLog.network.error("iclass request failed stage=sign_in outcome=non_http_response")
      return CheckInActionResult(succeeded: false, message: "签到结果尚未确认；正在回查课程状态…", requiresStatusRefresh: true)
    }
    if http.statusCode != 200 {
      AppLog.network.error("iclass request failed stage=sign_in http_status=\(http.statusCode) outcome=unconfirmed")
      return CheckInActionResult(succeeded: false, message: "签到结果尚未确认；正在回查课程状态…", requiresStatusRefresh: true)
    }
    let responseText = String(data: data.prefix(5000), encoding: .utf8) ?? ""
    if CasPageParser.isLoginRedirect(url: http.url, data: data)
        || responseText.localizedCaseInsensitiveContains("统一身份认证") {
      AppLog.network.error("iclass request failed stage=sign_in outcome=authentication_response_unconfirmed")
      return CheckInActionResult(succeeded: false, message: "签到会话可能已失效；结果尚未确认，正在回查课程状态…", requiresStatusRefresh: true)
    }
    guard let payload = try? Self.jsonObject(from: data) else {
      AppLog.network.error("iclass request failed stage=sign_in reason=unrecognized_response_format")
      return CheckInActionResult(
        succeeded: false,
        message: "签到响应格式无法识别，接口可能已调整；正在回查课程状态…",
        requiresStatusRefresh: true,
        responseFormatUnrecognized: true
      )
    }
    guard Self.string(payload["STATUS"]) != nil else {
      AppLog.network.error("iclass request failed stage=sign_in reason=missing_business_status")
      return CheckInActionResult(
        succeeded: false,
        message: "签到响应缺少状态字段，接口可能已调整；正在回查课程状态…",
        requiresStatusRefresh: true,
        responseFormatUnrecognized: true
      )
    }

    let result = payload["result"] as? [String: Any]
    if Self.isSuccessful(payload["STATUS"]), Self.string(result?["stuSignStatus"]) == nil {
      AppLog.network.error("iclass request failed stage=sign_in reason=missing_confirmation_status")
      return CheckInActionResult(
        succeeded: false,
        message: "签到响应缺少确认状态，接口可能已调整；正在回查课程状态…",
        requiresStatusRefresh: true,
        responseFormatUnrecognized: true
      )
    }
    let succeeded = Self.isSuccessful(payload["STATUS"]) && Self.string(result?["stuSignStatus"]) == "1"
    let rawMessage = Self.string(payload["ERRMSG"])
    let alreadySigned = rawMessage?.contains("已签到") == true
    let message = succeeded
      ? "学校已返回签到成功，正在回查课程状态…"
      : Self.signInFailureMessage(rawMessage)
    AppLog.network.info("iclass request completed stage=sign_in outcome=\(succeeded ? "confirmed" : "rejected", privacy: .public)")
    return CheckInActionResult(succeeded: succeeded, message: message, requiresStatusRefresh: alreadySigned)
  }

  private func prepareAccount(_ account: String) {
    if cachedAccount != account {
      cachedAccount = account
      iclassSession = nil
      route = prefersWebVPN ? .webVPN : .direct
      AppLog.network.info("iclass session cache reset reason=account_changed")
    }
  }

  private static func signInFailureMessage(_ rawMessage: String?) -> String {
    guard let rawMessage, !rawMessage.isEmpty else { return "签到未成功，学校未确认提交" }
    if rawMessage.contains("已签到") { return "这门课已经签到过了；正在回查状态" }
    if rawMessage.contains("未开始") { return "签到尚未开始，请在签到开放后重试" }
    if rawMessage.contains("不是上课时间") { return "当前不在可签到时间，请核对课程时间" }
    if rawMessage.contains("已结束") { return "本次签到已结束" }
    if rawMessage.contains("范围") { return "当前不在允许的签到范围内" }
    if rawMessage.contains("登录") { return "学校登录态已失效，请重新登录后重试" }
    return "签到未成功：\(rawMessage)"
  }

  private func loadOnDate(schoolDate: String, allowSessionRefresh: Bool) async throws -> CheckInSnapshot {
    let activeSession = try await currentSession()
    var components = URLComponents(string: "https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action")!
    components.queryItems = [
      URLQueryItem(name: "id", value: activeSession.userID),
      URLQueryItem(name: "dateStr", value: schoolDate)
    ]
    if let query = components.percentEncodedQuery {
      components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
    }
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 20
    request.setValue(activeSession.sessionID, forHTTPHeaderField: "sessionId")

    let (data, response) = try await requestData(for: request, using: session, stage: .courseSchedule)
    guard let http = response as? HTTPURLResponse else {
      logInvalidHTTPResponse(stage: .courseSchedule)
      throw CheckInError.unavailable
    }
    if http.statusCode == 401 || http.url?.host == "sso.buaa.edu.cn" {
      if allowSessionRefresh {
        iclassSession = nil
        AppLog.network.notice("iclass session refresh stage=course_schedule reason=auth_redirect")
        return try await loadOnDate(schoolDate: schoolDate, allowSessionRefresh: false)
      }
      iclassSession = nil
      logHTTPResponse(stage: .courseSchedule, statusCode: http.statusCode, outcome: "session_expired")
      throw CheckInError.sessionExpired
    }
    guard http.statusCode == 200 else {
      logHTTPResponse(stage: .courseSchedule, statusCode: http.statusCode, outcome: "http_failure")
      throw CheckInError.unavailable
    }

    let payload: [String: Any]
    do {
      payload = try Self.jsonObject(from: data)
    } catch {
      AppLog.network.error("iclass request failed stage=course_schedule reason=invalid_json")
      throw error
    }
    if Self.string(payload["STATUS"]) == "2" {
      AppLog.network.info("iclass request succeeded stage=course_schedule outcome=empty_schedule status=2")
      return CheckInSnapshot(items: [], fetchedAt: Date(), schoolDate: schoolDate)
    }
    guard Self.string(payload["STATUS"]) != nil else {
      AppLog.network.error("iclass request failed stage=app_login reason=missing_business_status")
      throw CheckInError.invalidResponse
    }
    guard Self.isSuccessful(payload["STATUS"]) else {
      if payload["STATUS"] != nil {
        iclassSession = nil
        if allowSessionRefresh {
          AppLog.network.notice("iclass session refresh stage=course_schedule reason=business_status_rejected")
          return try await loadOnDate(schoolDate: schoolDate, allowSessionRefresh: false)
        }
      }
      AppLog.network.error(
        "iclass request failed stage=course_schedule reason=unexpected_payload status=\(Self.safeStatus(payload["STATUS"]), privacy: .public)"
      )
      throw payload["STATUS"] == nil ? CheckInError.invalidResponse : CheckInError.serviceSessionRejected
    }
    guard let records = payload["result"] as? [[String: Any]] else {
      AppLog.network.error("iclass request failed stage=course_schedule reason=missing_result")
      throw CheckInError.invalidResponse
    }


    let parsedCandidates = try records.map { record -> CheckInCandidate in
      guard let id = Self.string(record["id"]),
            let name = Self.string(record["courseName"]),
            let begin = Self.string(record["classBeginTime"]),
            let end = Self.string(record["classEndTime"]),
            Self.string(record["signStatus"]) != nil else {
        AppLog.network.error("iclass request failed stage=course_schedule reason=missing_course_fields")
        throw CheckInError.invalidResponse
      }
      return CheckInCandidate(
        id: id,
        courseID: Self.string(record["courseId"]),
        courseNum: Self.string(record["courseNum"]),
        courseName: name,
        beginsAt: begin,
        endsAt: end,
        status: CheckInStatus(rawValue: Self.integer(record["signStatus"])),
        teacherName: Self.string(record["teacherName"]),
        classroomName: Self.string(record["classroomName"])
      )
    }

    let sessionKeys = parsedCandidates.map(Self.sessionKey(for:))
    var groups = DisjointSet(count: parsedCandidates.count)
    var firstIndexByID: [String: Int] = [:]
    var firstIndexBySession: [CourseSessionKey: Int] = [:]
    for index in parsedCandidates.indices {
      let candidate = parsedCandidates[index]
      if let firstIndex = firstIndexByID[candidate.id] {
        groups.join(index, firstIndex)
      } else {
        firstIndexByID[candidate.id] = index
      }
      if let firstIndex = firstIndexBySession[sessionKeys[index]] {
        groups.join(index, firstIndex)
      } else {
        firstIndexBySession[sessionKeys[index]] = index
      }
    }

    var groupedIndices: [[Int]] = []
    var positionByRoot: [Int: Int] = [:]
    for index in parsedCandidates.indices {
      let root = groups.root(of: index)
      if let position = positionByRoot[root] {
        groupedIndices[position].append(index)
      } else {
        positionByRoot[root] = groupedIndices.count
        groupedIndices.append([index])
      }
    }

    var conflictingRecordCount = 0
    let items = groupedIndices.map { indices -> CheckInItem in
      let first = parsedCandidates[indices[0]]
      let firstKey = sessionKeys[indices[0]]
      let hasSessionConflict = indices.contains { sessionKeys[$0] != firstKey }
      let hasStatusConflict = indices.contains { parsedCandidates[$0].status != first.status }
      let hasConflict = hasSessionConflict || hasStatusConflict
      if hasConflict { conflictingRecordCount += 1 }

      let candidates = indices.map { parsedCandidates[$0] }
        .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
      let uniqueIDs = Set(candidates.map(\.id))
      return CheckInItem(
        id: uniqueIDs.sorted().first ?? first.id,
        courseName: first.courseName,
        beginsAt: first.beginsAt,
        endsAt: first.endsAt,
        status: hasConflict ? .unknown : first.status,
        signInAllowed: uniqueIDs.count == 1 && !hasConflict,
        mergedRecordCount: candidates.count,
        candidates: candidates
      )
    }
    let parsedCandidateCount = parsedCandidates.count
    let duplicateRecordCount = parsedCandidateCount - items.count
    let sortedItems = items.sorted { $0.beginsAt < $1.beginsAt }
    if duplicateRecordCount > 0 {
      AppLog.network.notice(
        "iclass schedule normalized duplicate_record_count=\(duplicateRecordCount) conflicting_record_count=\(conflictingRecordCount)"
      )
    }
    AppLog.network.info("iclass request succeeded stage=course_schedule course_count=\(sortedItems.count)")
    return CheckInSnapshot(items: sortedItems, fetchedAt: Date(), schoolDate: schoolDate)
  }

  private static func sessionKey(for candidate: CheckInCandidate) -> CourseSessionKey {
    CourseSessionKey(
      courseName: normalizedSessionValue(candidate.courseName),
      beginsAt: normalizedSessionValue(candidate.beginsAt),
      endsAt: normalizedSessionValue(candidate.endsAt)
    )
  }

  private static func sessionKey(for item: CheckInItem) -> CourseSessionKey {
    CourseSessionKey(
      courseName: normalizedSessionValue(item.courseName),
      beginsAt: normalizedSessionValue(item.beginsAt),
      endsAt: normalizedSessionValue(item.endsAt)
    )
  }

  private static func normalizedSessionValue(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping
      .replacingOccurrences(of: "：", with: ":")
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
      .lowercased()
  }

  private func currentSession() async throws -> IClassSession {
    if let iclassSession { return iclassSession }
    let loginName = try await resolveLoginName()
    var components = URLComponents(string: "https://iclass.buaa.edu.cn:8347/app/user/login.action")!
    components.queryItems = [
      URLQueryItem(name: "password", value: ""),
      URLQueryItem(name: "phone", value: loginName),
      URLQueryItem(name: "userLevel", value: "1"),
      URLQueryItem(name: "verificationType", value: "2"),
      URLQueryItem(name: "verificationUrl", value: "")
    ]
    if let query = components.percentEncodedQuery {
      components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
    }
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 20
    let (data, response) = try await requestData(for: request, using: session, stage: .appLogin)
    guard let http = response as? HTTPURLResponse else {
      logInvalidHTTPResponse(stage: .appLogin)
      throw CheckInError.unavailable
    }
    guard http.statusCode == 200 else {
      logHTTPResponse(stage: .appLogin, statusCode: http.statusCode, outcome: "http_failure")
      throw CheckInError.unavailable
    }
    let payload: [String: Any]
    do {
      payload = try Self.jsonObject(from: data)
    } catch {
      AppLog.network.error("iclass request failed stage=app_login reason=invalid_json")
      throw error
    }
    guard Self.isSuccessful(payload["STATUS"]) else {
      AppLog.network.error(
        "iclass request failed stage=app_login reason=login_rejected status=\(Self.safeStatus(payload["STATUS"]), privacy: .public)"
      )
      throw CheckInError.loginNameUnavailable
    }
    guard let result = payload["result"] as? [String: Any],
          let userID = Self.string(result["id"]), let sessionID = Self.string(result["sessionId"]) else {
      AppLog.network.error("iclass request failed stage=app_login reason=missing_session_fields")
      throw CheckInError.invalidResponse
    }
    let newSession = IClassSession(userID: userID, sessionID: sessionID)
    iclassSession = newSession
    AppLog.network.info("iclass request succeeded stage=app_login")
    return newSession
  }

  private func resolveLoginName() async throws -> String {
    var currentURL = URL(string: "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter")!
    var redirectTrace: [String] = []
    for hop in 0..<8 {
      var request = URLRequest(url: currentURL)
      request.timeoutInterval = 20
      let (data, response) = try await requestData(for: request, using: noRedirectSession, stage: .ssoRedirect)
      guard let http = response as? HTTPURLResponse else {
        logInvalidHTTPResponse(stage: .ssoRedirect)
        throw CheckInError.unavailable
      }
      let upstreamResponseURL = response.url.flatMap(WebVPNRouter.unwrap)
      if let value = Self.loginName(in: upstreamResponseURL) {
        AppLog.network.info("iclass request succeeded stage=sso_redirect hop=\(hop) login_name_source=response_url")
        return value
      }
      if http.statusCode == 200, WebVPNRouter.isGatewayURL(response.url) {
        let responseUpstreamURL = response.url.flatMap(WebVPNRouter.unwrap)
        let upstreamService: String
        if responseUpstreamURL?.host == "sso.buaa.edu.cn", responseUpstreamURL?.path == "/login" {
          upstreamService = "cas_login"
        } else if responseUpstreamURL?.host == "iclass.buaa.edu.cn", responseUpstreamURL?.port == 8346 {
          upstreamService = "iclass_signin"
        } else {
          upstreamService = "other"
        }
        let pageHTML = String(data: data, encoding: .utf8) ?? ""
        let casFormPresent = CasPageParser.extractExecution(from: pageHTML) != nil
        let gatewayPageShape = Self.gatewayPageShape(pageHTML)
        let gatewayURL = try? WebVPNRouter.wrap(currentURL)
        let gatewayCookieCount = gatewayURL.flatMap {
          webVPNNoRedirectSession.configuration.httpCookieStorage?.cookies(for: $0)?.count
        } ?? 0
        let gatewayCookieScopeSummary = Self.gatewayCookieScopeSummary(
          storage: webVPNNoRedirectSession.configuration.httpCookieStorage,
          checkInURL: try? WebVPNRouter.wrap(URL(string: "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter")!),
          casURL: gatewayURL
        )
        AppLog.network.error(
          "iclass request failed stage=sso_redirect http_status=200 outcome=webvpn_gateway_page_without_login_name upstream_service=\(upstreamService, privacy: .public) cas_form=\(casFormPresent) gateway_page_shape=\(gatewayPageShape, privacy: .public) gateway_cookie_count=\(gatewayCookieCount) gateway_cookie_scopes=\(gatewayCookieScopeSummary, privacy: .public) redirect_trace=\(redirectTrace.joined(separator: ","), privacy: .public)"
        )
        throw CheckInError.webVPNUnavailable
      }

      guard (300..<400).contains(http.statusCode) else {
        logHTTPResponse(stage: .ssoRedirect, statusCode: http.statusCode, outcome: "login_name_not_found")
        if http.statusCode == 200 {
          if upstreamResponseURL?.host == "sso.buaa.edu.cn", upstreamResponseURL?.path == "/login" {
            throw CheckInError.sessionExpired
          }
          AppLog.network.error("iclass request failed stage=sso_redirect http_status=200 outcome=unexpected_landing_page")
          throw CheckInError.loginNameUnavailable
        }
        throw CheckInError.loginNameUnavailable
      }
      guard let location = http.value(forHTTPHeaderField: "Location") else {
        logHTTPResponse(stage: .ssoRedirect, statusCode: http.statusCode, outcome: "redirect_missing_location")
        throw CheckInError.loginNameUnavailable
      }
      guard let nextURL = WebVPNRouter.resolveRedirect(
        location,
        relativeTo: upstreamResponseURL ?? currentURL
      ) else {
        AppLog.network.error(
          "iclass request failed stage=sso_redirect http_status=\(http.statusCode) outcome=redirect_unresolvable shape=\(Self.redirectShape(location), privacy: .public)"
        )
        throw CheckInError.loginNameUnavailable
      }
      guard hop < 7 else {
        logHTTPResponse(stage: .ssoRedirect, statusCode: http.statusCode, outcome: "redirect_limit_reached")
        throw CheckInError.loginNameUnavailable
      }
      AppLog.network.info(
        "iclass redirect stage=sso_redirect hop=\(hop) status=\(http.statusCode) destination_host=\(nextURL.host ?? "unknown", privacy: .public)"
      )
      redirectTrace.append("\(Self.redirectTarget(currentURL))>\(Self.redirectTarget(nextURL))")
      if let value = Self.loginName(in: nextURL) {
        AppLog.network.info("iclass request succeeded stage=sso_redirect hop=\(hop) login_name_source=location")
        return value
      }
      currentURL = nextURL
    }
    throw CheckInError.loginNameUnavailable
  }

  private static func redirectTarget(_ url: URL) -> String {
    if url.host == "iclass.buaa.edu.cn" { return "iclass" }
    if url.host == "sso.buaa.edu.cn" { return "sso" }
    return "other"
  }

  /// Logs only whether gateway cookies apply to the two routed services; never their names or values.
  private static func gatewayCookieScopeSummary(
    storage: HTTPCookieStorage?,
    checkInURL: URL?,
    casURL: URL?
  ) -> String {
    guard let storage else { return "store_missing" }
    let checkInCount = checkInURL.flatMap { storage.cookies(for: $0)?.count } ?? 0
    let casCount = casURL.flatMap { storage.cookies(for: $0)?.count } ?? 0
    let all = storage.cookies ?? []
    let routeScoped = all.filter { $0.path.hasPrefix("/https-") || $0.path.hasPrefix("/http-") }.count
    let rootScoped = all.filter { $0.path == "/" }.count
    let otherScoped = all.count - routeScoped - rootScoped
    return "total:\(all.count),iclass:\(checkInCount),cas:\(casCount),root:\(rootScoped),route:\(routeScoped),other:\(otherScoped)"
  }

  /// Coarse HTML markers only; response bodies, titles, and form values can contain personal data.
  private static func gatewayPageShape(_ html: String) -> String {
    let lower = html.lowercased()
    let markers = [
      "html": lower.contains("<html"),
      "form": lower.contains("<form"),
      "script_redirect": lower.contains("window.location") || lower.contains("location.href"),
      "webvpn_marker": lower.contains("webvpn") || lower.contains("web vpn"),
      "cas_marker": lower.contains("cas") || lower.contains("sso.buaa.edu.cn"),
      "iclass_marker": lower.contains("iclass")
    ]
    return markers.map { "\($0.key):\($0.value ? 1 : 0)" }.sorted().joined(separator: ",")
  }

  private static func loginName(in url: URL?) -> String? {
    guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    return JSONValue.nonEmptyString(components.queryItems?.first(where: { $0.name.caseInsensitiveCompare("loginName") == .orderedSame })?.value)
  }

  private static func redirectShape(_ location: String) -> String {
    let target = location.trimmingCharacters(in: .whitespacesAndNewlines)
    if target.hasPrefix("/https-") || target.hasPrefix("/http-") || target.hasPrefix("/wss-") || target.hasPrefix("/ws-") {
      return "webvpn_relative"
    }
    if target.hasPrefix("//") { return "scheme_relative" }
    if target.hasPrefix("/") { return "path_relative" }
    if let url = URL(string: target), url.scheme != nil { return "absolute" }
    return "relative"
  }

  private static func jsonObject(from data: Data) throws -> [String: Any] {
    guard let object = try? JSONSerialization.jsonObject(with: data), let dictionary = object as? [String: Any] else {
      throw CheckInError.invalidResponse
    }
    return dictionary
  }

  private func requestData(
    for request: URLRequest,
    using session: URLSession,
    stage: RequestStage
  ) async throws -> (Data, URLResponse) {
    do {
      return try await sessionForCurrentRoute(matching: session).data(for: routedRequest(request))
    } catch {
      let networkError = error as NSError
      AppLog.network.error(
        "iclass transport failed stage=\(stage.rawValue, privacy: .public) error_domain=\(networkError.domain, privacy: .public) error_code=\(networkError.code)"
      )
      guard case .direct = route,
            (error as? URLError)?.code == .secureConnectionFailed else {
        throw error
      }

      route = .webVPN
      iclassSession = nil
      AppLog.network.notice("iclass route fallback reason=secure_connection_failed route=webvpn")
      do {
        return try await sessionForCurrentRoute(matching: session).data(for: routedRequest(request))
      } catch {
        let fallbackError = error as NSError
        AppLog.network.error(
          "iclass transport failed stage=\(stage.rawValue, privacy: .public) route=webvpn error_domain=\(fallbackError.domain, privacy: .public) error_code=\(fallbackError.code)"
        )
        throw CheckInError.webVPNUnavailable
      }
    }
  }

  private func sessionForCurrentRoute(matching directSession: URLSession) -> URLSession {
    guard case .webVPN = route else { return directSession }
    return directSession === noRedirectSession ? webVPNNoRedirectSession : webVPNSession
  }

  private func routedRequest(_ request: URLRequest) throws -> URLRequest {
    guard case .webVPN = route, let url = request.url else { return request }
    var routed = request
    routed.url = try WebVPNRouter.wrap(url)
    return routed
  }

  private func logInvalidHTTPResponse(stage: RequestStage) {
    AppLog.network.error("iclass request failed stage=\(stage.rawValue, privacy: .public) reason=non_http_response")
  }

  private func logHTTPResponse(stage: RequestStage, statusCode: Int, outcome: String) {
    AppLog.network.error(
      "iclass request failed stage=\(stage.rawValue, privacy: .public) http_status=\(statusCode) outcome=\(outcome, privacy: .public)"
    )
  }

  private static func safeStatus(_ value: Any?) -> String {
    guard let value = string(value) else { return "missing" }
    return value.count <= 16 && value.allSatisfy({ $0.isASCII && ($0.isNumber || $0.isLetter || $0 == "_" || $0 == "-") })
      ? value
      : "unrecognized"
  }

  private static func isSuccessful(_ value: Any?) -> Bool {
    guard let status = string(value) else { return false }
    return ["0", "200", "success"].contains(status.lowercased())
  }

  /// iclass 字段一律去除首尾空白，空文本视为缺失。
  private static func string(_ value: Any?) -> String? { JSONValue.nonEmptyString(value) }
  private static func integer(_ value: Any?) -> Int? { JSONValue.int(value) }

  private static func schoolDateString(from date: Date) -> String {
    SchoolTime.string(from: date, format: "yyyyMMdd")
  }
}

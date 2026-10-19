import Foundation

actor CgyyClient {
  private let session: URLSession
  private let base = "https://cgyy.buaa.edu.cn/venue-zhjs-server/"
  private var accessToken: String?
  private var credential: SavedCredential?

  init(session: URLSession = APIClient.shared.session, accessToken: String? = nil) {
    self.session = session
    self.accessToken = accessToken
  }

  func setCredential(_ credential: SavedCredential?) {
    if self.credential?.username != credential?.username { accessToken = nil }
    self.credential = credential
  }

  func venues() async throws -> [CgyyVenueSite] {
    let data = try await request(
      method: "GET",
      path: "/api/front/website/venues",
      params: ["page": "-1", "size": "-1", "reservationRoleId": "3"],
      includeAuthorization: false
    )
    let content: [[String: Any]]
    if let array = data as? [[String: Any]] {
      content = array
    } else if let root = data as? [String: Any] {
      content = (root["content"] as? [[String: Any]]) ?? (root["data"] as? [[String: Any]]) ?? []
    } else {
      throw CgyyError.invalidResponse("场馆列表")
    }
    var sites: [CgyyVenueSite] = []
    for venue in content {
      let venueID = int(venue["id"])
      let venueName = string(venue["venueName"])
      let campus = string(venue["campusName"])
      let siteList = venue["siteList"] as? [[String: Any]] ?? []
      for site in siteList {
        guard let siteID = int(site["id"] ?? site["siteId"]), siteID > 0 else { continue }
        sites.append(
          CgyyVenueSite(
            id: siteID,
            siteName: string(site["siteName"]),
            venueName: venueName,
            campusName: campus,
            seatCount: int(site["seatCount"]),
            reservationSpaceCount: int(site["reservationSpaceCount"]),
            siteTelephone: stringOrNil(site["siteTelephone"]),
            openStartDate: stringOrNil(site["openStartDate"]),
            openEndDate: stringOrNil(site["openEndDate"])
          )
        )
      }
      if siteList.isEmpty, let siteID = venueID, siteID > 0 {
        sites.append(
          CgyyVenueSite(
            id: siteID,
            siteName: string(venue["siteName"]),
            venueName: venueName,
            campusName: campus,
            seatCount: nil,
            reservationSpaceCount: nil,
            siteTelephone: nil,
            openStartDate: nil,
            openEndDate: nil
          )
        )
      }
    }
    guard sites.isEmpty == false else { throw CgyyError.invalidResponse("场馆列表为空") }
    return sites.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }

  func purposeTypes() async throws -> [CgyyPurposeType] {
    let data = try? await request(method: "GET", path: "/api/codes")
    var results: [Int: String] = [:]
    func traverse(_ value: Any?) {
      if let array = value as? [Any] {
        array.forEach(traverse)
      } else if let object = value as? [String: Any] {
        let name = string(object["name"])
        let key = int(object["key"] ?? object["value"] ?? object["id"])
        if let key, name.contains("类") {
          results[key] = results[key] ?? name
        }
        object.values.forEach(traverse)
      }
    }
    traverse(data)
    if results.isEmpty {
      return Self.fallbackPurposeTypes
    }
    return results.map { CgyyPurposeType(id: $0.key, name: $0.value) }.sorted { $0.id < $1.id }
  }

  func dayInfo(siteID: Int, date: String) async throws -> CgyyDayInfo {
    let data = try await request(
      method: "GET",
      path: "/api/reservation/day/info",
      params: ["searchDate": date, "venueSiteId": String(siteID)]
    )
    guard let root = data as? [String: Any] else { throw CgyyError.invalidResponse("时段") }
    let timeSlots = (root["spaceTimeInfo"] as? [[String: Any]] ?? []).compactMap { row -> CgyyTimeSlot? in
      guard let id = int(row["id"]) else { return nil }
      return CgyyTimeSlot(id: id, beginTime: string(row["beginTime"]), endTime: string(row["endTime"]))
    }
    let timeIDs = Set(timeSlots.map(\.id))
    let dateSpace = root["reservationDateSpaceInfo"] as? [String: Any] ?? [:]
    let dateKey = dateSpace.keys.contains(date) ? date : dateSpace.keys.first ?? date
    let spaceRows = dateSpace[dateKey] as? [[String: Any]] ?? []
    let spaces = spaceRows.compactMap { row -> CgyySpaceAvailability? in
      guard let id = int(row["id"] ?? row["spaceId"]), id > 0 else { return nil }
      let slots = timeSlots.compactMap { slot -> CgyySlotStatus? in
        guard timeIDs.contains(slot.id),
              let raw = row[String(slot.id)] as? [String: Any] else { return nil }
        return slotStatus(timeID: slot.id, raw: raw)
      }
      return CgyySpaceAvailability(
        id: id,
        name: string(row["spaceName"]),
        venueSiteID: int(row["venueSiteId"]) ?? siteID,
        groupID: int(row["venueSpaceGroupId"]),
        slots: slots
      )
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    let dates = stringArray(root["ableReservationDateList"]) ?? stringArray(root["reservationDateList"]) ?? []
    return CgyyDayInfo(
      siteID: siteID,
      date: dateKey,
      availableDates: dates,
      timeSlots: timeSlots,
      spaces: spaces,
      reservationToken: stringOrNil(root["token"]),
      reservationTotalNum: int(root["reservationTotalNum"])
    )
  }

  func createDraft(
    siteID: Int,
    date: String,
    selections: [CgyyOrderSelection],
    token: String
  ) async throws {
    let json = try JSONEncoder().encode(selections)
    guard let text = String(data: json, encoding: .utf8) else {
      throw CgyyError.operation("预约选择编码失败")
    }
    _ = try await request(
      method: "POST",
      path: "/api/reservation/order/info",
      form: [
        "venueSiteId": String(siteID),
        "reservationDate": date,
        "weekStartDate": date,
        "reservationOrderJson": text,
        "token": token
      ]
    )
  }

  func captcha() async throws -> CgyyCaptchaChallenge {
    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    let data = try await request(
      method: "GET",
      path: "/api/captcha/get",
      params: [
        "captchaType": "blockPuzzle",
        "clientUid": "slider-\(timestamp)",
        "ts": String(timestamp)
      ]
    )
    guard let root = data as? [String: Any] else { throw CgyyError.captcha("响应为空") }
    let success = bool(root["success"])
    guard success else {
      throw CgyyError.captcha(string(root["repMsg"]).isEmpty ? "获取验证码失败" : string(root["repMsg"]))
    }
    guard let rep = root["repData"] as? [String: Any] else {
      throw CgyyError.captcha("验证码数据缺失")
    }
    let secretKey = string(rep["secretKey"])
    let token = string(rep["token"])
    let original = string(rep["originalImageBase64"])
    let jigsaw = string(rep["jigsawImageBase64"])
    guard secretKey.isEmpty == false, token.isEmpty == false,
          original.isEmpty == false, jigsaw.isEmpty == false else {
      throw CgyyError.captcha("验证码字段不完整")
    }
    return CgyyCaptchaChallenge(
      secretKey: secretKey,
      token: token,
      originalImageBase64: original,
      jigsawImageBase64: jigsaw
    )
  }

  func verifyCaptcha(pointJSON: String, token: String, secretKey: String) async throws {
    let point = try CgyyCrypto.encryptedPointJSON(pointJSON, secretKey: secretKey)
    let data = try await request(
      method: "POST",
      path: "/api/captcha/check",
      form: ["pointJson": point, "token": token]
    )
    guard let root = data as? [String: Any], bool(root["success"]) else {
      throw CgyyError.captcha(string((data as? [String: Any])?["repMsg"] ?? "").isEmpty
        ? "验证码校验失败" : string((data as? [String: Any])?["repMsg"]))
    }
  }

  func submitOrder(
    siteID: Int,
    date: String,
    selections: [CgyyOrderSelection],
    token: String,
    phone: String,
    theme: String,
    purposeType: Int,
    joinerNum: Int,
    activityContent: String,
    joiners: String,
    captchaVerification: String,
    philosophy: Bool,
    offSchool: Bool
  ) async throws -> CgyyOrder? {
    let jsonData = try JSONEncoder().encode(selections)
    guard let json = String(data: jsonData, encoding: .utf8) else {
      throw CgyyError.operation("预约选择编码失败")
    }
    let data = try await request(
      method: "POST",
      path: "/api/reservation/order/submit",
      form: [
        "venueSiteId": String(siteID),
        "reservationDate": date,
        "reservationOrderJson": json,
        "weekStartDate": date,
        "phone": phone,
        "theme": theme,
        "purposeType": String(purposeType),
        "joinerNum": String(joinerNum),
        "activityContent": activityContent,
        "joiners": joiners,
        "isPhilosophySocialSciences": philosophy ? "1" : "0",
        "isOffSchoolJoiner": offSchool ? "1" : "0",
        "captchaVerification": captchaVerification,
        "token": token
      ]
    )
    if let root = data as? [String: Any],
       let info = root["orderInfo"] as? [String: Any] {
      return order(info)
    }
    return nil
  }

  func orders(page: Int = 1, size: Int = 20) async throws -> [CgyyOrder] {
    let data = try await request(
      method: "GET",
      path: "/api/orders/mine",
      params: ["page": String(page), "size": String(size)]
    )
    guard let root = data as? [String: Any] else { throw CgyyError.invalidResponse("预约记录") }
    let rows = root["content"] as? [[String: Any]] ?? root["list"] as? [[String: Any]] ?? []
    return rows.compactMap(order)
  }

  func cancel(orderID: Int) async throws {
    _ = try await request(
      method: "POST",
      path: "/api/orders/new/cancel/\(orderID)"
    )
  }

  func lockCode() async throws -> CgyyLockCodeInfo? {
    let data = try await request(method: "GET", path: "/api/orders/lock/code")
    guard let root = data as? [String: Any] else { return nil }
    let order = root["orderView"] as? [String: Any] ?? [:]
    return CgyyLockCodeInfo(
      qrCode: stringOrNil(root["qrCode"]),
      dueDate: stringOrNil(root["dueDate"]),
      tradeNo: stringOrNil(order["tradeNo"]),
      venueName: stringOrNil(order["venueName"]),
      siteName: stringOrNil(order["siteName"]),
      spaceName: stringOrNil(order["venueSpaceName"]),
      orderName: stringOrNil(order["orderName"]),
      reservationDate: stringOrNil(order["reservationDate"]),
      reservationDateDetail: stringOrNil(order["reservationDateDetail"]),
      reservationStartDate: stringOrNil(order["reservationStartDate"]),
      reservationEndDate: stringOrNil(order["reservationEndDate"])
    )
  }

  // MARK: - HTTP

  private func ensureLogin() async throws {
    if accessToken != nil { return }
    try await login()
  }

  private func login() async throws {
    accessToken = nil
    // CGYY's SSO cookie is issued on cgyy.buaa.edu.cn and the service is
    // documented by UBAA as direct-only. Keep the full business session direct
    // even when the user's global upstream preference is WebVPN.
    try await loginDirect()
  }

  private func loginDirect() async throws {
    clearDirectSSOToken()
    // 如果应用本身已有直连 SSO 会话，先走一次 manageLogin 拿新 token。
    try? await refreshManageLoginDirect()
    if let token = directSSOToken() {
      try await businessLogin(token)
      return
    }

    guard let credential else {
      throw CgyyError.operation("研讨室需要直连学校 SSO，但应用没有可用的保存凭据；请在登录页勾选“记住密码”并允许钥匙串，或重新登录后再试。")
    }
    var components = URLComponents(string: "https://sso.buaa.edu.cn/login")!
    components.queryItems = [
      URLQueryItem(name: "service", value: base + "sso/manageLogin")
    ]
    guard let serviceLoginURL = components.url else { throw CgyyError.authentication }
    let cas = CasClient(
      session: APIClient.shared.noRedirectSession,
      loginURL: serviceLoginURL,
      ignoreGlobalRoute: true
    )
    do {
      try await cas.loginForService(
        username: credential.username,
        password: credential.password
      )
    } catch {
      if let casError = error as? CasClientError,
         case .captchaRequired = casError {
        throw CgyyError.operation("学校登录页要求验证码；请先在浏览器完成一次学校登录，再回到研讨室重试。")
      }
      throw CgyyError.operation("研讨室登录失败：\(error.localizedDescription)")
    }

    try await refreshManageLoginDirect()
    guard let token = directSSOToken() else {
      throw CgyyError.operation("学校 SSO 已登录，但没有拿到研讨室 sso_buaa_zhjs_token；请确认 CGYY 服务可直连后重试。")
    }
    try await businessLogin(token)
  }

  private func businessLogin(_ ssoToken: String) async throws {
    let data = try await request(
      method: "POST",
      path: "/api/login",
      extraHeaders: ["Sso-Token": ssoToken],
      includeAuthorization: false,
      retry: false
    )
    guard let root = data as? [String: Any],
          let token = root["token"] as? [String: Any],
          let value = token["access_token"] as? String,
          value.isEmpty == false else {
      throw CgyyError.operation("研讨室 SSO Token 已获取，但 /api/login 没有返回 access_token。")
    }
    accessToken = value
  }

  private func refreshManageLoginDirect() async throws {
    var request = URLRequest(url: URL(string: base + "sso/manageLogin")!)
    request.timeoutInterval = 45
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
      throw CgyyError.authentication
    }
  }

  private func directSSOToken() -> String? {
    guard let url = URL(string: base) else { return nil }
    return (HTTPCookieStorage.shared.cookies(for: url) ?? [])
      .first { $0.name == "sso_buaa_zhjs_token" && $0.value.isEmpty == false }?
      .value
  }

  private func clearDirectSSOToken() {
    guard let url = URL(string: base) else { return }
    for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? []
    where cookie.name == "sso_buaa_zhjs_token" {
      HTTPCookieStorage.shared.deleteCookie(cookie)
    }
  }

  private func request(
    method: String,
    path: String,
    params: [String: String] = [:],
    form: [String: String] = [:],
    extraHeaders: [String: String] = [:],
    includeAuthorization: Bool = true,
    retry: Bool = true
  ) async throws -> Any? {
    if includeAuthorization { try await ensureLogin() }
    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    let isGET = method == "GET"
    let requestParams = isGET ? CgyySigner.withNoCache(params, timestamp: timestamp) : form
    let sign = CgyySigner.sign(path: path, parameters: requestParams, timestamp: timestamp)

    guard var components = URLComponents(string: base + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
      throw CgyyError.invalidResponse("URL")
    }
    if isGET, requestParams.isEmpty == false {
      components.percentEncodedQuery = encode(requestParams)
    }
    guard let url = components.url else { throw CgyyError.invalidResponse("URL") }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 45
    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
    request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    request.setValue("https://cgyy.buaa.edu.cn/venue-zhjs/mobileReservation", forHTTPHeaderField: "Referer")
    request.setValue(CgyySigner.appKey, forHTTPHeaderField: "app-key")
    request.setValue(String(timestamp), forHTTPHeaderField: "timestamp")
    request.setValue(sign, forHTTPHeaderField: "sign")
    if includeAuthorization, let token = accessToken {
      request.setValue(token, forHTTPHeaderField: "cgAuthorization")
    }
    for (key, value) in extraHeaders {
      request.setValue(value, forHTTPHeaderField: key)
    }
    if isGET == false {
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.httpBody = encode(form).data(using: .utf8)
    }

    let mutation = method == "POST" && (path.hasPrefix("/api/reservation/order/") || path.hasPrefix("/api/orders/new/cancel/"))
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      if mutation { throw CgyyError.uncertain }
      throw error
    }
    guard let http = response as? HTTPURLResponse else {
      if mutation { throw CgyyError.uncertain }
      throw CgyyError.unavailable
    }
    let body = String(data: data, encoding: .utf8) ?? ""
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    if http.statusCode == 401 || int(json?["code"]) == 401 || Self.isLoginRedirect(url: http.url, body: body) {
      accessToken = nil
      if includeAuthorization, retry, isGET {
        try await login()
        return try await self.request(
          method: method, path: path, params: params, form: form, extraHeaders: extraHeaders,
          includeAuthorization: includeAuthorization, retry: false
        )
      }
      if mutation { throw CgyyError.uncertain }
      throw CgyyError.authentication
    }
    guard (200..<300).contains(http.statusCode) else {
      if mutation { throw CgyyError.uncertain }
      throw CgyyError.unavailable
    }
    guard let json, let code = int(json["code"]) else {
      if mutation { throw CgyyError.uncertain }
      throw CgyyError.invalidResponse("响应缺少业务状态")
    }
    if code != 200 {
      let message = string(json["message"])
      throw CgyyError.upstream(message.isEmpty ? "研讨室系统请求失败（代码 \(code)）" : message)
    }
    return json["data"] ?? NSNull()
  }

  /// 参数按键名排序编码，与签名时的参数顺序一致。
  private func encode(_ params: [String: String]) -> String {
    FormURLEncoding.encode(params.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
  }

  private static func isLoginRedirect(url: URL?, body: String) -> Bool {
    if url?.host == "sso.buaa.edu.cn" { return true }
    return body.contains("name=\"execution\"") && body.contains("username_password")
  }

  // MARK: - Mapping

  private func slotStatus(timeID: Int, raw: [String: Any]) -> CgyySlotStatus {
    let status = int(raw["reservationStatus"]) ?? 0
    let tradeNo = stringOrNil(raw["tradeNo"])
    let orderID = int(raw["orderId"])
    let takeUp = bool(raw["takeUp"])
    return CgyySlotStatus(
      timeID: timeID,
      status: status,
      isReservable: status == 1 && tradeNo == nil && orderID == nil && takeUp != true,
      startDate: stringOrNil(raw["startDate"]),
      endDate: stringOrNil(raw["endDate"]),
      tradeNo: tradeNo,
      orderID: orderID,
      useNum: int(raw["useNum"]),
      alreadyNum: int(raw["alreadyNum"]),
      takeUp: takeUp,
      takeUpExplain: stringOrNil(raw["takeUpExplain"])
    )
  }

  private func order(_ row: [String: Any]) -> CgyyOrder? {
    guard let id = int(row["id"]) else { return nil }
    return CgyyOrder(
      id: id,
      tradeNo: stringOrNil(row["tradeNo"]),
      venueSiteID: int(row["venueSiteId"]),
      reservationDate: stringOrNil(row["reservationDate"]),
      reservationDateDetail: stringOrNil(row["reservationDateDetail"]),
      venueSpaceName: stringOrNil(row["venueSpaceName"]),
      campusName: stringOrNil(row["campusName"]),
      venueName: stringOrNil(row["venueName"]),
      siteName: stringOrNil(row["siteName"]),
      reservationStartDate: stringOrNil(row["reservationStartDate"]),
      reservationEndDate: stringOrNil(row["reservationEndDate"]),
      phone: stringOrNil(row["phone"]),
      orderStatus: int(row["orderStatus"]),
      payStatus: int(row["payStatus"]),
      checkStatus: int(row["checkStatus"]),
      theme: stringOrNil(row["theme"]),
      purposeType: int(row["purposeType"]),
      joinerNum: int(row["joinerNum"]),
      activityContent: stringOrNil(row["activityContent"]),
      joiners: stringOrNil(row["joiners"]),
      checkContent: stringOrNil(row["checkContent"]),
      handleReason: stringOrNil(row["handleReason"]),
      remark: stringOrNil(row["remark"])
    )
  }

  private func string(_ value: Any?) -> String { JSONValue.string(value) ?? "" }

  /// CGYY 偶尔把空值序列化成字符串 `"null"`。
  private func stringOrNil(_ value: Any?) -> String? {
    let text = string(value)
    return text.isEmpty || text == "null" ? nil : text
  }

  private func int(_ value: Any?) -> Int? { JSONValue.int(value) }
  private func bool(_ value: Any?) -> Bool { JSONValue.bool(value) ?? false }

  private func stringArray(_ value: Any?) -> [String]? {
    guard let array = value as? [Any] else { return nil }
    return array.compactMap { string($0) }.filter { $0.isEmpty == false }
  }

  private static let fallbackPurposeTypes: [CgyyPurposeType] = [
    CgyyPurposeType(id: 1, name: "导学活动类"),
    CgyyPurposeType(id: 2, name: "学业支持类（串讲、答疑、学习小组讨论等）"),
    CgyyPurposeType(id: 3, name: "学术研讨类（竞赛、答辩、展示等小组讨论）"),
    CgyyPurposeType(id: 4, name: "党建活动类"),
    CgyyPurposeType(id: 5, name: "工作会议类（单位工作例会、学生组织工作会议等）"),
    CgyyPurposeType(id: 6, name: "团队建设类（班级、社团、学生会等学生组织团建）"),
    CgyyPurposeType(id: 7, name: "培训面试类（梦拓、学生组织培训及面试等）"),
    CgyyPurposeType(id: 8, name: "博雅课程类"),
    CgyyPurposeType(id: 9, name: "讲座、沙龙研讨类"),
    CgyyPurposeType(id: 10, name: "其他特色活动类")
  ]
}

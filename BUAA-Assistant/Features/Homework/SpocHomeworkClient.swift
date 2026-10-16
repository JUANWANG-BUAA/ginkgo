import Foundation
import CommonCrypto

struct SpocHomeworkClient {
  private enum Stage: String {
    case loginRedirect = "登录跳转"
    case casLogin = "CAS 认证"
    case currentTerm = "学期查询"
    case courseList = "课程查询"
    case assignmentList = "作业列表"
    case assignmentDetail = "作业详情"
    case submissionInfo = "提交信息"
  }

  let session: URLSession
  private let api = "https://spoc.buaa.edu.cn/spocnewht"
  private let json = JSONDecoder()

  private struct LoadedAssignments {
    let items: [HomeworkItem]
    let term: HomeworkTerm
  }

  struct Envelope<T: Decodable>: Decodable { let code: Int; let content: T?; let msg: String? }
  struct Term: Decodable { let dqxq: String?; let mrxq: String? }
  struct Course: Decodable { let kcid: String; let kcmc: String; let skjs: String? }
  struct Page: Decodable { let pages: Int?; let pageNum: Int?; let hasNextPage: Bool?; let list: [Assignment] }
  struct Assignment: Decodable {
    let zyid: String
    let tjzt: String?
    let zyjzsj: String?
    let zykssj: String?
    let zymc: String
    let sskcid: String?
    let kcmc: String?
    let mf: String?
  }
  struct AssignmentDetail: Decodable {
    let zynr: String?
    let zykssj: String?
    let zyjzsj: String?
    let zyfs: String?
  }
  struct Submission: Decodable { let tjzt: String?; let tjsj: String? }
  struct Role: Decodable {
    let jsdm: String?
    let rolecode: String?
    let jsdmList: String?

    private enum CodingKeys: String, CodingKey { case jsdm, rolecode, jsdmList }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      jsdm = Self.firstString(in: container, forKey: .jsdm)
      rolecode = Self.firstString(in: container, forKey: .rolecode)
      jsdmList = Self.firstString(in: container, forKey: .jsdmList)
    }

    var resolvedCode: String? { jsdm ?? rolecode ?? jsdmList }

    private static func firstString(
      in container: KeyedDecodingContainer<CodingKeys>,
      forKey key: CodingKeys
    ) -> String? {
      if let value = try? container.decode(String.self, forKey: key), !value.isEmpty { return value }
      if let value = try? container.decode(Int.self, forKey: key) { return String(value) }
      if let values = try? container.decode([String].self, forKey: key) {
        return values.first(where: { !$0.isEmpty })
      }
      if let values = try? container.decode([Int].self, forKey: key), let value = values.first {
        return String(value)
      }
      return nil
    }
  }

  var items: [HomeworkItem] { get async throws { try await loadItems().items } }

  func load() async throws -> HomeworkSnapshot {
    let loaded = try await loadItems()
    return HomeworkSnapshot(items: loaded.items, fetchedAt: Date(), spocTerm: loaded.term)
  }

  func loadDetail(assignmentID: String) async throws -> HomeworkDetail {
    do {
      return try await loadDetailOnce(assignmentID: assignmentID)
    } catch HomeworkError.spocAuthenticationExpired(let stage) {
      AppLog.network.info("SPOC detail authentication expired; retrying once stage=\(stage, privacy: .public)")
      return try await loadDetailOnce(assignmentID: assignmentID)
    }
  }

  private func loadItems() async throws -> LoadedAssignments {
    do {
      return try await loadItemsOnce()
    } catch HomeworkError.spocAuthenticationExpired(let stage) {
      AppLog.network.info("SPOC authentication expired; retrying once stage=\(stage, privacy: .public)")
      return try await loadItemsOnce()
    }
  }

  private func loadItemsOnce() async throws -> LoadedAssignments {
    let (token, role) = try await authenticate()
    let term = try await post(
      "/inco/ht/queryOne", headers: headers(token, role),
      body: ["param": Self.currentTermParam], type: Term.self, stage: .currentTerm
    )
    guard let termCode = term.mrxq else { throw HomeworkError.spocFailure(stage: Stage.currentTerm.rawValue, reason: "未返回学期代码") }
    let courses = try await get(
      "/jxkj/queryKclb?kcmc=&xnxq=\(termCode)", headers: headers(token, role),
      type: [Course].self, stage: .courseList
    )
    let courseMap = Dictionary(uniqueKeysWithValues: courses.map { ($0.kcid, $0) })
    var result: [HomeworkItem] = []
    var page = 1
    while true {
      let payload = ["pageSize": 15, "pageNum": page, "sqlid": Self.assignmentSQLID, "xnxq": termCode, "kcid": "", "yzwz": ""] as [String : Any]
      let data = try JSONSerialization.data(withJSONObject: payload)
      let encoded = Self.encrypt(data)
      let pageData = try await post(
        "/inco/ht/queryListByPage", headers: headers(token, role),
        body: ["param": encoded], type: Page.self, stage: .assignmentList
      )
      result += pageData.list.map { assignment in
        let due = Self.date(assignment.zyjzsj)
        let mappedStatus = Self.mapSubmissionStatus(assignment.tjzt, dueAt: due)
        let course = assignment.sskcid.flatMap { courseMap[$0] }
        return HomeworkItem(
          id: "spoc:\(assignment.zyid)",
          courseName: assignment.kcmc ?? course?.kcmc ?? "SPOC 课程",
          title: assignment.zymc,
          dueAt: due,
          sourceURL: nil,
          status: mappedStatus.status,
          source: .spoc,
          fetchedAt: Date(),
          courseID: assignment.sskcid,
          publishedAt: Self.date(assignment.zykssj),
          teacherName: course?.skjs,
          score: Self.normalizeScore(assignment.mf),
          statusDetail: mappedStatus.detail
        )
      }
      if pageData.hasNextPage != true && page >= (pageData.pages ?? page) { break }
      page += 1
      if page > 100 { break }
    }
    let deadlines = result.filter { $0.dueAt != nil }.count
    AppLog.network.info("SPOC assignments loaded count=\(result.count) deadlines_confirmed=\(deadlines)")
    return LoadedAssignments(
      items: result,
      term: HomeworkTerm(code: termCode, name: term.dqxq)
    )
  }

  private func authenticate() async throws -> (token: String, role: String) {
    let token = try await loginToken()
    let role = try await post(
      "/sys/casLogin",
      headers: ["Token": "Inco-\(token)"],
      body: ["token": token],
      type: Role.self,
      stage: .casLogin
    ).resolvedCode ?? ""
    guard !role.isEmpty else {
      throw HomeworkError.spocFailure(stage: Stage.casLogin.rawValue, reason: "登录响应未包含可用角色")
    }
    return (token, role)
  }

  private func loadDetailOnce(assignmentID: String) async throws -> HomeworkDetail {
    let (token, role) = try await authenticate()
    let detailURL = Self.url("\(api)/kczy/queryKczyInfoByid", queryItems: [
      URLQueryItem(name: "id", value: assignmentID)
    ])
    let assignment = try await get(detailURL, headers: headers(token, role), type: AssignmentDetail.self, stage: .assignmentDetail)

    let submissionURL = Self.url("\(api)/kczy/queryXsSubmitKczyInfo", queryItems: [
      URLQueryItem(name: "kczyid", value: assignmentID)
    ])
    let submission = try await getOptional(submissionURL, headers: headers(token, role), type: Submission.self, stage: .submissionInfo)
    let dueAt = Self.date(assignment.zyjzsj)
    let status = Self.mapDetailSubmissionStatus(
      submission?.tjzt,
      hasSubmissionRecord: submission != nil,
      dueAt: dueAt
    )
    return HomeworkDetail(
      itemID: "spoc:\(assignmentID)",
      content: Self.plainText(assignment.zynr),
      submissionStatus: status.status,
      statusDetail: status.detail,
      submittedAt: Self.date(submission?.tjsj),
      score: Self.normalizeScore(assignment.zyfs),
      publishedAt: Self.date(assignment.zykssj),
      dueAt: dueAt,
      fetchedAt: Date()
    )
  }

  private func loginToken() async throws -> String {
    var url = URL(string: "\(api)/cas")!
    for hop in 0..<8 {
      let request = URLRequest(url: url)
      let (_, http) = try await requestData(request, using: APIClient.shared.noRedirectSession, stage: .loginRedirect)
      if let location = http.value(forHTTPHeaderField: "Location"), let next = URL(string: location, relativeTo: url)?.absoluteURL {
        if let components = URLComponents(url: next, resolvingAgainstBaseURL: false), next.path.contains("/spocnew/cas"), let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
          AppLog.network.info("SPOC request succeeded stage=login_redirect hops=\(hop + 1)")
          return token
        }
        guard (300..<400).contains(http.statusCode) else {
          throw HomeworkError.spocFailure(stage: Stage.loginRedirect.rawValue, reason: "未返回访问凭证")
        }
        url = next; continue
      }
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let token = components.queryItems?.first(where: { $0.name == "token" })?.value { return token }
      AppLog.network.error("SPOC request failed stage=login_redirect http_status=\(http.statusCode) outcome=location_missing")
      throw HomeworkError.spocFailure(stage: Stage.loginRedirect.rawValue, reason: "未收到有效登录跳转")
    }
    AppLog.network.error("SPOC request failed stage=login_redirect outcome=redirect_limit")
    throw HomeworkError.spocFailure(stage: Stage.loginRedirect.rawValue, reason: "登录跳转次数过多")
  }

  private func headers(_ token: String, _ role: String) -> [String: String] { ["Token": "Inco-\(token)", "RoleCode": role, "X-Requested-With": "XMLHttpRequest"] }
  private func get<T: Decodable>(_ path: String, headers: [String: String], type: T.Type, stage: Stage) async throws -> T {
    try await get(URL(string: api + path)!, headers: headers, type: type, stage: stage)
  }
  private func get<T: Decodable>(_ url: URL, headers: [String: String], type: T.Type, stage: Stage) async throws -> T {
    var request = URLRequest(url: url)
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    let (data, response) = try await requestData(request, using: session, stage: stage)
    return try decode(data, response, type, stage: stage)
  }
  private func getOptional<T: Decodable>(_ url: URL, headers: [String: String], type: T.Type, stage: Stage) async throws -> T? {
    var request = URLRequest(url: url)
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    let (data, response) = try await requestData(request, using: session, stage: stage)
    guard response.statusCode == 200 else {
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) http_status=\(response.statusCode)")
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "服务返回 HTTP \(response.statusCode)")
    }
    let envelope: Envelope<T>
    do {
      envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
    } catch {
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) outcome=invalid_json")
      let looksLikeHTML = String(data: data.prefix(128), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<") == true
      if looksLikeHTML {
        throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "收到登录页面，请重新登录后重试")
      }
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: stage.rawValue)
    }
    guard envelope.code == 200 else {
      if envelope.code == 401 || envelope.code == 403 { throw HomeworkError.spocAuthenticationExpired(stage: stage.rawValue) }
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "业务响应未成功（\(envelope.code)）")
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object.keys.contains("content") else {
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: stage.rawValue)
    }
    AppLog.network.info("SPOC request succeeded stage=\(stage.rawValue, privacy: .public)")
    return envelope.content
  }
  private func post<T: Decodable>(_ path: String, headers: [String: String], body: [String: Any], type: T.Type, stage: Stage) async throws -> T {
    var request = URLRequest(url: URL(string: api + path)!); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await requestData(request, using: session, stage: stage)
    return try decode(data, response, type, stage: stage)
  }
  private func requestData(
    _ request: URLRequest,
    using session: URLSession,
    stage: Stage
  ) async throws -> (Data, HTTPURLResponse) {
    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) outcome=non_http_response")
        throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "服务器响应无效")
      }
      if http.statusCode == 401 || http.statusCode == 403 {
        throw HomeworkError.spocAuthenticationExpired(stage: stage.rawValue)
      }
      return (data, http)
    } catch let error as HomeworkError {
      throw error
    } catch {
      let networkError = error as NSError
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) error_domain=\(networkError.domain, privacy: .public) error_code=\(networkError.code)")
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "网络连接失败（\(networkError.code)）")
    }
  }

  private func decode<T: Decodable>(_ data: Data, _ response: HTTPURLResponse, _ type: T.Type, stage: Stage) throws -> T {
    guard response.statusCode == 200 else {
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) http_status=\(response.statusCode)")
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "服务返回 HTTP \(response.statusCode)")
    }
    let envelope: Envelope<T>
    do {
      envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
    } catch {
      let looksLikeHTML = String(data: data.prefix(128), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<") == true
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) outcome=\(looksLikeHTML ? "html_response" : "invalid_json", privacy: .public)")
      if looksLikeHTML {
        throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "收到登录页面，请重新登录后重试")
      }
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: stage.rawValue)
    }
    guard envelope.code == 200, let content = envelope.content else {
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) business_code=\(envelope.code)")
      if envelope.code == 401 || envelope.code == 403 {
        throw HomeworkError.spocAuthenticationExpired(stage: stage.rawValue)
      }
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "业务响应未成功（\(envelope.code)）")
    }
    AppLog.network.info("SPOC request succeeded stage=\(stage.rawValue, privacy: .public)")
    return content
  }
  static func date(_ value: String?) -> Date? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    for options: ISO8601DateFormatter.Options in [
      [.withInternetDateTime, .withFractionalSeconds],
      [.withInternetDateTime]
    ] {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = options
      if let date = formatter.date(from: value) { return date }
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    for pattern in ["yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
      formatter.dateFormat = pattern
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }

  static func normalizeScore(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
      let range = value.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
    return String(value[range])
  }

  static func submissionStatus(_ raw: String?, hasSubmissionRecord: Bool, dueAt: Date?) -> HomeworkStatus {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "1", "已做", "已提交": return .submitted
    case "0", "未做", "未提交", nil, "":
      guard hasSubmissionRecord else { return (dueAt ?? .distantFuture) < Date() ? .overdue : .pending }
      return .unknown
    case .some: return .unknown
    }
  }

  static func mapSubmissionStatus(
    _ rawStatus: String?,
    dueAt: Date?,
    now: Date = Date()
  ) -> (status: HomeworkStatus, detail: String?) {
    let normalized = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
    switch normalized {
    case "1", "已做", "已提交": return (.submitted, nil)
    case "0", "未做", "未提交": return ((dueAt ?? .distantFuture) < now ? .overdue : .pending, nil)
    case nil, "": return ((dueAt ?? .distantFuture) < now ? .overdue : .pending, nil)
    case .some(let value): return (.unknown, value)
    }
  }

  static func mapDetailSubmissionStatus(
    _ rawStatus: String?,
    hasSubmissionRecord: Bool,
    dueAt: Date?,
    now: Date = Date()
  ) -> (status: HomeworkStatus, detail: String?) {
    let normalized = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
    switch normalized {
    case "1", "已做", "已提交": return (.submitted, nil)
    case "0", "未做", "未提交", nil, "":
      guard hasSubmissionRecord else {
        return ((dueAt ?? .distantFuture) < now ? .overdue : .pending, nil)
      }
      return (.unknown, nil)
    case .some(let value): return (.unknown, value)
    }
  }

  static func plainText(_ html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }
    let withBreaks = html.replacingOccurrences(
      of: #"(?i)<br\s*/?>|</p\s*>|</li\s*>|</div\s*>"#,
      with: "\n",
      options: .regularExpression
    )
    let text = withBreaks
      .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
    let lines = text.components(separatedBy: .newlines)
      .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
      .filter { !$0.isEmpty }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
  }

  private static func url(_ value: String, queryItems: [URLQueryItem]) -> URL {
    var components = URLComponents(string: value)!
    components.queryItems = queryItems
    return components.url!
  }
  static func encrypt(_ data: Data) -> String {
    var input = data
    input.append(Data(repeating: 0, count: (16 - data.count % 16) % 16))
    let outputCapacity = input.count + kCCBlockSizeAES128
    var output = Data(count: outputCapacity)
    var moved = 0
    let key = Array("inco12345678ocni".utf8)
    let iv = Array("ocni12345678inco".utf8)
    let inputCount = input.count
    _ = input.withUnsafeBytes { inputBytes in
      output.withUnsafeMutableBytes { outputBytes in
        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(0), key, kCCKeySizeAES128, iv,
          inputBytes.baseAddress, inputCount, outputBytes.baseAddress, outputCapacity, &moved)
      }
    }
    return output.prefix(moved).base64EncodedString()
  }
  private static let currentTermParam = "YHrxtTavu6raCwC0/qdgYffB9evWHBkTng/XS4W6j3f/TPo02iEPSoegscDTRNzIPRG49o3RHl4JiFCXAiBkkA=="
  private static let assignmentSQLID = "1713252980496efac7d5d9985e81693116d3e8a52ebf2b"
}

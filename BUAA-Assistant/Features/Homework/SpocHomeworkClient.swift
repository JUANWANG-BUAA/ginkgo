import Foundation

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

  init(session: URLSession = APIClient.shared.session) {
    self.session = session
  }

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
    struct Entry: Decodable { let jsdm: String? }

    let jsdm: String?
    let rolecode: String?
    let jsdmList: String?
    let roles: [Entry]

    private enum CodingKeys: String, CodingKey { case jsdm, rolecode, jsdmList, role }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      jsdm = Self.firstString(in: container, forKey: .jsdm)
      rolecode = Self.firstString(in: container, forKey: .rolecode)
      jsdmList = Self.firstString(in: container, forKey: .jsdmList)
      roles = (try? container.decode([Entry].self, forKey: .role)) ?? []
    }

    var resolvedCode: String? {
      jsdm ?? rolecode ?? jsdmList ?? roles.compactMap(\.jsdm).first(where: { $0.isEmpty == false })
    }

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
    guard let termCode = term.mrxq, !termCode.isEmpty else {
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.currentTerm.rawValue)
    }
    let courses = try await get(
      "/jxkj/queryKclb?kcmc=&xnxq=\(termCode)", headers: headers(token, role),
      type: [Course].self, stage: .courseList
    )
    guard courses.allSatisfy({ !$0.kcid.isEmpty && !$0.kcmc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.courseList.rawValue)
    }
    guard Set(courses.map(\.kcid)).count == courses.count else {
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.courseList.rawValue)
    }
    let courseMap = Dictionary(courses.map { ($0.kcid, $0) }, uniquingKeysWith: { first, _ in first })
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
      guard pageData.pages != nil || pageData.hasNextPage != nil else {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
      if let responsePage = pageData.pageNum, responsePage != page {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
      if let pages = pageData.pages, pages < page, !pageData.list.isEmpty {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
      guard pageData.list.allSatisfy({
        !$0.zyid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && !$0.zymc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }) else {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
      let hasNext: Bool
      if let explicitHasNext = pageData.hasNextPage {
        hasNext = explicitHasNext
        if let pages = pageData.pages, explicitHasNext != (page < pages) {
          throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
        }
      } else if let pages = pageData.pages {
        hasNext = page < pages
      } else {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
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
      if !hasNext { break }
      guard page < 100 else {
        throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.assignmentList.rawValue)
      }
      page += 1
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
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: Stage.casLogin.rawValue)
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
    let status = Self.mapSubmissionStatus(
      submission?.tjzt,
      hasSubmissionRecord: submission != nil,
      dueAt: dueAt
    )
    return HomeworkDetail(
      itemID: "spoc:\(assignmentID)",
      content: assignment.zynr.flatMap(HTMLText.multilineText),
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
    // 浏览器先加载 SPA，再一次性跟随 CAS 重定向链。当前上游会校验这次
    // 浏览及回调产生的 SPOC/WebVPN Cookie；只取中间 Location 会得到错误 UUID。
    if let landing = URL(string: "https://spoc.buaa.edu.cn/spocnew/") {
      var landingRequest = URLRequest(url: landing)
      landingRequest.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
      _ = try? await session.routedData(for: landingRequest)
    }

    guard let casURL = URL(string: "\(api)/cas") else {
      throw HomeworkError.spocFailure(stage: Stage.loginRedirect.rawValue, reason: "登录地址无效")
    }
    var request = URLRequest(url: casURL)
    request.timeoutInterval = 35
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    let (_, response) = try await requestData(request, using: session, stage: .loginRedirect)
    if let components = URLComponents(url: response.url ?? casURL, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
       token.isEmpty == false {
      AppLog.network.info("SPOC request succeeded stage=login_redirect")
      return token
    }

    let looksLikeLogin = response.statusCode == 200
    AppLog.network.error(
      "SPOC request failed stage=login_redirect http_status=\(response.statusCode, privacy: .public) outcome=\(looksLikeLogin ? "login_page" : "location_missing", privacy: .public)"
    )
    throw HomeworkError.spocFailure(stage: Stage.loginRedirect.rawValue, reason: "未收到有效登录跳转")
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
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      let shape = root.map { "keys=\($0.keys.sorted().joined(separator: ",")) code=\(String(describing: $0["code"])) msg=\(String(describing: $0["msg"]).prefix(80))" } ?? "non_object"
      AppLog.network.error(
        "SPOC request failed stage=\(stage.rawValue, privacy: .public) http_status=\(response.statusCode, privacy: .public) bytes=\(data.count) shape=\(shape, privacy: .public)"
      )
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
    stage: Stage,
    noRedirect: Bool = false
  ) async throws -> (Data, HTTPURLResponse) {
    do {
      let (data, response) = try await session.routedData(for: request, noRedirect: noRedirect)
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
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      let content = root?["content"]
      let contentType = content.map { String(describing: Swift.type(of: $0)) } ?? "nil"
      let shape = root.map { "keys=\($0.keys.sorted().joined(separator: ",")) code=\(String(describing: $0["code"])) content=\(contentType)" } ?? "non_object"
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) outcome=\(looksLikeHTML ? "html_response" : "invalid_json", privacy: .public) shape=\(shape)")
      if looksLikeHTML {
        throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "收到登录页面，请重新登录后重试")
      }
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: stage.rawValue)
    }
    guard envelope.code == 200 else {
      AppLog.network.error("SPOC request failed stage=\(stage.rawValue, privacy: .public) business_code=\(envelope.code)")
      if envelope.code == 401 || envelope.code == 403 {
        throw HomeworkError.spocAuthenticationExpired(stage: stage.rawValue)
      }
      throw HomeworkError.spocFailure(stage: stage.rawValue, reason: "业务响应未成功（\(envelope.code)）")
    }
    guard let content = envelope.content else {
      throw HomeworkError.upstreamProtocolChanged(source: .spoc, stage: stage.rawValue)
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
    return SchoolTime.date(
      from: value,
      formats: ["yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
    )
  }

  static func normalizeScore(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
      let range = value.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
    return String(value[range])
  }

  /// 列表接口只有 `tjzt`；详情接口另带提交记录。没有提交记录时才按截止时间推断待处理/逾期，
  /// 有记录但状态缺失时保持未知，不臆测为已提交；无法识别的上游原文保留在 detail 中。
  static func mapSubmissionStatus(
    _ rawStatus: String?,
    hasSubmissionRecord: Bool = false,
    dueAt: Date?,
    now: Date = Date()
  ) -> (status: HomeworkStatus, detail: String?) {
    switch rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "1", "已做", "已提交": return (.submitted, nil)
    case "0", "未做", "未提交", nil, "":
      guard hasSubmissionRecord else {
        return ((dueAt ?? .distantFuture) < now ? .overdue : .pending, nil)
      }
      return (.unknown, nil)
    case .some(let value): return (.unknown, value)
    }
  }

  private static func url(_ value: String, queryItems: [URLQueryItem]) -> URL {
    var components = URLComponents(string: value)!
    components.queryItems = queryItems
    return components.url!
  }
  /// 分页参数使用 AES-CBC + 零填充（不是 PKCS7），与 SPOC 前端一致（API.md §7.1）。
  static func encrypt(_ data: Data) -> String {
    var input = data
    input.append(Data(repeating: 0, count: (16 - data.count % 16) % 16))
    let encrypted = AESCipher.encrypt(
      input,
      key: Array("inco12345678ocni".utf8),
      mode: .cbc(iv: Array("ocni12345678inco".utf8)),
      pkcs7Padding: false
    )
    return encrypted?.base64EncodedString() ?? ""
  }
  private static let currentTermParam = "YHrxtTavu6raCwC0/qdgYffB9evWHBkTng/XS4W6j3f/TPo02iEPSoegscDTRNzIPRG49o3RHl4JiFCXAiBkkA=="
  private static let assignmentSQLID = "1713252980496efac7d5d9985e81693116d3e8a52ebf2b"
}

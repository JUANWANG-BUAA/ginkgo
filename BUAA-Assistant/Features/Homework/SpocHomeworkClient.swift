import Foundation
import CommonCrypto

struct SpocHomeworkClient {
  let session: URLSession
  private let api = "https://spoc.buaa.edu.cn/spocnewht"
  private let json = JSONDecoder()

  struct Envelope<T: Decodable>: Decodable { let code: Int; let content: T?; let msg: String? }
  struct Term: Decodable { let dqxq: String?; let mrxq: String? }
  struct Course: Decodable { let kcid: String; let kcmc: String }
  struct Page: Decodable { let pages: Int?; let pageNum: Int?; let hasNextPage: Bool?; let list: [Assignment] }
  struct Assignment: Decodable { let zyid: String; let tjzt: String?; let zyjzsj: String?; let zymc: String; let sskcid: String?; let kcmc: String? }
  struct Role: Decodable { let jsdm: String? }

  var items: [HomeworkItem] { get async throws { try await loadItems() } }
  func load() async throws -> HomeworkSnapshot { HomeworkSnapshot(items: try await loadItems(), fetchedAt: Date()) }

  private func loadItems() async throws -> [HomeworkItem] {
    let token = try await loginToken()
    let role = try await post( "/sys/casLogin", headers: ["Token": "Inco-\(token)"], body: ["token": token], type: Role.self).jsdm ?? ""
    guard !role.isEmpty else { throw HomeworkError.unavailable }
    let term = try await post("/inco/ht/queryOne", headers: headers(token, role), body: ["param": Self.currentTermParam], type: Term.self)
    guard let termCode = term.mrxq else { throw HomeworkError.unavailable }
    let courses = try await get("/jxkj/queryKclb?kcmc=&xnxq=\(termCode)", headers: headers(token, role), type: [Course].self)
    let names = Dictionary(uniqueKeysWithValues: courses.map { ($0.kcid, $0.kcmc) })
    var result: [HomeworkItem] = []
    var page = 1
    while true {
      let payload = ["pageSize": 15, "pageNum": page, "sqlid": Self.assignmentSQLID, "xnxq": termCode, "kcid": "", "yzwz": ""] as [String : Any]
      let data = try JSONSerialization.data(withJSONObject: payload)
      let encoded = Self.encrypt(data)
      let pageData = try await post("/inco/ht/queryListByPage", headers: headers(token, role), body: ["param": encoded], type: Page.self)
      result += pageData.list.map { assignment in
        let due = Self.date(assignment.zyjzsj)
        let submitted = ["1", "已做", "已提交"].contains(assignment.tjzt?.trimmingCharacters(in: .whitespaces))
        return HomeworkItem(id: "spoc:\(assignment.zyid)", courseName: assignment.kcmc ?? names[assignment.sskcid ?? ""] ?? "SPOC 课程", title: assignment.zymc, dueAt: due, sourceURL: nil, status: submitted ? .submitted : ((due ?? .distantFuture) < Date() ? .overdue : .pending), source: .spoc, fetchedAt: Date())
      }
      if pageData.hasNextPage != true && page >= (pageData.pages ?? page) { break }
      page += 1
      if page > 100 { break }
    }
    return result
  }

  private func loginToken() async throws -> String {
    var url = URL(string: "\(api)/cas")!
    for _ in 0..<8 {
      let (data, response) = try await APIClient.shared.noRedirectSession.data(from: url)
      guard let http = response as? HTTPURLResponse else { throw HomeworkError.unavailable }
      if let location = http.value(forHTTPHeaderField: "Location"), let next = URL(string: location, relativeTo: url)?.absoluteURL {
        if let components = URLComponents(url: next, resolvingAgainstBaseURL: false), next.path.contains("/spocnew/cas"), let token = components.queryItems?.first(where: { $0.name == "token" })?.value { return token }
        url = next; continue
      }
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let token = components.queryItems?.first(where: { $0.name == "token" })?.value { return token }
      _ = data
      throw HomeworkError.sessionExpired
    }
    throw HomeworkError.sessionExpired
  }

  private func headers(_ token: String, _ role: String) -> [String: String] { ["Token": "Inco-\(token)", "RoleCode": role, "X-Requested-With": "XMLHttpRequest"] }
  private func get<T: Decodable>(_ path: String, headers: [String: String], type: T.Type) async throws -> T {
    var request = URLRequest(url: URL(string: api + path)!)
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    let (data, response) = try await session.data(for: request); return try decode(data, response, type)
  }
  private func post<T: Decodable>(_ path: String, headers: [String: String], body: [String: Any], type: T.Type) async throws -> T {
    var request = URLRequest(url: URL(string: api + path)!); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }; request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await session.data(for: request); return try decode(data, response, type)
  }
  private func decode<T: Decodable>(_ data: Data, _ response: URLResponse, _ type: T.Type) throws -> T {
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw HomeworkError.unavailable }
    let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data); guard envelope.code == 200, let content = envelope.content else { throw HomeworkError.unavailable }; return content
  }
  private static func date(_ value: String?) -> Date? { guard let value else { return nil }; let formatter = ISO8601DateFormatter(); return formatter.date(from: value) ?? { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f.date(from: value) }() }
  static func encrypt(_ data: Data) -> String {
    var input = data
    input.append(Data(repeating: 0, count: (16 - data.count % 16) % 16))
    let outputCapacity = input.count + kCCBlockSizeAES128
    var output = Data(count: outputCapacity)
    var moved = 0
    let key = Array("inco12345678ocni".utf8)
    let iv = Array("ocni12345678inco".utf8)
    let inputCount = input.count
    input.withUnsafeBytes { inputBytes in
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

/// Direct Judge implementation ported from BBAA's LocalJudgeApiBackend.
struct JudgeHomeworkClient {
  let session: URLSession
  private let base = URL(string: "https://judge.buaa.edu.cn")!

  func load() async throws -> HomeworkSnapshot {
    let activation = URL(string: "https://sso.buaa.edu.cn/login?service=http%3A%2F%2Fjudge.buaa.edu.cn%2F")!
    let (_, activationResponse) = try await session.data(from: activation)
    guard let response = activationResponse as? HTTPURLResponse, response.statusCode == 200 else {
      throw HomeworkError.sessionExpired
    }
    let courses = try await getCourses()
    var items: [HomeworkItem] = []
    for course in courses {
      let assignments = try await getAssignments(course: course)
      for assignment in assignments {
        let detail = try await getDetail(courseID: course.id, assignmentID: assignment.id)
        let status: HomeworkStatus = detail.submitted ? .submitted : (detail.dueAt ?? .distantFuture < Date() ? .overdue : .pending)
        items.append(HomeworkItem(id: "judge:\(course.id):\(assignment.id)", courseName: course.name,
          title: assignment.title, dueAt: detail.dueAt, sourceURL: detail.url, status: status,
          source: .judge, fetchedAt: Date()))
      }
    }
    return HomeworkSnapshot(items: items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }, fetchedAt: Date())
  }

  private func getCourses() async throws -> [(id: String, name: String)] {
    let (data, response) = try await session.data(from: base.appendingPathComponent("courselist.jsp?courseID=0"))
    let html = try body(data, response)
    let pattern = try NSRegularExpression(pattern: #"courselist\.jsp\?courseID=(\d+)[^>]*>([\s\S]*?)</a>"#, options: .caseInsensitive)
    return matches(pattern, html).compactMap { m in
      guard m.count > 2, m[1] != "0" else { return nil }
      return (m[1], stripHTML(m[2]))
    }
  }

  private func getAssignments(course: (id: String, name: String)) async throws -> [(id: String, title: String)] {
    _ = try await session.data(from: base.appendingPathComponent("courselist.jsp?courseID=\(course.id)"))
    let (data, response) = try await session.data(from: base.appendingPathComponent("assignment/index.jsp"))
    let html = try body(data, response)
    let pattern = try NSRegularExpression(pattern: #"assignID=(\d+)[^>]*>([\s\S]*?)</a>"#, options: .caseInsensitive)
    return matches(pattern, html).map { ($0[1], stripHTML($0[2])) }.filter { !$0.1.isEmpty }
  }

  private func getDetail(courseID: String, assignmentID: String) async throws -> (dueAt: Date?, submitted: Bool, url: URL?) {
    let url = base.appendingPathComponent("assignment/index.jsp?assignID=\(assignmentID)")
    let (data, response) = try await session.data(from: url)
    let text = stripHTML(try body(data, response))
    let dates = try NSRegularExpression(pattern: #"作业时间[：:]\s*(\d{4}-\d\d-\d\d\s+\d\d:\d\d(?::\d\d)?)\s*至\s*(\d{4}-\d\d-\d\d\s+\d\d:\d\d(?::\d\d)?)"#).firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    let due: Date? = dates.flatMap { match in
      guard let range = Range(match.range(at: 2), in: text) else { return nil }
      let value = String(text[range])
      let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      return formatter.date(from: value.count == 16 ? value + ":00" : value)
    }
    let submitted = ["初次提交时间", "最后一次提交时间", "已提交", "得分"].contains { text.contains($0) }
    return (due, submitted, url)
  }

  private func body(_ data: Data, _ response: URLResponse) throws -> String {
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      let text = String(data: data, encoding: .utf8), !text.contains("统一身份认证") else { throw HomeworkError.sessionExpired }
    return text
  }

  private func matches(_ regex: NSRegularExpression, _ text: String) -> [[String]] {
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { match in
      (0..<match.numberOfRanges).map { index in
        guard let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
      }
    }
  }

  private func stripHTML(_ value: String) -> String {
    value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

import Foundation

protocol TermServing {
  func availableTerms() async throws -> [SchoolTerm]
}

protocol ScheduleServing {
  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot
}

actor ScheduleClient: ScheduleServing, TermServing {
  private let session: URLSession
  private let undergraduateBase = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/"
  private let graduateBase = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/"

  init(session: URLSession = APIClient.shared.session) { self.session = session }

  func load(termID: String? = nil, week: Int? = nil) async throws -> ScheduleSnapshot {
    // API.md §2.1：BYXT 最终地址同时用于判定账号所属门户。
    let probe = try await send(url: URL(string: undergraduateBase + "currentUser.do")!)
    let firstByte = probe.data.first(where: { !$0.isASCIIWhitespace }) ?? 0
    let portal: SchedulePortal = probe.response.url?.path.contains("/jwapp/sys/byrhmhsy/") == true
      ? .graduate : .undergraduate
    if portal == .graduate { return try await loadGraduate(termID: termID, week: week) }
    guard firstByte == 123 || firstByte == 91 else {
      // 某些账号的 BYXT 探测保持原地址并返回 HTML；用已验证的 GSMIS 入口复核。
      // GSMIS 不可用时仍保持“尚未确认”，不将 HTML 当作空课表。
      do { return try await loadGraduate(termID: termID, week: week) }
      catch { throw error }
    }
    return try await loadUndergraduate(termID: termID, week: week)
  }

  func availableTerms() async throws -> [SchoolTerm] {
    let probe = try await send(url: URL(string: undergraduateBase + "currentUser.do")!)
    let first = probe.data.first(where: { !$0.isASCIIWhitespace }) ?? 0
    if probe.response.url?.path.contains("/jwapp/sys/byrhmhsy/") != true, first == 123 || first == 91 {
      let data = try await send(url: URL(string: undergraduateBase + "student/schoolCalendars.do")!, ajaxReferer: byxtReferer).data
      return try ScheduleParser.terms(data, portal: .undergraduate)
    }
    let entry = URL(string: graduateBase + "*default/index.do")!
    _ = try await send(url: entry)
    let data = try await send(url: URL(string: graduateBase + "modules/xskcb/kfdxnxqcx.do")!, fields: [], ajaxReferer: entry.absoluteString).data
    return try ScheduleParser.terms(data, portal: .graduate)
  }

  private func loadUndergraduate(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    // API.md §2.2：学期列表使用 BYXT Ajax 请求头。
    let termsData = try await send(url: URL(string: undergraduateBase + "student/schoolCalendars.do")!, ajaxReferer: byxtReferer).data
    let terms: [SchoolTerm]
    do { terms = try ScheduleParser.terms(termsData, portal: .undergraduate) }
    catch { throw ScheduleError.changedResponseAt("本科学期列表") }
    guard let term = terms.first(where: { $0.id == termID }) ?? terms.first(where: \.isSelected) ?? terms.first else {
      throw ScheduleError.invalidTerm
    }
    var components = URLComponents(string: undergraduateBase + "getTermWeeks.do")!
    components.queryItems = [URLQueryItem(name: "termCode", value: term.id)]
    // API.md §2.3：周次列表。
    let weeksData = try await send(url: components.url!, ajaxReferer: byxtReferer).data
    let weeks: [SchoolWeek]
    do { weeks = try ScheduleParser.weeks(weeksData) }
    catch { throw ScheduleError.changedResponseAt("本科周次列表") }
    guard let selected = weeks.first(where: { $0.number == week }) ?? weeks.first(where: \.isCurrent) ?? weeks.first else {
      throw ScheduleError.changedResponse
    }
    // API.md §2.4：每次仅请求当前选择的一周。
    let scheduleData = try await send(url: URL(string: undergraduateBase + "student/getMyScheduleDetail.do")!,
                                      fields: [("termCode", term.id), ("type", "week"), ("week", String(selected.number))],
                                      ajaxReferer: byxtReferer).data
    let courses: [CourseMeeting]
    do { courses = try ScheduleParser.undergraduateCourses(scheduleData) }
    catch { throw ScheduleError.changedResponseAt("本科周课表") }
    return ScheduleSnapshot(portal: .undergraduate, terms: terms, termID: term.id, weeks: weeks,
                            weekNumber: selected.number, courses: courses, fetchedAt: Date())
  }

  private func loadGraduate(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    let entry = URL(string: graduateBase + "*default/index.do")!
    // API.md §3.1：激活 GSMIS 会话并检测 SSO 登录页。
    _ = try await send(url: entry)
    // API.md §3.2：研究生学期列表 POST 空表单。
    let termsData = try await send(url: URL(string: graduateBase + "modules/xskcb/kfdxnxqcx.do")!,
                                   fields: [], ajaxReferer: entry.absoluteString).data
    let terms: [SchoolTerm]
    do { terms = try ScheduleParser.terms(termsData, portal: .graduate) }
    catch { throw ScheduleError.changedResponseAt("研究生学期列表") }
    guard let term = terms.first(where: { $0.id == termID }) ?? terms.first else { throw ScheduleError.invalidTerm }
    // API.md §3.3：除学期码外，ZC/XH/XQDM 必须为空。
    let data = try await send(url: URL(string: graduateBase + "bykb/loadXskbData.do")!,
                              fields: [("ZC", ""), ("XNXQDM", term.id), ("XH", ""), ("XQDM", "")],
                              ajaxReferer: entry.absoluteString).data
    let weeks: [SchoolWeek]
    do { weeks = try ScheduleParser.graduateWeeks(data, termID: term.id) }
    catch { throw ScheduleError.changedResponseAt("研究生周次") }
    guard let selected = weeks.first(where: { $0.number == week }) ?? weeks.first(where: \.isCurrent) ?? weeks.first else {
      throw ScheduleError.changedResponse
    }
    let courses: [CourseMeeting]
    do { courses = try ScheduleParser.graduateCourses(data, termID: term.id, week: selected.number) }
    catch { throw ScheduleError.changedResponseAt("研究生课表") }
    return ScheduleSnapshot(portal: .graduate, terms: terms, termID: term.id, weeks: weeks,
                            weekNumber: selected.number, courses: courses, fetchedAt: Date(),
                            termCourses: try Dictionary(uniqueKeysWithValues: weeks.map {
                              (String($0.number), try ScheduleParser.graduateCourses(data, termID: term.id, week: $0.number))
                            }))
  }

  private var byxtReferer: String { "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html" }

  private func send(url: URL, fields: [(String, String)]? = nil, ajaxReferer: String? = nil) async throws -> (data: Data, response: HTTPURLResponse) {
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    if let fields {
      request.httpMethod = "POST"
      request.httpBody = fields.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&").data(using: .utf8)
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
    if let ajaxReferer {
      request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
      request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
      request.setValue(ajaxReferer, forHTTPHeaderField: "Referer")
    }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw ScheduleError.changedResponse }
    if http.statusCode == 401 || http.statusCode == 403 { throw ScheduleError.sessionExpired }
    guard (200..<300).contains(http.statusCode) else { throw ScheduleError.unavailable(url.host ?? "课表服务") }
    if http.url?.host == "sso.buaa.edu.cn" ||
        String(data: data.prefix(5000), encoding: .utf8)?.contains("name=\"execution\"") == true {
      throw ScheduleError.sessionExpired
    }
    return (data, http)
  }

  private func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
  }
}

private extension UInt8 {
  var isASCIIWhitespace: Bool { self == 9 || self == 10 || self == 13 || self == 32 }
}

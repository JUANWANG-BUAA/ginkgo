import Foundation

protocol TermServing {
  func availableTerms() async throws -> [SchoolTerm]
}

protocol ScheduleServing {
  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot
}

protocol ExamServing {
  func loadExams(termID: String) async throws -> [Exam]
}

actor ScheduleClient: ScheduleServing, TermServing, ExamServing {
  private let session: URLSession
  private let undergraduateBase = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/"
  private let graduateBase = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/"

  init(session: URLSession = APIClient.shared.session) { self.session = session }

  func load(termID: String? = nil, week: Int? = nil) async throws -> ScheduleSnapshot {
    switch try await probePortal() {
    case .undergraduate:
      return try await loadUndergraduate(termID: termID, week: week)
    case .graduate, .unconfirmed:
      // 未确认时用已验证的 GSMIS 入口复核；GSMIS 不可用时仍保持“尚未确认”，不把 HTML 当作空课表。
      return try await loadGraduate(termID: termID, week: week)
    }
  }

  func availableTerms() async throws -> [SchoolTerm] {
    try await probePortal() == .undergraduate ? undergraduateTerms() : graduateTerms()
  }

  func loadExams(termID: String) async throws -> [Exam] {
    switch try await probePortal() {
    case .undergraduate: break
    case .graduate: throw ScheduleError.unsupportedPortal
    case .unconfirmed: throw ScheduleError.changedResponseAt("本科门户身份确认")
    }
    var components = URLComponents(string: undergraduateBase + "student/exams.do")!
    components.queryItems = [URLQueryItem(name: "termCode", value: termID)]
    let data = try await send(url: components.url!, ajaxReferer: examReferer, accept: "*/*").data
    return try parseResponse("exams") { try ScheduleParser.exams(data) }
  }

  private enum PortalProbe { case undergraduate, graduate, unconfirmed }

  /// API.md §2.1：BYXT 的最终地址同时用于判定账号所属门户。研究生账号会被带到 byrhmhsy；
  /// 部分账号保持原地址却返回 HTML，此时不能确认为本科门户。
  private func probePortal() async throws -> PortalProbe {
    let probe = try await send(url: URL(string: undergraduateBase + "currentUser.do")!)
    if probe.response.url?.path.contains("/jwapp/sys/byrhmhsy/") == true { return .graduate }
    let firstByte = probe.data.first(where: { !$0.isASCIIWhitespace })
    return firstByte == UInt8(ascii: "{") || firstByte == UInt8(ascii: "[") ? .undergraduate : .unconfirmed
  }

  /// API.md §2.2：学期列表使用 BYXT Ajax 请求头。
  private func undergraduateTerms() async throws -> [SchoolTerm] {
    let data = try await send(url: URL(string: undergraduateBase + "student/schoolCalendars.do")!, ajaxReferer: byxtReferer).data
    return try parseResponse("undergraduate_terms") { try ScheduleParser.terms(data, portal: .undergraduate) }
  }

  /// API.md §3.1：先激活 GSMIS 会话并检测 SSO 登录页；§3.2：学期列表 POST 空表单。
  private func graduateTerms() async throws -> [SchoolTerm] {
    _ = try await send(url: graduateEntry)
    let data = try await send(url: URL(string: graduateBase + "modules/xskcb/kfdxnxqcx.do")!,
                              fields: [], ajaxReferer: graduateEntry.absoluteString).data
    return try parseResponse("graduate_terms") { try ScheduleParser.terms(data, portal: .graduate) }
  }

  private func loadUndergraduate(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    let terms = try await undergraduateTerms()
    guard let term = terms.first(where: { $0.id == termID }) ?? terms.first(where: \.isSelected) ?? terms.first else {
      throw ScheduleError.invalidTerm
    }
    var components = URLComponents(string: undergraduateBase + "getTermWeeks.do")!
    components.queryItems = [URLQueryItem(name: "termCode", value: term.id)]
    // API.md §2.3：周次列表。
    let weeksData = try await send(url: components.url!, ajaxReferer: byxtReferer).data
    let weeks = try parseResponse("undergraduate_weeks") {
      try ScheduleParser.weeks(weeksData)
    }
    guard let selected = weeks.first(where: { $0.number == week }) ?? weeks.first(where: \.isCurrent) ?? weeks.first else {
      throw ScheduleError.changedResponse
    }
    // API.md §2.4：每次仅请求当前选择的一周。
    let scheduleData = try await send(url: URL(string: undergraduateBase + "student/getMyScheduleDetail.do")!,
                                      fields: [("termCode", term.id), ("type", "week"), ("week", String(selected.number))],
                                      ajaxReferer: byxtReferer).data
    let courses = try parseResponse("undergraduate_courses") {
      try ScheduleParser.undergraduateCourses(scheduleData)
    }
    return ScheduleSnapshot(portal: .undergraduate, terms: terms, termID: term.id, weeks: weeks,
                            weekNumber: selected.number, courses: courses, fetchedAt: Date())
  }

  private func loadGraduate(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    let terms = try await graduateTerms()
    guard let term = terms.first(where: { $0.id == termID }) ?? terms.first else { throw ScheduleError.invalidTerm }
    // API.md §3.3：除学期码外，ZC/XH/XQDM 必须为空；一次返回整学期排课。
    let data = try await send(url: URL(string: graduateBase + "bykb/loadXskbData.do")!,
                              fields: [("ZC", ""), ("XNXQDM", term.id), ("XH", ""), ("XQDM", "")],
                              ajaxReferer: graduateEntry.absoluteString).data
    let weeks = try parseResponse("graduate_weeks") {
      try ScheduleParser.graduateWeeks(data, termID: term.id)
    }
    guard !weeks.isEmpty else {
      return ScheduleSnapshot(portal: .graduate, terms: terms, termID: term.id, weeks: [],
                              weekNumber: 1, courses: [], fetchedAt: Date())
    }
    guard let selected = weeks.first(where: { $0.number == week }) ?? weeks.first(where: \.isCurrent) ?? weeks.first else {
      throw ScheduleError.changedResponse
    }
    let termCourses = try Dictionary(uniqueKeysWithValues: weeks.map { week in
      (String(week.number), try parseResponse("graduate_courses") {
        try ScheduleParser.graduateCourses(data, termID: term.id, week: week.number)
      })
    })
    return ScheduleSnapshot(portal: .graduate, terms: terms, termID: term.id, weeks: weeks,
                            weekNumber: selected.number, courses: termCourses[String(selected.number)] ?? [],
                            fetchedAt: Date(), termCourses: termCourses)
  }

  private var graduateEntry: URL { URL(string: graduateBase + "*default/index.do")! }
  private var byxtReferer: String { "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html" }
  private var examReferer: String { "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/home/index.html" }

  private func parseResponse<T>(_ stage: String, _ parse: () throws -> T) throws -> T {
    do {
      return try parse()
    } catch let error as ScheduleError {
      switch error {
      case .unavailable, .sessionExpired, .unsupportedPortal, .invalidTerm:
        throw error
      case .changedResponse, .changedResponseAt:
        AppLog.responseFormatChanged(feature: "schedule", stage: stage)
        throw ScheduleError.changedResponseAt(stage)
      }
    } catch {
      AppLog.responseFormatChanged(feature: "schedule", stage: stage)
      throw ScheduleError.changedResponseAt(stage)
    }
  }

  private func send(
    url: URL,
    fields: [(String, String)]? = nil,
    ajaxReferer: String? = nil,
    accept: String = "application/json, text/javascript, */*; q=0.01"
  ) async throws -> (data: Data, response: HTTPURLResponse) {
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    if let fields {
      request.httpMethod = "POST"
      request.httpBody = FormURLEncoding.body(fields)
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
    if let ajaxReferer {
      request.setValue(accept, forHTTPHeaderField: "Accept")
      request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
      request.setValue(ajaxReferer, forHTTPHeaderField: "Referer")
    }
    let (data, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse else { throw ScheduleError.unavailable(url.host ?? "课表服务") }
    if http.statusCode == 401 || http.statusCode == 403 { throw ScheduleError.sessionExpired }
    guard (200..<300).contains(http.statusCode) else { throw ScheduleError.unavailable(url.host ?? "课表服务") }
    if CasPageParser.isLoginRedirect(url: http.url, data: data) { throw ScheduleError.sessionExpired }
    return (data, http)
  }
}

private extension UInt8 {
  var isASCIIWhitespace: Bool { self == 9 || self == 10 || self == 13 || self == 32 }
}

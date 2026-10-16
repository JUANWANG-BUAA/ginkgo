import Foundation

/// Read-only Judge client aligned with BBAA's LocalJudgeApiBackend.
struct JudgeHomeworkClient {
  let session: URLSession
  private let base = URL(string: "https://judge.buaa.edu.cn")!

  func load() async throws -> HomeworkSnapshot {
    try await activateSession()
    let courses = try await getCourses()
    var items: [HomeworkItem] = []
    for course in courses {
      let assignments = try await getAssignments(course: course)
      for assignment in assignments {
        let id = "judge:\(course.id):\(assignment.id)"
        let detail = try await getDetail(
          itemID: id, courseID: course.id, assignmentID: assignment.id
        )
        items.append(HomeworkItem(
          id: id, courseName: course.name, title: assignment.title, dueAt: detail.dueAt,
          sourceURL: assignmentURL(assignment.id),
          status: detail.submissionStatus ?? .unknown, source: .judge, fetchedAt: Date(),
          publishedAt: detail.publishedAt, score: detail.score
        ))
      }
    }
    return HomeworkSnapshot(
      items: items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) },
      fetchedAt: Date()
    )
  }

  func loadDetail(
    itemID: String,
    courseID: String,
    assignmentID: String
  ) async throws -> HomeworkDetail {
    try await activateSession()
    return try await getDetail(
      itemID: itemID, courseID: courseID, assignmentID: assignmentID
    )
  }

  static func parseDetail(html: String, itemID: String) -> HomeworkDetail {
    let text = plainText(html)
    let timePattern = #"作业时间[：:]\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s*至\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)"#
    let dateMatch = firstMatch(timePattern, in: text)
    let publishedAt = dateMatch.flatMap { date(in: $0[safe: 1]) }
    let dueAt = dateMatch.flatMap { date(in: $0[safe: 2]) }
    let maxScore = firstMatch(#"作业满分[：:]\s*([\d.]+)"#, in: text)?[safe: 1]
    let totalFromText = firstMatch(#"共\s*(\d+)\s*道"#, in: text)?[safe: 1].flatMap(Int.init)
    let explicitScore = firstMatch(#"总分[：:]\s*([\d.]+)"#, in: text)?[safe: 1]
    let problems = parseProblems(html)
    let total = (totalFromText ?? 0) > 0 ? totalFromText : (problems.isEmpty ? nil : problems.count)
    let submittedCount = problems.isEmpty
      ? estimateSubmittedCount(text)
      : problems.filter { $0.status == .submitted }.count
    let status: HomeworkStatus
    if let total, total > 0, submittedCount >= total {
      status = .submitted
    } else if let dueAt, dueAt < Date() {
      status = .overdue
    } else if total == nil {
      status = .unknown
    } else {
      status = .pending
    }
    let earnedScore = explicitScore ?? scoreTotal(problems.compactMap(\.earnedScore))
    let submittedAt = firstMatch(
      #"(?:初次|首次|最近一次|最后一次)提交时间[：:]?\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)"#,
      in: text
    ).flatMap { date(in: $0[safe: 1]) }

    return HomeworkDetail(
      itemID: itemID, content: text.isEmpty ? nil : text,
      submissionStatus: status, submittedAt: submittedAt, score: maxScore,
      publishedAt: publishedAt, dueAt: dueAt, fetchedAt: Date(),
      earnedScore: earnedScore, totalProblems: total, submittedCount: total == nil ? nil : submittedCount,
      problems: problems
    )
  }

  private func activateSession() async throws {
    let activation = URL(string: "https://sso.buaa.edu.cn/login?service=http%3A%2F%2Fjudge.buaa.edu.cn%2F")!
    let (_, response) = try await session.data(from: activation)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw HomeworkError.sessionExpired
    }
  }

  private func getCourses() async throws -> [(id: String, name: String)] {
    let (data, response) = try await session.data(from: courseURL("0"))
    let html = try body(data, response)
    let pattern = #"courselist\.jsp\?courseID=(\d+)[^>]*>([\s\S]*?)</a>"#
    let matches = Self.captures(pattern, in: html)
    if matches.isEmpty && !Self.containsEmptyState(in: html, markers: ["暂无课程", "没有课程", "当前学期暂无教学班", "没有符合条件的课程"]) {
      throw HomeworkError.upstreamProtocolChanged(source: .judge, stage: "课程列表")
    }
    return matches.compactMap { match in
      guard let id = match[safe: 1], id != "0", let rawName = match[safe: 2] else { return nil }
      let name = Self.cleanText(rawName)
      return name.isEmpty ? nil : (id, name)
    }
  }

  private func getAssignments(course: (id: String, name: String)) async throws -> [(id: String, title: String)] {
    let (_, selectionResponse) = try await session.data(from: courseURL(course.id))
    guard (selectionResponse as? HTTPURLResponse)?.statusCode == 200 else { throw HomeworkError.unavailable }
    let (data, response) = try await session.data(from: base.appendingPathComponent("assignment/index.jsp"))
    let html = try body(data, response)
    let pattern = #"assignID=(\d+)[^>]*>([\s\S]*?)</a>"#
    let matches = Self.captures(pattern, in: html)
    if matches.isEmpty && !Self.containsEmptyState(in: html, markers: ["暂无作业", "没有作业", "暂无待完成作业", "没有待完成作业"]) {
      throw HomeworkError.upstreamProtocolChanged(source: .judge, stage: "作业列表")
    }
    return matches.compactMap { match in
      guard let id = match[safe: 1], let rawTitle = match[safe: 2] else { return nil }
      let title = Self.cleanText(rawTitle)
      return title.isEmpty ? nil : (id, title)
    }
  }

  private func getDetail(
    itemID: String, courseID: String, assignmentID: String
  ) async throws -> HomeworkDetail {
    let (_, selectionResponse) = try await session.data(from: courseURL(courseID))
    guard (selectionResponse as? HTTPURLResponse)?.statusCode == 200 else { throw HomeworkError.unavailable }
    let (data, response) = try await session.data(from: assignmentURL(assignmentID))
    return Self.parseDetail(html: try body(data, response), itemID: itemID)
  }

  private func assignmentURL(_ assignmentID: String) -> URL {
    var components = URLComponents(url: base.appendingPathComponent("assignment/index.jsp"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "assignID", value: assignmentID)]
    return components.url!
  }

  private func courseURL(_ courseID: String) -> URL {
    var components = URLComponents(url: base.appendingPathComponent("courselist.jsp"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "courseID", value: courseID)]
    return components.url!
  }

  private func body(_ data: Data, _ response: URLResponse) throws -> String {
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
          let html = String(data: data, encoding: .utf8),
          !html.localizedCaseInsensitiveContains("统一身份认证") else {
      throw HomeworkError.sessionExpired
    }
    return html
  }

  private static func parseProblems(_ html: String) -> [HomeworkProblem] {
    Self.topLevelTables(in: html).enumerated().flatMap { tableIndex, table -> [HomeworkProblem] in
      let flattened = removeNestedTables(table)
      return captures(#"<tr\b[^>]*>([\s\S]*?)</tr>"#, in: flattened).enumerated().compactMap { rowIndex, row -> HomeworkProblem? in
        guard let rowHTML = row[safe: 1] else { return nil }
        let cells = captures(#"<(?:th|td)\b[^>]*>([\s\S]*?)</(?:th|td)>"#, in: rowHTML)
          .compactMap { $0[safe: 1] }.map(cleanText)
        return parseProblem(cells, id: "\(tableIndex)-\(rowIndex)")
      }
    }
  }

  private static func parseProblem(_ cells: [String], id: String) -> HomeworkProblem? {
    let unsubmittedMarkers = ["还未提交代码", "未提交文件", "未提交答案", "未作答", "未提交"]
    let submittedMarkers = ["初次提交时间", "首次提交时间", "最近一次提交时间", "最后一次提交时间", "最后一次修改时间", "已提交", "得分", "Accepted", "Accept"]
    let name: String
    let maxScore: String?
    let statusText: String
    if cells.count >= 4 {
      name = cells[1]
      maxScore = number(cells[2])
      statusText = cells.dropFirst(3).joined(separator: " ")
    } else if cells.count == 2 {
      name = cells[0].isEmpty ? "题目" : "第\(cells[0].trimmingCharacters(in: CharacterSet(charactersIn: ". ")))题"
      maxScore = nil
      statusText = cells[1]
    } else {
      return nil
    }
    let status: HomeworkStatus
    if unsubmittedMarkers.contains(where: statusText.contains) {
      status = .pending
    } else if submittedMarkers.contains(where: { statusText.localizedCaseInsensitiveContains($0) }) {
      status = .submitted
    } else {
      return nil
    }
    let earned = firstMatch(#"得分[：:]\s*([\d.]+)"#, in: statusText)?[safe: 1]
      ?? (status == .submitted && cells.count >= 4 ? maxScore : nil)
    return HomeworkProblem(
      id: id, name: name,
      earnedScore: earned, maxScore: maxScore ?? earned, status: status,
      statusText: status == .submitted ? "已提交" : "未提交"
    )
  }

  private static func topLevelTables(in html: String) -> [String] {
    var depth = 0
    var start: String.Index?
    var tables: [String] = []
    let regex = try! NSRegularExpression(pattern: #"</?table\b[^>]*>"#, options: .caseInsensitive)
    let nsRange = NSRange(html.startIndex..., in: html)
    for match in regex.matches(in: html, range: nsRange) {
      guard let range = Range(match.range, in: html) else { continue }
      let tag = String(html[range])
      if tag.hasPrefix("</") {
        depth -= 1
        if depth == 0, let tableStart = start {
          tables.append(String(html[tableStart..<range.upperBound]))
          start = nil
        }
      } else {
        if depth == 0 { start = range.lowerBound }
        depth += 1
      }
    }
    return tables
  }

  private static func removeNestedTables(_ html: String) -> String {
    let regex = try! NSRegularExpression(pattern: #"</?table\b[^>]*>"#, options: .caseInsensitive)
    var output = ""
    var depth = 0
    var cursor = html.startIndex
    for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
      guard let range = Range(match.range, in: html) else { continue }
      if depth <= 1 { output += html[cursor..<range.lowerBound] }
      let tag = html[range]
      if tag.hasPrefix("</") { depth -= 1 } else { depth += 1 }
      if depth <= 1 { output += tag }
      cursor = range.upperBound
    }
    if depth <= 1 { output += html[cursor...] }
    return output
  }

  private static func estimateSubmittedCount(_ text: String) -> Int {
    let sections = ["填空题", "编程题", "文件上传题"].compactMap { text.range(of: $0)?.lowerBound }
    let choiceEnd = sections.min() ?? text.endIndex
    let choice = countMatches(#"得分[：:]\s*[\d.]+"#, in: String(text[..<choiceEnd]))
    let fillStart = text.range(of: "填空题")?.lowerBound
    var fill = 0
    if let fillStart {
      let fillEnd = [text.range(of: "编程题", range: fillStart..<text.endIndex)?.lowerBound,
                     text.range(of: "文件上传题", range: fillStart..<text.endIndex)?.lowerBound]
        .compactMap { $0 }.min() ?? text.endIndex
      fill = countMatches(#"得分[：:]\s*[\d.]+"#, in: String(text[fillStart..<fillEnd]))
    }
    let programmingStart = text.range(of: "编程题")?.lowerBound
    let fileStart = text.range(of: "文件上传题")?.lowerBound
    let programming = programmingStart.map { start in
      countMatches(#"最后一次提交时间"#, in: String(text[start..<(fileStart ?? text.endIndex)]))
    } ?? 0
    let files = fileStart.map { countMatches(#"初次提交时间"#, in: String(text[$0...])) } ?? 0
    return choice + fill + programming + files
  }

  private static func number(_ text: String) -> String? {
    let value = cleanText(text)
    return value.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) == nil ? nil : value
  }

  private static func plainText(_ html: String) -> String {
    html.replacingOccurrences(of: #"<script\b[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"</(?:p|div|tr|li|h[1-6])\s*>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func cleanText(_ value: String) -> String { plainText(value) }
  private static func containsEmptyState(in html: String, markers: [String]) -> Bool {
    markers.contains { html.localizedCaseInsensitiveContains($0) }
  }

  private static func date(in value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
      formatter.dateFormat = format
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }

  private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
    captures(pattern, in: text).first
  }

  private static func captures(_ pattern: String, in text: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
      (0..<match.numberOfRanges).map { index in
        guard let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
      }
    }
  }

  private static func countMatches(_ pattern: String, in text: String) -> Int { captures(pattern, in: text).count }

  private static func scoreTotal(_ values: [String]) -> String? {
    let numbers = values.compactMap(Double.init)
    guard !numbers.isEmpty else { return nil }
    let sum = numbers.reduce(0, +)
    return sum.rounded() == sum ? String(Int(sum)) : String(sum)
  }
}

private extension Array where Element == String {
  subscript(safe index: Int) -> String? { indices.contains(index) ? self[index] : nil }
}

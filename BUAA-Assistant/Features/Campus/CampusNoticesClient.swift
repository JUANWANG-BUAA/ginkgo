import Foundation

struct CampusNotice: Identifiable, Equatable, Codable {
  let id: String
  let title: String
  let summary: String
  let publishedAt: String
  let url: URL
}

enum CampusNoticesError: LocalizedError {
  case unavailable
  case changedResponse

  var errorDescription: String? {
    switch self {
    case .unavailable: "北航新闻网暂时不可用，请稍后重试"
    case .changedResponse: "北航通知页面格式无法识别，官网可能已调整；请重试，若持续出现请反馈"
    }
  }
}

actor CampusNoticesClient {
  private let session: URLSession
  private let url = URL(string: "https://news.buaa.edu.cn/tzgg.htm")!

  init(session: URLSession? = nil) {
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.httpCookieStorage = nil
      configuration.urlCache = nil
      configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
      configuration.timeoutIntervalForRequest = 15
      configuration.timeoutIntervalForResource = 20
      self.session = URLSession(configuration: configuration)
    }
  }

  func load() async throws -> [CampusNotice] {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
          http.url?.host == url.host else {
      throw CampusNoticesError.unavailable
    }
    guard let html = String(data: data, encoding: .utf8) else {
      AppLog.responseFormatChanged(feature: "campus-notices", stage: "html_encoding")
      throw CampusNoticesError.changedResponse
    }
    let result = CampusNoticeParser.analyze(html, baseURL: url)
    let notices = result.notices
    guard !notices.isEmpty, result.candidateCount <= notices.count else {
      AppLog.responseFormatChanged(feature: "campus-notices", stage: "notice_list")
      throw CampusNoticesError.changedResponse
    }
    return Array(notices.prefix(5))
  }
}

enum CampusNoticeParser {
  static func parse(_ html: String, baseURL: URL) -> [CampusNotice] {
    analyze(html, baseURL: baseURL).notices
  }

  static func analyze(_ html: String, baseURL: URL) -> (notices: [CampusNotice], candidateCount: Int) {
    let rows = matches(#"<li\b[^>]*>(.*?)</li>"#, in: html)
    let candidateCount = rows.filter { row in
      guard firstCapture(#"<h3\b[^>]*>(.*?)</h3>"#, in: row) != nil else { return false }
      guard let rawLink = firstCapture(#"<a\b[^>]*href=[\"']([^\"']+)[\"']"#, in: row) else {
        return row.localizedCaseInsensitiveContains("pub_date")
      }
      guard let link = URL(string: decodeEntities(rawLink), relativeTo: baseURL)?.absoluteURL else { return true }
      return link.host == baseURL.host && link.scheme != "javascript"
    }.count
    let notices: [CampusNotice] = rows.compactMap { row -> CampusNotice? in
      guard let rawLink = firstCapture(#"<a\b[^>]*href=[\"']([^\"']+)[\"']"#, in: row),
            let link = URL(string: decodeEntities(rawLink), relativeTo: baseURL)?.absoluteURL,
            link.scheme == "https", link.host == baseURL.host,
            let titleHTML = firstCapture(#"<h3\b[^>]*>(.*?)</h3>"#, in: row),
            let dayText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<b\b[^>]*>(\d{1,2})</b>"#, in: row),
            let monthText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<span\b[^>]*>(\d{4})\.(\d{1,2})</span>"#, group: 2, in: row),
            let yearText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<span\b[^>]*>(\d{4})\.(\d{1,2})</span>"#, group: 1, in: row),
            let day = Int(decodeEntities(dayText)),
            let month = Int(decodeEntities(monthText)),
            let year = Int(decodeEntities(yearText)),
            let published = formattedDate(year: year, month: month, day: day) else {
        return nil
      }
      let summaryHTML = firstCapture(#"<p\b[^>]*>(.*?)</p>"#, in: row) ?? ""
      let title = plainText(titleHTML)
      guard !title.isEmpty else { return nil }
      return CampusNotice(
        id: link.absoluteString,
        title: title,
        summary: plainText(summaryHTML),
        publishedAt: published,
        url: link
      )
    }
    return (notices, candidateCount)
  }

  private static func formattedDate(year: Int, month: Int, day: Int) -> String? {
    guard (1...12).contains(month), (1...31).contains(day) else { return nil }
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(identifier: "Asia/Shanghai")
    components.year = year
    components.month = month
    components.day = day
    guard let date = components.date else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = components.timeZone ?? .current
    guard calendar.component(.year, from: date) == year,
          calendar.component(.month, from: date) == month,
          calendar.component(.day, from: date) == day else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = components.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func plainText(_ value: String) -> String {
    let withoutTags = replacing(#"<[^>]+>"#, in: value, with: " ")
    return decodeEntities(withoutTags)
      .replacingOccurrences(of: "\u{00a0}", with: " ")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func decodeEntities(_ value: String) -> String {
    let named: [(String, String)] = [
      ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
      ("&#39;", "'"), ("&apos;", "'"), ("&amp;", "&")
    ]
    var result = value
    for (entity, replacement) in named {
      result = result.replacingOccurrences(of: entity, with: replacement)
    }
    let pattern = #"&#(?:x([0-9a-fA-F]+)|(\d+));"#
    let regex = try? NSRegularExpression(pattern: pattern)
    let nsValue = result as NSString
    for match in (regex?.matches(in: result, range: NSRange(location: 0, length: nsValue.length)) ?? []).reversed() {
      let hexRange = match.range(at: 1)
      let decimalRange = match.range(at: 2)
      let raw = hexRange.location != NSNotFound
        ? nsValue.substring(with: hexRange)
        : nsValue.substring(with: decimalRange)
      let radix = hexRange.location != NSNotFound ? 16 : 10
      guard let scalarValue = UInt32(raw, radix: radix), let scalar = UnicodeScalar(scalarValue) else { continue }
      result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
    }
    return result
  }

  private static func firstCapture(_ pattern: String, in value: String) -> String? {
    firstCapture(pattern, group: 1, in: value)
  }

  private static func firstCapture(_ pattern: String, group: Int, in value: String) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
    let nsValue = value as NSString
    guard let match = regex?.firstMatch(in: value, range: NSRange(location: 0, length: nsValue.length)),
          group < match.numberOfRanges,
          match.range(at: group).location != NSNotFound else { return nil }
    return nsValue.substring(with: match.range(at: group))
  }

  private static func matches(_ pattern: String, in value: String) -> [String] {
    let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
    let nsValue = value as NSString
    return (regex?.matches(in: value, range: NSRange(location: 0, length: nsValue.length)) ?? []).compactMap { match in
      guard match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
      return nsValue.substring(with: match.range(at: 1))
    }
  }

  private static func replacing(_ pattern: String, in value: String, with replacement: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
      return value
    }
    return regex.stringByReplacingMatches(
      in: value,
      range: NSRange(location: 0, length: (value as NSString).length),
      withTemplate: replacement
    )
  }
}

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
  private let allowsGlobalRouting: Bool
  private let url = URL(string: "https://news.buaa.edu.cn/tzgg.htm")!

  init(session: URLSession? = nil) {
    self.allowsGlobalRouting = session == nil
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
    let (data, response) = try await session.routedData(for: request, allowWebVPN: allowsGlobalRouting)
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
      guard let link = URL(string: HTMLText.decodeEntities(rawLink), relativeTo: baseURL)?.absoluteURL else { return true }
      return link.host == baseURL.host && link.scheme != "javascript"
    }.count
    let notices: [CampusNotice] = rows.compactMap { row -> CampusNotice? in
      guard let rawLink = firstCapture(#"<a\b[^>]*href=[\"']([^\"']+)[\"']"#, in: row),
            let link = URL(string: HTMLText.decodeEntities(rawLink), relativeTo: baseURL)?.absoluteURL,
            link.scheme == "https", link.host == baseURL.host,
            let titleHTML = firstCapture(#"<h3\b[^>]*>(.*?)</h3>"#, in: row),
            let dayText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<b\b[^>]*>(\d{1,2})</b>"#, in: row),
            let monthText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<span\b[^>]*>(\d{4})\.(\d{1,2})</span>"#, group: 2, in: row),
            let yearText = firstCapture(#"<div\b[^>]*class=[\"'][^\"']*pub_date[^\"']*[\"'][^>]*>.*?<span\b[^>]*>(\d{4})\.(\d{1,2})</span>"#, group: 1, in: row),
            let day = Int(HTMLText.decodeEntities(dayText)),
            let month = Int(HTMLText.decodeEntities(monthText)),
            let year = Int(HTMLText.decodeEntities(yearText)),
            let published = formattedDate(year: year, month: month, day: day) else {
        return nil
      }
      let summaryHTML = firstCapture(#"<p\b[^>]*>(.*?)</p>"#, in: row) ?? ""
      let title = HTMLText.plainText(titleHTML)
      guard !title.isEmpty else { return nil }
      return CampusNotice(
        id: link.absoluteString,
        title: title,
        summary: HTMLText.plainText(summaryHTML),
        publishedAt: published,
        url: link
      )
    }
    return (notices, candidateCount)
  }

  private static func formattedDate(year: Int, month: Int, day: Int) -> String? {
    guard (1...12).contains(month), (1...31).contains(day) else { return nil }
    let calendar = SchoolTime.calendar
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
          calendar.component(.year, from: date) == year,
          calendar.component(.month, from: date) == month,
          calendar.component(.day, from: date) == day else { return nil }
    return SchoolTime.dayString(date)
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

}

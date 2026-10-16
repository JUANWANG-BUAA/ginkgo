import Foundation

struct LibraryCountPair: Codable, Equatable {
  let available: Int
  let total: Int
}

struct LibraryReadingRoomOccupancy: Codable, Equatable, Identifiable {
  let name: String
  let people: Int

  var id: String { name }
}

struct LibraryCampusOccupancy: Codable, Equatable, Identifiable {
  let id: String
  let name: String
  let people: Int
  let readingRooms: [LibraryReadingRoomOccupancy]
  let seats: LibraryCountPair?
  let studyRooms: LibraryCountPair?
  let lockers: LibraryCountPair?
}

struct LibraryPublicStats: Codable, Equatable {
  let campuses: [LibraryCampusOccupancy]
  let fetchedAt: Date
}

enum LibraryPublicStatsSource {
  static let url = URL(string: "https://lib.buaa.edu.cn/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662")!
}

enum LibraryPublicStatsError: LocalizedError {
  case response, unavailable

  var errorDescription: String? {
    switch self {
    case .response: "图书馆官网返回格式无法识别，学校页面可能已调整"
    case .unavailable: "图书馆官网空间数据暂时不可用"
    }
  }
}

enum LibraryPublicStatsParser {
  private static let campusPattern = #"<img\b[^>]*\bsrc=[\"'][^\"']*/more/custom/t_(xylxq|shxq)\.png[^\"']*[\"'][^>]*>"#
  private static let listItemPattern = #"<li\b[^>]*>([\s\S]*?)</li>"#

  static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> LibraryPublicStats {
    guard let html = String(data: data, encoding: .utf8) else { throw LibraryPublicStatsError.response }
    let source = html as NSString
    let campusMatches = matches(campusPattern, in: html)
    guard campusMatches.count >= 2 else { throw LibraryPublicStatsError.response }

    var campuses: [LibraryCampusOccupancy] = []
    for (index, match) in campusMatches.enumerated() {
      guard let idRange = Range(match.range(at: 1), in: html) else { throw LibraryPublicStatsError.response }
      let id = String(html[idRange])
      let end = index + 1 < campusMatches.count ? campusMatches[index + 1].range.location : source.length
      let sectionRange = NSRange(location: match.range.location, length: end - match.range.location)
      let section = source.substring(with: sectionRange)
      let items = matches(listItemPattern, in: section).compactMap { item -> String? in
        guard let range = Range(item.range(at: 1), in: section) else { return nil }
        return visibleText(String(section[range]))
      }

      guard let people = items.compactMap({ capturedInteger(#"图书馆\s*(\d+)\s*人"#, in: $0) }).first else {
        throw LibraryPublicStatsError.response
      }
      let readingRoomItems = items.filter { $0.hasPrefix("特色阅览室") }
      let readingRooms = try readingRoomItems.map { text -> LibraryReadingRoomOccupancy in
        guard text.hasPrefix("特色阅览室"),
              let match = firstMatch(#"(特色阅览室.*?)\s*(\d+)\s*人"#, in: text),
              let nameRange = Range(match.range(at: 1), in: text),
              let countRange = Range(match.range(at: 2), in: text),
              let count = Int(text[countRange]) else { throw LibraryPublicStatsError.response }
        return LibraryReadingRoomOccupancy(name: String(text[nameRange]).trimmingCharacters(in: .whitespaces), people: count)
      }

      let campusName: String
      switch id {
      case "xylxq": campusName = "学院路校区"
      case "shxq": campusName = "沙河校区"
      default: throw LibraryPublicStatsError.response
      }
      campuses.append(LibraryCampusOccupancy(
        id: id,
        name: campusName,
        people: people,
        readingRooms: readingRooms,
        seats: try metricCount(named: "预约座位", unit: "座", in: items),
        studyRooms: try metricCount(named: "研讨间", unit: "间", in: items),
        lockers: try metricCount(named: "寄存柜", unit: "个", in: items)
      ))
    }

    guard Set(campuses.map(\.id)) == Set(["xylxq", "shxq"]) else { throw LibraryPublicStatsError.response }
    return LibraryPublicStats(campuses: campuses, fetchedAt: fetchedAt)
  }

  private static func metricCount(named name: String, unit: String, in items: [String]) throws -> LibraryCountPair? {
    let escapedName = NSRegularExpression.escapedPattern(for: name)
    let escapedUnit = NSRegularExpression.escapedPattern(for: unit)
    let pattern = #"\#(escapedName)\s*空闲\s*(\d+)\s*\#(escapedUnit)\s*/\s*总计\s*(\d+)\s*\#(escapedUnit)"#
    let matchingItems = items.filter { $0.contains(name) }
    guard !matchingItems.isEmpty else { return nil }
    guard let pair = matchingItems.compactMap({ text -> LibraryCountPair? in
      guard let match = firstMatch(pattern, in: text),
            let availableRange = Range(match.range(at: 1), in: text),
            let totalRange = Range(match.range(at: 2), in: text),
            let available = Int(text[availableRange]), let total = Int(text[totalRange]),
            available <= total else { return nil }
      return LibraryCountPair(available: available, total: total)
    }).first else { throw LibraryPublicStatsError.response }
    return pair
  }

  private static func visibleText(_ html: String) -> String {
    let withoutTags = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    let decoded = withoutTags
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&#160;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
    return decoded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }

  private static func capturedInteger(_ pattern: String, in text: String) -> Int? {
    guard let match = firstMatch(pattern, in: text),
          let range = Range(match.range(at: 1), in: text) else { return nil }
    return Int(text[range])
  }

  private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
  }

  private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
  }
}

actor LibraryPublicStatsClient {
  private let session: URLSession
  private let endpoint = LibraryPublicStatsSource.url

  init(session: URLSession? = nil) {
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.httpCookieStorage = nil
      configuration.httpShouldSetCookies = false
      configuration.httpCookieAcceptPolicy = .never
      configuration.urlCache = nil
      self.session = URLSession(configuration: configuration)
    }
  }

  func fetch() async throws -> LibraryPublicStats {
    var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    request.httpMethod = "GET"
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("https://lib.buaa.edu.cn/", forHTTPHeaderField: "Referer")
    request.setValue("BUAA-Assistant/1.0", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw LibraryPublicStatsError.unavailable
    }
    return try LibraryPublicStatsParser.parse(data, fetchedAt: Date())
  }
}

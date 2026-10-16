import Foundation

struct FreeClassroom: Identifiable, Codable, Sendable {
  let id: String
  let floorid: String
  let name: String
  let kxsds: String
  let availableSections: [Int]
  let availableSectionCount: Int
  let longestFreeRun: Int

  init(id: String, floorid: String, name: String, kxsds: String) {
    self.id = id
    self.floorid = floorid
    self.name = name
    self.kxsds = kxsds
    let sections = Self.parseAvailableSections(kxsds)
    availableSections = sections
    availableSectionCount = sections.count

    var longest = 0
    var run = 0
    var previous = 0
    for section in sections {
      run = section == previous + 1 ? run + 1 : 1
      longest = max(longest, run)
      previous = section
    }
    longestFreeRun = longest
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case floorid
    case name
    case kxsds
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try values.decode(String.self, forKey: .id),
      floorid: try values.decode(String.self, forKey: .floorid),
      name: try values.decode(String.self, forKey: .name),
      kxsds: try values.decode(String.self, forKey: .kxsds)
    )
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(floorid, forKey: .floorid)
    try values.encode(name, forKey: .name)
    try values.encode(kxsds, forKey: .kxsds)
  }

  /// The upstream returns a comma-separated list. Parse it once so filtering
  /// and SwiftUI row updates reuse the same normalized section values.
  private static func parseAvailableSections(_ value: String) -> [Int] {
    value
      .split { ",，、 /".contains($0) }
      .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
      .filter { (1...14).contains($0) }
      .sorted()
      .reduce(into: [Int]()) { result, section in
        if result.last != section { result.append(section) }
      }
  }

  func isAvailable(at section: Int) -> Bool {
    availableSections.contains(section)
  }

  var hasRecognizedAvailabilityFormat: Bool {
    let value = kxsds.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return true }
    let sections = value.split { ",，、 /".contains($0) }
    return !sections.isEmpty && sections.allSatisfy { raw in
      guard let section = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
      return (1...14).contains(section)
    }
  }
}
private struct ClassroomResponse: Decodable {
  let e: Int
  let m: String?
  let d: Payload
  struct Payload: Decodable { let list: [String: [FreeClassroom]] }
}
protocol ClassroomServing {
  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]]
}

actor ClassroomClient: ClassroomServing {
  private let session: URLSession
  init(session: URLSession = APIClient.shared.session) { self.session = session }
  // API.md §6A：先激活 app 会话，再查询。
  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]] {
    var activation = URLComponents(string: "https://sso.buaa.edu.cn/login")!
    activation.queryItems = [URLQueryItem(name: "service", value: "https://app.buaa.edu.cn/a_buaa/api/cas/index?redirect=https%3A%2F%2Fapp.buaa.edu.cn%2Fsite%2FclassRoomQuery%2Findex&from=wap&login_from="), URLQueryItem(name: "noAutoRedirect", value: "1")]
    _ = try await session.data(from: activation.url!)
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    var url = URLComponents(string: "https://app.buaa.edu.cn/buaafreeclass/wap/default/search1")!
    url.queryItems = [URLQueryItem(name: "xqid", value: String(campus)), URLQueryItem(name: "floorid", value: ""), URLQueryItem(name: "date", value: formatter.string(from: date))]
    var request = URLRequest(url: url.url!); request.timeoutInterval = 30
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue("https://app.buaa.edu.cn/site/classRoomQuery/index", forHTTPHeaderField: "Referer")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw ScheduleError.unavailable("空教室服务") }
    let bodyText = String(data: data.prefix(5000), encoding: .utf8) ?? ""
    if http.statusCode == 401 || http.statusCode == 403 || http.url?.host == "sso.buaa.edu.cn"
        || bodyText.contains("name=\"execution\"") || bodyText.localizedCaseInsensitiveContains("统一身份认证") {
      throw ScheduleError.sessionExpired
    }
    guard (200..<300).contains(http.statusCode) else { throw ScheduleError.unavailable("空教室服务") }
    guard let result = try? JSONDecoder().decode(ClassroomResponse.self, from: data) else {
      AppLog.responseFormatChanged(feature: "classrooms", stage: "room_list")
      throw ScheduleError.changedResponseAt("空教室")
    }
    guard result.e == 0 else { throw ScheduleError.unavailable("空教室服务") }
    let rooms = result.d.list.values.flatMap { $0 }
    guard rooms.allSatisfy({
      !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && $0.hasRecognizedAvailabilityFormat
    }) else {
      AppLog.responseFormatChanged(feature: "classrooms", stage: "room_fields")
      throw ScheduleError.changedResponseAt("空教室")
    }
    return result.d.list
  }
}

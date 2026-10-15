import Foundation

struct FreeClassroom: Identifiable, Decodable {
  let id: String
  let floorid: String
  let name: String
  let kxsds: String

  /// The upstream returns a comma-separated list. Keep the parsing here so every
  /// presentation mode uses the same normalized section values.
  var availableSections: [Int] {
    kxsds
      .split { ",，、 /".contains($0) }
      .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
      .filter { (1...14).contains($0) }
      .sorted()
      .reduce(into: [Int]()) { result, section in
        if result.last != section { result.append(section) }
      }
  }

  var availableSectionCount: Int { availableSections.count }

  func isAvailable(at section: Int) -> Bool {
    availableSections.contains(section)
  }

  var longestFreeRun: Int {
    var longest = 0
    var run = 0
    var previous = 0
    for section in availableSections {
      run = section == previous + 1 ? run + 1 : 1
      longest = max(longest, run)
      previous = section
    }
    return longest
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
    guard let http = response as? HTTPURLResponse else { throw ScheduleError.changedResponseAt("空教室") }
    if http.statusCode == 401 || http.url?.host == "sso.buaa.edu.cn" { throw ScheduleError.sessionExpired }
    guard http.statusCode == 200, let result = try? JSONDecoder().decode(ClassroomResponse.self, from: data) else { throw ScheduleError.changedResponseAt("空教室") }
    guard result.e == 0 else { throw ScheduleError.unavailable("空教室服务") }
    return result.d.list
  }
}

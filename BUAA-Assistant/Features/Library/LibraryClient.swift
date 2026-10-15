import Foundation
import CommonCrypto

struct LibraryItem: Identifiable, Hashable {
  let id: String
  let name: String
  let detail: String
  let available: Bool
}
struct LibrarySlot: Identifiable, Hashable {
  let id: String
  let day: String
  let start: String
  let end: String
  var title: String { "\(day) · \(start)–\(end)" }
}
enum LibraryError: LocalizedError {
  case response, authentication, rejected(String), uncertain
  var errorDescription: String? {
    switch self {
    case .response: "图书馆返回的数据无法识别"
    case .authentication: "图书馆登录未完成，请重新登录学校账号后再试"
    case .rejected(let message): message
    case .uncertain: "操作结果待核实，请刷新我的预约后确认，勿重复提交"
    }
  }
}

enum LibraryCrypto {
  static func encrypt(_ data: Data, day: String) throws -> String {
    let digits = day.filter { $0.isASCII && $0.isNumber }
    guard digits.count == 8 else { throw LibraryError.response }
    let key = Array((digits + String(digits.reversed())).utf8)
    let iv = Array("ZZWBKJ_ZHIHUAWEI".utf8)
    var output = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
    var count = 0
    let status = data.withUnsafeBytes { input in
      CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
              key, key.count, iv, input.baseAddress, data.count, &output, output.count, &count)
    }
    guard status == kCCSuccess else { throw LibraryError.response }
    return Data(output.prefix(count)).base64EncodedString()
  }
}

actor LibraryClient {
  private var token: String?
  private let session: URLSession
  private let authSession: URLSession
  private let base = "https://booking.lib.buaa.edu.cn"
  init(session: URLSession = APIClient.shared.session, authSession: URLSession = APIClient.shared.noRedirectSession) {
    self.session = session; self.authSession = authSession
  }

  // API.md §5.2：楼馆、分区、座位、预约记录均为 POST JSON。
  func libraries(day: String) async throws -> [LibraryItem] {
    try items(try await request("space/pcTopFor", body: ["day": day]), key: "list")
  }
  func areas(library: String, day: String) async throws -> [LibraryItem] {
    try items(try await request("space/pick", body: ["premisesIds": library, "date": day,
                                                           "categoryIds": [], "storeyIds": [], "boutiqueIds": []]), key: "area")
  }
  func slots(area: String) async throws -> [LibrarySlot] {
    let data = try await request("Space/map", body: ["id": area])
    guard let dates = data["date"] as? [String: Any], let rows = dates["list"] as? [[String: Any]] else { throw LibraryError.response }
    return rows.flatMap { row -> [LibrarySlot] in
      let day = Self.text(row["day"] ?? row["date"])
      return (row["times"] as? [[String: Any]] ?? []).compactMap { slot in
        let id = Self.text(slot["id"])
        guard !id.isEmpty, !day.isEmpty else { return nil }
        return LibrarySlot(id: day + "/" + id, day: day, start: Self.text(slot["start"]), end: Self.text(slot["end"]))
      }
    }
  }
  func seats(area: String, slot: LibrarySlot) async throws -> [LibraryItem] {
    try items(try await request("Space/seat", body: ["id": area, "day": slot.day, "label_id": [],
                                                            "start_time": slot.start, "end_time": slot.end, "begdate": "", "enddate": ""]), key: "list", seats: true)
  }
  func bookings() async throws -> [LibraryItem] {
    let data = try await request("member/seat", body: ["type": "1", "page": 1, "limit": 100])
    guard let rows = (data["data"] ?? data["list"]) as? [[String: Any]] else { throw LibraryError.response }
    return rows.map { row in
      LibraryItem(id: Self.text(row["id"]), name: Self.text(row["nameMerge"] ?? row["name_merge"] ?? row["name"]),
                  detail: [Self.text(row["day"] ?? row["date"]), Self.text(row["beginTime"] ?? row["begin_time"]),
                           Self.text(row["endTime"] ?? row["end_time"]), Self.text(row["status_name"])].joined(separator: " · "), available: true)
    }
  }
  func reserve(seat: String, slot: LibrarySlot) async throws {
    let segment = String(slot.id.split(separator: "/").last ?? "")
    let plain = try JSONSerialization.data(withJSONObject: ["seat_id": seat, "segment": segment, "day": slot.day, "start_time": "", "end_time": ""], options: .sortedKeys)
    let encrypted = try LibraryCrypto.encrypt(plain, day: slot.day)
    _ = try await request("space/confirm", body: ["aesjson": encrypted], mutation: true)
  }
  func cancel(id: String) async throws {
    _ = try await request("space/cancel", body: ["id": id], mutation: true)
  }

  private func items(_ data: [String: Any], key: String, seats: Bool = false) throws -> [LibraryItem] {
    guard let rows = data[key] as? [[String: Any]] else { throw LibraryError.response }
    return rows.map { row in
      LibraryItem(id: Self.text(row["id"]), name: Self.text(row["name"] ?? row["no"]),
                  detail: seats ? Self.text(row["status_name"]) : "可用 \(Self.text(row["free_num"])) / \(Self.text(row["total_num"]))",
                  available: !seats || Self.text(row["status"]) == "1")
    }
  }
  private func request(_ path: String, body: [String: Any], mutation: Bool = false, retry: Bool = true) async throws -> [String: Any] {
    if token == nil { try await login() }
    var request = makeRequest(URL(string: base + "/v4/" + path)!)
    request.httpMethod = "POST"
    request.setValue("bearer" + (token ?? ""), forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let result: [String: Any]
    do { result = try await send(request, session: session) }
    catch { if mutation { throw LibraryError.uncertain }; throw error }
    let message = Self.text(result["message"] ?? result["msg"])
    if ["登录失效", "请重新登录", "未登录"].contains(where: message.contains) {
      token = nil
      if retry && !mutation { return try await self.request(path, body: body, retry: false) }
      throw LibraryError.authentication
    }
    guard let code = Int(Self.text(result["code"])), [0, 1].contains(code) else { throw LibraryError.rejected(message.isEmpty ? "图书馆操作未成功" : message) }
    if mutation, ["失败", "不可", "已被", "不能", "无法"].contains(where: message.contains) { throw LibraryError.rejected(message) }
    return result["data"] as? [String: Any] ?? [:]
  }
  // API.md §5.1：最多八跳，查询串和 fragment 都提取 cas。
  private func login() async throws {
    var url = URL(string: "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas")!
    var cas: String?
    for _ in 0..<8 {
      if let value = Self.casToken(url.absoluteString) { cas = value; break }
      let (data, response) = try await authSession.data(for: makeRequest(url))
      guard let http = response as? HTTPURLResponse else { throw LibraryError.authentication }
      guard (300..<400).contains(http.statusCode), let location = http.value(forHTTPHeaderField: "Location"),
            let next = URL(string: location, relativeTo: url)?.absoluteURL, next.scheme == "https",
            ["sso.buaa.edu.cn", "booking.lib.buaa.edu.cn"].contains(next.host ?? "") else {
        _ = data; throw LibraryError.authentication
      }
      if let value = Self.casToken(next.absoluteString) { cas = value; break }
      url = next
    }
    guard let cas else { throw LibraryError.authentication }
    var request = makeRequest(URL(string: base + "/v4/login/user")!)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: ["cas": cas])
    let root = try await send(request, session: session)
    guard let data = root["data"] as? [String: Any], let member = data["member"] as? [String: Any],
          let value = member["token"] as? String, !value.isEmpty else { throw LibraryError.authentication }
    token = value
  }
  static func casToken(_ raw: String) -> String? {
    guard let range = raw.range(of: #"[?&#]cas=([^&#]+)"#, options: .regularExpression) else { return nil }
    let match = raw[range].dropFirst(5)
    return String(match).removingPercentEncoding
  }
  private func makeRequest(_ url: URL) -> URLRequest {
    var request = URLRequest(url: url); request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue(base, forHTTPHeaderField: "Origin"); request.setValue(base, forHTTPHeaderField: "Referer")
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/147.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
    return request
  }
  private func send(_ request: URLRequest, session: URLSession) async throws -> [String: Any] {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LibraryError.response }
    return json
  }
  private static func text(_ value: Any?) -> String {
    if let value = value as? String { return value }
    return (value as? NSNumber)?.stringValue ?? ""
  }
}

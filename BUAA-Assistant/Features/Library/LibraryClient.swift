import Foundation

struct LibraryItem: Identifiable, Hashable, Codable, Sendable {
  let id: String
  let name: String
  let detail: String
  let available: Bool
  let availableCount: Int?
  let totalCount: Int?
}
struct LibrarySlot: Identifiable, Hashable, Codable {
  let id: String
  let day: String
  let start: String
  let end: String
  var title: String { "\(day) · \(start)–\(end)" }
}
enum LibraryError: LocalizedError {
  case response, unavailable, authentication, rejected(String), uncertain, invalidRequest, operation
  var errorDescription: String? {
    switch self {
    case .response: "图书馆返回的数据格式无法识别，接口可能已调整；请重试，若持续出现请反馈"
    case .unavailable: "图书馆服务暂时不可用，请稍后重试"
    case .authentication: "图书馆登录未完成，请重新登录学校账号后再试"
    case .rejected(let message): message
    case .uncertain: "操作结果待核实，请刷新我的预约后确认，勿重复提交"
    case .invalidRequest: "预约请求信息无效，未提交"
    case .operation: "无法准备图书馆预约请求"
    }
  }
}

/// 上游预约记录附带的动作提示。字段来自 `index/subscribe` 的
/// `flag_in` / `flag_out` / `flag_leave` / `oksign`；历史列表
/// `member/seat` 不保证返回这些字段，因此全部保留为可选值。
struct LibraryBookingFlags: Equatable {
  let canSignIn: Bool?
  let canTemporaryLeave: Bool?
  let canReturnFromLeave: Bool?
  let canCheckout: Bool?
  let canCancel: Bool?

  init(
    canSignIn: Bool? = nil,
    canTemporaryLeave: Bool? = nil,
    canReturnFromLeave: Bool? = nil,
    canCheckout: Bool? = nil,
    canCancel: Bool? = nil
  ) {
    self.canSignIn = canSignIn
    self.canTemporaryLeave = canTemporaryLeave
    self.canReturnFromLeave = canReturnFromLeave
    self.canCheckout = canCheckout
    self.canCancel = canCancel
  }

  init(row: [String: Any]) {
    let signIn = Self.flag(row["flag_in"] ?? row["flagIn"])
    let temporaryLeave = Self.flag(row["flag_out"] ?? row["flagOut"])
    let returnFromLeave = Self.flag(row["flag_leave"] ?? row["flagLeave"])
    let cancel = Self.flag(row["oksign"] ?? row["okSign"])
    self.canSignIn = (signIn == nil && returnFromLeave == nil)
      ? nil
      : (signIn == true || returnFromLeave == true)
    self.canTemporaryLeave = temporaryLeave
    self.canReturnFromLeave = returnFromLeave
    self.canCheckout = (temporaryLeave == nil && returnFromLeave == nil)
      ? nil
      : (temporaryLeave == true || returnFromLeave == true)
    self.canCancel = cancel
  }

  var hasHints: Bool {
    [canSignIn, canTemporaryLeave, canReturnFromLeave, canCheckout, canCancel]
      .contains { $0 != nil }
  }

  private static func flag(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.intValue != 0 }
    if let value = value as? String {
      switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "1", "true", "yes": return true
      case "0", "false", "no", "": return false
      default: return nil
      }
    }
    return nil
  }
}

enum LibrarySeatAction: String, CaseIterable, Identifiable {
  case signIn
  case temporaryLeave
  case checkout

  var id: String { rawValue }

  var title: String {
    switch self {
    case .signIn: "签到入座"
    case .temporaryLeave: "临时离开"
    case .checkout: "完全离开"
    }
  }

  var symbol: String {
    switch self {
    case .signIn: "person.badge.clock"
    case .temporaryLeave: "figure.walk"
    case .checkout: "door.left.hand.open"
    }
  }

  var confirmationTitle: String {
    switch self {
    case .signIn: "确认签到入座？"
    case .temporaryLeave: "确认临时离开？"
    case .checkout: "确认完全离开？"
    }
  }

  var path: String {
    switch self {
    case .signIn: "space/signin"
    case .temporaryLeave: "space/leave"
    case .checkout: "space/checkout"
    }
  }

  /// 确认按钮文案；返回入座时使用预约记录的专用标题。
  func buttonTitle(for booking: LibraryBooking) -> String {
    self == .signIn ? booking.signInActionTitle : title
  }

  func confirmationMessage(for booking: LibraryBooking) -> String {
    switch self {
    case .signIn where booking.canReturnFromLeave:
      "返回入座后学校会恢复该座位的使用状态。请确认你已回到座位，操作结果以学校返回为准。"
    case .signIn:
      "签到后学校会开始计算座位使用时间。请确认你已在座位附近，操作结果以学校返回为准。"
    case .temporaryLeave:
      "临时离开会保留座位，但学校可能限制暂离时长。请在规定时间内返回并签到，超时可能被释放。"
    case .checkout:
      "完全离开会结束本次座位使用，之后无法继续使用该座位。此操作不可撤销。"
    }
  }
}

struct LibraryBooking: Identifiable, Equatable {
  let id: String
  let name: String
  let areaName: String
  let seatNumber: String
  let day: String
  let startTime: String
  let endTime: String
  let status: String
  let statusName: String
  /// `index/subscribe` 的 1=座位、2=研讨室、3/4=研修座位；历史列表可能不返回。
  let type: Int?
  let spaceName: String
  let title: String
  let flags: LibraryBookingFlags

  init(
    id: String,
    name: String,
    areaName: String,
    seatNumber: String,
    day: String,
    startTime: String,
    endTime: String,
    status: String,
    statusName: String,
    type: Int? = nil,
    spaceName: String = "",
    title: String = "",
    flags: LibraryBookingFlags = LibraryBookingFlags()
  ) {
    self.id = id
    self.name = name
    self.areaName = areaName
    self.seatNumber = seatNumber
    self.day = day
    self.startTime = startTime
    self.endTime = endTime
    self.status = status
    self.statusName = statusName
    self.type = type
    self.spaceName = spaceName
    self.title = title
    self.flags = flags
  }

  var detail: String {
    [day, startTime, endTime, statusName].filter { !$0.isEmpty }.joined(separator: " · ")
  }

  var displayTitle: String {
    if !name.isEmpty { return name }
    if !spaceName.isEmpty { return spaceName }
    if !title.isEmpty { return title }
    return [areaName, seatNumber].filter { !$0.isEmpty }.joined(separator: " · ")
  }

  var displayDetail: String { detail.isEmpty ? displayStatus : detail }

  var displayStatus: String {
    if !statusName.isEmpty { return statusName }
    if hasEnded() { return "已结束" }
    switch status {
    case "6": return "已取消"
    case "8": return "已结束"
    case "1": return "进行中"
    default:
      return Self.endDate(day: day, time: endTime) == nil
        ? "预约时间待确认"
        : (canCancel() ? "可取消" : "不可取消")
    }
  }

  var isSeminar: Bool { type == 2 }
  var isStudySeat: Bool { type == 3 || type == 4 }

  /// 座位生命周期接口只用于普通座位；研讨室与研修座位有各自的操作端点。
  private var supportsSeatLifecycle: Bool {
    type == nil || type == 1
  }

  var canSignIn: Bool {
    supportsSeatLifecycle && flags.canSignIn == true && canActOnCurrentRecord
  }

  var canReturnFromLeave: Bool {
    supportsSeatLifecycle && flags.canReturnFromLeave == true && canActOnCurrentRecord
  }

  var canTemporaryLeave: Bool {
    supportsSeatLifecycle && flags.canTemporaryLeave == true
      && canReturnFromLeave == false && canActOnCurrentRecord
  }

  var canCheckout: Bool {
    supportsSeatLifecycle && flags.canCheckout == true && canActOnCurrentRecord
  }

  var signInActionTitle: String {
    canReturnFromLeave ? "返回入座" : "签到入座"
  }

  /// 只有上游明确给出动作提示时才展示座位生命周期操作；
  /// 历史记录或字段缺失时保持只读，避免猜测学校状态。
  var hasLifecycleActions: Bool {
    canSignIn || canTemporaryLeave || canCheckout
  }

  private var canActOnCurrentRecord: Bool {
    guard !id.isEmpty,
          !["6", "8"].contains(status.trimmingCharacters(in: .whitespacesAndNewlines)),
          !["取消", "结束", "已完成", "过期", "失效"].contains(where: statusName.contains) else { return false }
    return !hasEnded()
  }

  func canCancel(at date: Date = Date()) -> Bool {
    guard !id.isEmpty,
          flags.canCancel != false,
          !["6", "8"].contains(status.trimmingCharacters(in: .whitespacesAndNewlines)),
          !["取消", "结束", "已完成", "过期", "失效"].contains(where: statusName.contains),
          let end = Self.endDate(day: day, time: endTime) else { return false }
    return end > date
  }

  func hasEnded(at date: Date = Date()) -> Bool {
    guard let end = Self.endDate(day: day, time: endTime) else { return false }
    return end <= date
  }

  private static func endDate(day: String, time: String) -> Date? {
    SchoolTime.date(
      from: "\(day) \(time)",
      formats: ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyyMMdd HH:mm:ss", "yyyyMMdd HH:mm"]
    )
  }
}

struct LibraryBookingPage: Equatable {
  let items: [LibraryBooking]
  let page: Int
  let pageSize: Int
  let total: Int?
  let lastPage: Int?
  let hasNext: Bool
}

struct LibraryCacheSnapshot: Codable {
  let libraries: [LibraryItem]
  let libraryID: String
  let areas: [LibraryItem]
  let areaID: String
  let slots: [LibrarySlot]
  let slotID: String
  let seats: [LibraryItem]
  let seatsAreTruncated: Bool
  let seatsFetchedAt: Date?
  let publicStats: LibraryPublicStats?
  let fetchedAt: Date
}

/// 每个账号最多缓存 2,000 个座位，避免大分区把快照文件撑大。
actor LibraryCache {
  private let store: LocalStore
  private let maximumCachedSeats = 2_000

  init(directory: URL? = nil) {
    store = LocalStore(module: "Library", directory: directory)
  }

  func read(account: String) -> LibraryCacheSnapshot? {
    store.read(LibraryCacheSnapshot.self, account: account)
  }

  func save(_ snapshot: LibraryCacheSnapshot, account: String) throws {
    let bounded = LibraryCacheSnapshot(
      libraries: Array(snapshot.libraries.prefix(100)), libraryID: snapshot.libraryID,
      areas: Array(snapshot.areas.prefix(500)), areaID: snapshot.areaID,
      slots: Array(snapshot.slots.prefix(100)), slotID: snapshot.slotID,
      seats: Array(snapshot.seats.prefix(maximumCachedSeats)),
      seatsAreTruncated: snapshot.seatsAreTruncated || snapshot.seats.count > maximumCachedSeats,
      seatsFetchedAt: snapshot.seatsFetchedAt,
      publicStats: snapshot.publicStats,
      fetchedAt: snapshot.fetchedAt
    )
    try store.write(bounded, account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

enum LibraryCrypto {
  static func encrypt(_ data: Data, day: String) throws -> String {
    let digits = day.filter { $0.isASCII && $0.isNumber }
    guard digits.count == 8 else { throw LibraryError.invalidRequest }
    let key = Array((digits + String(digits.reversed())).utf8)
    guard let encrypted = AESCipher.encrypt(data, key: key, mode: .cbc(iv: Array("ZZWBKJ_ZHIHUAWEI".utf8))) else {
      throw LibraryError.operation
    }
    return encrypted.base64EncodedString()
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
    let slots = try rows.flatMap { row -> [LibrarySlot] in
      let day = Self.text(row["day"] ?? row["date"])
      guard !day.isEmpty, let times = row["times"] as? [[String: Any]] else { throw LibraryError.response }
      return try times.map { slot in
        let id = Self.text(slot["id"])
        let start = Self.text(slot["start"])
        let end = Self.text(slot["end"])
        guard !id.isEmpty, !start.isEmpty, !end.isEmpty else { throw LibraryError.response }
        return LibrarySlot(id: day + "/" + id, day: day, start: start, end: end)
      }
    }
    guard Set(slots.map(\.id)).count == slots.count else { throw LibraryError.response }
    return slots
  }
  func seats(area: String, slot: LibrarySlot) async throws -> [LibraryItem] {
    try items(try await request("Space/seat", body: ["id": area, "day": slot.day, "label_id": [],
                                                            "start_time": slot.start, "end_time": slot.end, "begdate": "", "enddate": ""]), key: "list", seats: true)
  }
  func bookings(page: Int, limit: Int) async throws -> LibraryBookingPage {
    let safePage = max(1, page)
    let safeLimit = min(max(1, limit), 100)
    let data = try await request("member/seat", body: ["type": "1", "page": safePage, "limit": safeLimit])
    guard let rows = (data["data"] ?? data["list"]) as? [[String: Any]] else { throw LibraryError.response }
    let items = try rows.map { row in
      guard let booking = Self.booking(from: row, requiresStatus: true) else {
        throw LibraryError.response
      }
      return booking
    }
    guard Set(items.map(\.id)).count == items.count else { throw LibraryError.response }
    let paginationKeys: Set<String> = ["current_page", "page", "per_page", "limit", "total", "count", "last_page", "lastPage", "has_more", "hasNextPage"]
    guard !Set(data.keys).isDisjoint(with: paginationKeys) else { throw LibraryError.response }
    let currentPageValue = [data["current_page"], data["page"]].compactMap { $0 }.first { !($0 is NSNull) }
    let pageSizeValue = [data["per_page"], data["limit"]].compactMap { $0 }.first { !($0 is NSNull) }
    let totalValue = [data["total"], data["count"]].compactMap { $0 }.first { !($0 is NSNull) }
    let lastPageValue = [data["last_page"], data["lastPage"]].compactMap { $0 }.first { !($0 is NSNull) }
    let reportedPage = Self.integer(currentPageValue)
    let reportedPageSize = Self.integer(pageSizeValue)
    let total = Self.integer(totalValue)
    let lastPage = Self.integer(lastPageValue)
    if (currentPageValue != nil && reportedPage == nil && !(currentPageValue is NSNull))
        || (pageSizeValue != nil && reportedPageSize == nil && !(pageSizeValue is NSNull))
        || (totalValue != nil && total == nil && !(totalValue is NSNull))
        || (lastPageValue != nil && lastPage == nil && !(lastPageValue is NSNull)) {
      throw LibraryError.response
    }
    let currentPage = reportedPage ?? safePage
    let pageSize = reportedPageSize ?? safeLimit
    let nextValue = [data["has_more"], data["hasNextPage"]].compactMap { $0 }.first { !($0 is NSNull) }
    let explicitHasNext: Bool?
    if let nextValue {
      if let value = nextValue as? Bool {
        explicitHasNext = value
      } else if let value = Self.integer(nextValue), value == 0 || value == 1 {
        explicitHasNext = value == 1
      } else {
        throw LibraryError.response
      }
    } else {
      explicitHasNext = nil
    }
    guard currentPage > 0, pageSize > 0, total.map({ $0 >= 0 }) ?? true,
          lastPage.map({ $0 >= 0 }) ?? true,
          currentPage <= Int.max / pageSize, items.count <= pageSize,
          reportedPage == nil || currentPage == safePage,
          total != nil || lastPage != nil || explicitHasNext != nil || items.count == pageSize else {
      throw LibraryError.response
    }
    if let explicitHasNext, let lastPage, explicitHasNext != (currentPage < lastPage) {
      throw LibraryError.response
    }
    if let explicitHasNext, let total, explicitHasNext != (currentPage * pageSize < total) {
      throw LibraryError.response
    }
    let inferredHasNext: Bool
    if let lastPage { inferredHasNext = currentPage < lastPage }
    else if let total { inferredHasNext = currentPage * pageSize < total }
    else { inferredHasNext = items.count == pageSize }
    let hasNext = explicitHasNext ?? inferredHasNext
    return LibraryBookingPage(items: items, page: currentPage, pageSize: pageSize, total: total, lastPage: lastPage, hasNext: hasNext)
  }
  /// 当前仍在进行中的预约（`index/subscribe`）。与历史分页 `member/seat`
  /// 分开读取，因为只有当前记录带 `flag_in/flag_out/flag_leave/oksign`。
  func currentBookings() async throws -> [LibraryBooking] {
    let result = try await request("index/subscribe", body: [:], extractData: false)
    guard let raw = result["data"], !(raw is NSNull) else { return [] }
    let rows: [[String: Any]]
    if let array = raw as? [[String: Any]] {
      rows = array
    } else if let dictionary = raw as? [String: Any],
              let list = dictionary["list"] as? [[String: Any]] {
      rows = list
    } else {
      throw LibraryError.response
    }
    let items = try rows.map { row in
      guard let booking = Self.booking(from: row, requiresStatus: false) else {
        throw LibraryError.response
      }
      return booking
    }
    guard Set(items.map(\.id)).count == items.count else { throw LibraryError.response }
    return items
  }

  func reserve(seat: String, slot: LibrarySlot) async throws {
    let segment = String(slot.id.split(separator: "/").last ?? "")
    let plain = try JSONSerialization.data(withJSONObject: ["seat_id": seat, "segment": segment, "day": slot.day, "start_time": "", "end_time": ""], options: .sortedKeys)
    let encrypted = try LibraryCrypto.encrypt(plain, day: slot.day)
    _ = try await request("space/confirm", body: ["aesjson": encrypted], mutation: true, requiresObjectData: false)
  }

  /// 座位生命周期写操作。前端在无法取得定位时提交空 `points`；
  /// 这里同样不申请系统定位权限，由学校接口决定是否接受。
  func perform(_ action: LibrarySeatAction, bookingID: String) async throws {
    let plain = try JSONSerialization.data(
      withJSONObject: ["id": bookingID, "points": [String: Any]()],
      options: .sortedKeys
    )
    let encrypted = try LibraryCrypto.encrypt(plain, day: SchoolTime.dayString())
    _ = try await request(
      action.path,
      body: ["aesjson": encrypted],
      mutation: true,
      requiresObjectData: false
    )
  }

  func cancel(_ booking: LibraryBooking) async throws {
    let path: String
    if booking.isSeminar {
      path = "seminar/cancel"
    } else if booking.isStudySeat {
      path = "space/studyCancel"
    } else {
      path = "space/cancel"
    }
    _ = try await request(path, body: ["id": booking.id], mutation: true, requiresObjectData: false)
  }

  private func items(_ data: [String: Any], key: String, seats: Bool = false) throws -> [LibraryItem] {
    guard let rows = data[key] as? [[String: Any]] else { throw LibraryError.response }
    let items = try rows.map { row in
      let id = Self.text(row["id"])
      let name = Self.text(row["name"] ?? row["no"])
      guard !id.isEmpty, !name.isEmpty else { throw LibraryError.response }
      let availableCount = seats ? nil : Self.integer(row["free_num"])
      let totalCount = seats ? nil : Self.integer(row["total_num"])
      if seats {
        guard row.keys.contains("status"), !Self.text(row["status"]).isEmpty else { throw LibraryError.response }
      } else {
        guard let availableCount, let totalCount, availableCount >= 0, totalCount >= availableCount else {
          throw LibraryError.response
        }
      }
      return LibraryItem(id: id, name: name,
                         detail: seats ? Self.text(row["status_name"]) : "可预约 \(Self.text(row["free_num"])) / \(Self.text(row["total_num"]))",
                         available: !seats || Self.text(row["status"]) == "1",
                         availableCount: availableCount, totalCount: totalCount)
    }
    guard Set(items.map(\.id)).count == items.count else { throw LibraryError.response }
    return items
  }
  private func request(
    _ path: String,
    body: [String: Any],
    mutation: Bool = false,
    requiresObjectData: Bool = true,
    extractData: Bool = true,
    retry: Bool = true
  ) async throws -> [String: Any] {
    if token == nil { try await login() }
    var request = makeRequest(URL(string: base + "/v4/" + path)!)
    request.httpMethod = "POST"
    request.setValue("bearer" + (token ?? ""), forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    // 只读请求在登录失效时重新取 token 后重试一次；写操作绝不重发（COLLABORATION §3.5）。
    func retryAfterRelogin() async throws -> [String: Any] {
      try await self.request(
        path, body: body, requiresObjectData: requiresObjectData, extractData: extractData, retry: false
      )
    }
    let result: [String: Any]
    do { result = try await send(request, session: session) }
    catch {
      if case LibraryError.authentication = error {
        token = nil
        if retry, !mutation { return try await retryAfterRelogin() }
      }
      // 写请求失败时无法确认学校是否已受理，只能提示用户核实。
      if mutation { throw LibraryError.uncertain }
      throw error
    }
    let message = Self.text(result["message"] ?? result["msg"])
    if ["登录失效", "请重新登录", "未登录"].contains(where: message.contains) {
      token = nil
      if retry, !mutation { return try await retryAfterRelogin() }
      if mutation { throw LibraryError.uncertain }
      throw LibraryError.authentication
    }
    guard let code = Self.integer(result["code"]) else {
      if mutation { throw LibraryError.uncertain }
      throw LibraryError.response
    }
    let failureKeywords = ["失败", "不可", "已被", "不能", "无法", "不足", "不符合", "已满", "超过", "限制", "无效", "未选择", "请选择", "请输入"]
    guard [0, 1].contains(code) else {
      let explicitFailure = failureKeywords.contains(where: message.contains)
      if mutation && !explicitFailure { throw LibraryError.uncertain }
      throw LibraryError.rejected(message.isEmpty ? "图书馆操作未成功（服务代码 \(code)）" : message)
    }
    if mutation, failureKeywords.contains(where: message.contains) { throw LibraryError.rejected(message) }
    if extractData == false { return result }
    if let data = result["data"] as? [String: Any] { return data }
    guard !requiresObjectData else { throw LibraryError.response }
    return [:]
  }
  // API.md §5.1：最多八跳，查询串和 fragment 都提取 cas。
  private func login() async throws {
    var url = URL(string: "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas")!
    var cas: String?
    for _ in 0..<8 {
      if let value = Self.casToken(url.absoluteString) { cas = value; break }
      let (data, response) = try await authSession.routedData(for: makeRequest(url), noRedirect: true)
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
    let (data, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse else { throw LibraryError.unavailable }
    if http.statusCode == 401 || http.statusCode == 403 { throw LibraryError.authentication }
    guard (200..<300).contains(http.statusCode) else { throw LibraryError.unavailable }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LibraryError.response }
    return json
  }
  static func booking(from row: [String: Any], requiresStatus: Bool) -> LibraryBooking? {
    let id = text(row["id"])
    guard !id.isEmpty else { return nil }
    let statusValue = [row["status"], row["statusName"], row["status_name"]]
      .compactMap { $0 }.first { !($0 is NSNull) }
    let status = text(statusValue)
    let hasStatus = ["status", "statusName", "status_name"].contains { row.keys.contains($0) }
    if requiresStatus && (!hasStatus || status.isEmpty) { return nil }
    let statusName = text([row["status_name"], row["statusName"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let name = text([row["nameMerge"], row["name_merge"], row["name"], row["room_name"], row["space_name"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let areaName = text([row["areaName"], row["area_name"], row["name"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let seatNumber = text([row["no"], row["seat_no"], row["seatNo"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let rawDay = text([row["day"], row["date"], row["start_date"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let rawBegin = text([row["beginTime"], row["begin_time"], row["start_time"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let rawEnd = text([row["endTime"], row["end_time"], row["finish_time"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let begin = splitDateTime(rawBegin)
    let end = splitDateTime(rawEnd)
    let day = rawDay.isEmpty ? begin.day : rawDay
    let startTime = begin.time
    let endTime = end.time.isEmpty ? rawEnd : end.time
    let type = integer([row["type"], row["type_id"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let spaceName = text([row["spaceName"], row["space_name"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    let title = text([row["title"], row["theme"]]
      .compactMap { $0 }.first { !($0 is NSNull) })
    return LibraryBooking(
      id: id,
      name: name,
      areaName: areaName,
      seatNumber: seatNumber,
      day: day,
      startTime: startTime,
      endTime: endTime,
      status: status,
      statusName: statusName,
      type: type,
      spaceName: spaceName,
      title: title,
      flags: LibraryBookingFlags(row: row)
    )
  }

  private static func splitDateTime(_ value: String) -> (day: String, time: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return ("", "") }
    for separator in [" ", "T"] {
      if let range = trimmed.range(of: separator) {
        let day = String(trimmed[..<range.lowerBound])
        let time = String(trimmed[range.upperBound...])
        if day.count == 10, time.isEmpty == false { return (day, time) }
      }
    }
    return ("", trimmed)
  }

  private static func text(_ value: Any?) -> String { JSONValue.string(value) ?? "" }
  private static func integer(_ value: Any?) -> Int? { JSONValue.int(value) }
}

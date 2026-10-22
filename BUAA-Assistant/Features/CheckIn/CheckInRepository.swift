import Foundation

struct CheckInCacheSnapshot: Codable {
  var today: CheckInSnapshot?
  var history: [String: CheckInSnapshot]
}

/// 当天状态与最多 180 个历史日期的签到快照。
actor CheckInCache {
  private let store: LocalStore
  private let maximumHistoryDays = 180

  init(directory: URL? = nil) {
    store = LocalStore(module: "CheckIn", directory: directory)
  }

  func read(account: String) -> CheckInCacheSnapshot {
    store.read(CheckInCacheSnapshot.self, account: account) ?? CheckInCacheSnapshot(today: nil, history: [:])
  }

  func saveToday(_ snapshot: CheckInSnapshot, account: String) throws {
    var cached = read(account: account)
    cached.today = snapshot
    try save(cached, account: account)
  }

  func saveHistory(_ snapshot: CheckInSnapshot, account: String) throws {
    var cached = read(account: account)
    cached.history[snapshot.schoolDate] = snapshot
    if cached.history.count > maximumHistoryDays {
      let retained = cached.history.values.sorted { $0.fetchedAt > $1.fetchedAt }.prefix(maximumHistoryDays)
      cached.history = Dictionary(uniqueKeysWithValues: retained.map { ($0.schoolDate, $0) })
    }
    try save(cached, account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }

  private func save(_ snapshot: CheckInCacheSnapshot, account: String) throws {
    try store.write(snapshot, account: account)
  }
}

/// 签到数据访问边界：组合 iclass 上游服务与按账号隔离的本地快照。
///
/// 缓存写入失败只记录日志，不影响已取得的网络结果；写操作（签到提交）只做单次转发，
/// 不重试、不重复提交，结果判定仍由 ViewModel 依据回查状态给出。
protocol CheckInRepository {
  func cachedSnapshot(account: String) async -> CheckInCacheSnapshot
  func loadToday(account: String) async throws -> CheckInSnapshot
  func load(on date: Date, account: String) async throws -> CheckInSnapshot
  func performSignIn(courseID: String, account: String) async throws -> CheckInActionResult
  func setWebVPNRouteEnabled(_ enabled: Bool) async
  func clearCache(account: String) async throws
}

struct DefaultCheckInRepository: CheckInRepository {
  private let service: CheckInServing
  private let cache: CheckInCache

  init(service: CheckInServing = CheckInClient(), cache: CheckInCache = CheckInCache()) {
    self.service = service
    self.cache = cache
  }

  func cachedSnapshot(account: String) async -> CheckInCacheSnapshot {
    await cache.read(account: account)
  }

  func loadToday(account: String) async throws -> CheckInSnapshot {
    let snapshot = try await service.loadToday(account: account)
    if snapshot.schoolDate == Self.schoolDateString(from: Date()) {
      do { try await cache.saveToday(snapshot, account: account) }
      catch { AppLog.cacheWriteFailed(feature: "checkin-today", error: error) }
    }
    return snapshot
  }

  func load(on date: Date, account: String) async throws -> CheckInSnapshot {
    let snapshot = try await service.loadOnDate(account: account, date: date)
    do { try await cache.saveHistory(snapshot, account: account) }
    catch { AppLog.cacheWriteFailed(feature: "checkin-history", error: error) }
    return snapshot
  }

  func performSignIn(courseID: String, account: String) async throws -> CheckInActionResult {
    try await service.performSignIn(account: account, courseID: courseID)
  }

  /// 探测不到签到专用 WebVPN 能力时保持 no-op，与重构前行为一致。
  func setWebVPNRouteEnabled(_ enabled: Bool) async {
    guard let router = service as? CheckInWebVPNRouting else { return }
    await router.setWebVPNRouteEnabled(enabled)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }

  private static func schoolDateString(from date: Date) -> String {
    SchoolTime.string(from: date, format: "yyyyMMdd")
  }
}

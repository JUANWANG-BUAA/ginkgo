import Foundation

/// 课表数据访问边界：组合上游课表服务与按账号隔离的本地快照。
protocol ScheduleRepository {
  func cachedSnapshot(account: String) async -> ScheduleSnapshot?
  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot
  func save(_ snapshot: ScheduleSnapshot, account: String) async throws
  func clearCache(account: String) async throws
}

struct DefaultScheduleRepository: ScheduleRepository {
  private let service: ScheduleServing
  private let cache: ScheduleCache

  init(service: ScheduleServing = ScheduleClient(), cache: ScheduleCache = ScheduleCache()) {
    self.service = service
    self.cache = cache
  }

  func cachedSnapshot(account: String) async -> ScheduleSnapshot? {
    await cache.read(account: account)
  }

  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    try await service.load(termID: termID, week: week)
  }

  func save(_ snapshot: ScheduleSnapshot, account: String) async throws {
    try await cache.save(snapshot, account: account)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

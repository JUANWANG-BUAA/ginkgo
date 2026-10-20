import Foundation

/// 作业数据访问边界：组合上游来源、可选详情能力和账号隔离快照。
protocol HomeworkRepository {
  func cachedSnapshot(account: String) async -> HomeworkSnapshot?
  func loadSnapshot() async throws -> HomeworkSnapshot
  func loadDetail(for item: HomeworkItem) async throws -> HomeworkDetail?
  func save(_ snapshot: HomeworkSnapshot, account: String) async throws
  func clearCache(account: String) async throws
}

struct DefaultHomeworkRepository: HomeworkRepository {
  private let service: HomeworkServing
  private let detailService: HomeworkDetailServing?
  private let cache: HomeworkCache

  init(
    service: HomeworkServing = HomeworkClient(),
    detailService: HomeworkDetailServing? = nil,
    cache: HomeworkCache = HomeworkCache()
  ) {
    self.service = service
    self.detailService = detailService ?? (service as? HomeworkDetailServing)
    self.cache = cache
  }

  func cachedSnapshot(account: String) async -> HomeworkSnapshot? {
    await cache.read(account: account)
  }

  func loadSnapshot() async throws -> HomeworkSnapshot {
    try await service.load()
  }

  func loadDetail(for item: HomeworkItem) async throws -> HomeworkDetail? {
    guard let detailService else { return nil }
    return try await detailService.loadDetail(for: item)
  }

  func save(_ snapshot: HomeworkSnapshot, account: String) async throws {
    try await cache.save(snapshot, account: account)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

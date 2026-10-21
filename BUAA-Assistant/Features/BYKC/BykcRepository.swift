import Foundation

protocol BykcServing {
  func load() async throws -> BykcSnapshot
}

/// BYKC 数据访问边界：上游服务与按账号隔离的快照缓存。
protocol BykcRepository {
  func cachedSnapshot(account: String) async -> BykcSnapshot?
  func refresh(account: String) async throws -> BykcSnapshot
  func clearCache(account: String) async throws
}

struct DefaultBykcRepository: BykcRepository {
  private let service: BykcServing
  private let cache: BykcCache

  init(service: BykcServing = BykcClient(), cache: BykcCache = BykcCache()) {
    self.service = service
    self.cache = cache
  }

  func cachedSnapshot(account: String) async -> BykcSnapshot? {
    await cache.read(account: account)
  }

  func refresh(account: String) async throws -> BykcSnapshot {
    let snapshot = try await service.load()
    do {
      try await cache.save(snapshot, account: account)
    } catch {
      AppLog.cacheWriteFailed(feature: "bykc", error: error)
    }
    return snapshot
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

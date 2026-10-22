import Foundation

struct CampusNoticesSnapshot: Codable {
  let notices: [CampusNotice]
  let fetchedAt: Date
}

/// 校园通知是公开内容，不按账号区分，只缓存最近一次结果。
actor CampusNoticesCache {
  private let store: LocalStore

  init(directory: URL? = nil) {
    store = LocalStore(module: "Campus", directory: directory)
  }

  func read() -> CampusNoticesSnapshot? {
    store.read(CampusNoticesSnapshot.self, name: "notices")
  }

  func save(_ snapshot: CampusNoticesSnapshot) throws {
    try store.write(snapshot, name: "notices")
  }

  func clear() throws {
    try store.remove(name: "notices")
  }
}

/// 校园通知上游读取边界，便于测试注入合成结果。
protocol CampusNoticesServing {
  func load() async throws -> [CampusNotice]
}

extension CampusNoticesClient: CampusNoticesServing {}

/// 校园通知数据访问边界：上游新闻页与最近一次公开快照。
///
/// 成功加载时在这里打上 `fetchedAt` 并写缓存；写缓存失败只记日志，不改变本次返回。
/// 15 分钟新鲜度与“先显示缓存”的判定仍留在 ViewModel。
protocol CampusNoticesRepository {
  func cached() async -> CampusNoticesSnapshot?
  func load() async throws -> CampusNoticesSnapshot
  func clear() async throws
}

struct DefaultCampusNoticesRepository: CampusNoticesRepository {
  private let service: CampusNoticesServing
  private let cache: CampusNoticesCache

  init(service: CampusNoticesServing = CampusNoticesClient(), cache: CampusNoticesCache = CampusNoticesCache()) {
    self.service = service
    self.cache = cache
  }

  func cached() async -> CampusNoticesSnapshot? {
    await cache.read()
  }

  func load() async throws -> CampusNoticesSnapshot {
    let notices = try await service.load()
    let snapshot = CampusNoticesSnapshot(notices: notices, fetchedAt: Date())
    do {
      try await cache.save(snapshot)
    } catch {
      AppLog.cacheWriteFailed(feature: "campus-notices", error: error)
    }
    return snapshot
  }

  func clear() async throws {
    try await cache.clear()
  }
}

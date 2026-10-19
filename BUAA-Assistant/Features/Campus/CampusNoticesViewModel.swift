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

@MainActor
final class CampusNoticesViewModel: ObservableObject {
  @Published private(set) var notices: [CampusNotice] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isUsingCachedData = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var fetchedAt: Date?

  private let client: CampusNoticesClient
  private let cache: CampusNoticesCache
  private var hasHydratedCache = false

  init(client: CampusNoticesClient = CampusNoticesClient(), cache: CampusNoticesCache = CampusNoticesCache()) {
    self.client = client
    self.cache = cache
  }

  func refresh(force: Bool = false) async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    if !hasHydratedCache {
      if let cached = await cache.read(), notices.isEmpty {
        notices = cached.notices
        fetchedAt = cached.fetchedAt
        isUsingCachedData = true
      }
      hasHydratedCache = true
    }
    if !force, let fetchedAt, Date().timeIntervalSince(fetchedAt) < 15 * 60 { return }
    do {
      let refreshed = try await client.load()
      let refreshedAt = Date()
      notices = refreshed
      fetchedAt = refreshedAt
      isUsingCachedData = false
      errorMessage = nil
      do {
        try await cache.save(CampusNoticesSnapshot(notices: refreshed, fetchedAt: refreshedAt))
      } catch {
        AppLog.cacheWriteFailed(feature: "campus-notices", error: error)
      }
    } catch {
      AppLog.operationFailed(feature: "campus-notices", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "校园通知暂时无法加载"
    }
  }

  func clearCache() async throws {
    try await cache.clear()
    notices = []
    fetchedAt = nil
    isUsingCachedData = false
    errorMessage = nil
    hasHydratedCache = true
  }
}

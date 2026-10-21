import Foundation

struct ClassroomCacheEntry: Codable, Sendable {
  let key: String
  let campus: Int
  let date: Date
  let rooms: [String: [FreeClassroom]]
  let fetchedAt: Date
}

enum ClassroomCachePolicy {
  static let maximumQueries = 12
}

/// 按“校区 + 日期”保存空教室结果，最多保留最近的 12 组查询。
actor ClassroomCache {
  private let store: LocalStore

  init(directory: URL? = nil) {
    store = LocalStore(module: "Classrooms", directory: directory)
  }

  func read(account: String) -> [ClassroomCacheEntry] {
    store.read([ClassroomCacheEntry].self, account: account) ?? []
  }

  func save(_ entry: ClassroomCacheEntry, account: String) throws {
    var entries = read(account: account)
    entries.removeAll { $0.key == entry.key }
    entries.append(entry)
    entries.sort { $0.fetchedAt > $1.fetchedAt }
    try store.write(Array(entries.prefix(ClassroomCachePolicy.maximumQueries)), account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

/// 空教室数据边界：ViewModel 只依赖该接口，不直接协调上游请求和磁盘缓存。
protocol ClassroomRepository {
  func cachedQueries(account: String) async -> [ClassroomCacheEntry]
  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]]
  func save(_ entry: ClassroomCacheEntry, account: String) async throws
  func clearCache(account: String) async throws
}

struct DefaultClassroomRepository: ClassroomRepository {
  private let client: ClassroomServing
  private let cache: ClassroomCache

  init(client: ClassroomServing = ClassroomClient(), cache: ClassroomCache = ClassroomCache()) {
    self.client = client
    self.cache = cache
  }

  func cachedQueries(account: String) async -> [ClassroomCacheEntry] {
    await cache.read(account: account)
  }

  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]] {
    try await client.query(campus: campus, date: date)
  }

  func save(_ entry: ClassroomCacheEntry, account: String) async throws {
    try await cache.save(entry, account: account)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

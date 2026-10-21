import Foundation

struct ExamCacheEntry: Codable {
  let exams: [Exam]
  let fetchedAt: Date
}

/// 按学期保存考试结果，最多保留最近更新的 12 个学期。
actor ExamCache {
  private let store: LocalStore
  private let maximumTerms = 12

  init(directory: URL? = nil) {
    store = LocalStore(module: "Exams", directory: directory)
  }

  func read(account: String, termID: String) -> ExamCacheEntry? {
    store.read([String: ExamCacheEntry].self, account: account)?[termID]
  }

  func save(_ entry: ExamCacheEntry, account: String, termID: String) throws {
    var entries = store.read([String: ExamCacheEntry].self, account: account) ?? [:]
    entries[termID] = entry
    if entries.count > maximumTerms {
      let retained = entries.sorted { $0.value.fetchedAt > $1.value.fetchedAt }.prefix(maximumTerms)
      entries = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
    }
    try store.write(entries, account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

/// 考试数据访问边界：封装上游查询与按账号、学期隔离的快照读写。
protocol ExamRepository {
  func cachedEntry(account: String, termID: String) async -> ExamCacheEntry?
  func load(termID: String) async throws -> [Exam]
  func save(_ entry: ExamCacheEntry, account: String, termID: String) async throws
  func clearCache(account: String) async throws
}

struct DefaultExamRepository: ExamRepository {
  private let service: ExamServing
  private let cache: ExamCache

  init(service: ExamServing = ScheduleClient(), cache: ExamCache = ExamCache()) {
    self.service = service
    self.cache = cache
  }

  func cachedEntry(account: String, termID: String) async -> ExamCacheEntry? {
    await cache.read(account: account, termID: termID)
  }

  func load(termID: String) async throws -> [Exam] {
    try await service.loadExams(termID: termID)
  }

  func save(_ entry: ExamCacheEntry, account: String, termID: String) async throws {
    try await cache.save(entry, account: account, termID: termID)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

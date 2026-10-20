import Foundation

/// 成绩数据访问边界：统一学期发现、成绩查询与账号快照存取。
protocol GradeRepository {
  func cachedSnapshot(account: String) async -> GradeSnapshot?
  func availableTerms() async throws -> [SchoolTerm]
  func load(term: SchoolTerm) async throws -> GradeSnapshot
  func save(_ snapshot: GradeSnapshot, account: String) async throws
  func clearCache(account: String) async throws
}

struct DefaultGradeRepository: GradeRepository {
  private let termService: TermServing
  private let gradeService: GradeServing
  private let cache: GradeCache

  init(
    termService: TermServing = ScheduleClient(),
    gradeService: GradeServing = GradeClient(),
    cache: GradeCache = GradeCache()
  ) {
    self.termService = termService
    self.gradeService = gradeService
    self.cache = cache
  }

  func cachedSnapshot(account: String) async -> GradeSnapshot? {
    await cache.read(account: account)
  }

  func availableTerms() async throws -> [SchoolTerm] {
    try await termService.availableTerms()
  }

  func load(term: SchoolTerm) async throws -> GradeSnapshot {
    try await gradeService.load(term: term)
  }

  func save(_ snapshot: GradeSnapshot, account: String) async throws {
    try await cache.save(snapshot, account: account)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
  }
}

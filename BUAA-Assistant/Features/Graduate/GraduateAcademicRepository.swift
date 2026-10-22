import Foundation

/// 研究生教务数据访问边界：上游教务服务与按账号隔离的版本化快照。
///
/// `load(account:)` 只做网络读取；`retainingSuccessfulData` 的合并规则留在 ViewModel，
/// 合并结果再交回这里写缓存，写失败只记日志、不覆盖内存状态。
protocol GraduateAcademicRepository {
  func cached(account: String) async -> GraduateAcademicSnapshot?
  func load(account: String) async throws -> GraduateAcademicSnapshot
  func save(_ snapshot: GraduateAcademicSnapshot, account: String) async
  func clear(account: String) async throws
}

struct DefaultGraduateAcademicRepository: GraduateAcademicRepository {
  private let service: any GraduateAcademicLoading
  private let cache: GraduateAcademicCache

  init(
    service: any GraduateAcademicLoading = GraduateAcademicClient(),
    cache: GraduateAcademicCache = GraduateAcademicCache()
  ) {
    self.service = service
    self.cache = cache
  }

  func cached(account: String) async -> GraduateAcademicSnapshot? {
    await cache.read(account: account)
  }

  func load(account: String) async throws -> GraduateAcademicSnapshot {
    try await service.load(account: account)
  }

  func save(_ snapshot: GraduateAcademicSnapshot, account: String) async {
    do {
      try await cache.save(snapshot, account: account)
    } catch {
      AppLog.cacheWriteFailed(feature: "graduate-academic", error: error)
    }
  }

  func clear(account: String) async throws {
    try await cache.clear(account: account)
  }
}

import Foundation

@MainActor
final class CampusNoticesViewModel: ObservableObject {
  @Published private(set) var notices: [CampusNotice] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isUsingCachedData = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var fetchedAt: Date?

  private let repository: CampusNoticesRepository
  private var hasHydratedCache = false

  init(repository: CampusNoticesRepository = DefaultCampusNoticesRepository()) {
    self.repository = repository
  }

  func refresh(force: Bool = false) async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    if !hasHydratedCache {
      if let cached = await repository.cached(), notices.isEmpty {
        notices = cached.notices
        fetchedAt = cached.fetchedAt
        isUsingCachedData = true
      }
      hasHydratedCache = true
    }
    if !force, let fetchedAt, Date().timeIntervalSince(fetchedAt) < 15 * 60 { return }
    do {
      let refreshed = try await repository.load()
      notices = refreshed.notices
      fetchedAt = refreshed.fetchedAt
      isUsingCachedData = false
      errorMessage = nil
    } catch {
      AppLog.operationFailed(feature: "campus-notices", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "校园通知暂时无法加载"
    }
  }

  func clearCache() async throws {
    try await repository.clear()
    notices = []
    fetchedAt = nil
    isUsingCachedData = false
    errorMessage = nil
    hasHydratedCache = true
  }
}

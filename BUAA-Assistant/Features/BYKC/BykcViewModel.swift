import Foundation

@MainActor
final class BykcViewModel: ObservableObject {
  @Published private(set) var snapshot: BykcSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var isShowingCachedData = false
  @Published var searchText = ""
  @Published var selectedCategory: BykcCourseCategorySelection = .all

  private let repository: BykcRepository
  private var account: String?
  private var hasLoaded = false
  private var generation = 0

  init(repository: BykcRepository) {
    self.repository = repository
  }

  var categories: [BykcCourseCategorySelection] {
    [.all] + BykcCourseCatalog.categoryCounts(in: snapshot?.courses ?? []).map(\.category)
  }

  var filteredCourses: [BykcCourse] {
    BykcCourseCatalog.filtered(
      snapshot?.courses ?? [],
      by: BykcCourseFilter(searchText: searchText, category: selectedCategory)
    )
  }

  func start(account: String) async {
    guard account.isEmpty == false else { return }
    if self.account != account {
      generation += 1
      isLoading = false
      snapshot = nil
      hasLoaded = false
      isShowingCachedData = false
      errorMessage = nil
      searchText = ""
      selectedCategory = .all
      self.account = account
    }
    guard hasLoaded == false, isLoading == false else { return }
    let current = generation
    isLoading = true
    defer {
      if current == generation { isLoading = false }
    }
    errorMessage = nil
    if let cached = await repository.cachedSnapshot(account: account) {
      guard current == generation else { return }
      snapshot = cached
      isShowingCachedData = true
    }
    await loadFreshSnapshot(account: account, generation: current)
    if current == generation { hasLoaded = snapshot != nil }
  }

  func refresh(account overrideAccount: String? = nil) async {
    let target = overrideAccount ?? account
    guard let target, target.isEmpty == false else { return }
    if account != target {
      await start(account: target)
      return
    }
    guard isLoading == false else { return }
    let current = generation
    isLoading = true
    defer {
      if current == generation { isLoading = false }
    }
    await loadFreshSnapshot(account: target, generation: current)
    if current == generation { hasLoaded = snapshot != nil }
  }

  /// 进入页面时先显示缓存，再按时间阈值主动刷新。
  func refreshIfStale(account: String, maxAge: TimeInterval = 2 * 60) async {
    if self.account != account {
      await start(account: account)
      return
    }
    if let snapshot,
       Date().timeIntervalSince(snapshot.fetchedAt) < maxAge,
       errorMessage == nil {
      return
    }
    await refresh(account: account)
  }

  func clearCache(account: String) async throws {
    generation += 1
    let current = generation
    isLoading = false
    try await repository.clearCache(account: account)
    guard current == generation else { return }
    snapshot = nil
    self.account = nil
    hasLoaded = false
    isShowingCachedData = false
    errorMessage = nil
    searchText = ""
    selectedCategory = .all
  }

  private func loadFreshSnapshot(account: String, generation current: Int) async {
    errorMessage = nil
    do {
      let loaded = try await repository.refresh(account: account)
      guard current == generation, self.account == account else { return }
      snapshot = loaded
      isShowingCachedData = false
    } catch {
      guard current == generation, self.account == account else { return }
      if RequestCancellation.isCancellation(error) == false {
        AppLog.operationFailed(feature: "bykc", stage: "refresh", error: error)
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "博雅更新失败，请检查网络后重试"
      }
      if snapshot == nil { hasLoaded = false }
    }
  }
}

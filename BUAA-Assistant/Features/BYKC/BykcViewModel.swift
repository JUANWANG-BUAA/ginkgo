import Foundation

@MainActor
final class BykcViewModel: ObservableObject {
  @Published private(set) var snapshot: BykcSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var isShowingCachedData = false
  @Published var searchText = ""
  @Published var selectedCategory = "全部"

  private let client: BykcClient
  private let cache: BykcCache
  private var account: String?
  private var hasLoaded = false

  init(client: BykcClient = BykcClient(), cache: BykcCache = BykcCache()) {
    self.client = client
    self.cache = cache
  }

  var categories: [String] {
    ["全部"] + (snapshot?.categoryCounts.map(\.0) ?? [])
  }

  var filteredCourses: [BykcCourse] {
    guard let courses = snapshot?.courses else { return [] }
    return courses.filter { course in
      let categoryMatches = selectedCategory == "全部" || course.filterCategory == selectedCategory
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let searchMatches = query.isEmpty
        || course.name.localizedCaseInsensitiveContains(query)
        || (course.teacher?.localizedCaseInsensitiveContains(query) ?? false)
        || (course.position?.localizedCaseInsensitiveContains(query) ?? false)
      return categoryMatches && searchMatches
    }
  }

  func start(account: String) async {
    if self.account != account {
      snapshot = nil
      hasLoaded = false
      isShowingCachedData = false
      self.account = account
    }
    guard hasLoaded == false else { return }
    if let cached = await cache.read(account: account) {
      snapshot = cached
      isShowingCachedData = true
    }
    await refresh(account: account)
    hasLoaded = snapshot != nil
  }

  func refresh(account overrideAccount: String? = nil) async {
    guard isLoading == false else { return }
    let target = overrideAccount ?? account
    guard let target, target.isEmpty == false else { return }
    isLoading = true
    defer { isLoading = false }
    errorMessage = nil
    do {
      let loaded = try await client.load()
      snapshot = loaded
      isShowingCachedData = false
      do { try await cache.save(loaded, account: target) }
      catch { AppLog.cacheWriteFailed(feature: "bykc", error: error) }
    } catch {
      if RequestCancellation.isCancellation(error) == false {
        AppLog.operationFailed(feature: "bykc", stage: "refresh", error: error)
        errorMessage = error.localizedDescription
      }
      if snapshot == nil {
        hasLoaded = false
      }
    }
  }

  /// 进入页面时先显示缓存，再按时间阈值主动刷新。
  func refreshIfStale(account: String, maxAge: TimeInterval = 2 * 60) async {
    if let snapshot,
       Date().timeIntervalSince(snapshot.fetchedAt) < maxAge,
       errorMessage == nil {
      return
    }
    await refresh(account: account)
  }

  func clearCache(account: String) async throws {
    try await cache.clear(account: account)
    snapshot = nil
    self.account = nil
    hasLoaded = false
    isShowingCachedData = false
  }
}

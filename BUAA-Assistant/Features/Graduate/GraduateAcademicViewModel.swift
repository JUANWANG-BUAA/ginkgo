import Foundation

@MainActor
final class GraduateAcademicViewModel: ObservableObject {
  @Published private(set) var snapshot: GraduateAcademicSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var isShowingCachedData = false

  private let client: any GraduateAcademicLoading
  private let cache: GraduateAcademicCache
  private var generation = 0
  private var loadedAccount: String?

  init(cache: GraduateAcademicCache = GraduateAcademicCache(), client: any GraduateAcademicLoading = GraduateAcademicClient()) {
    self.client = client
    self.cache = cache
  }

  func start(account: String) async {
    guard loadedAccount != account else { return }
    generation += 1
    isLoading = false
    loadedAccount = account
    snapshot = nil
    isShowingCachedData = false
    let current = generation
    if let cached = await cache.read(account: account), current == generation {
      snapshot = cached
      isShowingCachedData = true
    }
    guard current == generation else { return }
    await refresh(account: account)
  }

  func refresh(account: String) async {
    guard isLoading == false else { return }
    if loadedAccount == nil { loadedAccount = account }
    guard loadedAccount == account else { return }
    let current = generation
    isLoading = true
    defer { if current == generation { isLoading = false } }
    errorMessage = nil
    do {
      let loaded = try await client.load(account: account)
      guard current == generation, loadedAccount == account else { return }
      let merged = loaded.retainingSuccessfulData(from: snapshot)
      snapshot = merged
      isShowingCachedData = false
      do { try await cache.save(merged, account: account) }
      catch { AppLog.cacheWriteFailed(feature: "graduate-academic", error: error) }
    } catch {
      guard current == generation else { return }
      if RequestCancellation.isCancellation(error) == false {
        AppLog.operationFailed(feature: "graduate-academic", stage: "refresh", error: error)
        errorMessage = error.localizedDescription
      }
      if snapshot == nil {
        loadedAccount = nil
      }
    }
  }

  /// 进入页面时先显示缓存，再按时间阈值主动刷新，避免每次都整页等待。
  func refreshIfStale(account: String, maxAge: TimeInterval = 2 * 60) async {
    if let snapshot,
       Date().timeIntervalSince(snapshot.fetchedAt) < maxAge,
       errorMessage == nil {
      return
    }
    await refresh(account: account)
  }

  func clearCache(account: String) async throws {
    generation += 1
    isLoading = false
    try await cache.clear(account: account)
    snapshot = nil
    loadedAccount = nil
    isShowingCachedData = false
  }
}

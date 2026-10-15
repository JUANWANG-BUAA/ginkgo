import Foundation

@MainActor
final class HomeworkViewModel: ObservableObject {
  @Published private(set) var snapshot: HomeworkSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false

  private let service: HomeworkServing
  private let cache: HomeworkCache
  private var account: String?
  private var generation = 0

  init(service: HomeworkServing = HomeworkClient(), cache: HomeworkCache = HomeworkCache()) {
    self.service = service
    self.cache = cache
  }

  var pendingItems: [HomeworkItem] {
    snapshot?.items.filter { $0.status == .pending || $0.status == .overdue }
      .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) } ?? []
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    isLoading = true
    let current = generation
    snapshot = await cache.read(account: account)
    guard current == generation else { return }
    await refresh()
  }

  func reset() {
    generation += 1
    account = nil
    snapshot = nil
    isLoading = false
    errorMessage = nil
    needsSessionCheck = false
  }

  func refresh() async {
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    needsSessionCheck = false
    defer { if current == generation { isLoading = false } }
    do {
      let result = try await service.load()
      guard current == generation else { return }
      snapshot = result
      if let account { try? await cache.save(result, account: account) }
    } catch {
      guard current == generation else { return }
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "学校作业更新失败"
      if case HomeworkError.sessionExpired = error { needsSessionCheck = true }
    }
  }

  func clearCache() async throws {
    guard let account else { return }
    try await cache.clear(account: account)
    reset()
  }
}

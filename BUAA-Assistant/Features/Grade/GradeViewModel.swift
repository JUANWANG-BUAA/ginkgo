import Foundation

@MainActor
final class GradeViewModel: ObservableObject {
  @Published private(set) var terms: [SchoolTerm] = []
  @Published private(set) var snapshot: GradeSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var feedback: String?
  @Published private(set) var needsSessionCheck = false

  private let repository: GradeRepository
  private var account: String?
  private var generation = 0
  private var autoRefresh = AutoRefreshGate()

  init(repository: GradeRepository) {
    self.repository = repository
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    isLoading = true
    let current = generation
    let cached = await repository.cachedSnapshot(account: account)
    guard current == generation else { return }
    snapshot = cached
    await refresh()
  }

  func reset() {
    generation += 1
    account = nil
    autoRefresh.reset()
    terms = []
    snapshot = nil
    isLoading = false
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
  }

  func clearCache(account overrideAccount: String? = nil) async throws {
    guard let account = overrideAccount ?? self.account else { return }
    try await repository.clearCache(account: account)
    reset()
  }

  func refreshIfStale(
    maxAge: TimeInterval = 15 * 60,
    queueIfLoading: Bool = false,
    bypassCooldown: Bool = false,
    forceRefresh: Bool = false
  ) async {
    guard account != nil else { return }
    if isLoading { autoRefresh.deferWhileLoading(queue: queueIfLoading); return }
    let isStale = snapshot.map { Date().timeIntervalSince($0.fetchedAt) >= maxAge } ?? true
    guard forceRefresh || errorMessage != nil || isStale,
          autoRefresh.allowsAttempt(force: forceRefresh, bypassCooldown: bypassCooldown) else { return }
    await refresh()
  }

  func refresh(term: SchoolTerm? = nil) async {
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
    defer { finishRefresh(current: current) }
    do {
      if terms.isEmpty {
        let available = try await repository.availableTerms()
        guard current == generation else { return }
        terms = available
      }
      let chosen = term ?? terms.first(where: { $0.id == snapshot?.term.id })
        ?? terms.first(where: \.isSelected) ?? terms.first
      guard let chosen else { throw ScheduleError.invalidTerm }
      let result = try await repository.load(term: chosen)
      guard current == generation else { return }
      snapshot = result
      feedback = "成绩已更新"
      if let account {
        do { try await repository.save(result, account: account) }
        catch { AppLog.cacheWriteFailed(feature: "grades", error: error) }
      }
    } catch {
      guard current == generation else { return }
      if RequestCancellation.isCancellation(error) { return }
      AppLog.operationFailed(feature: "grades", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "成绩更新失败，请检查网络后重试"
      if let failure = error as? ScheduleError, case .sessionExpired = failure { needsSessionCheck = true }
    }
  }

  func cancelPendingAutomaticRefresh() {
    autoRefresh.cancelPending()
  }

  private func finishRefresh(current: Int) {
    guard current == generation else { return }
    isLoading = false
    guard autoRefresh.takePending() else { return }
    Task { await refreshIfStale(bypassCooldown: true) }
  }
}

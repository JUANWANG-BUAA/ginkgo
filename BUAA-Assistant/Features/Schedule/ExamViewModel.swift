import Foundation

@MainActor
final class ExamViewModel: ObservableObject {
  @Published private(set) var exams: [Exam]?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var loadedTermID: String?
  @Published private(set) var resultsAreCached = false
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false

  private let repository: ExamRepository
  private var account: String?
  private var generation = 0
  private var autoRefresh = AutoRefreshGate()

  init(repository: ExamRepository) {
    self.repository = repository
  }

  func load(termID: String, force: Bool = false, account: String? = nil) async {
    guard !termID.isEmpty else { return }
    if let account, self.account != account {
      generation += 1
      autoRefresh.reset()
      exams = nil
      fetchedAt = nil
      loadedTermID = nil
      resultsAreCached = false
      self.account = account
    }
    let termChanged = loadedTermID != termID
    if termChanged {
      exams = nil
      fetchedAt = nil
      loadedTermID = nil
      resultsAreCached = false
      errorMessage = nil
    }
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    needsSessionCheck = false
    defer { finishRefresh(current: current) }

    if termChanged, let account = self.account,
       let cached = await repository.cachedEntry(account: account, termID: termID) {
      guard current == generation else { return }
      exams = cached.exams
      fetchedAt = cached.fetchedAt
      loadedTermID = termID
      resultsAreCached = true
    }
    if !force, loadedTermID == termID, exams != nil,
       let fetchedAt, Date().timeIntervalSince(fetchedAt) < 15 * 60 { return }
    if exams != nil { resultsAreCached = true }

    do {
      let result = try await repository.load(termID: termID)
      guard current == generation else { return }
      exams = result
      fetchedAt = Date()
      loadedTermID = termID
      resultsAreCached = false
      if let account = self.account {
        let refreshedAt = fetchedAt ?? Date()
        do {
          try await repository.save(ExamCacheEntry(exams: result, fetchedAt: refreshedAt), account: account, termID: termID)
        } catch {
          AppLog.cacheWriteFailed(feature: "exams", error: error)
        }
      }
    } catch {
      guard current == generation else { return }
      AppLog.operationFailed(feature: "exams", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "考试安排读取失败，请稍后重试"
      if let error = error as? ScheduleError, case .sessionExpired = error {
        needsSessionCheck = true
      }
    }
  }

  func reset() {
    generation += 1
    autoRefresh.reset()
    exams = nil
    fetchedAt = nil
    loadedTermID = nil
    resultsAreCached = false
    account = nil
    isLoading = false
    errorMessage = nil
    needsSessionCheck = false
  }

  func refreshIfStale(
    maxAge: TimeInterval = 15 * 60,
    queueIfLoading: Bool = false,
    bypassCooldown: Bool = false,
    forceRefresh: Bool = false
  ) async {
    guard account != nil else { return }
    if isLoading { autoRefresh.deferWhileLoading(queue: queueIfLoading); return }
    guard let termID = loadedTermID else { return }
    let isStale = fetchedAt.map { Date().timeIntervalSince($0) >= maxAge } ?? true
    guard forceRefresh || errorMessage != nil || isStale,
          autoRefresh.allowsAttempt(force: forceRefresh, bypassCooldown: bypassCooldown) else { return }
    await load(termID: termID, force: true)
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

  func clearCache(account overrideAccount: String? = nil) async throws {
    if let account = overrideAccount ?? account { try await repository.clearCache(account: account) }
    reset()
  }
}

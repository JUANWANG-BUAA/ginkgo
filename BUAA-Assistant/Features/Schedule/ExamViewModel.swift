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

@MainActor
final class ExamViewModel: ObservableObject {
  @Published private(set) var exams: [Exam]?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var loadedTermID: String?
  @Published private(set) var resultsAreCached = false
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false

  private let service: ExamServing
  private let cache: ExamCache
  private var account: String?
  private var generation = 0
  private var autoRefresh = AutoRefreshGate()

  init(service: ExamServing = ScheduleClient(), cache: ExamCache = ExamCache()) {
    self.service = service
    self.cache = cache
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
       let cached = await cache.read(account: account, termID: termID) {
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
      let result = try await service.loadExams(termID: termID)
      guard current == generation else { return }
      exams = result
      fetchedAt = Date()
      loadedTermID = termID
      resultsAreCached = false
      if let account = self.account {
        let refreshedAt = fetchedAt ?? Date()
        do {
          try await cache.save(ExamCacheEntry(exams: result, fetchedAt: refreshedAt), account: account, termID: termID)
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
    if let account = overrideAccount ?? account { try await cache.clear(account: account) }
    reset()
  }
}

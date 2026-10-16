import Foundation

@MainActor
final class ScheduleViewModel: ObservableObject {
  @Published private(set) var snapshot: ScheduleSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var feedback: String?
  @Published private(set) var needsSessionCheck = false
  @Published private(set) var reminderRevision = 0

  private let service: ScheduleServing
  private let cache: ScheduleCache
  private var account: String?
  private var generation = 0
  private var lastAutomaticRefreshAttemptAt: Date?
  private var pendingAutomaticRefresh = false
  private var pendingAutomaticRefreshForCurrentWeek = false

  init(service: ScheduleServing = ScheduleClient(), cache: ScheduleCache = ScheduleCache()) {
    self.service = service
    self.cache = cache
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    isLoading = true
    let current = generation
    let cached = await cache.read(for: account)
    guard current == generation else { return }
    snapshot = cached
    reminderRevision += 1
    await refresh(termID: snapshot?.termID)
  }

  func reset() {
    generation += 1
    account = nil
    lastAutomaticRefreshAttemptAt = nil
    pendingAutomaticRefresh = false
    pendingAutomaticRefreshForCurrentWeek = false
    snapshot = nil
    reminderRevision += 1
    isLoading = false
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
  }

  func refreshToday() async {
    await refresh(termID: snapshot?.terms.first(where: \.isSelected)?.id, currentWeek: true)
  }

  func refreshIfStale(
    currentWeek: Bool = false,
    maxAge: TimeInterval = 15 * 60,
    queueIfLoading: Bool = false,
    bypassCooldown: Bool = false,
    forceRefresh: Bool = false
  ) async {
    guard account != nil else { return }
    if isLoading {
      if queueIfLoading {
        pendingAutomaticRefresh = true
        pendingAutomaticRefreshForCurrentWeek = pendingAutomaticRefreshForCurrentWeek || currentWeek
      }
      return
    }
    let now = Date()
    let isStale = snapshot.map { now.timeIntervalSince($0.fetchedAt) >= maxAge } ?? true
    guard forceRefresh || errorMessage != nil || isStale else { return }
    let cooldown: TimeInterval = forceRefresh ? 5 : 30
    if !bypassCooldown, let lastAutomaticRefreshAttemptAt,
       now.timeIntervalSince(lastAutomaticRefreshAttemptAt) < cooldown { return }
    lastAutomaticRefreshAttemptAt = now
    if currentWeek { await refreshToday() } else { await refresh() }
  }

  func refresh(termID: String? = nil, week: Int? = nil, currentWeek: Bool = false) async {
    if let week, let snapshot, termID == nil, let courses = snapshot.termCourses?[String(week)] {
      generation += 1
      isLoading = false
      feedback = nil
      self.snapshot = ScheduleSnapshot(portal: snapshot.portal, terms: snapshot.terms, termID: snapshot.termID,
                                       weeks: snapshot.weeks, weekNumber: week, courses: courses, fetchedAt: snapshot.fetchedAt,
                                       termCourses: snapshot.termCourses)
      reminderRevision += 1
      return
    }
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
    defer { finishRefresh(current: current) }
    do {
      var newSnapshot = try await service.load(termID: termID ?? snapshot?.termID,
                                               week: currentWeek ? nil : week ?? (termID == nil ? snapshot?.weekNumber : nil))
      guard current == generation else { return }
      if newSnapshot.termCourses == nil {
        var known = snapshot?.termID == newSnapshot.termID ? snapshot?.termCourses ?? [:] : [:]
        known[String(newSnapshot.weekNumber)] = newSnapshot.courses
        newSnapshot.termCourses = known
      }
      snapshot = newSnapshot
      reminderRevision += 1
      feedback = "课表已更新"
      if let account {
        do { try await cache.save(newSnapshot, for: account) }
        catch { AppLog.cacheWriteFailed(feature: "schedule", error: error) }
      }
    } catch {
      guard current == generation else { return }
      AppLog.operationFailed(feature: "schedule", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "课表更新失败，请检查网络后重试"
      if let failure = error as? ScheduleError, case .sessionExpired = failure { needsSessionCheck = true }
    }
  }

  func cancelPendingAutomaticRefresh() {
    pendingAutomaticRefresh = false
    pendingAutomaticRefreshForCurrentWeek = false
  }

  private func finishRefresh(current: Int) {
    guard current == generation else { return }
    isLoading = false
    guard pendingAutomaticRefresh else { return }
    let currentWeek = pendingAutomaticRefreshForCurrentWeek
    cancelPendingAutomaticRefresh()
    Task { await refreshIfStale(currentWeek: currentWeek, bypassCooldown: true) }
  }
}

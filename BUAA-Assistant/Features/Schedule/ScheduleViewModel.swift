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
  private var autoRefresh = AutoRefreshGate()
  private var pendingRefreshTargetsCurrentWeek = false

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
    let cached = await cache.read(account: account)
    guard current == generation else { return }
    snapshot = cached
    reminderRevision += 1
    await refresh(termID: snapshot?.termID)
  }

  func reset() {
    generation += 1
    account = nil
    autoRefresh.reset()
    pendingRefreshTargetsCurrentWeek = false
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
      autoRefresh.deferWhileLoading(queue: queueIfLoading)
      if queueIfLoading { pendingRefreshTargetsCurrentWeek = pendingRefreshTargetsCurrentWeek || currentWeek }
      return
    }
    let isStale = snapshot.map { Date().timeIntervalSince($0.fetchedAt) >= maxAge } ?? true
    guard forceRefresh || errorMessage != nil || isStale,
          autoRefresh.allowsAttempt(force: forceRefresh, bypassCooldown: bypassCooldown) else { return }
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
        do { try await cache.save(newSnapshot, account: account) }
        catch { AppLog.cacheWriteFailed(feature: "schedule", error: error) }
      }
    } catch {
      guard current == generation else { return }
      if RequestCancellation.isCancellation(error) { return }
      AppLog.operationFailed(feature: "schedule", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "课表更新失败，请检查网络后重试"
      if let failure = error as? ScheduleError, case .sessionExpired = failure { needsSessionCheck = true }
    }
  }

  func cancelPendingAutomaticRefresh() {
    autoRefresh.cancelPending()
    pendingRefreshTargetsCurrentWeek = false
  }

  private func finishRefresh(current: Int) {
    guard current == generation else { return }
    isLoading = false
    guard autoRefresh.takePending() else { return }
    let currentWeek = pendingRefreshTargetsCurrentWeek
    pendingRefreshTargetsCurrentWeek = false
    Task { await refreshIfStale(currentWeek: currentWeek, bypassCooldown: true) }
  }
}

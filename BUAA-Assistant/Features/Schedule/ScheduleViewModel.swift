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
    defer { if current == generation { isLoading = false } }
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
      if let account { try? await cache.save(newSnapshot, for: account) }
    } catch {
      guard current == generation else { return }
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "课表更新失败，请检查网络后重试"
      if let failure = error as? ScheduleError, case .sessionExpired = failure { needsSessionCheck = true }
    }
  }
}

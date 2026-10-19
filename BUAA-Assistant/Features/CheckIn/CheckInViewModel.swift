import Foundation
import UserNotifications

struct CheckInCacheSnapshot: Codable {
  var today: CheckInSnapshot?
  var history: [String: CheckInSnapshot]
}

/// 当天状态与最多 180 个历史日期的签到快照。
actor CheckInCache {
  private let store: LocalStore
  private let maximumHistoryDays = 180

  init(directory: URL? = nil) {
    store = LocalStore(module: "CheckIn", directory: directory)
  }

  func read(account: String) -> CheckInCacheSnapshot {
    store.read(CheckInCacheSnapshot.self, account: account) ?? CheckInCacheSnapshot(today: nil, history: [:])
  }

  func saveToday(_ snapshot: CheckInSnapshot, account: String) throws {
    var cached = read(account: account)
    cached.today = snapshot
    try save(cached, account: account)
  }

  func saveHistory(_ snapshot: CheckInSnapshot, account: String) throws {
    var cached = read(account: account)
    cached.history[snapshot.schoolDate] = snapshot
    if cached.history.count > maximumHistoryDays {
      let retained = cached.history.values.sorted { $0.fetchedAt > $1.fetchedAt }.prefix(maximumHistoryDays)
      cached.history = Dictionary(uniqueKeysWithValues: retained.map { ($0.schoolDate, $0) })
    }
    try save(cached, account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }

  private func save(_ snapshot: CheckInCacheSnapshot, account: String) throws {
    try store.write(snapshot, account: account)
  }
}

@MainActor
final class CheckInViewModel: ObservableObject {
  @Published private(set) var snapshot: CheckInSnapshot?
  @Published private(set) var snapshotIsCached = false
  @Published private(set) var historySnapshot: CheckInSnapshot?
  @Published private(set) var historyIsCached = false
  @Published private(set) var historyDate: Date?
  @Published private(set) var historyIsLoading = false
  @Published private(set) var historyErrorMessage: String?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false
  @Published private(set) var webVPNAuthenticationUnavailable = false
  @Published private(set) var iclassStatusRejected = false
  @Published private(set) var statusChangeRevision = 0
  @Published private(set) var statusChangeMessage: String?
  @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
  @Published private(set) var notificationsEnabled: Bool
  @Published private(set) var isSigningInCourseID: String?
  @Published private(set) var actionMessage: String?
  @Published private(set) var actionSucceeded = false

  private let service: CheckInServing
  private let notifications: CheckInNotificationServing
  private let userDefaults: UserDefaults
  private let cache: CheckInCache
  private var account: String?
  private var generation = 0
  private var historyGeneration = 0

  private static let notificationPreferenceKey = "checkInStatusNotificationsEnabled"

  var canSubmitSignIn: Bool { !snapshotIsCached }

  init(
    service: CheckInServing = CheckInClient(),
    notifications: CheckInNotificationServing? = nil,
    userDefaults: UserDefaults = .standard,
    cache: CheckInCache = CheckInCache()
  ) {
    self.service = service
    self.notifications = notifications ?? SystemCheckInNotificationClient()
    self.userDefaults = userDefaults
    self.cache = cache
    notificationsEnabled = userDefaults.object(forKey: Self.notificationPreferenceKey) as? Bool ?? true
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    let current = generation
    let cached = await cache.read(account: account)
    guard current == generation, self.account == account else { return }
    if let today = cached.today, today.schoolDate == Self.schoolDateString(from: Date()) {
      snapshot = today
      snapshotIsCached = true
    }
    await refreshNotificationAuthorization()
    await refresh()
  }

  func refreshOnAppearance(account: String) async {
    guard self.account == account else {
      await start(account: account)
      return
    }
    guard !isLoading else { return }
    await refresh()
  }

  func notificationHint(webVPNSessionStatus: WebVPNSessionStatus) -> String {
    let sessionHint: String
    switch webVPNSessionStatus {
    case .notAttempted:
      sessionHint = "登录后会建立签到专用 WebVPN 会话。"
    case .preparing:
      sessionHint = "正在建立签到专用 WebVPN 会话…"
    case .ready:
      sessionHint = "WebVPN CAS 会话已验证；签到结果仍以 iclass 实际返回为准。"
    case .requiresCaptcha:
      sessionHint = "WebVPN 登录需要验证码，签到状态暂未确认；请完成登录后重试。"
    case .unavailable:
      sessionHint = "WebVPN 会话未建立，签到状态暂未确认；请检查网络并重试登录。"
    }

    let notificationHint: String
    if !notificationsEnabled {
      notificationHint = "应用内已关闭系统签到通知；页面状态和应用内提示仍会正常更新。"
    } else {
      switch notificationAuthorization {
      case .notDetermined:
        notificationHint = "开启通知后，只在确认状态变化时提醒。"
      case .denied:
        notificationHint = "系统通知已关闭，可在系统设置 → 通知 → Ginkgo 中开启。"
      case .authorized, .provisional, .ephemeral:
        notificationHint = "系统通知已开启，只在确认状态变化后提醒。"
      @unknown default:
        notificationHint = "通知权限状态暂不可用。"
      }
    }
    return "\(sessionHint)\(notificationHint) 联网时自动核对，正常约每 30 秒；暂时失败后会放慢重试。签到仅在你确认后提交。"
  }

  func refreshNotificationAuthorization() async {
    notificationAuthorization = await notifications.authorizationStatus()
  }

  func requestNotificationAuthorization() async -> Bool {
    do {
      _ = try await notifications.requestAuthorization()
      await refreshNotificationAuthorization()
      return notificationAuthorization == .authorized || notificationAuthorization == .provisional
    } catch {
      let notificationError = error as NSError
      AppLog.network.error(
        "请求系统通知权限失败 error_domain=\(notificationError.domain, privacy: .public) error_code=\(notificationError.code)"
      )
      await refreshNotificationAuthorization()
      return false
    }
  }

  func notifyStatusChange() {
    guard notificationsEnabled,
          notificationAuthorization == .authorized || notificationAuthorization == .provisional else { return }
    notifications.sendStatusChangeNotification()
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    guard notificationsEnabled != enabled else { return }
    notificationsEnabled = enabled
    userDefaults.set(enabled, forKey: Self.notificationPreferenceKey)
  }

  func reset() {
    generation += 1
    historyGeneration += 1
    account = nil
    snapshot = nil
    snapshotIsCached = false
    historySnapshot = nil
    historyIsCached = false
    historyDate = nil
    historyIsLoading = false
    historyErrorMessage = nil
    isLoading = false
    errorMessage = nil
    needsSessionCheck = false
    webVPNAuthenticationUnavailable = false
    iclassStatusRejected = false
    statusChangeMessage = nil
    isSigningInCourseID = nil
    actionMessage = nil
    actionSucceeded = false
  }

  func refresh() async {
    await refresh(checkPrimarySessionOnFailure: true)
  }

  func refreshAfterSessionValidation() async {
    await refresh(checkPrimarySessionOnFailure: false)
  }

  func loadHistory(on date: Date) async {
    guard let account else { return }
    historyGeneration += 1
    let current = historyGeneration
    historyDate = date
    historyIsLoading = true
    historyErrorMessage = nil
    defer { if current == historyGeneration { historyIsLoading = false } }

    let schoolDate = Self.schoolDateString(from: date)
    if historySnapshot?.schoolDate != schoolDate {
      historySnapshot = nil
      historyIsCached = false
    }
    if historySnapshot == nil {
      let cached = await cache.read(account: account)
      guard current == historyGeneration, self.account == account else { return }
      if let history = cached.history[schoolDate] {
        historySnapshot = history
        historyIsCached = true
      }
    }

    do {
      let result = try await service.loadOnDate(account: account, date: date)
      guard current == historyGeneration else { return }
      historySnapshot = result
      historyIsCached = false
      do { try await cache.saveHistory(result, account: account) }
      catch { AppLog.cacheWriteFailed(feature: "checkin-history", error: error) }
    } catch {
      guard current == historyGeneration else { return }
      AppLog.operationFailed(feature: "checkin", stage: "history", error: error)
      historyErrorMessage = (error as? LocalizedError)?.errorDescription ?? CheckInError.unavailable.errorDescription
    }
  }

  func setWebVPNRouteEnabled(_ enabled: Bool) async {
    guard let router = service as? CheckInWebVPNRouting else { return }
    await router.setWebVPNRouteEnabled(enabled)
  }

  private func refresh(checkPrimarySessionOnFailure: Bool) async {
    guard let account, !isLoading else { return }
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    needsSessionCheck = false
    webVPNAuthenticationUnavailable = false
    iclassStatusRejected = false
    defer { if current == generation { isLoading = false } }

    do {
      let updated = try await service.loadToday(account: account)
      guard current == generation else { return }
      if let snapshot {
        var oldStatuses: [String: CheckInStatus] = [:]
        snapshot.items.forEach { oldStatuses[$0.id] = $0.status }
        let newlySigned = updated.items.filter {
          oldStatuses[$0.id] == .notSigned && $0.status == .signed
        }
        if !newlySigned.isEmpty {
          statusChangeMessage = newlySigned.map(\.courseName).joined(separator: "、") + "：签到状态已确认"
          statusChangeRevision += 1
        }
      }
      snapshot = updated
      snapshotIsCached = false
      if updated.schoolDate == Self.schoolDateString(from: Date()) {
        do { try await cache.saveToday(updated, account: account) }
        catch { AppLog.cacheWriteFailed(feature: "checkin-today", error: error) }
      }
    } catch {
      guard current == generation else { return }
      AppLog.operationFailed(feature: "checkin", stage: "today", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? CheckInError.unavailable.errorDescription
      if case CheckInError.sessionExpired = error, checkPrimarySessionOnFailure { needsSessionCheck = true }
      if case CheckInError.webVPNUnavailable = error { webVPNAuthenticationUnavailable = true }
      if case CheckInError.serviceSessionRejected = error { iclassStatusRejected = true }
    }
  }

  func clearCache(account overrideAccount: String? = nil) async throws {
    guard let targetAccount = overrideAccount ?? account else { return }
    try await cache.clear(account: targetAccount)
    if targetAccount == account {
      snapshot = nil
      snapshotIsCached = false
      historySnapshot = nil
      historyIsCached = false
      historyDate = nil
      historyErrorMessage = nil
    }
  }

  private static func schoolDateString(from date: Date) -> String {
    SchoolTime.string(from: date, format: "yyyyMMdd")
  }

  func clearWebVPNAuthenticationFailure() {
    webVPNAuthenticationUnavailable = false
  }

  private func confirmedSigned(courseID: String) -> Bool {
    CheckInTargetMatcher.isSigned(courseID: courseID, in: snapshot?.items ?? [])
  }

  func performSignIn(courseID: String) async {
    guard let account, isSigningInCourseID == nil else { return }
    isSigningInCourseID = courseID
    actionMessage = nil
    actionSucceeded = false
    defer { isSigningInCourseID = nil }

    do {
      let result = try await service.performSignIn(account: account, courseID: courseID)
      actionMessage = result.message
      guard result.succeeded || result.requiresStatusRefresh else { return }

      await refresh()
      if errorMessage != nil {
        actionMessage = result.responseFormatUnrecognized
          ? "签到提交响应格式无法识别，接口可能已调整；状态回查失败，请勿重复提交，稍后刷新或到原站核实"
          : "签到结果尚未确认；状态回查暂时失败，请勿重复提交，稍后刷新或到原站核实"
      } else if confirmedSigned(courseID: courseID) {
        actionSucceeded = true
        if result.responseFormatUnrecognized {
          actionMessage = "课程已签到，状态回查已确认；提交响应格式无法识别，接口可能已调整"
        } else {
          actionMessage = result.succeeded ? "签到成功，课程状态已回查确认" : "课程已签到，状态已回查确认"
        }
      } else if result.responseFormatUnrecognized {
        actionMessage = "签到提交响应格式无法识别，接口可能已调整；状态回查未确认签到，请勿立即重复提交，稍后刷新或到原站核实"
      } else if result.requiresStatusRefresh {
        actionMessage = "签到状态尚未确认；已回查但未确认成功，请勿立即重复提交，稍后刷新或到原站核实"
      } else {
        actionMessage = result.succeeded
          ? "学校已返回签到成功，课程状态尚未同步；请稍后再次核对"
          : "尚未确认课程已签到；请检查时间/范围后重试，或再次核对状态"
      }
    } catch {
      AppLog.operationFailed(feature: "checkin", stage: "sign_in_response", error: error)
      await refresh()
      if snapshot?.items.first(where: { $0.id == courseID })?.status == .signed {
        actionSucceeded = true
        actionMessage = "签到成功，已通过状态回查确认"
      } else {
        actionSucceeded = false
        actionMessage = "签到结果暂时无法确认；已尝试回查状态。请勿立即重复提交，可稍后刷新确认。"
      }
    }
  }
}

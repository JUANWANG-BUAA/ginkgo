import Foundation
import UserNotifications
import XCTest
@testable import BUAA_Assistant

@MainActor
final class CheckInViewModelTests: XCTestCase {
  func testStatusChangeSendsOneNotificationAndDoesNotRepeat() async {
    let repository = StubCheckInRepository(results: [
      .success(snapshot(status: .notSigned)),
      .success(snapshot(status: .signed)),
      .success(snapshot(status: .signed))
    ])
    let notifications = StubCheckInNotifications(status: .authorized)
    let model = CheckInViewModel(repository: repository, notifications: notifications)

    await model.start(account: "test-account")
    XCTAssertEqual(model.statusChangeRevision, 0)

    await model.refresh()
    XCTAssertEqual(model.statusChangeRevision, 1)
    XCTAssertEqual(model.statusChangeMessage, "软件工程：签到状态已确认")
    model.notifyStatusChange()
    XCTAssertEqual(notifications.sentCount, 1)

    await model.refresh()
    XCTAssertEqual(model.statusChangeRevision, 1)
    XCTAssertEqual(notifications.sentCount, 1)
  }

  func testInitialSignedSnapshotDoesNotTriggerChangeNotification() async {
    let notifications = StubCheckInNotifications(status: .authorized)
    let model = CheckInViewModel(
      repository: StubCheckInRepository(results: [.success(snapshot(status: .signed))]),
      notifications: notifications
    )

    await model.start(account: "test-account")

    XCTAssertEqual(model.statusChangeRevision, 0)
    XCTAssertNil(model.statusChangeMessage)
    XCTAssertEqual(notifications.sentCount, 0)
  }

  func testNotificationPreferencePersistsAndSuppressesSystemNotification() async throws {
    let suiteName = "CheckInViewModelTests.\(UUID().uuidString)"
    let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { userDefaults.removePersistentDomain(forName: suiteName) }
    let notifications = StubCheckInNotifications(status: .authorized)
    let model = CheckInViewModel(
      repository: StubCheckInRepository(),
      notifications: notifications,
      userDefaults: userDefaults
    )

    await model.refreshNotificationAuthorization()
    XCTAssertTrue(model.notificationsEnabled, "Existing users keep the pre-preference notification behavior by default.")

    model.setNotificationsEnabled(false)
    model.notifyStatusChange()

    XCTAssertFalse(model.notificationsEnabled)
    XCTAssertEqual(notifications.sentCount, 0)
    XCTAssertTrue(model.notificationHint(webVPNSessionStatus: .ready).contains("应用内已关闭"))

    let restored = CheckInViewModel(
      repository: StubCheckInRepository(),
      notifications: notifications,
      userDefaults: userDefaults
    )
    await restored.refreshNotificationAuthorization()
    XCTAssertFalse(restored.notificationsEnabled)

    restored.setNotificationsEnabled(true)
    restored.notifyStatusChange()
    XCTAssertEqual(notifications.sentCount, 1)
  }

  func testPageAppearanceRefreshesExistingAccountSession() async {
    let repository = StubCheckInRepository(results: [
      .success(snapshot(status: .notSigned)),
      .success(snapshot(status: .signed))
    ])
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    await model.refreshOnAppearance(account: "test-account")

    XCTAssertEqual(repository.loadCount, 2)
    XCTAssertEqual(model.snapshot?.items.first?.status, .signed)
  }

  func testDiskCacheSeparatesAccountsAndRetainsAttendanceHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = CheckInCache(directory: directory)
    let today = snapshot(status: .signed)
    let history = snapshot(status: .notSigned)
    try await cache.saveToday(today, account: "account-1")
    try await cache.saveHistory(history, account: "account-1")

    let restored = await cache.read(account: "account-1")
    let otherAccount = await cache.read(account: "account-2")

    XCTAssertEqual(restored.today, today)
    XCTAssertEqual(restored.history[history.schoolDate], history)
    XCTAssertNil(otherAccount.today)
    XCTAssertTrue(otherAccount.history.isEmpty)
  }

  func testCachedTodayStatusStaysVisibleButCannotSubmitUntilConfirmed() async throws {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyyMMdd"
    let cachedSnapshot = CheckInSnapshot(
      items: [CheckInItem(
        id: "course-1", courseName: "软件工程", beginsAt: "08:00", endsAt: "09:40", status: .notSigned
      )],
      fetchedAt: Date(timeIntervalSinceNow: -90),
      schoolDate: formatter.string(from: Date())
    )
    let repository = StubCheckInRepository(
      results: [.failure(CheckInError.unavailable)],
      cached: CheckInCacheSnapshot(today: cachedSnapshot, history: [:])
    )
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "account-1")

    XCTAssertEqual(model.snapshot, cachedSnapshot)
    XCTAssertTrue(model.snapshotIsCached)
    XCTAssertFalse(model.canSubmitSignIn)
    XCTAssertNotNil(model.errorMessage)
  }

  func testConcurrentRefreshRequestsShareOneInFlightLoad() async {
    let repository = StubCheckInRepository(
      results: [
        .success(snapshot(status: .notSigned)),
        .success(snapshot(status: .signed)),
        .success(snapshot(status: .signed))
      ],
      loadDelayNanoseconds: 50_000_000
    )
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    let firstRefresh = Task { await model.refresh() }
    try? await Task.sleep(nanoseconds: 5_000_000)
    let overlappingRefresh = Task { await model.refresh() }
    await firstRefresh.value
    await overlappingRefresh.value

    XCTAssertEqual(repository.loadCount, 2, "Only the initial load and one refresh should reach iclass.")
    XCTAssertEqual(model.snapshot?.items.first?.status, .signed)
    XCTAssertFalse(model.isLoading)
  }

  func testDeniedNotificationPermissionShowsActionableHintAndCanRefresh() async {
    let notifications = StubCheckInNotifications(status: .denied)
    let model = CheckInViewModel(
      repository: StubCheckInRepository(results: [.success(snapshot(status: .notSigned))]),
      notifications: notifications
    )

    await model.start(account: "test-account")
    XCTAssertTrue(model.notificationHint(webVPNSessionStatus: .notAttempted).contains("系统设置 → 通知 → Ginkgo"))

    notifications.nextRequestResult = true
    let enabled = await model.requestNotificationAuthorization()

    XCTAssertTrue(enabled)
    XCTAssertEqual(model.notificationAuthorization, .authorized)
    XCTAssertTrue(model.notificationHint(webVPNSessionStatus: .ready).contains("系统通知已开启"))
    XCTAssertTrue(model.notificationHint(webVPNSessionStatus: .ready).contains("签到结果仍以 iclass 实际返回为准"))
  }

  func testFailedRefreshKeepsLastSuccessfulSnapshot() async {
    let expected = snapshot(status: .notSigned)
    let model = CheckInViewModel(
      repository: StubCheckInRepository(results: [
        .success(expected),
        .failure(CheckInError.unavailable)
      ]),
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    await model.refresh()

    XCTAssertEqual(model.snapshot, expected)
    XCTAssertEqual(model.errorMessage, CheckInError.unavailable.errorDescription)
  }

  func testHistoryQueryUsesSelectedDateAndKeepsAttendanceStatus() async {
    let expected = snapshot(status: .notSigned)
    let repository = StubCheckInRepository()
    repository.historySnapshot = expected
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    let date = Date(timeIntervalSince1970: 1_760_000_000)
    await model.loadHistory(on: date)

    XCTAssertEqual(repository.historyDates, [date])
    XCTAssertEqual(repository.historyAccounts, ["test-account"])
    XCTAssertEqual(model.historySnapshot, expected)
    XCTAssertEqual(model.historyDate, date)
    XCTAssertFalse(model.historyIsLoading)
    XCTAssertNil(model.historyErrorMessage)
  }

  func testHistoryQueryFailureDoesNotClaimAbsence() async {
    let repository = StubCheckInRepository()
    repository.historyError = .unavailable
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    await model.loadHistory(on: Date())

    XCTAssertNil(model.historySnapshot)
    XCTAssertEqual(model.historyErrorMessage, CheckInError.unavailable.errorDescription)
    XCTAssertFalse(model.historyIsLoading)
  }

  func testWebVPNGatewayFailureExposesSessionRecoveryState() async {
    let model = CheckInViewModel(
      repository: StubCheckInRepository(results: [.failure(CheckInError.webVPNUnavailable)]),
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")

    XCTAssertTrue(model.webVPNAuthenticationUnavailable)
    XCTAssertEqual(model.errorMessage, CheckInError.webVPNUnavailable.errorDescription)
    model.clearWebVPNAuthenticationFailure()
    XCTAssertFalse(model.webVPNAuthenticationUnavailable)
  }

  func testManualSignInImmediatelyRefreshesAndConfirmsSignedStatus() async {
    let repository = StubCheckInRepository(results: [
      .success(snapshot(status: .notSigned)),
      .success(snapshot(status: .signed))
    ])
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    await model.performSignIn(courseID: "course-1")

    XCTAssertEqual(repository.signInCourseIDs, ["course-1"])
    XCTAssertEqual(model.snapshot?.items.first?.status, .signed)
    XCTAssertTrue(model.actionSucceeded)
    XCTAssertEqual(model.actionMessage, "签到成功，课程状态已回查确认")
    XCTAssertEqual(model.statusChangeRevision, 1)
  }

  func testAmbiguousManualSignInFailureRechecksWithoutClaimingSuccess() async {
    let repository = StubCheckInRepository(results: [
      .success(snapshot(status: .notSigned)),
      .success(snapshot(status: .notSigned))
    ])
    repository.signInError = .unavailable
    let model = CheckInViewModel(
      repository: repository,
      notifications: StubCheckInNotifications(status: .notDetermined)
    )

    await model.start(account: "test-account")
    await model.performSignIn(courseID: "course-1")

    XCTAssertEqual(repository.signInCourseIDs, ["course-1"], "An ambiguous write must never be automatically retried.")
    XCTAssertFalse(model.actionSucceeded)
    XCTAssertTrue(model.actionMessage?.contains("结果暂时无法确认") == true)
  }

  private func snapshot(status: CheckInStatus) -> CheckInSnapshot {
    CheckInSnapshot(
      items: [CheckInItem(
        id: "course-1",
        courseName: "软件工程",
        beginsAt: "08:00",
        endsAt: "09:40",
        status: status
      )],
      fetchedAt: Date(timeIntervalSince1970: 1_760_000_000),
      schoolDate: "20261015"
    )
  }
}

@MainActor
private final class StubCheckInNotifications: CheckInNotificationServing {
  var status: UNAuthorizationStatus
  var nextRequestResult = false
  private(set) var requestCount = 0
  private(set) var sentCount = 0

  init(status: UNAuthorizationStatus) {
    self.status = status
  }

  func authorizationStatus() async -> UNAuthorizationStatus { status }

  func requestAuthorization() async throws -> Bool {
    requestCount += 1
    if nextRequestResult { status = .authorized }
    return nextRequestResult
  }

  func sendStatusChangeNotification() {
    sentCount += 1
  }
}

/// 用仓储替身注入 ViewModel，网络与缓存细节由 DefaultCheckInRepository 的独立测试覆盖。
private final class StubCheckInRepository: CheckInRepository {
  private var results: [Result<CheckInSnapshot, CheckInError>]
  private let loadDelayNanoseconds: UInt64
  private var cached: CheckInCacheSnapshot
  private(set) var signInCourseIDs: [String] = []
  private(set) var loadCount = 0
  private(set) var historyDates: [Date] = []
  private(set) var historyAccounts: [String] = []
  private(set) var webVPNRouteStates: [Bool] = []
  private(set) var clearedAccounts: [String] = []
  var historySnapshot: CheckInSnapshot?
  var historyError: CheckInError?
  var signInError: CheckInError?

  init(
    results: [Result<CheckInSnapshot, CheckInError>] = [],
    loadDelayNanoseconds: UInt64 = 0,
    cached: CheckInCacheSnapshot = CheckInCacheSnapshot(today: nil, history: [:])
  ) {
    self.results = results
    self.loadDelayNanoseconds = loadDelayNanoseconds
    self.cached = cached
  }

  func cachedSnapshot(account: String) async -> CheckInCacheSnapshot {
    cached
  }

  func loadToday(account: String) async throws -> CheckInSnapshot {
    loadCount += 1
    if loadDelayNanoseconds > 0 {
      try? await Task.sleep(nanoseconds: loadDelayNanoseconds)
    }
    guard !results.isEmpty else { throw CheckInError.unavailable }
    return try results.removeFirst().get()
  }

  func load(on date: Date, account: String) async throws -> CheckInSnapshot {
    historyDates.append(date)
    historyAccounts.append(account)
    if let historyError { throw historyError }
    guard let historySnapshot else { throw CheckInError.unavailable }
    return historySnapshot
  }

  func performSignIn(courseID: String, account: String) async throws -> CheckInActionResult {
    signInCourseIDs.append(courseID)
    if let signInError { throw signInError }
    return CheckInActionResult(succeeded: true, message: "学校已接受签到，正在回查课程状态…")
  }

  func setWebVPNRouteEnabled(_ enabled: Bool) async {
    webVPNRouteStates.append(enabled)
  }

  func clearCache(account: String) async throws {
    clearedAccounts.append(account)
    cached = CheckInCacheSnapshot(today: nil, history: [:])
  }
}

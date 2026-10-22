import Foundation
import XCTest
@testable import BUAA_Assistant

final class CheckInRepositoryTests: XCTestCase {
  func testLoadTodayWritesCacheForCurrentSchoolDate() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let snapshot = makeSnapshot(schoolDate: schoolDateString(from: Date()), status: .signed)
    let service = StubCheckInRepositoryService(results: [.success(snapshot)])
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))

    let loaded = try await repository.loadToday(account: "account-1")

    XCTAssertEqual(loaded, snapshot)
    let cached = await repository.cachedSnapshot(account: "account-1")
    XCTAssertEqual(cached.today, snapshot)
    XCTAssertTrue(cached.history.isEmpty)
    XCTAssertEqual(service.loadTodayCount, 1)
  }

  func testLoadTodayDoesNotWriteCacheForOtherSchoolDate() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let snapshot = makeSnapshot(schoolDate: "20000101")
    let service = StubCheckInRepositoryService(results: [.success(snapshot)])
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))

    let loaded = try await repository.loadToday(account: "account-1")

    XCTAssertEqual(loaded, snapshot)
    let cached = await repository.cachedSnapshot(account: "account-1")
    XCTAssertNil(cached.today)
  }

  func testLoadHistoryWritesCacheAndFailureKeepsPreviousSnapshot() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = makeSnapshot(schoolDate: "20261014")
    let service = StubCheckInRepositoryService(results: [
      .success(first),
      .failure(CheckInError.unavailable)
    ])
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))
    let date = Date(timeIntervalSince1970: 1_760_000_000)

    let loaded = try await repository.load(on: date, account: "account-1")
    XCTAssertEqual(loaded, first)
    let cachedAfterSuccess = await repository.cachedSnapshot(account: "account-1")
    XCTAssertEqual(cachedAfterSuccess.history["20261014"], first)
    XCTAssertEqual(service.historyDates, [date])

    do {
      _ = try await repository.load(on: date, account: "account-1")
      XCTFail("刷新失败时应当抛出错误，而不是返回空快照")
    } catch {
      XCTAssertEqual(error as? CheckInError, CheckInError.unavailable)
    }
    let cachedAfterFailure = await repository.cachedSnapshot(account: "account-1")
    XCTAssertEqual(cachedAfterFailure.history["20261014"], first, "失败刷新不得覆盖旧缓存")
  }

  func testCacheWriteFailureStillReturnsSnapshot() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let blocker = directory.appendingPathComponent("blocker")
    try Data("not-a-directory".utf8).write(to: blocker)
    let snapshot = makeSnapshot(schoolDate: schoolDateString(from: Date()), status: .signed)
    let service = StubCheckInRepositoryService(results: [.success(snapshot)])
    let repository = DefaultCheckInRepository(
      service: service,
      cache: CheckInCache(directory: blocker.appendingPathComponent("nested"))
    )

    let loaded = try await repository.loadToday(account: "account-1")

    XCTAssertEqual(loaded, snapshot, "写缓存失败不得影响已取得的网络结果")
    let cached = await repository.cachedSnapshot(account: "account-1")
    XCTAssertNil(cached.today)
  }

  func testCachedSnapshotIsPerAccountAndClearCacheRemovesOnlyThatAccount() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let snapshot = makeSnapshot(schoolDate: "20261014")
    let service = StubCheckInRepositoryService(results: [.success(snapshot)])
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))

    _ = try await repository.load(on: Date(), account: "account-1")
    let otherAccount = await repository.cachedSnapshot(account: "account-2")
    XCTAssertTrue(otherAccount.history.isEmpty)

    try await repository.clearCache(account: "account-1")
    let cleared = await repository.cachedSnapshot(account: "account-1")
    XCTAssertNil(cleared.today)
    XCTAssertTrue(cleared.history.isEmpty)
  }

  func testPerformSignInForwardsOnceAndWebVPNRouteSettingIsForwarded() async throws {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = StubCheckInWebVPNRepositoryService()
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))

    await repository.setWebVPNRouteEnabled(true)
    await repository.setWebVPNRouteEnabled(false)
    let result = try await repository.performSignIn(courseID: "course-1", account: "account-1")

    XCTAssertEqual(service.webVPNRouteStates, [true, false])
    XCTAssertEqual(service.signInCourseIDs, ["course-1"], "签到只提交一次，不由仓储重试")
    XCTAssertEqual(service.signInAccounts, ["account-1"])
    XCTAssertTrue(result.succeeded)
  }

  func testWebVPNRouteSettingIsNoOpWhenServiceCannotRoute() async {
    let directory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = StubCheckInRepositoryService()
    let repository = DefaultCheckInRepository(service: service, cache: CheckInCache(directory: directory))

    XCTAssertFalse((service as Any) is CheckInWebVPNRouting)
    await repository.setWebVPNRouteEnabled(true)
  }

  private func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  }

  private func schoolDateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyyMMdd"
    return formatter.string(from: date)
  }

  private func makeSnapshot(schoolDate: String, status: CheckInStatus = .notSigned) -> CheckInSnapshot {
    CheckInSnapshot(
      items: [CheckInItem(
        id: "course-1",
        courseName: "软件工程",
        beginsAt: "08:00",
        endsAt: "09:40",
        status: status
      )],
      fetchedAt: Date(timeIntervalSince1970: 1_760_000_000),
      schoolDate: schoolDate
    )
  }
}

private class StubCheckInRepositoryService: CheckInServing {
  private var results: [Result<CheckInSnapshot, CheckInError>]
  private(set) var loadTodayCount = 0
  private(set) var historyDates: [Date] = []
  private(set) var signInCourseIDs: [String] = []
  private(set) var signInAccounts: [String] = []

  init(results: [Result<CheckInSnapshot, CheckInError>] = []) {
    self.results = results
  }

  func loadToday(account: String) async throws -> CheckInSnapshot {
    loadTodayCount += 1
    guard !results.isEmpty else { throw CheckInError.unavailable }
    return try results.removeFirst().get()
  }

  func loadOnDate(account: String, date: Date) async throws -> CheckInSnapshot {
    historyDates.append(date)
    guard !results.isEmpty else { throw CheckInError.unavailable }
    return try results.removeFirst().get()
  }

  func performSignIn(account: String, courseID: String) async throws -> CheckInActionResult {
    signInCourseIDs.append(courseID)
    signInAccounts.append(account)
    return CheckInActionResult(succeeded: true, message: "学校已接受签到，正在回查课程状态…")
  }
}

private final class StubCheckInWebVPNRepositoryService: StubCheckInRepositoryService, CheckInWebVPNRouting {
  private(set) var webVPNRouteStates: [Bool] = []

  func setWebVPNRouteEnabled(_ enabled: Bool) async {
    webVPNRouteStates.append(enabled)
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class WorkspaceIntegrationTests: XCTestCase {
  func testResetDiscardsInFlightScheduleResponse() async {
    let service = SuspendedScheduleService()
    let model = ScheduleViewModel(service: service)
    let request = Task { await model.refresh() }
    while service.continuation == nil { await Task.yield() }
    model.reset()
    service.continuation?.resume(returning: ScheduleSnapshot(portal: .graduate, terms: [],
      termID: "synthetic", weeks: [], weekNumber: 1, courses: [], fetchedAt: Date()))
    await request.value
    XCTAssertNil(model.snapshot)
    XCTAssertFalse(model.isLoading)
    XCTAssertNil(model.feedback)
  }

  func testTasksPersistAndRemainIsolatedByAccount() throws {
    let suite = "WorkspaceTests." + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = PersonalTaskStore(defaults: defaults)
    store.load(account: "synthetic-a")
    store.add(title: "  实验报告  ", due: Date(timeIntervalSince1970: 100))
    XCTAssertEqual(store.tasks.first?.title, "实验报告")
    let id = try XCTUnwrap(store.tasks.first?.id)
    store.toggle(id)
    store.load(account: "synthetic-b")
    XCTAssertTrue(store.tasks.isEmpty)
    let restored = PersonalTaskStore(defaults: defaults)
    restored.load(account: "synthetic-a")
    XCTAssertEqual(restored.tasks.first?.id, id)
    XCTAssertEqual(restored.tasks.first?.completed, true)
    restored.delete(id)
    store.load(account: "synthetic-a")
    XCTAssertTrue(store.tasks.isEmpty)
  }

  func testTodayUsesCurrentWeekWhileBrowsingAnotherWeek() throws {
    let calendar = ScheduleSnapshot.schoolCalendar
    let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12)))
    let sunday = try XCTUnwrap(calendar.date(byAdding: .day, value: 6, to: monday))
    let meeting = CourseMeeting(id: "current", name: "合成课程", day: 1, startSection: 1,
      endSection: 2, startTime: "08:00", endTime: "09:35", place: nil, teacher: nil, color: nil)
    var snapshot = ScheduleSnapshot(portal: .graduate, terms: [], termID: "synthetic", weeks: [
      SchoolWeek(number: 6, start: monday, end: sunday, isCurrent: true)
    ], weekNumber: 1, courses: [], fetchedAt: monday, termCourses: ["6": [meeting]])
    XCTAssertTrue(snapshot.containsToday(now: monday))
    XCTAssertEqual(snapshot.todayCourses(now: monday).map(\.id), ["current"])
    snapshot.termCourses = nil
    XCTAssertFalse(snapshot.containsToday(now: monday))
    XCTAssertTrue(snapshot.todayCourses(now: monday).isEmpty)
  }
}

private final class SuspendedScheduleService: ScheduleServing {
  var continuation: CheckedContinuation<ScheduleSnapshot, Error>?
  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    try await withCheckedThrowingContinuation { continuation = $0 }
  }
}

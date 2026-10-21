import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class WorkspaceIntegrationTests: XCTestCase {
  func testScheduleSnapshotRetainsKnownWeeksFromPortableFixture() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("fixtures/schedule/week-snapshot-v1.json")
    let fixture = try JSONDecoder().decode(
      ScheduleSnapshotContractFixture.self,
      from: Data(contentsOf: fixtureURL)
    )

    XCTAssertEqual(fixture.contract, "schedule.snapshot_retained_weeks")
    XCTAssertEqual(fixture.version, 1)
    XCTAssertEqual(fixture.source, "synthetic")

    let previous = fixture.input.previous.makeSnapshot()
    let fetched = fixture.input.fetched.makeSnapshot()
    let merged = fetched.retainingKnownWeeks(from: previous)
    let courseIDsByWeek = try XCTUnwrap(merged.termCourses).mapValues { $0.map(\.id) }
    XCTAssertEqual(courseIDsByWeek, fixture.expected.courseIDsByWeek)

    let selected = try XCTUnwrap(merged.selectingCachedWeek(fixture.expected.selectableCachedWeek))
    XCTAssertEqual(selected.weekNumber, fixture.expected.selectableCachedWeek)
    XCTAssertEqual(
      selected.courses.map(\.id),
      fixture.expected.courseIDsByWeek[String(selected.weekNumber)] ?? []
    )
  }

  func testScheduleSnapshotDoesNotRetainWeeksAcrossTerms() {
    let oldCourse = CourseMeeting(id: "old-term", name: "旧学期", day: 1, startSection: 1,
      endSection: 2, startTime: nil, endTime: nil, place: nil, teacher: nil, color: nil)
    let newCourse = CourseMeeting(id: "new-term", name: "新学期", day: 1, startSection: 1,
      endSection: 2, startTime: nil, endTime: nil, place: nil, teacher: nil, color: nil)
    let previous = ScheduleSnapshot(
      portal: .undergraduate,
      terms: [],
      termID: "old-term",
      weeks: [],
      weekNumber: 1,
      courses: [oldCourse],
      fetchedAt: Date(timeIntervalSince1970: 1),
      termCourses: ["1": [oldCourse]]
    )
    let fetched = ScheduleSnapshot(
      portal: .undergraduate,
      terms: [],
      termID: "new-term",
      weeks: [],
      weekNumber: 2,
      courses: [newCourse],
      fetchedAt: Date(timeIntervalSince1970: 2)
    )

    let merged = fetched.retainingKnownWeeks(from: previous)

    XCTAssertEqual(merged.termCourses?.mapValues { $0.map(\.id) } ?? [:], ["2": ["new-term"]])
  }

  func testResetDiscardsInFlightScheduleResponse() async {
    let service = SuspendedScheduleService()
    let model = ScheduleViewModel(repository: DefaultScheduleRepository(service: service))
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
    let calendar = SchoolTime.calendar
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

private struct ScheduleSnapshotContractFixture: Decodable {
  let contract: String
  let version: Int
  let source: String
  let input: Input
  let expected: Expected

  struct Input: Decodable {
    let previous: SnapshotInput
    let fetched: SnapshotInput
  }

  struct SnapshotInput: Decodable {
    let termID: String
    let weekNumber: Int
    let courses: [CourseMeeting]
    let termCourses: [String: [CourseMeeting]]?

    func makeSnapshot() -> ScheduleSnapshot {
      ScheduleSnapshot(
        portal: .undergraduate,
        terms: [],
        termID: termID,
        weeks: [],
        weekNumber: weekNumber,
        courses: courses,
        fetchedAt: Date(timeIntervalSince1970: 0),
        termCourses: termCourses
      )
    }
  }

  struct Expected: Decodable {
    let courseIDsByWeek: [String: [String]]
    let selectableCachedWeek: Int
  }
}

private final class SuspendedScheduleService: ScheduleServing {
  var continuation: CheckedContinuation<ScheduleSnapshot, Error>?
  func load(termID: String?, week: Int?) async throws -> ScheduleSnapshot {
    try await withCheckedThrowingContinuation { continuation = $0 }
  }
}

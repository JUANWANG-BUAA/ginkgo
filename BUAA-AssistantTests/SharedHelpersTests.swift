import Foundation
import XCTest
@testable import BUAA_Assistant

final class SharedHelpersTests: XCTestCase {
  func testAutoRefreshGateEnforcesCooldownAndQueuesOnce() {
    var gate = AutoRefreshGate()
    let start = Date(timeIntervalSince1970: 1_000)

    XCTAssertTrue(gate.allowsAttempt(force: false, bypassCooldown: false, now: start))
    XCTAssertFalse(gate.allowsAttempt(force: false, bypassCooldown: false, now: start.addingTimeInterval(10)))
    XCTAssertTrue(gate.allowsAttempt(force: true, bypassCooldown: false, now: start.addingTimeInterval(10)))
    XCTAssertTrue(gate.allowsAttempt(force: false, bypassCooldown: true, now: start.addingTimeInterval(11)))
    XCTAssertFalse(gate.allowsAttempt(force: false, bypassCooldown: false, now: start.addingTimeInterval(12)))

    gate.deferWhileLoading(queue: true)
    gate.deferWhileLoading(queue: true)
    XCTAssertTrue(gate.takePending())
    XCTAssertFalse(gate.takePending())
    gate.deferWhileLoading(queue: true)
    gate.cancelPending()
    XCTAssertFalse(gate.takePending())
    gate.deferWhileLoading(queue: true)
    gate.reset()
    XCTAssertFalse(gate.takePending())
  }

  func testGraduateCreditFormatting() {
    XCTAssertEqual(GraduateCredit.text(3), "3")
    XCTAssertEqual(GraduateCredit.text(2.5), "2.5")
    XCTAssertEqual(GraduateCredit.text(nil), "—")
    XCTAssertEqual(GraduateCredit.text(.infinity), "—")
  }

  func testGradeSearchMatchesNameOrCode() {
    let courses = [
      GradeCourse(id: "1", name: "高级软件工程", code: "C1", credit: 3, score: "90", scoreValue: 90, scoreType: "百分制", courseType: nil),
      GradeCourse(id: "2", name: "数据挖掘", code: "C2", credit: 2, score: "85", scoreValue: 85, scoreType: "百分制", courseType: nil)
    ]
    let snapshot = GradeSnapshot(term: SchoolTerm(id: "20261", name: "2026 秋", isSelected: true), courses: courses, fetchedAt: Date())
    XCTAssertEqual(snapshot.courses(matching: "  ").count, 2)
    XCTAssertEqual(snapshot.courses(matching: "软件").map(\.id), ["1"])
    XCTAssertEqual(snapshot.courses(matching: "c2").map(\.id), ["2"])
  }

  func testHomeworkFilterCombinesStatusSourceAndQuery() {
    let now = Date(timeIntervalSince1970: 1_760_000_000)
    let pending = HomeworkItem(
      id: "spoc:1", courseName: "软件工程", title: "实验一", dueAt: now.addingTimeInterval(3_600),
      sourceURL: nil, status: .pending, source: .spoc, fetchedAt: now
    )
    let overdue = HomeworkItem(
      id: "spoc:2", courseName: "数据挖掘", title: "报告", dueAt: now.addingTimeInterval(-3_600),
      sourceURL: nil, status: .overdue, source: .spoc, fetchedAt: now
    )
    let items = [overdue, pending]

    XCTAssertEqual(items.filteredHomework(status: nil, source: nil, query: "").map(\.id), ["spoc:2", "spoc:1"])
    XCTAssertEqual(items.filteredHomework(status: .pending, source: nil, query: "").map(\.id), ["spoc:1"])
    XCTAssertEqual(items.filteredHomework(status: nil, source: .judge, query: "").map(\.id), [])
    XCTAssertEqual(items.filteredHomework(status: nil, source: nil, query: "数据").map(\.id), ["spoc:2"])
  }

  func testCalendarWeekdayNames() {
    XCTAssertEqual(SchoolTime.weekdayName(calendarWeekday: 1), "周日")
    XCTAssertEqual(SchoolTime.weekdayName(calendarWeekday: 2), "周一")
    XCTAssertEqual(SchoolTime.weekdayName(calendarWeekday: 7), "周六")
  }
}

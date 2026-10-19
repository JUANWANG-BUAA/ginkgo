import Foundation
import XCTest
@testable import BUAA_Assistant

final class CheckInTargetMatcherTests: XCTestCase {
  private func candidates() -> [CheckInCandidate] {
    [
      CheckInCandidate(
        id: "2504184", courseID: "95931", courseNum: "D031041024",
        courseName: "机器人控制技术",
        beginsAt: "2026-10-19 09:50:00", endsAt: "2026-10-19 12:15:00",
        status: .notSigned, teacherName: "刘正华", classroomName: "B228"
      ),
      CheckInCandidate(
        id: "2504185", courseID: "95928", courseNum: "D031041024",
        courseName: "机器人控制技术",
        beginsAt: "2026-10-19 09:50:00", endsAt: "2026-10-19 12:15:00",
        status: .notSigned, teacherName: "教师乙", classroomName: "B229"
      ),
      CheckInCandidate(
        id: "2504186", courseID: "95930", courseNum: "D031041024",
        courseName: "机器人控制技术",
        beginsAt: "2026-10-19 09:50:00", endsAt: "2026-10-19 12:15:00",
        status: .notSigned, teacherName: "教师丙", classroomName: "B230"
      ),
      CheckInCandidate(
        id: "2504187", courseID: "95929", courseNum: "D031041024",
        courseName: "机器人控制技术",
        beginsAt: "2026-10-19 09:50:00", endsAt: "2026-10-19 12:15:00",
        status: .notSigned, teacherName: "教师丁", classroomName: "B231"
      )
    ]
  }

  private func item(_ candidates: [CheckInCandidate]) -> CheckInItem {
    CheckInItem(
      id: candidates.first?.id ?? "id",
      courseName: "机器人控制技术",
      beginsAt: "2026-10-19 09:50:00",
      endsAt: "2026-10-19 12:15:00",
      status: .notSigned,
      signInAllowed: false,
      mergedRecordCount: candidates.count,
      candidates: candidates
    )
  }

  private func schedule() -> ScheduleSnapshot {
    ScheduleSnapshot(
      portal: .graduate,
      terms: [],
      termID: "1",
      weeks: [],
      weekNumber: 1,
      courses: [
        CourseMeeting(
          id: "course-1", name: "机器人控制技术", day: 1, startSection: 3, endSection: 5,
          startTime: "09:50", endTime: "12:15", place: "B228", teacher: "刘正华", color: nil
        )
      ],
      fetchedAt: Date(),
      termCourses: nil
    )
  }

  func testScheduleClassroomSelectsOneCandidate() {
    let item = item(candidates())
    let result = CheckInTargetMatcher.signInCandidates(for: item, schedule: schedule())
    XCTAssertEqual(result.map(\.id), ["2504184"])
    XCTAssertEqual(
      CheckInTargetMatcher.matchedTargetLabel(for: item, schedule: schedule()),
      "B228 · 刘正华 · D031041024"
    )
  }

  func testWithoutScheduleKeepsAllUnsignedCandidates() {
    let item = item(candidates())
    let result = CheckInTargetMatcher.signInCandidates(for: item, schedule: nil)
    XCTAssertEqual(result.count, 4)
    XCTAssertNil(CheckInTargetMatcher.matchedTargetLabel(for: item, schedule: nil))
  }

  func testSignedCandidateIsDetectedByID() {
    let signed = CheckInCandidate(
      id: "2504184", courseID: "95931", courseNum: "D031041024",
      courseName: "机器人控制技术",
      beginsAt: "2026-10-19 09:50:00", endsAt: "2026-10-19 12:15:00",
      status: .signed, teacherName: "刘正华", classroomName: "B228"
    )
    let item = item([signed])
    XCTAssertTrue(CheckInTargetMatcher.isSigned(courseID: "2504184", in: [item]))
    XCTAssertFalse(CheckInTargetMatcher.isSigned(courseID: "2504185", in: [item]))
  }
}

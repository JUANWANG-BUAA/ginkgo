import Foundation
import XCTest
@testable import BUAA_Assistant

final class GraduateProgressTests: XCTestCase {
  private func course(
    _ id: String,
    _ name: String,
    code: String,
    credits: Double,
    category: String,
    required: String,
    term: String = "2025-2026-1"
  ) -> GraduatePlanCourse {
    GraduatePlanCourse(
      id: id, name: name, code: code, credits: credits, category: category,
      examMode: "考试", term: term, required: required
    )
  }

  private func grade(_ name: String, code: String, score: String, credits: Double) -> GraduateGradeRecord {
    GraduateGradeRecord(
      id: "grade-\(code)", courseName: name, courseCode: code, score: score,
      credits: credits, gradePoint: nil, category: nil
    )
  }

  private func academic(
    plan: GraduatePlan?,
    grades: [GraduateGradeRecord],
    execution: GraduatePlanExecution? = nil
  ) -> GraduateAcademicSnapshot {
    GraduateAcademicSnapshot(
      status: GraduateStatusSummary(
        college: "计算机学院", major: "软件工程", grade: "2025", degreeLevel: "硕士",
        studentType: "学术学位", status: "在籍", className: "软工1班", campus: "学院路",
        studyMode: "全日制", enrollmentDate: "2025-09-01", expectedGraduation: "2028-06"
      ),
      plan: plan,
      planExecution: execution,
      examSummary: GraduateExamSummary(examCount: 0, quizCourseCount: 0, invigilationCount: 0),
      grades: grades,
      moduleCategories: [],
      fetchedAt: Date(), currentTermID: "20261"
    )
  }

  private func schedule(_ names: [String]) -> ScheduleSnapshot {
    let courses = names.enumerated().map { index, name in
      CourseMeeting(
        id: "course-\(index)", name: name, day: 1, startSection: 1, endSection: 2,
        startTime: "08:00", endTime: "09:35", place: "主M101", teacher: "教师", color: nil
      )
    }
    return ScheduleSnapshot(
      portal: .graduate, terms: [], termID: "2026-1", weeks: [], weekNumber: 1,
      courses: courses, fetchedAt: Date(), termCourses: nil
    )
  }

  func testProgressMatchesGradeByCodeAndScheduleByName() throws {
    let plan = GraduatePlan(
      title: "软件工程培养方案", college: "计算机学院", major: "软件工程",
      totalCredits: 20, degreeCourseCredits: 8, jointCourseCredits: 4, reviewStatus: "已审核",
      sections: [], courses: [
        course("a", "高级软件工程", code: "C1", credits: 4, category: "学位课", required: "是"),
        course("b", "软件体系结构", code: "C2", credits: 4, category: "学位课", required: "是"),
        course("c", "数据挖掘", code: "C3", credits: 4, category: "专业课", required: "否"),
        course("d", "学术规范", code: "C4", credits: 4, category: "专业课", required: "否")
      ]
    )
    let snapshot = academic(
      plan: plan,
      grades: [
        grade("高级软件工程（研）", code: "C1", score: "85", credits: 4),
        grade("软件体系结构", code: "C2", score: "55", credits: 4)
      ]
    )
    let summary = GraduateProgressBuilder.build(
      academic: snapshot,
      schedule: schedule(["数据挖掘"])
    )

    XCTAssertEqual(summary.totalCredits, 20)
    XCTAssertEqual(summary.completedCredits, 4)
    XCTAssertEqual(summary.inProgressCredits, 4)
    XCTAssertEqual(summary.remainingCredits, 16)
    XCTAssertEqual(summary.requiredRemainingCredits, 4)
    XCTAssertEqual(summary.electiveRemainingCredits, 4)
    XCTAssertEqual(summary.courses.first(where: { $0.planCourse.code == "C1" })?.status, .completed)
    XCTAssertEqual(summary.courses.first(where: { $0.planCourse.code == "C2" })?.status, .notPassed)
    XCTAssertEqual(summary.courses.first(where: { $0.planCourse.code == "C2" })?.note, "成绩 55，未通过")
    XCTAssertEqual(summary.courses.first(where: { $0.planCourse.code == "C3" })?.status, .inProgress)
    XCTAssertEqual(summary.courses.first(where: { $0.planCourse.code == "C4" })?.status, .remaining)
    XCTAssertTrue(summary.notes.contains { $0.contains("1 门计划课程未匹配") })

    let degree = try XCTUnwrap(summary.categories.first { $0.category == "学位课" })
    XCTAssertEqual(degree.totalCredits, 8)
    XCTAssertEqual(degree.completedCredits, 4)
    XCTAssertEqual(degree.unmatchedCredits, 4)
    XCTAssertFalse(summary.categories.contains { $0.category == "校企课程" })
  }

  func testQualitativeScoresAndUnknownScores() {
    XCTAssertEqual(GraduateProgressBuilder.passingStatus("优秀"), true)
    XCTAssertEqual(GraduateProgressBuilder.passingStatus("不合格"), false)
    XCTAssertEqual(GraduateProgressBuilder.passingStatus("通过"), true)
    XCTAssertEqual(GraduateProgressBuilder.passingStatus("未通过"), false)
    XCTAssertEqual(GraduateProgressBuilder.passingStatus("免修"), nil)
    XCTAssertEqual(GraduateProgressBuilder.passingStatus(nil), nil)

    let plan = GraduatePlan(
      title: "方案", college: nil, major: nil, totalCredits: 6,
      degreeCourseCredits: nil, jointCourseCredits: 0, reviewStatus: nil, sections: [], courses: [
        course("a", "课程甲", code: "A1", credits: 3, category: "学位课", required: "是"),
        course("b", "课程乙", code: "B1", credits: 3, category: "学位课", required: "是")
      ]
    )
    let snapshot = academic(
      plan: plan,
      grades: [
        grade("课程甲", code: "A1", score: "优秀", credits: 3),
        grade("课程乙", code: "B1", score: "免修", credits: 3)
      ]
    )
    let summary = GraduateProgressBuilder.build(academic: snapshot, schedule: nil)
    XCTAssertEqual(summary.completedCredits, 3)
    XCTAssertEqual(summary.needsReviewCredits, 3)
    XCTAssertEqual(summary.needsReviewCourseCount, 1)
    XCTAssertEqual(summary.remainingCredits, 3)
  }

  func testOfficialExecutionCompletionWinsWhenGradesAreUnavailable() {
    let plan = GraduatePlan(title: "方案", college: nil, major: nil, totalCredits: 32,
      degreeCourseCredits: nil, jointCourseCredits: nil, reviewStatus: nil, sections: [],
      courses: [course("m1", "数值分析", code: "M1", credits: 3, category: "理论课", required: "是")])
    let execution = GraduatePlanExecution(totalRequiredCredits: 32, earnedCredits: 3, pendingCredits: 0,
      researchCredits: nil, stageRequiredCredits: nil, stageEarnedCredits: nil,
      categories: [GraduatePlanExecutionCategory(code: "01", name: "理论课", requiredCredits: 9,
        earnedCredits: 3, pendingCredits: 0, minimumCourseCount: nil, requirementNote: nil,
        groups: [], courses: [GraduatePlanExecutionCourse(code: "M1", name: "数值分析", credits: 3,
          completed: true, grade: nil, term: nil, category: nil, courseAttribute: nil)])])
    let summary = GraduateProgressBuilder.build(academic: academic(plan: plan, grades: [], execution: execution), schedule: nil)
    XCTAssertEqual(summary.courses.first?.status, .completed)
    XCTAssertEqual(summary.completedCredits, 3)
    XCTAssertEqual(summary.remainingCredits, 29)
  }

  func testCourseCodeMatchesEvenWhenNamesDiffer() {
    let plan = GraduatePlan(
      title: "方案", college: nil, major: nil, totalCredits: 2,
      degreeCourseCredits: nil, jointCourseCredits: 0, reviewStatus: nil, sections: [], courses: [
        course("a", "机器学习", code: "M1", credits: 2, category: "专业课", required: "否")
      ]
    )
    let snapshot = academic(
      plan: plan,
      grades: [grade("机器学习（全英文）", code: "m1", score: "90", credits: 2)]
    )
    let summary = GraduateProgressBuilder.build(academic: snapshot, schedule: nil)
    XCTAssertEqual(summary.completedCredits, 2)
    XCTAssertEqual(summary.courses.first?.matchedName, "机器学习（全英文）")
  }

  func testJointCourseRequirementIsNotAddedAsAnotherCoursePoolCategory() {
    let plan = GraduatePlan(
      title: "方案", college: nil, major: nil, totalCredits: 30,
      degreeCourseCredits: nil, jointCourseCredits: 6, reviewStatus: nil, sections: [], courses: [
        course("a", "课程甲", code: "A1", credits: 10, category: "学位课", required: "是"),
        course("b", "课程乙", code: "B1", credits: 10, category: "专业课", required: "否")
      ]
    )
    let snapshot = academic(plan: plan, grades: [])
    let summary = GraduateProgressBuilder.build(academic: snapshot, schedule: nil)
    XCTAssertEqual(summary.totalCredits, 30)
    XCTAssertEqual(summary.remainingCredits, 30)
    XCTAssertFalse(summary.categories.contains { $0.category == "校企课程" })
    XCTAssertFalse(summary.categories.contains { $0.category == "方案未列课程/环节" })
    let requirement = GraduateRequirementBuilder.build(snapshot)
    XCTAssertEqual(requirement.children.first { $0.kind == .joint }?.required, 6)
  }

  func testPlanExecutionProvidesStructuredCategoryRequirements() {
    let execution = GraduatePlanExecution(
      totalRequiredCredits: 32,
      earnedCredits: 0,
      pendingCredits: 32,
      researchCredits: 0,
      stageRequiredCredits: 32,
      stageEarnedCredits: 0,
      categories: [
        GraduatePlanExecutionCategory(
          code: "01", name: "学位理论课",
          requiredCredits: 9, earnedCredits: 0, pendingCredits: 9,
          minimumCourseCount: nil, requirementNote: nil,
          groups: [
            GraduatePlanExecutionGroup(
              code: "0101", name: "数学课", requiredCredits: 3,
              earnedCredits: 0, pendingCredits: 3, courses: []
            ),
            GraduatePlanExecutionGroup(
              code: "0102", name: "当代科技及方法论", requiredCredits: 1,
              earnedCredits: 0, pendingCredits: 1, courses: []
            )
          ],
          courses: []
        ),
        GraduatePlanExecutionCategory(
          code: "02", name: "综合实践", requiredCredits: 11,
          earnedCredits: 0, pendingCredits: 11, minimumCourseCount: nil,
          requirementNote: nil, groups: [], courses: []
        )
      ]
    )
    let plan = GraduatePlan(
      title: "2026级培养方案", college: nil, major: nil,
      totalCredits: 32, degreeCourseCredits: nil, jointCourseCredits: nil,
      reviewStatus: nil, sections: [],
      courses: [
        GraduatePlanCourse(
          id: "c1", name: "数值分析I", code: "001", credits: 3,
          category: "学位理论课", examMode: nil, term: nil, required: nil
        )
      ]
    )
    let progress = GraduateProgressBuilder.build(
      academic: academic(plan: plan, grades: [], execution: execution),
      schedule: nil
    )
    XCTAssertEqual(progress.totalCredits, 32)
    let theory = progress.categories.first { $0.category == "学位理论课" }
    XCTAssertEqual(theory?.requiredCredits, 9)
    XCTAssertEqual(theory?.groups.count, 2)
    XCTAssertEqual(theory?.groups.first?.requiredCredits, 3)
  }

  func testCoursePoolLargerThanRequirementUsesPlanTotal() {
    let plan = GraduatePlan(
      title: "专业硕士方案", college: nil, major: nil, totalCredits: 32,
      degreeCourseCredits: nil, jointCourseCredits: nil, reviewStatus: nil, sections: [],
      courses: (0..<12).map { index in
        course(
          "pool-\(index)", "课程池课程 \(index)", code: "P\(index)", credits: 4,
          category: index < 7 ? "学位理论课" : "综合实践", required: "否"
        )
      }
    )
    let summary = GraduateProgressBuilder.build(academic: academic(plan: plan, grades: []), schedule: nil)
    XCTAssertEqual(summary.totalCredits, 32)
    XCTAssertEqual(summary.coursePoolCredits, 48)
    XCTAssertEqual(summary.remainingCredits, 32)
    XCTAssertEqual(summary.completedCredits, 0)
    XCTAssertEqual(summary.categories.reduce(0) { $0 + $1.totalCredits }, 48)
    XCTAssertTrue(summary.notes.contains { $0.contains("课程池合计 48 学分") && $0.contains("总学分要求为 32") })
    XCTAssertTrue(summary.notes.contains { $0.contains("不是全部必修") })
  }

  func testAcademicCacheRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = GraduateAcademicCache(directory: directory)
    let snapshot = academic(
      plan: GraduatePlan(
        title: "方案", college: "学院", major: "专业", totalCredits: 2,
        degreeCourseCredits: nil, jointCourseCredits: 0, reviewStatus: nil, sections: [],
        courses: [course("a", "课程甲", code: "A1", credits: 2, category: "学位课", required: "是")]
      ),
      grades: []
    )
    try await cache.save(snapshot, account: "test-account")
    let restored = await cache.read(account: "test-account")
    XCTAssertEqual(restored?.plan?.title, "方案")
    XCTAssertEqual(restored?.plan?.courses.first?.name, "课程甲")
    try await cache.clear(account: "test-account")
    let cleared = await cache.read(account: "test-account")
    XCTAssertNil(cleared)
  }
}

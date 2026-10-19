import Foundation
import ImageIO
import SwiftUI
import XCTest
#if os(macOS)
import AppKit
#endif
@testable import BUAA_Assistant

final class GraduateRequirementsTests: XCTestCase {
  func testGapStaysAtItsOwnLevelAndPendingDoesNotReduceIt() throws {
    let root = GraduateRequirementBuilder.build(try fixture())
    XCTAssertEqual(root.required, 32)
    XCTAssertEqual(root.earned, 8)
    XCTAssertEqual(root.gap, 24)
    let theory = try XCTUnwrap(root.children.first)
    XCTAssertEqual(theory.gap, 4)
    XCTAssertEqual(theory.children.first?.gap, 2)
    XCTAssertEqual(theory.children.first?.path, ["基础及专业理论核心课", "数学课"])
    XCTAssertEqual(theory.children.first?.children.first?.path,
      ["基础及专业理论核心课", "数学课", "数值分析"])
    XCTAssertEqual(theory.pending, 5)
  }

  func testTotalMetDoesNotHideUnmetSubgroupOrMinimumCourseCount() throws {
    var snapshot = try fixture()
    let execution = try XCTUnwrap(snapshot.planExecution)
    snapshot = replacing(snapshot, execution: GraduatePlanExecution(
      totalRequiredCredits: 8, earnedCredits: 8, pendingCredits: 5, researchCredits: nil,
      stageRequiredCredits: nil, stageEarnedCredits: nil, categories: execution.categories))
    let root = GraduateRequirementBuilder.build(snapshot)
    XCTAssertEqual(root.gap, 0)
    XCTAssertTrue(root.children[0].needsAttention)
    XCTAssertEqual(root.children[0].countGap, 2)
  }

  func testMissingRequirementOrEarnedCreditsStayUnknown() {
    let node = GraduateRequirement(id: "a", title: "综合实践", path: [], kind: .category,
      required: 8, earned: nil, pending: 8)
    XCTAssertNil(node.gap)
    XCTAssertTrue(node.needsAttention)
    let pool = GraduateRequirement(id: "b", title: "课程池", path: [], kind: .category,
      earned: 3, pending: 20)
    XCTAssertNil(pool.gap)
  }

  func testExecutionParserPreservesZeroRequirementAndCombinedRule() throws {
    let execution = try XCTUnwrap(GraduateAcademicClient.parseExecution(envelope()))
    XCTAssertEqual(execution.categories[1].requiredCredits, 0)
    XCTAssertEqual(execution.categories[1].requirementNote, "综合实践与专业实践合计至少 8 学分")
    XCTAssertEqual(execution.jointEarnedCredits, 2)
    XCTAssertEqual(execution.categories[0].groups[0].courses[0].completed, true)
  }

  func testExecutionParsesJSONStringTreeAndRejectsMalformedGroup() throws {
    var data = envelope()
    let encoded = try JSONSerialization.data(withJSONObject: data["zxbg"]!)
    data["zxbg"] = String(data: encoded, encoding: .utf8)
    XCTAssertEqual(try GraduateAcademicClient.parseExecution(data)?.categories.count, 2)
    data["zxbg"] = [["kclbmc": "理论课", "dxzList": [["dxzmc": "数学"]], "kcList": []]]
    XCTAssertThrowsError(try GraduateAcademicClient.parseExecution(data))
  }

  func testExecutionRejectsBusinessFailureAndMissingStructure() {
    XCTAssertThrowsError(try GraduateAcademicClient.parseExecution(["code": 0, "msg": "暂不可用"]))
    XCTAssertThrowsError(try GraduateAcademicClient.parseExecution(["code": 1, "datas": [:]]))
    XCTAssertThrowsError(try GraduateAcademicClient.parseExecution(["zxbg": []]))
  }

  func testAllEarnedCreditsAreNotSubstitutedForCreditsRecognizedByPlan() throws {
    var data = envelope()
    data.removeValue(forKey: "yhpyfaxf")
    data["yxxf"] = 50
    let execution = try XCTUnwrap(GraduateAcademicClient.parseExecution(data))
    XCTAssertNil(execution.earnedCredits)
  }

  func testPartialFailurePreservesPreviousDataAndTimestamp() throws {
    var old = try fixture()
    let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
    old.sourceDates = ["execution": originalDate, "grades": originalDate]
    old = replacing(old, grades: [GraduateGradeRecord(id: "g1", courseName: "数值分析",
      courseCode: "M1", score: "85", credits: 3, gradePoint: nil, category: nil)])
    var fresh = replacing(try fixture(), execution: nil)
    fresh.issues = [GraduateAcademicIssue(section: .execution, message: "网络中断"),
      GraduateAcademicIssue(section: .grades, message: "结构变化")]
    fresh.sourceDates = ["plan": Date()]
    let merged = fresh.retainingSuccessfulData(from: old)
    XCTAssertEqual(merged.planExecution, old.planExecution)
    XCTAssertEqual(merged.grades, old.grades)
    XCTAssertEqual(merged.sourceDates?["execution"], originalDate)
    XCTAssertTrue(merged.issue(for: .grades)?.usesPreviousData == true)
  }

  func testSuccessfulEmptyGradesReplaceOldGrades() throws {
    var old = try fixture()
    old = replacing(old, grades: [GraduateGradeRecord(id: "g1", courseName: "示例课",
      courseCode: nil, score: "85", credits: 3, gradePoint: nil, category: nil)])
    let fresh = try fixture()
    XCTAssertTrue(fresh.retainingSuccessfulData(from: old).grades.isEmpty)
  }

  func testHistoricalScheduleCannotBecomeCurrentStudy() {
    XCTAssertFalse(GraduateProgressBuilder.termMatches("20251", "20261"))
    XCTAssertFalse(GraduateProgressBuilder.termMatches("20261", nil))
    XCTAssertTrue(GraduateProgressBuilder.termMatches("2026-2027-1", "20261"))
    XCTAssertTrue(GraduateProgressBuilder.termMatches("2026-1", "20261"))
    XCTAssertNil(GraduateProgressBuilder.passingStatus("DEFERRED"))
    XCTAssertNil(GraduateProgressBuilder.passingStatus("PENDING"))
  }

  @MainActor
  func testRequirementDashboardRendersAtDesktopAndPhoneWidths() throws {
    let snapshot = try fixture()
    for (name, width, scheme) in [("desktop", 960.0, ColorScheme.light),
      ("phone", 350.0, ColorScheme.light), ("dark", 960.0, ColorScheme.dark)] {
      let view = GraduateRequirementDashboard(snapshot: snapshot, expandAll: true)
        .padding(20).frame(width: width).background(Color.ginkgoWindowBackground)
        .environment(\.colorScheme, scheme)
      #if os(macOS)
      let host = NSHostingView(rootView: view)
      host.frame = CGRect(x: 0, y: 0, width: width, height: host.fittingSize.height)
      host.layoutSubtreeIfNeeded()
      let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
      try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("ginkgo-academic-\(name).png"))
      XCTAssertGreaterThan(host.bounds.height, 500)
      #else
      let renderer = ImageRenderer(content: view)
      renderer.scale = 1
      let image = try XCTUnwrap(renderer.cgImage)
      XCTAssertEqual(image.width, Int(width))
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("ginkgo-academic-\(name).png")
      let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
      CGImageDestinationAddImage(destination, image, nil)
      XCTAssertTrue(CGImageDestinationFinalize(destination))
      #endif
    }
  }

  private func fixture() throws -> GraduateAcademicSnapshot {
    GraduateAcademicSnapshot(
      status: GraduateStatusSummary(college: "示例学院", major: "软件工程", grade: "2026",
        degreeLevel: "硕士", studentType: nil, status: "在籍", className: nil, campus: nil,
        studyMode: nil, enrollmentDate: nil, expectedGraduation: nil),
      plan: GraduatePlan(title: "软件工程 · 硕士培养方案", college: nil, major: nil,
        totalCredits: 32, degreeCourseCredits: nil, jointCourseCredits: nil, reviewStatus: nil,
        sections: [], courses: []),
      planExecution: try GraduateAcademicClient.parseExecution(envelope()),
      examSummary: GraduateExamSummary(examCount: 0, quizCourseCount: 0, invigilationCount: 0),
      grades: [], moduleCategories: [], fetchedAt: Date(), currentTermID: "20261"
    )
  }

  private func replacing(_ value: GraduateAcademicSnapshot, execution: GraduatePlanExecution? = nil,
    grades: [GraduateGradeRecord]? = nil) -> GraduateAcademicSnapshot {
    var result = GraduateAcademicSnapshot(status: value.status, plan: value.plan,
      planExecution: grades == nil ? execution : value.planExecution,
      examSummary: value.examSummary, grades: grades ?? value.grades,
      moduleCategories: value.moduleCategories, fetchedAt: value.fetchedAt)
    result.sourceDates = value.sourceDates
    return result
  }

  private func envelope() -> [String: Any] {
    ["code": 1, "fa": ["ZDXF": 32], "yhpyfaxf": 8, "dkhxf": 11, "yhxqlhkcxf": 2,
      "zxbg": [
        ["kclbdm": "01", "kclbmc": "基础及专业理论核心课", "yqxf": 9, "yhxf": 5,
          "dkhxf": 5, "zsms": 3,
          "dxzList": [["dxzdm": "0101", "dxzmc": "数学课", "yqxf": 3, "yhxf": 1, "dkhxf": 2,
            "kcList": [["kcdm": "M1", "kcmc": "数值分析", "xf": 3, "sfwc": true, "cjxsz": "85"],
              ["kcdm": "M2", "kcmc": "矩阵理论", "xf": 2, "sfwc": false]]]], "kcList": []],
        ["kclbdm": "02", "kclbmc": "综合实践", "yqxf": 0, "yhxf": 0,
          "kclbhbzyq": "综合实践与专业实践合计至少 8 学分", "dxzList": [], "kcList": []]
      ]]
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class GradeParserTests: XCTestCase {
  func testTermNormalization() throws {
    XCTAssertEqual(try GradeTermCode.parts("20251").year, "2025-2026")
    XCTAssertEqual(try GradeTermCode.parts("20251").semester, "1")
    XCTAssertEqual(try GradeTermCode.parts("2025-2026-2").semester, "2")
    XCTAssertThrowsError(try GradeTermCode.parts("2025-2027-1"))
  }

  func testScoresWithStringAndNumericFields() throws {
    let data = Data(#"{"e":0,"m":"","d":{"a":{"kcmc":"算法","xf":4.0,"kccj":92},"b":{"kcmc":"英语","xf":"2","kccj":"优秀"}}}"#.utf8)
    let courses = try GradeParser.courses(data)
    XCTAssertEqual(courses.count, 2)
    XCTAssertEqual(courses.first(where: { $0.name == "算法" })?.scoreValue, 92)
    XCTAssertNil(courses.first(where: { $0.name == "英语" })?.scoreValue)
    let snapshot = GradeSnapshot(term: SchoolTerm(id: "20251", name: "第一学期", isSelected: true), courses: courses, fetchedAt: Date())
    XCTAssertEqual(snapshot.weightedAverage, 92)
    XCTAssertNotNil(snapshot.gradePointAverage)
  }

  func testErrorCodeIsRejected() {
    XCTAssertThrowsError(try GradeParser.courses(Data(#"{"e":1,"m":"失败","d":{}}"#.utf8)))
  }

  func testFailedPercentageScoreCountsAsZeroAndFivePointScaleIsExcluded() throws {
    let data = Data(#"{"e":0,"d":{"a":{"kcmc":"课程甲","xf":2,"kccj":100,"fslx":"百分制"},"b":{"kcmc":"课程乙","xf":2,"kccj":50,"fslx":"百分制"},"c":{"kcmc":"课程丙","xf":8,"kccj":5,"fslx":"五分制"}}}"#.utf8)
    let snapshot = GradeSnapshot(term: SchoolTerm(id: "20251", name: "第一学期", isSelected: true),
                                 courses: try GradeParser.courses(data), fetchedAt: Date())
    XCTAssertEqual(snapshot.gradePointAverage, 2)
    XCTAssertEqual(snapshot.weightedAverage, 75)
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class BykcClientTests: XCTestCase {
  func testRequestEnvelopeContainsEncryptedPayloadAndRSAFields() throws {
    let request = try BykcCrypto.encrypt(["courseName": "示例课程"])
    let encrypted = try XCTUnwrap(Data(base64Encoded: request.body))
    let decrypted = try BykcCrypto.decrypt(encrypted, key: request.key)
    let object = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: decrypted) as? [String: String]
    )
    XCTAssertEqual(object["courseName"], "示例课程")
    XCTAssertFalse(request.ak.isEmpty)
    XCTAssertFalse(request.sk.isEmpty)
    XCTAssertFalse(request.ts.isEmpty)
  }

  func testCurrentSemesterChoosesDateWindow() throws {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let now = try XCTUnwrap(formatter.date(from: "2026-10-18 12:00:00"))
    let semesters = [
      BykcSemester(id: 1, name: "春季", startDate: "2026-02-01 00:00:00", endDate: "2026-06-30 23:59:59"),
      BykcSemester(id: 2, name: "秋季", startDate: "2026-09-01 00:00:00", endDate: "2027-01-31 23:59:59")
    ]
    XCTAssertEqual(BykcSemesterPolicy.currentSemester(semesters, now: now)?.name, "秋季")
  }

  func testCurrentSemesterFallsBackToLatestEndDate() throws {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let now = try XCTUnwrap(formatter.date(from: "2030-01-01 12:00:00"))
    let semesters = [
      BykcSemester(id: 1, name: "较早", startDate: "2026-02-01 00:00:00", endDate: "2026-06-30 23:59:59"),
      BykcSemester(id: 2, name: "较晚", startDate: "2026-09-01 00:00:00", endDate: "2027-01-31 23:59:59")
    ]
    XCTAssertEqual(BykcSemesterPolicy.currentSemester(semesters, now: now)?.name, "较晚")
  }

  func testCategoryUsesSubcategoryForFiltering() {
    let course = BykcCourse(
      id: 1,
      name: "示例",
      teacher: nil,
      position: nil,
      category: "博雅课程",
      subcategory: "美育",
      startDate: nil,
      endDate: nil,
      selectStartDate: nil,
      selectEndDate: nil,
      cancelEndDate: nil,
      maxCount: nil,
      currentCount: nil,
      campuses: [],
      summary: nil,
      selected: false,
      hasSignConfig: false
    )
    XCTAssertEqual(BykcCourseCatalog.category(for: course), .named("美育"))
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

/// Rust's recursive runner checks these same inputs against the same expected
/// projections. Keep normalization here limited to model naming and nulls.
final class SharedParserContractTests: XCTestCase {
  private let supported: Set<String> = [
    "auth.cas_login_page",
    "schedule.terms", "schedule.graduate_terms", "schedule.weeks",
    "schedule.undergraduate_courses", "schedule.exams",
    "grades.buaa_score", "grades.term_parts", "homework.spoc_encrypt"
  ]

  func testSharedParserFixturesMatchRustContractProjections() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("fixtures")
    let files = try XCTUnwrap(FileManager.default.enumerator(
      at: root, includingPropertiesForKeys: nil
    )).allObjects.compactMap { $0 as? URL }
      .filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
    var covered = Set<String>()
    for file in files {
      let fixture = try XCTUnwrap(
        JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      )
      let contract = try XCTUnwrap(fixture["contract"] as? String)
      guard supported.contains(contract) else { continue }
      covered.insert(contract)
      XCTAssertEqual(fixture["version"] as? Int, 1, file.lastPathComponent)
      XCTAssertTrue(["synthetic", "redacted-upstream"].contains(
        fixture["source"] as? String ?? ""
      ), file.lastPathComponent)
      let input = try XCTUnwrap(fixture["input"] as? [String: Any])
      let expected = try XCTUnwrap(fixture["expected"] as? [String: Any])
      let actual: [String: Any]
      do {
        actual = try project(contract, input: input)
      } catch {
        actual = ["error": errorCode(error)]
      }
      XCTAssertEqual(NSDictionary(dictionary: actual), NSDictionary(dictionary: expected),
                     file.path)
    }
    XCTAssertEqual(covered, supported, "Every supported contract must have fixtures")
  }

  private func project(_ contract: String, input: [String: Any]) throws -> [String: Any] {
    switch contract {
    case "auth.cas_login_page":
      let html = try XCTUnwrap(input["html"] as? String)
      let captcha: Any = CasPageParser.detectCaptcha(from: html).map {
        ["type": $0.type, "id": $0.id, "imageURL": $0.imageURL.absoluteString]
      } ?? NSNull()
      return [
        "execution": nullable(CasPageParser.extractExecution(from: html)),
        "formAction": nullable(CasPageParser.extractLoginFormAction(from: html)),
        "captcha": captcha
      ]
    case "schedule.terms", "schedule.graduate_terms":
      let terms = try ScheduleParser.terms(body(input), portal:
        contract == "schedule.terms" ? .undergraduate : .graduate)
      return ["terms": terms.map { ["id": $0.id, "name": $0.name, "selected": $0.isSelected] }]
    case "schedule.weeks":
      let weeks = try ScheduleParser.weeks(body(input))
      return ["weeks": weeks.map { [
        "number": $0.number, "startDate": SchoolTime.dayString($0.start),
        "endDate": SchoolTime.dayString($0.end), "current": $0.isCurrent
      ] }]
    case "schedule.undergraduate_courses":
      let courses = try ScheduleParser.undergraduateCourses(body(input))
      return ["courses": try courses.map(encoded)]
    case "schedule.exams":
      let exams = try ScheduleParser.exams(body(input))
      return ["exams": try exams.map { exam -> [String: Any] in
        var result = try encoded(exam)
        result["id"] = exam.id
        return result
      }]
    case "grades.buaa_score":
      let courses = try GradeParser.courses(body(input))
      return ["courses": courses.map { [
        "id": $0.id, "name": $0.name, "code": nullable($0.code),
        "credit": nullable($0.credit), "score": $0.score, "scoreValue": nullable($0.scoreValue),
        "scoreType": nullable($0.scoreType), "courseType": nullable($0.courseType)
      ] }]
    case "grades.term_parts":
      let parts = try GradeTermCode.parts(XCTUnwrap(input["code"] as? String))
      return ["year": parts.year, "semester": parts.semester]
    case "homework.spoc_encrypt":
      let plain = try XCTUnwrap(input["plain"] as? String)
      return ["encoded": SpocHomeworkClient.encrypt(Data(plain.utf8))]
    default:
      XCTFail("Unregistered contract: \(contract)")
      throw ScheduleError.changedResponse
    }
  }

  private func body(_ input: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: XCTUnwrap(input["body"]))
  }

  private func nullable<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }

  private func encoded<T: Encodable>(_ value: T) throws -> [String: Any] {
    var result = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
    )
    // Codable omits absent Optionals, while the shared JSON contract uses null.
    let optionalKeys: [String]
    if value is CourseMeeting {
      optionalKeys = ["startTime", "endTime", "place", "teacher", "color"]
    } else {
      optionalKeys = ["courseNo", "examTimeDescription", "examDate", "startTime", "endTime",
                      "examPlace", "examSeatNo", "week", "examStatus", "examType", "taskId"]
    }
    for key in optionalKeys where result[key] == nil { result[key] = NSNull() }
    return result
  }

  private func errorCode(_ error: Error) -> String {
    guard let error = error as? ScheduleError else {
      XCTFail("Unexpected parser error type: \(type(of: error))")
      return "unexpected_error"
    }
    switch error {
    case .changedResponse, .changedResponseAt: return "changed_response"
    case .unavailable: return "service_unavailable"
    case .invalidTerm: return "invalid_request"
    default:
      XCTFail("Unexpected parser error: \(error)")
      return "unexpected_error"
    }
  }
}

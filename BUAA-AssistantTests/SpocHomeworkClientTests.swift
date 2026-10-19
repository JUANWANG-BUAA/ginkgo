import Foundation
import XCTest
@testable import BUAA_Assistant

final class SpocHomeworkClientTests: XCTestCase {
  private let plainAssignmentsPageParam =
    #"{"pageSize":15,"pageNum":1,"sqlid":"1713252980496efac7d5d9985e81693116d3e8a52ebf2b","xnxq":"2025-20262","kcid":"","yzwz":""}"#
  private let encryptedAssignmentsPageParam =
    "hkJ9jAFVEMFUgJEjbOLv4eRZqXHIsmF+WbYaG1ipT1L1N+BbxRXtBj6Gcjri4Mo+y6q22/FkNm/isiC2+B+/hNejBx2cQJfNp9zoxorVJBa86sID0ROtPQ/2V07JCmVC3qsgIWBokL7EYyiPfilw+0ryJ6e61jRnLn90sQFosew="

  func test_encryptMatchesUBAAKnownAssignmentsVector() {
    XCTAssertEqual(SpocHomeworkClient.encrypt(Data(plainAssignmentsPageParam.utf8)), encryptedAssignmentsPageParam)
  }

  func testRoleDecoderSupportsUBAAFallbackFieldsAndArrays() throws {
    let roleCode = try JSONDecoder().decode(
      SpocHomeworkClient.Role.self,
      from: Data(#"{"rolecode":["02"],"jsdmList":["03"]}"#.utf8)
    )
    let roleList = try JSONDecoder().decode(
      SpocHomeworkClient.Role.self,
      from: Data(#"{"jsdmList":["03"]}"#.utf8)
    )

    XCTAssertEqual(roleCode.resolvedCode, "02")
    XCTAssertEqual(roleList.resolvedCode, "03")
  }

  func testRoleDecoderSupportsCASLoginRoleObjects() throws {
    let role = try JSONDecoder().decode(
      SpocHomeworkClient.Role.self,
      from: Data(#"{"rolecode":null,"jsdmList":null,"role":[{"jsdm":"02","jsmc":"学生"}]}"#.utf8)
    )
    XCTAssertEqual(role.resolvedCode, "02")
  }

  func testCurrentTermKeepsHumanNameAndQueryCode() throws {
    let term = try JSONDecoder().decode(
      SpocHomeworkClient.Term.self,
      from: Data(#"{"dqxq":"2025-2026 学年 第二学期","mrxq":"2025-20262"}"#.utf8)
    )

    XCTAssertEqual(term.dqxq, "2025-2026 学年 第二学期")
    XCTAssertEqual(term.mrxq, "2025-20262")
  }

  func testDateParserSupportsUBAAFractionalUTCDeadline() throws {
    let actual = try XCTUnwrap(SpocHomeworkClient.date("2026-03-31T15:59:59.000+00:00"))
    let expected = try XCTUnwrap(SpocHomeworkClient.date("2026-03-31 23:59:59"))

    XCTAssertEqual(actual.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)
  }

  func testAssignmentDecoderPreservesUBAAPublishAndDueFields() throws {
    let assignment = try JSONDecoder().decode(
      SpocHomeworkClient.Assignment.self,
      from: Data(#"{"zyid":"fixture-id","zymc":"fixture","sskcid":"course-42","mf":"100分","zykssj":"2026-10-01T00:00:00.000+00:00","zyjzsj":"2026-10-08T15:59:59.000+00:00"}"#.utf8)
    )

    XCTAssertEqual(assignment.zykssj, "2026-10-01T00:00:00.000+00:00")
    XCTAssertEqual(assignment.zyjzsj, "2026-10-08T15:59:59.000+00:00")
    XCTAssertEqual(assignment.sskcid, "course-42")
    XCTAssertEqual(SpocHomeworkClient.normalizeScore(assignment.mf), "100")
  }

  func testUnknownSubmissionStatusRetainsUpstreamDetail() {
    let now = Date(timeIntervalSince1970: 1_760_000_000)
    let mapped = SpocHomeworkClient.mapSubmissionStatus("  待批阅  ", dueAt: now.addingTimeInterval(3600), now: now)

    XCTAssertEqual(mapped.status, .unknown)
    XCTAssertEqual(mapped.detail, "待批阅")
  }

  func testDetailParsersKeepPlainTextReadableAndScoreDistinct() {
    XCTAssertEqual(
      HTMLText.multilineText("<p>第一题&nbsp;完成</p><p>第二题 &amp; 附图</p>"),
      "第一题 完成\n第二题 & 附图"
    )
    XCTAssertEqual(SpocHomeworkClient.normalizeScore("满分：100.0 分"), "100.0")
  }

  func testSubmissionStatusDoesNotInferSubmittedFromMissingRecord() {
    XCTAssertEqual(SpocHomeworkClient.mapSubmissionStatus(nil, hasSubmissionRecord: false, dueAt: Date().addingTimeInterval(3600)).status, .pending)
    XCTAssertEqual(SpocHomeworkClient.mapSubmissionStatus(nil, hasSubmissionRecord: true, dueAt: nil).status, .unknown)
    XCTAssertEqual(SpocHomeworkClient.mapSubmissionStatus("已提交", hasSubmissionRecord: true, dueAt: nil).status, .submitted)
  }

  func testDetailSubmissionStatusPreservesUnknownUpstreamValue() {
    let mapped = SpocHomeworkClient.mapSubmissionStatus(
      "已退回",
      hasSubmissionRecord: true,
      dueAt: nil
    )

    XCTAssertEqual(mapped.status, .unknown)
    XCTAssertEqual(mapped.detail, "已退回")
  }
}

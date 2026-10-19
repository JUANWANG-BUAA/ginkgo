import Foundation
import XCTest
@testable import BUAA_Assistant

final class GraduateAcademicClientTests: XCTestCase {
  func testLoadingSeparatesFailedGradesFromSuccessfulEmptyExams() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [AcademicReviewProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); AcademicReviewProtocol.handler = nil }
    AcademicReviewProtocol.handler = { request in
      let path = request.url?.path ?? ""
      let endpoint = request.url?.lastPathComponent ?? ""
      if path.contains("xscjcx.do") { return (503, [:]) }
      switch endpoint {
      case "getUserInfo.do": return (200, ["code": 0, "data": ["xnxqdm": "20261"]])
      case "xsjcxxcx.do": return (200, ["code": 0, "datas": ["xsjcxxcx": ["rows": [["YXDM_DISPLAY": "示例学院"]]]]])
      case "getCanVisitAppList.do": return (200, ["success": true, "res": []])
      case "gjxhcxdyfadm.do": return (200, ["datas": ["gjxhcxdyfadm": ["rows": [["FADM": "test-plan"]]]]])
      case "facx.do": return (200, ["datas": ["facx": ["rows": [["MC": "测试方案", "ZDXF": 32, "XQLHKCXF": 2]]]]])
      case "gjfadmhqdydpyfanr.do": return (200, ["datas": ["gjfadmhqdydpyfanr": ["rows": []]]])
      case "pyfakcxxcx.do": return (200, ["datas": ["pyfakcxxcx": ["rows": []]]])
      case "loadXspyfazxbgInfo.do": return (200, ["code": 1, "fa": ["ZDXF": 32], "yhpyfaxf": 8,
        "zxbg": [["kclbmc": "学位课", "kclbdm": "01", "yqxf": 9, "yhxf": 3, "dxzList": [], "kcList": []]]])
      case "getWdksxx.do": return (200, ["countKs": 0, "countKcks": 0, "countJk": 0])
      default: return (200, [:])
      }
    }
    let snapshot = try await GraduateAcademicClient(session: session).load(account: "synthetic-student")
    XCTAssertEqual(snapshot.currentTermID, "20261")
    XCTAssertEqual(snapshot.plan?.jointCourseCredits, 2)
    XCTAssertEqual(snapshot.planExecution?.earnedCredits, 8)
    XCTAssertNotNil(snapshot.issue(for: .grades))
    XCTAssertNil(snapshot.issue(for: .exams))
    XCTAssertEqual(snapshot.examSummary.total, 0)
    XCTAssertNotNil(snapshot.sourceDates?["exams"])
    XCTAssertNil(snapshot.sourceDates?["grades"])
  }

  func testStatusMappingUsesWhitelistedFieldsOnly() {
    let status = GraduateAcademicClient.status([
      "YXDM_DISPLAY": "示例学院",
      "ZYDM_DISPLAY": "示例专业",
      "NJDM_DISPLAY": "2026",
      "PYCCDM_DISPLAY": "硕士",
      "XSLBDM_DISPLAY": "全日制",
      "XJZTDM_DISPLAY": "在籍",
      "BJMC": "示例班",
      "XQDM_DISPLAY": "学院路",
      "XXFSDM_DISPLAY": "全日制",
      "RDRQ": "2026-09-01",
      "SJBYSJ": "2029-06-30",
      "ZJHM": "must-not-be-mapped",
      "SJHM": "must-not-be-mapped",
      "JTDZDM": "must-not-be-mapped"
    ])
    XCTAssertEqual(status.college, "示例学院")
    XCTAssertEqual(status.major, "示例专业")
    XCTAssertEqual(status.grade, "2026")
    XCTAssertEqual(status.status, "在籍")
    XCTAssertEqual(status.expectedGraduation, "2029-06-30")
  }

  func testModuleCatalogPreservesAppAndMenuNames() {
    let envelope: [String: Any] = [
      "success": true,
      "res": [[
        "FZDM": "category-1",
        "FZMC": "课程学习",
        "secondCategory": [[
          "secondCategoryApp": [[
            "YYDM": "wdcjapp",
            "YYMC": "我的成绩",
            "caidanList": [
              ["caidandm": "wdcj", "caidanmc": "我的成绩"]
            ]
          ]]
        ]]
      ]]
    ]
    let categories = GraduateAcademicClient.moduleCategories(envelope)
    XCTAssertEqual(categories.first?.name, "课程学习")
    XCTAssertEqual(categories.first?.apps.first?.name, "我的成绩")
    XCTAssertEqual(categories.first?.apps.first?.menus.first?.name, "我的成绩")
  }

  func testPlanCourseCreditAndExamSummaryFormatting() {
    let course = GraduatePlanCourse(
      id: "1",
      name: "示例课程",
      code: "M001",
      credits: 3,
      category: "学位课",
      examMode: "考试",
      term: "第一学期",
      required: "是"
    )
    XCTAssertEqual(course.creditText, "3 学分")
    XCTAssertEqual(
      GraduateExamSummary(examCount: 2, quizCourseCount: 1, invigilationCount: 0).total,
      3
    )
  }
}

private final class AcademicReviewProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, [String: Any]))?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let url = request.url, let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
    }
    let (status, object) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil),
          let data = try? JSONSerialization.data(withJSONObject: object) else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class JudgeHomeworkClientTests: XCTestCase {
  func testDetailParserExtractsDatesScoresAndPerProblemProgress() throws {
    let html = """
    <html><body>
      <div>作业时间：2099-04-20 19:00:00 至 2099-05-03 23:00:00</div>
      <div>作业满分：100.00，共 2道 题</div>
      <table><tbody>
        <tr><th>1.</th><td>设计说明</td><td>60.00</td><td>初次提交时间: 2099-04-17 12:24:26 得分：58.00</td></tr>
        <tr><th>2.</th><td>用例设计</td><td>40.00</td><td>未提交答案</td></tr>
      </tbody></table>
    </body></html>
    """

    let detail = JudgeHomeworkClient.parseDetail(html: html, itemID: "judge:1:101")

    XCTAssertEqual(detail.itemID, "judge:1:101")
    XCTAssertEqual(detail.score, "100.00")
    XCTAssertEqual(detail.earnedScore, "58")
    XCTAssertEqual(detail.totalProblems, 2)
    XCTAssertEqual(detail.submittedCount, 1)
    XCTAssertEqual(detail.submissionStatus, .pending)
    XCTAssertEqual(detail.problems.map(\.name), ["设计说明", "用例设计"])
    XCTAssertEqual(detail.problems.map(\.status), [.submitted, .pending])
    XCTAssertEqual(detail.problems[0].earnedScore, "58.00")
    XCTAssertEqual(detail.problems[1].maxScore, "40.00")
    XCTAssertTrue(try XCTUnwrap(detail.content).contains("用例设计"))
    XCTAssertNotNil(detail.publishedAt)
    XCTAssertNotNil(detail.dueAt)
    XCTAssertNotNil(detail.submittedAt)
  }

  func testDetailParserRecognizesCompleteSubmissionAndDecodesEntities() {
    let html = """
    <div>作业时间: 2099-04-20 19:00 至 2099-05-03 23:00</div>
    <div>作业满分: 20，共 1 道题</div>
    <table><tr><th>1.</th><td>A &amp; B</td><td>20</td><td>Accepted 得分: 20</td></tr></table>
    """

    let detail = JudgeHomeworkClient.parseDetail(html: html, itemID: "judge:2:202")

    XCTAssertEqual(detail.submissionStatus, .submitted)
    XCTAssertEqual(detail.submittedCount, 1)
    XCTAssertEqual(detail.earnedScore, "20")
    XCTAssertEqual(detail.problems.first?.name, "A & B")
  }

  func testDetailParserEstimatesSubmissionProgressForNonTableQuestionTypes() {
    let html = """
    <div>作业满分：30，共 3 道题；总分：20</div>
    <section>选择题 得分：10</section>
    <section>填空题 得分：10</section>
    <section>编程题 最后一次提交时间：2099-05-01 12:00:00</section>
    """

    let detail = JudgeHomeworkClient.parseDetail(html: html, itemID: "judge:3:303")

    XCTAssertEqual(detail.totalProblems, 3)
    XCTAssertEqual(detail.submittedCount, 3)
    XCTAssertEqual(detail.submissionStatus, .submitted)
    XCTAssertEqual(detail.earnedScore, "20")
  }

  func testLoadDetailRestoresCourseContextAndUsesQueryParameter() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [JudgeMockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    var requestedAssignment = false
    JudgeMockURLProtocol.handler = { request in
      switch (request.url?.host, request.url?.path) {
      case ("sso.buaa.edu.cn", "/login"):
        XCTAssertTrue(
          request.url?.absoluteString.contains("service=https%3A%2F%2Fjudge.buaa.edu.cn%2F") == true,
          "CAS service 必须使用 https，否则 ATS 会拦截后的明文跳转"
        )
        return (200, [:], Data("<html>ready</html>".utf8))
      case ("judge.buaa.edu.cn", "/courselist.jsp"):
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "7")
        return (200, [:], Data("<html>course selected</html>".utf8))
      case ("judge.buaa.edu.cn", "/assignment/index.jsp"):
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "101")
        requestedAssignment = true
        return (200, [:], Data("<div>作业满分：10，共 1 道题</div><table><tr><th>1.</th><td>题目</td><td>10</td><td>未提交答案</td></tr></table>".utf8))
      default:
        XCTFail("Unexpected URL: \(request.url?.absoluteString ?? "nil")")
        return (500, [:], Data())
      }
    }
    defer {
      JudgeMockURLProtocol.handler = nil
      session.invalidateAndCancel()
    }

    let detail = try await JudgeHomeworkClient(session: session).loadDetail(
      itemID: "judge:7:101", courseID: "7", assignmentID: "101"
    )

    XCTAssertTrue(requestedAssignment)
    XCTAssertEqual(detail.itemID, "judge:7:101")
    XCTAssertEqual(detail.totalProblems, 1)
    XCTAssertEqual(detail.problems.first?.status, .pending)
  }

  func testLoadListsAssignmentsAgainstTheirSelectedCourses() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [JudgeMockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    var selectedCourseID: String?
    let assignments = ["1": "11", "2": "22"]
    JudgeMockURLProtocol.handler = { request in
      let url = request.url!
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      let courseID = query.first(where: { $0.name == "courseID" })?.value
      let assignmentID = query.first(where: { $0.name == "assignID" })?.value
      switch (url.host, url.path, courseID, assignmentID) {
      case ("sso.buaa.edu.cn", "/login", _, _):
        return (200, [:], Data("<html>ready</html>".utf8))
      case ("judge.buaa.edu.cn", "/courselist.jsp", "0", nil):
        return (200, [:], Data("<a href=\"courselist.jsp?courseID=1\">课程甲</a><a href=\"courselist.jsp?courseID=2\">课程乙</a>".utf8))
      case ("judge.buaa.edu.cn", "/courselist.jsp", let id?, nil):
        selectedCourseID = id
        return (200, [:], Data("<html>selected</html>".utf8))
      case ("judge.buaa.edu.cn", "/assignment/index.jsp", nil, nil):
        guard let selectedCourseID, let assignmentID = assignments[selectedCourseID] else {
          XCTFail("Assignment list requested without a selected course")
          return (500, [:], Data())
        }
        let name = selectedCourseID == "1" ? "作业甲" : "作业乙"
        return (200, [:], Data("<a href=\"assignment/index.jsp?assignID=\(assignmentID)\">\(name)</a>".utf8))
      case ("judge.buaa.edu.cn", "/assignment/index.jsp", nil, let id?):
        let expectedCourseID = id == "11" ? "1" : "2"
        XCTAssertEqual(selectedCourseID, expectedCourseID, "详情请求必须先切换到所属课程")
        let submission = id == "11" ? "Accepted 得分：10" : "未提交答案"
        let due = id == "11" ? "2099-05-02" : "2099-05-03"
        return (200, [:], Data("<div>作业时间：2099-05-01 12:00 至 \(due) 12:00</div><div>作业满分：10，共 1 道题</div><table><tr><th>1.</th><td>题目\(id)</td><td>10</td><td>\(submission)</td></tr></table>".utf8))
      default:
        XCTFail("Unexpected URL: \(url.absoluteString)")
        return (500, [:], Data())
      }
    }
    defer {
      JudgeMockURLProtocol.handler = nil
      session.invalidateAndCancel()
    }

    let snapshot = try await JudgeHomeworkClient(session: session).load()

    XCTAssertEqual(snapshot.items.map(\.id), ["judge:1:11", "judge:2:22"])
    XCTAssertEqual(snapshot.items.map(\.courseName), ["课程甲", "课程乙"])
    XCTAssertEqual(snapshot.items.map(\.status), [.submitted, .pending])
    XCTAssertEqual(URLComponents(url: try XCTUnwrap(snapshot.items[0].sourceURL), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "11")
    XCTAssertEqual(URLComponents(url: try XCTUnwrap(snapshot.items[1].sourceURL), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "22")
  }

  func testCourseListShapeChangeIsReportedAsPossibleUpstreamChange() async {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [JudgeMockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    JudgeMockURLProtocol.handler = { request in
      if request.url?.host == "sso.buaa.edu.cn" {
        return (200, [:], Data("<html>ready</html>".utf8))
      }
      return (200, [:], Data("<html>new page structure</html>".utf8))
    }
    defer {
      JudgeMockURLProtocol.handler = nil
      session.invalidateAndCancel()
    }

    do {
      _ = try await JudgeHomeworkClient(session: session).load()
      XCTFail("A response with no course anchors or empty-state marker should be treated as a format change")
    } catch let error as HomeworkError {
      XCTAssertEqual(error, .upstreamProtocolChanged(source: .judge, stage: "课程列表"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private final class JudgeMockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, [String: String], Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let (status, headers, data) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

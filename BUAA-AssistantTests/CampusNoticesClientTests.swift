import Foundation
import XCTest
@testable import BUAA_Assistant

final class CampusNoticesClientTests: XCTestCase {
  override func tearDown() {
    CampusNoticesMockURLProtocol.handler = nil
    super.tearDown()
  }

  func testParserExtractsNoticeTextDatesAndRelativeLinks() throws {
    let html = """
    <ul>
      <li>
        <a href="info/1010/70027.htm">
          <div class="pub_date"><div><b>15</b><span>2026.10</span></div></div>
          <div class="pub_info"><span>通知公告</span><h3>讲座 &amp; 交流</h3><p>欢迎&#x4E2D;&#25991;读者参加。</p></div>
        </a>
      </li>
      <li>
        <a href="https://example.com/outside.htm">
          <div class="pub_date"><div><b>14</b><span>2026.10</span></div></div>
          <h3>外部链接</h3><p>应被忽略</p>
        </a>
      </li>
      <li>
        <a href="javascript:void(0)">
          <div class="pub_date"><div><b>31</b><span>2026.02</span></div></div>
          <h3>无效日期</h3><p>应被忽略</p>
        </a>
      </li>
    </ul>
    """

    let notices = CampusNoticeParser.parse(
      html,
      baseURL: URL(string: "https://news.buaa.edu.cn/tzgg.htm")!
    )

    XCTAssertEqual(notices.count, 1)
    XCTAssertEqual(notices.first?.title, "讲座 & 交流")
    XCTAssertEqual(notices.first?.summary, "欢迎中文读者参加。")
    XCTAssertEqual(notices.first?.publishedAt, "2026-10-15")
    XCTAssertEqual(notices.first?.url.absoluteString, "https://news.buaa.edu.cn/info/1010/70027.htm")
  }

  func testClientLoadsOnlyFivePublicNoticesWithoutCookieHeaders() async throws {
    let fixture = (1...6).map { day in
      """
      <li><a href="info/1010/\(70000 + day).htm"><div class="pub_date"><div><b>\(day)</b><span>2026.10</span></div></div><h3>公告 \(day)</h3><p>摘要</p></a></li>
      """
    }.joined()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CampusNoticesMockURLProtocol.self]
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    CampusNoticesMockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://news.buaa.edu.cn/tzgg.htm")
      XCTAssertTrue(request.value(forHTTPHeaderField: "Accept")?.contains("text/html") == true)
      XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
      return (200, Data("<ul>\(fixture)</ul>".utf8))
    }

    let notices = try await CampusNoticesClient(session: session).load()

    XCTAssertEqual(notices.count, 5)
    XCTAssertEqual(notices.map(\.title), ["公告 1", "公告 2", "公告 3", "公告 4", "公告 5"])
  }

  func testCampusNoticesCacheRoundTripsSnapshot() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = CampusNoticesCache(directory: directory)
    let snapshot = CampusNoticesSnapshot(
      notices: [CampusNotice(
        id: "https://news.buaa.edu.cn/info/1010/70027.htm",
        title: "缓存通知",
        summary: "摘要",
        publishedAt: "2026-10-15",
        url: URL(string: "https://news.buaa.edu.cn/info/1010/70027.htm")!
      )],
      fetchedAt: Date(timeIntervalSince1970: 1_792_000_000)
    )

    try await cache.save(snapshot)

    let restored = await cache.read()
    XCTAssertEqual(restored?.notices, snapshot.notices)
    XCTAssertEqual(restored?.fetchedAt, snapshot.fetchedAt)
  }
}

private final class CampusNoticesMockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    do {
      let (status, data) = try handler(request)
      guard let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "text/html; charset=utf-8"]
      ) else {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        return
      }
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class CgyyClientTests: XCTestCase {
  func testCancellationIsNeverResentAfterHTTP401() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CgyyReviewProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); CgyyReviewProtocol.handler = nil }
    var requests = 0
    CgyyReviewProtocol.handler = { request in
      requests += 1
      XCTAssertEqual(request.httpMethod, "POST")
      return (401, Data("{\"code\":401}".utf8))
    }
    let client = CgyyClient(session: session, accessToken: "synthetic-token")
    do {
      try await client.cancel(orderID: 123)
      XCTFail("Expected uncertain outcome")
    } catch CgyyError.uncertain {} catch { XCTFail("Unexpected error: \(error)") }
    XCTAssertEqual(requests, 1)
  }

  func testCancellationRejectsResponseWithoutBusinessCode() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CgyyReviewProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); CgyyReviewProtocol.handler = nil }
    CgyyReviewProtocol.handler = { _ in (200, Data("{\"data\":null}".utf8)) }
    let client = CgyyClient(session: session, accessToken: "synthetic-token")
    do {
      try await client.cancel(orderID: 123)
      XCTFail("Missing business code must not be treated as success")
    } catch CgyyError.uncertain {} catch { XCTFail("Unexpected error: \(error)") }
  }

  @MainActor
  func testChangingDateDuringLoadingDiscardsOldContext() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CgyyReviewProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); CgyyReviewProtocol.handler = nil; CgyyReviewProtocol.delay = 0 }
    CgyyReviewProtocol.delay = 0.05
    CgyyReviewProtocol.handler = { request in
      let date = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
        .queryItems?.first { $0.name == "searchDate" }?.value ?? ""
      let object: [String: Any] = ["code": 200, "data": [
        "spaceTimeInfo": [], "reservationDateSpaceInfo": [date: []],
        "ableReservationDateList": [date], "token": "synthetic-token"]]
      return (200, try! JSONSerialization.data(withJSONObject: object))
    }
    let model = CgyyViewModel(client: CgyyClient(session: session, accessToken: "synthetic-token"))
    model.selectedSiteID = 1
    model.selectedDate = "2099-01-01"
    let initial = Task { await model.loadDayInfo() }
    while !model.isLoading { await Task.yield() }
    await model.selectDate("2099-01-02")
    await initial.value
    XCTAssertEqual(model.selectedDate, "2099-01-02")
    XCTAssertEqual(model.dayInfo?.date, "2099-01-02")
    XCTAssertEqual(model.dayInfo?.siteID, 1)
  }

  func testSignerMatchesUBAAVector() {
    let sign = CgyySigner.sign(
      path: "/api/front/website/venues",
      parameters: ["page": "-1", "size": "-1", "reservationRoleId": "3"],
      timestamp: 1_700_000_000_000
    )
    XCTAssertEqual(sign, "e5293206cc00281c757eed3674ab37ea")
  }

  func testCaptchaAESMatchesECBVector() throws {
    let encrypted = try CgyyCrypto.aesECBEncrypt("{\"x\":123,\"y\":5}", key: "0123456789abcdef")
    XCTAssertEqual(encrypted, "v2YIRhhvn+W0p2mFHDrkNA==")
  }

  func testOrderSelectionJSONUsesUpstreamKeys() throws {
    let selection = CgyyOrderSelection(spaceID: 12, timeID: 3, groupID: 9)
    let data = try JSONEncoder().encode([selection])
    let text = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertTrue(text.contains("\"spaceId\":12"))
    XCTAssertTrue(text.contains("\"timeId\":3"))
    XCTAssertTrue(text.contains("\"venueSpaceGroupId\":9"))
  }

  func testOrderDisplayStatusAndCancellationWindow() throws {
    let future = CgyyOrdersFixtures.order(
      start: "2099-01-01 10:00:00",
      orderStatus: 1,
      checkStatus: 2
    )
    XCTAssertEqual(future.displayStatus.title, "待审批")
    XCTAssertEqual(future.displayStatus.detail, "待辅导员审批")
    XCTAssertTrue(future.canCancel())

    let soon = CgyyOrdersFixtures.order(
      start: "2099-01-01 10:00:00",
      orderStatus: 1,
      checkStatus: 2
    )
    let twoHoursBefore = try XCTUnwrap(CgyyOrder.date(from: "2099-01-01 08:00:00"))
    XCTAssertFalse(soon.canCancel(at: twoHoursBefore))
  }

  func testLockCodeDisplayUsesOrderView() {
    let lock = CgyyLockCodeInfo(
      qrCode: "123456",
      dueDate: "2026-10-19 22:00:00",
      tradeNo: "T1",
      venueName: "学院路校区",
      siteName: "主楼",
      spaceName: "204",
      orderName: "张三",
      reservationDate: "2026-10-19",
      reservationDateDetail: "204 10:00-11:00",
      reservationStartDate: nil,
      reservationEndDate: nil
    )
    XCTAssertTrue(lock.hasLockCode)
    XCTAssertTrue(lock.hasUpcomingReservation)
    XCTAssertEqual(lock.displayLocation, "学院路校区 主楼")
    XCTAssertEqual(lock.displayTime, "204 10:00-11:00")
  }
}

private enum CgyyOrdersFixtures {
  static func order(start: String, orderStatus: Int, checkStatus: Int) -> CgyyOrder {
    CgyyOrder(
      id: 1,
      tradeNo: "T1",
      venueSiteID: 2,
      reservationDate: "2099-01-01",
      reservationDateDetail: "204 10:00-11:00",
      venueSpaceName: "204",
      campusName: "学院路校区",
      venueName: "主楼",
      siteName: "研讨室",
      reservationStartDate: start,
      reservationEndDate: start,
      phone: "13800000000",
      orderStatus: orderStatus,
      payStatus: 0,
      checkStatus: checkStatus,
      theme: "小组讨论",
      purposeType: 3,
      joinerNum: 4,
      activityContent: "讨论",
      joiners: "课题组",
      checkContent: nil,
      handleReason: nil,
      remark: nil
    )
  }
}

private final class CgyyReviewProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, Data))?
  static var delay: TimeInterval = 0
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let url = request.url, let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
    }
    let (status, data) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
    let complete = {
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      self.client?.urlProtocol(self, didLoad: data)
      self.client?.urlProtocolDidFinishLoading(self)
    }
    if Self.delay > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: complete) }
    else { complete() }
  }
  override func stopLoading() {}
}

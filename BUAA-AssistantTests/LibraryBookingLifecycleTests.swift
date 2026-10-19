import Foundation
import XCTest
@testable import BUAA_Assistant

final class LibraryBookingLifecycleTests: XCTestCase {
  func testCurrentSeatBookingExposesSignInTemporaryLeaveAndCheckout() throws {
    let row: [String: Any] = [
      "id": "current-1",
      "nameMerge": "四层阅览区 A01",
      "type": 1,
      "status": "1",
      "status_name": "使用中",
      "day": "2099-01-01",
      "beginTime": "08:00",
      "endTime": "22:00",
      "flag_in": 1,
      "flag_out": "1",
      "flag_leave": 0,
      "oksign": 1
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: false))

    XCTAssertEqual(booking.type, 1)
    XCTAssertEqual(booking.displayTitle, "四层阅览区 A01")
    XCTAssertTrue(booking.canSignIn)
    XCTAssertTrue(booking.canTemporaryLeave)
    XCTAssertTrue(booking.canCheckout)
    XCTAssertTrue(booking.canCancel())
    XCTAssertEqual(booking.signInActionTitle, "签到入座")
    XCTAssertTrue(booking.hasLifecycleActions)
    XCTAssertFalse(booking.isSeminar)
  }

  func testTemporarilyLeftSeatUsesReturnLabelAndCanCheckout() throws {
    let row: [String: Any] = [
      "id": "current-2",
      "name": "A02",
      "type": 1,
      "status": "1",
      "statusName": "临时离开",
      "day": "2099-01-01",
      "begin_time": "08:00",
      "end_time": "22:00",
      "flag_in": 1,
      "flag_out": 0,
      "flag_leave": 1,
      "oksign": 0
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: false))

    XCTAssertTrue(booking.canReturnFromLeave)
    XCTAssertTrue(booking.canSignIn)
    XCTAssertTrue(booking.canCheckout)
    XCTAssertFalse(booking.canTemporaryLeave)
    XCTAssertEqual(booking.signInActionTitle, "返回入座")
    XCTAssertFalse(booking.canCancel())
  }

  func testSeminarBookingIsNotSentToSeatLifecycleEndpoints() throws {
    let row: [String: Any] = [
      "id": "current-3",
      "nameMerge": "研讨室 204",
      "type": 2,
      "status": "1",
      "status_name": "已预约",
      "day": "2099-01-01",
      "beginTime": "10:00",
      "endTime": "12:00",
      "flag_in": 1,
      "flag_out": 1,
      "flag_leave": 0,
      "oksign": 1
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: false))

    XCTAssertTrue(booking.isSeminar)
    XCTAssertFalse(booking.hasLifecycleActions)
    XCTAssertFalse(booking.canSignIn)
    XCTAssertFalse(booking.canTemporaryLeave)
    XCTAssertFalse(booking.canCheckout)
    XCTAssertTrue(booking.canCancel())
    XCTAssertEqual(booking.displayTitle, "研讨室 204")
  }

  func testMissingUpstreamFlagsStayReadOnly() throws {
    let row: [String: Any] = [
      "id": "history-1",
      "name": "B01",
      "status": "1",
      "status_name": "进行中",
      "day": "2099-01-01",
      "beginTime": "08:00",
      "endTime": "22:00"
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: true))

    XCTAssertFalse(booking.flags.hasHints)
    XCTAssertFalse(booking.hasLifecycleActions)
    XCTAssertTrue(booking.canCancel())
  }

  func testEndedBookingRejectsLifecycleActions() throws {
    let row: [String: Any] = [
      "id": "current-4",
      "name": "A03",
      "type": 1,
      "status": "1",
      "status_name": "使用中",
      "day": "2020-01-01",
      "beginTime": "08:00",
      "endTime": "22:00",
      "flag_in": 1,
      "flag_out": 1,
      "oksign": 1
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: false))

    XCTAssertFalse(booking.hasLifecycleActions)
    XCTAssertFalse(booking.canCancel())
    XCTAssertEqual(booking.displayStatus, "使用中")
  }

  func testCurrentBookingNormalizesCombinedDateTimeFields() throws {
    // 预约必须尚未结束才可暂离；用明天的日期，避免测试结果随运行时刻变化。
    let day = SchoolTime.dayString(Date().addingTimeInterval(24 * 60 * 60))
    let row: [String: Any] = [
      "id": "current-datetime",
      "nameMerge": "研讨室 204",
      "type": 1,
      "status": "1",
      "status_name": "使用中",
      "begin_time": "\(day) 10:00:00",
      "end_time": "\(day) 12:00:00",
      "flag_out": 1
    ]
    let booking = try XCTUnwrap(LibraryClient.booking(from: row, requiresStatus: false))
    XCTAssertEqual(booking.day, day)
    XCTAssertEqual(booking.startTime, "10:00:00")
    XCTAssertEqual(booking.endTime, "12:00:00")
    XCTAssertTrue(booking.canTemporaryLeave)
  }

  func testSeatActionEndpointsMatchFrontendEvidence() {
    XCTAssertEqual(LibrarySeatAction.signIn.path, "space/signin")
    XCTAssertEqual(LibrarySeatAction.temporaryLeave.path, "space/leave")
    XCTAssertEqual(LibrarySeatAction.checkout.path, "space/checkout")
    XCTAssertEqual(LibrarySeatAction.temporaryLeave.title, "临时离开")
    XCTAssertEqual(LibrarySeatAction.checkout.title, "完全离开")
  }
}

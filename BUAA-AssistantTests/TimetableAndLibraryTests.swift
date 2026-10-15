import Foundation
import XCTest
@testable import BUAA_Assistant

final class TimetableAndLibraryTests: XCTestCase {
  func testChainedOverlapsUseConsistentLanes() {
    func course(_ id: String, _ start: Int, _ end: Int) -> CourseMeeting {
      CourseMeeting(id: id, name: id, day: 1, startSection: start, endSection: end, startTime: nil, endTime: nil, place: nil, teacher: nil, color: nil)
    }
    let layout = TimetableLayout.placements([course("a", 1, 2), course("b", 2, 3), course("c", 3, 4)])
    XCTAssertEqual(layout["a"]?.count, 2)
    XCTAssertEqual(layout["b"]?.count, 2)
    XCTAssertEqual(layout["c"]?.count, 2)
    XCTAssertNotEqual(layout["a"]?.lane, layout["b"]?.lane)
    XCTAssertNotEqual(layout["b"]?.lane, layout["c"]?.lane)
  }

  func testReservationEncryptionMatchesOpenSSLVector() throws {
    XCTAssertEqual(try LibraryCrypto.encrypt(Data("hello".utf8), day: "2026-10-13"), "4P5qd0GhoSBYCiSluQMcRA==")
    XCTAssertThrowsError(try LibraryCrypto.encrypt(Data(), day: "invalid"))
  }

  func testCasQueryAndFragment() {
    XCTAssertEqual(LibraryClient.casToken("https://booking.lib.buaa.edu.cn/?cas=synthetic%2Bticket"), "synthetic+ticket")
    XCTAssertEqual(LibraryClient.casToken("https://booking.lib.buaa.edu.cn/#cas=synthetic-ticket"), "synthetic-ticket")
    XCTAssertNil(LibraryClient.casToken("https://booking.lib.buaa.edu.cn/"))
  }
}

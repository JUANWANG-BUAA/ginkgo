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

  func testFinishedLibraryBookingsCannotBeCancelled() {
    let now = ISO8601DateFormatter().date(from: "2026-10-16T02:00:00Z")!
    func booking(id: String = "booking", endTime: String = "12:00", status: String = "1", statusName: String = "") -> LibraryBooking {
      LibraryBooking(
        id: id, name: "座位", areaName: "阅览区", seatNumber: "A01", day: "2026-10-16",
        startTime: "08:00", endTime: endTime, status: status, statusName: statusName
      )
    }

    XCTAssertTrue(booking().canCancel(at: now))
    XCTAssertFalse(booking(endTime: "09:00").canCancel(at: now))
    XCTAssertFalse(booking(status: "8").canCancel(at: now))
    XCTAssertFalse(booking(status: "6").canCancel(at: now))
    XCTAssertFalse(booking(statusName: "预约已完成").canCancel(at: now))
    XCTAssertFalse(booking(id: "").canCancel(at: now))
  }

  func testLibraryCacheBoundsSeatSnapshotAndKeepsTruncationFlag() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = LibraryCache(directory: directory)
    let seats = (0..<2_001).map { index in
      LibraryItem(id: "seat-\(index)", name: "座位 \(index)", detail: "可预约", available: true, availableCount: nil, totalCount: nil)
    }
    let snapshot = LibraryCacheSnapshot(
      libraries: [], libraryID: "", areas: [], areaID: "", slots: [], slotID: "",
      seats: seats, seatsAreTruncated: false, seatsFetchedAt: Date(), publicStats: nil, fetchedAt: Date()
    )

    try await cache.save(snapshot, account: "test-account")
    let cachedSnapshot = await cache.read(account: "test-account")
    let restored = try XCTUnwrap(cachedSnapshot)

    XCTAssertEqual(restored.seats.count, 2_000)
    XCTAssertTrue(restored.seatsAreTruncated)
    try await cache.clear(account: "test-account")
    let clearedSnapshot = await cache.read(account: "test-account")
    XCTAssertNil(clearedSnapshot)
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class BykcRepositoryTests: XCTestCase {
  func testRefreshCachesByAccountAndClearRemovesOnlyThatAccount() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let snapshot = makeSnapshot()
    let service = StubBykcService(snapshot: snapshot)
    let repository = DefaultBykcRepository(
      service: service,
      cache: BykcCache(directory: directory)
    )

    let loaded = try await repository.refresh(account: "synthetic-account-a")
    XCTAssertEqual(loaded, snapshot)
    let cachedForAccountA = await repository.cachedSnapshot(account: "synthetic-account-a")
    let cachedForAccountB = await repository.cachedSnapshot(account: "synthetic-account-b")
    let loadCount = await service.loadCount
    XCTAssertEqual(cachedForAccountA, snapshot)
    XCTAssertNil(cachedForAccountB)
    XCTAssertEqual(loadCount, 1)

    try await repository.clearCache(account: "synthetic-account-a")
    let clearedAccountA = await repository.cachedSnapshot(account: "synthetic-account-a")
    let stillEmptyAccountB = await repository.cachedSnapshot(account: "synthetic-account-b")
    XCTAssertNil(clearedAccountA)
    XCTAssertNil(stillEmptyAccountB)
  }

  private func makeSnapshot() -> BykcSnapshot {
    BykcSnapshot(
      profile: BykcProfile(studentType: nil, className: nil, collegeName: nil, termName: nil),
      semesters: [],
      currentSemester: nil,
      courses: [],
      chosen: [],
      statistics: [],
      validCourseCount: 0,
      fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
  }
}

private actor StubBykcService: BykcServing {
  private let snapshot: BykcSnapshot
  private(set) var loadCount = 0

  init(snapshot: BykcSnapshot) {
    self.snapshot = snapshot
  }

  func load() async throws -> BykcSnapshot {
    loadCount += 1
    return snapshot
  }
}

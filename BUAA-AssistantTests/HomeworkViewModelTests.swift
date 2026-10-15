import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class HomeworkViewModelTests: XCTestCase {
  func testProtocolNotConfiguredIsShownAsUnavailableNotEmpty() async {
    let model = HomeworkViewModel(service: StubHomeworkService(result: .failure(HomeworkError.protocolNotConfigured)))
    await model.refresh()
    XCTAssertNil(model.snapshot)
    XCTAssertEqual(model.errorMessage, HomeworkError.protocolNotConfigured.errorDescription)
  }

  func testPendingItemsSortByDueDateAndExcludeSubmitted() async {
    let now = Date()
    let items = [
      HomeworkItem(id: "late", courseName: "课程 B", title: "迟到作业", dueAt: now.addingTimeInterval(7200), sourceURL: nil, status: .pending, source: .judge, fetchedAt: now),
      HomeworkItem(id: "done", courseName: "课程 A", title: "已交作业", dueAt: now, sourceURL: nil, status: .submitted, source: .spoc, fetchedAt: now),
      HomeworkItem(id: "soon", courseName: "课程 A", title: "近期作业", dueAt: now.addingTimeInterval(60), sourceURL: nil, status: .pending, source: .judge, fetchedAt: now)
    ]
    let model = HomeworkViewModel(service: StubHomeworkService(result: .success(HomeworkSnapshot(items: items, fetchedAt: now))))
    await model.refresh()
    XCTAssertEqual(model.pendingItems.map(\.id), ["soon", "late"])
  }
}

private struct StubHomeworkService: HomeworkServing {
  let result: Result<HomeworkSnapshot, Error>
  func load() async throws -> HomeworkSnapshot { try result.get() }
}

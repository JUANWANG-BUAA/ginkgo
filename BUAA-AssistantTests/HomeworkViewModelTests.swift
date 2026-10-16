import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class HomeworkViewModelTests: XCTestCase {
  func testHomeworkSnapshotDecodesLegacyCacheWithoutSpocTerm() throws {
    let snapshot = try JSONDecoder().decode(
      HomeworkSnapshot.self,
      from: Data(#"{"items":[],"fetchedAt":0}"#.utf8)
    )

    XCTAssertNil(snapshot.spocTerm)
    XCTAssertEqual(snapshot.unavailableSources, [])
    XCTAssertEqual(snapshot.protocolChangedSources, [])
  }

  func testHomeworkSnapshotPersistsSpocTermContext() throws {
    let original = HomeworkSnapshot(
      items: [],
      fetchedAt: Date(timeIntervalSince1970: 1),
      spocTerm: HomeworkTerm(code: "2025-20262", name: "2025-2026 学年 第二学期")
    )
    let data = try JSONEncoder().encode(original)
    let restored = try JSONDecoder().decode(HomeworkSnapshot.self, from: data)

    XCTAssertEqual(restored.spocTerm, original.spocTerm)
    XCTAssertEqual(restored.spocTerm?.displayName, "2025-2026 学年 第二学期 · 2025-20262")
  }

  func testHomeworkItemDecodesLegacyCacheWithoutCourseID() throws {
    let item = try JSONDecoder().decode(
      HomeworkItem.self,
      from: Data(#"{"id":"spoc:assignment-1","courseName":"课程","title":"作业","dueAt":null,"publishedAt":null,"teacherName":null,"score":null,"sourceURL":null,"status":"pending","source":"spoc","fetchedAt":0}"#.utf8)
    )

    XCTAssertNil(item.courseID)
    XCTAssertNil(item.statusDetail)
  }

  func testHomeworkItemPersistsOptionalCourseIDAndStatusDetail() throws {
    let original = HomeworkItem(
      id: "spoc:assignment-1",
      courseName: "课程",
      title: "作业",
      dueAt: nil,
      sourceURL: nil,
      status: .unknown,
      source: .spoc,
      fetchedAt: Date(timeIntervalSince1970: 1),
      courseID: "course-42",
      statusDetail: "待批阅"
    )

    let restored = try JSONDecoder().decode(HomeworkItem.self, from: JSONEncoder().encode(original))
    XCTAssertEqual(restored.courseID, "course-42")
    XCTAssertEqual(restored.statusDetail, "待批阅")
  }

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

  func testAttentionItemsOnlyIncludesPendingItemsDueWithinOneDay() async {
    let now = Date()
    let items = [
      HomeworkItem(id: "soon", courseName: "课程", title: "近期截止", dueAt: now.addingTimeInterval(3_600), sourceURL: nil, status: .pending, source: .judge, fetchedAt: now),
      HomeworkItem(id: "later", courseName: "课程", title: "远期截止", dueAt: now.addingTimeInterval(3 * 24 * 60 * 60), sourceURL: nil, status: .pending, source: .spoc, fetchedAt: now),
      HomeworkItem(id: "unknown", courseName: "课程", title: "未给截止时间", dueAt: nil, sourceURL: nil, status: .pending, source: .spoc, fetchedAt: now),
      HomeworkItem(id: "overdue", courseName: "课程", title: "已逾期", dueAt: now.addingTimeInterval(-7 * 24 * 60 * 60), sourceURL: nil, status: .overdue, source: .judge, fetchedAt: now)
    ]
    let model = HomeworkViewModel(service: StubHomeworkService(result: .success(HomeworkSnapshot(items: items, fetchedAt: now))))

    await model.refresh()

    XCTAssertEqual(model.attentionItems(now: now).map(\.id), ["soon"])
  }

  func testLoadDetailPublishesMatchingAssignmentDetails() async {
    let now = Date()
    let item = HomeworkItem(
      id: "spoc:assignment-1", courseName: "课程 A", title: "作业一", dueAt: nil,
      sourceURL: nil, status: .pending, source: .spoc, fetchedAt: now
    )
    let detail = HomeworkDetail(
      itemID: item.id, content: "完成第一题", submissionStatus: .pending,
      submittedAt: nil, score: "100", publishedAt: now, dueAt: now.addingTimeInterval(3600), fetchedAt: now
    )
    let model = HomeworkViewModel(
      service: StubHomeworkService(result: .success(HomeworkSnapshot(items: [item], fetchedAt: now)), detailResult: .success(detail))
    )

    await model.loadDetail(for: item)

    XCTAssertEqual(model.detailItemID, item.id)
    XCTAssertEqual(model.detail, detail)
    XCTAssertNil(model.detailErrorMessage)
    XCTAssertFalse(model.isLoadingDetail)
  }

  func testDetailSessionExpiryRequestsSharedSessionConfirmation() async {
    let now = Date()
    let item = HomeworkItem(
      id: "spoc:assignment-1", courseName: "课程 A", title: "作业一", dueAt: nil,
      sourceURL: nil, status: .pending, source: .spoc, fetchedAt: now
    )
    let model = HomeworkViewModel(
      service: StubHomeworkService(
        result: .success(HomeworkSnapshot(items: [item], fetchedAt: now)),
        detailResult: .failure(HomeworkError.spocAuthenticationExpired(stage: "作业详情"))
      )
    )

    await model.loadDetail(for: item)

    XCTAssertTrue(model.needsSessionCheck)
    XCTAssertEqual(model.detailErrorMessage, HomeworkError.spocAuthenticationExpired(stage: "作业详情").errorDescription)
  }
}

private struct StubHomeworkService: HomeworkServing, HomeworkDetailServing {
  let result: Result<HomeworkSnapshot, Error>
  var detailResult: Result<HomeworkDetail, Error>? = nil
  func load() async throws -> HomeworkSnapshot { try result.get() }
  func loadDetail(for item: HomeworkItem) async throws -> HomeworkDetail {
    guard let detailResult else { throw HomeworkError.detailUnavailable("详情未配置") }
    return try detailResult.get()
  }
}

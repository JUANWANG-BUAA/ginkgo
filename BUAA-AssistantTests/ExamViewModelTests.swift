import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class ExamViewModelTests: XCTestCase {
  func testRefreshFailureKeepsLastConfirmedExams() async {
    let exam = Exam(courseName: "线性代数", courseNo: "MATH101", examTimeDescription: nil,
                    examDate: "2026-01-08", startTime: "09:00", endTime: "11:00",
                    examPlace: "主楼 201", examSeatNo: "A12", week: 17,
                    examStatus: nil, examType: "期末", taskId: "exam-1")
    let service = StubExamService(results: [.success([exam]), .failure(ScheduleError.unavailable("本科教务"))])
    let model = ExamViewModel(service: service)

    await model.load(termID: "2026-2027-1")
    await model.load(termID: "2026-2027-1", force: true)

    XCTAssertEqual(model.exams, [exam])
    XCTAssertEqual(model.loadedTermID, "2026-2027-1")
    XCTAssertNotNil(model.fetchedAt)
    XCTAssertNotNil(model.errorMessage)
    XCTAssertFalse(model.isLoading)
  }

  func testChangingTermClearsPriorExamListBeforeLoadingNextTerm() async {
    let old = Exam(courseName: "旧学期", courseNo: nil, examTimeDescription: nil,
                   examDate: nil, startTime: nil, endTime: nil, examPlace: nil,
                   examSeatNo: nil, week: nil, examStatus: nil, examType: nil, taskId: "old")
    let service = StubExamService(results: [.success([old]), .failure(ScheduleError.unavailable("本科教务"))])
    let model = ExamViewModel(service: service)

    await model.load(termID: "2025-2026-1")
    await model.load(termID: "2026-2027-1")

    XCTAssertNil(model.exams)
    XCTAssertNil(model.loadedTermID)
    XCTAssertNil(model.fetchedAt)
    XCTAssertNotNil(model.errorMessage)
  }

  func testExpiredDiskCacheRemainsVisibleWhenRefreshFails() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = ExamCache(directory: directory)
    let exam = Exam(courseName: "缓存课程", courseNo: "CACHE101", examTimeDescription: nil,
                    examDate: "2026-12-08", startTime: "09:00", endTime: "11:00",
                    examPlace: "主楼 101", examSeatNo: nil, week: nil,
                    examStatus: nil, examType: "期末", taskId: "cached-exam")
    let termID = "2026-2027-1"
    let cachedAt = Date(timeIntervalSinceNow: -60 * 60)
    try await cache.save(ExamCacheEntry(exams: [exam], fetchedAt: cachedAt), account: "account-1", termID: termID)
    let model = ExamViewModel(
      service: StubExamService(results: [.failure(ScheduleError.unavailable("本科教务"))]),
      cache: cache
    )

    await model.load(termID: termID, account: "account-1")

    XCTAssertEqual(model.exams, [exam])
    XCTAssertEqual(model.fetchedAt, cachedAt)
    XCTAssertNotNil(model.errorMessage)
    XCTAssertFalse(model.isLoading)
  }
}

private actor StubExamService: ExamServing {
  var results: [Result<[Exam], Error>]
  private var index = 0

  init(results: [Result<[Exam], Error>]) { self.results = results }

  func loadExams(termID: String) async throws -> [Exam] {
    guard !results.isEmpty else { return [] }
    let result = results[min(index, results.count - 1)]
    index += 1
    return try result.get()
  }
}

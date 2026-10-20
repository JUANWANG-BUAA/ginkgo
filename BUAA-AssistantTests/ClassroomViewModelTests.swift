import Foundation
import XCTest
@testable import BUAA_Assistant

@MainActor
final class ClassroomViewModelTests: XCTestCase {
  func testPortableClassroomFilterFixtureV1() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("fixtures/classroom/filter-v1.json")
    let fixture = try JSONDecoder().decode(
      ClassroomFilterContractFixture.self,
      from: Data(contentsOf: fixtureURL)
    )

    XCTAssertEqual(fixture.contract, "classroom.filter")
    XCTAssertEqual(fixture.version, 1)
    XCTAssertEqual(fixture.input.sort.rawValue, "availability")

    let result = ClassroomResultProcessor.process(fixture.input.makeInput())
    XCTAssertEqual(result.filtered.mapValues { $0.map(\.id) }, fixture.expected.roomIDsByBuilding)
    XCTAssertEqual(result.summary.roomCount, fixture.expected.summary.roomCount)
    XCTAssertEqual(result.summary.buildingCount, fixture.expected.summary.buildingCount)
    XCTAssertEqual(result.summary.freeSlotCount, fixture.expected.summary.freeSlotCount)
  }

  func testSectionNormalizationAndConsecutiveAvailability() {
    let room = FreeClassroom(id: "test", floorid: "opaque", name: "101", kxsds: "1, 2,2,4,5,6,14,0,15,unknown")
    XCTAssertEqual(room.availableSections, [1, 2, 4, 5, 6, 14])
    XCTAssertEqual(room.longestFreeRun, 3)
    XCTAssertFalse(room.isAvailable(at: 3))
    XCTAssertEqual(FreeClassroom(id: "empty", floorid: "", name: "", kxsds: "").longestFreeRun, 0)
  }

  func testCombinedFiltersSortingAndBuildingNavigation() async {
    let service = FakeClassroomService()
    service.rooms = [
      "主楼": [
        FreeClassroom(id: "1", floorid: "", name: "101", kxsds: "1,3,5,7"),
        FreeClassroom(id: "2", floorid: "", name: "102", kxsds: "1,2,3")
      ],
      "主楼北": [FreeClassroom(id: "3", floorid: "", name: "201", kxsds: "1,2,3,4,5")]
    ]
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()
    model.building = "主楼"
    model.sort = .availability
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filtered["主楼"]?.map(\.id), ["1", "2"])
    XCTAssertNil(model.filtered["主楼北"])
    model.sort = .consecutive
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filtered["主楼"]?.map(\.id), ["2", "1"])
    model.minimumConsecutiveSections = 2
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filtered["主楼"]?.map(\.id), ["2"])
    model.section = 4
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filteredRoomCount, 0)
    model.resetFilters()
    await model.waitForFilterUpdate()
    XCTAssertFalse(model.hasActiveFilters)
    XCTAssertEqual(model.filteredRoomCount, 3)
    model.minimumFreeSections = 4
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filteredRoomCount, 2)
    XCTAssertEqual(service.callCount, 1, "Local filters must not query the school service")
  }

  func testLargeResultsRemainReachableAndFilterCountsAreConsistent() async {
    let service = FakeClassroomService()
    service.rooms = ["测试楼": (1...2000).map {
      FreeClassroom(id: "\($0)", floorid: "", name: "教室 \($0)", kxsds: $0.isMultiple(of: 2) ? "1,2,3,4" : "8,10")
    }]
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()
    XCTAssertEqual(model.roomCount, 2000)
    model.minimumConsecutiveSections = 4
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filteredRoomCount, 1000)
    model.search = "教室 2000"
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filtered["测试楼"]?.first?.id, "2000")
    model.resetFilters()
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filteredRoomCount, 2000)
  }

  func testRoomSearchIgnoresPresentationPunctuation() async {
    let service = FakeClassroomService()
    service.rooms = ["三号楼": [
      FreeClassroom(id: "105", floorid: "", name: "(三)105", kxsds: "1,2,3"),
      FreeClassroom(id: "205", floorid: "", name: "(三)205", kxsds: "1,2,3")
    ]]
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()

    model.search = "三105"
    await model.waitForFilterUpdate()

    XCTAssertEqual(model.filtered["三号楼"]?.map(\.id), ["105"])
  }

  func testFailedRefreshPreservesResultsAndFiltersByBuildingAndSection() async {
    let service = FakeClassroomService()
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()
    model.search = " 主楼 "
    model.section = 2
    await model.waitForFilterUpdate()
    XCTAssertEqual(model.filtered["主楼"]?.count, 1)
    model.section = 3
    await model.waitForFilterUpdate()
    XCTAssertTrue(model.filtered.isEmpty)
    service.fail = true
    await model.query(forceRefresh: true)
    XCTAssertTrue(model.queried)
    XCTAssertNotNil(model.fetchedAt)
    XCTAssertNotNil(model.message)
    XCTAssertEqual(model.rooms["主楼"]?.count, 1)
    model.campus = 2
    XCTAssertFalse(model.queried)
    XCTAssertTrue(model.rooms.isEmpty)
    XCTAssertNil(model.message)
  }

  func testResetDiscardsInFlightResult() async {
    let service = DelayedClassroomService()
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    let request = Task { await model.query() }
    while service.continuation == nil { await Task.yield() }
    model.campus = 2
    service.continuation?.resume(returning: [:])
    await request.value
    XCTAssertFalse(model.queried)
    XCTAssertFalse(model.busy)
    XCTAssertNil(model.fetchedAt)
  }

  func testSessionFailureIsDistinctFromEmptySuccess() async {
    let service = FakeClassroomService()
    service.fail = true
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()
    XCTAssertFalse(model.queried)
    XCTAssertTrue(model.needsSessionCheck)
    XCTAssertNotNil(model.message)
  }

  func testFreshQueryUsesCacheUntilForceRefresh() async {
    let service = FakeClassroomService()
    let model = ClassroomViewModel(repository: DefaultClassroomRepository(client: service))
    await model.query()
    XCTAssertEqual(service.callCount, 1)
    service.rooms = [:]
    await model.query()
    XCTAssertEqual(service.callCount, 1)
    XCTAssertEqual(model.rooms["主楼"]?.count, 1)
    await model.query(forceRefresh: true)
    XCTAssertEqual(service.callCount, 2)
    XCTAssertTrue(model.rooms.isEmpty)
    XCTAssertTrue(model.queried)
  }

  func testDiskCacheRestoresResultsForAnotherWindow() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = ClassroomCache(directory: directory)
    let initialService = FakeClassroomService()
    initialService.rooms = ["主楼": [FreeClassroom(id: "cached-101", floorid: "1", name: "101", kxsds: "1,2,3")]]
    let firstWindow = ClassroomViewModel(
      repository: DefaultClassroomRepository(client: initialService, cache: cache)
    )
    let cachedDate = try XCTUnwrap(SchoolTime.calendar.date(byAdding: .day, value: 1, to: Date()))
    firstWindow.campus = 2
    firstWindow.date = cachedDate
    await firstWindow.start(account: "account-1")
    await firstWindow.query(forceRefresh: true)

    let nextWindowService = FakeClassroomService()
    nextWindowService.fail = true
    let nextWindow = ClassroomViewModel(
      repository: DefaultClassroomRepository(client: nextWindowService, cache: cache)
    )
    await nextWindow.start(account: "account-1")
    await nextWindow.query()

    XCTAssertTrue(nextWindow.queried)
    XCTAssertEqual(nextWindow.rooms["主楼"]?.map(\.id), ["cached-101"])
    XCTAssertEqual(nextWindow.campus, 2)
    XCTAssertTrue(SchoolTime.calendar.isDate(nextWindow.date, inSameDayAs: cachedDate))
    XCTAssertEqual(nextWindowService.callCount, 0, "A fresh disk result should be shown without a redundant request.")
  }
}

private final class FakeClassroomService: ClassroomServing {
  var fail = false
  var callCount = 0
  var rooms: [String: [FreeClassroom]] = ["主楼": [FreeClassroom(id: "synthetic", floorid: "1", name: "101", kxsds: "1, 2,12")]]
  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]] {
    callCount += 1
    if fail { throw ScheduleError.sessionExpired }
    return rooms
  }
}

private final class DelayedClassroomService: ClassroomServing {
  var continuation: CheckedContinuation<[String: [FreeClassroom]], Error>?
  func query(campus: Int, date: Date) async throws -> [String: [FreeClassroom]] {
    try await withCheckedThrowingContinuation { continuation = $0 }
  }
}

private struct ClassroomFilterContractFixture: Decodable {
  let contract: String
  let version: Int
  let input: ClassroomFilterInputFixture
  let expected: Expected

  struct Expected: Decodable {
    let roomIDsByBuilding: [String: [String]]
    let summary: Summary
  }

  struct Summary: Decodable {
    let roomCount: Int
    let buildingCount: Int
    let freeSlotCount: Int
  }
}

private struct ClassroomFilterInputFixture: Decodable {
  let sourceRooms: [String: [FreeClassroom]]
  let search: String
  let section: Int
  let minimumFreeSections: Int
  let minimumConsecutiveSections: Int
  let building: String?
  let sort: ClassroomSort

  func makeInput() -> ClassroomFilterInput {
    ClassroomFilterInput(
      sourceRooms: sourceRooms,
      indexedRooms: nil,
      search: search,
      section: section,
      minimumFreeSections: minimumFreeSections,
      minimumConsecutiveSections: minimumConsecutiveSections,
      building: building,
      sort: sort
    )
  }
}

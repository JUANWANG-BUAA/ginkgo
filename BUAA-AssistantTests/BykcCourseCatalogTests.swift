import Foundation
import XCTest
@testable import BUAA_Assistant

final class BykcCourseCatalogTests: XCTestCase {
  func testPortableCourseFilterFixtureV1() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("fixtures/bykc/course-filter-v1.json")
    let fixture = try JSONDecoder().decode(
      BykcCourseFilterContractFixture.self,
      from: Data(contentsOf: fixtureURL)
    )

    XCTAssertEqual(fixture.contract, "bykc.course_filter")
    XCTAssertEqual(fixture.version, 1)
    XCTAssertEqual(fixture.source, "synthetic")

    let matching = BykcCourseCatalog.filtered(fixture.input.courses, by: fixture.input.filter)
    XCTAssertEqual(matching.map(\.id), fixture.expected.matchingCourseIDs)
    XCTAssertEqual(
      BykcCourseCatalog.categoryCounts(in: fixture.input.courses),
      fixture.expected.categoryCounts
    )
  }

  func testFilterTrimsQueryAndUsesNameTeacherAndLocation() {
    let course = makeCourse(
      id: 1,
      name: "Course Catalog",
      teacher: "Wang Lei",
      position: "North Hall A-101",
      category: "Required",
      subcategory: "Arts"
    )

    for query in [" catalog ", " WANG ", "a-101"] {
      XCTAssertEqual(
        BykcCourseCatalog.filtered([course], by: BykcCourseFilter(searchText: query)).map(\.id),
        [1]
      )
    }
  }

  func testBlankCategoriesNormalizeToUnclassifiedAndCanBeSelected() {
    let course = makeCourse(id: 7, name: "No Category", category: "  ", subcategory: "\n")

    XCTAssertEqual(BykcCourseCatalog.category(for: course), .unclassified)
    XCTAssertEqual(
      BykcCourseCatalog.filtered(
        [course],
        by: BykcCourseFilter(category: .unclassified)
      ).map(\.id),
      [7]
    )
  }

  private func makeCourse(
    id: Int64,
    name: String,
    teacher: String? = nil,
    position: String? = nil,
    category: String? = nil,
    subcategory: String? = nil
  ) -> BykcCourse {
    BykcCourse(
      id: id,
      name: name,
      teacher: teacher,
      position: position,
      category: category,
      subcategory: subcategory,
      startDate: nil,
      endDate: nil,
      selectStartDate: nil,
      selectEndDate: nil,
      cancelEndDate: nil,
      maxCount: nil,
      currentCount: nil,
      campuses: [],
      summary: nil,
      selected: false,
      hasSignConfig: false
    )
  }
}

private struct BykcCourseFilterContractFixture: Decodable {
  let contract: String
  let version: Int
  let source: String
  let input: Input
  let expected: Expected

  struct Input: Decodable {
    let courses: [BykcCourse]
    let filter: BykcCourseFilter
  }

  struct Expected: Decodable {
    let matchingCourseIDs: [Int64]
    let categoryCounts: [BykcCourseCategoryCount]
  }
}

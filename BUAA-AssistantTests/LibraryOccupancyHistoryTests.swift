import Foundation
import XCTest
@testable import BUAA_Assistant

final class LibraryOccupancyHistoryTests: XCTestCase {
  func testHistoryIsLocalDeduplicatedAndForecastUsesSameWeekdayAndHour() throws {
    let suiteName = "LibraryOccupancyHistoryTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let history = LibraryOccupancyHistory(defaults: defaults)
    let firstDay = try date(year: 2026, month: 10, day: 6, hour: 9)
    let secondDay = try date(year: 2026, month: 10, day: 13, hour: 9)
    let thirdDay = try date(year: 2026, month: 10, day: 20, hour: 9)
    let before = try date(year: 2026, month: 10, day: 22, hour: 12)
    let weekday = Calendar(identifier: .gregorian).component(.weekday, from: firstDay)

    history.record(areaID: "area-1", availableSeats: 2, totalSeats: 10, at: firstDay)
    history.record(areaID: "area-1", availableSeats: 4, totalSeats: 10, at: firstDay)
    history.record(areaID: "area-1", availableSeats: 4, totalSeats: 10, at: secondDay)
    history.record(areaID: "area-1", availableSeats: 6, totalSeats: 10, at: thirdDay)
    history.record(areaID: "area-2", availableSeats: 0, totalSeats: 10, at: thirdDay)

    XCTAssertEqual(history.sampleCount(areaID: "area-1", weekday: weekday, hour: 9, before: before), 3)
    let trend = history.trend(areaID: "area-1", weekday: weekday, before: before)
    XCTAssertEqual(trend.map(\.hour), [9])
    XCTAssertEqual(trend.first?.sampleCount, 3)
    XCTAssertEqual(trend.first?.averageUnavailableRatio ?? 0, 0.533333, accuracy: 0.0001)

    let forecast = try XCTUnwrap(history.forecast(
      areaID: "area-1",
      weekday: weekday,
      hour: 9,
      totalSeats: 20,
      before: before
    ))
    XCTAssertEqual(forecast.sampleCount, 3)
    XCTAssertEqual(forecast.estimatedUnavailableSeats, 11)
    XCTAssertEqual(forecast.totalSeats, 20)
  }

  func testForecastWaitsForThreeSamples() throws {
    let suiteName = "LibraryOccupancyHistoryTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let history = LibraryOccupancyHistory(defaults: defaults)
    let sampleDay = try date(year: 2026, month: 10, day: 6, hour: 11)
    let before = try date(year: 2026, month: 10, day: 22, hour: 12)
    let weekday = Calendar(identifier: .gregorian).component(.weekday, from: sampleDay)
    history.record(areaID: "area-1", availableSeats: 5, totalSeats: 10, at: sampleDay)

    XCTAssertNil(history.forecast(areaID: "area-1", weekday: weekday, hour: 11, totalSeats: 10, before: before))
  }

  func testPeopleHistoryDeduplicatesHourlySamplesAndEstimatesByCampusWeekdayAndHour() throws {
    let suiteName = "LibraryOccupancyHistoryTests.People.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let history = LibraryOccupancyHistory(defaults: defaults)
    let firstDay = try date(year: 2026, month: 10, day: 5, hour: 9)
    let secondDay = try date(year: 2026, month: 10, day: 12, hour: 9)
    let thirdDay = try date(year: 2026, month: 10, day: 19, hour: 9)
    let before = try date(year: 2026, month: 10, day: 20, hour: 12)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let weekday = calendar.component(.weekday, from: firstDay)

    history.recordPeople(campusID: "xylxq", people: 100, at: firstDay)
    history.recordPeople(campusID: "xylxq", people: 200, at: firstDay)
    history.recordPeople(campusID: "xylxq", people: 200, at: secondDay)
    history.recordPeople(campusID: "xylxq", people: 300, at: thirdDay)
    history.recordPeople(campusID: "shxq", people: 900, at: thirdDay)

    XCTAssertEqual(history.peopleSampleCount(campusID: "xylxq", weekday: weekday, hour: 9, before: before), 3)
    XCTAssertEqual(history.peopleSampleCount(campusID: "shxq", weekday: weekday, hour: 9, before: before), 1)
    let forecast = try XCTUnwrap(history.peopleForecast(campusID: "xylxq", weekday: weekday, hour: 9, before: before))
    XCTAssertEqual(forecast.sampleCount, 3)
    XCTAssertEqual(forecast.estimatedPeople, 233)
    let trend = history.peopleTrend(campusID: "xylxq", weekday: weekday, before: before)
    XCTAssertEqual(trend.map(\.hour), [9])
    XCTAssertEqual(trend.first?.averagePeople ?? 0, 700.0 / 3.0, accuracy: 0.0001)
  }

  private func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
  }
}

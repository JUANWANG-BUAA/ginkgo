import Foundation
import XCTest
@testable import BUAA_Assistant

final class ScheduleParserTests: XCTestCase {
  func testUndergraduateTermsWeeksAndCourses() throws {
    let terms = try ScheduleParser.terms(Data(#"{"code":"0","datas":[{"itemCode":"2025-2026-1","itemName":"第一学期","selected":true}]}"#.utf8), portal: .undergraduate)
    XCTAssertEqual(terms.first?.id, "2025-2026-1")
    XCTAssertEqual(terms.first?.isSelected, true)

    let weeks = try ScheduleParser.weeks(Data(#"{"code":"0","datas":[{"serialNumber":"10","startDate":"2025-10-06","endDate":"2025-10-12","curWeek":true}]}"#.utf8))
    XCTAssertEqual(weeks.first?.number, 10)
    XCTAssertEqual(weeks.first?.isCurrent, true)

    let courses = try ScheduleParser.undergraduateCourses(Data(#"{"code":"0","datas":{"code":"sy2501001","arrangedList":[{"courseName":"算法设计","dayOfWeek":2,"beginSection":3,"endSection":4,"beginTime":"10:00","endTime":"11:35","placeName":"主楼","credit":"4.0"}]}}"#.utf8))
    XCTAssertEqual(courses.count, 1)
    XCTAssertEqual(courses[0].day, 2)
    XCTAssertEqual(courses[0].place, "主楼")
  }

  func testGraduateBitmapFiltersAlternatingWeeksAndDerivesMonday() throws {
    let json = #"{"code":"1","jgList":[{"BJDM":"A","XNXQDM":"20251","KCMC":"研究方法","XQ":3,"KSJCDM":1,"JSJCDM":2,"ZCBH":"1010","JASMC":"教室"}],"rwList":[{"BJDM":"A","XNXQDM":"20251","SCSKRQ":"2025-09-03"}],"jcfaList":[]}"#
    let data = Data(json.utf8)
    let weeks = try ScheduleParser.graduateWeeks(data, termID: "20251")
    XCTAssertEqual(weeks.count, 4)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    XCTAssertEqual(calendar.component(.day, from: weeks[0].start), 1)
    XCTAssertEqual(calendar.component(.weekday, from: weeks[0].start), 2)
    XCTAssertEqual(try ScheduleParser.graduateCourses(data, termID: "20251", week: 1).count, 1)
    XCTAssertEqual(try ScheduleParser.graduateCourses(data, termID: "20251", week: 2).count, 0)
    XCTAssertEqual(try ScheduleParser.graduateCourses(data, termID: "20251", week: 3).count, 1)
  }

  func testGraduateInconsistentStartIsRejected() throws {
    let json = #"{"code":"1","jgList":[{"BJDM":"A","XNXQDM":"20251","XQ":3,"ZCBH":"10"},{"BJDM":"B","XNXQDM":"20251","XQ":4,"ZCBH":"10"}],"rwList":[{"BJDM":"A","XNXQDM":"20251","SCSKRQ":"2025-09-03"},{"BJDM":"B","XNXQDM":"20251","SCSKRQ":"2025-09-11"}],"jcfaList":[]}"#
    XCTAssertThrowsError(try ScheduleParser.graduateWeeks(Data(json.utf8), termID: "20251"))
  }

  func testGraduateFirstClassDateUsesEarliestMeetingOfSameClass() throws {
    let json = #"{"code":"1","jgList":[{"BJDM":"A","XNXQDM":"20251","XQ":3,"ZCBH":"11"},{"BJDM":"A","XNXQDM":"20251","XQ":5,"ZCBH":"11"}],"rwList":[{"BJDM":"A","XNXQDM":"20251","SCSKRQ":"2025-09-03"}],"jcfaList":[]}"#
    let weeks = try ScheduleParser.graduateWeeks(Data(json.utf8), termID: "20251")
    XCTAssertEqual(weeks.count, 2)
  }

  func testGraduateMeetingCanOmitTermCode() throws {
    let json = #"{"code":"1","jgList":[{"BJDM":"A","KCMC":"研究方法","XQ":"3","KSJCDM":"1","JSJCDM":"2","ZCBH":"1"}],"rwList":[],"jcfaList":[]}"#
    XCTAssertEqual(try ScheduleParser.graduateCourses(Data(json.utf8), termID: "20251", week: 1).first?.name, "研究方法")
  }

  func testGraduateAdjacentSectionsAreOneCourse() throws {
    let json = #"{"code":"1","jgList":[{"BJDM":"A","KCMC":"矩阵理论","XQ":4,"KSJCDM":6,"JSJCDM":6,"ZCBH":"1","JASMC":"主楼"},{"BJDM":"A","KCMC":"矩阵理论","XQ":4,"KSJCDM":7,"JSJCDM":7,"ZCBH":"1","JASMC":"主楼"}],"rwList":[],"jcfaList":[]}"#
    let courses = try ScheduleParser.graduateCourses(Data(json.utf8), termID: "20251", week: 1)
    XCTAssertEqual(courses.count, 1)
    XCTAssertEqual(courses[0].startSection, 6)
    XCTAssertEqual(courses[0].endSection, 7)
  }

  func testInvalidBusinessCodeIsRejected() {
    XCTAssertThrowsError(try ScheduleParser.undergraduateCourses(Data(#"{"code":"1","datas":{"arrangedList":[]}}"#.utf8)))
  }
}

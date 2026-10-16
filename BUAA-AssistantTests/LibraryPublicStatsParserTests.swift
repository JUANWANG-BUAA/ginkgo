import Foundation
import XCTest
@testable import BUAA_Assistant

final class LibraryPublicStatsParserTests: XCTestCase {
  func testParsesCampusPeopleAndSeparatesFacilityCounts() throws {
    let html = #"""
    <div class="item"><div class="item-title"><img class="title" src="/engine2/assets/images/more/custom/t_xylxq.png" alt=""></div>
      <ul class="lists">
        <li class="clear"><span>图书馆</span><span class="num">741</span><span>人</span></li>
        <li class="clear"><span>预约座位</span><span>空闲</span><span>1817</span><span>座</span><span>/总计</span><span>2305</span><span>座</span></li>
        <li class="clear"><span>研讨间</span><span>空闲</span><span>5</span><span>间</span><span>/总计</span><span>16</span><span>间</span></li>
        <li class="clear"><span>寄存柜</span><span>空闲</span><span>395</span><span>个</span><span>/总计</span><span>477</span><span>个</span></li>
      </ul></div>
    <div class="item"><div class="item-title"><img class="title" src="/engine2/assets/images/more/custom/t_shxq.png" alt=""></div>
      <ul class="lists">
        <li class="clear"><span>图书馆</span><span class="num">384</span><span>人</span></li>
        <li class="clear"><span>特色阅览室B1</span><span class="num">3</span><span>人</span></li>
        <li class="clear"><span>特色阅览室B2</span><span class="num">10</span><span>人</span></li>
        <li class="clear"><span>研讨间</span><span>空闲</span><span>16</span><span>间</span><span>/总计</span><span>29</span><span>间</span></li>
        <li class="clear"><span>寄存柜</span><span>空闲</span><span>229</span><span>个</span><span>/总计</span><span>286</span><span>个</span></li>
      </ul></div>
    """#
    let fetchedAt = Date(timeIntervalSince1970: 1_792_000_000)

    let snapshot = try LibraryPublicStatsParser.parse(Data(html.utf8), fetchedAt: fetchedAt)

    XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
    XCTAssertEqual(snapshot.campuses.map(\.id), ["xylxq", "shxq"])
    XCTAssertEqual(snapshot.campuses[0].name, "学院路校区")
    XCTAssertEqual(snapshot.campuses[0].people, 741)
    XCTAssertEqual(snapshot.campuses[0].seats, LibraryCountPair(available: 1817, total: 2305))
    XCTAssertEqual(snapshot.campuses[0].studyRooms, LibraryCountPair(available: 5, total: 16))
    XCTAssertEqual(snapshot.campuses[0].lockers, LibraryCountPair(available: 395, total: 477))
    XCTAssertEqual(snapshot.campuses[1].people, 384)
    XCTAssertEqual(snapshot.campuses[1].readingRooms, [
      LibraryReadingRoomOccupancy(name: "特色阅览室B1", people: 3),
      LibraryReadingRoomOccupancy(name: "特色阅览室B2", people: 10)
    ])
    XCTAssertNil(snapshot.campuses[1].seats)
    XCTAssertEqual(snapshot.campuses[1].studyRooms, LibraryCountPair(available: 16, total: 29))
  }

  func testRejectsIncompleteOrUnrecognizedCampusPage() {
    let html = #"<img src="/engine2/assets/images/more/custom/t_xylxq.png"><ul><li>图书馆 12 人</li></ul>"#
    XCTAssertThrowsError(try LibraryPublicStatsParser.parse(Data(html.utf8)))
  }
}

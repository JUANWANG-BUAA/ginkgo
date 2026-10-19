import Foundation
import XCTest
@testable import BUAA_Assistant

final class CoreUtilitiesTests: XCTestCase {
  func testAESCipherECBRoundTrip() throws {
    let key = Array("abcdefghijk23456".utf8)
    let payload = Data(#"{"courseName":"示例课程","pageNumber":1}"#.utf8)
    let encrypted = try XCTUnwrap(AESCipher.encrypt(payload, key: key, mode: .ecb))
    XCTAssertNotEqual(encrypted, payload)
    XCTAssertEqual(AESCipher.decrypt(encrypted, key: key, mode: .ecb), payload)
    XCTAssertNil(AESCipher.encrypt(payload, key: Array("short".utf8), mode: .ecb))
  }

  func testSchoolTimeUsesBeijingDateRegardlessOfDeviceZone() throws {
    // 2026-10-18 16:30 UTC 是北京时间 10-19 00:30。
    let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-18T16:30:00Z"))
    XCTAssertEqual(SchoolTime.dayString(instant), "2026-10-19")
    XCTAssertEqual(SchoolTime.minutesSinceMidnight(instant), 30)
    XCTAssertEqual(SchoolTime.date(from: "2026-10-19 00:30", formats: ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"]), instant)
    XCTAssertNil(SchoolTime.date(from: "待定", formats: ["yyyy-MM-dd"]))
  }

  func testClockMinutesAcceptUpstreamTimeShapes() {
    XCTAssertEqual(SchoolTime.minutes(fromClock: "08:05"), 485)
    XCTAssertEqual(SchoolTime.minutes(fromClock: " 13：30 "), 810)
    XCTAssertEqual(SchoolTime.minutes(fromClock: "22:00:00"), 1320)
    XCTAssertEqual(SchoolTime.minutes(fromClock: "0930"), 570)
    XCTAssertNil(SchoolTime.minutes(fromClock: "24:00"))
    XCTAssertNil(SchoolTime.minutes(fromClock: "第1节"))
    XCTAssertNil(SchoolTime.minutes(fromClock: nil))
    XCTAssertEqual(SchoolTime.weekdayName(1), "周一")
    XCTAssertEqual(SchoolTime.weekdayName(7), "周日")
  }

  func testJSONValueNormalizesStringAndNumberFields() {
    XCTAssertEqual(JSONValue.string(NSNumber(value: 3)), "3")
    XCTAssertNil(JSONValue.string(NSNull()))
    XCTAssertNil(JSONValue.nonEmptyString("  "))
    XCTAssertEqual(JSONValue.nonEmptyString(" 课程 "), "课程")
    XCTAssertEqual(JSONValue.int("42"), 42)
    XCTAssertEqual(JSONValue.int(NSNumber(value: 7)), 7)
    XCTAssertNil(JSONValue.int("4.5"))
    XCTAssertEqual(JSONValue.double("4.5"), 4.5)
    XCTAssertEqual(JSONValue.bool("YES"), true)
    XCTAssertEqual(JSONValue.bool("0"), false)
    XCTAssertNil(JSONValue.bool([1]))
  }

  func testHTMLEntitiesDecodeOnceAndStripMarkup() {
    XCTAssertEqual(HTMLText.decodeEntities("&amp;lt;b&amp;gt; &#x4E2D;&#25991; &quot;x&quot;"), "&lt;b&gt; 中文 \"x\"")
    XCTAssertEqual(
      HTMLText.plainText("<div>第一&nbsp;行<script>var a = '<b>';</script>\n  <b>第二</b></div>"),
      "第一 行 第二"
    )
    XCTAssertEqual(HTMLText.multilineText("<p>第一题&nbsp;完成</p><p>第二题 &amp; 附图<br>续行</p>"), "第一题 完成\n第二题 & 附图\n续行")
    XCTAssertNil(HTMLText.multilineText("<p> </p>"))
  }

  func testFormEncodingEscapesEverythingOutsideUnreservedSet() {
    XCTAssertEqual(
      FormURLEncoding.encode([("execution", "a+b/c=d"), ("name", "研讨 室"), ("safe", "A-z_0.9~")]),
      "execution=a%2Bb%2Fc%3Dd&name=%E7%A0%94%E8%AE%A8%20%E5%AE%A4&safe=A-z_0.9~"
    )
  }

  func testLocalStoreIsolatesAccountsAndIgnoresUnreadableFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = LocalStore(module: "Unused", directory: directory)

    try store.write(["value": 1], account: "sy2501001")
    XCTAssertEqual(store.read([String: Int].self, account: "sy2501001"), ["value": 1])
    XCTAssertNil(store.read([String: Int].self, account: "sy2501002"))
    XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path)
      .contains { $0.contains("sy2501001") })

    try Data("not json".utf8).write(to: directory.appendingPathComponent("broken.json"))
    XCTAssertNil(store.read([String: Int].self, name: "broken"))

    try store.remove(account: "sy2501001")
    try store.remove(account: "sy2501001")
    XCTAssertNil(store.read([String: Int].self, account: "sy2501001"))
  }
}

import Foundation
import XCTest
@testable import BUAA_Assistant

final class CasFormParserTests: XCTestCase {
  func test_loginFields_preservesHiddenAndCheckedInputs() {
    let html = #"""
    <input value="part+two/three" name="execution" type="hidden">
    <input type='hidden' name='extra' value='A&amp;B'>
    <input type="checkbox" name="agree" value="yes" checked>
    <input type="checkbox" name="optional" value="no">
    <input type="hidden" name="_eventId" value="submit">
    <input type="hidden" name="type" value="username_password">
    """#
    let fields = CasFormParser.loginFields(
      html: html, username: "sy2501001", password: "p+a&b", captchaText: "12 34"
    )
    let values = Dictionary(fields, uniquingKeysWith: { _, last in last })
    XCTAssertEqual(values["execution"], "part+two/three")
    XCTAssertEqual(values["extra"], "A&B")
    XCTAssertEqual(values["agree"], "yes")
    XCTAssertNil(values["optional"])
    XCTAssertEqual(values["captcha"], "12 34")
    XCTAssertEqual(values["captchaResponse"], "12 34")
    XCTAssertEqual(values["password"], "p+a&b")
    let body = String(decoding: FormURLEncoding.body(fields), as: UTF8.self)
    XCTAssertTrue(body.contains("execution=part%2Btwo%2Fthree"))
    XCTAssertTrue(body.contains("password=p%2Ba%26b"))
    XCTAssertTrue(body.contains("captcha=12%2034"))
  }

  func test_loginFields_addsRequiredDefaults() {
    let fields = CasFormParser.loginFields(html: "", username: "sy2501001", password: "test", captchaText: nil)
    let values = Dictionary(fields, uniquingKeysWith: { _, last in last })
    XCTAssertEqual(values["_eventId"], "submit")
    XCTAssertEqual(values["type"], "username_password")
    XCTAssertEqual(values["submit"], "登录")
    XCTAssertNil(values["captcha"])
  }
}

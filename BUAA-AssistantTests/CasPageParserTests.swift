import XCTest
@testable import BUAA_Assistant

/// CAS 登录页解析测试（API.md §1.2 / §1.3 / §1.5）。
/// HTML 样本为合成结构，与上游真实页面结构对齐（对照 UBAA LocalCasParser 的正则语义）。
final class CasPageParserTests: XCTestCase {

  // MARK: - execution 提取（API.md §1.2）

  func test_extractExecution_withDoubleQuotedInput_shouldReturnToken() {
    let html = #"""
    <form action="/login" method="post">
      <input type="hidden" name="execution" value="60569136-414e-46d2-87b1-example"/>
    </form>
    """#
    XCTAssertEqual(
      CasPageParser.extractExecution(from: html),
      "60569136-414e-46d2-87b1-example"
    )
  }

  func test_extractLoginFormAction_keepsWebVPNSerivceQuery() {
    let html = #"<form action="/https/encoded-sso/login?service=https%3A%2F%2Fd.buaa.edu.cn%2Flogin" method="post">"#
    XCTAssertEqual(
      CasPageParser.extractLoginFormAction(from: html),
      "/https/encoded-sso/login?service=https%3A%2F%2Fd.buaa.edu.cn%2Flogin"
    )
  }

  func test_extractExecution_withSingleQuotedInput_shouldReturnToken() {
    let html = #"<input type='hidden' name='execution' value='abc-123'/>"#
    XCTAssertEqual(CasPageParser.extractExecution(from: html), "abc-123")
  }

  func test_extractExecution_withMissingInput_shouldReturnNil() {
    XCTAssertNil(CasPageParser.extractExecution(from: "<html><body>普通页面</body></html>"))
  }

  func test_extractExecution_withEmptyPage_shouldReturnNil() {
    XCTAssertNil(CasPageParser.extractExecution(from: ""))
  }

  // MARK: - 验证码检测（API.md §1.3）

  func test_detectCaptcha_withConfigScript_shouldReturnChallenge() {
    let html = #"""
    <script>
      var config = { some: true };
      config.captcha = { type: 'local', id: 'cap-123' };
    </script>
    """#
    let captcha = CasPageParser.detectCaptcha(from: html)
    XCTAssertEqual(captcha?.type, "local")
    XCTAssertEqual(captcha?.id, "cap-123")
    XCTAssertEqual(captcha?.imageURL.absoluteString, "https://sso.buaa.edu.cn/captcha?captchaId=cap-123")
  }

  func test_detectCaptcha_withoutConfig_shouldReturnNil() {
    let html = "<html><body>无验证码的登录页</body></html>"
    XCTAssertNil(CasPageParser.detectCaptcha(from: html))
  }

  // MARK: - 预登录提示（API.md §1.2）

  func test_extractTipText_withTipDiv_shouldReturnStrippedText() {
    let html = #"<div class="tip-text">账号已锁定，请 30 分钟后重试</div>"#
    XCTAssertEqual(CasPageParser.extractTipText(from: html), "账号已锁定，请 30 分钟后重试")
  }

  func test_extractTipText_withInnerTags_shouldStripHtml() {
    let html = #"<div class='tip-text'>密码错误 <b>5</b> 次</div>"#
    XCTAssertEqual(CasPageParser.extractTipText(from: html), "密码错误 5 次")
  }

  func test_extractTipText_absent_shouldReturnNil() {
    XCTAssertNil(CasPageParser.extractTipText(from: "<html></html>"))
  }

  func test_extractErrorText_withErrorDiv_shouldReturnMessage() {
    let html = #"<div id="errorDiv"><span>账号或密码错误</span></div>"#
    XCTAssertEqual(CasPageParser.extractErrorText(from: html), "账号或密码错误")
  }

  func test_extractErrorText_withErrorsClass_shouldReturnMessage() {
    let html = #"<div class="alert errors">验证码错误</div>"#
    XCTAssertEqual(CasPageParser.extractErrorText(from: html), "验证码错误")
  }

  // MARK: - 密码过期跳过页（API.md §1.5）

  func test_isPasswordExpiryPage_withContinueForm_shouldBeTrue() {
    let html = #"""
    <input type="hidden" name="execution" value="e-2"/>
    <form name="continueForm"><button id="ignoreAndContinue">继续</button></form>
    """#
    XCTAssertTrue(CasPageParser.isPasswordExpiryPage(html))
  }

  func test_isPasswordExpiryPage_withKeyword_shouldBeTrue() {
    let html = #"<input name="execution" value="e-3"/><div>密码过期提示</div>"#
    XCTAssertTrue(CasPageParser.isPasswordExpiryPage(html))
  }

  func test_isPasswordExpiryPage_withoutExecution_shouldBeFalse() {
    // 有关键词但没有 execution → 不是 CAS 流程页，不能当跳过页处理
    let html = "<div>密码过期</div>"
    XCTAssertFalse(CasPageParser.isPasswordExpiryPage(html))
  }

  func test_isAccessPolicyDenied_withUcWafPage_shouldBeTrue() {
    let html = "访问出错 - 403 出错啦！访问策略禁止您访问该网站，可能的原因为 您(IP：192.0.2.1)，没有权限访问相应的资源"
    XCTAssertTrue(CasPageParser.isAccessPolicyDenied(html))
  }

  func test_isAccessPolicyDenied_withNormalForbiddenPage_shouldBeFalse() {
    XCTAssertFalse(CasPageParser.isAccessPolicyDenied("<h1>403 Forbidden</h1>"))
  }

  func test_isPasswordExpiryPage_normalLogin_shouldBeFalse() {
    let html = #"<input type="hidden" name="execution" value="e-1"/>"#
    XCTAssertFalse(CasPageParser.isPasswordExpiryPage(html))
  }
}

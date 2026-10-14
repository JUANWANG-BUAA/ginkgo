import Foundation

/// 验证码挑战（API.md §1.3）：type/id 来自登录页 config.captcha，
/// imageURL 为图片端点。
struct CaptchaChallenge: Equatable {
  let type: String
  let id: String
  let imageURL: URL
}

/// CAS 登录页 HTML 解析（API.md §1.2）。
/// 正则与判定逻辑逐条对照 UBAA `LocalCasParser`（LocalConnectionAuth.kt:820-880）移植。
///
/// 这是本项目第一个「真实逻辑」模块：纯函数、可直接单元测试，
/// 作为后续所有解析器的样板（先写测试 → 再写实现 → 快照回归）。
enum CasPageParser {
  // 模式串为编译期常量，语法非法即程序错误，try! 直接崩溃暴露。
  private static let executionRegex = try! NSRegularExpression(
    pattern: #"<input[^>]*name=["']execution["'][^>]*value=["']([^"']+)["'][^>]*>"#,
    options: [.caseInsensitive]
  )
  private static let captchaRegex = try! NSRegularExpression(
    pattern: #"config\.captcha\s*=\s*\{\s*type:\s*['"]([^'"]+)['"],\s*id:\s*['"]([^'"]+)['"]"#,
    options: []
  )
  private static let tipRegex = try! NSRegularExpression(
    pattern: #"<div[^>]*class=["'][^"']*tip-text[^"']*["'][^>]*>([\s\S]*?)</div>"#,
    options: [.caseInsensitive]
  )

  /// 提取登录页的 execution 隐藏字段。缺失返回 nil（该页面不是登录页或结构已变）。
  static func extractExecution(from html: String) -> String? {
    firstMatch(executionRegex, in: html, group: 1)
  }

  /// 检测验证码配置。返回 nil 表示本页无需验证码。
  /// 图片地址固定为 `https://sso.buaa.edu.cn/captcha?captchaId=<id>`（API.md §1.3）。
  static func detectCaptcha(from html: String) -> CaptchaChallenge? {
    guard let type = firstMatch(captchaRegex, in: html, group: 1),
          let id = firstMatch(captchaRegex, in: html, group: 2)
    else { return nil }
    guard let url = URL(string: "https://sso.buaa.edu.cn/captcha?captchaId=\(id)") else {
      return nil
    }
    return CaptchaChallenge(type: type, id: id, imageURL: url)
  }

  /// 提取预登录提示（如「账号已锁定」）。有提示时登录流程应直接终止并展示。
  static func extractTipText(from html: String) -> String? {
    let stripped = firstMatch(tipRegex, in: html, group: 1)?
      .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      ?? ""
    // 去标签会留下连续空格，折叠为单个空格便于展示。
    let collapsed = stripped
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return collapsed.nilIfBlank
  }

  /// 「密码过期 / 账号存在安全风险」跳过页判定（API.md §1.5）。
  /// 必须同时存在 execution（说明仍是 CAS 流程页）才算。
  static func isPasswordExpiryPage(_ html: String) -> Bool {
    guard extractExecution(from: html) != nil else { return false }
    return html.contains("continueForm")
      || html.contains("ignoreAndContinue")
      || html.contains("账号存在安全风险")
      || html.contains("密码过期")
  }

  // MARK: - 私有

  private static func firstMatch(
    _ regex: NSRegularExpression, in text: String, group: Int
  ) -> String? {
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range),
          match.numberOfRanges > group,
          let groupRange = Range(match.range(at: group), in: text)
    else { return nil }
    return String(text[groupRange])
  }
}

private extension String {
  var nilIfBlank: String? {
    isEmpty ? nil : self
  }
}

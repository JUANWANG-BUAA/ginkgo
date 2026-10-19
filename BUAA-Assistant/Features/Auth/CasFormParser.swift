import Foundation

/// 从刚获取的 CAS 页面构建表单（API.md §1.4）。
enum CasFormParser {
  private static let inputPattern = try! NSRegularExpression(
    pattern: #"<input\b[^>]*>"#, options: [.caseInsensitive]
  )
  private static let attributePattern = try! NSRegularExpression(
    pattern: #"([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#,
    options: [.caseInsensitive]
  )

  static func loginFields(
    html: String, username: String, password: String, captchaText: String?
  ) -> [(String, String)] {
    var fields: [(String, String)] = []
    let range = NSRange(html.startIndex..., in: html)
    for match in inputPattern.matches(in: html, range: range) {
      guard let tagRange = Range(match.range, in: html) else { continue }
      let tag = String(html[tagRange])
      let attributes = parseAttributes(tag)
      guard let name = attributes["name"], !name.isEmpty else { continue }
      let type = attributes["type"]?.lowercased() ?? "text"
      if type == "hidden" || (type == "checkbox" && tag.range(of: #"\bchecked\b"#, options: [.regularExpression, .caseInsensitive]) != nil) {
        fields.append((name, HTMLText.decodeEntities(attributes["value"] ?? "")))
      }
    }
    set("username", username, in: &fields)
    set("password", password, in: &fields)
    set("submit", "登录", in: &fields)
    if !fields.contains(where: { $0.0 == "_eventId" }) { fields.append(("_eventId", "submit")) }
    if !fields.contains(where: { $0.0 == "type" }) { fields.append(("type", "username_password")) }
    if let captchaText, !captchaText.isEmpty {
      set("captcha", captchaText, in: &fields)
      set("captchaResponse", captchaText, in: &fields)
    }
    return fields
  }

  private static func set(_ key: String, _ value: String, in fields: inout [(String, String)]) {
    fields.removeAll { $0.0 == key }
    fields.append((key, value))
  }

  private static func parseAttributes(_ tag: String) -> [String: String] {
    var result: [String: String] = [:]
    let range = NSRange(tag.startIndex..., in: tag)
    for match in attributePattern.matches(in: tag, range: range) {
      guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
      let valueRange = (2...4).compactMap { Range(match.range(at: $0), in: tag) }.first
      result[String(tag[keyRange]).lowercased()] = valueRange.map { String(tag[$0]) } ?? ""
    }
    return result
  }
}

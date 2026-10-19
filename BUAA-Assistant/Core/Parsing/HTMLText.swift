import Foundation

/// 上游 HTML 片段转可显示文本。页面不保证规范，只处理项目实际遇到的标签与实体。
enum HTMLText {
  private static let namedEntities: [(String, String)] = [
    ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")
  ]
  private static let numericEntity = try! NSRegularExpression(pattern: #"&#(?:[xX]([0-9a-fA-F]+)|(\d+));"#)

  /// 解码命名实体与数字实体；`&amp;` 最后处理，避免 `&amp;lt;` 被二次解码成 `<`。
  static func decodeEntities(_ text: String) -> String {
    guard text.contains("&") else { return text }
    var result = namedEntities.reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    let source = result as NSString
    for match in numericEntity.matches(in: result, range: NSRange(location: 0, length: source.length)).reversed() {
      let isHex = match.range(at: 1).location != NSNotFound
      let digits = source.substring(with: match.range(at: isHex ? 1 : 2))
      guard let value = UInt32(digits, radix: isHex ? 16 : 10), let scalar = UnicodeScalar(value) else { continue }
      result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
    }
    return result.replacingOccurrences(of: "&amp;", with: "&")
  }

  /// 单行文本：去掉脚本与标签、解码实体，并把所有空白折叠为单个空格。
  static func plainText(_ html: String) -> String {
    decodeEntities(strippingTags(html))
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  /// 多行正文：块级元素结束与 `<br>` 保留为换行，每行折叠空白并去掉空行；无内容时为 nil。
  static func multilineText(_ html: String) -> String? {
    let withBreaks = html.replacingOccurrences(
      of: #"<br\s*/?>|</(?:p|div|li|tr|h[1-6])\s*>"#,
      with: "\n",
      options: [.regularExpression, .caseInsensitive]
    )
    let lines = decodeEntities(strippingTags(withBreaks))
      .components(separatedBy: .newlines)
      .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
      .filter { !$0.isEmpty }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
  }

  private static func strippingTags(_ html: String) -> String {
    html.replacingOccurrences(
      of: #"<(script|style)\b[\s\S]*?</\1\s*>"#,
      with: " ",
      options: [.regularExpression, .caseInsensitive]
    )
    .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
  }
}

import Foundation

/// `application/x-www-form-urlencoded` 编码：只保留 RFC 3986 非保留字符，其余（空格、`+`、中文等）
/// 一律百分号编码，避免 `execution` 里的 `+` 被服务器读成空格（API.md §1.4）。
enum FormURLEncoding {
  private static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  )

  /// 按传入顺序编码；字段顺序由调用方决定（部分上游的签名要求固定顺序）。
  static func encode(_ fields: [(String, String)]) -> String {
    fields.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&")
  }

  static func body(_ fields: [(String, String)]) -> Data {
    Data(encode(fields).utf8)
  }

  static func escape(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
  }
}

import Foundation

/// `JSONSerialization` 结果的宽松取值。同一字段在不同系统/版本里可能是字符串或数字
/// （API.md 附录 C），这里只做类型归一；必填、取值范围与成功码判定仍由各解析器自己负责。
enum JSONValue {
  /// String 原样返回；NSNumber 转十进制文本；其余（含 NSNull）为 nil。
  static func string(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value.stringValue }
    return nil
  }

  /// 去除首尾空白后非空的文本。
  static func nonEmptyString(_ value: Any?) -> String? {
    guard let text = string(value)?.trimmingCharacters(in: .whitespacesAndNewlines),
          text.isEmpty == false else { return nil }
    return text
  }

  static func int(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) }
    return nil
  }

  static func int64(_ value: Any?) -> Int64? {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    if let value = value as? String { return Int64(value) }
    return nil
  }

  static func double(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) }
    return nil
  }

  /// 布尔、数字或 `1/true/yes` 文本；其他文本为 false，非标量类型为 nil。
  static func bool(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.boolValue }
    if let value = value as? String { return ["1", "true", "yes"].contains(value.lowercased()) }
    return nil
  }
}

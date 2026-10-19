import Foundation

/// 北航上游统一使用北京时间。日期解析、按天分组与“今天/本周”判断都必须绑定学校时区，
/// 并固定公历与 POSIX 区域，不能跟随设备时区或地区日历（例如佛历会让 `yyyy` 年份错位）。
enum SchoolTime {
  static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

  /// 公历、周一为一周首日。
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = 2
    return calendar
  }()

  /// 固定格式的日期格式器。
  static func formatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = calendar
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter
  }

  static func string(from date: Date, format: String) -> String {
    formatter(format).string(from: date)
  }

  /// 依次尝试各格式，返回第一个能完整解析的结果。
  static func date(from text: String, formats: [String]) -> Date? {
    let formatter = formatter(formats.first ?? "")
    for format in formats {
      formatter.dateFormat = format
      if let date = formatter.date(from: text) { return date }
    }
    return nil
  }

  /// 学校日期 `yyyy-MM-dd`。
  static func dayString(_ date: Date = Date()) -> String {
    string(from: date, format: "yyyy-MM-dd")
  }

  /// 当天 0 点起算的分钟数。
  static func minutesSinceMidnight(_ date: Date = Date()) -> Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }

  /// 解析 `HH:mm`、`HH:mm:ss`、全角冒号或紧凑的 `HHmm`，返回当天分钟数。
  static func minutes(fromClock text: String?) -> Int? {
    guard let text else { return nil }
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "：", with: ":")
    let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
    let hour: Int
    let minute: Int
    if parts.count >= 2, let parsedHour = Int(parts[0]), let parsedMinute = Int(parts[1].prefix(2)) {
      hour = parsedHour
      minute = parsedMinute
    } else if parts.count == 1, (3...4).contains(normalized.count), let compact = Int(normalized) {
      hour = compact / 100
      minute = compact % 100
    } else {
      return nil
    }
    guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
    return hour * 60 + minute
  }

  /// `Calendar.component(.weekday)`：1 = 周日 … 7 = 周六。
  static func weekdayName(calendarWeekday: Int) -> String {
    weekdayName(calendarWeekday == 1 ? 7 : calendarWeekday - 1)
  }

  /// 课表约定 1 = 周一 … 7 = 周日。
  static func weekdayName(_ day: Int) -> String {
    let names = ["一", "二", "三", "四", "五", "六", "日"]
    return names.indices.contains(day - 1) ? "周\(names[day - 1])" : "周?"
  }
}

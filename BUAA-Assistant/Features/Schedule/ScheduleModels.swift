import Foundation

enum SchedulePortal: String, Codable {
  case undergraduate, graduate
}

struct SchoolTerm: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let isSelected: Bool
}

struct SchoolWeek: Identifiable, Codable, Hashable {
  let number: Int
  let start: Date
  let end: Date
  let isCurrent: Bool
  var id: Int { number }
}

struct CourseMeeting: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let day: Int
  let startSection: Int
  let endSection: Int
  let startTime: String?
  let endTime: String?
  let place: String?
  let teacher: String?
  let color: String?
}

struct ScheduleSnapshot: Codable {
  let portal: SchedulePortal
  let terms: [SchoolTerm]
  let termID: String
  let weeks: [SchoolWeek]
  let weekNumber: Int
  let courses: [CourseMeeting]
  let fetchedAt: Date
  var termCourses: [String: [CourseMeeting]]? = nil

  func containsToday(now: Date = Date()) -> Bool {
    guard let week = weekContaining(now),
          let end = Self.schoolCalendar.date(byAdding: .day, value: 1, to: week.end) else { return false }
    return week.start <= now && now < end && (week.number == weekNumber || termCourses?[String(week.number)] != nil)
  }

  private func weekContaining(_ date: Date) -> SchoolWeek? {
    weeks.first { week in
      guard let end = Self.schoolCalendar.date(byAdding: .day, value: 1, to: Self.schoolCalendar.startOfDay(for: week.end)) else { return false }
      return week.start <= date && date < end
    }
  }

  func todayCourses(now: Date = Date()) -> [CourseMeeting] {
    guard containsToday(now: now) else { return [] }
    let weekday = Self.schoolCalendar.component(.weekday, from: now)
    let week = weekContaining(now)!
    let meetings = week.number == weekNumber ? courses : termCourses?[String(week.number)] ?? []
    return meetings.filter { $0.day == (weekday == 1 ? 7 : weekday - 1) }
      .sorted { $0.startSection < $1.startSection }
  }

  static var schoolCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    calendar.firstWeekday = 2
    return calendar
  }
}

enum ScheduleError: LocalizedError {
  case sessionExpired
  case unavailable(String)
  case changedResponse
  case changedResponseAt(String)
  case invalidTerm

  var errorDescription: String? {
    switch self {
    case .sessionExpired: "学校会话已过期，请重新登录"
    case .unavailable(let service): "\(service)暂时无法访问，请稍后重试"
    case .changedResponse: "学校课表数据格式已变化，请稍后重试"
    case .changedResponseAt(let step): "\(step)返回的数据无法识别，请稍后重试"
    case .invalidTerm: "学期信息无效，请重新选择学期"
    }
  }
}

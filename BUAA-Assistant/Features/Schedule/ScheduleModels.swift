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

struct Exam: Identifiable, Codable, Hashable {
  let courseName: String
  let courseNo: String?
  let examTimeDescription: String?
  let examDate: String?
  let startTime: String?
  let endTime: String?
  let examPlace: String?
  let examSeatNo: String?
  let week: Int?
  let examStatus: String?
  let examType: String?
  let taskId: String?

  var id: String { taskId ?? "\(courseNo ?? ""):\(examDate ?? ""):\(courseName)" }
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

  /// Selects a previously cached week without changing the set of known weeks.
  func selectingCachedWeek(_ week: Int) -> ScheduleSnapshot? {
    guard let courses = termCourses?[String(week)] else { return nil }
    return ScheduleSnapshot(
      portal: portal,
      terms: terms,
      termID: termID,
      weeks: weeks,
      weekNumber: week,
      courses: courses,
      fetchedAt: fetchedAt,
      termCourses: termCourses
    )
  }

  /// Retains known weeks when an upstream response only contains one week.
  /// A prior snapshot's displayed week is itself a known result even if its map is nil.
  func retainingKnownWeeks(from previous: ScheduleSnapshot?) -> ScheduleSnapshot {
    guard termCourses == nil else { return self }

    var knownWeeks: [String: [CourseMeeting]] = [:]
    if let previous, previous.termID == termID {
      knownWeeks = previous.termCourses ?? [:]
      knownWeeks[String(previous.weekNumber)] = previous.courses
    }
    knownWeeks[String(weekNumber)] = courses

    var result = self
    result.termCourses = knownWeeks
    return result
  }

  func containsToday(now: Date = Date()) -> Bool {
    guard let week = weekContaining(now),
          let end = SchoolTime.calendar.date(byAdding: .day, value: 1, to: week.end) else { return false }
    return week.start <= now && now < end && (week.number == weekNumber || termCourses?[String(week.number)] != nil)
  }

  private func weekContaining(_ date: Date) -> SchoolWeek? {
    weeks.first { week in
      guard let end = SchoolTime.calendar.date(byAdding: .day, value: 1, to: SchoolTime.calendar.startOfDay(for: week.end)) else { return false }
      return week.start <= date && date < end
    }
  }

  func todayCourses(now: Date = Date()) -> [CourseMeeting] {
    guard containsToday(now: now) else { return [] }
    let weekday = SchoolTime.calendar.component(.weekday, from: now)
    let week = weekContaining(now)!
    let meetings = week.number == weekNumber ? courses : termCourses?[String(week.number)] ?? []
    return meetings.filter { $0.day == (weekday == 1 ? 7 : weekday - 1) }
      .sorted { $0.startSection < $1.startSection }
  }
}

enum ScheduleError: LocalizedError {
  case sessionExpired
  case unsupportedPortal
  case unavailable(String)
  case changedResponse
  case changedResponseAt(String)
  case invalidTerm

  var errorDescription: String? {
    switch self {
    case .sessionExpired: "学校会话已过期，请重新登录"
    case .unsupportedPortal: "当前研究生教务门户不提供本科考试安排接口"
    case .unavailable(let service): "\(service)暂时不可用，请稍后重试"
    case .changedResponse: "学校服务返回的数据格式无法识别，接口可能已调整；请重试，若持续出现请反馈"
    case .changedResponseAt(let step): "\(step)返回的数据格式无法识别，接口可能已调整；请重试，若持续出现请反馈"
    case .invalidTerm: "学期信息无效，请重新选择学期"
    }
  }
}

typealias ScheduleCache = SnapshotCache<ScheduleSnapshot>

extension SnapshotCache where Value == ScheduleSnapshot {
  init(directory: URL? = nil) { self.init(module: "Schedules", directory: directory) }
}

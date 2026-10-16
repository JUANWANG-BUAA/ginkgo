import Foundation

enum ScheduleParser {
  private struct MeetingKey: Hashable {
    let name: String
    let day: Int
    let startSection: Int
    let endSection: Int
  }

  static func terms(_ data: Data, portal: SchedulePortal) throws -> [SchoolTerm] {
    let root = try object(data)
    guard string(root["code"]) == "0" else { throw ScheduleError.changedResponse }
    if portal == .undergraduate {
      guard let rows = root["datas"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
      return try rows.map { row in
        guard let code = row["itemCode"] as? String, !code.isEmpty,
              let name = row["itemName"] as? String else { throw ScheduleError.changedResponse }
        return SchoolTerm(id: code, name: name, isSelected: row["selected"] as? Bool ?? false)
      }
    }
    guard let datas = root["datas"] as? [String: Any],
          let table = datas["kfdxnxqcx"] as? [String: Any],
          let rows = table["rows"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    return try rows.map { row in
      guard let code = row["XNXQDM"] as? String, code.range(of: #"^\d{4}[123]$"#, options: .regularExpression) != nil,
            let name = row["XNXQDM_DISPLAY"] as? String else { throw ScheduleError.changedResponse }
      return SchoolTerm(id: code, name: name, isSelected: false)
    }.sorted { $0.id > $1.id }
  }

  static func weeks(_ data: Data) throws -> [SchoolWeek] {
    let root = try object(data)
    guard string(root["code"]) == "0", let rows = root["datas"] as? [[String: Any]] else {
      throw ScheduleError.changedResponse
    }
    return try rows.map { row in
      guard let number = integer(row["serialNumber"]), number > 0,
            let start = date(row["startDate"]), let end = date(row["endDate"]) else {
        throw ScheduleError.changedResponse
      }
      return SchoolWeek(number: number, start: start, end: end, isCurrent: row["curWeek"] as? Bool ?? false)
    }.sorted { $0.number < $1.number }
  }

  static func exams(_ data: Data) throws -> [Exam] {
    let root = try object(data)
    guard string(root["code"]) == "0", let rows = root["datas"] as? [[String: Any]] else {
      throw ScheduleError.changedResponseAt("考试安排")
    }
    return try rows.map { row in
      guard let courseName = row["courseName"] as? String, !courseName.isEmpty else {
        throw ScheduleError.changedResponseAt("考试安排")
      }
      return Exam(
        courseName: courseName,
        courseNo: string(row["courseNo"]),
        examTimeDescription: row["examTimeDescription"] as? String,
        examDate: row["examDate"] as? String,
        startTime: row["startTime"] as? String,
        endTime: row["endTime"] as? String,
        examPlace: row["examPlace"] as? String,
        examSeatNo: string(row["examSeatNo"]),
        week: integer(row["week"]),
        examStatus: string(row["examStatus"]),
        examType: row["examType"] as? String,
        taskId: string(row["taskId"])
      )
    }
    .sorted { left, right in
      let lhs = "\(left.examDate ?? "9999-99-99") \(left.startTime ?? "99:99")"
      let rhs = "\(right.examDate ?? "9999-99-99") \(right.startTime ?? "99:99")"
      return lhs == rhs ? left.courseName.localizedStandardCompare(right.courseName) == .orderedAscending : lhs < rhs
    }
  }

  static func undergraduateCourses(_ data: Data) throws -> [CourseMeeting] {
    let root = try object(data)
    guard string(root["code"]) == "0", let datas = root["datas"] as? [String: Any],
          let rows = datas["arrangedList"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    let meetings = try rows.enumerated().map { index, row in
      guard let name = row["courseName"] as? String, !name.isEmpty,
            let day = integer(row["dayOfWeek"]), (1...7).contains(day),
            let start = integer(row["beginSection"]), let end = integer(row["endSection"]), start <= end else {
        throw ScheduleError.changedResponse
      }
      return CourseMeeting(id: "u-\(index)-\(day)-\(start)", name: name, day: day,
                           startSection: start, endSection: end,
                           startTime: row["beginTime"] as? String, endTime: row["endTime"] as? String,
                           place: row["placeName"] as? String, teacher: row["weeksAndTeachers"] as? String,
                           color: row["color"] as? String)
    }
    return mergeAdjacent(uniqueMeetings(meetings).sorted(by: meetingOrder))
  }

  static func graduateCourses(_ data: Data, termID: String, week: Int) throws -> [CourseMeeting] {
    let root = try object(data)
    guard string(root["code"]) == "1", let rows = root["jgList"] as? [[String: Any]] else {
      throw ScheduleError.changedResponse
    }
    let slots = (root["jcfaList"] as? [[String: Any]] ?? []).flatMap { $0["skjcList"] as? [[String: Any]] ?? [] }
    let meetings: [CourseMeeting] = try rows.enumerated().compactMap { index, row -> CourseMeeting? in
      guard let bitmap = row["ZCBH"] as? String,
            bitmap.allSatisfy({ $0 == "0" || $0 == "1" }), week > 0 else {
        throw ScheduleError.changedResponse
      }
      guard week <= bitmap.count, Array(bitmap)[week - 1] == "1" else { return nil }
      guard let name = row["KCMC"] as? String, !name.isEmpty,
            let day = integer(row["XQ"]), (1...7).contains(day),
            let start = integer(row["KSJCDM"]), let end = integer(row["JSJCDM"]), start <= end else {
        throw ScheduleError.changedResponse
      }
      return CourseMeeting(id: "g-\(index)-\(day)-\(start)", name: name, day: day,
                           startSection: start, endSection: end,
                           startTime: slotTime(slots, scheme: row["JCFADM"] as? String, section: start, key: "KSSJ"),
                           endTime: slotTime(slots, scheme: row["JCFADM"] as? String, section: end, key: "JSSJ"),
                           place: row["JASMC"] as? String, teacher: row["JGJSXM"] as? String, color: nil)
    }
    return mergeAdjacent(uniqueMeetings(meetings).sorted(by: meetingOrder))
  }

  static func graduateWeeks(_ data: Data, termID: String) throws -> [SchoolWeek] {
    let root = try object(data)
    guard string(root["code"]) == "1", let rows = root["jgList"] as? [[String: Any]],
          let tasks = root["rwList"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    // API.md §3.3：SCSKRQ 属于教学班，须取该班所有排课中的最早周/星期偏移。
    let candidates: [Date] = tasks.compactMap { task in
      guard task["XNXQDM"] as? String == termID,
            let classID = task["BJDM"] as? String,
            let firstDate = date(task["SCSKRQ"]) else { return nil }
      let offsets = rows.filter { $0["BJDM"] as? String == classID }.compactMap { row -> Int? in
        guard let day = integer(row["XQ"]), (1...7).contains(day),
              let bitmap = row["ZCBH"] as? String,
              let first = bitmap.firstIndex(of: "1") else { return nil }
        return bitmap.distance(from: bitmap.startIndex, to: first) * 7 + day - 1
      }
      guard let offset = offsets.min() else { return nil }
      return calendar.date(byAdding: .day, value: -offset, to: firstDate)
    }
    guard let start = candidates.first, candidates.allSatisfy({ calendar.isDate($0, inSameDayAs: start) }),
          calendar.component(.weekday, from: start) == 2 else { throw ScheduleError.changedResponse }
    let count = rows.compactMap { $0["ZCBH"] as? String }.map(\.count).max() ?? 0
    guard count > 0 else { throw ScheduleError.changedResponse }
    return (1...count).compactMap { number in
      guard let first = calendar.date(byAdding: .day, value: (number - 1) * 7, to: start),
            let last = calendar.date(byAdding: .day, value: 6, to: first) else { return nil }
      let current = calendar.dateInterval(of: .weekOfYear, for: Date()).map { $0.contains(first) } ?? false
      return SchoolWeek(number: number, start: first, end: last, isCurrent: current)
    }
  }

  private static func object(_ data: Data) throws -> [String: Any] {
    guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ScheduleError.changedResponse
    }
    return value
  }

  private static func string(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value.stringValue }
    return nil
  }

  private static func integer(_ value: Any?) -> Int? { string(value).flatMap(Int.init) }

  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    calendar.firstWeekday = 2
    return calendar
  }()

  private static func date(_ value: Any?) -> Date? {
    guard let raw = value as? String else { return nil }
    let prefix = String(raw.prefix(10))
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: prefix)
  }

  private static func meetingOrder(_ lhs: CourseMeeting, _ rhs: CourseMeeting) -> Bool {
    lhs.day == rhs.day ? lhs.startSection < rhs.startSection : lhs.day < rhs.day
  }

  private static func uniqueMeetings(_ meetings: [CourseMeeting]) -> [CourseMeeting] {
    var positions: [MeetingKey: Int] = [:]
    var result: [CourseMeeting] = []

    for meeting in meetings {
      let key = MeetingKey(
        name: normalizedCourseName(meeting.name),
        day: meeting.day,
        startSection: meeting.startSection,
        endSection: meeting.endSection
      )
      if let index = positions[key] {
        let existing = result[index]
        result[index] = CourseMeeting(
          id: existing.id,
          name: existing.name,
          day: existing.day,
          startSection: existing.startSection,
          endSection: existing.endSection,
          startTime: existing.startTime ?? meeting.startTime,
          endTime: existing.endTime ?? meeting.endTime,
          place: existing.place ?? meeting.place,
          teacher: existing.teacher ?? meeting.teacher,
          color: existing.color ?? meeting.color
        )
      } else {
        positions[key] = result.count
        result.append(meeting)
      }
    }

    return result
  }

  private static func normalizedCourseName(_ name: String) -> String {
    let normalized = name.precomposedStringWithCanonicalMapping
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
      .lowercased()
    return normalized.isEmpty ? name : normalized
  }

  private static func mergeAdjacent(_ meetings: [CourseMeeting]) -> [CourseMeeting] {
    var result: [CourseMeeting] = []
    for meeting in meetings {
      if let previous = result.last,
         previous.day == meeting.day,
         normalizedCourseName(previous.name) == normalizedCourseName(meeting.name),
         compatible(previous.place, meeting.place),
         previous.endSection + 1 == meeting.startSection {
        result[result.count - 1] = CourseMeeting(id: previous.id, name: previous.name, day: previous.day,
                                                  startSection: previous.startSection, endSection: meeting.endSection,
                                                  startTime: previous.startTime ?? meeting.startTime,
                                                  endTime: meeting.endTime ?? previous.endTime,
                                                  place: nonEmpty(previous.place) ?? meeting.place,
                                                  teacher: mergedTeacher(previous.teacher, meeting.teacher),
                                                  color: previous.color ?? meeting.color)
      } else {
        result.append(meeting)
      }
    }
    return result
  }

  private static func compatible(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs = nonEmpty(lhs), let rhs = nonEmpty(rhs) else { return true }
    return normalizedCourseName(lhs) == normalizedCourseName(rhs)
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func mergedTeacher(_ lhs: String?, _ rhs: String?) -> String? {
    let left = nonEmpty(lhs)
    let right = nonEmpty(rhs)
    switch (left, right) {
    case let (left?, right?) where normalizedCourseName(left) != normalizedCourseName(right):
      return "\(left) / \(right)"
    case let (left?, _): return left
    case let (_, right?): return right
    default: return nil
    }
  }

  private static func slotTime(_ slots: [[String: Any]], scheme: String?, section: Int, key: String) -> String? {
    guard let scheme, let slot = slots.first(where: {
      $0["JCFADM"] as? String == scheme && integer($0["DM"]) == section
    }), let value = integer(slot[key]), (0...2359).contains(value), value % 100 < 60 else { return nil }
    return String(format: "%02d:%02d", value / 100, value % 100)
  }
}

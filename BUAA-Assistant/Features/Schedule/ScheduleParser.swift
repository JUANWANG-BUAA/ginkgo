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
    guard let code = string(root["code"]) else { throw ScheduleError.changedResponse }
    guard code == "0" else { throw ScheduleError.unavailable("教务服务") }
    if portal == .undergraduate {
      guard let rows = root["datas"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
      let terms = try rows.map { row in
        guard let code = row["itemCode"] as? String, !code.isEmpty,
              let name = row["itemName"] as? String, !name.isEmpty,
              let selected = row["selected"] as? Bool else { throw ScheduleError.changedResponse }
        return SchoolTerm(id: code, name: name, isSelected: selected)
      }
      guard Set(terms.map(\.id)).count == terms.count else { throw ScheduleError.changedResponse }
      return terms
    }
    guard let datas = root["datas"] as? [String: Any],
          let table = datas["kfdxnxqcx"] as? [String: Any],
          let rows = table["rows"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    let sorted = try rows.map { row in
      guard let code = row["XNXQDM"] as? String, code.range(of: #"^\d{4}[123]$"#, options: .regularExpression) != nil,
            let name = row["XNXQDM_DISPLAY"] as? String, !name.isEmpty else { throw ScheduleError.changedResponse }
      return SchoolTerm(id: code, name: name, isSelected: false)
    }.sorted { $0.id > $1.id }
    guard Set(sorted.map(\.id)).count == sorted.count else { throw ScheduleError.changedResponse }
    // GSMIS 不返回 selected 字段；倒序第一项即当前学期，对齐 UBAA parseGsmisTerms。
    return sorted.enumerated().map { index, term in
      SchoolTerm(id: term.id, name: term.name, isSelected: index == 0)
    }
  }

  static func weeks(_ data: Data) throws -> [SchoolWeek] {
    let root = try object(data)
    guard let code = string(root["code"]) else { throw ScheduleError.changedResponse }
    guard code == "0" else { throw ScheduleError.unavailable("课表服务") }
    guard let rows = root["datas"] as? [[String: Any]] else {
      throw ScheduleError.changedResponse
    }
    let weeks = try rows.map { row in
      guard let number = integer(row["serialNumber"]), number > 0,
            let start = date(row["startDate"]), let end = date(row["endDate"]), start <= end,
            let isCurrent = row["curWeek"] as? Bool else {
        throw ScheduleError.changedResponse
      }
      return SchoolWeek(number: number, start: start, end: end, isCurrent: isCurrent)
    }.sorted { $0.number < $1.number }
    guard Set(weeks.map(\.number)).count == weeks.count else { throw ScheduleError.changedResponse }
    return weeks
  }

  static func exams(_ data: Data) throws -> [Exam] {
    let root = try object(data)
    guard let code = string(root["code"]) else { throw ScheduleError.changedResponseAt("考试安排") }
    guard code == "0" else { throw ScheduleError.unavailable("考试安排服务") }
    guard let rows = root["datas"] as? [[String: Any]] else {
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
    guard let schemes = root["jcfaList"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    let slots = try schemes.flatMap { scheme -> [[String: Any]] in
      guard let entries = scheme["skjcList"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
      return entries
    }
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
    // 新学期尚未发布排课时 GSMIS 会返回 code=1 和三个空数组。
    // 这是合法的“暂无课表”，不是上游结构变化。
    if rows.isEmpty && tasks.isEmpty { return [] }
    // API.md §3.3：SCSKRQ 属于教学班，须取该班所有排课中的最早周/星期偏移。
    // 论文/实践类教学班可能没有排课行或缺少可解析日期，这类任务无法参与推算，跳过即可；
    // 只有有效任务给出不一致的开学日期时，才报告结构变化。
    let termTasks = tasks.filter { string($0["XNXQDM"]) == termID }
    guard !termTasks.isEmpty else { throw ScheduleError.changedResponse }
    var skippedTasks = 0
    let candidates: [Date] = termTasks.compactMap { task in
      guard let classID = string(task["BJDM"]), !classID.isEmpty,
            let firstDate = date(task["SCSKRQ"]) else { skippedTasks += 1; return nil }
      let classRows = rows.filter { string($0["BJDM"]) == classID }
      guard !classRows.isEmpty else { skippedTasks += 1; return nil }
      let offsets: [Int] = classRows.compactMap { row in
        guard let day = integer(row["XQ"]), (1...7).contains(day),
              let bitmap = row["ZCBH"] as? String, !bitmap.isEmpty,
              bitmap.allSatisfy({ $0 == "0" || $0 == "1" }),
              let first = bitmap.firstIndex(of: "1") else { return nil }
        return bitmap.distance(from: bitmap.startIndex, to: first) * 7 + day - 1
      }
      guard let offset = offsets.min(),
            let start = calendar.date(byAdding: .day, value: -offset, to: firstDate) else {
        skippedTasks += 1
        return nil
      }
      return start
    }
    if skippedTasks > 0 {
      AppLog.network.notice("graduate weeks skipped incomputable tasks count=\(skippedTasks)")
    }
    guard let start = candidates.first, candidates.allSatisfy({ calendar.isDate($0, inSameDayAs: start) }),
          calendar.component(.weekday, from: start) == 2 else { throw ScheduleError.changedResponse }
    let bitmaps = rows.compactMap { row -> String? in
      guard let bitmap = row["ZCBH"] as? String, !bitmap.isEmpty,
            bitmap.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
      return bitmap
    }
    let count = bitmaps.map(\.count).max() ?? 0
    guard count > 0 else { throw ScheduleError.changedResponse }
    let currentInterval = calendar.dateInterval(of: .weekOfYear, for: Date())
    return (1...count).compactMap { number in
      guard let first = calendar.date(byAdding: .day, value: (number - 1) * 7, to: start),
            let last = calendar.date(byAdding: .day, value: 6, to: first) else { return nil }
      // DateInterval.contains 包含右端点，而右端点正是下一周的周一；用半开区间避免连续两周都标“本周”。
      let current = currentInterval.map { first >= $0.start && first < $0.end } ?? false
      return SchoolWeek(number: number, start: first, end: last, isCurrent: current)
    }
  }

  private static func object(_ data: Data) throws -> [String: Any] {
    guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ScheduleError.changedResponse
    }
    return value
  }

  private static func string(_ value: Any?) -> String? { JSONValue.string(value) }

  /// 课表字段严格要求整数文本：`3.5` 这类非整数视为结构变化，而不是截断为 3。
  private static func integer(_ value: Any?) -> Int? { string(value).flatMap(Int.init) }

  private static var calendar: Calendar { SchoolTime.calendar }

  private static func date(_ value: Any?) -> Date? {
    guard let raw = value as? String else { return nil }
    return SchoolTime.date(from: String(raw.prefix(10)), formats: ["yyyy-MM-dd"])
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

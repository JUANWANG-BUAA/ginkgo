import Foundation

enum ScheduleParser {
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

  static func undergraduateCourses(_ data: Data) throws -> [CourseMeeting] {
    let root = try object(data)
    guard string(root["code"]) == "0", let datas = root["datas"] as? [String: Any],
          let rows = datas["arrangedList"] as? [[String: Any]] else { throw ScheduleError.changedResponse }
    return try rows.enumerated().map { index, row in
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
    }.sorted(by: meetingOrder)
  }

  static func graduateCourses(_ data: Data, termID: String, week: Int) throws -> [CourseMeeting] {
    let root = try object(data)
    guard string(root["code"]) == "1", let rows = root["jgList"] as? [[String: Any]] else {
      throw ScheduleError.changedResponse
    }
    let slots = (root["jcfaList"] as? [[String: Any]] ?? []).flatMap { $0["skjcList"] as? [[String: Any]] ?? [] }
    let meetings = try rows.enumerated().compactMap { index, row in
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
    }.sorted(by: meetingOrder)
    return mergeAdjacent(meetings)
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

  private static func mergeAdjacent(_ meetings: [CourseMeeting]) -> [CourseMeeting] {
    var result: [CourseMeeting] = []
    for meeting in meetings {
      if let previous = result.last,
         previous.day == meeting.day, previous.name == meeting.name,
         previous.place == meeting.place, previous.teacher == meeting.teacher,
         previous.endSection + 1 == meeting.startSection {
        result[result.count - 1] = CourseMeeting(id: previous.id, name: previous.name, day: previous.day,
                                                  startSection: previous.startSection, endSection: meeting.endSection,
                                                  startTime: previous.startTime, endTime: meeting.endTime,
                                                  place: previous.place, teacher: previous.teacher, color: previous.color)
      } else {
        result.append(meeting)
      }
    }
    return result
  }

  private static func slotTime(_ slots: [[String: Any]], scheme: String?, section: Int, key: String) -> String? {
    guard let scheme, let slot = slots.first(where: {
      $0["JCFADM"] as? String == scheme && integer($0["DM"]) == section
    }), let value = integer(slot[key]), (0...2359).contains(value), value % 100 < 60 else { return nil }
    return String(format: "%02d:%02d", value / 100, value % 100)
  }
}

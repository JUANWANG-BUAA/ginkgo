import Foundation

/// 把 iclass 同一课程/时间的多条教学班记录，与本周课表做保守匹配。
/// 匹配不到时保留全部未签到候选，让用户在界面上明确选择。
enum CheckInTargetMatcher {
  static func signInCandidates(for item: CheckInItem, schedule: ScheduleSnapshot?) -> [CheckInCandidate] {
    let unsigned = item.candidates.filter { $0.status == .notSigned }
    guard unsigned.isEmpty == false else { return [] }
    if let matched = matchedCandidate(for: item, among: unsigned, schedule: schedule) {
      return [matched]
    }
    return unsigned
  }

  static func matchedCandidate(
    for item: CheckInItem,
    among candidates: [CheckInCandidate],
    schedule: ScheduleSnapshot?
  ) -> CheckInCandidate? {
    guard let schedule else { return nil }
    let courses = schedule.courses + (schedule.termCourses?.values.flatMap { $0 } ?? [])
    let itemName = normalize(item.courseName)
    let itemTime = timePart(item.beginsAt)
    let matches = courses.filter { course in
      normalize(course.name) == itemName
        && course.startTime.map(timePart) == itemTime
    }
    guard matches.isEmpty == false else { return nil }

    let places = Set(matches.compactMap(\.place).map(normalize))
    let teachers = Set(matches.compactMap(\.teacher).map(normalize))
    let placeMatches = candidates.filter { candidate in
      guard let classroom = candidate.classroomName else { return false }
      return places.contains(normalize(classroom))
    }
    if placeMatches.count == 1 { return placeMatches[0] }

    let teacherMatches = candidates.filter { candidate in
      guard let teacher = candidate.teacherName else { return false }
      return teachers.contains { teacher.contains($0) || $0.contains(teacher) }
    }
    if teacherMatches.count == 1 { return teacherMatches[0] }
    return nil
  }

  static func matchedTargetLabel(for item: CheckInItem, schedule: ScheduleSnapshot?) -> String? {
    guard item.mergedRecordCount > 1 else { return nil }
    let candidates = signInCandidates(for: item, schedule: schedule)
    guard candidates.count == 1, let label = candidates.first?.displayLabel, label.isEmpty == false else {
      return nil
    }
    return label
  }

  static func isSigned(courseID: String, in items: [CheckInItem]) -> Bool {
    items.contains { item in
      (item.id == courseID && item.status == .signed)
        || item.candidates.first(where: { $0.id == courseID })?.status == .signed
    }
  }

  private static func normalize(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
      .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_CN"))
      .lowercased()
  }

  private static func timePart(_ value: String) -> String {
    String(value.suffix(8).prefix(5))
  }
}

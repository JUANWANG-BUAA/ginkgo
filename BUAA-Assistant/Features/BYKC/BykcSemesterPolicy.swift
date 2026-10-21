import Foundation

/// 与门户请求无关的学期选择规则。
enum BykcSemesterPolicy {
  static func currentSemester(_ semesters: [BykcSemester], now: Date = Date()) -> BykcSemester? {
    if let active = semesters.first(where: { semester in
      guard let start = BykcDate.parse(semester.startDate),
            let end = BykcDate.parse(semester.endDate) else { return false }
      return start <= now && now <= end
    }) {
      return active
    }
    return semesters.max { lhs, rhs in
      (BykcDate.parse(lhs.endDate) ?? .distantPast) < (BykcDate.parse(rhs.endDate) ?? .distantPast)
    }
  }
}

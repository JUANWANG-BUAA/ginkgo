import Foundation

struct GradeCourse: Identifiable, Codable {
  let id: String
  let name: String
  let code: String?
  let credit: Double?
  let score: String
  let scoreValue: Double?
  let scoreType: String?
  let courseType: String?

  var percentageScore: Double? {
    guard let value = scoreValue, value.isFinite, (0...100).contains(value),
          scoreType == nil || scoreType?.isEmpty == true || scoreType == "百分制" else { return nil }
    return value
  }
}

struct GradeSnapshot: Codable {
  let term: SchoolTerm
  let courses: [GradeCourse]
  let fetchedAt: Date

  var weightedAverage: Double? {
    let included = courses.compactMap { course -> (Double, Double)? in
      guard let score = course.percentageScore, let credit = course.credit, credit.isFinite, credit > 0 else { return nil }
      return (score, credit)
    }
    let totalCredit = included.reduce(0) { $0 + $1.1 }
    guard totalCredit > 0 else { return nil }
    return included.reduce(0) { $0 + $1.0 * $1.1 } / totalCredit
  }

  var gradePointAverage: Double? {
    let included = courses.compactMap { course -> (Double, Double)? in
      guard let score = course.percentageScore,
            let credit = course.credit, credit.isFinite, credit > 0 else { return nil }
      return (score < 60 ? 0 : 4 - 3 * pow(100 - score, 2) / 1600, credit)
    }
    let totalCredit = included.reduce(0) { $0 + $1.1 }
    guard totalCredit > 0 else { return nil }
    return included.reduce(0) { $0 + $1.0 * $1.1 } / totalCredit
  }
}

enum GradeTermCode {
  static func parts(_ code: String) throws -> (year: String, semester: String) {
    if code.range(of: #"^\d{4}-\d{4}-[123]$"#, options: .regularExpression) != nil {
      let pieces = code.split(separator: "-")
      guard Int(pieces[1]) == Int(pieces[0])! + 1 else { throw ScheduleError.invalidTerm }
      return ("\(pieces[0])-\(pieces[1])", String(pieces[2]))
    }
    if code.range(of: #"^\d{4}[123]$"#, options: .regularExpression) != nil,
       let start = Int(code.prefix(4)) {
      return ("\(start)-\(start + 1)", String(code.suffix(1)))
    }
    throw ScheduleError.invalidTerm
  }
}

enum GradeParser {
  static func courses(_ data: Data) throws -> [GradeCourse] {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let status = root["e"] as? Int else {
      throw ScheduleError.changedResponseAt("成绩")
    }
    guard status == 0 else { throw ScheduleError.unavailable("成绩服务") }
    guard let rows = root["d"] as? [String: [String: Any]] else {
      throw ScheduleError.changedResponseAt("成绩")
    }
    return try rows.map { key, row in
      guard let name = text(row["kcmc"]), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            row.keys.contains("kccj"), row.keys.contains("xf"),
            validScoreValue(row["kccj"]), validCreditValue(row["xf"]) else {
        throw ScheduleError.changedResponseAt("成绩")
      }
      let score = text(row["kccj"]) ?? "未发布"
      return GradeCourse(id: key, name: name,
                         code: text(row["kch"]), credit: text(row["xf"]).flatMap(Double.init),
                         score: score, scoreValue: Double(score), scoreType: text(row["fslx"]),
                         courseType: text(row["kclx"]))
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private static func text(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value.stringValue }
    return nil
  }

  private static func validScoreValue(_ value: Any?) -> Bool {
    value is NSNull || text(value) != nil
  }

  private static func validCreditValue(_ value: Any?) -> Bool {
    guard let value, !(value is NSNull) else { return true }
    guard let raw = text(value), !raw.isEmpty, let credit = Double(raw) else { return false }
    return credit.isFinite && credit >= 0
  }
}

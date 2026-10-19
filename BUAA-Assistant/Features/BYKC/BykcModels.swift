import Foundation

struct BykcProfile: Codable, Equatable {
  let studentType: String?
  let className: String?
  let collegeName: String?
  let termName: String?
}

struct BykcSemester: Codable, Equatable, Identifiable {
  let id: Int64
  let name: String
  let startDate: String?
  let endDate: String?
}

struct BykcCourse: Codable, Equatable, Identifiable, Hashable {
  let id: Int64
  let name: String
  let teacher: String?
  let position: String?
  let category: String?
  let subcategory: String?
  let startDate: String?
  let endDate: String?
  let selectStartDate: String?
  let selectEndDate: String?
  let cancelEndDate: String?
  let maxCount: Int?
  let currentCount: Int?
  let campuses: [String]
  let summary: String?
  let selected: Bool
  let hasSignConfig: Bool

  var availability: String? {
    guard let maxCount else { return nil }
    return "\(currentCount ?? 0)/\(maxCount) 人"
  }

  var filterCategory: String { subcategory ?? category ?? "未分类" }
}

struct BykcChosenCourse: Codable, Equatable, Identifiable {
  let id: Int64
  let course: BykcCourse
  let selectedAt: String?
  let checkin: Int?
  let passed: Int?
  let score: Int?
}

struct BykcStatisticsEntry: Codable, Equatable, Identifiable {
  var id: String { "\(category)|\(subcategory)" }
  let category: String
  let subcategory: String
  let required: Int
  let completed: Int

  var isComplete: Bool { required > 0 && completed >= required }
  var progress: Double {
    guard required > 0 else { return 0 }
    return min(1, Double(completed) / Double(required))
  }
}

struct BykcSnapshot: Codable, Equatable {
  let profile: BykcProfile
  let semesters: [BykcSemester]
  let currentSemester: BykcSemester?
  let courses: [BykcCourse]
  let chosen: [BykcChosenCourse]
  let statistics: [BykcStatisticsEntry]
  let validCourseCount: Int
  let fetchedAt: Date

  var categoryCounts: [(String, Int)] {
    Dictionary(grouping: courses, by: \.filterCategory)
      .map { ($0.key, $0.value.count) }
      .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
  }
}

enum BykcError: LocalizedError {
  case loginFailed
  case invalidEnvelope
  case upstream(String)
  case crypto

  var errorDescription: String? {
    switch self {
    case .loginFailed: "博雅登录未返回有效 token，请重新登录后重试"
    case .invalidEnvelope: "博雅返回的数据结构无法识别，接口可能已调整"
    case .upstream(let message): "博雅请求失败：\(message)"
    case .crypto: "博雅请求加密或响应解密失败"
    }
  }
}

typealias BykcCache = SnapshotCache<BykcSnapshot>

extension SnapshotCache where Value == BykcSnapshot {
  init(directory: URL? = nil) { self.init(module: "BYKC", directory: directory) }
}

import Foundation

/// 可跨界面、跨语言传递的课程类别选择。UI 文案不编码进此类型。
enum BykcCourseCategorySelection: Hashable, Identifiable, Codable {
  case all
  case named(String)
  case unclassified

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
  }

  private enum Kind: String, Codable {
    case all
    case named
    case unclassified
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .all:
      self = .all
    case .named:
      let value = try container.decode(String.self, forKey: .value)
      guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw DecodingError.dataCorruptedError(
          forKey: .value,
          in: container,
          debugDescription: "Named BYKC category must not be empty."
        )
      }
      self = .named(value)
    case .unclassified:
      self = .unclassified
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .all:
      try container.encode(Kind.all, forKey: .kind)
    case .named(let value):
      try container.encode(Kind.named, forKey: .kind)
      try container.encode(value, forKey: .value)
    case .unclassified:
      try container.encode(Kind.unclassified, forKey: .kind)
    }
  }

  var id: String {
    switch self {
    case .all: "all"
    case .named(let value): "named:\(value)"
    case .unclassified: "unclassified"
    }
  }

  fileprivate var sortKey: String {
    switch self {
    case .all: ""
    case .named(let value): value
    case .unclassified: "未分类"
    }
  }
}

/// 课程目录查询输入；`category` 使用稳定类别选择，不使用本地化的“全部/未分类”文案。
struct BykcCourseFilter: Codable, Equatable {
  var searchText: String
  var category: BykcCourseCategorySelection

  init(searchText: String = "", category: BykcCourseCategorySelection = .all) {
    self.searchText = searchText
    self.category = category
  }
}

struct BykcCourseCategoryCount: Codable, Equatable, Identifiable {
  let category: BykcCourseCategorySelection
  let count: Int

  var id: String { category.id }
}

/// 纯课程目录规则：不访问网络、缓存、SwiftUI 或账号状态。
enum BykcCourseCatalog {
  static func category(for course: BykcCourse) -> BykcCourseCategorySelection {
    if let subcategory = normalizedCategory(course.subcategory) {
      return .named(subcategory)
    }
    if let category = normalizedCategory(course.category) {
      return .named(category)
    }
    return .unclassified
  }

  static func categoryCounts(in courses: [BykcCourse]) -> [BykcCourseCategoryCount] {
    Dictionary(grouping: courses, by: category(for:))
      .map { BykcCourseCategoryCount(category: $0.key, count: $0.value.count) }
      .sorted { lhs, rhs in
        lhs.count == rhs.count
          ? lhs.category.sortKey < rhs.category.sortKey
          : lhs.count > rhs.count
      }
  }

  static func filtered(_ courses: [BykcCourse], by filter: BykcCourseFilter) -> [BykcCourse] {
    let query = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return courses.filter { course in
      guard category(course, matches: filter.category) else { return false }
      guard query.isEmpty == false else { return true }
      return [course.name, course.teacher, course.position]
        .compactMap { $0 }
        .contains { contains($0, query: query) }
    }
  }

  private static func category(
    _ course: BykcCourse,
    matches selection: BykcCourseCategorySelection
  ) -> Bool {
    switch selection {
    case .all:
      true
    case .named, .unclassified:
      category(for: course) == selection
    }
  }

  private static func normalizedCategory(_ value: String?) -> String? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  private static func contains(_ value: String, query: String) -> Bool {
    value.range(
      of: query,
      options: [.caseInsensitive],
      locale: Locale(identifier: "en_US_POSIX")
    ) != nil
  }
}

/// BYKC 的少量本地化展示格式；不属于课程数据或 Rust/Flutter 领域契约。
enum BykcCoursePresentation {
  static func categoryTitle(_ selection: BykcCourseCategorySelection) -> String {
    switch selection {
    case .all: "全部"
    case .named(let value): value
    case .unclassified: "未分类"
    }
  }

  static func availabilityText(for course: BykcCourse) -> String? {
    guard let maximum = course.maxCount else { return nil }
    return "\(course.currentCount ?? 0)/\(maximum) 人"
  }
}

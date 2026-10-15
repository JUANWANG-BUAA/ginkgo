import Foundation

enum HomeworkStatus: String, Codable {
  case pending
  case submitted
  case overdue
  case unknown
}

enum HomeworkSource: String, Codable, CaseIterable, Identifiable {
  case judge
  case spoc
  var id: String { rawValue }
  var title: String { self == .judge ? "希冀" : "SPOC" }
}

struct HomeworkItem: Identifiable, Codable, Hashable {
  let id: String
  let courseName: String
  let title: String
  let dueAt: Date?
  let sourceURL: URL?
  let status: HomeworkStatus
  let source: HomeworkSource
  let fetchedAt: Date
}

struct HomeworkSnapshot: Codable {
  let items: [HomeworkItem]
  let fetchedAt: Date
  /// Sources that failed during this refresh. An empty item list is only a complete empty result when this is empty.
  let unavailableSources: [HomeworkSource]

  init(items: [HomeworkItem], fetchedAt: Date, unavailableSources: [HomeworkSource] = []) {
    self.items = items
    self.fetchedAt = fetchedAt
    self.unavailableSources = unavailableSources
  }

  private enum CodingKeys: String, CodingKey {
    case items, fetchedAt, unavailableSources
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    items = try container.decode([HomeworkItem].self, forKey: .items)
    fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    unavailableSources = try container.decodeIfPresent([HomeworkSource].self, forKey: .unavailableSources) ?? []
  }
}

enum HomeworkError: LocalizedError, Equatable {
  case protocolNotConfigured
  case sessionExpired
  case unavailable

  var errorDescription: String? {
    switch self {
    case .protocolNotConfigured: "学校作业协议尚未完成取证，暂未连接"
    case .sessionExpired: "学校作业会话已过期，请重新登录"
    case .unavailable: "学校作业服务暂时不可用"
    }
  }
}

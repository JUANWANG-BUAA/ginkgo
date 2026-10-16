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
  /// Upstream course identifier when exposed by the source (SPOC: `sskcid`).
  let courseID: String?
  let courseName: String
  let title: String
  let dueAt: Date?
  let publishedAt: Date?
  let teacherName: String?
  /// Maximum assignment points exposed by SPOC; this is not the student's earned score.
  let score: String?
  let sourceURL: URL?
  let status: HomeworkStatus
  /// Original upstream status text when it cannot be mapped to a known state.
  let statusDetail: String?
  let source: HomeworkSource
  let fetchedAt: Date

  init(
    id: String,
    courseName: String,
    title: String,
    dueAt: Date?,
    sourceURL: URL?,
    status: HomeworkStatus,
    source: HomeworkSource,
    fetchedAt: Date,
    courseID: String? = nil,
    publishedAt: Date? = nil,
    teacherName: String? = nil,
    score: String? = nil,
    statusDetail: String? = nil
  ) {
    self.id = id
    self.courseID = courseID
    self.courseName = courseName
    self.title = title
    self.dueAt = dueAt
    self.publishedAt = publishedAt
    self.teacherName = teacherName
    self.score = score
    self.sourceURL = sourceURL
    self.status = status
    self.statusDetail = statusDetail
    self.source = source
    self.fetchedAt = fetchedAt
  }
}

struct HomeworkDetail: Equatable {
  let itemID: String
  let content: String?
  let submissionStatus: HomeworkStatus?
  var statusDetail: String? = nil
  let submittedAt: Date?
  let score: String?
  let publishedAt: Date?
  let dueAt: Date?
  let fetchedAt: Date
  var earnedScore: String? = nil
  var totalProblems: Int? = nil
  var submittedCount: Int? = nil
  var problems: [HomeworkProblem] = []
}

struct HomeworkProblem: Identifiable, Equatable {
  let id: String
  let name: String
  let earnedScore: String?
  let maxScore: String?
  let status: HomeworkStatus
  let statusText: String
}

struct HomeworkTerm: Codable, Equatable {
  let code: String?
  let name: String?

  var displayName: String {
    let parts = [name, code].compactMap { value in
      value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
    return parts.joined(separator: " · ")
  }
}

struct HomeworkSnapshot: Codable {
  let items: [HomeworkItem]
  let fetchedAt: Date
  /// Sources that failed during this refresh. An empty item list is only a complete empty result when this is empty.
  let unavailableSources: [HomeworkSource]
  let protocolChangedSources: [HomeworkSource]
  let spocTerm: HomeworkTerm?

  init(
    items: [HomeworkItem],
    fetchedAt: Date,
    unavailableSources: [HomeworkSource] = [],
    protocolChangedSources: [HomeworkSource] = [],
    spocTerm: HomeworkTerm? = nil
  ) {
    self.items = items
    self.fetchedAt = fetchedAt
    self.unavailableSources = unavailableSources
    self.protocolChangedSources = protocolChangedSources
    self.spocTerm = spocTerm
  }

  private enum CodingKeys: String, CodingKey {
    case items, fetchedAt, unavailableSources, protocolChangedSources, spocTerm
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    items = try container.decode([HomeworkItem].self, forKey: .items)
    fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    unavailableSources = try container.decodeIfPresent([HomeworkSource].self, forKey: .unavailableSources) ?? []
    protocolChangedSources = try container.decodeIfPresent([HomeworkSource].self, forKey: .protocolChangedSources) ?? []
    spocTerm = try container.decodeIfPresent(HomeworkTerm.self, forKey: .spocTerm)
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}

enum HomeworkError: LocalizedError, Equatable {
  case protocolNotConfigured
  case sessionExpired
  case unavailable
  case detailUnavailable(String)
  case spocFailure(stage: String, reason: String)
  case spocAuthenticationExpired(stage: String)
  case upstreamProtocolChanged(source: HomeworkSource, stage: String)
  case allSourcesUnavailable(judge: String, spoc: String)

  var errorDescription: String? {
    switch self {
    case .protocolNotConfigured: "学校作业协议尚未完成取证，暂未连接"
    case .sessionExpired: "学校作业会话已过期，请重新登录"
    case .unavailable: "学校作业服务暂时不可用"
    case .detailUnavailable(let reason): reason
    case .spocFailure(let stage, let reason): "SPOC\(stage)失败：\(reason)"
    case .spocAuthenticationExpired(let stage): "SPOC\(stage)时登录态失效"
    case .upstreamProtocolChanged(let source, let stage): "\(source.title)\(stage)响应格式已变化，学校接口可能已调整"
    case .allSourcesUnavailable(let judge, let spoc): "希冀：\(judge)；SPOC：\(spoc)"
    }
  }
}

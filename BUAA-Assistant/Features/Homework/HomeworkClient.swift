import Foundation
import CommonCrypto

protocol HomeworkServing {
  func load() async throws -> HomeworkSnapshot
}

protocol HomeworkDetailServing {
  func loadDetail(for item: HomeworkItem) async throws -> HomeworkDetail
}

actor HomeworkClient: HomeworkServing, HomeworkDetailServing {
  private let session: URLSession
  init(session: URLSession = APIClient.shared.session) { self.session = session }

  func load() async throws -> HomeworkSnapshot {
    async let judge = JudgeHomeworkClient(session: session).load()
    async let spoc = SpocHomeworkClient(session: session).load()
    var items: [HomeworkItem] = []
    var failures: [HomeworkSource: Error] = [:]
    var spocTerm: HomeworkTerm?
    do {
      items += try await judge.items
    } catch {
      failures[.judge] = error
      AppLog.network.error("homework provider failed source=judge category=\(Self.failureCategory(error), privacy: .public)")
    }
    do {
      let result = try await spoc
      items += result.items
      spocTerm = result.spocTerm
    } catch {
      failures[.spoc] = error
      AppLog.network.error("homework provider failed source=spoc category=\(Self.failureCategory(error), privacy: .public)")
    }
    if failures.count == HomeworkSource.allCases.count {
      throw HomeworkError.allSourcesUnavailable(
        judge: Self.userFacingDescription(for: failures[.judge]),
        spoc: Self.userFacingDescription(for: failures[.spoc])
      )
    }
    return HomeworkSnapshot(items: items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) },
                            fetchedAt: Date(),
                            unavailableSources: HomeworkSource.allCases.filter { failures[$0] != nil },
                            protocolChangedSources: HomeworkSource.allCases.filter { source in
                              guard let error = failures[source] else { return false }
                              return Self.isProtocolChanged(error)
                            },
                            spocTerm: spocTerm)
  }

  func loadDetail(for item: HomeworkItem) async throws -> HomeworkDetail {
    if item.source == .spoc {
      let assignmentID = String(item.id.dropFirst("spoc:".count))
      guard item.id.hasPrefix("spoc:"), !assignmentID.isEmpty else {
        throw HomeworkError.detailUnavailable("未能识别 SPOC 作业编号")
      }
      return try await SpocHomeworkClient(session: session).loadDetail(assignmentID: assignmentID)
    }
    guard item.source == .judge else {
      throw HomeworkError.detailUnavailable("当前作业来源暂不支持应用内详情")
    }
    let parts = item.id.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0] == "judge" else {
      throw HomeworkError.detailUnavailable("未能识别希冀作业编号")
    }
    return try await JudgeHomeworkClient(session: session).loadDetail(
      itemID: item.id,
      courseID: String(parts[1]),
      assignmentID: String(parts[2])
    )
  }

  private static func userFacingDescription(for error: Error?) -> String {
    guard let error else { return "暂时不可用" }
    if let localized = error as? LocalizedError, let description = localized.errorDescription {
      return description
    }
    if let urlError = error as? URLError {
      return "网络连接失败（\(urlError.code.rawValue)）"
    }
    if error is DecodingError { return "服务响应格式无法识别，学校接口可能已调整" }
    return "服务暂时不可用"
  }

  private static func failureCategory(_ error: Error) -> String {
    if let homeworkError = error as? HomeworkError {
      switch homeworkError {
      case .protocolNotConfigured: return "protocol_not_configured"
      case .sessionExpired: return "session_expired"
      case .unavailable: return "service_unavailable"
      case .detailUnavailable: return "detail_unavailable"
      case .spocFailure: return "spoc_stage_failure"
      case .spocAuthenticationExpired: return "spoc_authentication_expired"
      case .upstreamProtocolChanged: return "upstream_protocol_changed"
      case .allSourcesUnavailable: return "all_sources_unavailable"
      }
    }
    if let urlError = error as? URLError { return "network_\(urlError.code.rawValue)" }
    if error is DecodingError { return "decoding_failure" }
    return "unexpected_failure"
  }

  private static func isProtocolChanged(_ error: Error) -> Bool {
    if let homeworkError = error as? HomeworkError,
       case .upstreamProtocolChanged = homeworkError { return true }
    if error is DecodingError { return true }
    return false
  }
}

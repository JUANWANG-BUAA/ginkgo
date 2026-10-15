import Foundation
import CommonCrypto

protocol HomeworkServing {
  func load() async throws -> HomeworkSnapshot
}

actor HomeworkClient: HomeworkServing {
  private let session: URLSession
  init(session: URLSession = APIClient.shared.session) { self.session = session }

  func load() async throws -> HomeworkSnapshot {
    async let judge = JudgeHomeworkClient(session: session).load()
    async let spoc = SpocHomeworkClient(session: session).load()
    var items: [HomeworkItem] = []
    var errors: [Error] = []
    var unavailableSources: [HomeworkSource] = []
    do { items += try await judge.items } catch { errors.append(error); unavailableSources.append(.judge) }
    do { items += try await spoc.items } catch { errors.append(error); unavailableSources.append(.spoc) }
    if unavailableSources.count == HomeworkSource.allCases.count, let first = errors.first { throw first }
    return HomeworkSnapshot(items: items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) },
                            fetchedAt: Date(), unavailableSources: unavailableSources)
  }
}

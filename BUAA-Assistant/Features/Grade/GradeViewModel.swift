import CryptoKit
import Foundation

actor GradeCache {
  private let directory: URL

  init(directory: URL? = nil) {
    self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("BUAA-Assistant/Grades", isDirectory: true)
  }

  func read(account: String) -> GradeSnapshot? {
    guard let data = try? Data(contentsOf: file(account)) else { return nil }
    return try? JSONDecoder().decode(GradeSnapshot.self, from: data)
  }

  func save(_ snapshot: GradeSnapshot, account: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(snapshot).write(to: file(account), options: .atomic)
  }

  func clear(account: String) throws {
    let target = file(account)
    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
  }

  private func file(_ account: String) -> URL {
    let digest = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(digest + ".json")
  }
}

@MainActor
final class GradeViewModel: ObservableObject {
  @Published private(set) var terms: [SchoolTerm] = []
  @Published private(set) var snapshot: GradeSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var feedback: String?
  @Published private(set) var needsSessionCheck = false

  private let termService: TermServing
  private let grades: GradeServing
  private let cache: GradeCache
  private var account: String?
  private var generation = 0

  init(termService: TermServing = ScheduleClient(), grades: GradeServing = GradeClient(), cache: GradeCache = GradeCache()) {
    self.termService = termService
    self.grades = grades
    self.cache = cache
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    isLoading = true
    let current = generation
    let cached = await cache.read(account: account)
    guard current == generation else { return }
    snapshot = cached
    await refresh()
  }

  func reset() {
    generation += 1
    account = nil
    terms = []
    snapshot = nil
    isLoading = false
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
  }

  func refresh(term: SchoolTerm? = nil) async {
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    feedback = nil
    needsSessionCheck = false
    defer { if current == generation { isLoading = false } }
    do {
      if terms.isEmpty {
        let available = try await termService.availableTerms()
        guard current == generation else { return }
        terms = available
      }
      let chosen = term ?? terms.first(where: { $0.id == snapshot?.term.id })
        ?? terms.first(where: \.isSelected) ?? terms.first
      guard let chosen else { throw ScheduleError.invalidTerm }
      let result = try await grades.load(term: chosen)
      guard current == generation else { return }
      snapshot = result
      feedback = "成绩已更新"
      if let account { try? await cache.save(result, account: account) }
    } catch {
      guard current == generation else { return }
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "成绩更新失败，请检查网络后重试"
      if let failure = error as? ScheduleError, case .sessionExpired = failure { needsSessionCheck = true }
    }
  }
}

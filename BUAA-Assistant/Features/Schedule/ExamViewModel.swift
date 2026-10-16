import CryptoKit
import Foundation

struct ExamCacheEntry: Codable {
  let exams: [Exam]
  let fetchedAt: Date
}

actor ExamCache {
  private let directory: URL
  private let maximumTerms = 12

  init(directory: URL? = nil) {
    self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("BUAA-Assistant/Exams", isDirectory: true)
  }

  func read(account: String, termID: String) -> ExamCacheEntry? {
    guard let data = try? Data(contentsOf: file(account: account)),
          let entries = try? JSONDecoder().decode([String: ExamCacheEntry].self, from: data) else { return nil }
    return entries[termID]
  }

  func save(_ entry: ExamCacheEntry, account: String, termID: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = file(account: account)
    var entries = (try? Data(contentsOf: target)).flatMap { try? JSONDecoder().decode([String: ExamCacheEntry].self, from: $0) } ?? [:]
    entries[termID] = entry
    if entries.count > maximumTerms {
      let retained = entries.sorted { $0.value.fetchedAt > $1.value.fetchedAt }.prefix(maximumTerms)
      entries = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
    }
    try JSONEncoder().encode(entries).write(to: target, options: .atomic)
  }

  func clear(account: String) throws {
    let target = file(account: account)
    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
  }

  private func file(account: String) -> URL {
    let digest = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(digest + ".json")
  }
}

@MainActor
final class ExamViewModel: ObservableObject {
  @Published private(set) var exams: [Exam]?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var loadedTermID: String?
  @Published private(set) var resultsAreCached = false
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false

  private let service: ExamServing
  private let cache: ExamCache
  private var account: String?
  private var generation = 0

  init(service: ExamServing = ScheduleClient(), cache: ExamCache = ExamCache()) {
    self.service = service
    self.cache = cache
  }

  func load(termID: String, force: Bool = false, account: String? = nil) async {
    guard !termID.isEmpty else { return }
    if let account, self.account != account {
      generation += 1
      exams = nil
      fetchedAt = nil
      loadedTermID = nil
      resultsAreCached = false
      self.account = account
    }
    let termChanged = loadedTermID != termID
    if termChanged {
      exams = nil
      fetchedAt = nil
      loadedTermID = nil
      resultsAreCached = false
      errorMessage = nil
    }
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    needsSessionCheck = false
    defer { if current == generation { isLoading = false } }

    if termChanged, let account = self.account,
       let cached = await cache.read(account: account, termID: termID) {
      guard current == generation else { return }
      exams = cached.exams
      fetchedAt = cached.fetchedAt
      loadedTermID = termID
      resultsAreCached = true
    }
    if !force, loadedTermID == termID, exams != nil,
       let fetchedAt, Date().timeIntervalSince(fetchedAt) < 15 * 60 { return }
    if exams != nil { resultsAreCached = true }

    do {
      let result = try await service.loadExams(termID: termID)
      guard current == generation else { return }
      exams = result
      fetchedAt = Date()
      loadedTermID = termID
      resultsAreCached = false
      if let account = self.account {
        try? await cache.save(ExamCacheEntry(exams: result, fetchedAt: fetchedAt!), account: account, termID: termID)
      }
    } catch {
      guard current == generation else { return }
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "考试安排读取失败，请稍后重试"
      if let error = error as? ScheduleError, case .sessionExpired = error {
        needsSessionCheck = true
      }
    }
  }

  func reset() {
    generation += 1
    exams = nil
    fetchedAt = nil
    loadedTermID = nil
    resultsAreCached = false
    account = nil
    isLoading = false
    errorMessage = nil
    needsSessionCheck = false
  }

  func clearCache(account overrideAccount: String? = nil) async throws {
    if let account = overrideAccount ?? account { try await cache.clear(account: account) }
    reset()
  }
}

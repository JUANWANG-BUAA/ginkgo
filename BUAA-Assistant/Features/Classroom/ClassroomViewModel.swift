import Foundation
import CryptoKit

struct ClassroomCacheEntry: Codable {
  let key: String
  let campus: Int
  let date: Date
  let rooms: [String: [FreeClassroom]]
  let fetchedAt: Date
}

actor ClassroomCache {
  private let directory: URL
  private let maximumQueries = 12

  init(directory: URL? = nil) {
    self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("BUAA-Assistant/Classrooms", isDirectory: true)
  }

  func read(account: String) -> [ClassroomCacheEntry] {
    guard let data = try? Data(contentsOf: file(account: account)) else { return [] }
    return (try? JSONDecoder().decode([ClassroomCacheEntry].self, from: data)) ?? []
  }

  func save(_ entry: ClassroomCacheEntry, account: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = file(account: account)
    var entries = (try? Data(contentsOf: target)).flatMap { try? JSONDecoder().decode([ClassroomCacheEntry].self, from: $0) } ?? []
    entries.removeAll { $0.key == entry.key }
    entries.append(entry)
    entries.sort { $0.fetchedAt > $1.fetchedAt }
    try JSONEncoder().encode(Array(entries.prefix(maximumQueries))).write(to: target, options: .atomic)
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

enum ClassroomSort: String, CaseIterable, Identifiable {
  case name = "教室名称"
  case availability = "空闲节数优先"
  case consecutive = "连续空闲优先"
  var id: String { rawValue }
}

@MainActor
final class ClassroomViewModel: ObservableObject {
  @Published var campus = 1 { didSet { if campus != oldValue { reset() } } }
  @Published var date = Date() { didSet { if !ScheduleSnapshot.schoolCalendar.isDate(date, inSameDayAs: oldValue) { reset() } } }
  @Published var search = "" { didSet { updateResults() } }
  @Published var section = 0 { didSet { updateResults() } }
  @Published var minimumFreeSections = 0 { didSet { updateResults() } }
  @Published var minimumConsecutiveSections = 0 { didSet { updateResults() } }
  @Published var building: String? { didSet { updateResults() } }
  @Published var sort: ClassroomSort = .name { didSet { updateResults() } }
  @Published private(set) var rooms: [String: [FreeClassroom]] = [:] { didSet { updateResults() } }
  @Published private(set) var filtered: [String: [FreeClassroom]] = [:]
  @Published private(set) var resultRevision = 0
  @Published private(set) var busy = false
  @Published private(set) var isLoadingCache = false
  @Published private(set) var resultsAreCached = false
  @Published private(set) var queried = false
  @Published private(set) var message: String?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var needsSessionCheck = false
  private let client: ClassroomServing
  private let cache: ClassroomCache
  private var account: String?
  private var generation = 0
  private struct CachedQuery {
    let rooms: [String: [FreeClassroom]]
    let fetchedAt: Date
  }
  private var cachedQueries: [String: CachedQuery] = [:]
  private var resultSummary = ResultSummary()

  private struct ResultSummary {
    var roomCount = 0
    var buildingCount = 0
    var freeSlotCount = 0
  }

  private var queryKey: String {
    let components = ScheduleSnapshot.schoolCalendar.dateComponents([.year, .month, .day], from: date)
    return "\(campus)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  func clearCache(account overrideAccount: String? = nil) async throws {
    if let account = overrideAccount ?? account { try await cache.clear(account: account) }
    cachedQueries = [:]
    reset()
  }

  init(client: ClassroomServing = ClassroomClient(), cache: ClassroomCache = ClassroomCache()) {
    self.client = client
    self.cache = cache
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    cachedQueries = [:]
    self.account = account
    isLoadingCache = true
    defer { isLoadingCache = false }
    let loadGeneration = generation
    let entries = await cache.read(account: account)
    guard self.account == account, generation == loadGeneration else { return }
    cachedQueries = entries.reduce(into: [:]) { result, entry in
      result[entry.key] = CachedQuery(rooms: entry.rooms, fetchedAt: entry.fetchedAt)
    }
    if let latest = entries.max(by: { $0.fetchedAt < $1.fetchedAt }) {
      campus = latest.campus
      date = latest.date
    }
    isLoadingCache = true
    if let cached = cachedQueries[queryKey] {
      rooms = cached.rooms
      fetchedAt = cached.fetchedAt
      queried = true
      resultsAreCached = true
    }
  }

  private func updateResults() {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedTerm = Self.normalizedSearch(term)
    var summary = ResultSummary()
    let nextResults = rooms.reduce(into: [String: [FreeClassroom]]()) { result, entry in
      guard building == nil || building == entry.key else { return }
      let matchesBuilding = Self.normalizedSearch(entry.key).contains(normalizedTerm)
      let matches = entry.value.filter { room in
        (normalizedTerm.isEmpty || matchesBuilding || Self.normalizedSearch(room.name).contains(normalizedTerm)) &&
        (section == 0 || room.isAvailable(at: section)) &&
        room.availableSectionCount >= minimumFreeSections &&
        room.longestFreeRun >= minimumConsecutiveSections
      }.sorted { lhs, rhs in
        if sort == .availability, lhs.availableSectionCount != rhs.availableSectionCount {
          return lhs.availableSectionCount > rhs.availableSectionCount
        }
        if sort == .consecutive, lhs.longestFreeRun != rhs.longestFreeRun {
          return lhs.longestFreeRun > rhs.longestFreeRun
        }
        let order = lhs.name.localizedStandardCompare(rhs.name)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
      }
      if !matches.isEmpty {
        result[entry.key] = matches
        summary.roomCount += matches.count
        summary.buildingCount += 1
        summary.freeSlotCount += matches.reduce(0) { $0 + $1.availableSectionCount }
      }
    }
    resultSummary = summary
    resultRevision &+= 1
    filtered = nextResults
  }

  private static func normalizedSearch(_ value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(scalars))
  }

  var hasActiveFilters: Bool {
    !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || section != 0 ||
      minimumFreeSections != 0 || minimumConsecutiveSections != 0 || building != nil
  }

  var roomCount: Int { rooms.values.reduce(0) { $0 + $1.count } }
  var filteredRoomCount: Int { resultSummary.roomCount }
  var buildingCount: Int { resultSummary.buildingCount }
  var freeSlotCount: Int { resultSummary.freeSlotCount }

  func reset() {
    generation += 1
    rooms = [:]; queried = false; fetchedAt = nil; message = nil
    building = nil
    busy = false; isLoadingCache = false; resultsAreCached = false; needsSessionCheck = false
  }

  func resetFilters() {
    search = ""
    section = 0
    minimumFreeSections = 0
    minimumConsecutiveSections = 0
    building = nil
  }

  func query(forceRefresh: Bool = false) async {
    guard !busy else { return }
    let key = queryKey
    if let cached = cachedQueries[key] {
      rooms = cached.rooms; fetchedAt = cached.fetchedAt; queried = true
      resultsAreCached = true
      if !forceRefresh && Date().timeIntervalSince(cached.fetchedAt) < 300 {
        message = nil
        return
      }
    }
    generation += 1
    let current = generation
    if queried { resultsAreCached = true }
    busy = true; message = nil; needsSessionCheck = false
    defer { if current == generation { busy = false } }
    do {
      let result = try await client.query(campus: campus, date: date)
      guard current == generation else { return }
      rooms = result; queried = true; resultsAreCached = false; fetchedAt = Date()
      cachedQueries[key] = CachedQuery(rooms: result, fetchedAt: fetchedAt!)
      if let account {
        try? await cache.save(ClassroomCacheEntry(
          key: key, campus: campus, date: date, rooms: result, fetchedAt: fetchedAt!
        ), account: account)
      }
      if cachedQueries.count > 12, let oldest = cachedQueries.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key {
        cachedQueries.removeValue(forKey: oldest)
      }
    } catch {
      guard current == generation else { return }
      AppLog.network.error("空教室查询失败")
      message = error.localizedDescription
      if case ScheduleError.sessionExpired = error { needsSessionCheck = true }
    }
  }
}

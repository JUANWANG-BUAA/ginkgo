import Foundation

struct ClassroomCacheEntry: Codable {
  let key: String
  let campus: Int
  let date: Date
  let rooms: [String: [FreeClassroom]]
  let fetchedAt: Date
}

/// 按“校区 + 日期”保存空教室结果，最多保留最近的 12 组查询。
actor ClassroomCache {
  private let store: LocalStore
  private let maximumQueries = 12

  init(directory: URL? = nil) {
    store = LocalStore(module: "Classrooms", directory: directory)
  }

  func read(account: String) -> [ClassroomCacheEntry] {
    store.read([ClassroomCacheEntry].self, account: account) ?? []
  }

  func save(_ entry: ClassroomCacheEntry, account: String) throws {
    var entries = read(account: account)
    entries.removeAll { $0.key == entry.key }
    entries.append(entry)
    entries.sort { $0.fetchedAt > $1.fetchedAt }
    try store.write(Array(entries.prefix(maximumQueries)), account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

enum ClassroomSort: String, CaseIterable, Identifiable, Sendable {
  case name = "教室名称"
  case availability = "空闲节数优先"
  case consecutive = "连续空闲优先"
  var id: String { rawValue }
}

private struct IndexedClassroom: Sendable {
  let room: FreeClassroom
  let normalizedName: String
}

private struct ClassroomResultSummary: Sendable {
  var roomCount = 0
  var buildingCount = 0
  var freeSlotCount = 0
}

private struct ClassroomFilterInput: Sendable {
  let sourceRooms: [String: [FreeClassroom]]?
  let indexedRooms: [String: [IndexedClassroom]]?
  let search: String
  let section: Int
  let minimumFreeSections: Int
  let minimumConsecutiveSections: Int
  let building: String?
  let sort: ClassroomSort
}

private struct ClassroomFilterOutput: Sendable {
  let filtered: [String: [FreeClassroom]]
  let index: [String: [IndexedClassroom]]?
  let summary: ClassroomResultSummary
}

private enum ClassroomResultProcessor {
  static func process(_ input: ClassroomFilterInput) -> ClassroomFilterOutput {
    let index: [String: [IndexedClassroom]]
    let shouldReturnIndex = input.indexedRooms == nil
    if let indexedRooms = input.indexedRooms {
      index = indexedRooms
    } else {
      var prepared: [String: [IndexedClassroom]] = [:]
      for (building, rooms) in input.sourceRooms ?? [:] {
        var entries: [IndexedClassroom] = []
        entries.reserveCapacity(rooms.count)
        for room in rooms {
          guard !Task.isCancelled else {
            return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
          }
          entries.append(IndexedClassroom(room: room, normalizedName: normalizedSearch(room.name)))
        }
        prepared[building] = entries
      }
      index = prepared
    }

    let term = normalizedSearch(input.search.trimmingCharacters(in: .whitespacesAndNewlines))
    var filtered: [String: [FreeClassroom]] = [:]
    var summary = ClassroomResultSummary()

    for (building, entries) in index {
      guard !Task.isCancelled else {
        return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
      }
      if let selectedBuilding = input.building, selectedBuilding != building { continue }
      let matchesBuilding = normalizedSearch(building).contains(term)
      var matches: [FreeClassroom] = []
      matches.reserveCapacity(entries.count)
      for entry in entries {
        guard !Task.isCancelled else {
          return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
        }
        let room = entry.room
        let matchesSearch = term.isEmpty || matchesBuilding || entry.normalizedName.contains(term)
        let matchesSection = input.section == 0 || room.isAvailable(at: input.section)
        guard matchesSearch, matchesSection,
              room.availableSectionCount >= input.minimumFreeSections,
              room.longestFreeRun >= input.minimumConsecutiveSections else { continue }
        matches.append(room)
      }

      matches.sort { lhs, rhs in
        if input.sort == .availability, lhs.availableSectionCount != rhs.availableSectionCount {
          return lhs.availableSectionCount > rhs.availableSectionCount
        }
        if input.sort == .consecutive, lhs.longestFreeRun != rhs.longestFreeRun {
          return lhs.longestFreeRun > rhs.longestFreeRun
        }
        let order = lhs.name.localizedStandardCompare(rhs.name)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
      }
      guard !Task.isCancelled else {
        return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
      }
      guard !matches.isEmpty else { continue }
      filtered[building] = matches
      summary.roomCount += matches.count
      summary.buildingCount += 1
      summary.freeSlotCount += matches.reduce(0) { $0 + $1.availableSectionCount }
    }

    return ClassroomFilterOutput(
      filtered: filtered,
      index: shouldReturnIndex ? index : nil,
      summary: summary
    )
  }

  private static func normalizedSearch(_ value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(scalars))
  }
}

@MainActor
final class ClassroomViewModel: ObservableObject {
  @Published var campus = 1 { didSet { if campus != oldValue { reset() } } }
  @Published var date = Date() { didSet { if !SchoolTime.calendar.isDate(date, inSameDayAs: oldValue) { reset() } } }
  @Published var search = "" { didSet { updateResults(debounceSearch: true) } }
  @Published var section = 0 { didSet { updateResults() } }
  @Published var minimumFreeSections = 0 { didSet { updateResults() } }
  @Published var minimumConsecutiveSections = 0 { didSet { updateResults() } }
  @Published var building: String? { didSet { updateResults() } }
  @Published var sort: ClassroomSort = .name { didSet { updateResults() } }
  @Published private(set) var rooms: [String: [FreeClassroom]] = [:] { didSet { updateResults(roomsChanged: true) } }
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
  private var preparedSearchIndex: [String: [IndexedClassroom]]?
  private var resultSummary = ClassroomResultSummary()
  private var resultUpdateGeneration = 0
  private var resultUpdateTask: Task<Void, Never>?
  private var resultComputationTask: Task<ClassroomFilterOutput, Never>?

  private var queryKey: String {
    let components = SchoolTime.calendar.dateComponents([.year, .month, .day], from: date)
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

  private func updateResults(roomsChanged: Bool = false, debounceSearch: Bool = false) {
    if roomsChanged { preparedSearchIndex = nil }
    resultUpdateGeneration &+= 1
    let current = resultUpdateGeneration
    resultUpdateTask?.cancel()
    resultComputationTask?.cancel()

    let input = ClassroomFilterInput(
      sourceRooms: preparedSearchIndex == nil ? rooms : nil,
      indexedRooms: preparedSearchIndex,
      search: search,
      section: section,
      minimumFreeSections: minimumFreeSections,
      minimumConsecutiveSections: minimumConsecutiveSections,
      building: building,
      sort: sort
    )

    resultUpdateTask = Task { [weak self] in
      if debounceSearch {
        do {
          try await Task.sleep(nanoseconds: 120_000_000)
        } catch {
          return
        }
      }
      guard !Task.isCancelled, let self else { return }
      let computation = Task.detached(priority: .userInitiated) {
        ClassroomResultProcessor.process(input)
      }
      self.resultComputationTask = computation
      let output = await computation.value
      guard !Task.isCancelled, self.resultUpdateGeneration == current else { return }
      if let index = output.index { self.preparedSearchIndex = index }
      self.resultSummary = output.summary
      self.filtered = output.filtered
      self.resultRevision &+= 1
      self.resultComputationTask = nil
      self.resultUpdateTask = nil
    }
  }

  /// 等待最近一次筛选计算写入 `filtered`。
  /// 界面依赖发布属性自动刷新；测试与需要串行读取最终结果的调用方在此等待，
  /// 避免在后台计算完成前读取旧值。
  func waitForFilterUpdate() async {
    await resultUpdateTask?.value
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
        do {
          try await cache.save(ClassroomCacheEntry(
            key: key, campus: campus, date: date, rooms: result, fetchedAt: fetchedAt!
          ), account: account)
        } catch {
          AppLog.cacheWriteFailed(feature: "classrooms", error: error)
        }
      }
      if cachedQueries.count > 12, let oldest = cachedQueries.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key {
        cachedQueries.removeValue(forKey: oldest)
      }
    } catch {
      guard current == generation else { return }
      AppLog.operationFailed(feature: "classrooms", stage: "query", error: error)
      message = error.localizedDescription
      if case ScheduleError.sessionExpired = error { needsSessionCheck = true }
    }
  }
}

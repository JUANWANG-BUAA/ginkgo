import Foundation

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
  private let repository: ClassroomRepository
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
    if let account = overrideAccount ?? account { try await repository.clearCache(account: account) }
    cachedQueries = [:]
    reset()
  }

  init(repository: ClassroomRepository) {
    self.repository = repository
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    cachedQueries = [:]
    self.account = account
    isLoadingCache = true
    defer { isLoadingCache = false }
    let loadGeneration = generation
    let entries = await repository.cachedQueries(account: account)
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
      let result = try await repository.query(campus: campus, date: date)
      guard current == generation else { return }
      let fetchedAt = Date()
      rooms = result; queried = true; resultsAreCached = false; self.fetchedAt = fetchedAt
      let entry = ClassroomCacheEntry(
        key: key, campus: campus, date: date, rooms: result, fetchedAt: fetchedAt
      )
      cachedQueries[key] = CachedQuery(rooms: result, fetchedAt: fetchedAt)
      if let account {
        do {
          try await repository.save(entry, account: account)
        } catch {
          AppLog.cacheWriteFailed(feature: "classrooms", error: error)
        }
      }
      if cachedQueries.count > ClassroomCachePolicy.maximumQueries,
         let oldest = cachedQueries.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key {
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

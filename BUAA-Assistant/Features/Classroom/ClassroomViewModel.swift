import Foundation

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
  @Published private(set) var busy = false
  @Published private(set) var queried = false
  @Published private(set) var message: String?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var needsSessionCheck = false
  private let client: ClassroomServing
  private var generation = 0
  private struct CachedQuery {
    let rooms: [String: [FreeClassroom]]
    let fetchedAt: Date
  }
  private var cachedQueries: [String: CachedQuery] = [:]
  private var queryKey: String {
    let components = ScheduleSnapshot.schoolCalendar.dateComponents([.year, .month, .day], from: date)
    return "\(campus)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  func clearCache() { cachedQueries = [:]; reset() }

  init(client: ClassroomServing = ClassroomClient()) { self.client = client }

  private func updateResults() {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    filtered = rooms.reduce(into: [:]) { result, entry in
      guard building == nil || building == entry.key else { return }
      let matchesBuilding = entry.key.localizedCaseInsensitiveContains(term)
      let matches = entry.value.filter { room in
        (term.isEmpty || matchesBuilding || room.name.localizedCaseInsensitiveContains(term)) &&
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
      if !matches.isEmpty { result[entry.key] = matches }
    }
  }

  var hasActiveFilters: Bool {
    !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || section != 0 ||
      minimumFreeSections != 0 || minimumConsecutiveSections != 0 || building != nil
  }

  var roomCount: Int { rooms.values.reduce(0) { $0 + $1.count } }
  var filteredRoomCount: Int { filtered.values.reduce(0) { $0 + $1.count } }
  var buildingCount: Int { filtered.keys.count }
  var freeSlotCount: Int { filtered.values.flatMap { $0 }.reduce(0) { $0 + $1.availableSectionCount } }

  func reset() {
    generation += 1
    rooms = [:]; queried = false; fetchedAt = nil; message = nil
    building = nil
    busy = false; needsSessionCheck = false
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
      if !forceRefresh && Date().timeIntervalSince(cached.fetchedAt) < 300 {
        message = nil
        return
      }
    }
    generation += 1
    let current = generation
    busy = true; message = nil; needsSessionCheck = false
    defer { if current == generation { busy = false } }
    do {
      let result = try await client.query(campus: campus, date: date)
      guard current == generation else { return }
      rooms = result; queried = true; fetchedAt = Date()
      cachedQueries[key] = CachedQuery(rooms: result, fetchedAt: fetchedAt!)
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

import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
  @Published var libraries: [LibraryItem] = []
  @Published var areas: [LibraryItem] = []
  @Published var slots: [LibrarySlot] = []
  @Published var seats: [LibraryItem] = []
  @Published private(set) var filteredSeats: [LibraryItem] = []
  @Published var bookings: [LibraryBooking] = []
  @Published private(set) var currentBookings: [LibraryBooking] = []
  @Published private(set) var loadedCurrentBookings = false
  @Published private(set) var isLoadingCurrentBookings = false
  @Published private(set) var currentBookingsError: String?
  @Published var libraryID = ""
  @Published var areaID = ""
  @Published var slotID = ""
  @Published var busy = false
  @Published var message: String?
  @Published var failed = false
  @Published var loadedBookings = false
  @Published var loadedSeats = false
  @Published private(set) var isLoadingBookings = false
  @Published private(set) var isRefreshingSeats = false
  @Published private(set) var bookingPage = 1
  @Published private(set) var bookingPageSize = 40
  @Published private(set) var bookingTotal: Int?
  @Published private(set) var bookingHasNext = false
  @Published private(set) var seatsFetchedAt: Date?
  @Published private(set) var seatsAreCached = false
  @Published private(set) var seatsCacheIsPartial = false
  @Published private(set) var publicStats: LibraryPublicStats?
  @Published private(set) var publicStatsAreCached = false
  @Published private(set) var publicStatsError: String?
  @Published private(set) var refreshingPublicStats = false
  private let client = LibraryClient()
  private let cache = LibraryCache()
  private let publicStatsClient = LibraryPublicStatsClient()
  private let occupancyHistory = LibraryOccupancyHistory()
  private var account: String?
  private var librariesFetchedAt: Date?
  private var seatFilterGeneration = 0
  private var seatFilterTask: Task<Void, Never>?
  private var seatFilterWork: Task<[LibraryItem], Never>?
  var selectedSlot: LibrarySlot? { slots.first { $0.id == slotID } }

  /// 历史列表里剔除仍在进行中的记录，避免“我的预约”重复展示。
  var historyBookings: [LibraryBooking] {
    let currentIDs = Set(currentBookings.map(\.id))
    return bookings.filter { !currentIDs.contains($0.id) }
  }

  func start(account: String) async {
    if self.account != account {
      reset()
      self.account = account
      if let snapshot = await cache.read(account: account) {
        libraries = snapshot.libraries
        libraryID = snapshot.libraryID
        areas = snapshot.areas
        areaID = snapshot.areaID
        slots = snapshot.slots
        slotID = snapshot.slotID
        seats = snapshot.seats
        filteredSeats = snapshot.seats
        seatsFetchedAt = snapshot.seatsFetchedAt
        loadedSeats = !snapshot.seats.isEmpty
        seatsAreCached = loadedSeats
        seatsCacheIsPartial = snapshot.seatsAreTruncated
        publicStats = snapshot.publicStats
        publicStatsAreCached = snapshot.publicStats != nil
        librariesFetchedAt = snapshot.fetchedAt
      }
    }

    await refreshIfStale()
  }

  /// 页面重新出现或应用回到前台时调用：按时效刷新楼馆列表与官网公开实时数据。
  /// 实时人数变化快，聚焦时按 5 分钟时效刷新；楼馆列表 15 分钟内不重复请求。
  func refreshIfStale(maxPublicStatsAge: TimeInterval = 5 * 60) async {
    if libraries.isEmpty || librariesFetchedAt.map({ Date().timeIntervalSince($0) >= 15 * 60 }) ?? true {
      await loadLibraries()
    }
    if publicStats == nil || publicStats.map({ Date().timeIntervalSince($0.fetchedAt) >= maxPublicStatsAge }) ?? true {
      await refreshPublicStats()
    }
  }

  func reset() {
    cancelSeatFiltering()
    libraries = []; areas = []; slots = []; seats = []; bookings = []; currentBookings = []
    libraryID = ""; areaID = ""; slotID = ""
    busy = false; message = nil; failed = false
    loadedBookings = false; loadedSeats = false; isLoadingBookings = false; isRefreshingSeats = false
    loadedCurrentBookings = false; isLoadingCurrentBookings = false; currentBookingsError = nil
    bookingPage = 1; bookingTotal = nil; bookingHasNext = false
    seatsFetchedAt = nil; seatsAreCached = false
    filteredSeats = []; seatsCacheIsPartial = false
    publicStats = nil; publicStatsAreCached = false; publicStatsError = nil; refreshingPublicStats = false
    account = nil; librariesFetchedAt = nil
  }

  func clearCache(account overrideAccount: String? = nil) async throws {
    if let account = overrideAccount ?? account { try await cache.clear(account: account) }
    occupancyHistory.clear()
    reset()
  }

  func applySeatFilter(search: String, onlyAvailable: Bool, debounceSearch: Bool = false) {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = seats
    seatFilterGeneration &+= 1
    let current = seatFilterGeneration
    seatFilterTask?.cancel()
    seatFilterWork?.cancel()
    seatFilterTask = Task { [weak self] in
      if debounceSearch, !term.isEmpty {
        do { try await Task.sleep(nanoseconds: 120_000_000) }
        catch { return }
      }
      guard !Task.isCancelled, let self else { return }
      let work = Task.detached(priority: .userInitiated) {
        var filtered: [LibraryItem] = []
        filtered.reserveCapacity(min(source.count, 128))
        for seat in source {
          guard !Task.isCancelled else { return [LibraryItem]() }
          if (!onlyAvailable || seat.available) && (term.isEmpty || seat.name.localizedCaseInsensitiveContains(term)) {
            filtered.append(seat)
          }
        }
        return filtered
      }
      self.seatFilterWork = work
      let filtered = await work.value
      guard !Task.isCancelled, self.seatFilterGeneration == current else { return }
      self.filteredSeats = filtered
      self.seatFilterWork = nil
      self.seatFilterTask = nil
    }
  }

  func clearSeatResults() {
    cancelSeatFiltering()
    seats = []; filteredSeats = []; loadedSeats = false
    seatsFetchedAt = nil; seatsAreCached = false; seatsCacheIsPartial = false
  }

  private func cancelSeatFiltering() {
    seatFilterGeneration &+= 1
    seatFilterTask?.cancel()
    seatFilterWork?.cancel()
    seatFilterTask = nil
    seatFilterWork = nil
  }

  func run(stage: String = "action", _ work: () async throws -> Void) async {
    guard !busy else { return }
    busy = true; message = nil; failed = false
    defer { busy = false }
    do { try await work() } catch {
      if RequestCancellation.isCancellation(error) { return }
      AppLog.operationFailed(feature: "library", stage: stage, error: error)
      failed = true
      message = error.localizedDescription
    }
  }
  func loadLibraries() async {
    await run(stage: "libraries") {
      let refreshedLibraries = try await client.libraries(day: SchoolTime.dayString())
      libraries = refreshedLibraries
      if !libraries.contains(where: { $0.id == libraryID }) {
        libraryID = ""; areaID = ""; slotID = ""; areas = []; slots = []
        clearSeatResults()
      }
      librariesFetchedAt = Date()
      message = libraries.isEmpty ? "今天暂无可查询楼馆" : "楼馆已更新"
      await persistCache()
    }
  }
  func loadAreas() async {
    areaID = ""; slotID = ""; areas = []; slots = []
    clearSeatResults()
    guard !libraryID.isEmpty else { return }
    await run(stage: "areas") {
      areas = try await client.areas(library: libraryID, day: SchoolTime.dayString())
      if areas.isEmpty { message = "该楼馆暂无可查询分区" }
      await persistCache()
    }
  }
  func loadSlots() async {
    slotID = ""; slots = []
    clearSeatResults()
    guard !areaID.isEmpty else { return }
    await run(stage: "slots") {
      let allSlots = try await client.slots(area: areaID)
      if let current = Self.currentSlot(in: allSlots, at: Date()) {
        slots = [current]
        slotID = current.id
        message = "已定位到当前时段：\(current.start)–\(current.end)"
      } else {
        slots = []
        slotID = ""
        message = "当前没有可预约时段"
      }
      await persistCache()
    }
  }
  func loadSeats(search: String = "", onlyAvailable: Bool = false) async {
    guard let slot = selectedSlot else { return }
    guard Self.currentSlot(in: slots, at: Date())?.id == slot.id else {
      await loadSlots()
      message = selectedSlot == nil ? "当前没有可预约时段" : "当前时段已更新，请重新查询座位"
      return
    }
    isRefreshingSeats = true
    defer { isRefreshingSeats = false }
    await run(stage: "seats") {
      let refreshedSeats = try await client.seats(area: areaID, slot: slot)
      seats = refreshedSeats
      loadedSeats = true
      seatsAreCached = false
      seatsCacheIsPartial = false
      seatsFetchedAt = Date()
      applySeatFilter(search: search, onlyAvailable: onlyAvailable)
      await persistCache()
    }
    guard loadedSeats, !failed else { return }
    occupancyHistory.record(
      areaID: areaID,
      availableSeats: seats.filter(\.available).count,
      totalSeats: seats.count
    )
  }
  func loadBookings(page: Int = 1) async {
    guard !isLoadingBookings else { return }
    let targetPage = max(1, page)
    let samePage = loadedBookings && targetPage == bookingPage
    if !samePage {
      bookings = []
      loadedBookings = false
    }
    isLoadingBookings = true
    message = nil
    failed = false
    defer { isLoadingBookings = false }
    do {
      let result = try await client.bookings(page: targetPage, limit: bookingPageSize)
      bookings = result.items
      bookingPage = result.page
      bookingPageSize = result.pageSize
      bookingTotal = result.total
      bookingHasNext = result.hasNext
      loadedBookings = true
      message = "预约记录已更新"
    } catch {
      AppLog.operationFailed(feature: "library", stage: "bookings", error: error)
      failed = true
      message = error.localizedDescription
    }
  }

  func loadCurrentBookings() async {
    guard !isLoadingCurrentBookings else { return }
    isLoadingCurrentBookings = true
    defer { isLoadingCurrentBookings = false }
    do {
      currentBookings = try await client.currentBookings()
      loadedCurrentBookings = true
      currentBookingsError = nil
    } catch {
      AppLog.operationFailed(feature: "library", stage: "current_bookings", error: error)
      currentBookingsError = error.localizedDescription
    }
  }

  func refreshMyBookings(page: Int = 1) async {
    await loadCurrentBookings()
    await loadBookings(page: page)
  }

  func perform(_ action: LibrarySeatAction, on booking: LibraryBooking) async {
    guard !busy else { return }
    let hadUncertainResult: Bool
    await run(stage: "seat_\(action.rawValue)") {
      try await client.perform(action, bookingID: booking.id)
    }
    hadUncertainResult = failed && message?.contains("待核实") == true
    await loadCurrentBookings()
    if failed {
      if hadUncertainResult {
        message = "\(action.title)结果待核实：已刷新“我的预约”，请以学校状态为准，勿重复提交"
      }
    } else {
      message = currentBookings.contains(where: { $0.id == booking.id })
        ? "\(action.title)已提交，学校状态已刷新"
        : "\(action.title)已提交，学校已结束该预约"
    }
  }

  func refreshPublicStats() async {
    guard !refreshingPublicStats else { return }
    refreshingPublicStats = true
    defer { refreshingPublicStats = false }
    do {
      let snapshot = try await publicStatsClient.fetch()
      publicStats = snapshot
      publicStatsAreCached = false
      publicStatsError = nil
      occupancyHistory.recordPeople(snapshot)
      await persistCache()
    } catch {
      AppLog.operationFailed(feature: "library", stage: "public_stats", error: error)
      publicStatsError = error.localizedDescription
    }
  }
  func reserve(_ seat: LibraryItem) async {
    guard let slot = selectedSlot else { return }
    guard Self.currentSlot(in: slots, at: Date())?.id == slot.id else {
      await loadSlots()
      message = selectedSlot == nil ? "当前没有可预约时段，未提交预约" : "预约时段已变化，未提交预约；请重新查询座位"
      return
    }
    await run(stage: "reserve") {
      try await client.reserve(seat: seat.id, slot: slot)
      message = "学校已确认预约成功，请到我的预约查看"
      clearSeatResults()
      await persistCache()
    }
    if !failed { await loadCurrentBookings() }
  }
  func cancel(_ booking: LibraryBooking) async {
    guard booking.canCancel() else { return }
    let page = bookingPage
    await run(stage: "cancel") {
      try await client.cancel(booking)
      message = "预约已取消"
      loadedBookings = false
      bookings = []
    }
    await loadCurrentBookings()
    if !failed {
      await loadBookings(page: page)
      if page > 1 && bookings.isEmpty { await loadBookings(page: page - 1) }
      if !failed { message = "预约已取消" }
    }
  }

  private func persistCache() async {
    guard let account else { return }
    let snapshot = LibraryCacheSnapshot(
      libraries: libraries, libraryID: libraryID, areas: areas, areaID: areaID,
      slots: slots, slotID: slotID, seats: seats, seatsAreTruncated: seatsCacheIsPartial,
      seatsFetchedAt: seatsFetchedAt,
      publicStats: publicStats, fetchedAt: librariesFetchedAt ?? Date()
    )
    do { try await cache.save(snapshot, account: account) }
    catch { AppLog.cacheWriteFailed(feature: "library", error: error) }
  }

  func occupancySampleCount(weekday: Int, hour: Int) -> Int {
    occupancyHistory.sampleCount(areaID: areaID, weekday: weekday, hour: hour)
  }

  func occupancyForecast(weekday: Int, hour: Int) -> LibraryOccupancyForecast? {
    guard let total = areas.first(where: { $0.id == areaID })?.totalCount else { return nil }
    return occupancyHistory.forecast(areaID: areaID, weekday: weekday, hour: hour, totalSeats: total)
  }

  func occupancyTrend(weekday: Int) -> [LibraryOccupancyTrendPoint] {
    occupancyHistory.trend(areaID: areaID, weekday: weekday)
  }

  func peopleSampleCount(campusID: String, weekday: Int, hour: Int) -> Int {
    occupancyHistory.peopleSampleCount(campusID: campusID, weekday: weekday, hour: hour)
  }

  func peopleForecast(campusID: String, weekday: Int, hour: Int) -> LibraryPeopleForecast? {
    occupancyHistory.peopleForecast(campusID: campusID, weekday: weekday, hour: hour)
  }

  func peopleTrend(campusID: String, weekday: Int) -> [LibraryPeopleTrendPoint] {
    occupancyHistory.peopleTrend(campusID: campusID, weekday: weekday)
  }

  private static func currentSlot(in slots: [LibrarySlot], at date: Date) -> LibrarySlot? {
    let today = SchoolTime.dayString(date).filter(\.isNumber)
    let now = SchoolTime.minutesSinceMidnight(date)
    return slots.first { slot in
      guard slot.day.filter(\.isNumber) == today,
            let start = SchoolTime.minutes(fromClock: slot.start),
            let end = SchoolTime.minutes(fromClock: slot.end) else { return false }
      return start <= now && now < end
    }
  }
}

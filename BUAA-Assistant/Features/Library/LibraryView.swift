import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
  @Published var libraries: [LibraryItem] = []
  @Published var areas: [LibraryItem] = []
  @Published var slots: [LibrarySlot] = []
  @Published var seats: [LibraryItem] = []
  @Published var bookings: [LibraryItem] = []
  @Published var libraryID = ""
  @Published var areaID = ""
  @Published var slotID = ""
  @Published var busy = false
  @Published var message: String?
  @Published var failed = false
  @Published var loadedBookings = false
  @Published var loadedSeats = false
  private let client = LibraryClient()
  var selectedSlot: LibrarySlot? { slots.first { $0.id == slotID } }

  func run(_ work: () async throws -> Void) async {
    guard !busy else { return }
    busy = true; message = nil; failed = false
    defer { busy = false }
    do { try await work() } catch { failed = true; message = error.localizedDescription }
  }
  func loadLibraries() async {
    await run {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
      let day = formatter.string(from: Date())
      libraries = try await client.libraries(day: day)
      libraryID = ""; areaID = ""; slotID = ""; areas = []; slots = []; seats = []; loadedSeats = false
      message = libraries.isEmpty ? "所选日期暂无可查询楼馆" : "楼馆已更新"
    }
  }
  func loadAreas() async {
    areaID = ""; slotID = ""; areas = []; slots = []; seats = []; loadedSeats = false
    guard !libraryID.isEmpty else { return }
    await run {
      let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
      areas = try await client.areas(library: libraryID, day: formatter.string(from: Date()))
      if areas.isEmpty { message = "该楼馆暂无可查询分区" }
    }
  }
  func loadSlots() async {
    slotID = ""; slots = []; seats = []; loadedSeats = false
    guard !areaID.isEmpty else { return }
    await run { slots = try await client.slots(area: areaID); if slots.isEmpty { message = "该分区暂无可预约时段" } }
  }
  func loadSeats() async {
    seats = []; loadedSeats = false
    guard let slot = selectedSlot else { return }
    await run { seats = try await client.seats(area: areaID, slot: slot); loadedSeats = true }
  }
  func loadBookings() async {
    await run { bookings = try await client.bookings(); loadedBookings = true; message = "预约记录已更新（前 100 条）" }
  }
  func reserve(_ seat: LibraryItem) async {
    guard let slot = selectedSlot else { return }
    await run {
      try await client.reserve(seat: seat.id, slot: slot)
      message = "学校已确认预约成功，请到我的预约查看"
      seats = []; loadedSeats = false
    }
  }
  func cancel(_ booking: LibraryItem) async {
    await run { try await client.cancel(id: booking.id); message = "学校已确认取消，请刷新预约记录"; loadedBookings = false; bookings = [] }
  }
}

struct LibraryView: View {
  @StateObject private var model = LibraryViewModel()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var seatSearch = ""
  @State private var onlyAvailable = false
  @State private var tab = "选择座位"
  @State private var pendingSeat: LibraryItem?
  @State private var pendingCancellation: LibraryItem?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "CAMPUS / LIBRARY", title: "图书馆", subtitle: "按楼馆、分区与时段查询座位，管理自己的预约")
        Picker("页面", selection: $tab) {
          Text("选择座位").tag("选择座位"); Text("我的预约").tag("我的预约")
        }.pickerStyle(.segmented).frame(width: 280)
        if let message = model.message { StatusNotice(message: message, kind: model.failed ? .warning : .information) }
        if model.busy { ProgressView("正在连接图书馆…") }
        if tab == "选择座位" {
          QueryFlowSteps(titles: ["楼馆", "分区", "时段", "座位"], current: model.libraryID.isEmpty ? 0 : (model.areaID.isEmpty ? 1 : (model.slotID.isEmpty ? 2 : 3)))
          selectors
          if model.loadedSeats {
            SearchField(prompt: "搜索座位名称", text: $seatSearch)
            HStack {
              Toggle("只看可预约", isOn: $onlyAvailable)
              Spacer()
              Text("显示 \(visibleSeats.count) / \(model.seats.count) 个座位").font(.caption).foregroundStyle(.secondary)
            }
            if !model.seats.isEmpty && visibleSeats.isEmpty {
              PageEmptyState(symbol: "magnifyingglass", title: "没有匹配的座位", detail: "清除搜索或关闭可预约筛选后重试。")
              Button("清除座位筛选") { seatSearch = ""; onlyAvailable = false }
            }
          }
          Text("选择分区后显示学校提供的日期和时段。研讨室是否可用，以学校分区列表及预约规则为准。")
            .font(.caption).foregroundStyle(.secondary)
          if model.loadedSeats && model.seats.isEmpty {
            PageEmptyState(symbol: "chair", title: "该时段暂无座位", detail: "可以更换分区或时段。")
          }
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 12) {
            ForEach(visibleSeats) { seat in
              Button { pendingSeat = seat } label: {
                VStack(spacing: 8) {
                  Image(systemName: "chair.fill").font(.title2)
                  Text(seat.name).font(.headline)
                  Text(seat.detail.isEmpty ? (seat.available ? "可预约" : "不可用") : seat.detail).font(.caption)
                }.frame(maxWidth: .infinity).padding(14)
                  .background(seat.available ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
              }.buttonStyle(.plain).disabled(!seat.available || model.busy)
            }
          }
        } else {
          Button("刷新我的预约") { Task { await model.loadBookings() } }.disabled(model.busy)
          if model.loadedBookings && model.bookings.isEmpty {
            PageEmptyState(symbol: "ticket", title: "暂无预约记录", detail: "学校已成功返回预约列表。")
          }
          ProgressiveList(items: model.bookings, pageSize: 40) { booking in
            HStack {
              VStack(alignment: .leading, spacing: 6) { Text(booking.name).font(.headline); Text(booking.detail).font(.caption).foregroundStyle(.secondary) }
              Spacer()
              Button("取消预约", role: .destructive) { pendingCancellation = booking }.disabled(model.busy)
            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
          }
        }
      }.padding(24).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
    }.background(Color(nsColor: .windowBackgroundColor))
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: tab)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.busy)
      .task { await model.loadLibraries() }
      .onChange(of: tab) { _, value in if value == "我的预约" { Task { await model.loadBookings() } } }
      .alert("确认预约？", isPresented: Binding(get: { pendingSeat != nil }, set: { if !$0 { pendingSeat = nil } })) {
        Button("确认预约") { if let seat = pendingSeat { Task { await model.reserve(seat) } }; pendingSeat = nil }
        Button("取消", role: .cancel) { pendingSeat = nil }
      } message: { Text("座位：\(pendingSeat?.name ?? "")\n\(model.selectedSlot?.title ?? "")") }
      .alert("取消这条预约？", isPresented: Binding(get: { pendingCancellation != nil }, set: { if !$0 { pendingCancellation = nil } })) {
        Button("确认取消预约", role: .destructive) { if let booking = pendingCancellation { Task { await model.cancel(booking) } }; pendingCancellation = nil }
        Button("保留预约", role: .cancel) { pendingCancellation = nil }
      } message: { Text(pendingCancellation?.detail ?? "") }
  }

  private var visibleSeats: [LibraryItem] {
    let term = seatSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    return model.seats.filter { (!onlyAvailable || $0.available) && (term.isEmpty || $0.name.localizedCaseInsensitiveContains(term)) }
  }

  private var selectors: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Picker("楼馆", selection: $model.libraryID) { Text("请选择楼馆").tag(""); ForEach(model.libraries) { Text($0.name + " · " + $0.detail).tag($0.id) } }
        Button("刷新") { Task { await model.loadLibraries() } }
      }
      Picker("分区", selection: $model.areaID) { Text("请选择分区").tag(""); ForEach(model.areas) { Text($0.name + " · " + $0.detail).tag($0.id) } }.disabled(model.libraryID.isEmpty || model.areas.isEmpty)
      Picker("日期与时段", selection: $model.slotID) { Text("请选择时段").tag(""); ForEach(model.slots) { Text($0.title).tag($0.id) } }.disabled(model.areaID.isEmpty || model.slots.isEmpty)
      Button("查询座位") { Task { await model.loadSeats() } }.buttonStyle(.borderedProminent).disabled(model.selectedSlot == nil)
    }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .disabled(model.busy)
      .onChange(of: model.libraryID) { _, _ in Task { await model.loadAreas() } }
      .onChange(of: model.areaID) { _, _ in Task { await model.loadSlots() } }
      .onChange(of: model.slotID) { _, _ in model.seats = []; model.loadedSeats = false }
  }
}

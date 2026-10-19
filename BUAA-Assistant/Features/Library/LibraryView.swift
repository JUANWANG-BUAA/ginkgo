import SwiftUI
import Charts

struct LibraryView: View {
  @EnvironmentObject private var model: LibraryViewModel
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var seatSearch = ""
  @State private var onlyAvailable = false
  @State private var tab = "选择座位"
  @State private var pendingSeat: LibraryItem?
  @State private var pendingCancellation: LibraryBooking?
  @State private var pendingSeatAction: PendingLibrarySeatAction?
  @State private var forecastWeekday = LibraryOccupancyHistory.currentWeekday
  @State private var forecastHour = LibraryOccupancyHistory.currentHour
  @State private var selectedTrendHour: Int?
  @State private var peopleCampusID = "xylxq"
  @State private var peopleWeekday = LibraryOccupancyHistory.currentWeekday
  @State private var peopleHour = LibraryOccupancyHistory.currentHour
  @State private var selectedPeopleTrendHour: Int?
  @State private var seatPage = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "CAMPUS / LIBRARY", title: "图书馆", subtitle: "选择楼馆与分区，查询当前可预约座位并管理预约")
        publicStatsPanel
        Picker("页面", selection: $tab) {
          Text("选择座位").tag("选择座位"); Text("我的预约").tag("我的预约")
        }.pickerStyle(.segmented).frame(width: 280)
        if let message = model.message { StatusNotice(message: message, kind: model.failed ? .warning : .information) }
        if model.busy {
          Label(model.loadedSeats ? "正在更新 · 保留上次结果" : "正在连接图书馆…", systemImage: "arrow.clockwise")
            .font(.caption).foregroundStyle(.secondary)
        }
        if tab == "选择座位" { seatSelectionContent } else { bookingContent }
      }.ginkgoPagePadding().frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
    }.background(Color.ginkgoWindowBackground)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: tab)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.busy)
      .task(id: "\(appState.user?.schoolid ?? "")|\(scenePhase == .active)") {
        guard let account = appState.user?.schoolid else { return }
        await model.start(account: account)
        model.applySeatFilter(search: seatSearch, onlyAvailable: onlyAvailable)
        guard scenePhase == .active else { return }
        while !Task.isCancelled {
          do { try await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) }
          catch { return }
          guard !Task.isCancelled else { return }
          await model.refreshPublicStats()
        }
      }
      .onChange(of: tab) { _, value in
        openBookingsIfNeeded(for: value)
      }
      .onChange(of: seatSearch) { _, _ in
        seatPage = 0
        model.applySeatFilter(search: seatSearch, onlyAvailable: onlyAvailable, debounceSearch: true)
      }
      .onChange(of: onlyAvailable) { _, _ in
        seatPage = 0
        model.applySeatFilter(search: seatSearch, onlyAvailable: onlyAvailable)
      }
      .onChange(of: model.seatsFetchedAt) { _, _ in seatPage = 0 }
      .alert("确认预约？", isPresented: Binding(get: { pendingSeat != nil }, set: { if !$0 { pendingSeat = nil } })) {
        Button("确认预约") { if let seat = pendingSeat { Task { await model.reserve(seat) } }; pendingSeat = nil }
        Button("取消", role: .cancel) { pendingSeat = nil }
      } message: { Text("座位：\(pendingSeat?.name ?? "")\n\(model.selectedSlot?.title ?? "")") }
      .alert("取消这条预约？", isPresented: Binding(get: { pendingCancellation != nil }, set: { if !$0 { pendingCancellation = nil } })) {
        Button("确认取消预约", role: .destructive) { if let booking = pendingCancellation { Task { await model.cancel(booking) } }; pendingCancellation = nil }
        Button("保留预约", role: .cancel) { pendingCancellation = nil }
      } message: { Text(pendingCancellation?.detail ?? "") }
      .alert(pendingSeatAction?.action.confirmationTitle ?? "确认操作？", isPresented: Binding(
        get: { pendingSeatAction != nil },
        set: { if !$0 { pendingSeatAction = nil } }
      )) {
        Button(seatActionButtonTitle(pendingSeatAction), role: pendingSeatAction?.action == .checkout ? .destructive : nil) {
          if let pending = pendingSeatAction {
            Task { await model.perform(pending.action, on: pending.booking) }
          }
          pendingSeatAction = nil
        }
        Button("取消", role: .cancel) { pendingSeatAction = nil }
      } message: {
        Text("\(pendingSeatAction?.booking.displayTitle ?? "")\n\(pendingSeatAction.map { $0.action.confirmationMessage(for: $0.booking) } ?? "")")
      }
  }

  private var visibleSeats: [LibraryItem] {
    model.filteredSeats
  }

  private func openBookingsIfNeeded(for value: String) {
    guard value == "我的预约" else { return }
    guard !model.loadedBookings || !model.loadedCurrentBookings else { return }
    Task { await model.refreshMyBookings(page: model.bookingPage) }
  }

  private func seatActionButtonTitle(_ pending: PendingLibrarySeatAction?) -> String {
    pending.map { $0.action.buttonTitle(for: $0.booking) } ?? "确认"
  }

  @ViewBuilder
  private var seatSelectionContent: some View {
    QueryFlowSteps(titles: ["楼馆", "分区", "当前时段", "座位"], current: model.libraryID.isEmpty ? 0 : (model.areaID.isEmpty ? 1 : (model.slotID.isEmpty ? 2 : (model.loadedSeats ? 3 : 2))))
    selectors
    if !model.areas.isEmpty { areaDistribution }
    if model.loadedSeats {
      SearchField(prompt: "搜索座位名称", text: $seatSearch)
      HStack {
        Toggle("只看可预约", isOn: $onlyAvailable)
        Spacer()
        Text(seatCountSummary).font(.caption).foregroundStyle(.secondary)
      }
      if model.seatsAreCached, let fetchedAt = model.seatsFetchedAt {
        Label("缓存于 \(fetchedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock.arrow.circlepath")
          .font(.caption2).foregroundStyle(.secondary)
        if model.seatsCacheIsPartial {
          StatusNotice(message: "缓存仅含前 2,000 个座位，刷新后可查看完整列表。", kind: .warning)
        }
      }
      occupancyForecast
      if !model.seats.isEmpty && visibleSeats.isEmpty {
        PageEmptyState(symbol: "magnifyingglass", title: "没有匹配的座位", detail: "清除搜索或关闭可预约筛选后重试。")
        Button("清除座位筛选") { seatSearch = ""; onlyAvailable = false }
      }
    }
    if model.loadedSeats && model.seats.isEmpty {
      PageEmptyState(symbol: "chair", title: "当前时段暂无座位", detail: "可以更换分区后重新查询。")
    }
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 12) {
      ForEach(pageSeats) { seat in
        LibrarySeatCard(seat: seat, isBusy: model.busy) { pendingSeat = seat }
      }
    }
    if visibleSeats.count > seatPageSize {
      HStack {
        Button("上一页") { seatPage = max(0, seatPage - 1) }.disabled(seatPage == 0)
        Spacer()
        Text(seatPaginationText).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        Spacer()
        Button("下一页") { seatPage = min(seatPageCount - 1, seatPage + 1) }
          .disabled(seatPage + 1 >= seatPageCount)
      }
      .buttonStyle(.bordered)
    }
  }

  @ViewBuilder
  private var bookingContent: some View {
    HStack {
      Button("刷新我的预约") { Task { await model.refreshMyBookings(page: model.bookingPage) } }
        .disabled(model.isLoadingBookings || model.isLoadingCurrentBookings)
      Spacer()
      if model.isLoadingBookings || model.isLoadingCurrentBookings {
        ProgressView().controlSize(.small)
      }
    }

    if let error = model.currentBookingsError {
      StatusNotice(message: "进行中的预约暂时无法读取：\(error)", kind: .warning)
    }

    Text("进行中的预约")
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
    if model.loadedCurrentBookings && model.currentBookings.isEmpty {
      StatusNotice(message: "当前没有进行中的预约。已结束或已取消的记录在下方历史列表中。", kind: .information)
    }
    ForEach(model.currentBookings) { booking in
      LibraryActiveBookingCard(
        booking: booking,
        isBusy: model.busy || model.isLoadingCurrentBookings
      ) { action in
        pendingSeatAction = PendingLibrarySeatAction(booking: booking, action: action)
      } onCancel: {
        pendingCancellation = booking
      }
    }

    Text("历史记录")
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    if model.loadedBookings && model.historyBookings.isEmpty {
      PageEmptyState(symbol: "ticket", title: "暂无历史预约", detail: "学校已返回空列表。")
    }
    ForEach(model.historyBookings) { booking in
      LibraryBookingRow(booking: booking, isBusy: model.busy || model.isLoadingBookings) {
        pendingCancellation = booking
      }
    }
    if model.loadedBookings {
      HStack {
        Button("上一页") { Task { await model.loadBookings(page: max(1, model.bookingPage - 1)) } }
          .disabled(model.bookingPage <= 1 || model.isLoadingBookings)
        Spacer()
        Text(bookingPaginationText).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        Spacer()
        Button("下一页") { Task { await model.loadBookings(page: model.bookingPage + 1) } }
          .disabled(!model.bookingHasNext || model.isLoadingBookings)
      }
      .buttonStyle(.bordered)
    }
    Text("临时离开会保留座位，需在暂离时限内返回并签到；完全离开会结束本次使用。写操作提交后以学校返回状态为准，Ginkgo 不会自动重试。")
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  private let seatPageSize = 60
  private var availableSeatCount: Int { model.seats.reduce(0) { $0 + ($1.available ? 1 : 0) } }
  private var seatCountSummary: String { "可预约 \(availableSeatCount) / 共 \(model.seats.count) 个座位" }
  private var seatPageCount: Int { max(1, (visibleSeats.count + seatPageSize - 1) / seatPageSize) }
  private var seatPaginationText: String { "第 \(seatPage + 1) / \(seatPageCount) 页 · \(visibleSeats.count) 个结果" }
  private var bookingPaginationText: String {
    let totalText = model.bookingTotal.map { "共 \($0) 条" } ?? "每页 \(model.bookingPageSize) 条"
    return "第 \(model.bookingPage) 页 · \(totalText)"
  }
  private var pageSeats: [LibraryItem] {
    let safePage = min(seatPage, seatPageCount - 1)
    let start = safePage * seatPageSize
    return Array(visibleSeats.dropFirst(start).prefix(seatPageSize))
  }

  private var publicStatsPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Label("图书馆实时数据", systemImage: "person.3.fill")
          .font(.headline)
        Spacer()
        if let snapshot = model.publicStats {
          Text("\(model.publicStatsAreCached ? "缓存于" : "更新于") \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        publicStatsRefreshButton
      }

      if let snapshot = model.publicStats {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
          ForEach(snapshot.campuses) { campus in campusOccupancyCard(campus) }
        }
        DisclosureGroup {
          peopleForecastContent(snapshot)
            .padding(.top, 10)
        } label: {
          Label("人数趋势与时段估算", systemImage: "chart.xyaxis.line")
            .font(.subheadline.weight(.medium))
        }
        if let error = model.publicStatsError {
          StatusNotice(message: "官网更新失败，当前保留上次数据：\(error)", kind: .warning)
        }
      } else if model.refreshingPublicStats {
        ProgressView("正在读取官网空间数据…")
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if let error = model.publicStatsError {
        StatusNotice(message: error, kind: .warning)
      }

      HStack(alignment: .top, spacing: 8) {
        Link("官网空间数据", destination: LibraryPublicStatsSource.url)
        Text("人数来自官网实时页面，缓存值以时间为准；资源余量来自预约系统。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(18)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
  }

  private var publicStatsRefreshButton: some View {
    Button {
      Task { await model.refreshPublicStats() }
    } label: {
      if model.refreshingPublicStats {
        ProgressView().controlSize(.small)
      } else {
        Image(systemName: "arrow.clockwise")
      }
    }
    .buttonStyle(.plain)
    .disabled(model.refreshingPublicStats)
    .help("刷新图书馆实时数据")
    .accessibilityLabel("刷新图书馆实时数据")
  }

  private func campusOccupancyCard(_ campus: LibraryCampusOccupancy) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(campus.name).font(.subheadline.weight(.semibold))
        Spacer()
        Label(
          model.publicStatsAreCached ? "缓存数据" : "官网实时",
          systemImage: model.publicStatsAreCached ? "clock.arrow.circlepath" : "circle.fill"
        )
          .font(.caption2)
          .foregroundStyle(model.publicStatsAreCached ? Color.secondary : Color.green)
      }
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(campus.people.formatted())
          .font(.system(size: 32, weight: .semibold, design: .rounded))
          .monospacedDigit()
        Text("人在馆内").font(.caption).foregroundStyle(.secondary)
      }
      if campus.readingRooms.isEmpty == false {
        Text(campus.readingRooms.map {
          "\($0.name.replacingOccurrences(of: "特色阅览室", with: "阅览室")) · \($0.people) 人"
        }.joined(separator: " · "))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], alignment: .leading, spacing: 7) {
        if let seats = campus.seats {
          Label("预约座位 \(seats.available)/\(seats.total)", systemImage: "chair")
        }
        if let rooms = campus.studyRooms {
          Label("研讨间 \(rooms.available)/\(rooms.total)", systemImage: "door.left.hand.open")
        }
        if let lockers = campus.lockers {
          Label("寄存柜 \(lockers.available)/\(lockers.total)", systemImage: "archivebox")
        }
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
      .help("依次为可预约座位、可用研讨间、可用寄存柜；斜线后为总量")
    }
    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    .padding(14)
    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.06)))
    .accessibilityElement(children: .combine)
  }

  private func peopleForecastContent(_ snapshot: LibraryPublicStats) -> some View {
    let trend = model.peopleTrend(campusID: peopleCampusID, weekday: peopleWeekday)
    return VStack(alignment: .leading, spacing: 12) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
        Picker("校区", selection: $peopleCampusID) {
          ForEach(snapshot.campuses) { Text($0.name).tag($0.id) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Picker("星期", selection: $peopleWeekday) {
          Text("周日").tag(1); Text("周一").tag(2); Text("周二").tag(3); Text("周三").tag(4)
          Text("周四").tag(5); Text("周五").tag(6); Text("周六").tag(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Picker("时段", selection: $peopleHour) {
          ForEach(7..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let forecast = model.peopleForecast(campusID: peopleCampusID, weekday: peopleWeekday, hour: peopleHour) {
        Text("近 60 天同星期、同小时有 \(forecast.sampleCount) 天记录，历史均值约 \(forecast.estimatedPeople) 人。")
          .font(.callout)
      } else {
        let count = model.peopleSampleCount(campusID: peopleCampusID, weekday: peopleWeekday, hour: peopleHour)
        Text("已缓存 \(count) 天同星期、同小时记录；积累至少 3 天后显示历史均值。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      if trend.isEmpty {
        ContentUnavailableView(
          "还没有人数样本",
          systemImage: "chart.xyaxis.line",
          description: Text("打开图书馆页面后会定期采样；也可以点右上角手动刷新。")
        )
        .frame(height: 130)
      } else {
        Chart(trend) { point in
          LineMark(
            x: .value("小时", point.hour),
            y: .value("平均在馆人数", point.averagePeople)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(Color.accentColor)
          PointMark(
            x: .value("小时", point.hour),
            y: .value("平均在馆人数", point.averagePeople)
          )
          .foregroundStyle(Color.accentColor)
        }
        .chartXScale(domain: 7...23)
        .chartXAxis {
          AxisMarks(values: .stride(by: 2)) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
              if let hour = value.as(Int.self) { Text(String(format: "%02d", hour)) }
            }
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
            AxisGridLine()
            AxisValueLabel {
              if let count = value.as(Double.self) { Text(count.formatted(.number.precision(.fractionLength(0)))) }
            }
          }
        }
        .chartXSelection(value: $selectedPeopleTrendHour)
        .frame(height: 170)
        .accessibilityLabel("所选校区过去 60 天各小时平均在馆人数")
        .onChange(of: selectedPeopleTrendHour) { _, hour in
          if let hour { peopleHour = hour }
        }
        if let point = trend.first(where: { $0.hour == peopleHour }) {
          Text("\(String(format: "%02d:00", point.hour)) · 平均 \(Int(point.averagePeople.rounded())) 人 · \(point.sampleCount) 天样本")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      Text("历史均值仅供参考，不是学校官方预测。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var selectors: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Picker("楼馆", selection: $model.libraryID) { Text("请选择楼馆").tag(""); ForEach(model.libraries) { Text($0.name + " · " + $0.detail).tag($0.id) } }
        Button("刷新") { Task { await model.loadLibraries() } }
      }
      Picker("分区", selection: $model.areaID) { Text("请选择分区").tag(""); ForEach(model.areas) { Text($0.name + " · " + $0.detail).tag($0.id) } }.disabled(model.libraryID.isEmpty || model.areas.isEmpty)
      LabeledContent("预约时段", value: model.selectedSlot?.title ?? "当前没有开放时段")
      Button("查询当前座位") { Task { await model.loadSeats(search: seatSearch, onlyAvailable: onlyAvailable) } }
        .buttonStyle(.borderedProminent).disabled(model.selectedSlot == nil)
    }.padding(16).background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
      .disabled(model.busy)
      .onChange(of: model.libraryID) { _, _ in Task { await model.loadAreas() } }
      .onChange(of: model.areaID) { _, _ in Task { await model.loadSlots() } }
      .onChange(of: model.slotID) { _, _ in model.clearSeatResults() }
  }

  private var areaDistribution: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("分区座位概况").font(.headline)
      ForEach(model.areas) { area in
        HStack(spacing: 12) {
          Text(area.name)
            .frame(width: 150, alignment: .leading)
            .lineLimit(1)
          if let available = area.availableCount, let total = area.totalCount, total > 0 {
            let clampedAvailable = min(max(available, 0), total)
            ProgressView(value: Double(total - clampedAvailable), total: Double(total))
              .accessibilityLabel("\(area.name) 不可预约座位比例")
            Text("可预约 \(clampedAvailable) / \(total)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          } else {
            Text(area.detail).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
  }

  private var forecastWeekdayPicker: some View {
    Picker("星期", selection: $forecastWeekday) {
      Text("周日").tag(1); Text("周一").tag(2); Text("周二").tag(3); Text("周三").tag(4)
      Text("周四").tag(5); Text("周五").tag(6); Text("周六").tag(7)
    }
    .frame(maxWidth: 100)
  }

  private var forecastHourPicker: some View {
    Picker("时段", selection: $forecastHour) {
      ForEach(7..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
    }
    .frame(maxWidth: 100)
  }

  @ViewBuilder
  private var occupancyForecast: some View {
    let trend = model.occupancyTrend(weekday: forecastWeekday)
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("本机时段估算", systemImage: "chart.xyaxis.line")
          .font(.headline)
        Spacer()
        forecastWeekdayPicker
        forecastHourPicker
      }
      if let forecast = model.occupancyForecast(weekday: forecastWeekday, hour: forecastHour) {
        Text("近 60 天同星期、同小时有 \(forecast.sampleCount) 天记录，预计约 \(forecast.estimatedUnavailableSeats) / \(forecast.totalSeats) 个座位不可预约。")
          .font(.callout)
      } else {
        let count = model.occupancySampleCount(weekday: forecastWeekday, hour: forecastHour)
        Text("已缓存 \(count) 天同星期、同小时记录；至少积累 3 天后显示估算。")
          .font(.callout).foregroundStyle(.secondary)
      }
      if trend.isEmpty {
        ContentUnavailableView(
          "还没有时段样本",
          systemImage: "chart.bar.xaxis",
          description: Text("查询座位后会在本机累计趋势；相同星期的样本会出现在这里。")
        )
        .frame(height: 150)
      } else {
        Chart(trend) { point in
          BarMark(
            x: .value("小时", point.hour),
            y: .value("不可预约座位比例", point.averageUnavailableRatio)
          )
          .foregroundStyle(point.hour == forecastHour ? Color.accentColor : Color.accentColor.opacity(0.55))
          .cornerRadius(3)
        }
        .chartXScale(domain: 7...23)
        .chartYScale(domain: 0...1)
        .chartXAxis {
          AxisMarks(values: .stride(by: 2)) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
              if let hour = value.as(Int.self) { Text(String(format: "%02d", hour)) }
            }
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine()
            AxisValueLabel {
              if let ratio = value.as(Double.self) {
                Text(ratio.formatted(.percent.precision(.fractionLength(0))))
              }
            }
          }
        }
        .chartXSelection(value: $selectedTrendHour)
        .frame(height: 160)
        .accessibilityLabel("所选星期过去 60 天各小时不可预约座位比例")
        .onChange(of: selectedTrendHour) { _, hour in
          if let hour { forecastHour = hour }
        }
        if let point = trend.first(where: { $0.hour == forecastHour }) {
          Text("\(String(format: "%02d:00", point.hour)) · 不可预约座位平均 \(point.averageUnavailableRatio.formatted(.percent.precision(.fractionLength(0)))) · \(point.sampleCount) 天样本")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      Text("只在你查询当前时段座位时记录到本机，每个分区每天每小时保留一条汇总。不可预约座位仅作繁忙程度参考，不等同真实在馆人数。")
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct PendingLibrarySeatAction: Identifiable {
  let id = UUID()
  let booking: LibraryBooking
  let action: LibrarySeatAction
}

private struct LibraryActiveBookingCard: View {
  let booking: LibraryBooking
  let isBusy: Bool
  let onAction: (LibrarySeatAction) -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 8) {
            Text(booking.displayTitle).font(.headline)
            Text(kindLabel)
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 7)
              .padding(.vertical, 2)
              .background(Color.accentColor.opacity(0.12), in: Capsule())
              .foregroundStyle(Color.accentColor)
          }
          Text(booking.displayDetail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Text(booking.displayStatus).font(.caption).foregroundStyle(.secondary)
      }

      if booking.hasLifecycleActions {
        HStack(spacing: 8) {
          if booking.canSignIn {
            actionButton(.signIn)
          }
          if booking.canTemporaryLeave {
            actionButton(.temporaryLeave)
          }
          if booking.canCheckout {
            Button(role: .destructive) {
              onAction(.checkout)
            } label: {
              Label(LibrarySeatAction.checkout.title, systemImage: LibrarySeatAction.checkout.symbol)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy)
          }
        }
      }

      HStack {
        if booking.canCancel() {
          Button("取消预约", role: .destructive, action: onCancel)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy)
        }
        Spacer()
        Text(booking.hasLifecycleActions
          ? "操作结果以学校返回状态为准"
          : (booking.canCancel() ? "座位状态操作未开放" : "学校尚未开放自助操作"))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.12)))
  }

  private var kindLabel: String {
    if booking.isSeminar { return "研讨室" }
    if booking.isStudySeat { return "研修座位" }
    return "座位"
  }

  private func actionButton(_ action: LibrarySeatAction) -> some View {
    Button {
      onAction(action)
    } label: {
      Label(
        action == .signIn ? booking.signInActionTitle : action.title,
        systemImage: action.symbol
      )
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(isBusy)
  }
}

private struct LibraryBookingRow: View {
  let booking: LibraryBooking
  let isBusy: Bool
  let onCancel: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text(booking.displayTitle).font(.headline)
        Text(booking.displayDetail).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if booking.canCancel() {
        Button("取消预约", role: .destructive, action: onCancel).disabled(isBusy)
      } else {
        Text(booking.displayStatus).font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 10))
  }
}

private struct LibrarySeatCard: View {
  let seat: LibraryItem
  let isBusy: Bool
  let onSelect: () -> Void

  private var statusText: String {
    if !seat.detail.isEmpty { return seat.detail }
    return seat.available ? "可预约" : "不可用"
  }

  var body: some View {
    Button(action: onSelect) {
      VStack(spacing: 8) {
        Image(systemName: "chair.fill").font(.title2)
        Text(seat.name).font(.headline)
        Text(statusText).font(.caption)
      }
      .frame(maxWidth: .infinity)
      .padding(14)
      .background(
        seat.available ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
        in: RoundedRectangle(cornerRadius: 10)
      )
    }
    .buttonStyle(.plain)
    .disabled(!seat.available || isBusy)
  }
}

import Charts
import SwiftUI

struct IOSLibraryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: LibraryViewModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var tab = 0
  @State private var search = ""
  @State private var onlyAvailable = false
  @State private var pendingSeat: LibraryItem?
  @State private var pendingCancellation: LibraryBooking?
  @State private var pendingSeatAction: PendingIOSSeatAction?
  @State private var visibleSeatLimit = 60

  var body: some View {
    List {
      Section {
        Picker("内容", selection: $tab) {
          Text("选择座位").tag(0)
          Text("我的预约").tag(1)
        }
        .pickerStyle(.segmented)
      }

      if let message = model.message {
        Section {
          IOSInlineMessage(
            message,
            systemImage: model.failed ? "exclamationmark.triangle.fill" : "info.circle",
            tint: model.failed ? .orange : .secondary
          )
        }
      }

      if tab == 0 {
        seatSelectionSections
      } else {
        bookingSections
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("图书馆")
    .searchable(text: $search, prompt: "搜索座位名称")
    .refreshable { await refreshCurrentTab() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await refreshCurrentTab() }
        } label: {
          if model.busy || model.refreshingPublicStats || model.isLoadingBookings || model.isLoadingCurrentBookings {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.busy || model.refreshingPublicStats || model.isLoadingBookings || model.isLoadingCurrentBookings)
        .accessibilityLabel("刷新图书馆")
      }
    }
    .task(id: "\(appState.user?.schoolid ?? "")|\(scenePhase == .active)") {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
      model.applySeatFilter(search: search, onlyAvailable: onlyAvailable)
    }
    .onChange(of: tab) { _, value in
      if value == 1, model.loadedBookings == false || model.loadedCurrentBookings == false {
        Task { await model.refreshMyBookings(page: model.bookingPage) }
      }
    }
    .onChange(of: search) { _, _ in
      visibleSeatLimit = 60
      model.applySeatFilter(search: search, onlyAvailable: onlyAvailable, debounceSearch: true)
    }
    .onChange(of: onlyAvailable) { _, _ in
      visibleSeatLimit = 60
      model.applySeatFilter(search: search, onlyAvailable: onlyAvailable)
    }
    .onChange(of: model.libraryID) { _, value in
      guard value.isEmpty == false else { return }
      Task { await model.loadAreas() }
    }
    .onChange(of: model.areaID) { _, value in
      guard value.isEmpty == false else { return }
      Task { await model.loadSlots() }
    }
    .onChange(of: model.slotID) { _, _ in
      model.clearSeatResults()
    }
    .alert("确认预约？", isPresented: seatConfirmationPresented) {
      Button("确认预约") {
        guard let seat = pendingSeat else { return }
        pendingSeat = nil
        Task { await model.reserve(seat) }
      }
      Button("取消", role: .cancel) { pendingSeat = nil }
    } message: {
      Text("座位：\(pendingSeat?.name ?? "")\n\(model.selectedSlot?.title ?? "")")
    }
    .alert("取消这条预约？", isPresented: cancellationPresented) {
      Button("取消预约", role: .destructive) {
        guard let booking = pendingCancellation else { return }
        pendingCancellation = nil
        Task { await model.cancel(booking) }
      }
      Button("保留预约", role: .cancel) { pendingCancellation = nil }
    } message: {
      Text(pendingCancellation?.displayDetail ?? "")
    }
    .alert(pendingSeatAction?.action.confirmationTitle ?? "确认操作？", isPresented: seatActionPresented) {
      Button(seatActionButtonTitle, role: pendingSeatAction?.action == .checkout ? .destructive : nil) {
        guard let pending = pendingSeatAction else { return }
        pendingSeatAction = nil
        Task { await model.perform(pending.action, on: pending.booking) }
      }
      Button("取消", role: .cancel) { pendingSeatAction = nil }
    } message: {
      Text("\(pendingSeatAction?.booking.displayTitle ?? "")\n\(pendingSeatAction.map { $0.action.confirmationMessage(for: $0.booking) } ?? "")")
    }
  }

  private var seatActionPresented: Binding<Bool> {
    Binding(
      get: { pendingSeatAction != nil },
      set: { presented in if presented == false { pendingSeatAction = nil } }
    )
  }

  private var seatActionButtonTitle: String {
    pendingSeatAction.map { $0.action.buttonTitle(for: $0.booking) } ?? "确认"
  }

  @ViewBuilder
  private var seatSelectionSections: some View {
    publicStatsSection

    Section {
      Picker("楼馆", selection: $model.libraryID) {
        Text("请选择").tag("")
        ForEach(model.libraries) { library in
          Text(library.name).tag(library.id)
        }
      }
      .disabled(model.libraries.isEmpty || model.busy)

      Picker("分区", selection: $model.areaID) {
        Text("请选择").tag("")
        ForEach(model.areas) { area in
          Text(area.name).tag(area.id)
        }
      }
      .disabled(model.libraryID.isEmpty || model.areas.isEmpty || model.busy)

      LabeledContent("预约时段", value: model.selectedSlot?.title ?? "当前没有开放时段")

      Button {
        Task {
          visibleSeatLimit = 60
          await model.loadSeats(search: search, onlyAvailable: onlyAvailable)
        }
      } label: {
        Label("查询当前座位", systemImage: "chair.lounge")
      }
      .disabled(model.selectedSlot == nil || model.busy)
    } header: {
      Text("预约范围")
    } footer: {
      Text("预约时间由图书馆当前开放时段决定。")
    }

    if model.loadedSeats {
      Section {
        Toggle("只看可预约", isOn: $onlyAvailable)
        if let fetchedAt = model.seatsFetchedAt {
          LabeledContent(model.seatsAreCached ? "缓存时间" : "更新时间", value: fetchedAt.formatted(date: .omitted, time: .shortened))
        }
        if model.seatsCacheIsPartial {
          IOSInlineMessage("缓存仅含前 2,000 个座位，刷新后可查看完整结果。", systemImage: "externaldrive", tint: .orange)
        }
      } header: {
        Text("座位筛选")
      }

      let seats = Array(model.filteredSeats.prefix(visibleSeatLimit))
      Section {
        if seats.isEmpty {
          ContentUnavailableView(
            "没有匹配的座位",
            systemImage: "chair",
            description: Text(model.seats.isEmpty ? "当前时段暂无座位。" : "请调整搜索或筛选条件。")
          )
        } else {
          ForEach(seats) { seat in
            Button {
              if seat.available { pendingSeat = seat }
            } label: {
              seatRow(seat)
            }
            .buttonStyle(.plain)
            .disabled(seat.available == false || model.busy)
          }
          if visibleSeatLimit < model.filteredSeats.count {
            Button("显示更多座位") {
              visibleSeatLimit += 60
            }
          }
        }
      } header: {
        Text("座位 · \(model.filteredSeats.count) 个结果")
      }
    } else if model.isRefreshingSeats || model.busy {
      Section {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在查询座位…")
        }
      }
    }
  }

  @ViewBuilder
  private var publicStatsSection: some View {
    if let stats = model.publicStats {
      Section {
        ForEach(stats.campuses) { campus in
          VStack(alignment: .leading, spacing: 7) {
            LabeledContent(campus.name, value: "\(campus.people) 人在馆")
            if campus.readingRooms.isEmpty == false {
              Text(campus.readingRooms.map { "\($0.name) \($0.people) 人" }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
              if let seats = campus.seats {
                Label("\(seats.available)/\(seats.total) 座位", systemImage: "chair")
              }
              if let rooms = campus.studyRooms {
                Label("\(rooms.available)/\(rooms.total) 研讨间", systemImage: "door.left.hand.open")
              }
              if let lockers = campus.lockers {
                Label("\(lockers.available)/\(lockers.total) 寄存柜", systemImage: "archivebox")
              }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }

        NavigationLink {
          IOSLibraryTrendsView()
        } label: {
          Label("人数趋势与历史估算", systemImage: "chart.xyaxis.line")
        }

        Link("查看官网空间数据", destination: LibraryPublicStatsSource.url)
      } header: {
        Text("实时在馆")
      } footer: {
        Text("\(model.publicStatsAreCached ? "缓存" : "更新")于 \(stats.fetchedAt.formatted(date: .abbreviated, time: .shortened))。人数与资源余量来自图书馆官网。")
      }
    } else if model.refreshingPublicStats {
      Section("实时在馆") {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在读取官网空间数据…")
        }
      }
    } else if let error = model.publicStatsError {
      Section("实时在馆") {
        IOSInlineMessage(error, systemImage: "wifi.exclamationmark", tint: .orange)
      }
    }
  }

  @ViewBuilder
  private var bookingSections: some View {
    if let error = model.currentBookingsError {
      Section {
        IOSInlineMessage("进行中的预约暂时无法读取：\(error)", systemImage: "wifi.exclamationmark", tint: .orange)
      }
    }

    Section {
      if model.isLoadingCurrentBookings && model.loadedCurrentBookings == false {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在读取进行中的预约…")
        }
      } else if model.loadedCurrentBookings {
        if model.currentBookings.isEmpty {
          Text("当前没有进行中的预约。")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          ForEach(model.currentBookings) { booking in
            activeBookingRow(booking)
          }
        }
      } else {
        Button {
          Task { await model.refreshMyBookings(page: model.bookingPage) }
        } label: {
          Label("读取进行中的预约", systemImage: "ticket")
        }
      }
    } header: {
      Text("进行中的预约")
    } footer: {
      Text("临时离开保留座位，需在暂离时限内返回并签到；完全离开会结束本次使用。操作结果以学校返回状态为准，不会自动重试。")
    }

    Section {
      if model.isLoadingBookings && model.loadedBookings == false {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在读取历史预约…")
        }
      } else if model.loadedBookings && model.historyBookings.isEmpty {
        Text("暂无历史预约记录。")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(model.historyBookings) { booking in
          historyBookingRow(booking)
        }
        if model.bookingHasNext {
          Button {
            Task { await model.loadBookings(page: model.bookingPage + 1) }
          } label: {
            Label("加载更多预约", systemImage: "ellipsis.circle")
          }
        }
      }
    } header: {
      Text("历史记录")
    } footer: {
      Text(model.bookingTotal.map { "共 \($0) 条预约" } ?? "每页 \(model.bookingPageSize) 条")
    }

    if model.loadedBookings == false && model.isLoadingBookings == false {
      Section {
        Button {
          Task { await model.loadBookings(page: 1) }
        } label: {
          Label("读取全部预约记录", systemImage: "ticket")
        }
      }
    }
  }

  @ViewBuilder
  private func activeBookingRow(_ booking: LibraryBooking) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(booking.displayTitle).font(.body.weight(.medium))
            if booking.isSeminar {
              tag("研讨室")
            } else if booking.isStudySeat {
              tag("研修座位")
            }
          }
          Text(booking.displayDetail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Text(booking.displayStatus).font(.caption).foregroundStyle(.secondary)
      }

      if booking.hasLifecycleActions {
        HStack(spacing: 8) {
          if booking.canSignIn {
            actionButton(booking, .signIn)
          }
          if booking.canTemporaryLeave {
            actionButton(booking, .temporaryLeave)
          }
          if booking.canCheckout {
            Button {
              pendingSeatAction = PendingIOSSeatAction(booking: booking, action: .checkout)
            } label: {
              Label(LibrarySeatAction.checkout.title, systemImage: LibrarySeatAction.checkout.symbol)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(model.busy)
          }
        }
      }

      HStack(spacing: 8) {
        if booking.canCancel() {
          Button("取消预约", role: .destructive) {
            pendingCancellation = booking
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        Spacer()
        if booking.hasLifecycleActions == false {
          Text(booking.canCancel() ? "座位状态操作未开放" : "学校尚未开放自助操作")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 3)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if booking.canCheckout {
        Button("完全离开", role: .destructive) {
          pendingSeatAction = PendingIOSSeatAction(booking: booking, action: .checkout)
        }
      }
      if booking.canCancel() {
        Button("取消", role: .destructive) {
          pendingCancellation = booking
        }
      }
    }
  }

  @ViewBuilder
  private func historyBookingRow(_ booking: LibraryBooking) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(booking.displayTitle).font(.body.weight(.medium))
          Text(booking.displayDetail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Text(booking.displayStatus).font(.caption).foregroundStyle(.secondary)
      }
      if booking.canCancel() {
        Button("取消预约", role: .destructive) {
          pendingCancellation = booking
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(.vertical, 2)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if booking.canCancel() {
        Button("取消", role: .destructive) {
          pendingCancellation = booking
        }
      }
    }
  }

  private func actionButton(_ booking: LibraryBooking, _ action: LibrarySeatAction) -> some View {
    Button {
      pendingSeatAction = PendingIOSSeatAction(booking: booking, action: action)
    } label: {
      Label(
        action == .signIn ? booking.signInActionTitle : action.title,
        systemImage: action.symbol
      )
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(model.busy)
  }

  private func tag(_ text: String) -> some View {
    Text(text)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(Color.accentColor.opacity(0.12), in: Capsule())
      .foregroundStyle(Color.accentColor)
  }

  private func seatRow(_ seat: LibraryItem) -> some View {
    HStack(spacing: 12) {
      Image(systemName: seat.available ? "chair.fill" : "chair")
        .foregroundStyle(seat.available ? Color.green : Color.secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(seat.name)
          .foregroundStyle(.primary)
        if seat.detail.isEmpty == false {
          Text(seat.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Text(seat.available ? "可预约" : "不可用")
        .font(.caption)
        .foregroundStyle(seat.available ? Color.green : Color.secondary)
    }
  }

  private var seatConfirmationPresented: Binding<Bool> {
    Binding(
      get: { pendingSeat != nil },
      set: { presented in if presented == false { pendingSeat = nil } }
    )
  }

  private var cancellationPresented: Binding<Bool> {
    Binding(
      get: { pendingCancellation != nil },
      set: { presented in if presented == false { pendingCancellation = nil } }
    )
  }

  private func refreshCurrentTab() async {
    if tab == 0 {
      await model.refreshIfStale()
      if model.selectedSlot != nil {
        await model.loadSeats(search: search, onlyAvailable: onlyAvailable)
      }
    } else {
      await model.refreshMyBookings(page: model.bookingPage)
    }
  }
}

private struct PendingIOSSeatAction: Identifiable {
  let id = UUID()
  let booking: LibraryBooking
  let action: LibrarySeatAction
}

private struct IOSLibraryTrendsView: View {
  @EnvironmentObject private var model: LibraryViewModel
  @State private var campusID = ""
  @State private var peopleWeekday = LibraryOccupancyHistory.currentWeekday
  @State private var peopleHour = LibraryOccupancyHistory.currentHour
  @State private var seatWeekday = LibraryOccupancyHistory.currentWeekday
  @State private var seatHour = LibraryOccupancyHistory.currentHour

  var body: some View {
    List {
      Section {
        if let stats = model.publicStats {
          Picker("校区", selection: $campusID) {
            ForEach(stats.campuses) { campus in
              Text(campus.name).tag(campus.id)
            }
          }
        }
        Picker("星期", selection: $peopleWeekday) {
          ForEach(1...7, id: \.self) { weekday in
            Text(SchoolTime.weekdayName(calendarWeekday: weekday)).tag(weekday)
          }
        }
        Picker("时段", selection: $peopleHour) {
          ForEach(7..<24, id: \.self) { hour in
            Text(String(format: "%02d:00", hour)).tag(hour)
          }
        }

        if let forecast = model.peopleForecast(campusID: campusID, weekday: peopleWeekday, hour: peopleHour) {
          LabeledContent("历史均值", value: "约 \(forecast.estimatedPeople) 人")
          LabeledContent("样本数", value: "\(forecast.sampleCount) 天")
        } else {
          let count = model.peopleSampleCount(campusID: campusID, weekday: peopleWeekday, hour: peopleHour)
          Text("已缓存 \(count) 天同星期、同小时记录；至少 3 天后显示历史均值。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        let peopleTrend = model.peopleTrend(campusID: campusID, weekday: peopleWeekday)
        if peopleTrend.isEmpty == false {
          Chart(peopleTrend) { point in
            LineMark(
              x: .value("小时", point.hour),
              y: .value("平均在馆人数", point.averagePeople)
            )
            .interpolationMethod(.catmullRom)
          }
          .frame(height: 180)
          .chartXScale(domain: 7...23)
          .accessibilityLabel("同星期各小时平均在馆人数")
        }
      } header: {
        Text("在馆人数")
      } footer: {
        Text("历史数据仅保存在本机，仅供参考，不是学校官方预测。")
      }

      Section("座位繁忙度") {
        Picker("星期", selection: $seatWeekday) {
          ForEach(1...7, id: \.self) { weekday in
            Text(SchoolTime.weekdayName(calendarWeekday: weekday)).tag(weekday)
          }
        }
        Picker("时段", selection: $seatHour) {
          ForEach(7..<24, id: \.self) { hour in
            Text(String(format: "%02d:00", hour)).tag(hour)
          }
        }

        if let forecast = model.occupancyForecast(weekday: seatWeekday, hour: seatHour) {
          LabeledContent("预计不可预约", value: "\(forecast.estimatedUnavailableSeats) / \(forecast.totalSeats)")
          LabeledContent("样本数", value: "\(forecast.sampleCount) 天")
        } else {
          let count = model.occupancySampleCount(weekday: seatWeekday, hour: seatHour)
          Text("已缓存 \(count) 天同星期、同小时记录；至少 3 天后显示估算。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        let seatTrend = model.occupancyTrend(weekday: seatWeekday)
        if seatTrend.isEmpty == false {
          Chart(seatTrend) { point in
            BarMark(
              x: .value("小时", point.hour),
              y: .value("不可预约比例", point.averageUnavailableRatio)
            )
            .foregroundStyle(Color.accentColor)
          }
          .frame(height: 180)
          .chartXScale(domain: 7...23)
          .chartYScale(domain: 0...1)
          .accessibilityLabel("同星期各小时不可预约座位比例")
        }
      }
    }
    .navigationTitle("图书馆趋势")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if campusID.isEmpty {
        campusID = model.publicStats?.campuses.first?.id ?? "xylxq"
      }
    }
  }


}

import SwiftUI

private enum ClassroomDisplayMode: String, CaseIterable, Identifiable {
  case overview
  case list
  case timeline

  var id: String { rawValue }
  var title: String {
    switch self {
    case .overview: "楼栋概览"
    case .list: "房间列表"
    case .timeline: "节次对照"
    }
  }
  var symbol: String {
    switch self {
    case .overview: "square.grid.2x2"
    case .list: "list.bullet"
    case .timeline: "chart.bar.xaxis"
    }
  }
}

struct ClassroomView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: ClassroomViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("compactLists") private var compactLists = false
  @State private var displayMode: ClassroomDisplayMode = .overview
  @State private var filtersExpanded = false
  @State private var resultPage = 0
  private let pageSize = 40
  @State private var selectedRoom: FreeClassroom?

  private var calendar: Calendar { SchoolTime.calendar }

  var body: some View {
    ScrollViewReader { proxy in
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "CAMPUS / CLASSROOM", title: "空教室", subtitle: "把校区、日期和空闲节次组合起来，快速找到可以使用的教室")
        queryPanel
        filterPanel

        if let message = model.message {
          VStack(alignment: .leading, spacing: 8) {
            StatusNotice(message: message + (model.queried ? " · 保留上次查询结果，请核对查询时间" : ""), kind: .warning)
            Button("重试") { Task { await model.query(forceRefresh: true) } }
              .buttonStyle(.bordered)
              .disabled(model.busy)
          }
        }

        if model.busy {
          ProgressView("正在查询空教室…")
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        }

        if model.isLoadingCache {
          ProgressView("正在读取本机查询结果…")
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let fetchedAt = model.fetchedAt {
          HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
            Text("查询于 \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            if model.resultsAreCached { Text("· 本机缓存").foregroundStyle(.secondary) }
            if model.busy { Text("· 正在更新").foregroundStyle(.secondary) }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        resultContent
          .id("classroom-results")
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 1040, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid { await model.start(account: account) }
    }
    .onChange(of: displayMode) { _, _ in
      resultPage = 0
      proxy.scrollTo("classroom-results", anchor: .top)
    }
    .onChange(of: model.resultRevision) { _, _ in resultPage = 0 }
    .onChange(of: resultPage) { _, _ in
      proxy.scrollTo("classroom-results", anchor: .top)
    }
    .onChange(of: model.filteredRoomCount) { _, count in
      if model.hasActiveFilters && count == 0 { filtersExpanded = true }
    }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      if needed {
        Task {
          do { _ = try await appState.confirmSessionAfterAuthFailure() }
          catch {
            AppLog.auth.error("空教室会话复核失败")
            appState.showToast("暂时无法验证学校会话，请稍后重试", isError: true)
          }
        }
      }
    }
    .sheet(item: $selectedRoom) { room in
      ClassroomRoomDetail(room: room, building: model.filtered.first(where: { $0.value.contains(where: { $0.id == room.id }) })?.key)
    }
  }


  private var queryPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "location.magnifyingglass")
          .font(.title2)
          .foregroundStyle(Color.accentColor)
          .frame(width: 32)
        VStack(alignment: .leading, spacing: 4) {
          Text("先确定查询范围").font(.headline)
          Text("结果来自学校当天公布的空闲安排，查询不会占用或预订教室。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if model.queried && !model.busy && model.message == nil {
          Label("已查询", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.green)
        }
      }
      Divider()
      VStack(alignment: .leading, spacing: 12) {
        Picker("校区", selection: $model.campus) {
          Text("学院路").tag(1)
          Text("沙河").tag(2)
          Text("杭州").tag(3)
        }
        .frame(width: 150)
        DatePicker("日期", selection: $model.date, displayedComponents: .date)
          .frame(maxWidth: 230)
        HStack {
        Button("今天") { model.date = Date() }
          .buttonStyle(.bordered)
        Button("明天") {
          if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) { model.date = tomorrow }
        }
        .buttonStyle(.bordered)
        }
      }
      HStack(spacing: 10) {
        queryButtons
        Spacer()
        Text("缓存 5 分钟内自动复用")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(18)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
  }

  private var queryButtons: some View {
    HStack(spacing: 10) {
      Button { Task { await model.query() } } label: {
        Label("查询空教室", systemImage: "magnifyingglass")
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
      .disabled(model.busy || model.isLoadingCache)

      Button { Task { await model.query(forceRefresh: true) } } label: {
        Label("强制刷新", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
      .help("跳过五分钟缓存重新查询")
      .keyboardShortcut("r", modifiers: .command)
      .disabled(model.busy || model.isLoadingCache)

      if model.busy { ProgressView().controlSize(.small) }
    }
  }

  private var filterPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        SearchField(prompt: "搜索楼栋或教室", text: $model.search)
          .frame(maxWidth: .infinity)
          .accessibilityHint("输入后立即筛选当前结果")
        if model.hasActiveFilters {
          Button("清除") { model.resetFilters() }
            .buttonStyle(.borderless)
            .help("清除全部筛选条件")
        }
      }

      DisclosureGroup(isExpanded: $filtersExpanded) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
          Picker("空闲节次", selection: $model.section) {
            Text("任意节次").tag(0)
            ForEach(1...14, id: \.self) { Text("第 \($0) 节").tag($0) }
          }
          Picker("至少空闲", selection: $model.minimumFreeSections) {
            Text("不限制空闲数量").tag(0)
            Text("至少 3 节").tag(3)
            Text("至少 5 节").tag(5)
            Text("至少 8 节").tag(8)
          }
          Picker("连续空闲", selection: $model.minimumConsecutiveSections) {
            Text("不限").tag(0)
            Text("至少 2 节").tag(2)
            Text("至少 4 节").tag(4)
          }
          Picker("排序", selection: $model.sort) {
            ForEach(ClassroomSort.allCases) { Text(ClassroomSortPresentation.title(for: $0)).tag($0) }
          }
        }
        .padding(.top, 10)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "slider.horizontal.3")
            .foregroundStyle(Color.accentColor)
          Text("筛选与排序")
            .font(.callout.weight(.medium))
          Text(model.hasActiveFilters ? "已启用 \(activeFilterCount) 项" : "节次、空闲数、连续时间")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
      }

      HStack(spacing: 12) {
        Label("结果布局", systemImage: "rectangle.3.group")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Picker("结果布局", selection: $displayMode) {
          ForEach(ClassroomDisplayMode.allCases) { mode in
            Label(mode.title, systemImage: mode.symbol).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        Spacer(minLength: 0)
        if model.hasActiveFilters {
          Text("结果即时更新")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(14)
    .background(Color.ginkgoCardBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
  }

  private var activeFilterCount: Int {
    [!model.search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
     model.section != 0,
     model.minimumFreeSections != 0,
     model.minimumConsecutiveSections != 0,
     model.building != nil].filter { $0 }.count
  }

  @ViewBuilder
  private var resultContent: some View {
    if !model.queried && !model.busy && model.message == nil {
      PageEmptyState(symbol: "sparkles", title: "准备寻找空闲空间", detail: "选择校区和日期后开始查询。你也可以用“今天”和“明天”快速切换。")
    } else if model.queried && model.filtered.isEmpty && (model.message != nil || model.busy) {
      PageEmptyState(symbol: "questionmark.folder", title: "当前空闲情况尚未确认", detail: "上次结果没有匹配教室，请等待查询完成或重试。")
    } else if model.queried && model.filtered.isEmpty {
      let title = model.rooms.isEmpty || !model.hasActiveFilters ? "当天没有返回空闲教室" : "没有符合筛选条件的教室"
      let detail = model.rooms.isEmpty || !model.hasActiveFilters
        ? "学校已成功返回查询结果，但当前范围没有可用教室。可以换一个日期或校区。"
        : "尝试清除筛选，或降低“至少空闲”的节数。原始结果仍保留在本次查询中。"
      PageEmptyState(symbol: model.rooms.isEmpty ? "building.2" : "line.3.horizontal.decrease.circle", title: title, detail: detail)
    } else if model.queried {
      VStack(alignment: .leading, spacing: 16) {
        summary
        if let building = model.building {
          Button { model.building = nil; displayMode = .overview } label: {
            Label("返回全部楼栋 · " + building, systemImage: "chevron.left")
          }
        }
        switch displayMode {
        case .overview:
          overview
        case .list, .timeline:
          list
        }
      }

    }
  }

  @ViewBuilder
  private var summary: some View {
    let roomMetric = ClassroomMetric(title: "可用教室", value: "\(model.filteredRoomCount)", detail: model.hasActiveFilters ? "筛选后" : "全部结果", symbol: "door.left.hand.open")
    let buildingMetric = ClassroomMetric(title: "楼栋", value: "\(model.buildingCount)", detail: "当前范围", symbol: "building.2")
    let slotMetric = ClassroomMetric(title: "空闲节次", value: "\(model.freeSlotCount)", detail: "合计空闲标记", symbol: "clock")

    HStack(alignment: .top, spacing: 10) {
      roomMetric
      buildingMetric
      slotMetric
      Spacer(minLength: 0)
      Text("共 \(model.roomCount) 间返回")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var overview: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
      ForEach(model.filtered.keys.sorted(), id: \.self) { building in
        let rooms = model.filtered[building] ?? []
        Button {
          displayMode = .list
          model.building = building
        } label: {
          BuildingSummaryCard(building: building, rooms: rooms)
        }
        .buttonStyle(.plain)
        .help("查看 \(building) 的教室")
      }
    }
  }

  // Render one bounded page without flattening every matching room on each update.
  private var list: some View {
    let buildings = model.filtered.keys.sorted()
    let totalCount = model.filteredRoomCount
    let pageCount = max(1, (totalCount + pageSize - 1) / pageSize)
    let page = min(resultPage, pageCount - 1)
    var offset = page * pageSize
    var remaining = pageSize
    var visibleByBuilding: [String: [FreeClassroom]] = [:]
    for building in buildings {
      guard remaining > 0, let rooms = model.filtered[building] else { break }
      if offset >= rooms.count {
        offset -= rooms.count
        continue
      }
      let end = min(rooms.count, offset + remaining)
      visibleByBuilding[building] = Array(rooms[offset..<end])
      remaining -= end - offset
      offset = 0
    }
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("第 \(page + 1) / \(pageCount) 页 · 每页最多 \(pageSize) 间")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("上一页") { resultPage = max(0, page - 1) }.disabled(page == 0)
        Button("下一页") { resultPage = page + 1 }.disabled(page + 1 >= pageCount)
      }
      ForEach(buildings, id: \.self) { building in
        let rooms = visibleByBuilding[building] ?? []
        if !rooms.isEmpty {
          Label(building, systemImage: "building.2").font(.headline).padding(.top, 8)
          ForEach(rooms) { room in
            Button { selectedRoom = room } label: {
              ClassroomRoomCard(room: room, compact: compactLists, timeline: displayMode == .timeline)
            }.buttonStyle(.plain)
          }
        }
      }
      if pageCount > 1 {
        HStack {
          Button("上一页") { resultPage = max(0, page - 1) }.disabled(page == 0)
          Spacer()
          Button("下一页") { resultPage = page + 1 }.disabled(page + 1 >= pageCount)
        }
      }
    }
  }

}

private struct ClassroomMetric: View {
  let title: String
  let value: String
  let detail: String
  let symbol: String

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: symbol).foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        Text("\(title) · \(detail)").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .frame(minWidth: 130, alignment: .leading)
    .padding(12)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 10))
  }
}

private struct BuildingSummaryCard: View {
  let building: String
  let rooms: [FreeClassroom]

  private var mostAvailable: [Int] {
    let counts = Dictionary(grouping: rooms.flatMap(\.availableSections), by: { $0 }).mapValues(\.count)
    return counts.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }.prefix(3).map(\.key)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        Image(systemName: "building.2.crop.circle")
          .font(.title2)
          .foregroundStyle(Color.accentColor)
        VStack(alignment: .leading, spacing: 4) {
          Text(building).font(.headline)
          Text("\(rooms.count) 间可查询教室").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Divider()
      if mostAvailable.isEmpty {
        Text("暂无节次信息").font(.caption).foregroundStyle(.secondary)
      } else {
        Text("出现较多的空闲节次").font(.caption).foregroundStyle(.secondary)
        HStack(spacing: 6) {
          ForEach(mostAvailable, id: \.self) { section in
            Text("第 \(section) 节")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 7)
              .padding(.vertical, 5)
              .background(Color.accentColor.opacity(0.12), in: Capsule())
          }
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.08)))
  }
}

private struct ClassroomRoomCard: View {
  let room: FreeClassroom
  let compact: Bool
  let timeline: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 11) {
      HStack(alignment: .firstTextBaseline) {
        Text(room.name).font(.headline)
        Spacer()
        Text("\(room.availableSectionCount) 节空闲")
          .font(.caption.weight(.medium))
          .foregroundStyle(room.availableSectionCount > 0 ? .green : .secondary)
      }
      HStack(spacing: 5) {
        Image(systemName: "clock.badge.checkmark")
          .foregroundStyle(.secondary)
        Text("最长连续空闲 \(room.longestFreeRun) 节")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("点击查看节次")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      if timeline {
        ClassroomSectionStrip(sections: room.availableSections)
      } else {
        FlowSectionPills(sections: room.availableSections)
      }
    }
    .padding(compact ? 11 : 15)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 11))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2)
        .fill(room.availableSectionCount > 0 ? Color.green : Color.secondary)
        .frame(width: 3)
        .padding(.vertical, 8)
    }
  }
}

private struct FlowSectionPills: View {
  let sections: [Int]

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 4) { pills }
      HStack(spacing: 4) {
        ForEach(Array(sections.prefix(6)), id: \.self) { section in pill(section) }
        if sections.count > 6 { Text("+\(sections.count - 6)").font(.caption2).foregroundStyle(.secondary) }
      }
    }
  }

  @ViewBuilder private var pills: some View {
    ForEach(sections, id: \.self) { section in pill(section) }
  }

  private func pill(_ section: Int) -> some View {
    Text("\(section)")
      .font(.caption2.monospacedDigit().weight(.medium))
      .frame(minWidth: 22, minHeight: 20)
      .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
      .foregroundStyle(.green)
  }
}

private struct ClassroomRoomDetail: View {
  let room: FreeClassroom
  let building: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(room.name).font(.title2.weight(.semibold))
          Text(building ?? "教室详情")
            .font(.callout).foregroundStyle(.secondary)
        }
        Spacer()
        Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
      }
      Divider()
      Text("空闲节次 · 最长连续 \(room.longestFreeRun) 节").font(.headline)
      Text("✓ 表示学校标为空闲；— 表示未标为空闲，不代表已确认占用。")
        .font(.caption).foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
        ForEach(1...14, id: \.self) { section in
          HStack(spacing: 5) {
            Image(systemName: room.isAvailable(at: section) ? "checkmark.circle.fill" : "minus.circle")
            Text("第 \(section) 节")
          }
          .font(.caption)
          .frame(maxWidth: .infinity, minHeight: 30)
          .foregroundStyle(room.isAvailable(at: section) ? Color.green : Color.secondary)
          .background((room.isAvailable(at: section) ? Color.green : Color.secondary).opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
        }
      }
      Text("空闲状态来自最近一次查询，实际使用前请以现场和学校安排为准。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .ginkgoPagePadding()
    .ginkgoSheetSizing(minWidth: 500, minHeight: 420)
  }
}

private struct ClassroomSectionStrip: View {
  let sections: [Int]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      sectionCells
      Text("节次 1–14 · ✓ 空闲 · — 未标为空闲").font(.caption2).foregroundStyle(.secondary)
    }
  }

  private var sectionCells: some View {
    HStack(spacing: 3) {
      ForEach(1...14, id: \.self) { section in
        sectionCell(section).frame(maxWidth: .infinity)
      }
    }
  }

  private func sectionCell(_ section: Int) -> some View {
    VStack(spacing: 4) {
      Text("\(section)").font(.caption2.monospacedDigit())
      Image(systemName: sections.contains(section) ? "checkmark" : "minus")
        .font(.caption2)
    }
    .padding(.vertical, 7)
    .background(
      sections.contains(section) ? Color.green.opacity(0.16) : Color.secondary.opacity(0.07),
      in: RoundedRectangle(cornerRadius: 5)
    )
    .accessibilityLabel("第 \(section) 节，" + (sections.contains(section) ? "空闲" : "未标为空闲"))
  }
}

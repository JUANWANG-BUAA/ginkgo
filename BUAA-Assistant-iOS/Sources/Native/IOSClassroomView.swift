import SwiftUI

struct IOSClassroomView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: ClassroomViewModel
  @State private var filtersExpanded = false

  var body: some View {
    List {
      querySection
      filterSection

      if let message = model.message {
        Section {
          IOSInlineMessage(message, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
      }

      if model.busy {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在查询空教室…")
          }
        }
      } else if model.isLoadingCache {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取本机查询结果…")
          }
        }
      } else if model.queried == false {
        Section {
          ContentUnavailableView(
            "选择范围后查询",
            systemImage: "building.2",
            description: Text("查询结果来自学校当天公布的空闲安排，不会占用或预订教室。")
          )
        }
      } else if model.filteredRoomCount == 0 {
        Section {
          ContentUnavailableView(
            "没有符合条件的空教室",
            systemImage: "building.2",
            description: Text("请调整日期、节次或筛选条件。")
          )
        }
      } else {
        if let fetchedAt = model.fetchedAt {
          Section {
            LabeledContent("查询时间", value: fetchedAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("结果", value: "\(model.filteredRoomCount) 间 · \(model.buildingCount) 栋")
            if model.hasActiveFilters {
              Button("清除筛选") { model.resetFilters() }
            }
          }
        }

        ForEach(model.filtered.keys.sorted(), id: \.self) { building in
          Section(building) {
            ForEach(model.filtered[building] ?? []) { room in
              NavigationLink {
                IOSClassroomDetailView(room: room, building: building)
              } label: {
                classroomRow(room)
              }
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("空教室")
    .searchable(text: $model.search, prompt: "搜索楼栋或教室")
    .refreshable { await model.query(forceRefresh: true) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await model.query(forceRefresh: true) }
        } label: {
          if model.busy {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.busy || model.isLoadingCache)
        .accessibilityLabel("刷新空教室")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
  }

  private var querySection: some View {
    Section {
      Picker("校区", selection: $model.campus) {
        Text("学院路").tag(1)
        Text("沙河").tag(2)
        Text("杭州").tag(3)
      }

      DatePicker("日期", selection: $model.date, displayedComponents: .date)

      HStack {
        Button("今天") { model.date = Date() }
          .buttonStyle(.bordered)
        Button("明天") {
          if let tomorrow = SchoolTime.calendar.date(byAdding: .day, value: 1, to: Date()) {
            model.date = tomorrow
          }
        }
        .buttonStyle(.bordered)
      }

      Button {
        Task { await model.query() }
      } label: {
        Label("查询空教室", systemImage: "magnifyingglass")
      }
      .disabled(model.busy || model.isLoadingCache)
    } header: {
      Text("查询范围")
    } footer: {
      Text("结果在 5 分钟内优先复用本机缓存。")
    }
  }

  private var filterSection: some View {
    Section {
      DisclosureGroup("筛选与排序", isExpanded: $filtersExpanded) {
        Picker("空闲节次", selection: $model.section) {
          Text("任意节次").tag(0)
          ForEach(1...14, id: \.self) { section in
            Text("第 \(section) 节").tag(section)
          }
        }
        Picker("最少空闲", selection: $model.minimumFreeSections) {
          Text("不限制").tag(0)
          Text("至少 3 节").tag(3)
          Text("至少 5 节").tag(5)
          Text("至少 8 节").tag(8)
        }
        Picker("连续空闲", selection: $model.minimumConsecutiveSections) {
          Text("不限制").tag(0)
          Text("至少 2 节").tag(2)
          Text("至少 4 节").tag(4)
        }
        Picker("排序", selection: $model.sort) {
          ForEach(ClassroomSort.allCases) { sort in
            Text(sort.rawValue).tag(sort)
          }
        }
      }
    } footer: {
      if model.hasActiveFilters {
        Text("筛选后共 \(model.filteredRoomCount) 间教室。")
      }
    }
  }

  private func classroomRow(_ room: FreeClassroom) -> some View {
    HStack(spacing: 12) {
      Image(systemName: room.availableSectionCount > 0 ? "door.left.hand.open" : "door.left.hand.closed")
        .foregroundStyle(room.availableSectionCount > 0 ? Color.green : Color.secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(room.name).font(.body.weight(.medium))
        Text("\(room.availableSectionCount) 节空闲 · 最长连续 \(room.longestFreeRun) 节")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
}

private struct IOSClassroomDetailView: View {
  let room: FreeClassroom
  let building: String

  var body: some View {
    List {
      Section {
        LabeledContent("楼栋", value: building)
        LabeledContent("空闲节次", value: "\(room.availableSectionCount) 节")
        LabeledContent("最长连续空闲", value: "\(room.longestFreeRun) 节")
      } header: {
        Text(room.name)
      }

      Section("节次状态") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
          ForEach(1...14, id: \.self) { section in
            let available = room.isAvailable(at: section)
            HStack(spacing: 4) {
              Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
              Text("第 \(section) 节")
            }
            .font(.caption)
            .foregroundStyle(available ? Color.green : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
              (available ? Color.green : Color.secondary).opacity(0.10),
              in: RoundedRectangle(cornerRadius: 7)
            )
            .accessibilityLabel("第 \(section) 节，\(available ? "空闲" : "未标为空闲")")
          }
        }
        .padding(.vertical, 4)
      }

      Section {
        Text("✓ 表示学校标为空闲；— 表示未标为空闲，不代表已确认占用。实际使用前请以现场和学校安排为准。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(room.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

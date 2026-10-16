import SwiftUI

struct TodayView: View {
  var openTasks: () -> Void = {}
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var tasks: PersonalTaskStore
  @EnvironmentObject private var homework: HomeworkViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month().day()),
                    title: "今天", subtitle: "今日课程与最近同步状态")
        CheckInSummaryView()
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("接下来要做").font(.title2.weight(.semibold))
            Spacer()
            Button("查看全部", action: openTasks)
          }
          if homework.isLoading && homework.snapshot == nil {
            StatusNotice(message: "正在检查学校作业…", kind: .information)
          } else if let error = homework.errorMessage {
            StatusNotice(message: "暂时无法确认学校作业状态：\(error)", kind: .warning)
          } else if let snapshot = homework.snapshot, !snapshot.protocolChangedSources.isEmpty {
            let sources = snapshot.protocolChangedSources.map(\.title).joined(separator: "、")
            StatusNotice(message: "\(sources)接口格式可能已调整；暂时保留可用数据", kind: .warning)
          } else if let snapshot = homework.snapshot, !snapshot.unavailableSources.isEmpty {
            StatusNotice(message: "学校作业仅部分来源已更新（\(snapshot.unavailableSources.map(\.title).joined(separator: "、"))）", kind: .warning)
          } else if homework.snapshot == nil {
            StatusNotice(message: "学校作业尚未确认", kind: .information)
          }
          if let error = tasks.errorMessage {
            StatusNotice(message: error, kind: .warning)
          } else {
            let pending = tasks.tasks.filter { !$0.completed }.sorted { $0.due < $1.due }
            if pending.isEmpty {
              Label("暂无个人待办", systemImage: "checkmark.circle").foregroundStyle(.secondary)
            }
            ForEach(Array(pending.prefix(3))) { task in
              HStack {
                Button { tasks.toggle(task.id) } label: { Image(systemName: "circle") }
                  .buttonStyle(.plain).accessibilityLabel("完成待办：\(task.title)")
                Text(task.title).lineLimit(2)
                Spacer()
                Text(task.due.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption).foregroundStyle(task.due < Date() ? Color.orange : Color.secondary)
              }
            }
          }
          let attentionItems = homework.attentionItems()
          if !attentionItems.isEmpty {
            Divider()
            HStack {
              Label("近期截止", systemImage: "clock.badge.exclamationmark").font(.callout.weight(.medium))
              Spacer()
              Text("\(attentionItems.count) 项").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(attentionItems.prefix(2))) { item in
              HStack {
                Text(item.title).lineLimit(1)
                Spacer()
                Text(item.courseName).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        if let snapshot = schedule.snapshot {
          if let error = schedule.errorMessage {
            StatusNotice(message: "课表更新失败：\(error) · 以下是缓存内容", kind: .warning)
          } else if schedule.isLoading {
            StatusNotice(message: "正在核对学校课表…", kind: .information)
          }
          let items = todayCourses(snapshot)
          if items.isEmpty {
            let confirmed = schedule.errorMessage == nil && isCurrentWeek(snapshot)
            PageEmptyState(symbol: confirmed ? "calendar" : "wifi.exclamationmark",
                           title: confirmed ? "今天没有课程" : "今日课表尚未确认",
                           detail: confirmed ? "当前选择的课表中没有今天的课程。" : "请刷新课表后再判断今天是否无课。")
          } else {
            Text("今天有 \(items.count) 门课").font(.title2.weight(.semibold))
            ForEach(items) { item in
              HStack(alignment: .top, spacing: 16) {
                Text(item.startTime ?? "第 \(item.startSection) 节")
                  .font(.headline.monospacedDigit())
                  .frame(width: 90, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                  Text(item.name).font(.headline)
                  Text("第 \(item.startSection)–\(item.endSection) 节" + (item.endTime.map { " · 至 \($0)" } ?? ""))
                    .foregroundStyle(.secondary)
                  if let place = item.place, !place.isEmpty {
                    Label(place, systemImage: "mappin").foregroundStyle(.secondary)
                  }
                }
                Spacer()
              }
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
          }
          Text("课表同步：\(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
        } else if schedule.isLoading {
          ProgressView("正在查询今日课程…")
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
          PageEmptyState(symbol: "wifi.exclamationmark", title: "今日课程尚未确认",
                         detail: schedule.errorMessage ?? "请刷新后查看学校课表。")
          Button("重试") { Task { await schedule.refreshToday() } }.buttonStyle(.borderedProminent)
        }
        CampusNoticesSummaryView()
      }
      .padding(24)
      .frame(maxWidth: 760, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { Task { await schedule.refreshToday() } } label: {
          Label("刷新今日课程", systemImage: "arrow.clockwise")
        }
        .disabled(schedule.isLoading)
        .keyboardShortcut("r", modifiers: .command)
      }
    }
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid {
        tasks.load(account: account)
        await homework.start(account: account)
        await schedule.start(account: account)
      }
    }
    .onChange(of: schedule.needsSessionCheck) { _, needed in
      if needed { Task { _ = try? await appState.confirmSessionAfterAuthFailure() } }
    }
  }

  private func todayCourses(_ snapshot: ScheduleSnapshot) -> [CourseMeeting] {
    snapshot.todayCourses()
  }

  private func isCurrentWeek(_ snapshot: ScheduleSnapshot) -> Bool {
    snapshot.containsToday()
  }
}

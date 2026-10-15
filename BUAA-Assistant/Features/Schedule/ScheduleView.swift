import SwiftUI

struct ScheduleView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var model: ScheduleViewModel
  @State private var mode = "周课表"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "ACADEMIC / SCHEDULE", title: "我的课表", subtitle: "按周查看课程与上课地点")
        if let snapshot = model.snapshot {
          controls(snapshot)
          if let error = model.errorMessage {
            StatusNotice(message: "\(error) · 保留上次同步的课表", kind: .warning)
          } else if let feedback = model.feedback {
            StatusNotice(message: feedback, kind: .success)
          }
          Text("上次同步：\(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)) · \(snapshot.portal == .graduate ? "研究生教务" : "本科教务")")
            .font(.caption).foregroundStyle(.secondary)
          Picker("显示方式", selection: $mode) {
            Text("周课表").tag("周课表")
            Text("学期总览").tag("学期总览")
            Text("每日清单").tag("每日清单")
          }.pickerStyle(.segmented).frame(maxWidth: 360)
          if mode == "学期总览" {
            SemesterOverview(snapshot: snapshot) { week in
              mode = "周课表"
              Task { await model.refresh(week: week) }
            }
          } else if snapshot.courses.isEmpty {
            PageEmptyState(
              symbol: model.errorMessage == nil ? "calendar.badge.checkmark" : "wifi.exclamationmark",
              title: model.errorMessage == nil ? "本周没有课程" : "暂时无法确认本周课表",
              detail: model.errorMessage == nil ? "可以切换其他周次查看。" : "这次刷新没有返回可用数据，请重试后再判断是否无课。"
            )
          } else if mode == "每日清单" {
            weekContent(snapshot)
          } else {
            TimetableGrid(snapshot: snapshot)
          }
        } else if model.isLoading {
          VStack(spacing: 12) {
            ProgressView()
            Text("正在查询学校课表…").foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 260)
        } else {
          PageEmptyState(symbol: "wifi.exclamationmark", title: "暂时无法获取课表", detail: model.errorMessage ?? "请检查网络连接后重试。")
          Button("重试") { Task { await model.refresh() } }
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(24)
      .frame(maxWidth: 960, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { Task { await model.refresh() } } label: {
          Label("刷新课表", systemImage: "arrow.clockwise")
        }
        .disabled(model.isLoading)
        .help("刷新课表")
        .keyboardShortcut("r", modifiers: .command)
      }
    }
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid { await model.start(account: account) }
    }
    .onChange(of: model.feedback) { _, message in
      if let message { appState.showToast(message) }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      if needed { Task { _ = try? await appState.confirmSessionAfterAuthFailure() } }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.snapshot?.weekNumber)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: mode)
  }

  private func controls(_ snapshot: ScheduleSnapshot) -> some View {
    HStack(spacing: 12) {
      Picker("学期", selection: Binding(get: { snapshot.termID }, set: { term in
        Task { await model.refresh(termID: term) }
      })) {
        ForEach(snapshot.terms) { term in Text(term.name).tag(term.id) }
      }
      .frame(maxWidth: 300)
      Picker("周次", selection: Binding(get: { snapshot.weekNumber }, set: { week in
        Task { await model.refresh(week: week) }
      })) {
        ForEach(snapshot.weeks) { week in
          Text("第 \(week.number) 周\(week.isCurrent ? " · 本周" : "")").tag(week.number)
        }
      }
      .frame(maxWidth: 190)
      if let current = snapshot.weeks.first(where: \.isCurrent), current.number != snapshot.weekNumber {
        Button("回到本周") { Task { await model.refresh(week: current.number) } }
      }
      Spacer(minLength: 0)
      if model.isLoading { ProgressView().controlSize(.small).accessibilityLabel("正在更新课表") }
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  private func weekContent(_ snapshot: ScheduleSnapshot) -> some View {
    let selected = snapshot.weeks.first(where: { $0.number == snapshot.weekNumber })
    return VStack(alignment: .leading, spacing: 12) {
      if let selected {
        Text("\(selected.start.formatted(date: .abbreviated, time: .omitted)) – \(selected.end.formatted(date: .abbreviated, time: .omitted))")
          .font(.headline)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], alignment: .leading, spacing: 12) {
        ForEach(1...7, id: \.self) { day in dayColumn(day, snapshot: snapshot) }
      }
    }
  }

  private func dayColumn(_ day: Int, snapshot: ScheduleSnapshot) -> some View {
    let meetings = snapshot.courses.filter { $0.day == day }
    let date = snapshot.weeks.first(where: { $0.number == snapshot.weekNumber })
      .flatMap { Calendar.current.date(byAdding: .day, value: day - 1, to: $0.start) }
    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("周\(["一", "二", "三", "四", "五", "六", "日"][day - 1])").font(.headline)
        Spacer()
        if let date { Text(date.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary) }
      }
      .padding(.bottom, 4)
      if meetings.isEmpty {
        Text("无课程").font(.callout).foregroundStyle(.tertiary).padding(.vertical, 16)
      }
      ForEach(meetings) { meeting in CourseRow(meeting: meeting) }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct CourseRow: View {
  let meeting: CourseMeeting

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(meeting.name).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
      Label("第 \(meeting.startSection)–\(meeting.endSection) 节" + time, systemImage: "clock")
      if let place = meeting.place, !place.isEmpty { Label(place, systemImage: "mappin") }
      if let teacher = meeting.teacher, !teacher.isEmpty { Text(teacher).lineLimit(2) }
    }
    .font(.caption)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
  }

  private var time: String {
    guard let start = meeting.startTime, let end = meeting.endTime else { return "" }
    return " · \(start)–\(end)"
  }
}

import SwiftUI

struct IOSTodayView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var homework: HomeworkViewModel
  @EnvironmentObject private var checkIn: CheckInViewModel
  @EnvironmentObject private var tasks: PersonalTaskStore
  @EnvironmentObject private var campusNotices: CampusNoticesViewModel
  @State private var now = Date()

  var openTasks: () -> Void = {}

  var body: some View {
    List {
      scheduleSection
      checkInSection
      homeworkSection
      tasksSection
      noticesSection
    }
    .listStyle(.insetGrouped)
    .navigationTitle("今天")
    .refreshable { await refresh() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await refresh() }
        } label: {
          if schedule.isLoading || homework.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .accessibilityLabel("刷新今天的数据")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      tasks.load(account: account)
      await schedule.start(account: account)
      await homework.start(account: account)
      await campusNotices.refresh()
    }
    .task {
      while Task.isCancelled == false {
        do { try await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        catch { return }
        now = Date()
      }
    }
    .onChange(of: schedule.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
    .onChange(of: homework.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
  }

  @ViewBuilder
  private var scheduleSection: some View {
    Section {
      if let snapshot = schedule.snapshot {
        let courses = snapshot.todayCourses(now: now)
        if courses.isEmpty {
          ContentUnavailableView {
            Label("今天没有课程", systemImage: "calendar.badge.checkmark")
          } description: {
            Text(schedule.errorMessage == nil
                 ? "当前周次没有查询到今天的课程。"
                 : "课表刷新失败，暂时无法确认今天是否无课。")
          }
        } else {
          ForEach(courses) { meeting in
            HStack(alignment: .top, spacing: 12) {
              IOSCourseTime(meeting: meeting)
              VStack(alignment: .leading, spacing: 4) {
                Text(meeting.name).font(.body.weight(.medium))
                if let place = meeting.place, place.isEmpty == false {
                  Label(place, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Text("第 \(meeting.startSection)–\(meeting.endSection) 节")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 2)
          }
        }

        if let error = schedule.errorMessage {
          IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
        Text("第 \(snapshot.weekNumber) 周 · 更新于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if schedule.isLoading {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在读取课表…")
        }
      } else {
        ContentUnavailableView(
          "课表尚未确认",
          systemImage: "wifi.exclamationmark",
          description: Text(schedule.errorMessage ?? "联网刷新后查看今天的课程。")
        )
      }
    } header: {
      Text("\(now.formatted(.dateTime.month().day().weekday(.wide))) · 今日课程")
    }
  }

  @ViewBuilder
  private var checkInSection: some View {
    Section("课程签到") {
      if let snapshot = checkIn.snapshot {
        let signed = snapshot.items.filter { $0.status == .signed }.count
        let pending = snapshot.items.filter { $0.status == .notSigned || $0.status == .unknown }.count
        LabeledContent("已确认签到", value: "\(signed) / \(snapshot.items.count)")
        if pending > 0 {
          Label("\(pending) 门课程待核对", systemImage: "exclamationmark.circle.fill")
            .foregroundStyle(.orange)
        } else {
          Label("签到状态已核对", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
      } else if checkIn.isLoading {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在核对签到状态…")
        }
      } else {
        Label("签到状态尚未确认", systemImage: "questionmark.circle")
          .foregroundStyle(.secondary)
      }

      NavigationLink {
        IOSCheckInView()
      } label: {
        Label("查看课程签到", systemImage: "checkmark.seal")
      }
    }
  }

  @ViewBuilder
  private var homeworkSection: some View {
    Section("学校作业") {
      if let snapshot = homework.snapshot {
        let pending = snapshot.items.filter { $0.status == .pending || $0.status == .overdue }
          .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        if pending.isEmpty {
          Label("暂无待处理作业", systemImage: "checkmark.circle")
            .foregroundStyle(.secondary)
        } else {
          ForEach(pending.prefix(3)) { item in
            HStack(alignment: .top, spacing: 10) {
              Image(systemName: item.status.symbol)
                .foregroundStyle(item.status.tint)
                .padding(.top, 2)
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title).lineLimit(2)
                Text(item.courseName)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer(minLength: 8)
              if let due = item.dueAt {
                Text(due.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption2)
                  .foregroundStyle(due < now ? Color.orange : Color.secondary)
                  .multilineTextAlignment(.trailing)
              }
            }
          }
        }
        if snapshot.unavailableSources.isEmpty == false {
          IOSInlineMessage(
            "部分作业来源暂时不可用：\(snapshot.unavailableSources.map(\.title).joined(separator: "、"))",
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange
          )
        }
      } else if homework.isLoading {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在检查作业…")
        }
      } else {
        Label("作业状态尚未确认", systemImage: "doc.badge.ellipsis")
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var tasksSection: some View {
    Section {
      let pending = tasks.tasks.filter { $0.completed == false }.sorted { $0.due < $1.due }
      if pending.isEmpty {
        Label("暂无个人待办", systemImage: "checkmark.circle")
          .foregroundStyle(.secondary)
      } else {
        ForEach(pending.prefix(3)) { task in
          HStack(spacing: 10) {
            Button {
              tasks.toggle(task.id)
            } label: {
              Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成待办：\(task.title)")

            VStack(alignment: .leading, spacing: 3) {
              Text(task.title).lineLimit(2)
              Text(task.due.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(task.due < now ? Color.orange : Color.secondary)
            }
          }
        }
      }
      Button("查看全部待办", action: openTasks)
    } header: {
      Text("个人待办")
    }
  }

  @ViewBuilder
  private var noticesSection: some View {
    Section("北航通知") {
      if campusNotices.notices.isEmpty {
        if campusNotices.isLoading {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取通知…")
          }
        } else {
          Text("暂无可显示的通知")
            .foregroundStyle(.secondary)
        }
      } else {
        ForEach(campusNotices.notices.prefix(3)) { notice in
          Link(destination: notice.url) {
            VStack(alignment: .leading, spacing: 3) {
              Text(notice.title)
                .foregroundStyle(.primary)
                .lineLimit(2)
              Text(notice.publishedAt)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private func refresh() async {
    guard let account = appState.user?.schoolid else { return }
    tasks.load(account: account)
    await schedule.refreshToday()
    await homework.refresh()
    await checkIn.refresh()
    await campusNotices.refresh(force: true)
  }
}

import SwiftUI
import UserNotifications

/// 应用入口：主窗口（NavigationSplitView 布局）+ 菜单栏常驻入口。
/// 布局规范见 ARCHITECTURE.md §10（主窗口最小 800×560，菜单栏弹出面板宽 360）。
@main
struct BUAAAssistantApp: App {
  @StateObject private var appState = AppState()
  @StateObject private var globalShortcut = GlobalShortcutController()
  @StateObject private var courseReminders = CourseReminderScheduler()
  @StateObject private var updates = UpdateCenter()
  private let scheduleRepository = DefaultScheduleRepository()
  private let gradeRepository = DefaultGradeRepository()

  init() {
    UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
  }

  var body: some Scene {
    WindowGroup(id: "main") {
      RootView()
        .environmentObject(appState)
        .environmentObject(courseReminders)
        .environmentObject(updates)
        .frame(minWidth: 800, minHeight: 560)
    }
    .defaultSize(width: 1200, height: 800)
    .commands {
      CommandGroup(after: .appInfo) {
        Toggle("全局快捷键（⌃⌥B）", isOn: Binding(
          get: { globalShortcut.isEnabled },
          set: { globalShortcut.setEnabled($0) }
        ))
      }
    }

    MenuBarExtra(appState.isLoggedIn ? "Ginkgo（已连接）" : "Ginkgo", systemImage: menuBarIcon) {
      MenuBarPanel(scheduleRepository: scheduleRepository, gradeRepository: gradeRepository)
        .environmentObject(appState)
        .frame(width: 360)
    }
    .menuBarExtraStyle(.window)
  }

  private var menuBarIcon: String {
    appState.isLoggedIn ? "checkmark.circle.fill" : "graduationcap"
  }
}

/// 菜单栏只展示最近同步的摘要；打开主窗口后各模块会主动刷新。
struct MenuBarPanel: View {
  @EnvironmentObject private var appState: AppState
  private let scheduleRepository: ScheduleRepository
  private let gradeRepository: GradeRepository
  @State private var schedule: ScheduleSnapshot?
  @State private var grades: GradeSnapshot?

  init(scheduleRepository: ScheduleRepository, gradeRepository: GradeRepository) {
    self.scheduleRepository = scheduleRepository
    self.gradeRepository = gradeRepository
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Ginkgo", systemImage: "graduationcap")
          .font(.headline)
        Spacer()
      }

      if appState.isLoggedIn {
        if let schedule, schedule.containsToday() {
          let today = todayCourses(schedule)
          if let next = today.first(where: { meeting in
            guard let time = meeting.startTime else { return true }
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return true }
            let calendar = SchoolTime.calendar
            let now = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
            return parts[0] * 60 + parts[1] >= now
          }) {
            VStack(alignment: .leading, spacing: 4) {
              Text("下一节课").font(.caption).foregroundStyle(.secondary)
              Text(next.name).font(.headline)
              Text([next.startTime ?? "第 \(next.startSection) 节", next.place].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
            }
          } else {
            Label(today.isEmpty ? "今日课表无课程" : "今天的课程已结束", systemImage: "calendar.badge.checkmark")
              .font(.subheadline)
          }
          Text("课表同步：\(schedule.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Label("今日课程尚未确认，请打开主窗口刷新", systemImage: "calendar.badge.exclamationmark")
            .font(.subheadline)
        }
        if let grades, let gpa = grades.gradePointAverage {
          Label("\(grades.term.name)参考绩点 \(gpa.formatted(.number.precision(.fractionLength(2))))", systemImage: "chart.bar")
            .font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Label("未登录", systemImage: "person.crop.circle")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Divider()

      Button("打开主窗口") {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
          window.makeKeyAndOrderFront(nil)
        }
      }

      Button("退出 Ginkgo") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")

      Divider()

      Link(destination: URL(string: "https://github.com/JUANWANG-BUAA/ginkgo")!) {
        Label("GitHub 项目主页", systemImage: "star")
          .font(.caption)
      }
    }
    .padding(16)
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { schedule = nil; grades = nil; return }
      schedule = await scheduleRepository.cachedSnapshot(account: account)
      grades = await gradeRepository.cachedSnapshot(account: account)
    }
    .onAppear {
      Task {
        guard let account = appState.user?.schoolid else { return }
        schedule = await scheduleRepository.cachedSnapshot(account: account)
        grades = await gradeRepository.cachedSnapshot(account: account)
      }
    }
  }

  private func todayCourses(_ snapshot: ScheduleSnapshot) -> [CourseMeeting] {
    snapshot.todayCourses()
  }
}

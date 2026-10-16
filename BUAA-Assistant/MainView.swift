import SwiftUI

/// 主界面：侧边栏 + 详情区双栏布局（ARCHITECTURE.md §10.10）。
/// 登录会话内持有模块模型，切换页面保留同步状态。
struct MainView: View {
  /// 侧边栏条目。注意不要命名为 Section（会与 SwiftUI 的 Section 视图撞名）。
  enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case today = "今天"
    case checkIn = "课程签到"
    case schedule = "课表"
    case grade = "成绩"
    case homework = "学校作业"
    case library = "图书馆"
    case classroom = "空教室"
    case tasks = "待办"
    case settings = "设置"

    var id: String { rawValue }

    var systemImage: String {
      switch self {
      case .today: return "sun.max.fill"
      case .checkIn: return "checkmark.seal.fill"
      case .schedule: return "calendar"
      case .grade: return "chart.bar.fill"
      case .homework: return "doc.text.fill"
      case .library: return "books.vertical.fill"
      case .classroom: return "building.2"
      case .tasks: return "checklist"
      case .settings: return "gearshape.fill"
      }
    }

    /// 该模块的实施顺序与依据（docs/ROADMAP.md）。
    var roadmapNote: String {
      switch self {
      case .today: return "今日课程"
      case .checkIn: return "iclass 签到查询与手动提交"
      case .schedule: return "ROADMAP Step 3-4（API.md §2 本科 / §3 研究生）"
      case .grade: return "ROADMAP Step 5（API.md §4 buaascore）"
      case .homework: return "Judge 与 SPOC 只读查询（待真实账号验收）"
      case .library: return "ROADMAP Step 6（API.md §5 座位 · §6 借阅为探索项）"
      case .classroom: return "空教室查询"
      case .tasks: return "本地待办"
      case .settings: return "骨架已就绪"
      }
    }
  }

  @StateObject private var schedule = ScheduleViewModel()
  @StateObject private var exams = ExamViewModel()
  @StateObject private var grades = GradeViewModel()
  @StateObject private var homework = HomeworkViewModel()
  @StateObject private var library = LibraryViewModel()
  @StateObject private var campusNotices = CampusNoticesViewModel()
  @StateObject private var classroom = ClassroomViewModel()
  @StateObject private var checkIn = CheckInViewModel()
  @StateObject private var tasks = PersonalTaskStore()
  @State private var selectedSection: AppSection? = .today
  @State private var hoveredSection: AppSection?
  @Namespace private var sidebarSelection
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var courseReminders: CourseReminderScheduler

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        sidebarIdentity
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            sidebarGroup("工作台", sections: [.today, .checkIn])
            sidebarGroup("学习", sections: [.schedule, .grade, .homework])
            sidebarGroup("校园", sections: [.library, .classroom, .tasks])
          }
          .padding(.horizontal, 12)
          .padding(.top, 15)
          .padding(.bottom, 14)
        }
        sidebarFooter
      }
      .background(Color(nsColor: .underPageBackgroundColor))
      .navigationSplitViewColumnWidth(min: 218, ideal: 248, max: 288)
    } detail: {
      ZStack {
        sectionDestination
          .id(selectedSection)
          .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8)),
            removal: .opacity
          ))
      }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selectedSection)
    }
    .environmentObject(schedule)
    .environmentObject(exams)
    .environmentObject(grades)
    .environmentObject(homework)
    .environmentObject(library)
    .environmentObject(campusNotices)
    .environmentObject(checkIn)
    .environmentObject(tasks)
    .environmentObject(classroom)
    .navigationTitle(selectedSection?.rawValue ?? "BUAA Assistant")
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else {
        await courseReminders.update(snapshot: nil)
        await checkIn.setWebVPNRouteEnabled(false)
        checkIn.reset()
        library.reset()
        return
      }
      await courseReminders.update(snapshot: nil)
      await checkIn.setWebVPNRouteEnabled(appState.webVPNSessionStatus == .ready)
      await checkIn.start(account: account)
      await courseReminders.update(snapshot: schedule.snapshot)
      while !Task.isCancelled {
        let delay: UInt64 = checkIn.errorMessage == nil ? 30 : 120
        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
        guard !Task.isCancelled else { return }
        await checkIn.refresh()
      }
    }
    .onChange(of: checkIn.needsSessionCheck) { _, needed in
      if needed {
        Task {
          if (try? await appState.confirmSessionAfterAuthFailure()) == true {
            await checkIn.refreshAfterSessionValidation()
          }
        }
      }
    }
    .onChange(of: checkIn.webVPNAuthenticationUnavailable) { _, unavailable in
      if unavailable { appState.markWebVPNSessionUnavailable() }
    }
    .onChange(of: appState.webVPNSessionStatus) { _, status in
      Task {
        await checkIn.setWebVPNRouteEnabled(status == .ready)
        if status == .ready {
          checkIn.clearWebVPNAuthenticationFailure()
          await checkIn.refresh()
        }
      }
    }
    .onChange(of: checkIn.statusChangeRevision) { _, revision in
      guard revision > 0, let message = checkIn.statusChangeMessage else { return }
      appState.showToast(message)
      checkIn.notifyStatusChange()
    }
    .onChange(of: schedule.reminderRevision) { _, _ in
      Task { await courseReminders.update(snapshot: schedule.snapshot) }
    }
    .onChange(of: courseReminders.isEnabled) { _, _ in
      Task { await courseReminders.update(snapshot: schedule.snapshot) }
    }
  }

  private var sidebarIdentity: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ))
        Image(systemName: "graduationcap.fill")
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: 40, height: 40)
      VStack(alignment: .leading, spacing: 3) {
        Text("BUAA Assistant")
          .font(.system(.headline, design: .rounded).weight(.semibold))
          .lineLimit(1)
        HStack(spacing: 5) {
          Text(appState.user?.name ?? "校园工作台")
            .lineLimit(1)
          Circle()
            .fill(appState.isLoggedIn ? Color.green : Color.orange)
            .frame(width: 5, height: 5)
          Text(appState.isLoggedIn ? "已连接" : "未登录")
            .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 18)
    .padding(.top, 20)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1).padding(.horizontal, 14)
    }
  }

  private var sidebarFooter: some View {
    VStack(spacing: 10) {
      Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
      navRow(.settings)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    .padding(.top, 8)
  }

  private struct SidebarIndicator: Equatable {
    let title: String
    let tint: Color
    let symbol: String?
    let accessibilityText: String
  }

  private func sidebarIndicator(for section: AppSection) -> SidebarIndicator? {
    switch section {
    case .checkIn:
      if checkIn.snapshot == nil, checkIn.errorMessage != nil {
        return SidebarIndicator(title: "!", tint: .orange, symbol: nil, accessibilityText: "签到状态未确认")
      }
      guard let snapshot = checkIn.snapshot else { return nil }
      let unknownCount = snapshot.items.filter { $0.status == .unknown }.count
      if unknownCount > 0 {
        return SidebarIndicator(title: "?", tint: .orange, symbol: nil, accessibilityText: "有课程签到状态未确认")
      }
      let unsignedCount = snapshot.items.filter { $0.status == .notSigned }.count
      if unsignedCount > 0 {
        return SidebarIndicator(title: "\(unsignedCount)", tint: .orange, symbol: nil, accessibilityText: "\(unsignedCount) 门课程待签到")
      }
      return SidebarIndicator(title: "", tint: .green, symbol: "checkmark", accessibilityText: "签到状态已核对")
    case .homework:
      guard let snapshot = homework.snapshot else {
        return homework.errorMessage == nil ? nil : SidebarIndicator(title: "!", tint: .orange, symbol: nil, accessibilityText: "作业状态未确认")
      }
      let urgentCount = homework.attentionItems().count
      if urgentCount == 0 {
        return snapshot.unavailableSources.isEmpty ? nil : SidebarIndicator(title: "!", tint: .orange, symbol: nil, accessibilityText: "部分作业来源未更新")
      }
      let count = snapshot.unavailableSources.isEmpty ? "\(urgentCount)" : "\(urgentCount)+"
      return SidebarIndicator(title: count, tint: .orange, symbol: nil, accessibilityText: "\(count) 项作业即将截止")
    case .tasks:
      let pendingCount = tasks.tasks.filter { !$0.completed }.count
      guard pendingCount > 0 else { return nil }
      return SidebarIndicator(title: "\(pendingCount)", tint: .secondary, symbol: nil, accessibilityText: "\(pendingCount) 项个人待办")
    default:
      return nil
    }
  }

  @ViewBuilder
  private func sidebarIndicatorView(_ indicator: SidebarIndicator?) -> some View {
    if let indicator {
      Group {
        if let symbol = indicator.symbol {
          Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .frame(minWidth: 18, minHeight: 18)
        } else {
          Text(indicator.title)
            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
            .padding(.horizontal, 6)
            .frame(minWidth: 18, minHeight: 18)
        }
      }
      .foregroundStyle(indicator.tint)
      .background(indicator.tint.opacity(0.12), in: Capsule())
      .transition(.scale(scale: 0.8).combined(with: .opacity))
      .accessibilityHidden(true)
    }
  }

  private var sectionDestination: some View {
    Group {
      switch selectedSection {
      case .today: TodayView(openTasks: { select(.tasks) })
      case .checkIn: CheckInPage()
      case .schedule: ScheduleView()
      case .grade: GradeView()
      case .homework: HomeworkView()
      case .library: LibraryView()
      case .classroom: ClassroomView()
      case .tasks: TasksView()
      case .settings: SettingsView()
      case nil: Text("请选择一个功能").foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func sidebarGroup(_ title: String, sections: [AppSection]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .tracking(0.7)
        .foregroundStyle(.tertiary)
        .padding(.leading, 11)
        .padding(.bottom, 2)

      VStack(spacing: 2) {
        ForEach(sections) { section in navRow(section) }
      }
    }
  }

  private func navRow(_ section: AppSection) -> some View {
    let isSelected = selectedSection == section
    let isHovered = hoveredSection == section
    let indicator = sidebarIndicator(for: section)
    return Button {
      select(section)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: section.systemImage)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
          .frame(width: 19)
          .symbolEffect(.bounce, value: isSelected && !reduceMotion)
        Text(section.rawValue)
          .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
          .lineLimit(1)
        Spacer(minLength: 0)
        sidebarIndicatorView(indicator)
      }
      .padding(.leading, 12)
      .padding(.trailing, 11)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(isSelected ? Color.accentColor.opacity(0.11) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
      }
      .overlay {
        if isSelected {
          HStack {
            Capsule()
              .fill(Color.accentColor)
              .frame(width: 3, height: 17)
              .matchedGeometryEffect(id: "active-sidebar-item", in: sidebarSelection)
            Spacer(minLength: 0)
          }
          .padding(.leading, 3)
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
      .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: indicator)
    }
    .buttonStyle(.plain)
    .onHover { hovering in hoveredSection = hovering ? section : (hoveredSection == section ? nil : hoveredSection) }
    .accessibilityLabel(section.rawValue + (indicator.map { "，\($0.accessibilityText)" } ?? ""))
    .accessibilityHint("打开\(section.rawValue)")
    .accessibilityValue(isSelected ? "当前页面" : "未选择")
  }

  private func select(_ section: AppSection) {
    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
      selectedSection = section
    }
  }
}

/// 占位详情页的统一样式。
struct PlaceholderPage: View {
  let title: String
  let systemImage: String
  let roadmapNote: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.title2.weight(.semibold))
      Text("此模块尚未实施")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(roadmapNote)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

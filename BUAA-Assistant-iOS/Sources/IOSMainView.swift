import SwiftUI

private enum IOSPrimaryTab: Hashable {
  case today
  case schedule
  case homework
  case library
  case more
}

/// Adaptive iOS shell. iPhone uses a five-tab information architecture; iPad and
/// landscape regular-width layouts use the same sidebar hierarchy as macOS.
/// 会话生命周期由共享的 `WorkspaceLifecycleModifier` 处理，这里只保留导航结构。
struct IOSMainView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var workspace: WorkspaceCoordinator
  @EnvironmentObject private var tasks: PersonalTaskStore
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var selectedSection: WorkspaceFeature? = .today
  @State private var tab: IOSPrimaryTab = .today
  @State private var morePath: [WorkspaceFeature] = []

  var body: some View {
    Group {
      if horizontalSizeClass == .regular {
        regularLayout
      } else {
        compactLayout
      }
    }
    .workspaceLifecycle(workspace: workspace, feature: currentFeature)
  }

  private var regularLayout: some View {
    NavigationSplitView {
      List(selection: $selectedSection) {
        Section("工作台") {
          sidebarRow(.today)
          sidebarRow(.checkIn)
        }
        Section("学习") {
          sidebarRow(.schedule)
          sidebarRow(.graduateAcademic)
          sidebarRow(.grade)
          sidebarRow(.homework)
          sidebarRow(.bykc)
        }
        Section("校园") {
          sidebarRow(.library)
          sidebarRow(.seminar)
          sidebarRow(.classroom)
          sidebarRow(.tasks)
        }
        Section {
          sidebarRow(.settings)
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("Ginkgo")
      .safeAreaInset(edge: .bottom) {
        sidebarAccount
      }
    } detail: {
      NavigationStack {
        IOSSectionDestination(section: selectedSection ?? .today) {
          selectedSection = .tasks
        }
      }
    }
    .tint(.accentColor)
  }

  private var compactLayout: some View {
    TabView(selection: $tab) {
      NavigationStack {
        primaryDestination(.today)
      }
      .tabItem { Label("今天", systemImage: "sun.max.fill") }
      .tag(IOSPrimaryTab.today)

      NavigationStack {
        primaryDestination(.schedule)
      }
      .tabItem { Label("课表", systemImage: "calendar") }
      .tag(IOSPrimaryTab.schedule)

      NavigationStack {
        primaryDestination(.homework)
      }
      .tabItem { Label("作业", systemImage: "doc.text.fill") }
      .tag(IOSPrimaryTab.homework)

      NavigationStack {
        primaryDestination(.library)
      }
      .tabItem { Label("图书馆", systemImage: "books.vertical.fill") }
      .tag(IOSPrimaryTab.library)

      NavigationStack(path: $morePath) {
        IOSMoreView()
          .navigationDestination(for: WorkspaceFeature.self) { section in
            IOSSectionDestination(section: section)
          }
      }
      .tabItem { Label("更多", systemImage: "ellipsis.circle.fill") }
      .badge(pendingTaskCount)
      .tag(IOSPrimaryTab.more)
    }
    .tint(.accentColor)
  }

  @ViewBuilder
  private func primaryDestination(_ section: WorkspaceFeature) -> some View {
    IOSSectionDestination(section: section) {
      tab = .more
      morePath = [.tasks]
    }
  }

  private func sidebarRow(_ section: WorkspaceFeature) -> some View {
    Label(section.title, systemImage: section.systemImage)
      .tag(section)
      .accessibilityHint("打开\(section.title)")
  }

  private var sidebarAccount: some View {
    HStack(spacing: 10) {
      Image(systemName: "person.crop.circle.fill")
        .font(.title3)
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text(appState.user?.name ?? "校园账号")
          .font(.callout.weight(.medium))
          .lineLimit(1)
        Text(appState.user?.schoolid ?? "")
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      Circle()
        .fill(Color.green)
        .frame(width: 7, height: 7)
        .accessibilityLabel("已连接")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var currentFeature: WorkspaceFeature {
    if horizontalSizeClass == .regular {
      return selectedSection ?? .today
    }
    switch tab {
    case .today: return .today
    case .schedule: return .schedule
    case .homework: return .homework
    case .library: return .library
    case .more: return morePath.last ?? .settings
    }
  }

  private var pendingTaskCount: Int {
    tasks.tasks.filter { $0.completed == false }.count
  }
}

struct IOSSectionDestination: View {
  let section: WorkspaceFeature
  var openTasks: () -> Void = {}

  @ViewBuilder
  var body: some View {
    switch section {
    case .today:
      IOSTodayView(openTasks: openTasks)
    case .checkIn:
      IOSCheckInView()
    case .schedule:
      IOSScheduleView()
    case .graduateAcademic:
      IOSGraduateAcademicView()
    case .grade:
      IOSGradeView()
    case .homework:
      IOSHomeworkView()
    case .bykc:
      IOSBykcView()
    case .library:
      IOSLibraryView()
    case .seminar:
      IOSCgyyView()
    case .classroom:
      IOSClassroomView()
    case .tasks:
      IOSTasksView()
    case .settings:
      IOSSettingsView()
    }
  }
}

private struct IOSMoreView: View {
  @EnvironmentObject private var tasks: PersonalTaskStore
  @EnvironmentObject private var checkIn: CheckInViewModel

  var body: some View {
    List {
      Section("工作台") {
        NavigationLink(value: WorkspaceFeature.checkIn) {
          Label("课程签到", systemImage: "checkmark.seal.fill")
        }
        .badge(pendingCheckInCount)
      }

      Section("学习") {
        NavigationLink(value: WorkspaceFeature.grade) {
          Label("成绩", systemImage: "chart.bar.fill")
        }
        NavigationLink(value: WorkspaceFeature.bykc) {
          Label("博雅", systemImage: "graduationcap.fill")
        }
        NavigationLink(value: WorkspaceFeature.graduateAcademic) {
          Label("研究生教务", systemImage: "building.columns.fill")
        }
        NavigationLink(value: WorkspaceFeature.seminar) {
          Label("研讨室", systemImage: "person.3.sequence.fill")
        }
        NavigationLink(value: WorkspaceFeature.classroom) {
          Label("空教室", systemImage: "building.2")
        }
      }

      Section("校园") {
        NavigationLink(value: WorkspaceFeature.tasks) {
          Label("待办", systemImage: "checklist")
        }
        .badge(pendingTaskCount)
      }

      Section {
        NavigationLink(value: WorkspaceFeature.settings) {
          Label("设置", systemImage: "gearshape.fill")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("更多")
  }

  private var pendingTaskCount: Int {
    tasks.tasks.filter { $0.completed == false }.count
  }

  private var pendingCheckInCount: Int {
    checkIn.snapshot?.items.filter { $0.status == .notSigned || $0.status == .unknown }.count ?? 0
  }
}

import SwiftUI

/// 主界面：侧边栏 + 详情区双栏布局（ARCHITECTURE.md §10.10）。
/// 登录会话内持有模块模型，切换页面保留同步状态。
struct MainView: View {
  /// 侧边栏条目。注意不要命名为 Section（会与 SwiftUI 的 Section 视图撞名）。
  enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case today = "今天"
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
      case .schedule: return "ROADMAP Step 3-4（API.md §2 本科 / §3 研究生）"
      case .grade: return "ROADMAP Step 5（API.md §4 buaascore）"
      case .homework: return "待完成：希冀作业只读协议取证"
      case .library: return "ROADMAP Step 6（API.md §5 座位 · §6 借阅为探索项）"
      case .classroom: return "空教室查询"
      case .tasks: return "本地待办"
      case .settings: return "骨架已就绪"
      }
    }
  }

  @StateObject private var schedule = ScheduleViewModel()
  @StateObject private var grades = GradeViewModel()
  @StateObject private var homework = HomeworkViewModel()
  @StateObject private var classroom = ClassroomViewModel()
  @StateObject private var tasks = PersonalTaskStore()
  @State private var selectedSection: AppSection? = .today
  @EnvironmentObject private var appState: AppState

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedSection) {
        Label(AppSection.today.rawValue, systemImage: AppSection.today.systemImage)
          .tag(AppSection.today)
        SwiftUI.Section("学术") {
          Label(AppSection.schedule.rawValue, systemImage: AppSection.schedule.systemImage)
            .tag(AppSection.schedule)
          Label(AppSection.grade.rawValue, systemImage: AppSection.grade.systemImage)
            .tag(AppSection.grade)
          Label(AppSection.homework.rawValue, systemImage: AppSection.homework.systemImage)
            .tag(AppSection.homework)
        }
        SwiftUI.Section("校园服务") {
          Label(AppSection.library.rawValue, systemImage: AppSection.library.systemImage).tag(AppSection.library)
          Label(AppSection.classroom.rawValue, systemImage: AppSection.classroom.systemImage).tag(AppSection.classroom)
          Label(AppSection.tasks.rawValue, systemImage: AppSection.tasks.systemImage).tag(AppSection.tasks)
        }
        SwiftUI.Section("系统") {
          Label(AppSection.settings.rawValue, systemImage: AppSection.settings.systemImage)
            .tag(AppSection.settings)
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    } detail: {
      switch selectedSection {
      case .today: TodayView(openTasks: { selectedSection = .tasks })
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
    .environmentObject(schedule)
    .environmentObject(grades)
    .environmentObject(homework)
    .environmentObject(tasks)
    .environmentObject(classroom)
    .navigationTitle(selectedSection?.rawValue ?? "BUAA Assistant")
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

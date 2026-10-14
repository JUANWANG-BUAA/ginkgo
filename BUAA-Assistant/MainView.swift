import SwiftUI

/// 主界面：侧边栏 + 详情区双栏布局（ARCHITECTURE.md §10.10）。
/// 各详情页当前为占位骨架，按 docs/ROADMAP.md 的顺序逐个替换为真实实现。
struct MainView: View {
  /// 侧边栏条目。注意不要命名为 Section（会与 SwiftUI 的 Section 视图撞名）。
  enum AppSection: String, Hashable, CaseIterable, Identifiable {
    case schedule = "课表"
    case grade = "成绩"
    case library = "图书馆"
    case settings = "设置"

    var id: String { rawValue }

    var systemImage: String {
      switch self {
      case .schedule: return "calendar"
      case .grade: return "chart.bar.fill"
      case .library: return "books.vertical.fill"
      case .settings: return "gearshape.fill"
      }
    }

    /// 该模块的实施顺序与依据（docs/ROADMAP.md）。
    var roadmapNote: String {
      switch self {
      case .schedule: return "ROADMAP Step 3-4（API.md §2 本科 / §3 研究生）"
      case .grade: return "ROADMAP Step 5（API.md §4 buaascore）"
      case .library: return "ROADMAP Step 6（API.md §5 座位 · §6 借阅为探索项）"
      case .settings: return "骨架已就绪"
      }
    }
  }

  @State private var selectedSection: AppSection? = .schedule
  @EnvironmentObject private var appState: AppState

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedSection) {
        SwiftUI.Section("学术") {
          Label(AppSection.schedule.rawValue, systemImage: AppSection.schedule.systemImage)
            .tag(AppSection.schedule)
          Label(AppSection.grade.rawValue, systemImage: AppSection.grade.systemImage)
            .tag(AppSection.grade)
        }
        SwiftUI.Section("服务") {
          Label(AppSection.library.rawValue, systemImage: AppSection.library.systemImage)
            .tag(AppSection.library)
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
      case .schedule: ScheduleView()
      case .grade: GradeView()
      case .library: LibraryView()
      case .settings: SettingsView()
      case nil: Text("请选择一个功能").foregroundStyle(.secondary)
      }
    }
    .navigationTitle(selectedSection?.rawValue ?? "BUAA Assistant")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          // 数据刷新在各模块接入后按模块实现（Stale-While-Revalidate，ARCHITECTURE.md §4.2）
        } label: {
          Label("刷新数据", systemImage: "arrow.clockwise")
        }
        .accessibilityLabel("刷新数据")
      }
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

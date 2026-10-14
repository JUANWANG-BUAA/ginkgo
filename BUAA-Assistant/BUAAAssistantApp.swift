import SwiftUI

/// 应用入口：主窗口（NavigationSplitView 布局）+ 菜单栏常驻入口。
/// 布局规范见 ARCHITECTURE.md §10（主窗口最小 800×560，菜单栏弹出面板宽 360）。
@main
struct BUAAAssistantApp: App {
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(appState)
        .frame(minWidth: 800, minHeight: 560)
    }

    MenuBarExtra(appState.isLoggedIn ? "BUAA Assistant（已连接）" : "BUAA Assistant", systemImage: menuBarIcon) {
      MenuBarPanel()
        .environmentObject(appState)
        .frame(width: 360)
    }
    .menuBarExtraStyle(.window)
  }

  private var menuBarIcon: String {
    appState.isLoggedIn ? "checkmark.circle.fill" : "graduationcap"
  }
}

/// 菜单栏弹出面板（骨架态）。数据卡片在课表/成绩模块完成后填充。
struct MenuBarPanel: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("BUAA Assistant", systemImage: "graduationcap")
          .font(.headline)
        Spacer()
      }

      if appState.isLoggedIn {
        Label(
          appState.user.map { "已登录：\($0.name)（\($0.schoolid)）" } ?? "已登录",
          systemImage: "person.crop.circle.fill"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
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

      Button("退出 BUAA Assistant") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    }
    .padding(16)
  }
}

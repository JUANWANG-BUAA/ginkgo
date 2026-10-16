import SwiftUI

/// 根视图：按登录态切换 登录页 / 主界面。
/// 切换动效遵循 ARCHITECTURE.md §10.7 的弹簧参数。
struct RootView: View {
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var courseReminders: CourseReminderScheduler
  @EnvironmentObject private var updates: UpdateCenter
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.openWindow) private var openWindow
  /// 启动时让窗口内容做一次很轻的淡入；macOS 习惯是不做品牌闪屏。
  @State private var contentVisible = false

  var body: some View {
    ZStack {
      if appState.isRestoring {
        ProgressView(appState.restoreMessage)
      } else if appState.isLoggedIn {
        MainView()
          .id(appState.user?.schoolid)
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
      } else {
        LoginView()
          .transition(.opacity)
      }
    }
    .opacity(contentVisible ? 1 : 0)
    .onAppear {
      if reduceMotion {
        contentVisible = true
      } else {
        withAnimation(.easeOut(duration: 0.25)) { contentVisible = true }
      }
    }
    .overlay(alignment: .top) {
      if let toast = appState.toast {
        Label(toast, systemImage: appState.toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
          .font(.callout.weight(.medium))
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
          .padding(.top, 18)
          .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
          .accessibilityAddTraits(.updatesFrequently)
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: appState.isLoggedIn)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: appState.toast)
    .onAppear {
      AppWindowRouter.shared.setOpenMainWindow { openWindow(id: "main") }
    }
    .task {
      await appState.restoreSession()
      if !appState.isLoggedIn { await courseReminders.update(snapshot: nil) }
      // 启动时静默检查更新（每天最多一次）；有新版时用应用内提示告知。
      await updates.autoCheckIfDue()
      if let release = updates.latest {
        appState.showToast("发现新版本 \(release.displayVersion)，可在设置中更新")
      }
    }
    .task(id: appState.isRestoring) {
      guard !appState.isRestoring else { return }
      // 启动时静默检查更新（每天最多一次）；有新版时用应用内提示告知。
      await updates.autoCheckIfDue()
      if let release = updates.latest {
        appState.showToast("发现新版本 \(release.displayVersion)，可在设置中更新")
      }
    }
    .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
      if !isLoggedIn { Task { await courseReminders.update(snapshot: nil) } }
    }
    .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
  }
}

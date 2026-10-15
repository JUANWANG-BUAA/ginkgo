import SwiftUI

/// 根视图：按登录态切换 登录页 / 主界面。
/// 切换动效遵循 ARCHITECTURE.md §10.7 的弹簧参数。
struct RootView: View {
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    .task { await appState.restoreSession() }
    .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
  }
}

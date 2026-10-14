import SwiftUI

/// 根视图：按登录态切换 登录页 / 主界面。
/// 切换动效遵循 ARCHITECTURE.md §10.7 的弹簧参数。
struct RootView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    ZStack {
      if appState.isLoggedIn {
        MainView()
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
      } else {
        LoginView()
          .transition(.opacity)
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.isLoggedIn)
  }
}

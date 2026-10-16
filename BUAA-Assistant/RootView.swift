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
  /// 启动入场动画只在本次进程内播放一次；「减少动态效果」时直接跳过。
  @State private var showLaunchIntro = false
  @State private var didPlayLaunchIntro = false

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
      if showLaunchIntro {
        LaunchIntroView()
          .transition(.opacity)
          .allowsHitTesting(false)
          .zIndex(2)
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
      // 启动入场：等会话恢复结束后播一次短动画；不阻塞操作（约 0.9s 后自动淡出）。
      guard !appState.isRestoring, !reduceMotion, !didPlayLaunchIntro else { return }
      didPlayLaunchIntro = true
      showLaunchIntro = true
      do { try await Task.sleep(nanoseconds: 900_000_000) } catch { return }
      withAnimation(.easeOut(duration: 0.35)) { showLaunchIntro = false }
    }
    .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
      if !isLoggedIn { Task { await courseReminders.update(snapshot: nil) } }
    }
    .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
  }
}

/// 启动入场动画：短暂展示品牌标识后淡出。
/// 遵循 macOS 习惯：不阻塞交互（allowsHitTesting(false)）、时长不足 1 秒；
/// 开启「减少动态效果」时由 RootView 直接跳过，不播放位移或缩放。
private struct LaunchIntroView: View {
  @State private var appeared = false

  var body: some View {
    ZStack {
      Rectangle().fill(.ultraThinMaterial)
      VStack(spacing: 18) {
        ZStack {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 88, height: 88)
            .shadow(color: Color.accentColor.opacity(0.32), radius: 22, y: 10)
          Image(systemName: "graduationcap.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white)
        }
        VStack(spacing: 4) {
          Text("Ginkgo").font(.system(.title2, design: .rounded).weight(.semibold))
          Text("北航校园工作台").font(.caption).foregroundStyle(.secondary)
        }
      }
      .scaleEffect(appeared ? 1 : 0.94)
      .opacity(appeared ? 1 : 0)
    }
    .ignoresSafeArea()
    .onAppear {
      withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { appeared = true }
    }
    .accessibilityHidden(true)
  }
}

import SwiftUI

struct IOSRootView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var courseReminders: CourseReminderScheduler
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @State private var contentVisible = false

  var body: some View {
    ZStack {
      Color.ginkgoWindowBackground.ignoresSafeArea()
      content
    }
    .opacity(contentVisible ? 1 : 0)
    .overlay(alignment: .bottom) { toast }
    .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: appState.isLoggedIn)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: appState.toast)
    .onAppear {
      if reduceMotion {
        contentVisible = true
      } else {
        withAnimation(.easeOut(duration: 0.25)) { contentVisible = true }
      }
    }
    .task {
      #if DEBUG
      if ProcessInfo.processInfo.environment["GINKGO_DEMO_MODE"] == "1" {
        appState.isRestoring = false
        appState.acceptExistingSession(UserData(schoolid: "demo", name: "演示用户"))
        await courseReminders.update(snapshot: nil)
        return
      }
      #endif
      await appState.restoreSession()
      if appState.isLoggedIn == false {
        await courseReminders.update(snapshot: nil)
      }
    }
    .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
      if isLoggedIn == false {
        Task { await courseReminders.update(snapshot: nil) }
      }
    }
  }

  #if DEBUG
  private var isDemoMode: Bool {
    ProcessInfo.processInfo.environment["GINKGO_DEMO_MODE"] == "1"
  }
  #endif

  @ViewBuilder
  private var content: some View {
    #if DEBUG
    if isDemoMode {
      WorkspaceHost { IOSMainView() }
        .id("demo-shell")
    } else {
      regularContent
    }
    #else
    regularContent
    #endif
  }

  @ViewBuilder
  private var regularContent: some View {
    if appState.isRestoring {
      VStack(spacing: 16) {
        ProgressView().controlSize(.large)
        Text(appState.restoreMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    } else if appState.isLoggedIn {
      WorkspaceHost { IOSMainView() }
        .id(appState.user?.schoolid)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
    } else {
      IOSLoginView()
        .transition(.opacity)
    }
  }

  @ViewBuilder
  private var toast: some View {
    if let toast = appState.toast {
      Label(toast, systemImage: appState.toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .font(.callout.weight(.medium))
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, appState.isLoggedIn ? 88 : 20)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.updatesFrequently)
    }
  }
}

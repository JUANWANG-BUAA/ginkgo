import SwiftUI

/// 两个应用壳共用的生命周期编排。壳层只需要声明“当前可见分区”，
/// 轮询、提醒、WebVPN 与前后台刷新都在这里统一处理，避免两端各抄一份后逐渐分叉。
struct WorkspaceLifecycleModifier: ViewModifier {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var courseReminders: CourseReminderScheduler
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var checkIn: CheckInViewModel
  @Environment(\.scenePhase) private var scenePhase

  let workspace: WorkspaceCoordinator
  let feature: WorkspaceFeature

  func body(content: Content) -> some View {
    content
      .task(id: appState.user?.schoolid) {
        await workspace.activateSession(
          account: appState.user?.schoolid,
          appState: appState,
          reminders: courseReminders
        )
      }
      .task {
        workspace.prepare(feature: feature, sceneActive: scenePhase == .active)
      }
      .onChange(of: feature) { _, feature in
        workspace.select(feature: feature)
      }
      .onChange(of: scenePhase) { _, phase in
        workspace.setSceneActive(phase == .active)
        guard phase == .active else { return }
        Task { await courseReminders.update(snapshot: schedule.snapshot) }
      }
      .onChange(of: checkIn.needsSessionCheck) { _, needed in
        guard needed else { return }
        Task { await workspace.confirmSessionAfterAuthFailure(appState: appState) }
      }
      .onChange(of: checkIn.webVPNAuthenticationUnavailable) { _, unavailable in
        if unavailable { appState.markWebVPNSessionUnavailable() }
      }
      .onChange(of: appState.webVPNSessionStatus) { _, status in
        Task { await workspace.handleWebVPNStatusChange(status, appState: appState) }
      }
      .onChange(of: checkIn.statusChangeRevision) { _, _ in
        workspace.announceStatusChange(appState: appState)
      }
      .onChange(of: schedule.reminderRevision) { _, _ in
        Task { await courseReminders.update(snapshot: schedule.snapshot) }
      }
      .onChange(of: courseReminders.isEnabled) { _, _ in
        Task { await courseReminders.update(snapshot: schedule.snapshot) }
      }
  }
}

extension View {
  func workspaceLifecycle(workspace: WorkspaceCoordinator, feature: WorkspaceFeature) -> some View {
    modifier(WorkspaceLifecycleModifier(workspace: workspace, feature: feature))
  }
}

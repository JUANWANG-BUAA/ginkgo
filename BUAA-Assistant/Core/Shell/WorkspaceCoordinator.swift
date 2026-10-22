import Foundation
import Network
import SwiftUI

/// 侧边栏/标签页对应的功能分区。macOS 与 iOS 共用同一套标识和图标，壳层只决定导航形式。
enum WorkspaceFeature: String, CaseIterable, Identifiable, Hashable {
  case today
  case checkIn
  case schedule
  case grade
  case graduateAcademic
  case homework
  case bykc
  case library
  case seminar
  case classroom
  case tasks
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .today: "今天"
    case .checkIn: "课程签到"
    case .schedule: "课表"
    case .grade: "成绩"
    case .graduateAcademic: "研究生教务"
    case .homework: "学校作业"
    case .bykc: "博雅"
    case .library: "图书馆"
    case .seminar: "研讨室"
    case .classroom: "空教室"
    case .tasks: "待办"
    case .settings: "设置"
    }
  }

  var systemImage: String {
    switch self {
    case .today: "sun.max.fill"
    case .checkIn: "checkmark.seal.fill"
    case .schedule: "calendar"
    case .grade: "chart.bar.fill"
    case .graduateAcademic: "building.columns.fill"
    case .homework: "doc.text.fill"
    case .bykc: "graduationcap.fill"
    case .library: "books.vertical.fill"
    case .seminar: "person.3.sequence.fill"
    case .classroom: "building.2"
    case .tasks: "checklist"
    case .settings: "gearshape.fill"
    }
  }
}

/// 两个应用壳共享的会话级状态：持有全部功能 ViewModel，并集中处理与界面结构无关的编排
/// （签到轮询、WebVPN 会话、课程提醒、回到前台/网络恢复后的刷新、写入失败后的会话复核）。
///
/// 各页面仍按需在自己的 `.task` 里 `start(account:)`，避免登录后一次性并发拉取所有模块；
/// 这里只负责跨模块的生命周期与节流。
@MainActor
final class WorkspaceCoordinator: ObservableObject {
  let schedule = ScheduleViewModel(repository: DefaultScheduleRepository())
  let exams = ExamViewModel(repository: DefaultExamRepository())
  let grades = GradeViewModel(repository: DefaultGradeRepository())
  let graduateAcademic = GraduateAcademicViewModel(repository: DefaultGraduateAcademicRepository())
  let homework = HomeworkViewModel(repository: DefaultHomeworkRepository())
  let bykc = BykcViewModel(repository: DefaultBykcRepository())
  let library = LibraryViewModel()
  let cgyy = CgyyViewModel()
  let campusNotices = CampusNoticesViewModel(repository: DefaultCampusNoticesRepository())
  let classroom = ClassroomViewModel(repository: DefaultClassroomRepository())
  let checkIn = CheckInViewModel(repository: DefaultCheckInRepository())
  let tasks = PersonalTaskStore()

  private(set) var isNetworkAvailable: Bool?
  private var monitor: NWPathMonitor?
  private var account: String?
  private var feature: WorkspaceFeature = .today
  private var isSceneActive = false
  private var pollingActive = false
  private var pollingTask: Task<Void, Never>?
  private var refreshTask: Task<Void, Never>?

  init(monitorsNetwork: Bool = true) {
    guard monitorsNetwork else { return }
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      let connected = path.status == .satisfied
      Task { @MainActor [weak self] in self?.updateConnectivity(connected) }
    }
    monitor.start(queue: DispatchQueue(label: "Ginkgo.workspace.network"))
    self.monitor = monitor
  }

  deinit {
    monitor?.cancel()
    pollingTask?.cancel()
    refreshTask?.cancel()
  }

  /// 登录态变化后调用：建立签到会话、同步课程提醒；注销时清理账号相关内存状态。
  func activateSession(
    account: String?,
    appState: AppState,
    reminders: CourseReminderScheduler
  ) async {
    self.account = account
    guard let account else {
      pollingTask?.cancel()
      pollingActive = false
      refreshTask?.cancel()
      await reminders.update(snapshot: nil)
      await checkIn.setWebVPNRouteEnabled(false)
      checkIn.reset()
      library.reset()
      return
    }
    await checkIn.setWebVPNRouteEnabled(appState.webVPNSessionStatus == .ready)
    await checkIn.start(account: account)
    await reminders.update(snapshot: schedule.snapshot)
    updatePolling()
  }

  /// 首次出现时只记录页面与前后台状态，不主动刷新（页面自己的 `.task` 负责首次加载）。
  func prepare(feature: WorkspaceFeature, sceneActive: Bool) {
    self.feature = feature
    isSceneActive = sceneActive
    updatePolling()
  }

  func select(feature: WorkspaceFeature) {
    guard self.feature != feature else { return }
    self.feature = feature
    updatePolling()
    cancelPendingAutomaticRefreshes()
    scheduleRefresh(force: false)
  }

  func setSceneActive(_ active: Bool) {
    guard isSceneActive != active else { return }
    isSceneActive = active
    updatePolling()
    if active {
      scheduleRefresh(force: false)
    } else {
      refreshTask?.cancel()
      cancelPendingAutomaticRefreshes()
    }
  }

  /// 业务系统报未登录时先向 UC 复核；确认失效才由 AppState 清理本地会话。
  func confirmSessionAfterAuthFailure(appState: AppState) async {
    if (try? await appState.confirmSessionAfterAuthFailure()) == true {
      await checkIn.refreshAfterSessionValidation()
    }
  }

  func handleWebVPNStatusChange(_ status: WebVPNSessionStatus, appState: AppState) async {
    await checkIn.setWebVPNRouteEnabled(status == .ready)
    if status == .ready {
      checkIn.clearWebVPNAuthenticationFailure()
      await checkIn.refresh()
    }
  }

  /// 只有回查确认“未签到 → 已签到”时才提示并发送通知。
  func announceStatusChange(appState: AppState) {
    guard checkIn.statusChangeRevision > 0, let message = checkIn.statusChangeMessage else { return }
    appState.showToast(message)
    checkIn.notifyStatusChange()
  }

  func cancelPendingAutomaticRefreshes() {
    schedule.cancelPendingAutomaticRefresh()
    exams.cancelPendingAutomaticRefresh()
    grades.cancelPendingAutomaticRefresh()
    homework.cancelPendingAutomaticRefresh()
  }

  private func refreshVisible(force: Bool) async {
    guard isSceneActive, isNetworkAvailable == true, account != nil else { return }
    switch feature {
    case .today:
      async let scheduleRefresh = schedule.refreshIfStale(
        currentWeek: true, queueIfLoading: force, forceRefresh: force
      )
      async let homeworkRefresh = homework.refreshIfStale(
        queueIfLoading: force, forceRefresh: force
      )
      _ = await (scheduleRefresh, homeworkRefresh)
    case .checkIn:
      await checkIn.refresh()
    case .schedule:
      async let scheduleRefresh = schedule.refreshIfStale(
        queueIfLoading: force, forceRefresh: force
      )
      async let examRefresh = exams.refreshIfStale(queueIfLoading: force, forceRefresh: force)
      _ = await (scheduleRefresh, examRefresh)
    case .grade:
      await grades.refreshIfStale(queueIfLoading: force, forceRefresh: force)
    case .homework:
      await homework.refreshIfStale(queueIfLoading: force, forceRefresh: force)
    case .library:
      await library.refreshIfStale()
    case .graduateAcademic, .bykc, .seminar, .classroom, .tasks, .settings:
      break
    }
  }

  private func updateConnectivity(_ connected: Bool) {
    let previous = isNetworkAvailable
    isNetworkAvailable = connected
    guard previous == false else {
      if !connected { cancelPendingAutomaticRefreshes() }
      return
    }
    guard connected else {
      refreshTask?.cancel()
      cancelPendingAutomaticRefreshes()
      return
    }
    scheduleRefresh(force: true)
  }

  private func scheduleRefresh(force: Bool) {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      guard !Task.isCancelled else { return }
      await self?.refreshVisible(force: force)
    }
  }

  /// 签到状态只在“今天/课程签到”页面且应用在前台时轮询；失败后放慢到 2 分钟。
  private func updatePolling() {
    let shouldPoll = isSceneActive && account != nil && (feature == .today || feature == .checkIn)
    guard shouldPoll != pollingActive else { return }
    pollingActive = shouldPoll
    pollingTask?.cancel()
    pollingTask = nil
    guard shouldPoll else { return }
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let delay: UInt64 = self.checkIn.errorMessage == nil ? 30 : 120
        do { try await Task.sleep(nanoseconds: delay * 1_000_000_000) } catch { return }
        guard !Task.isCancelled else { return }
        await self.checkIn.refresh()
      }
    }
  }
}

extension View {
  /// 注入工作区及其全部功能 ViewModel；两个应用壳共用同一套环境对象。
  func workspaceEnvironment(_ workspace: WorkspaceCoordinator) -> some View {
    environmentObject(workspace)
      .environmentObject(workspace.schedule)
      .environmentObject(workspace.exams)
      .environmentObject(workspace.grades)
      .environmentObject(workspace.graduateAcademic)
      .environmentObject(workspace.homework)
      .environmentObject(workspace.bykc)
      .environmentObject(workspace.library)
      .environmentObject(workspace.cgyy)
      .environmentObject(workspace.campusNotices)
      .environmentObject(workspace.classroom)
      .environmentObject(workspace.checkIn)
      .environmentObject(workspace.tasks)
  }
}

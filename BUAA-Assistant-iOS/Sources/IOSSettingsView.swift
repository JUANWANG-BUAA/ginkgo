import SwiftUI
import UIKit

struct IOSSettingsView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var grades: GradeViewModel
  @EnvironmentObject private var exams: ExamViewModel
  @EnvironmentObject private var classroom: ClassroomViewModel
  @EnvironmentObject private var homework: HomeworkViewModel
  @EnvironmentObject private var bykc: BykcViewModel
  @EnvironmentObject private var library: LibraryViewModel
  @EnvironmentObject private var campusNotices: CampusNoticesViewModel
  @EnvironmentObject private var checkIn: CheckInViewModel
  @EnvironmentObject private var courseReminders: CourseReminderScheduler
  @Environment(\.openURL) private var openURL
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @AppStorage("compactLists") private var compactLists = false
  @AppStorage(UpstreamRoutePreference.storageKey) private var upstreamRoute = UpstreamRoutePreference.automatic.rawValue
  @State private var isLoggingOut = false
  @State private var clearing = false
  @State private var showLogout = false
  @State private var showCacheClear = false

  var body: some View {
    Form {
      accountSection
      displaySection
      networkSection
      notificationSection
      dataSection
      privacySection
      aboutSection
      if let notice = appState.notice {
        Section {
          Label(notice, systemImage: "info.circle.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle("设置")
    .task {
      await checkIn.refreshNotificationAuthorization()
      await courseReminders.update(snapshot: schedule.snapshot)
    }
    .confirmationDialog("退出登录？", isPresented: $showLogout, titleVisibility: .visible) {
      Button("退出登录", role: .destructive) {
        isLoggingOut = true
        Task {
          await appState.logout()
          isLoggingOut = false
        }
      }
    } message: {
      Text("本机保存的登录凭据和学校会话会被清除；课表等查询缓存仍按账号隔离保存。")
    }
    .confirmationDialog("清除查询缓存？", isPresented: $showCacheClear, titleVisibility: .visible) {
      Button("清除缓存", role: .destructive) {
        clearQueryCache()
      }
    } message: {
      Text("下次查看课表、成绩、作业、图书馆、签到和空教室时需要重新查询。个人待办不会被删除。")
    }
  }

  private var accountSection: some View {
    Section {
      HStack(spacing: 14) {
        Image(systemName: "person.crop.circle.fill")
          .font(.system(size: 42))
          .foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 4) {
          Text(appState.user?.name ?? "校园账号")
            .font(.headline)
          Text(appState.user?.schoolid ?? "")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Label("已连接", systemImage: "checkmark.shield.fill")
          .font(.caption.weight(.medium))
          .foregroundStyle(.green)
      }
      .padding(.vertical, 4)
    } header: {
      Text("账号")
    }
  }

  private var displaySection: some View {
    Section {
      Picker("外观", selection: $appearance) {
        ForEach(AppAppearance.allCases) { item in
          Text(item.title).tag(item.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Toggle("紧凑列表", isOn: $compactLists)
    } header: {
      Text("显示与阅读")
    } footer: {
      Text("紧凑列表会减少成绩、空教室和待办的行间距；外观偏好保存在本机。")
    }
  }

  private var networkSection: some View {
    Section {
      Picker("校园服务路线", selection: $upstreamRoute) {
        ForEach(UpstreamRoutePreference.allCases) { route in
          Text(route.title).tag(route.rawValue)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: upstreamRoute) { _, _ in
        appState.applyUpstreamRouteChange()
      }

      Text(selectedUpstreamRoute.detail)
        .font(.footnote)
        .foregroundStyle(.secondary)

      if selectedUpstreamRoute == .webVPN {
        Label("请求经 d.buaa.edu.cn 网关", systemImage: "network.badge.shield.half.filled")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("网络连接")
    } footer: {
      Text("自动模式会先直连；检测到学校访问策略拦截后自动切换 WebVPN。切换路线会清除旧会话并要求重新登录。")
    }
  }

  private var selectedUpstreamRoute: UpstreamRoutePreference {
    UpstreamRoutePreference(rawValue: upstreamRoute) ?? .automatic
  }

  private var notificationSection: some View {
    Section {
      Toggle("课程前 10 分钟提醒", isOn: courseReminderBinding)
      LabeledContent("课程提醒状态", value: courseReminders.statusMessage)

      Toggle("签到状态变化提醒", isOn: checkInNotificationBinding)
      LabeledContent("系统通知权限", value: notificationAuthorizationTitle)

      if checkIn.notificationAuthorization == .notDetermined {
        Button("请求系统通知权限") {
          Task {
            let granted = await checkIn.requestNotificationAuthorization()
            appState.showToast(granted ? "系统通知权限已开启" : "系统通知权限未开启")
          }
        }
      } else if checkIn.notificationAuthorization == .denied {
        Button("打开系统通知设置") {
          openNotificationSettings()
        }
      }
    } header: {
      Text("通知与提醒")
    } footer: {
      Text("课程提醒只使用未来 14 天内已缓存且开课时间明确的课表；通知正文不显示课程名和地点。")
    }
  }

  private var dataSection: some View {
    Section {
      LabeledContent("课表、考试与成绩", value: "按账号本机缓存")
      LabeledContent("作业、签到与空教室", value: "按账号本机缓存")
      LabeledContent("图书馆", value: "每账号最多 2,000 个座位")
      LabeledContent("个人待办", value: "仅保存在本机")

      Button(role: .destructive) {
        showCacheClear = true
      } label: {
        HStack {
          Text("清除查询缓存")
          Spacer()
          if clearing { ProgressView().controlSize(.small) }
        }
      }
      .disabled(clearing)
    } header: {
      Text("数据与缓存")
    } footer: {
      Text("先展示已有数据，再按需从学校服务更新；清除缓存不会删除个人待办。")
    }
  }

  private var privacySection: some View {
    Section {
      LabeledContent("下次自动登录", value: appState.rememberedCredential == nil ? "未启用" : "已启用")
      Text("密码仅在登录时勾选“记住密码”后写入系统钥匙串。Cookie、查询结果和个人待办都留在本机。")
        .font(.caption)
        .foregroundStyle(.secondary)
      Button(role: .destructive) {
        showLogout = true
      } label: {
        HStack {
          Text("退出登录")
          Spacer()
          if isLoggingOut { ProgressView().controlSize(.small) }
        }
      }
      .disabled(isLoggingOut)
    } header: {
      Text("账号与隐私")
    } footer: {
      Text("应用直连北航校内系统，不经过第三方中转服务器。")
    }
  }

  private var aboutSection: some View {
    Section {
      LabeledContent("版本", value: appVersion)

      Link(destination: URL(string: "https://github.com/JUANWANG-BUAA/ginkgo") ?? fallbackURL) {
        Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
      }
      Link(destination: URL(string: "https://juanwang-buaa.github.io/ginkgo/") ?? fallbackURL) {
        Label("项目主页", systemImage: "safari")
      }
      Link(destination: URL(string: "https://github.com/BUAASubnet/UBAA") ?? fallbackURL) {
        Label("协议研究参考 UBAA", systemImage: "book.closed")
      }
    } header: {
      Text("关于")
    } footer: {
      Text("Ginkgo 以 MIT License 开源。课表、成绩和校园服务协议研究与实现参考了 UBAA，谨致谢意。\n\n北航校园工作台 · 校园日常，从容有序")
    }
  }

  private var courseReminderBinding: Binding<Bool> {
    Binding(
      get: { courseReminders.isEnabled },
      set: { setCourseRemindersEnabled($0) }
    )
  }

  private var checkInNotificationBinding: Binding<Bool> {
    Binding(
      get: { checkIn.notificationsEnabled },
      set: { setCheckInNotificationsEnabled($0) }
    )
  }

  private var notificationAuthorizationTitle: String {
    switch checkIn.notificationAuthorization {
    case .notDetermined: "尚未授权"
    case .denied: "已关闭"
    case .authorized: "已允许"
    case .provisional: "临时允许"
    case .ephemeral: "临时授权"
    @unknown default: "状态未知"
    }
  }

  private func setCourseRemindersEnabled(_ enabled: Bool) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
      courseReminders.setEnabled(enabled)
    }
    Task {
      if enabled, checkIn.notificationAuthorization == .notDetermined {
        let granted = await checkIn.requestNotificationAuthorization()
        appState.showToast(granted ? "课程提醒已开启" : "系统通知未授权，请到设置中开启")
      } else if enabled, checkIn.notificationAuthorization == .denied {
        appState.showToast("请先在系统设置中允许 Ginkgo 发送通知")
      }
      await courseReminders.update(snapshot: schedule.snapshot)
    }
  }

  private func setCheckInNotificationsEnabled(_ enabled: Bool) {
    checkIn.setNotificationsEnabled(enabled)
    guard enabled else { return }
    Task {
      if checkIn.notificationAuthorization == .notDetermined {
        let granted = await checkIn.requestNotificationAuthorization()
        appState.showToast(granted ? "签到状态提醒已开启" : "系统通知未授权，请到设置中开启")
      } else if checkIn.notificationAuthorization == .denied {
        appState.showToast("请先在系统设置中允许 Ginkgo 发送通知")
      }
    }
  }

  private func openNotificationSettings() {
    let value = UIApplication.openNotificationSettingsURLString
    guard let url = URL(string: value) else { return }
    openURL(url)
  }

  private func clearQueryCache() {
    guard let account = appState.user?.schoolid else { return }
    clearing = true
    Task {
      defer { clearing = false }
      do {
        try await schedule.clearCache(account: account)
        try await grades.clearCache(account: account)
        try await homework.clearCache(account: account)
        try await GraduateAcademicCache().clear(account: account)
        try await bykc.clearCache(account: account)
        try await exams.clearCache(account: account)
        try await library.clearCache(account: account)
        try await checkIn.clearCache(account: account)
        try await classroom.clearCache(account: account)
        try await campusNotices.clearCache()
        appState.showToast("查询缓存已清除，个人待办已保留")
      } catch {
        AppLog.cacheWriteFailed(feature: "settings-clear", error: error)
        appState.showToast("缓存清理失败，请稍后重试", isError: true)
      }
    }
  }

  private var appVersion: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }

  private var fallbackURL: URL {
    URL(fileURLWithPath: "/")
  }
}

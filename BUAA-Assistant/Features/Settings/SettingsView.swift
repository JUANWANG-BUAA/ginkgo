import SwiftUI
import UserNotifications

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var grades: GradeViewModel
  @EnvironmentObject private var exams: ExamViewModel
  @EnvironmentObject private var classroom: ClassroomViewModel
  @EnvironmentObject private var homework: HomeworkViewModel
  @EnvironmentObject private var library: LibraryViewModel
  @EnvironmentObject private var campusNotices: CampusNoticesViewModel
  @EnvironmentObject private var checkIn: CheckInViewModel
  @EnvironmentObject private var courseReminders: CourseReminderScheduler
  @EnvironmentObject private var updates: UpdateCenter
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @AppStorage("compactLists") private var compactLists = false
  @AppStorage(UpdateCenter.downloadSourceKey) private var updateDownloadSource = UpdateCenter.DownloadSource.automatic.rawValue
  @StateObject private var launchAtLogin = LaunchAtLoginController()
  @State private var isLoggingOut = false
  @State private var clearing = false
  @State private var showLogout = false
  @State private var showCache = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "PREFERENCES", title: "设置", subtitle: "让校园工作台更适合你的使用习惯")
        HStack(spacing: 18) {
          Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 48)).foregroundStyle(Color.accentColor)
          VStack(alignment: .leading, spacing: 6) {
            Text(appState.user?.name ?? "校园账号").font(.title2.weight(.semibold))
            Text(appState.user?.schoolid ?? "").font(.callout.monospaced()).foregroundStyle(.secondary)
          }
          Spacer()
          Label("已登录", systemImage: "checkmark.shield").font(.callout).foregroundStyle(.secondary)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

        settingsGroup("显示与阅读", symbol: "paintpalette", detail: "外观偏好自动保存在这台 Mac 上") {
          Picker("外观", selection: $appearance) {
            ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
          }.pickerStyle(.segmented)
          Divider().padding(.vertical, 8)
          Toggle(isOn: $compactLists) {
            VStack(alignment: .leading, spacing: 4) {
              Text("紧凑列表")
              Text("减少成绩、教室和待办的行间距，一屏查看更多内容").font(.caption).foregroundStyle(.secondary)
            }
          }.toggleStyle(.switch)
        }
        settingsGroup("启动", symbol: "power", detail: "按需在你登录 macOS 时自动打开校园工作台") {
          Toggle(isOn: Binding(
            get: { launchAtLogin.isRegistered },
            set: { launchAtLogin.setEnabled($0) }
          )) {
            VStack(alignment: .leading, spacing: 4) {
              Text("登录时自动启动")
              Text("由 macOS 管理此登录项；关闭开关会从系统登录项中注销。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .toggleStyle(.switch)

          LabeledContent("当前状态", value: launchAtLogin.statusDescription)
          if launchAtLogin.requiresApproval {
            StatusNotice(message: "已向 macOS 注册；请在系统设置的“登录项”中允许 Ginkgo。", kind: .warning)
            Button("打开登录项设置") { launchAtLogin.openLoginItemsSettings() }
              .buttonStyle(.link)
          }
          if let errorMessage = launchAtLogin.errorMessage {
            StatusNotice(message: errorMessage, kind: .warning)
          }
        }
        settingsGroup("通知与提醒", symbol: "bell.badge", detail: "课程前提醒与签到状态通知分别控制") {
          Toggle(isOn: Binding(
            get: { courseReminders.isEnabled },
            set: { setCourseRemindersEnabled($0) }
          )) {
            VStack(alignment: .leading, spacing: 4) {
              Text("课程前 10 分钟提醒")
              Text("使用未来 14 天内已缓存且有明确开课时间的周次；锁屏通知不显示课程名和地点。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .toggleStyle(.switch)

          Text(courseReminders.statusMessage)
            .font(.caption)
            .foregroundStyle(courseReminders.statusMessage.contains("未授权") ? Color.orange : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)

          Divider().padding(.vertical, 4)
          Toggle(isOn: Binding(
            get: { checkIn.notificationsEnabled },
            set: { setCheckInNotificationsEnabled($0) }
          )) {
            VStack(alignment: .leading, spacing: 4) {
              Text("课程签到状态变化提醒")
              Text("只在状态从未签到变为已签到并经回查确认后通知，不会因重复刷新连发。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .toggleStyle(.switch)

          notificationPermissionStatus
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: checkIn.notificationAuthorization)
        }
        settingsGroup("数据与缓存", symbol: "externaldrive", detail: "先展示已有数据，再按需从学校服务更新") {
          LabeledContent("课表、考试、成绩与作业", value: "本机缓存 · 按账号隔离")
          LabeledContent("图书馆", value: "本机缓存 · 每账号最多 2,000 个座位")
          LabeledContent("签到状态与历史", value: "本机缓存 · 按账号隔离 · 最多 180 天历史")
          LabeledContent("校园通知", value: "本机缓存 · 15 分钟更新")
          Divider().padding(.vertical, 8)
          LabeledContent("空教室", value: "本机缓存 · 5 分钟 · 最多 12 个查询")
          Text("空教室普通查询优先复用缓存；强制刷新会重新查询。可用情况以学校和现场安排为准。")
            .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
          Divider().padding(.vertical, 8)
          HStack {
            Text("清除查询缓存不会删除个人待办。").font(.callout).foregroundStyle(.secondary)
            Spacer()
            if clearing { ProgressView().controlSize(.small) }
            Button("清除缓存…") { showCache = true }.disabled(clearing)
          }
        }
        settingsGroup("账号与隐私", symbol: "lock.shield", detail: "直连校园服务，个人待办保存在本机") {
          LabeledContent("下次自动登录", value: appState.rememberedCredential == nil ? "未启用" : "已启用")
          Text("自动登录取决于登录页的“记住密码”选项；密码由系统钥匙串保存。退出登录会清除本机凭据和会话。")
            .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
          Divider().padding(.vertical, 8)
          HStack {
            Text("需要切换账号？").foregroundStyle(.secondary)
            Spacer()
            Button("退出登录…", role: .destructive) { showLogout = true }.disabled(isLoggingOut)
          }
        }
        settingsGroup("软件更新", symbol: "arrow.triangle.2.circlepath", detail: "从 GitHub Releases 检查并安装新版本，不影响本机缓存") {
          LabeledContent("当前版本", value: updates.currentVersionDescription)
          if let release = updates.latest {
            LabeledContent("最新版本", value: release.displayVersion)
            Text("更新只替换应用本身，课表、成绩、作业缓存与本机待办都会保留。")
              .font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            if let progress = updates.downloadProgress {
              ProgressView(value: progress) {
                Text("正在下载 \(release.displayVersion)… \(Int(progress * 100))%")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
            HStack(spacing: 12) {
              Button {
                Task { await updates.install() }
              } label: {
                Label(downloadButtonTitle, systemImage: "arrow.down.circle")
              }
              .buttonStyle(.borderedProminent)
              .disabled(updates.isBusy)
              Button("查看发布页") { updates.openReleasePage(release) }.buttonStyle(.link)
              Button("忽略此版本") { updates.ignoreCurrent() }.buttonStyle(.link)
            }
          }
          HStack(spacing: 12) {
            Button {
              Task { await updates.check(manual: true) }
            } label: {
              Label(updates.phase == .checking ? "正在检查…" : (updates.updateAvailable ? "重新检查" : "检查更新"),
                    systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(updates.isBusy)
            if let last = updates.lastCheckedAt {
              Text("上次检查：\(last.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          if let message = updates.statusMessage {
            StatusNotice(message: message, kind: updates.hasError ? .warning : .information)
          }
          Divider().padding(.vertical, 6)
          Picker("下载源", selection: $updateDownloadSource) {
            ForEach(UpdateCenter.DownloadSource.allCases, id: \.self) { source in
              Text(source.title).tag(source.rawValue)
            }
          }
          .pickerStyle(.menu)
          Text("国内直连 GitHub 下载可能很慢；默认会自动尝试镜像并回退到直连。")
            .font(.caption).foregroundStyle(.secondary)
        }
        settingsGroup("关于", symbol: "info.circle", detail: "版本、开源与致谢") {
          LabeledContent("版本", value: appVersion)
          LabeledContent("仓库") {
            Link("JUANWANG-BUAA/ginkgo", destination: URL(string: "https://github.com/JUANWANG-BUAA/ginkgo")!)
          }
          LabeledContent("项目主页") {
            Link("juanwang-buaa.github.io/ginkgo", destination: URL(string: "https://juanwang-buaa.github.io/ginkgo/")!)
          }
          Divider().padding(.vertical, 4)
          Text("如果 Ginkgo 帮到了你，欢迎在 GitHub 点个 Star。")
            .font(.caption).foregroundStyle(.secondary)
          Text("协议研究与实现参考了同以 MIT 许可发布的 UBAA（BUAASubnet/UBAA），谨致谢意。")
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Link("访问 UBAA", destination: URL(string: "https://github.com/BUAASubnet/UBAA")!)
            .font(.caption)
        }
        if let notice = appState.notice { StatusNotice(message: notice, kind: .information) }
        HStack {
          Label("Ginkgo（北航校园工作台）", systemImage: "graduationcap")
          Spacer()
          Text("校园日常，从容有序")
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
      }.padding(28).frame(maxWidth: 820).frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .task {
      await checkIn.refreshNotificationAuthorization()
      await courseReminders.update(snapshot: schedule.snapshot)
      launchAtLogin.refresh()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        launchAtLogin.refresh()
        Task {
          await checkIn.refreshNotificationAuthorization()
          await courseReminders.update(snapshot: schedule.snapshot)
        }
      }
    }
      .confirmationDialog("退出登录？", isPresented: $showLogout) {
        Button("退出登录", role: .destructive) {
          isLoggingOut = true
          Task { await appState.logout(); isLoggingOut = false }
        }
      } message: { Text("本机保存的登录凭据与会话会被清除。") }
      .confirmationDialog("清除查询缓存？", isPresented: $showCache) {
        Button("清除缓存", role: .destructive) { clearCache() }
      } message: { Text("下次查看时需要重新查询课表、考试、成绩、作业、图书馆、签到历史、校园通知和空教室。个人待办会保留。") }
  }

  private var downloadButtonTitle: String {
    if let progress = updates.downloadProgress {
      return "正在下载 \(Int(progress * 100))%…"
    }
    switch updates.phase {
    case .downloading: return "正在下载…"
    case .installing: return "正在安装…"
    default: return "下载并安装"
    }
  }

  private var appVersion: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }

  private func settingsGroup<Content: View>(_ title: String, symbol: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: symbol).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline)
          Text(detail).font(.caption).foregroundStyle(.secondary)
        }
      }
      Divider()
      VStack(alignment: .leading, spacing: 8, content: content)
    }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
  }

  @ViewBuilder
  private var notificationPermissionStatus: some View {
    switch checkIn.notificationAuthorization {
    case .notDetermined:
      HStack(alignment: .firstTextBaseline) {
        Label("系统尚未授权；开启任一提醒时会请求 macOS 通知权限。", systemImage: "bell")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer(minLength: 12)
        Button("请求系统通知权限") {
          Task {
            let granted = await checkIn.requestNotificationAuthorization()
            appState.showToast(granted ? "系统通知权限已开启" : "系统通知权限未开启；可稍后在系统设置中修改")
          }
        }
        .buttonStyle(.link)
      }
    case .denied:
      VStack(alignment: .leading, spacing: 8) {
        StatusNotice(message: "系统已拒绝通知权限。请到系统设置 → 通知 → Ginkgo 开启；应用内状态提示不受影响。", kind: .warning)
        Button("重新检查系统权限") {
          Task { await checkIn.refreshNotificationAuthorization() }
        }
        .buttonStyle(.link)
      }
    case .authorized, .provisional, .ephemeral:
      Label("系统通知已授权；课程提醒和签到提醒可分别关闭。", systemImage: "checkmark.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    @unknown default:
      Label("无法读取系统通知权限状态。", systemImage: "questionmark.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func setCheckInNotificationsEnabled(_ enabled: Bool) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
      checkIn.setNotificationsEnabled(enabled)
    }
    guard enabled else { return }

    switch checkIn.notificationAuthorization {
    case .notDetermined:
      Task {
        let granted = await checkIn.requestNotificationAuthorization()
        appState.showToast(
          granted
            ? "签到状态提醒已开启"
            : "系统通知未授权；可在系统设置 → 通知 → Ginkgo 中开启"
        )
      }
    case .denied:
      appState.showToast("请先在系统设置 → 通知 → Ginkgo 中开启通知")
    default:
      break
    }
  }

  private func setCourseRemindersEnabled(_ enabled: Bool) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
      courseReminders.setEnabled(enabled)
    }
    guard enabled else {
      Task { await courseReminders.update(snapshot: schedule.snapshot) }
      return
    }

    switch checkIn.notificationAuthorization {
    case .notDetermined:
      Task {
        let granted = await checkIn.requestNotificationAuthorization()
        await checkIn.refreshNotificationAuthorization()
        await courseReminders.update(snapshot: schedule.snapshot)
        appState.showToast(
          granted
            ? "课程提醒已开启"
            : "系统通知未授权；可在系统设置 → 通知 → Ginkgo 中开启"
        )
      }
    case .denied:
      appState.showToast("请先在系统设置 → 通知 → Ginkgo 中开启通知")
      Task { await courseReminders.update(snapshot: schedule.snapshot) }
    default:
      Task { await courseReminders.update(snapshot: schedule.snapshot) }
    }
  }

  private func clearCache() {
    guard let account = appState.user?.schoolid else { return }
    clearing = true
    Task {
      defer { clearing = false }
      do {
        try await ScheduleCache().clear(for: account)
        try await GradeCache().clear(account: account)
        try await HomeworkCache().clear(account: account)
        try await exams.clearCache(account: account)
        try await library.clearCache(account: account)
        try await checkIn.clearCache(account: account)
        try await classroom.clearCache(account: account)
        try await campusNotices.clearCache()
        schedule.reset(); grades.reset(); homework.reset()
        appState.showToast("查询缓存已清除")
      } catch {
        AppLog.network.error("缓存清理失败")
        appState.showToast("缓存清理失败，请稍后重试", isError: true)
      }
    }
  }
}

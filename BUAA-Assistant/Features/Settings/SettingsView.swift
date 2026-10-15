import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var grades: GradeViewModel
  @EnvironmentObject private var classroom: ClassroomViewModel
  @EnvironmentObject private var homework: HomeworkViewModel
  @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
  @AppStorage("compactLists") private var compactLists = false
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
        settingsGroup("数据与缓存", symbol: "externaldrive", detail: "先展示已有数据，再按需从学校服务更新") {
          LabeledContent("课表、成绩与作业", value: "本机缓存 · 按账号隔离")
          Divider().padding(.vertical, 8)
          LabeledContent("空教室", value: "内存缓存 · 5 分钟 · 最多 12 个查询")
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
        if let notice = appState.notice { StatusNotice(message: notice, kind: .information) }
        HStack {
          Label("BUAA Assistant", systemImage: "graduationcap")
          Spacer()
          Text("校园日常，从容有序")
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
      }.padding(28).frame(maxWidth: 820).frame(maxWidth: .infinity)
    }.background(Color(nsColor: .windowBackgroundColor))
      .confirmationDialog("退出登录？", isPresented: $showLogout) {
        Button("退出登录", role: .destructive) {
          isLoggingOut = true
          Task { await appState.logout(); isLoggingOut = false }
        }
      } message: { Text("本机保存的登录凭据与会话会被清除。") }
      .confirmationDialog("清除查询缓存？", isPresented: $showCache) {
        Button("清除缓存", role: .destructive) { clearCache() }
      } message: { Text("下次查看时需要重新查询课表、成绩和空教室。个人待办会保留。") }
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

  private func clearCache() {
    guard let account = appState.user?.schoolid else { return }
    clearing = true
    Task {
      defer { clearing = false }
      do {
        try await ScheduleCache().clear(for: account)
        try await GradeCache().clear(account: account)
        schedule.reset(); grades.reset(); classroom.clearCache(); homework.reset()
        appState.showToast("查询缓存已清除")
      } catch {
        AppLog.network.error("缓存清理失败")
        appState.showToast("缓存清理失败，请稍后重试", isError: true)
      }
    }
  }
}

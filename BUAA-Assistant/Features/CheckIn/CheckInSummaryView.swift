import SwiftUI

struct CheckInSummaryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: CheckInViewModel
  @EnvironmentObject private var schedule: ScheduleViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selectedCourse: CheckInItem?
  @State private var selectedSignInID: String?
  @State private var showsSignInConfirmation = false
  @State private var showsHistorySheet = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("课程签到", systemImage: "checkmark.seal")
          .font(.title3.weight(.semibold))
        Spacer()
        signedCount
        historyButton
        refreshButton
      }

      if let error = model.errorMessage {
        StatusNotice(
          message: model.snapshot.map { "签到状态刷新失败：\(error) · 保留上次成功结果（\($0.fetchedAt.formatted(date: .omitted, time: .shortened))）" } ?? "暂时无法确认签到状态：\(error)",
          kind: .warning
        )
      }
      if model.snapshotIsCached {
        Label("显示本机缓存状态；联网确认前不能提交签到", systemImage: "externaldrive")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if model.isLoading && model.snapshot == nil {
        ProgressView("正在查询 iclass 签到状态…")
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if let snapshot = model.snapshot, snapshot.items.isEmpty {
        Label("今天没有签到课程 · 已于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) 核对", systemImage: "calendar.badge.checkmark")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else if let snapshot = model.snapshot {
        ForEach(snapshot.items) { item in
          courseRow(item)
        }
        HStack(spacing: 6) {
          Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.circle")
          Text(model.snapshotIsCached
            ? "缓存于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) · 正在联网确认"
            : model.isLoading
              ? "正在检查状态变化…"
              : "最近核对 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) · 自动检查约每 30 秒")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.updatesFrequently)
      } else if model.snapshot == nil && model.errorMessage == nil {
        Label("签到状态尚未确认", systemImage: "questionmark.circle")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Text(model.notificationHint(webVPNSessionStatus: appState.webVPNSessionStatus))
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if appState.canRetryWebVPNSession,
         appState.webVPNSessionStatus == .unavailable || appState.webVPNSessionStatus == .preparing ||
         (appState.webVPNSessionStatus == .ready && model.iclassStatusRejected) {
        Button {
          Task { await appState.retryWebVPNSession() }
        } label: {
          if appState.webVPNSessionStatus == .preparing {
            Label("正在重建签到会话…", systemImage: "arrow.triangle.2.circlepath")
          } else if model.iclassStatusRejected {
            Label("重新建立签到会话", systemImage: "arrow.clockwise")
          } else {
            Label("重试连接签到服务", systemImage: "arrow.clockwise")
          }
        }
        .ginkgoLinkButtonStyle()
        .disabled(appState.webVPNSessionStatus == .preparing)
        .accessibilityHint("使用钥匙串中已保存的登录凭据重新建立临时 WebVPN 会话")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: appState.webVPNSessionStatus)
      }
      if model.notificationsEnabled && model.notificationAuthorization == .notDetermined {
        Button("开启系统签到通知") {
          Task {
            let enabled = await model.requestNotificationAuthorization()
            appState.showToast(
              enabled
                ? "签到状态通知已开启"
                : "系统通知未授权；可在系统设置 → 通知 → Ginkgo 中开启"
            )
          }
        }
        .ginkgoLinkButtonStyle()
      }
      if let actionMessage = model.actionMessage {
        StatusNotice(message: actionMessage, kind: model.actionSucceeded ? .success : .warning)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
    .task { await model.refreshNotificationAuthorization() }
    .sheet(isPresented: $showsHistorySheet) {
      CheckInHistorySheet()
        .environmentObject(model)
        .ginkgoSheetSizing(minWidth: 600, minHeight: 500)
    }
    .confirmationDialog("确认课程签到", isPresented: $showsSignInConfirmation, titleVisibility: .visible) {
      Button("确认签到") {
        guard let selectedCourse else { return }
        let target = selectedSignInID ?? selectedCourse.id
        selectedSignInID = nil
        Task { await model.performSignIn(courseID: target) }
      }
      Button("取消", role: .cancel) {
        selectedSignInID = nil
        selectedCourse = nil
      }
    } message: {
      if let selectedCourse {
        Text("将为“\(selectedCourse.courseName)”提交签到，并在提交后立即回查状态。只有学校确认后才显示成功。")
      }
    }
  }

  @ViewBuilder
  private var signedCount: some View {
    if let snapshot = model.snapshot, snapshot.items.isEmpty == false {
      Text("\(snapshot.items.filter { $0.status == .signed }.count)/\(snapshot.items.count) 已确认签到")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: snapshot.items.filter { $0.status == .signed }.count)
    }
  }

  private var historyButton: some View {
    Button {
      showsHistorySheet = true
    } label: {
      Label("历史查询", systemImage: "calendar.badge.clock")
    }
    .buttonStyle(.borderless)
  }

  private var refreshButton: some View {
    Button {
      Task { await model.refresh() }
    } label: {
      if model.isLoading {
        ProgressView().controlSize(.small)
      } else {
        Image(systemName: "arrow.clockwise")
      }
    }
    .buttonStyle(.borderless)
    .disabled(model.isLoading)
    .help("立即刷新签到状态")
    .accessibilityLabel(model.isLoading ? "正在核对签到状态" : "立即刷新签到状态")
  }

  private func courseRow(_ item: CheckInItem) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.status.symbol)
        .foregroundStyle(item.status.tint)
        .frame(width: 18)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.courseName).font(.body.weight(.medium))
        Text("\(item.beginsAt)–\(item.endsAt)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        if let target = CheckInTargetMatcher.matchedTargetLabel(for: item, schedule: schedule.snapshot) {
          Text("签到目标：\(target)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .combine)
      Spacer()
      statusBadge(for: item)
      courseAction(for: item)
      if item.mergedRecordCount > 1 {
        mergedRecordLabel(item)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .contain)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: item.status)
  }

  private func statusBadge(for item: CheckInItem) -> some View {
    Text(item.status.title)
      .font(.caption.weight(.medium))
      .foregroundStyle(item.status.tint)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(item.status.tint.opacity(0.10), in: Capsule())
  }

  private func mergedRecordLabel(_ item: CheckInItem) -> some View {
    Label("\(item.mergedRecordCount) 条同名教学班记录", systemImage: "arrow.triangle.merge")
      .font(.caption2)
      .foregroundStyle(.secondary)
      .help("iclass 返回了同一课程、同一时间的多个教学班（教室/教师/课程 ID 不同）。签到时会按你的课表教室/教师匹配，匹配不到时可手动选择。")
      .accessibilityLabel("已合并 \(item.mergedRecordCount) 条同名教学班记录")
  }

  @ViewBuilder
  private func courseAction(for item: CheckInItem) -> some View {
    let candidates = CheckInTargetMatcher.signInCandidates(for: item, schedule: schedule.snapshot)
    let canChoose = item.status == .notSigned || item.status == .unknown
    if canChoose && candidates.isEmpty && model.canSubmitSignIn == false {
      Label("联网确认后可签到", systemImage: "clock.arrow.circlepath")
        .font(.caption)
        .foregroundStyle(.secondary)
    } else if canChoose && candidates.count == 1, let candidate = candidates.first {
      let isSubmitting = model.isSigningInCourseID == candidate.id
      Button {
        selectedCourse = item
        selectedSignInID = candidate.id
        showsSignInConfirmation = true
      } label: {
        if isSubmitting {
          ProgressView().controlSize(.small)
        } else {
          Text("签到")
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(model.isSigningInCourseID != nil)
      .accessibilityLabel(isSubmitting ? "正在提交签到：\(item.courseName)" : "签到：\(item.courseName)")
      .accessibilityHint(isSubmitting ? "正在等待学校确认签到结果" : "提交前会再次询问确认")
    } else if canChoose && candidates.isEmpty == false {
      Menu {
        ForEach(candidates) { candidate in
          Button(candidate.menuLabel) {
            selectedCourse = item
            selectedSignInID = candidate.id
            showsSignInConfirmation = true
          }
        }
      } label: {
        Text("选择签到记录")
      }
      .menuStyle(.borderlessButton)
      .controlSize(.small)
      .disabled(model.isSigningInCourseID != nil)
      .help("同名记录包含不同教室/教师；请选择你实际所在的课堂。")
    } else if canChoose {
      Label("签到目标待核实", systemImage: "exclamationmark.triangle")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .help("上游没有返回可签到的课程记录。")
    }
  }



}

private struct CheckInHistorySheet: View {
  @EnvironmentObject private var model: CheckInViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var selectedDate = Self.defaultDate

  private static var defaultDate: Date {
    SchoolTime.calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        PageHeading(
          eyebrow: "CAMPUS / ATTENDANCE",
          title: "历史日期查询",
          subtitle: "按日期读取 iclass 课程与签到状态；未签到状态不会自动判为缺勤。"
        )
        Button {
          dismiss()
        } label: {
          Label("关闭", systemImage: "xmark")
        }
        .buttonStyle(.borderless)
        .help("关闭历史查询")
        .accessibilityLabel("关闭历史查询")
        .keyboardShortcut(.cancelAction)
      }
      HStack(spacing: 14) {
        dateNavigationControls
        historyQueryButton
      }

      if let error = model.historyErrorMessage {
        StatusNotice(message: "历史日期查询失败：\(error)", kind: .warning)
      }
      if model.historyIsLoading {
        ProgressView("正在读取 iclass 日期记录…")
      }
      if let snapshot = model.historySnapshot {
        if model.historyIsCached {
          Label("显示本机缓存，正在确认学校记录", systemImage: "externaldrive")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text("\(snapshot.schoolDate) · \(snapshot.items.count) 门签到课程")
          .font(.callout.weight(.medium))
        if snapshot.items.isEmpty {
          PageEmptyState(
            symbol: "calendar.badge.checkmark",
            title: "上游未返回这一天的签到课程",
            detail: "这只表示该日期没有可查询课程，不代表出勤或缺勤。"
          )
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
              ForEach(snapshot.items) { item in
                HStack(alignment: .top, spacing: 12) {
                  Image(systemName: historySymbol(for: item.status))
                    .foregroundStyle(historyTint(for: item.status))
                    .frame(width: 18)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(item.courseName).font(.body.weight(.medium))
                    Text("\(item.beginsAt)–\(item.endsAt)")
                      .font(.caption.monospacedDigit())
                      .foregroundStyle(.secondary)
                    if item.mergedRecordCount > 1 {
                      Label("\(item.mergedRecordCount) 条同名教学班记录", systemImage: "arrow.triangle.merge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                  }
                  Spacer()
                  Text(historyTitle(for: item.status))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(historyTint(for: item.status))
                }
                .padding(.vertical, 7)
              }
            }
          }
          .frame(maxHeight: 300)
        }
      } else if !model.historyIsLoading {
        Text("选择一个已经过去的日期，按需查询。")
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      Text("当前仅验证了 iclass 的日期查询入口。课程级“未签到”不是学校正式缺勤结论；整学期记录完整性仍需确认。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .ginkgoOnExitCommand { dismiss() }
  }

  private var dateNavigationControls: some View {
    HStack(spacing: 14) {
      Button {
        shiftDate(by: -1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(.bordered)
      .help("前一天")
      .accessibilityLabel("选择前一天")

      DatePicker("日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
        .datePickerStyle(.compact)
        .labelsHidden()

      Button {
        shiftDate(by: 1)
      } label: {
        Image(systemName: "chevron.right")
      }
      .buttonStyle(.bordered)
      .help("后一天")
      .accessibilityLabel("选择后一天")
      .disabled(isTodaySelected)
    }
  }

  private var historyQueryButton: some View {
    Button {
      Task { await model.loadHistory(on: selectedDate) }
    } label: {
      if model.historyIsLoading {
        ProgressView().controlSize(.small)
      } else {
        Label("查询这一天", systemImage: "magnifyingglass")
      }
    }
    .buttonStyle(.borderedProminent)
    .disabled(model.historyIsLoading)
  }

  private var isTodaySelected: Bool {
    SchoolTime.calendar.startOfDay(for: selectedDate) >= SchoolTime.calendar.startOfDay(for: Date())
  }

  private func shiftDate(by days: Int) {
    guard let date = SchoolTime.calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
    selectedDate = min(date, Date())
  }

  private func historyTitle(for status: CheckInStatus) -> String {
    switch status {
    case .notSigned: "未签到 · 待核对"
    case .signed: "已签到"
    case .unknown: "状态待确认"
    }
  }

  private func historySymbol(for status: CheckInStatus) -> String {
    switch status {
    case .notSigned: "questionmark.circle"
    case .signed: "checkmark.circle.fill"
    case .unknown: "exclamationmark.circle"
    }
  }

  private func historyTint(for status: CheckInStatus) -> Color {
    switch status {
    case .notSigned: .orange
    case .signed: .green
    case .unknown: .secondary
    }
  }
}

struct CheckInPage: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: CheckInViewModel
  @EnvironmentObject private var schedule: ScheduleViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(
          eyebrow: "CAMPUS / ATTENDANCE",
          title: "课程签到",
          subtitle: "查看课程签到状态；每次提交都需要你亲自确认，提交后会立即回查结果。"
        )
        CheckInSummaryView()
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 820, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.refreshOnAppearance(account: account)
    }
  }
}

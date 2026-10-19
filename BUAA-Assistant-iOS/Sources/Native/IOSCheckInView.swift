import SwiftUI

struct IOSCheckInView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: CheckInViewModel
  @State private var selectedCourse: CheckInItem?
  @State private var showsConfirmation = false

  var body: some View {
    List {
      Section {
        if let snapshot = model.snapshot {
          let signed = snapshot.items.filter { $0.status == .signed }.count
          LabeledContent("已确认签到", value: "\(signed) / \(snapshot.items.count)")
          LabeledContent("最近核对", value: snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))
          if model.snapshotIsCached {
            IOSInlineMessage("当前显示本机缓存，联网确认前不能提交签到。", systemImage: "externaldrive", tint: .orange)
          }
        } else {
          Label("签到状态尚未确认", systemImage: "questionmark.circle")
            .foregroundStyle(.secondary)
        }

        if let error = model.errorMessage {
          IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }

        switch appState.webVPNSessionStatus {
        case .ready:
          Label("签到专用 WebVPN 会话已就绪", systemImage: "checkmark.shield.fill")
            .foregroundStyle(.green)
        case .preparing:
          HStack(spacing: 10) {
            ProgressView()
            Text("正在建立签到专用会话…")
          }
        case .requiresCaptcha:
          IOSInlineMessage("WebVPN 登录需要验证码，请在重新登录后重试。", systemImage: "person.badge.key", tint: .orange)
        case .unavailable:
          IOSInlineMessage("签到专用会话暂不可用。", systemImage: "wifi.exclamationmark", tint: .orange)
          if appState.canRetryWebVPNSession {
            Button("重试连接签到服务") {
              Task { await appState.retryWebVPNSession() }
            }
          }
        case .notAttempted:
          Label("登录后会建立签到专用会话", systemImage: "lock.shield")
            .foregroundStyle(.secondary)
        }

        NavigationLink {
          IOSCheckInHistoryView()
        } label: {
          Label("查询历史签到", systemImage: "calendar.badge.clock")
        }
      } header: {
        Text("签到状态")
      } footer: {
        Text(model.notificationHint(webVPNSessionStatus: appState.webVPNSessionStatus))
      }

      if model.isLoading && model.snapshot == nil {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取 iclass 签到状态…")
          }
        }
      } else if let snapshot = model.snapshot, snapshot.items.isEmpty {
        Section {
          ContentUnavailableView(
            "今天没有签到课程",
            systemImage: "calendar.badge.checkmark",
            description: Text("学校已返回当前日期的空课程列表。")
          )
        }
      } else if let snapshot = model.snapshot {
        Section("今日课程") {
          ForEach(snapshot.items) { item in
            courseRow(item)
          }
        }
      } else {
        Section {
          ContentUnavailableView(
            "签到状态尚未确认",
            systemImage: "questionmark.circle",
            description: Text("联网后下拉刷新。")
          )
        }
      }

      if let message = model.actionMessage {
        Section {
          IOSInlineMessage(
            message,
            systemImage: model.actionSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            tint: model.actionSucceeded ? .green : .orange
          )
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("课程签到")
    .refreshable { await model.refresh() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await model.refresh() }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新签到状态")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
    }
    .confirmationDialog("确认课程签到", isPresented: $showsConfirmation, titleVisibility: .visible) {
      Button("确认签到") {
        guard let course = selectedCourse else { return }
        selectedCourse = nil
        Task { await model.performSignIn(courseID: course.id) }
      }
      Button("取消", role: .cancel) { selectedCourse = nil }
    } message: {
      if let course = selectedCourse {
        Text("将为“\(course.courseName)”提交签到，并在提交后立即回查状态。只有学校确认后才显示成功。")
      }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
    .onChange(of: model.webVPNAuthenticationUnavailable) { _, unavailable in
      if unavailable { appState.markWebVPNSessionUnavailable() }
    }
  }

  private func courseRow(_ item: CheckInItem) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: item.status.symbol)
          .foregroundStyle(item.status.tint)
          .padding(.top, 2)
        VStack(alignment: .leading, spacing: 3) {
          Text(item.courseName)
            .font(.body.weight(.medium))
          Text("\(item.beginsAt)–\(item.endsAt)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          if item.mergedRecordCount > 1 {
            Text("已合并 \(item.mergedRecordCount) 条重复记录")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 6)
        Text(item.status.title)
          .font(.caption.weight(.medium))
          .foregroundStyle(item.status.tint)
      }

      if item.status == .notSigned && item.signInAllowed {
        if model.canSubmitSignIn {
          Button {
            selectedCourse = item
            showsConfirmation = true
          } label: {
            if model.isSigningInCourseID == item.id {
              ProgressView().controlSize(.small)
            } else {
              Label("签到", systemImage: "checkmark.seal")
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .disabled(model.isSigningInCourseID != nil)
          .accessibilityLabel("签到：\(item.courseName)")
          .accessibilityHint("提交前会再次询问确认")
        } else {
          Label("联网确认后可签到", systemImage: "clock.arrow.circlepath")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else if item.status == .notSigned {
        Label("签到目标待核实", systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 3)
  }
}

private struct IOSCheckInHistoryView: View {
  @EnvironmentObject private var model: CheckInViewModel
  @State private var date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

  var body: some View {
    List {
      Section {
        DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
        Button {
          Task { await model.loadHistory(on: date) }
        } label: {
          if model.historyIsLoading {
            HStack(spacing: 8) {
              ProgressView().controlSize(.small)
              Text("正在查询…")
            }
          } else {
            Label("查询这一天", systemImage: "magnifyingglass")
          }
        }
        .disabled(model.historyIsLoading)
      } header: {
        Text("选择日期")
      } footer: {
        Text("未签到状态不会自动判为缺勤；以学校记录为准。")
      }

      if let error = model.historyErrorMessage {
        Section {
          IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
      }

      if model.historyIsLoading && model.historySnapshot == nil {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取历史签到…")
          }
        }
      } else if let snapshot = model.historySnapshot {
        Section {
          if snapshot.items.isEmpty {
            ContentUnavailableView(
              "这一天没有签到课程",
              systemImage: "calendar.badge.checkmark",
              description: Text("学校未返回这一天的可查询课程。")
            )
          } else {
            ForEach(snapshot.items) { item in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.status.symbol)
                  .foregroundStyle(item.status.tint)
                  .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.courseName)
                  Text("\(item.beginsAt)–\(item.endsAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                Text(item.status.title)
                  .font(.caption)
                  .foregroundStyle(item.status.tint)
              }
            }
          }
        } header: {
          Text(snapshot.schoolDate)
        } footer: {
          if model.historyIsCached {
            Text("当前显示本机缓存，正在向学校确认。")
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("历史签到")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if model.historySnapshot == nil {
        await model.loadHistory(on: date)
      }
    }
  }
}

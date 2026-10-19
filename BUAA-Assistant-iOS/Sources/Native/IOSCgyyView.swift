import SwiftUI

struct IOSCgyyView: View {
  @EnvironmentObject private var model: CgyyViewModel
  @EnvironmentObject private var appState: AppState
  @State private var tab = 0
  @State private var pendingCancellation: CgyyOrder?
  @State private var showSubmitConfirmation = false

  var body: some View {
    List {
      Section {
        Picker("页面", selection: $tab) {
          Text("预约").tag(0)
          Text("我的预约").tag(1)
          Text("门锁密码").tag(2)
        }
        .pickerStyle(.segmented)
      }
      if let message = model.message {
        Section { Label(message, systemImage: "checkmark.circle").foregroundStyle(.green) }
      }
      if let error = model.errorMessage {
        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
      }
      if tab == 0 {
        bookingSections.disabled(model.isSubmitting)
      } else if tab == 1 {
        orderSections
        if model.requiresOrderReview {
          Section {
            Button("已核对订单，继续预约") { Task { await model.acknowledgeOrderReview() } }
          }
        }
      } else {
        lockCodeSections
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("研讨室")
    .refreshable {
      guard let account = appState.user?.schoolid else { return }
      await model.refreshAll(account: account)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          guard let account = appState.user?.schoolid else { return }
          Task { await model.refreshAll(account: account) }
        } label: {
          if model.isLoading || model.isLoadingOrders || model.isLoadingLockCode {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading || model.isLoadingOrders || model.isLoadingLockCode)
        .accessibilityLabel("刷新研讨室")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account, credential: appState.rememberedCredential)
      await model.refreshIfStale(account: account)
    }
    .alert("确认提交研讨室预约？", isPresented: $showSubmitConfirmation) {
      Button("确认提交") { Task { await model.submitBooking() } }
      Button("取消", role: .cancel) {}
    } message: {
      Text(submitSummary)
    }
    .alert("取消这条预约？", isPresented: cancellationPresented) {
      Button("确认取消", role: .destructive) {
        guard let order = pendingCancellation else { return }
        pendingCancellation = nil
        Task { await model.cancel(order) }
      }
      Button("保留预约", role: .cancel) { pendingCancellation = nil }
    } message: {
      Text(pendingCancellation?.displayTitle ?? "")
    }
  }

  @ViewBuilder
  private var bookingSections: some View {
    Section("场地与日期") {
      Picker("场地", selection: Binding(
        get: { model.selectedSiteID },
        set: { value in Task { await model.selectSite(value) } }
      )) {
        ForEach(model.venues) { site in
          Text(site.displayName).tag(site.id)
        }
      }
      Picker("日期", selection: Binding(
        get: { model.selectedDate },
        set: { value in Task { await model.selectDate(value) } }
      )) {
        ForEach(availableDates, id: \.self) { date in
          Text(date).tag(date)
        }
      }
      .disabled(availableDates.isEmpty)
      if let site = model.selectedSite, let spaces = site.reservationSpaceCount {
        LabeledContent("可预约空间", value: "\(spaces) 个")
      }
    }

    if model.isLoading && model.dayInfo == nil {
      Section { HStack { ProgressView(); Text("正在读取时段…") } }
    } else if let dayInfo = model.dayInfo {
      Section {
        if dayInfo.spaces.isEmpty {
          ContentUnavailableView("当天暂无可预约空间", systemImage: "door.left.hand.open", description: Text("请切换日期或场地。"))
        } else {
          ForEach(Array(dayInfo.spaces.enumerated()), id: \.offset) { _, space in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(space.name).font(.callout.weight(.medium))
                Spacer()
                Text("\(space.reservableSlots.count) 段可约")
                  .font(.caption2)
                  .foregroundStyle(space.reservableSlots.isEmpty ? Color.secondary : Color.green)
              }
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(dayInfo.timeSlots) { time in
                  let slot = space.slots.first { $0.timeID == time.id }
                  let selected = model.selectedSpaceID == space.id && model.selectedTimeIDs.contains(time.id)
                  Button {
                    model.selectSpace(space.id)
                    model.toggle(timeID: time.id)
                  } label: {
                    VStack(spacing: 1) {
                      Text("\(time.beginTime)–\(time.endTime)").font(.caption2.monospacedDigit())
                      Text(selected ? "已选" : (slot?.statusText ?? "待确认"))
                        .font(.system(size: 9))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.clear))
                  }
                  .buttonStyle(.plain)
                  .disabled(slot?.isReservable != true)
                }
              }
            }
            .padding(.vertical, 3)
          }
        }
      } header: {
        Text("选择空间与时段")
      } footer: {
        Text("同一次预约只能选择一个空间；可多选该空间时段。")
      }
    }

    if model.dayInfo == nil, model.venues.isEmpty == false {
      Section {
        ContentUnavailableView(
          model.loginRequired ? "场馆已加载，查看时段需要登录" : "暂时无法读取时段",
          systemImage: "person.badge.key",
          description: Text(model.loginRequired
            ? "场馆列表来自公开接口；可预约时段、我的预约和门锁密码需要学校 SSO。请重新登录后重试。"
            : (model.errorMessage ?? "请刷新后重试。"))
        )
        Button("重试登录/读取") { Task { await model.loadDayInfo() } }
      }
    }

    Section("预约信息") {
      TextField("手机号（11 位）", text: $model.phone)
        .keyboardType(.numberPad)
      TextField("活动主题", text: $model.theme)
      Picker("活动类型", selection: $model.purposeTypeID) {
        ForEach(model.purposeTypes) { type in
          Text(type.name).tag(type.id)
        }
      }
      Stepper("参与人数：\(model.joinerNum) 人", value: $model.joinerNum, in: 1...100)
      TextField("活动内容", text: $model.content, axis: .vertical)
        .lineLimit(2...4)
      TextField("参与人说明", text: $model.joiners)
      Toggle("哲学社会科学类", isOn: $model.philosophy)
      Toggle("含校外参与人", isOn: $model.offSchool)
      Button {
        showSubmitConfirmation = true
      } label: {
        if model.isSubmitting {
          HStack { ProgressView().controlSize(.small); Text("正在自动验证并提交…") }
        } else {
          Label("提交预约", systemImage: "paperplane.fill")
        }
      }
      .disabled(model.canSubmit == false || model.isSubmitting)
    }
  }

  @ViewBuilder
  private var orderSections: some View {
    Section("我的研讨室预约") {
      if model.orders.isEmpty {
        if model.isLoadingOrders {
          HStack { ProgressView(); Text("正在读取预约…") }
        } else {
          ContentUnavailableView("暂无研讨室预约", systemImage: "ticket", description: Text("提交预约后会显示审批状态。"))
        }
      } else {
        ForEach(model.orders) { order in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(order.displayTitle).font(.callout.weight(.medium))
              Spacer()
              Text(order.displayStatus.title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(order.statusTint.opacity(0.12), in: Capsule())
                .foregroundStyle(order.statusTint)
            }
            if order.displayLocation.isEmpty == false {
              Text(order.displayLocation).font(.caption).foregroundStyle(.secondary)
            }
            Text(order.displayTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack {
              Button("查看门锁密码") {
                tab = 2
                Task { await model.loadLockCode() }
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              if order.canCancel() {
                Button("取消预约", role: .destructive) { pendingCancellation = order }
                  .buttonStyle(.bordered)
                  .controlSize(.small)
                  .disabled(model.cancellingOrderID != nil || model.requiresOrderReview || model.isSubmitting)
              }
            }
          }
          .padding(.vertical, 3)
        }
      }
    }
  }

  @ViewBuilder
  private var lockCodeSections: some View {
    Section("门锁密码") {
      if let lock = model.lockCode {
        if lock.hasLockCode, let code = lock.qrCode {
          Text(code)
            .font(.system(.title2, design: .monospaced).weight(.semibold))
            .textSelection(.enabled)
          if let due = lock.dueDate {
            LabeledContent("有效至", value: due)
          }
        } else if lock.hasUpcomingReservation {
          Text("预约已存在，但当前不在可开门时段，密码尚未返回。")
            .foregroundStyle(.secondary)
        } else {
          ContentUnavailableView("暂无门锁密码", systemImage: "lock", description: Text("预约审批通过且进入可开门时段后显示。"))
        }
        if lock.displayLocation.isEmpty == false {
          LabeledContent("场地", value: lock.displayLocation)
        }
        if let space = lock.spaceName, space.isEmpty == false {
          LabeledContent("空间", value: space)
        }
        if lock.displayTime.isEmpty == false {
          LabeledContent("时间", value: lock.displayTime)
        }
        Text("门锁密码来自学校接口，仅用于当前预约；请勿转发或截图分享。")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else if model.isLoadingLockCode {
        HStack { ProgressView(); Text("正在读取门锁密码…") }
      } else {
        Button("读取门锁密码") { Task { await model.loadLockCode() } }
      }
    }
  }

  private var availableDates: [String] {
    if let dates = model.dayInfo?.availableDates, dates.isEmpty == false { return dates }
    return [model.selectedDate]
  }

  private var cancellationPresented: Binding<Bool> {
    Binding(get: { pendingCancellation != nil }, set: { if !$0 { pendingCancellation = nil } })
  }

  private var submitSummary: String {
    [
      model.selectedSite?.displayName,
      model.selectedSpace?.name,
      model.selectedSlots.first.map { "\($0.beginTime)–\(model.selectedSlots.last?.endTime ?? $0.endTime)" },
      "主题：\(model.theme)",
      model.selectedDate,
      "手机号：\(model.phone)"
    ].compactMap { $0 }.joined(separator: "\n")
  }

}

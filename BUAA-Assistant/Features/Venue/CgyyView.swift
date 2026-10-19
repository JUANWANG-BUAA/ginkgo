#if os(macOS)

import SwiftUI

private enum CgyySection: String, CaseIterable, Identifiable {
  case booking = "预约"
  case orders = "我的预约"
  case lockCode = "门锁密码"

  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .booking: "calendar.badge.plus"
    case .orders: "list.bullet.rectangle"
    case .lockCode: "lock.open"
    }
  }
}

/// 教学楼研讨室（cgyy.buaa.edu.cn）预约页。
/// 验证码在用户确认提交后自动识别；写操作不自动重试。
struct CgyyView: View {
  @EnvironmentObject private var model: CgyyViewModel
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var section: CgyySection = .booking
  @State private var pendingCancellation: CgyyOrder?
  @State private var showSubmitConfirmation = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(
          eyebrow: "CAMPUS / TEACHING BUILDING",
          title: "研讨室",
          subtitle: "教学楼场地预约（cgyy）：选场地与时段、提交预约、查看审批和门锁密码"
        )
        Picker("页面", selection: $section) {
          ForEach(CgyySection.allCases) { item in
            Label(item.rawValue, systemImage: item.symbol).tag(item)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)

        if let message = model.message {
          StatusNotice(message: message, kind: .success)
        }
        if let error = model.errorMessage {
          StatusNotice(message: error, kind: .warning)
        }

        switch section {
        case .booking:
          bookingContent.disabled(model.isSubmitting)
        case .orders:
          ordersContent
          if model.requiresOrderReview {
            Button("已核对订单，继续预约") { Task { await model.acknowledgeOrderReview() } }
              .buttonStyle(.bordered)
          }
        case .lockCode:
          lockCodeContent
        }
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 1100, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: section)
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
    .alert("取消这条预约？", isPresented: Binding(
      get: { pendingCancellation != nil },
      set: { if !$0 { pendingCancellation = nil } }
    )) {
      Button("确认取消", role: .destructive) {
        if let order = pendingCancellation { Task { await model.cancel(order) } }
        pendingCancellation = nil
      }
      Button("保留预约", role: .cancel) { pendingCancellation = nil }
    } message: {
      Text(pendingCancellation?.displayTitle ?? "")
    }
  }

  // MARK: - 预约

  @ViewBuilder
  private var bookingContent: some View {
    venueCard
    if model.isLoading && model.dayInfo == nil {
      HStack(spacing: 10) {
        ProgressView()
        Text("正在读取研讨室时段…").foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .cgyyCard()
    } else if let dayInfo = model.dayInfo {
      roomSection(dayInfo)
      if dayInfo.spaces.isEmpty == false {
        formCard
      }
    } else if model.venues.isEmpty == false {
      PageEmptyState(
        symbol: "person.badge.key",
        title: model.loginRequired ? "场馆已加载，查看时段需要登录" : "暂时无法读取时段",
        detail: model.errorMessage
          ?? "场馆列表来自公开接口；可预约时段、我的预约和门锁密码需要学校 SSO。请重新登录学校账号后点“重试”。"
      )
      Button("重试登录/读取") { Task { await model.loadDayInfo() } }
        .buttonStyle(.borderedProminent)
    } else {
      PageEmptyState(
        symbol: "building.2",
        title: "暂时无法读取研讨室",
        detail: model.errorMessage ?? "请刷新后重试。"
      )
      Button("重试") { Task { await model.loadDayInfo() } }
        .buttonStyle(.borderedProminent)
    }
  }

  private var venueCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("场地与日期", systemImage: "mappin.and.ellipse")
          .font(.headline)
        Spacer()
        Button {
          guard let account = appState.user?.schoolid else { return }
          Task { await model.refreshAll(account: account) }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }
        .buttonStyle(.bordered)
        .disabled(model.isLoading)
      }
      HStack(spacing: 14) {
        Picker("场地", selection: Binding(
          get: { model.selectedSiteID },
          set: { value in Task { await model.selectSite(value) } }
        )) {
          ForEach(model.venues) { site in
            Text(site.displayName).tag(site.id)
          }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 300, alignment: .leading)

        Picker("日期", selection: Binding(
          get: { model.selectedDate },
          set: { value in Task { await model.selectDate(value) } }
        )) {
          ForEach(availableDates, id: \.self) { date in
            Text(date).tag(date)
          }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 140, alignment: .leading)
        .disabled(availableDates.isEmpty)
        Spacer()
      }
      if let site = model.selectedSite {
        HStack(spacing: 12) {
          if let spaces = site.reservationSpaceCount {
            Label("\(spaces) 个空间", systemImage: "door.left.hand.open")
          }
          if let phone = site.siteTelephone {
            Label(phone, systemImage: "phone")
          }
          if let start = site.openStartDate, let end = site.openEndDate {
            Label("\(start) – \(end)", systemImage: "clock")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .cgyyCard()
  }

  private var availableDates: [String] {
    if let dates = model.dayInfo?.availableDates, dates.isEmpty == false {
      return dates
    }
    return [model.selectedDate]
  }

  private func roomSection(_ dayInfo: CgyyDayInfo) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Label("选择研讨室与时段", systemImage: "clock.badge.checkmark")
          .font(.headline)
        Spacer()
        Text("同一次预约只能选择一个空间；可多选该空间时段")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if dayInfo.spaces.isEmpty {
        PageEmptyState(
          symbol: "door.left.hand.open",
          title: "当天暂无可预约空间",
          detail: "请切换日期或场地。"
        )
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 12)], spacing: 12) {
          ForEach(dayInfo.spaces) { space in
            spaceCard(space, dayInfo: dayInfo)
          }
        }
      }
    }
    .cgyyCard()
  }

  private func spaceCard(_ space: CgyySpaceAvailability, dayInfo: CgyyDayInfo) -> some View {
    let isSelectedSpace = model.selectedSpaceID == space.id
    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(space.name).font(.callout.weight(.semibold))
        Spacer()
        Text("\(space.reservableSlots.count) 段可约")
          .font(.caption2)
          .foregroundStyle(space.reservableSlots.isEmpty ? Color.secondary : Color.green)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
        ForEach(dayInfo.timeSlots) { time in
          let slot = space.slots.first { $0.timeID == time.id }
          let reservable = slot?.isReservable == true
          let selected = isSelectedSpace && model.selectedTimeIDs.contains(time.id)
          Button {
            model.selectSpace(space.id)
            model.toggle(timeID: time.id)
          } label: {
            VStack(spacing: 2) {
              Text("\(time.beginTime)–\(time.endTime)")
                .font(.caption2.monospacedDigit())
              Text(selected ? "已选" : (slot?.statusText ?? "状态待确认"))
                .font(.system(size: 9))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
              selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045),
              in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 7)
                .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.clear)
            )
          }
          .buttonStyle(.plain)
          .disabled(reservable == false)
          .opacity(reservable ? 1 : 0.45)
        }
      }
    }
    .padding(12)
    .background(
      isSelectedSpace ? Color.accentColor.opacity(0.07) : Color.primary.opacity(0.035),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(isSelectedSpace ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06))
    )
  }

  private var formCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("预约信息", systemImage: "square.and.pencil")
          .font(.headline)
        Spacer()
        if let space = model.selectedSpace, model.selectedTimeIDs.isEmpty == false {
          Text("\(space.name) · \(selectedTimeText)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 5) {
          Text("手机号").font(.caption).foregroundStyle(.secondary)
          TextField("11 位手机号", text: $model.phone)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 160)
        }
        VStack(alignment: .leading, spacing: 5) {
          Text("活动主题").font(.caption).foregroundStyle(.secondary)
          TextField("例如：小组研讨", text: $model.theme)
            .textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 5) {
          Text("活动类型").font(.caption).foregroundStyle(.secondary)
          Picker("活动类型", selection: $model.purposeTypeID) {
            ForEach(model.purposeTypes) { type in
              Text(type.name).tag(type.id)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(minWidth: 200)
        }
      }
      VStack(alignment: .leading, spacing: 5) {
        Text("活动内容").font(.caption).foregroundStyle(.secondary)
        TextField("说明活动内容与用途", text: $model.content, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(2...4)
      }
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 5) {
          Text("参与人数").font(.caption).foregroundStyle(.secondary)
          Stepper("\(model.joinerNum) 人", value: $model.joinerNum, in: 1...100)
        }
        VStack(alignment: .leading, spacing: 5) {
          Text("参与人说明").font(.caption).foregroundStyle(.secondary)
          TextField("例如：课题组 4 人", text: $model.joiners)
            .textFieldStyle(.roundedBorder)
        }
        Spacer()
      }
      HStack(spacing: 18) {
        Toggle("哲学社会科学类", isOn: $model.philosophy)
        Toggle("含校外参与人", isOn: $model.offSchool)
        Spacer()
      }
      .font(.caption)
      HStack {
        Text("提交后需等待审批；门锁密码在可开门时段返回。")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        if model.isSubmitting {
          ProgressView().controlSize(.small)
          Text("正在自动验证并提交…").font(.caption).foregroundStyle(.secondary)
        }
        Button {
          showSubmitConfirmation = true
        } label: {
          Label("提交预约", systemImage: "paperplane.fill")
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.canSubmit == false || model.isSubmitting)
      }
    }
    .cgyyCard()
  }

  private var selectedTimeText: String {
    let times = model.selectedSlots
    guard let first = times.first, let last = times.last else { return "未选时段" }
    return "\(first.beginTime)–\(last.endTime) · \(times.count) 段"
  }

  private var submitSummary: String {
    [
      model.selectedSite?.displayName,
      model.selectedSpace?.name,
      model.selectedDate,
      selectedTimeText,
      "主题：\(model.theme)",
      "手机号：\(model.phone)",
      "参与人：\(model.joinerNum) 人"
    ]
    .compactMap { $0 }
    .filter { $0.isEmpty == false }
    .joined(separator: "\n")
  }

  // MARK: - 我的预约

  private var ordersContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("我的研讨室预约", systemImage: "list.bullet.rectangle")
          .font(.headline)
        Spacer()
        Button {
          Task { await model.loadOrders() }
        } label: {
          if model.isLoadingOrders {
            ProgressView().controlSize(.small)
          } else {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }
        .buttonStyle(.bordered)
        .disabled(model.isLoadingOrders)
      }
      if model.orders.isEmpty {
        if model.isLoadingOrders {
          HStack { ProgressView(); Text("正在读取预约…").foregroundStyle(.secondary) }
        } else {
          PageEmptyState(symbol: "ticket", title: "暂无研讨室预约", detail: "提交预约后会显示审批状态。")
        }
      } else {
        ForEach(model.orders) { order in
          orderRow(order)
        }
      }
    }
    .cgyyCard()
  }

  private func orderRow(_ order: CgyyOrder) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(order.displayTitle).font(.callout.weight(.semibold))
        Spacer()
        Text(order.displayStatus.title)
          .font(.caption2.weight(.medium))
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(order.statusTint.opacity(0.12), in: Capsule())
          .foregroundStyle(order.statusTint)
      }
      Text(order.displayLocation)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(order.displayTime)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      HStack(spacing: 12) {
        if let detail = order.displayStatus.detail, detail.isEmpty == false {
          Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
        if order.canCancel() {
          Button("取消预约", role: .destructive) {
            pendingCancellation = order
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(model.cancellingOrderID != nil || model.requiresOrderReview || model.isSubmitting)
        }
        Button("查看门锁密码") {
          section = .lockCode
          Task { await model.loadLockCode() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(12)
    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
  }


  // MARK: - 门锁密码

  private var lockCodeContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("门锁密码", systemImage: "lock.open")
          .font(.headline)
        Spacer()
        Button {
          Task { await model.loadLockCode() }
        } label: {
          if model.isLoadingLockCode {
            ProgressView().controlSize(.small)
          } else {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }
        .buttonStyle(.bordered)
        .disabled(model.isLoadingLockCode)
      }
      if let lock = model.lockCode {
        if lock.hasLockCode, let code = lock.qrCode {
          VStack(alignment: .leading, spacing: 8) {
            Text("门锁密码 / 开门二维码")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(code)
              .font(.system(.title2, design: .monospaced).weight(.semibold))
              .textSelection(.enabled)
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            if let due = lock.dueDate {
              Label("有效至 \(due)", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } else if lock.hasUpcomingReservation {
          Text("预约已存在，但当前不在可开门时段，密码尚未返回。")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          Text("当前没有可用于获取门锁密码的预约。")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        if lock.displayLocation.isEmpty == false || lock.displayTime.isEmpty == false {
          VStack(alignment: .leading, spacing: 4) {
            if lock.displayLocation.isEmpty == false {
              Text(lock.displayLocation).font(.callout.weight(.medium))
            }
            if let space = lock.spaceName, space.isEmpty == false {
              Text(space).font(.caption).foregroundStyle(.secondary)
            }
            if lock.displayTime.isEmpty == false {
              Text(lock.displayTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
          }
          .padding(.top, 4)
        }
        Text("门锁密码来自学校接口，仅用于当前预约；请勿转发或截图分享。")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else if model.isLoadingLockCode {
        HStack { ProgressView(); Text("正在读取门锁密码…").foregroundStyle(.secondary) }
      } else {
        PageEmptyState(symbol: "lock", title: "暂无门锁密码", detail: "预约审批通过且进入可开门时段后，这里会显示密码。")
      }
    }
    .cgyyCard()
  }
}

private extension View {
  func cgyyCard() -> some View {
    padding(18)
      .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
  }
}

#endif

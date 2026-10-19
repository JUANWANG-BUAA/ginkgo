import Foundation

@MainActor
final class CgyyViewModel: ObservableObject {
  @Published private(set) var venues: [CgyyVenueSite] = []
  @Published private(set) var purposeTypes: [CgyyPurposeType] = []
  @Published var selectedSiteID = 0
  @Published var selectedDate = CgyyViewModel.today()
  @Published private(set) var dayInfo: CgyyDayInfo?
  @Published var selectedSpaceID = 0
  @Published private(set) var selectedTimeIDs: Set<Int> = []
  @Published private(set) var orders: [CgyyOrder] = []
  @Published private(set) var lockCode: CgyyLockCodeInfo?
  @Published private(set) var isLoading = false
  @Published private(set) var isLoadingOrders = false
  @Published private(set) var isLoadingLockCode = false
  @Published private(set) var isSubmitting = false
  @Published private(set) var cancellingOrderID: Int?
  @Published var message: String?
  @Published var errorMessage: String?

  @Published private(set) var requiresOrderReview = false

  @Published var phone = ""
  @Published var theme = ""
  @Published var content = ""
  @Published var joiners = ""
  @Published var purposeTypeID = 0
  @Published var joinerNum = 2
  @Published var philosophy = false
  @Published var offSchool = false

  private let client: CgyyClient

  init(client: CgyyClient = CgyyClient()) { self.client = client }
  private var loadedAccount: String?
  private var ordersRevision = 0
  private var lastLoadedAt: Date?

  var loginRequired: Bool {
    guard let errorMessage else { return false }
    return ["登录", "认证", "凭据", "SSO"].contains { errorMessage.contains($0) }
  }

  var selectedSite: CgyyVenueSite? {
    venues.first { $0.id == selectedSiteID }
  }

  var selectedSpace: CgyySpaceAvailability? {
    dayInfo?.spaces.first { $0.id == selectedSpaceID }
  }

  var selectedSlots: [CgyyTimeSlot] {
    (dayInfo?.timeSlots ?? []).filter { selectedTimeIDs.contains($0.id) }
  }

  var canSubmit: Bool {
    guard isSubmitting == false, requiresOrderReview == false,
          selectedSpace != nil,
          dayInfo?.siteID == selectedSiteID, dayInfo?.date == selectedDate,
          selectedTimeIDs.isEmpty == false,
          dayInfo?.reservationToken?.isEmpty == false,
          purposeTypeID > 0,
          joinerNum > 0 else { return false }
    return phone.filter(\.isNumber).count == 11
      && phone.filter(\.isNumber).count == phone.count
      && theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      && joiners.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  func start(account: String, credential: SavedCredential?) async {
    await client.setCredential(credential)
    if loadedAccount != account {
      loadedAccount = account
      venues = []
      purposeTypes = []
      orders = []
      lockCode = nil
      dayInfo = nil
      selectedTimeIDs = []
      selectedSpaceID = 0
      phone = ""
      theme = ""
      content = ""
      joiners = ""
      requiresOrderReview = false
    }
    await loadVenues()
    guard venues.isEmpty == false else { return }
    await loadPurposes()
    await loadOrders()
    await loadLockCode()
    await loadDayInfo()
    lastLoadedAt = Date()
  }

  func refreshIfStale(account: String, maxAge: TimeInterval = 2 * 60) async {
    if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < maxAge, errorMessage == nil {
      return
    }
    await refreshAll(account: account)
  }

  func refreshAll(account: String) async {
    await loadVenues()
    guard venues.isEmpty == false else { return }
    await loadPurposes()
    await loadDayInfo()
    await loadOrders()
    await loadLockCode()
    lastLoadedAt = Date()
  }

  func loadVenues() async {
    do {
      let loaded = try await client.venues()
      venues = loaded
      if venues.contains(where: { $0.id == selectedSiteID }) == false {
        selectedSiteID = venues.first?.id ?? 0
        dayInfo = nil
        selectedSpaceID = 0
        selectedTimeIDs = []
      }
    } catch {
      if RequestCancellation.isCancellation(error) == false {
        errorMessage = error.localizedDescription
      }
    }
  }

  func loadPurposes() async {
    do {
      purposeTypes = try await client.purposeTypes()
      if purposeTypes.contains(where: { $0.id == purposeTypeID }) == false {
        purposeTypeID = purposeTypes.first?.id ?? 0
      }
    } catch {
      if RequestCancellation.isCancellation(error) == false {
        AppLog.operationFailed(feature: "cgyy", stage: "purposes", error: error)
      }
    }
  }

  func selectSite(_ id: Int) async {
    guard !isSubmitting, id != selectedSiteID else { return }
    selectedSiteID = id
    selectedSpaceID = 0
    selectedTimeIDs = []
    dayInfo = nil
    await loadDayInfo()
  }

  func selectDate(_ date: String) async {
    guard !isSubmitting, date != selectedDate else { return }
    selectedDate = date
    selectedSpaceID = 0
    selectedTimeIDs = []
    dayInfo = nil
    await loadDayInfo()
  }

  func loadDayInfo() async {
    guard selectedSiteID > 0 else { return }
    guard isLoading == false else { return }
    isLoading = true
    defer { isLoading = false }
    if !requiresOrderReview { errorMessage = nil }
    while !Task.isCancelled {
      let requestedSite = selectedSiteID
      let requestedDate = selectedDate
      do {
        var info = try await client.dayInfo(siteID: requestedSite, date: requestedDate)
        guard requestedSite == selectedSiteID, requestedDate == selectedDate else { continue }
        if !info.availableDates.contains(requestedDate), let first = info.availableDates.first,
           first != requestedDate {
          info = try await client.dayInfo(siteID: requestedSite, date: first)
          guard requestedSite == selectedSiteID, requestedDate == selectedDate else { continue }
          selectedDate = first
        }
        guard info.siteID == selectedSiteID, info.date == selectedDate else {
          throw CgyyError.invalidResponse("场地或日期与请求不一致")
        }
        dayInfo = info
        if !info.spaces.contains(where: { $0.id == selectedSpaceID }) {
          selectedSpaceID = info.spaces.first?.id ?? 0
          selectedTimeIDs = []
        }
        return
      } catch {
        guard requestedSite == selectedSiteID, requestedDate == selectedDate else { continue }
        if !RequestCancellation.isCancellation(error) { errorMessage = error.localizedDescription }
        return
      }
    }
  }

  func selectSpace(_ id: Int) {
    guard !isSubmitting, id != selectedSpaceID else { return }
    selectedSpaceID = id
    selectedTimeIDs = []
  }

  func toggle(timeID: Int) {
    guard !isSubmitting, let slot = dayInfo?.timeSlots.first(where: { $0.id == timeID }),
          selectedSpace?.slots.first(where: { $0.timeID == timeID })?.isReservable == true else {
      return
    }
    _ = slot
    if selectedTimeIDs.contains(timeID) {
      selectedTimeIDs.remove(timeID)
    } else {
      selectedTimeIDs.insert(timeID)
    }
  }

  func loadOrders() async {
    guard isLoadingOrders == false else { return }
    isLoadingOrders = true
    defer { isLoadingOrders = false }
    do {
      orders = try await client.orders()
      ordersRevision += 1
    } catch {
      if RequestCancellation.isCancellation(error) == false {
        errorMessage = error.localizedDescription
      }
    }
  }

  func loadLockCode() async {
    guard isLoadingLockCode == false else { return }
    isLoadingLockCode = true
    defer { isLoadingLockCode = false }
    do {
      lockCode = try await client.lockCode()
    } catch {
      if RequestCancellation.isCancellation(error) == false {
        AppLog.operationFailed(feature: "cgyy", stage: "lock_code", error: error)
      }
    }
  }

  func submitBooking() async {
    guard isSubmitting == false else { return }
    guard let dayInfo, dayInfo.siteID == selectedSiteID, dayInfo.date == selectedDate,
          dayInfo.reservationToken?.isEmpty == false else {
      errorMessage = "预约上下文尚未加载，请刷新后重试"
      return
    }
    guard let space = selectedSpace, selectedTimeIDs.isEmpty == false else {
      errorMessage = "请选择研讨室和时间"
      return
    }
    guard canSubmit else {
      errorMessage = "请完整填写手机号、主题、内容和参与人说明"
      return
    }
    isSubmitting = true
    errorMessage = nil
    message = nil
    defer { isSubmitting = false }

    let times = dayInfo.timeSlots.filter { selectedTimeIDs.contains($0.id) }
    let selections = times.map {
      CgyyOrderSelection(spaceID: space.id, timeID: $0.id, groupID: space.groupID)
    }
    let siteID = selectedSiteID
    let bookingDate = dayInfo.date
    let form = (phone: phone, theme: theme.trimmingCharacters(in: .whitespacesAndNewlines),
      purpose: purposeTypeID, count: joinerNum, content: content.trimmingCharacters(in: .whitespacesAndNewlines),
      joiners: joiners.trimmingCharacters(in: .whitespacesAndNewlines), philosophy: philosophy, offSchool: offSchool)
    do {
      let latest = try await client.dayInfo(siteID: siteID, date: bookingDate)
      guard latest.date == bookingDate, let token = latest.reservationToken, !token.isEmpty,
            let currentSpace = latest.spaces.first(where: { $0.id == space.id }),
            selections.allSatisfy({ selection in
              currentSpace.slots.contains { $0.timeID == selection.timeID && $0.isReservable }
            }) else {
        throw CgyyError.operation("所选时段已变化，请刷新后重新选择。")
      }
      try Task.checkCancellation()
      try await client.createDraft(siteID: siteID, date: bookingDate, selections: selections, token: token)
      let challenge = try await client.captcha()
      let solution = try await Task.detached(priority: .userInitiated) {
        try CgyyCaptchaSolver.solve(
          backgroundBase64: challenge.originalImageBase64,
          jigsawBase64: challenge.jigsawImageBase64
        )
      }.value
      try await client.verifyCaptcha(
        pointJSON: solution.pointJSON,
        token: challenge.token,
        secretKey: challenge.secretKey
      )
      let verification = try CgyyCrypto.captchaVerification(
        token: challenge.token,
        pointJSON: solution.pointJSON,
        secretKey: challenge.secretKey
      )
      let submitted = try await client.submitOrder(
        siteID: siteID, date: bookingDate, selections: selections, token: token,
        phone: form.phone, theme: form.theme, purposeType: form.purpose, joinerNum: form.count,
        activityContent: form.content, joiners: form.joiners, captchaVerification: verification,
        philosophy: form.philosophy, offSchool: form.offSchool
      )
      // Acknowledged submission still needs an order to confirm the result.
      let previousRevision = ordersRevision
      await loadOrders()
      if ordersRevision > previousRevision, let submitted, orders.contains(where: { $0.id == submitted.id }) {
        message = "预约记录已查回，请查看审批状态。"
      } else {
        requiresOrderReview = true
        errorMessage = "学校已受理提交，请先在我的预约核对结果，确认前暂停再次提交。"
      }
      selectedTimeIDs = []
      await loadLockCode()
      await loadDayInfo()
    } catch CgyyError.uncertain {
      requiresOrderReview = true
      errorMessage = CgyyError.uncertain.localizedDescription
    } catch {
      if RequestCancellation.isCancellation(error) == false { errorMessage = error.localizedDescription }
    }
  }

  func acknowledgeOrderReview() async {
    guard !isSubmitting else { return }
    requiresOrderReview = false
    errorMessage = nil
    selectedTimeIDs = []
    await loadDayInfo()
  }

  func cancel(_ order: CgyyOrder) async {
    guard !isSubmitting, !requiresOrderReview, cancellingOrderID == nil else { return }
    cancellingOrderID = order.id
    message = nil
    errorMessage = nil
    defer { cancellingOrderID = nil }
    do {
      try await client.cancel(orderID: order.id)
      let previousRevision = ordersRevision
      await loadOrders()
      if ordersRevision > previousRevision,
         let updated = orders.first(where: { $0.id == order.id }), updated.orderStatus == 2 {
        message = "已查回取消状态。"
      } else {
        requiresOrderReview = true
        errorMessage = "取消请求已受理，请在我的预约核对状态，确认前暂停再次操作。"
      }
      await loadLockCode()
    } catch CgyyError.uncertain {
      requiresOrderReview = true
      errorMessage = CgyyError.uncertain.localizedDescription
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  static func today() -> String { SchoolTime.dayString() }
}

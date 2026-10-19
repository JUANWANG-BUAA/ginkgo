import Foundation

@MainActor
final class HomeworkViewModel: ObservableObject {
  @Published private(set) var snapshot: HomeworkSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var needsSessionCheck = false
  @Published private(set) var detail: HomeworkDetail?
  @Published private(set) var detailItemID: String?
  @Published private(set) var isLoadingDetail = false
  @Published private(set) var detailErrorMessage: String?

  private let service: HomeworkServing
  private let cache: HomeworkCache
  private var account: String?
  private var generation = 0
  private var detailGeneration = 0
  private var autoRefresh = AutoRefreshGate()

  init(service: HomeworkServing = HomeworkClient(), cache: HomeworkCache = HomeworkCache()) {
    self.service = service
    self.cache = cache
  }

  var pendingItems: [HomeworkItem] {
    snapshot?.items.filter { $0.status == .pending || $0.status == .overdue }
      .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) } ?? []
  }

  func attentionItems(now: Date = Date(), leadTime: TimeInterval = 24 * 60 * 60) -> [HomeworkItem] {
    let deadline = now.addingTimeInterval(max(0, leadTime))
    return pendingItems.filter { item in
      guard item.status == .pending, let dueAt = item.dueAt else { return false }
      return dueAt >= now && dueAt <= deadline
    }
  }

  func start(account: String) async {
    guard self.account != account else { return }
    reset()
    self.account = account
    isLoading = true
    let current = generation
    snapshot = await cache.read(account: account)
    guard current == generation else { return }
    await refresh()
  }

  func reset() {
    generation += 1
    detailGeneration += 1
    account = nil
    autoRefresh.reset()
    snapshot = nil
    isLoading = false
    errorMessage = nil
    needsSessionCheck = false
    detail = nil
    detailItemID = nil
    isLoadingDetail = false
    detailErrorMessage = nil
  }

  func refreshIfStale(
    maxAge: TimeInterval = 15 * 60,
    queueIfLoading: Bool = false,
    bypassCooldown: Bool = false,
    forceRefresh: Bool = false
  ) async {
    guard account != nil else { return }
    if isLoading { autoRefresh.deferWhileLoading(queue: queueIfLoading); return }
    let isStale = snapshot.map { Date().timeIntervalSince($0.fetchedAt) >= maxAge } ?? true
    let hasUnavailableSources = snapshot.map { !$0.unavailableSources.isEmpty } ?? false
    guard forceRefresh || errorMessage != nil || isStale || hasUnavailableSources,
          autoRefresh.allowsAttempt(force: forceRefresh, bypassCooldown: bypassCooldown) else { return }
    await refresh()
  }

  func refresh() async {
    generation += 1
    let current = generation
    isLoading = true
    errorMessage = nil
    needsSessionCheck = false
    defer { finishRefresh(current: current) }
    do {
      let result = try await service.load()
      guard current == generation else { return }
      snapshot = result
      if let account {
        do { try await cache.save(result, account: account) }
        catch { AppLog.cacheWriteFailed(feature: "homework", error: error) }
      }
    } catch {
      guard current == generation else { return }
      if RequestCancellation.isCancellation(error) { return }
      AppLog.operationFailed(feature: "homework", stage: "refresh", error: error)
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "学校作业更新失败"
      if case HomeworkError.sessionExpired = error { needsSessionCheck = true }
    }
  }

  func cancelPendingAutomaticRefresh() {
    autoRefresh.cancelPending()
  }

  private func finishRefresh(current: Int) {
    guard current == generation else { return }
    isLoading = false
    guard autoRefresh.takePending() else { return }
    Task { await refreshIfStale(bypassCooldown: true) }
  }

  func loadDetail(for item: HomeworkItem) async {
    if detailItemID == item.id, detail != nil { return }
    if detailItemID == item.id, isLoadingDetail { return }

    detailGeneration += 1
    let current = detailGeneration
    detailItemID = item.id
    detail = nil
    detailErrorMessage = nil
    isLoadingDetail = true
    needsSessionCheck = false
    defer {
      if current == detailGeneration { isLoadingDetail = false }
    }

    guard let detailService = service as? HomeworkDetailServing else {
      detailErrorMessage = "当前作业来源暂不支持应用内详情，请打开原作业页面查看。"
      return
    }

    do {
      let result = try await detailService.loadDetail(for: item)
      guard current == detailGeneration else { return }
      detail = result
    } catch {
      guard current == detailGeneration else { return }
      if let homeworkError = error as? HomeworkError,
         case let .upstreamProtocolChanged(_, stage) = homeworkError {
        AppLog.responseFormatChanged(feature: "homework-detail", stage: stage)
      } else {
        AppLog.operationFailed(feature: "homework", stage: "detail", error: error)
      }
      detailErrorMessage = (error as? LocalizedError)?.errorDescription ?? "作业详情加载失败"
      if case HomeworkError.sessionExpired = error { needsSessionCheck = true }
      if case HomeworkError.spocAuthenticationExpired = error { needsSessionCheck = true }
    }
  }

  func clearDetail() {
    detailGeneration += 1
    detail = nil
    detailItemID = nil
    isLoadingDetail = false
    detailErrorMessage = nil
  }

  func clearCache() async throws {
    guard let account else { return }
    try await cache.clear(account: account)
    reset()
  }
}

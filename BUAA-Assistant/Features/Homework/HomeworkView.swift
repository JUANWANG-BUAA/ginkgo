import SwiftUI

struct HomeworkView: View {
  private enum Filter: String, CaseIterable, Identifiable {
    case all = "全部"
    case pending = "待处理"
    case overdue = "已逾期"
    case submitted = "已提交"
    case unknown = "待确认"
    var id: String { rawValue }
  }

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: HomeworkViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var filter: Filter = .pending
  @State private var source: HomeworkSource?
  @State private var search = ""
  @State private var selectedItem: HomeworkItem?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "ACADEMIC / HOMEWORK", title: "学校作业", subtitle: "集中查看希冀与 SPOC 作业、截止时间和提交状态")
        if let snapshot = model.snapshot {
          summary(snapshot)
          freshness(snapshot)
          controls

          let visibleItems = filteredItems(snapshot.items)
          Text("显示 \(visibleItems.count) / \(snapshot.items.count) 项")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.updatesFrequently)
          if visibleItems.isEmpty {
            emptyState(snapshot)
          } else {
            ProgressiveList(items: visibleItems, pageSize: 40) { item in
              HomeworkAssignmentRow(item: item) { selectedItem = item }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: filter)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: source)
          }
        } else if model.isLoading {
          ProgressView("正在查询希冀与 SPOC…")
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
          PageEmptyState(symbol: "doc.badge.ellipsis", title: "暂时无法确认学校作业", detail: model.errorMessage ?? "学校服务尚未返回可用结果，请稍后重试。")
          Button("重试") { Task { await model.refresh() } }
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(24)
      .frame(maxWidth: 820, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { Task { await model.refresh() } } label: {
          Label(model.isLoading ? "正在刷新" : "刷新作业", systemImage: "arrow.clockwise")
        }
        .disabled(model.isLoading)
        .keyboardShortcut("r", modifiers: .command)
      }
    }
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid { await model.start(account: account) }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      if needed { Task { _ = try? await appState.confirmSessionAfterAuthFailure() } }
    }
    .sheet(item: $selectedItem, onDismiss: { model.clearDetail() }) { item in
      HomeworkDetailSheet(item: item, model: model)
        .task(id: item.id) { await model.loadDetail(for: item) }
    }
  }

  private func summary(_ snapshot: HomeworkSnapshot) -> some View {
    let pending = snapshot.items.filter { $0.status == .pending }.count
    let overdue = snapshot.items.filter { $0.status == .overdue }.count
    let submitted = snapshot.items.filter { $0.status == .submitted }.count
    let unknown = snapshot.items.filter { $0.status == .unknown }.count
    return HStack(spacing: 10) {
      countCard("待处理", count: pending, symbol: "doc.text", tint: .accentColor, filter: .pending)
      countCard("已逾期", count: overdue, symbol: "exclamationmark.circle.fill", tint: .orange, filter: .overdue)
      countCard("已提交", count: submitted, symbol: "checkmark.circle.fill", tint: .green, filter: .submitted)
      if unknown > 0 { countCard("待确认", count: unknown, symbol: "questionmark.circle", tint: .secondary, filter: .unknown) }
    }
  }

  private func countCard(_ title: String, count: Int, symbol: String, tint: Color, filter target: Filter) -> some View {
    let isSelected = filter == target
    return Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
        filter = target
      }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        Text("\(count)")
          .font(.title2.weight(.semibold).monospacedDigit())
          .foregroundStyle(tint)
          .contentTransition(.numericText())
          .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: count)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityLabel("\(title)作业，\(count)项")
    .accessibilityHint("筛选显示\(title)作业")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder
  private func freshness(_ snapshot: HomeworkSnapshot) -> some View {
    let protocolChanged = snapshot.protocolChangedSources.map(\.title)
    let unavailable = snapshot.unavailableSources
      .filter { !snapshot.protocolChangedSources.contains($0) }
      .map(\.title)
    VStack(alignment: .leading, spacing: 6) {
      if model.isLoading {
        StatusNotice(message: "正在更新作业 · 显示上次结果", kind: .information)
      } else if let error = model.errorMessage {
        StatusNotice(message: "更新失败：\(error) · 已保留上次结果", kind: .warning)
      } else if !snapshot.protocolChangedSources.isEmpty {
        let sources = protocolChanged.joined(separator: "、")
        let unavailableDetail = unavailable.isEmpty ? "" : "；\(unavailable.joined(separator: "、"))暂时不可用"
        StatusNotice(message: "\(sources)响应格式无法识别，接口可能已调整\(unavailableDetail)；列表仅包含已成功同步的来源，请重试", kind: .warning)
      } else if !snapshot.unavailableSources.isEmpty {
        let sources = snapshot.unavailableSources.map(\.title).joined(separator: "、")
        let spocCount = snapshot.items.filter { $0.source == .spoc }.count
        let detail = snapshot.unavailableSources.contains(.judge) && spocCount > 0
          ? "SPOC 已同步 \(spocCount) 项；希冀暂不可用（\(sources)），结果不完整"
          : "部分来源未能确认（\(sources)），计数和列表可能不完整"
        StatusNotice(message: detail, kind: .warning)
      } else {
        Label("已同步 · \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityAddTraits(.updatesFrequently)
      }

      if let term = snapshot.spocTerm, !term.displayName.isEmpty {
        let title = model.isLoading || model.errorMessage != nil ? "上次 SPOC 学期" : "SPOC 学期"
        Label("\(title)：\(term.displayName)", systemImage: "calendar")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityLabel("\(title)：\(term.displayName)")
      }
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("作业状态", selection: $filter) {
        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      HStack(spacing: 10) {
        SearchField(prompt: "搜索作业或课程", text: $search)
        Picker("来源", selection: $source) {
          Text("全部来源").tag(nil as HomeworkSource?)
          ForEach(HomeworkSource.allCases) { item in Text(item.title).tag(item as HomeworkSource?) }
        }
        .frame(width: 140)
      }
    }
  }

  @ViewBuilder
  private func emptyState(_ snapshot: HomeworkSnapshot) -> some View {
    if !snapshot.unavailableSources.isEmpty || model.errorMessage != nil {
      PageEmptyState(symbol: "questionmark.folder", title: "暂时无法确认这个筛选结果", detail: "有作业来源未能更新。可以先切换状态或稍后刷新，避免把不完整结果当作没有作业。")
    } else if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      PageEmptyState(symbol: "magnifyingglass", title: "没有匹配的作业", detail: "试试其他标题或课程关键词。")
    } else {
      PageEmptyState(symbol: "checkmark.circle", title: filter == .pending ? "暂无待处理作业" : "这个状态下没有作业", detail: "最近一次完整同步没有发现符合条件的作业。")
    }
  }

  private func filteredItems(_ items: [HomeworkItem]) -> [HomeworkItem] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return items.filter { item in
      let matchesFilter: Bool
      switch filter {
      case .all: matchesFilter = true
      case .pending: matchesFilter = item.status == .pending
      case .overdue: matchesFilter = item.status == .overdue
      case .submitted: matchesFilter = item.status == .submitted
      case .unknown: matchesFilter = item.status == .unknown
      }
      let matchesSource = source == nil || item.source == source
      let matchesSearch = query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.courseName.localizedCaseInsensitiveContains(query)
      return matchesFilter && matchesSource && matchesSearch
    }
    .sorted { lhs, rhs in
      let left = lhs.dueAt ?? .distantFuture
      let right = rhs.dueAt ?? .distantFuture
      return left == right ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending : left < right
    }
  }

}

private struct HomeworkAssignmentRow: View {
  let item: HomeworkItem
  let onOpen: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovered = false

  var body: some View {
    Button(action: onOpen) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: statusSymbol)
          .foregroundStyle(statusTint)
          .font(.body.weight(.semibold))
          .frame(width: 22)
          .padding(.top, 2)
        VStack(alignment: .leading, spacing: 5) {
          Text(item.title).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
          HStack(spacing: 8) {
            Text(item.courseName).lineLimit(1)
            Text("·").foregroundStyle(.tertiary)
            Text(item.source.title)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          if item.status == .unknown, let statusDetail = item.statusDetail {
            Text("上游状态：\(displayedStatusDetail(statusDetail))")
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Label(
            item.publishedAt.map { "发布：\($0.formatted(date: .abbreviated, time: .shortened))" } ?? "发布时间未确认",
            systemImage: "calendar.badge.clock"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          if let dueAt = item.dueAt {
            Label(deadlineText(dueAt), systemImage: "clock")
              .font(.caption)
              .foregroundStyle(deadlineTint(dueAt))
          } else if item.status == .pending || item.status == .unknown {
            Text("截止时间未确认").font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 8) {
          Text(statusTitle)
            .font(.caption.weight(.medium))
            .foregroundStyle(statusTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusTint.opacity(0.10), in: Capsule())
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color.accentColor.opacity(isHovered ? 0.42 : 0), lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(HomeworkCardButtonStyle())
    .onHover { isHovered = $0 }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    .help("打开作业详情")
    .accessibilityLabel("\(item.title)，\(item.courseName)，\(statusTitle)")
    .accessibilityHint("打开作业详情")
  }

  private var statusTitle: String {
    switch item.status {
    case .pending: "待处理"
    case .submitted: "已提交"
    case .overdue: "已逾期"
    case .unknown: "待确认"
    }
  }

  private var statusSymbol: String {
    switch item.status {
    case .pending: "doc.text.fill"
    case .submitted: "checkmark.circle.fill"
    case .overdue: "exclamationmark.circle.fill"
    case .unknown: "questionmark.circle.fill"
    }
  }

  private var statusTint: Color {
    switch item.status {
    case .pending: .accentColor
    case .submitted: .green
    case .overdue: .orange
    case .unknown: .secondary
    }
  }

  private func deadlineText(_ date: Date) -> String {
    if item.status == .overdue { return "已超过截止时间 · \(date.formatted(date: .abbreviated, time: .shortened))" }
    if item.status == .submitted { return "截止：\(date.formatted(date: .abbreviated, time: .shortened))" }
    let interval = date.timeIntervalSinceNow
    if interval <= 0 { return "截止时间已过，提交状态待确认" }
    if interval < 60 * 60 { return "剩余 \(max(1, Int(ceil(interval / 60)))) 分钟" }
    if interval < 24 * 60 * 60 { return "剩余 \(Int(ceil(interval / 3600))) 小时 · \(date.formatted(date: .omitted, time: .shortened)) 截止" }
    return "截止：\(date.formatted(date: .abbreviated, time: .shortened))"
  }

  private func deadlineTint(_ date: Date) -> Color {
    if item.status == .overdue || (item.status == .pending && date < Date()) { return .orange }
    if item.status == .pending && date.timeIntervalSinceNow < 24 * 60 * 60 { return .orange }
    return .secondary
  }

  private func displayedStatusDetail(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 48 else { return trimmed }
    return String(trimmed.prefix(48)) + "…"
  }
}

private struct HomeworkCardButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
  }
}

private struct HomeworkDetailSheet: View {
  let item: HomeworkItem
  @ObservedObject var model: HomeworkViewModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.openURL) private var openURL

  private var detail: HomeworkDetail? { model.detailItemID == item.id ? model.detail : nil }
  private var isLoading: Bool { model.detailItemID == item.id && model.isLoadingDetail }
  private var errorMessage: String? { model.detailItemID == item.id ? model.detailErrorMessage : nil }
  private var upstreamURL: URL? {
    item.sourceURL ?? (item.source == .spoc ? URL(string: "https://spoc.buaa.edu.cn/") : nil)
  }
  private var upstreamTitle: String { item.source == .spoc ? "打开 SPOC 首页" : "在希冀中打开" }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "doc.text.fill")
          .font(.title2)
          .foregroundStyle(Color.accentColor)
          .frame(width: 42, height: 42)
          .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 5) {
          Text(item.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
          Text("\(item.courseName) · \(item.source.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 12)
        Button("关闭") { dismiss() }
          .keyboardShortcut(.cancelAction)
      }
      .padding(22)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          metadata
          if isLoading {
            ProgressView("正在读取作业详情…")
              .frame(maxWidth: .infinity, minHeight: 100)
          } else if let errorMessage {
            StatusNotice(message: errorMessage, kind: .warning)
            Button("重试读取详情") { Task { await model.loadDetail(for: item) } }
              .buttonStyle(.bordered)
          } else if let detail {
            assignmentContent(detail.content)
            if !detail.problems.isEmpty { problemList(detail.problems) }
          } else {
            ProgressView("正在准备详情…")
              .frame(maxWidth: .infinity, minHeight: 100)
          }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isLoadingDetail)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: detail?.problems.count)
      }

      if let url = upstreamURL {
        Divider()
        HStack(alignment: .center, spacing: 14) {
          if item.source == .spoc {
            VStack(alignment: .leading, spacing: 3) {
              Text("在网页端继续处理")
                .font(.callout.weight(.medium))
              Text("提交与附件请在 SPOC 官网完成；打开后需自行定位本项作业。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          Spacer(minLength: 8)
          Button {
            openURL(url)
          } label: {
            Label(upstreamTitle, systemImage: "arrow.up.right.square")
          }
          .buttonStyle(.borderedProminent)
          .help(item.source == .spoc ? "打开 SPOC 首页；需要在官网内定位本项作业" : upstreamTitle)
          .accessibilityHint(item.source == .spoc ? "打开 SPOC 站点首页，不会直达当前作业" : upstreamTitle)
        }
        .padding(16)
      }
    }
    .frame(minWidth: 520, idealWidth: 620, minHeight: 420, idealHeight: 480)
  }

  @Environment(\.dismiss) private var dismiss

  private var metadata: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("作业信息")
        .font(.headline)
      Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 9) {
        metadataRow("授课教师", value: confirmedValue(item.teacherName))
        metadataRow("提交状态", value: statusText(detail?.submissionStatus ?? item.status))
        if (detail?.submissionStatus ?? item.status) == .unknown {
          metadataRow("上游状态", value: displayedStatusDetail(detail?.statusDetail ?? item.statusDetail))
        }
        metadataRow(
          "发布时间",
          value: (detail?.publishedAt ?? item.publishedAt).map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "未确认"
        )
        if let due = detail?.dueAt ?? item.dueAt {
          metadataRow("截止时间", value: due.formatted(date: .abbreviated, time: .shortened))
        } else {
          metadataRow("截止时间", value: "未确认")
        }
        metadataRow("作业分值", value: confirmedValue(detail?.score ?? item.score))
        if let earnedScore = detail?.earnedScore, !earnedScore.isEmpty {
          metadataRow("当前得分", value: earnedScore)
        }
        if let total = detail?.totalProblems, total > 0 {
          metadataRow("完成进度", value: "\(detail?.submittedCount ?? 0) / \(total) 题")
        }
        if (detail?.submissionStatus ?? item.status) == .submitted {
          metadataRow("提交时间", value: detail?.submittedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未确认")
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  private func metadataRow(_ title: String, value: String) -> some View {
    GridRow {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.callout).textSelection(.enabled)
    }
  }

  private func confirmedValue(_ value: String?) -> String {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "未确认" }
    return value
  }

  private func displayedStatusDetail(_ value: String?) -> String {
    guard let value else { return "未确认" }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 48 else { return trimmed }
    return String(trimmed.prefix(48)) + "…"
  }

  @ViewBuilder
  private func assignmentContent(_ content: String?) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("作业要求").font(.headline)
      if let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(content)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("上游暂未返回可显示的文字要求。若作业包含附件或复杂格式，请到原作业页面查看。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  private func problemList(_ problems: [HomeworkProblem]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("题目与提交进度").font(.headline)
      ForEach(problems) { problem in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: problem.status == .submitted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(problem.status == .submitted ? Color.green : Color.secondary)
            .padding(.top, 2)
          VStack(alignment: .leading, spacing: 4) {
            Text(problem.name).font(.callout.weight(.medium))
            Text(problem.statusText).font(.caption).foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          if let earned = problem.earnedScore, let maximum = problem.maxScore {
            Text("\(earned) / \(maximum)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          } else if let maximum = problem.maxScore {
            Text("满分 \(maximum)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  private func statusText(_ status: HomeworkStatus) -> String {
    switch status {
    case .pending: "待处理"
    case .submitted: "已提交"
    case .overdue: "已逾期"
    case .unknown: "状态待确认"
    }
  }
}

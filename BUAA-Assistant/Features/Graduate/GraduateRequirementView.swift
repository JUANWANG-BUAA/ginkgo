import SwiftUI

/// Shared native academic ledger. Numbers always stay attached to the scope they describe.
struct GraduateRequirementDashboard: View {
  let snapshot: GraduateAcademicSnapshot
  let progressSummary: GraduateProgressSummary?
  @State private var expanded: Set<String> = []
  @State private var pageByNode: [String: Int] = [:]
  @State private var onlyAttention = false
  @State private var query = ""

  /// `expandAll` 用于一次展开整棵要求树（渲染回归测试需要覆盖最深层的修读记录）。
  init(snapshot: GraduateAcademicSnapshot, progress: GraduateProgressSummary? = nil, expandAll: Bool = false) {
    self.snapshot = snapshot
    self.progressSummary = progress
    if expandAll {
      let root = GraduateRequirementBuilder.build(snapshot, progress: progress)
      _expanded = State(initialValue: Self.branchIDs(in: root.children))
    }
  }

  private static func branchIDs(in nodes: [GraduateRequirement]) -> Set<String> {
    nodes.reduce(into: Set<String>()) { ids, node in
      ids.insert(node.id)
      ids.formUnion(branchIDs(in: node.children))
    }
  }

  private var root: GraduateRequirement { GraduateRequirementBuilder.build(snapshot, progress: progressSummary) }
  private var rows: [GraduateRequirement] {
    root.children.filter { !onlyAttention || $0.needsAttention }.compactMap { matching($0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      summary
      if let issue = snapshot.issue(for: .execution) {
        Label(issue.usesPreviousData
          ? "执行报告更新失败，以下保留上次数据。\(issue.message)"
          : "执行报告暂不可用，暂不能确认已获学分及各层缺口。\(issue.message)",
          systemImage: "exclamationmark.triangle")
          .font(.callout).foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      VStack(alignment: .leading, spacing: 16) {
        ViewThatFits(in: .horizontal) {
          HStack { hierarchyTitle; Spacer(); controls }
          VStack(alignment: .leading, spacing: 12) { hierarchyTitle; controls }
        }
        SearchField(prompt: "查找类别、课组或课程", text: $query)
        if root.children.isEmpty {
          ContentUnavailableView(
            "尚无可核对的要求层级", systemImage: "list.bullet.indent",
            description: Text("培养方案课程池保留在“课程与原文”。执行报告加载成功后，这里会显示类别与课组要求。")
          )
        } else if rows.isEmpty {
          ContentUnavailableView("没有匹配的要求", systemImage: "line.3.horizontal.decrease",
            description: Text("可切换到全部要求，或更换搜索词。"))
        } else {
          VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, node in
              GraduateRequirementBranch(
                node: node, number: String(format: "%02d", index + 1),
                expanded: $expanded, pageByNode: $pageByNode, forceExpanded: !query.isEmpty, depth: 0
              )
              if node.id != rows.last?.id { Divider() }
            }
          }
      .background(Color.ginkgoSidebarBackground, in: RoundedRectangle(cornerRadius: 16))
          .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.ginkgoSeparator.opacity(0.55)))
        }
      }
      VStack(alignment: .leading, spacing: 7) {
        Label("如何读这份进度", systemImage: "info.circle").font(.callout.weight(.medium))
        Text("缺口 = 本层要求 − 本层已获。父项与子项可能重叠，不能相加；在修和待考核尚未计入已获。总学分达到要求后，仍需核对课组、最少门数与跨类别规则。")
        Text("课程行来自学校执行报告；可选课程另见“课程与原文”。跨类别合并要求保留完整原文，暂不自动推算。最终认定以学校审核为准。")
        if let url = GraduateAcademicDestination.execution.url {
          Link("在学校查看执行报告", destination: url).font(.callout)
        }
      }
      .font(.caption).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var hierarchyTitle: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("学分要求地图").font(.title3.weight(.semibold))
      Text("类别 → 课组 → 修读记录").font(.caption).foregroundStyle(.secondary)
    }
  }

  private var controls: some View {
    HStack(spacing: 12) {
      Button {
        onlyAttention.toggle()
      } label: {
        Label(onlyAttention ? "查看全部" : "只看需关注", systemImage: "line.3.horizontal.decrease")
      }
      .buttonStyle(.bordered).controlSize(.small)
      if !expanded.isEmpty {
        Button("全部收起", systemImage: "chevron.up") { expanded.removeAll() }
          .buttonStyle(.bordered).controlSize(.small)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private var summary: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("培养进度").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          Text(root.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
          Text([snapshot.status.college, snapshot.status.major].compactMap { $0 }.joined(separator: " · "))
            .font(.callout).foregroundStyle(.secondary)
        }
        Spacer(minLength: 12)
        Image(systemName: "tree").font(.system(size: 28, weight: .light)).foregroundStyle(Color.accentColor)
          .accessibilityHidden(true)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 10)], alignment: .leading, spacing: 10) {
        totalMetric("总要求", value: root.required, tint: .primary)
        totalMetric("方案已认定", value: root.earned, tint: .green)
        totalMetric("本学期在修", value: progressSummary?.currentTermInProgressCredits, tint: .blue, detail: inProgressDetail)
        totalMetric("距总要求", value: root.gap, tint: .orange)
      }
      if let required = root.required, required > 0,
         root.earned != nil || progressSummary?.currentTermInProgressCredits != nil || root.pending != nil {
        segmentedProgressBar(required: required)
        HStack(spacing: 14) {
          progressLegend("已认定", color: .green)
          progressLegend("在修", color: .blue)
          progressLegend("待考核", color: .orange)
          progressLegend("缺口", color: .secondary.opacity(0.35))
        }
        .font(.caption2)
        .lineLimit(1)
        if let allEarned = snapshot.planExecution?.totalEarnedCredits {
          Text("全校累计已修 \(GraduateCredit.text(allEarned)) 学分 · 其中方案已认定 \(root.earned.map(GraduateCredit.text) ?? "待核对") 学分")
            .font(.caption).foregroundStyle(.secondary)
        }
        if let pending = root.pending, pending > 0 {
          Text("另有 \(GraduateCredit.text(pending)) 学分待考核，当前未计入方案已认定。")
            .font(.caption).foregroundStyle(.orange)
        }
      }
      if let updated = snapshot.sourceDates?[GraduateAcademicSection.execution.rawValue] {
        Text("执行报告 · \(updated.formatted(date: .abbreviated, time: .shortened))")
          .font(.caption).foregroundStyle(.secondary)
      }
      HStack(alignment: .top, spacing: 7) {
        Image(systemName: "arrow.down.right")
        Text(root.gap == 0
          ? "总学分已达到要求，继续核对下方各层约束。"
          : "先看缺口落在哪一类，再展开课组与修读记录。")
      }
      .font(.caption).foregroundStyle(.secondary)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 18))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.85))
        .frame(width: 4).padding(.vertical, 16)
    }
    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.ginkgoSeparator.opacity(0.55)))
  }

  private var inProgressDetail: String {
    if progressSummary?.currentTermInProgressCredits != nil { return "学分" }
    if let count = progressSummary?.inProgressCourseCount, count > 0 {
      return "在修 \(count) 门 · 学分待核对"
    }
    return "当前课表待核对"
  }

  private func totalMetric(_ title: String, value: Double?, tint: Color, detail: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        Circle().fill(tint).frame(width: 7, height: 7)
        Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
      }
      Text(value.map(GraduateCredit.text) ?? "—")
        .font(.system(size: 27, weight: .semibold, design: .rounded).monospacedDigit())
    .foregroundStyle(value == nil ? Color.secondary : tint)
      Text(detail ?? (value == nil ? "待核对" : "学分"))
        .font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
    .padding(.horizontal, 12).padding(.vertical, 10)
    .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 11))
    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(tint.opacity(0.14)))
  }

  private func segmentedProgressBar(required: Double) -> some View {
    let denominator = max(required, 0.001)
    let earned = share(root.earned ?? 0, of: denominator)
    let inProgress = min(1 - earned, progressSummary?.currentTermInProgressCredits.map { share($0, of: denominator) } ?? 0)
    let pending = min(1 - earned - inProgress, share(root.pending ?? 0, of: denominator))
    return GeometryReader { geometry in
      HStack(spacing: 2) {
        if earned > 0 { Capsule().fill(Color.green).frame(width: geometry.size.width * earned) }
        if inProgress > 0 { Capsule().fill(Color.blue).frame(width: geometry.size.width * inProgress) }
        if pending > 0 { Capsule().fill(Color.orange).frame(width: geometry.size.width * pending) }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.secondary.opacity(0.12), in: Capsule())
      .clipShape(Capsule())
      .accessibilityElement()
      .accessibilityLabel("学分进度：已认定 \(GraduateCredit.text(root.earned ?? 0))，在修 \(progressSummary?.currentTermInProgressCredits.map(GraduateCredit.text) ?? "待核对")，待考核 \(GraduateCredit.text(root.pending ?? 0))，总要求 \(GraduateCredit.text(required)) 学分")
    }
    .frame(height: 10)
  }

  private func share(_ value: Double, of total: Double) -> Double {
    min(max(value / total, 0), 1)
  }

  private func progressLegend(_ title: String, color: Color) -> some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(title).foregroundStyle(.secondary)
    }
  }

  private func matching(_ node: GraduateRequirement) -> GraduateRequirement? {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return node }
    if ([node.title, node.code ?? "", node.note ?? ""] + node.path)
      .contains(where: { $0.localizedCaseInsensitiveContains(term) }) { return node }
    let children = node.children.compactMap { matching($0) }
    guard !children.isEmpty else { return nil }
    var result = node
    result.children = children
    return result
  }
}

private struct GraduateRequirementBranch: View {
  let node: GraduateRequirement
  let number: String
  @Binding var expanded: Set<String>
  @Binding var pageByNode: [String: Int]
  let forceExpanded: Bool
  let depth: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if node.kind == .course {
        courseRow
      } else {
        Button {
          if !expanded.insert(node.id).inserted { expanded.remove(node.id) }
        } label: {
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) { heading; Spacer(minLength: 12); figures }
            VStack(alignment: .leading, spacing: 12) { heading; figures.padding(.leading, depth == 0 ? 30 : 0) }
          }
          .padding(depth == 0 ? 18 : 14)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "收起下级要求" : "展开下级要求与修读记录")
        if (node.kind == .category || node.kind == .group), (node.required ?? 0) > 0 {
          requirementStatusBar
            .padding(.leading, depth == 0 ? 30 : 14)
            .padding(.trailing, 16)
            .padding(.bottom, 10)
        }
        if isExpanded {
          VStack(alignment: .leading, spacing: 10) {
            if let note = node.note, !note.isEmpty {
              VStack(alignment: .leading, spacing: 5) {
                Label(node.kind == .category ? "学校补充规则 · 跨类别要求需一起核对" : "核对说明", systemImage: "link")
                  .font(.caption.weight(.medium))
                Text(note).font(.callout).textSelection(.enabled)
              }
              .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
              .padding(12).frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            if let minimum = node.minimumCount, minimum > 0 {
              Text("至少完成 \(minimum) 门 · 执行报告已完成 \(node.completedCount ?? 0) 门")
                .font(.caption).foregroundStyle(.secondary)
            }
            if let pending = node.pending {
              Text("学校标记待考核 \(GraduateCredit.text(pending)) 学分，尚未计入已获。")
                .font(.caption).foregroundStyle(.secondary)
            }
            if node.children.isEmpty {
              Text("学校未返回本层修读明细，请结合方案原文核对。")
                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 6)
            }
            ForEach(displayedChildren) { child in
              GraduateRequirementBranch(node: child, number: "", expanded: $expanded,
                pageByNode: $pageByNode, forceExpanded: forceExpanded, depth: depth + 1)
            }
            if node.children.count > pageSize {
              HStack(spacing: 12) {
                Button("上一页") { pageByNode[node.id] = max(0, currentPage - 1) }
                  .disabled(currentPage == 0)
                Text("第 \(currentPage + 1) / \(pageCount) 页 · 共 \(node.children.count) 项")
                  .font(.caption).foregroundStyle(.secondary)
                Button("下一页") { pageByNode[node.id] = min(pageCount - 1, currentPage + 1) }
                  .disabled(currentPage >= pageCount - 1)
              }
              .buttonStyle(.borderless).controlSize(.small)
              .padding(.top, 4)
            }
          }
          .padding(.leading, depth == 0 ? 30 : 14)
          .padding(.trailing, 16).padding(.bottom, 18)
          .overlay(alignment: .leading) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1).padding(.leading, depth == 0 ? 18 : 0)
          }
        }
      }
    }
    .background(depth == 1 ? Color.ginkgoSidebarBackground : Color.clear,
      in: RoundedRectangle(cornerRadius: depth == 0 ? 0 : 10))
  }

  private var isExpanded: Bool { forceExpanded || expanded.contains(node.id) }
  private let pageSize = 12
  private var pageCount: Int { max(1, Int(ceil(Double(node.children.count) / Double(pageSize)))) }
  private var currentPage: Int { min(pageByNode[node.id] ?? 0, pageCount - 1) }
  private var displayedChildren: [GraduateRequirement] {
    Array(node.children.dropFirst(currentPage * pageSize).prefix(pageSize))
  }
  private var heading: some View {
    HStack(alignment: .top, spacing: 10) {
      if depth == 0 {
        Text(number).font(.caption.monospaced()).foregroundStyle(.tertiary).frame(width: 20).padding(.top, 3)
      }
      VStack(alignment: .leading, spacing: 5) {
        Text(node.title).font(depth == 0 ? .headline : .callout.weight(.medium))
          .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 5) {
          Text(depth == 0 ? hierarchyKindTitle : (node.kind == .unmapped ? "方案课程类别 · 未匹配" : "课组要求"))
          if node.children.contains(where: { $0.kind != .course && $0.needsAttention }) {
            Text("· 下级仍需核对")
          } else if node.note?.isEmpty == false {
            Text("· 含补充规则")
          }
        }.font(.caption).foregroundStyle(.secondary)
      }
      Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
        .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 4)
    }
  }

  private var hierarchyKindTitle: String {
    switch node.kind {
    case .category: "类别要求"
    case .unmapped: "课表匹配 · 未归入执行报告"
    default: "专项要求"
    }
  }

  private var hasCombinedRule: Bool { node.note?.isEmpty == false && (node.required ?? 0) == 0 }

  private var requirementStatusBar: some View {
    GeometryReader { geometry in
      let required = max(node.required ?? 0, 0.001)
      let earnedWidth = min(1, max(0, (node.earned ?? 0) / required))
      let activeWidth = min(1 - earnedWidth, max(0, (node.inProgressCredits ?? 0) / required))
      let pendingWidth = min(1 - earnedWidth - activeWidth, max(0, (node.pending ?? 0) / required))
      HStack(spacing: 2) {
        if earnedWidth > 0 { Capsule().fill(Color.green).frame(width: geometry.size.width * earnedWidth) }
        if activeWidth > 0 { Capsule().fill(Color.blue).frame(width: geometry.size.width * activeWidth) }
        if pendingWidth > 0 { Capsule().fill(Color.orange).frame(width: geometry.size.width * pendingWidth) }
        Spacer(minLength: 0)
      }
      .background(Color.secondary.opacity(0.12), in: Capsule())
      .clipShape(Capsule())
      .accessibilityLabel("\(node.title)：已获 \(GraduateCredit.text(node.earned ?? 0))，在修 \(node.inProgressCredits.map(GraduateCredit.text) ?? "待核对")，待考核 \(GraduateCredit.text(node.pending ?? 0))，要求 \(GraduateCredit.text(node.required ?? 0)) 学分")
    }
    .frame(height: 6)
  }

  private var figures: some View {
    HStack(spacing: 14) {
      figure("要求", node.required)
      figure("已获", node.earned)
      figure("在修", node.inProgressCredits, tint: .blue)
      VStack(alignment: .trailing, spacing: 4) {
        Text(hasCombinedRule ? "合并要求" : (node.gap == nil ? "待核对" : (node.gap == 0 ? "学分已满足" : "缺口")))
          .font(.caption).foregroundStyle(.secondary)
        Text(hasCombinedRule ? "见规则" : (node.gap.map(GraduateCredit.text) ?? "—"))
          .font(.callout.monospacedDigit().weight(.semibold))
          .foregroundStyle(node.hasGap ? Color.orange : (node.gap == nil ? Color.secondary : Color.green))
      }
      if let count = node.countGap, count > 0 {
        Text("还差 \(count) 门").font(.caption).foregroundStyle(.orange)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private func figure(_ title: String, _ value: Double?, tint: Color = .primary) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value.map(GraduateCredit.text) ?? "—").font(.callout.monospacedDigit().weight(.medium))
        .foregroundStyle(value == nil ? Color.secondary : tint)
    }
  }

  private var courseRow: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: courseSymbol)
          .foregroundStyle(courseStatusColor)
        Text(node.title).font(.callout).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 6)
        Text(node.credits.map { "\(GraduateCredit.text($0)) 学分" } ?? "—")
          .font(.caption.monospacedDigit().weight(.medium)).foregroundStyle(courseStatusColor)
        if let status = node.courseStatus { statusBadge(status) }
      }
      Text([node.code, node.completed.map { $0 ? "学校已确认完成" : "学校标记待考核" }, node.note]
        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .background(courseStatusColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
    .accessibilityElement(children: .combine)
  }

  private var courseStatusColor: Color {
    switch node.courseStatus {
    case .completed: .green
    case .inProgress: .blue
    case .notPassed: .red
    case .needsReview: .orange
    case .remaining, .none: .secondary
    }
  }

  private var courseSymbol: String {
    switch node.courseStatus {
    case .completed: "checkmark.circle.fill"
    case .inProgress: "clock.fill"
    case .notPassed: "xmark.circle.fill"
    case .needsReview: "exclamationmark.circle.fill"
    case .remaining, .none: "circle.dashed"
    }
  }

  private func statusBadge(_ status: GraduateCourseProgressStatus) -> some View {
    Text(status.title)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 7).padding(.vertical, 3)
      .background(courseStatusColor.opacity(0.12), in: Capsule())
      .foregroundStyle(courseStatusColor)
  }
}

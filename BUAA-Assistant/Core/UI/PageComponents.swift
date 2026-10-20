import SwiftUI

/// A compact progress guide; selected inputs remain editable in the form below.
struct QueryFlowSteps: View {
  let titles: [String]
  let current: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 8) {
      ForEach(titles.indices, id: \.self) { index in
        HStack(spacing: 6) {
          ZStack {
            Circle().fill(index <= current ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            if index < current {
              Image(systemName: "checkmark").font(.caption.weight(.semibold))
            } else {
              Text("\(index + 1)").font(.caption.monospacedDigit())
            }
          }.frame(width: 28, height: 28)
          Text(titles[index]).font(.callout.weight(index == current ? .semibold : .regular))
        }
        .foregroundStyle(index <= current ? Color.accentColor : .secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titles[index] + (index < current ? "，已选择" : (index == current ? "，当前步骤" : "，待选择")))
        if index < titles.count - 1 {
          Rectangle().fill(index < current ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15))
            .frame(maxWidth: .infinity).frame(height: 2)
        }
      }
    }
    .padding(.vertical, 8)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: current)
  }
}

struct PageHeading: View {
  let eyebrow: String
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      Text(title)
        .font(.largeTitle.weight(.semibold))
      Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Shared hierarchy for the macOS academic workspace. It uses native semantic
/// type and colors; the symbol is a quiet locator, not a decorative hero.
struct AcademicPageHeader: View {
  let section: String
  let title: String
  let subtitle: String
  let symbol: String

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 22, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Color.accentColor)
        .frame(width: 48, height: 48)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(section)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Text(title)
          .font(.title.weight(.semibold))
          .foregroundStyle(.primary)
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

struct AcademicSectionHeading: View {
  let title: String
  var detail: String? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
      Spacer(minLength: 8)
      if let detail, !detail.isEmpty {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}

struct AcademicMetric: Identifiable {
  let id: String
  let title: String
  let value: String
  var detail: String? = nil
  var symbol: String? = nil
  var tint: Color = .primary
  var isProminent = false
}

/// A single quiet summary surface with clear value hierarchy. An optional
/// action turns its metrics into native-looking filter shortcuts.
struct AcademicMetricStrip: View {
  let metrics: [AcademicMetric]
  var selectedID: String? = nil
  var onSelect: ((String) -> Void)? = nil

  var body: some View {
    HStack(spacing: 0) {
      ForEach(metrics.indices, id: \.self) { index in
        if index > 0 {
          Divider()
            .frame(height: 48)
            .padding(.horizontal, 8)
        }
        metricItem(metrics[index])
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .academicPanel(inset: 0)
  }

  @ViewBuilder
  private func metricItem(_ metric: AcademicMetric) -> some View {
    let isSelected = selectedID == metric.id
    if let onSelect {
      Button { onSelect(metric.id) } label: {
        metricContent(metric, isSelected: isSelected)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(metric.title)，\(metric.value)")
      .accessibilityHint("筛选显示\(metric.title)")
      .accessibilityAddTraits(isSelected ? .isSelected : [])
    } else {
      metricContent(metric, isSelected: false)
    }
  }

  private func metricContent(_ metric: AcademicMetric, isSelected: Bool) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 6) {
        if let symbol = metric.symbol {
          Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
        }
        Text(metric.title)
          .lineLimit(1)
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      Text(metric.value)
        .font(metric.isProminent ? .title2.weight(.semibold) : .title3.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(metric.tint)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .contentTransition(.numericText())

      if let detail = metric.detail, !detail.isEmpty {
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .background {
      if isSelected {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color.accentColor.opacity(0.09))
      }
    }
  }
}

private struct AcademicPanelModifier: ViewModifier {
  let inset: CGFloat

  func body(content: Content) -> some View {
    content
      .padding(inset)
      .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.ginkgoSeparator.opacity(0.32), lineWidth: 0.5)
      }
  }
}

extension View {
  func academicPanel(inset: CGFloat = 16) -> some View {
    modifier(AcademicPanelModifier(inset: inset))
  }
}

struct StatusNotice: View {
  enum Kind { case information, warning, success }
  let message: String
  let kind: Kind

  var body: some View {
    Label(message, systemImage: symbol)
      .font(.callout)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
      .accessibilityAddTraits(.updatesFrequently)
  }

  private var symbol: String {
    switch kind {
    case .information: "info.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .success: "checkmark.circle.fill"
    }
  }

  private var tint: Color {
    switch kind {
    case .information: .accentColor
    case .warning: .orange
    case .success: .green
    }
  }
}

struct PageEmptyState: View {
  let symbol: String
  let title: String
  let detail: String

  var body: some View {
    ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
      .frame(maxWidth: .infinity, minHeight: 220)
  }
}

/// Keeps large result sets responsive while still letting the user reach every item.
struct ProgressiveList<Item: Identifiable, RowContent: View>: View where Item.ID: Hashable {
  let items: [Item]
  let pageSize: Int
  private let rowSpacing: CGFloat
  private let rowContent: (Item) -> RowContent
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visibleLimit: Int

  init(items: [Item], pageSize: Int = 60, rowSpacing: CGFloat = 8, @ViewBuilder rowContent: @escaping (Item) -> RowContent) {
    self.items = items
    self.pageSize = max(1, pageSize)
    self.rowSpacing = max(0, rowSpacing)
    self.rowContent = rowContent
    _visibleLimit = State(initialValue: max(1, pageSize))
  }

  var body: some View {
    let visibleCount = min(visibleLimit, items.count)
    LazyVStack(alignment: .leading, spacing: rowSpacing) {
      ForEach(Array(items.prefix(visibleCount))) { item in
        rowContent(item)
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
      }

      if visibleCount < items.count {
        Button("显示更多（剩余 \(items.count - visibleCount) 项）") {
          visibleLimit = min(items.count, visibleLimit + pageSize)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
      }

      if visibleLimit > pageSize && items.count > pageSize {
        Button("收起到前 \(min(pageSize, items.count)) 项") {
          visibleLimit = pageSize
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: visibleLimit)
    .onChange(of: items.map(\.id)) { _, _ in visibleLimit = pageSize }
  }
}

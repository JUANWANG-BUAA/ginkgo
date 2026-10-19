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
  private let rowContent: (Item) -> RowContent
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visibleLimit: Int

  init(items: [Item], pageSize: Int = 60, @ViewBuilder rowContent: @escaping (Item) -> RowContent) {
    self.items = items
    self.pageSize = max(1, pageSize)
    self.rowContent = rowContent
    _visibleLimit = State(initialValue: max(1, pageSize))
  }

  var body: some View {
    let visibleCount = min(visibleLimit, items.count)
    LazyVStack(alignment: .leading, spacing: 8) {
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

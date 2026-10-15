import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var title: String { switch self { case .system: "跟随系统"; case .light: "浅色"; case .dark: "深色" } }
  var colorScheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

struct SearchField: View {
  let prompt: String
  @Binding var text: String
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField(prompt, text: $text).textFieldStyle(.plain).accessibilityLabel(prompt)
      if !text.isEmpty {
        Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
          .buttonStyle(.plain).help("清除搜索").accessibilityLabel("清除搜索")
      }
    }
    .padding(10).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.10)))
  }
}

import SwiftUI

/// 课程稳定配色：同一门课在周网格与学期总览使用同一颜色，避免总览一片单色。
enum CoursePalette {
  private static let colors: [Color] = [.blue, .teal, .indigo, .orange, .purple, .pink, .green, .red]

  static func color(for name: String) -> Color {
    var hash = 5381
    for scalar in name.unicodeScalars { hash = (hash &* 33) &+ Int(scalar.value) }
    return colors[abs(hash) % colors.count]
  }
}

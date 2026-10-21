import Foundation

/// Swift UI 文案映射；不属于可移植的筛选/排序领域契约。
enum ClassroomSortPresentation {
  static func title(for sort: ClassroomSort) -> String {
    switch sort {
    case .name: "教室名称"
    case .availability: "空闲节数优先"
    case .consecutive: "连续空闲优先"
    }
  }
}

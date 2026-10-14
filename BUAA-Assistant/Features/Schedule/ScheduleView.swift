import SwiftUI

/// 课表模块占位页。实施顺序见 docs/ROADMAP.md Step 3（本科）/ Step 4（研究生）。
struct ScheduleView: View {
  var body: some View {
    PlaceholderPage(
      title: "课表",
      systemImage: "calendar",
      roadmapNote: "ROADMAP Step 3-4（API.md §2 本科 / §3 研究生）"
    )
  }
}

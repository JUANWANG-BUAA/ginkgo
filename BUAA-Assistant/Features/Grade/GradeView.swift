import SwiftUI

/// 成绩模块占位页。实施顺序见 docs/ROADMAP.md Step 5。
struct GradeView: View {
  var body: some View {
    PlaceholderPage(
      title: "成绩与 GPA",
      systemImage: "chart.bar.fill",
      roadmapNote: "ROADMAP Step 5（API.md §4 buaascore，注意 xf/kccj 类型漂移）"
    )
  }
}

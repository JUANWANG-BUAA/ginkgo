import SwiftUI

/// 图书馆模块占位页。座位（已验证协议）先做，借阅查询为探索项。
struct LibraryView: View {
  var body: some View {
    PlaceholderPage(
      title: "图书馆",
      systemImage: "books.vertical.fill",
      roadmapNote: "ROADMAP Step 6：座位（API.md §5）· 借阅为探索项（API.md §6）"
    )
  }
}

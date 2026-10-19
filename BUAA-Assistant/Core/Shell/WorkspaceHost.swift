import SwiftUI

/// 登录后工作区的宿主：创建并注入 `WorkspaceCoordinator`。
/// 上层用 `.id(account)` 包住它，账号切换或退出登录时整个工作区随视图一起释放，
/// 内存中的查询结果不会跨账号残留。
struct WorkspaceHost<Content: View>: View {
  @StateObject private var workspace = WorkspaceCoordinator()
  private let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    content().workspaceEnvironment(workspace)
  }
}

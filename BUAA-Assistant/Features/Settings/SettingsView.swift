import SwiftUI

/// 设置页占位。真实设置（通知/自启动/退出登录）在
/// ROADMAP Step 2（退出登录）与 Step 7（通知、自启动）接入时实现。
struct SettingsView: View {
  var body: some View {
    PlaceholderPage(
      title: "设置",
      systemImage: "gearshape.fill",
      roadmapNote: "退出登录：Step 2 · 通知/开机自启：Step 7"
    )
  }
}

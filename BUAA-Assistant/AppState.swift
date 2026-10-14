import Foundation

/// 登录用户信息（仅保留展示所需字段；上游返回的证件号/手机号等
/// 隐私字段按 API.md §1.8 的说明一律不进入本模型）。
struct UserData: Equatable {
  var schoolid: String
  var name: String
}

/// 全局应用状态。UI 层通过 @EnvironmentObject 读取；
/// 登录/登出的真实流程在 ROADMAP Step 1-2 接入。
@MainActor
final class AppState: ObservableObject {
  @Published var isLoggedIn: Bool = false
  @Published var user: UserData?
}

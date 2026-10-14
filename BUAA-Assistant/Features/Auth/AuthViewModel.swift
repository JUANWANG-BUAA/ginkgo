import Foundation
import SwiftUI

/// 登录表单状态。真实登录流程（CasClient，API.md §1）在 ROADMAP Step 1 接入，
/// 当前 `login()` 只给出明确的引导提示，不做任何假成功。
@MainActor
final class AuthViewModel: ObservableObject {
  @Published var username: String = ""
  @Published var password: String = ""
  @Published var captchaText: String = ""
  @Published var captcha: CaptchaChallenge?
  @Published var isLoading: Bool = false
  @Published var error: String?

  var canSubmit: Bool {
    !username.trimmingCharacters(in: .whitespaces).isEmpty
      && !password.isEmpty
      && (captcha == nil || !captchaText.isEmpty)
      && !isLoading
  }

  func login() {
    // ROADMAP Step 1 在此接入：
    // 1) CasClient.fetchLoginPage()（APIClient.noRedirectSession + CasPageParser）
    // 2) 有验证码 → 展示图片，提交时双字段同值（API.md §1.3）
    // 3) CasClient.submitLogin() + followRedirectsAndCheckError()
    // 4) activateUc() + validateSession() → appState.isLoggedIn = true
    error = "认证服务尚未接入：请按 docs/ROADMAP.md Step 1 实施"
  }
}

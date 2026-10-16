import Foundation

/// 登录用户信息（仅保留展示所需字段；上游返回的证件号/手机号等
/// 隐私字段按 API.md §1.8 的说明一律不进入本模型）。
struct UserData: Equatable {
  var schoolid: String
  var name: String
}

enum WebVPNSessionStatus: Equatable {
  case notAttempted
  case preparing
  case ready
  case requiresCaptcha
  case unavailable
}

/// 全局应用状态。UI 层通过 @EnvironmentObject 读取。
@MainActor
final class AppState: ObservableObject {
  @Published var isLoggedIn: Bool = false
  @Published var user: UserData?
  @Published var isRestoring: Bool = true
  @Published var restoreMessage: String = "正在检查学校会话…"
  @Published var notice: String?
  @Published var toast: String?
  @Published var toastIsError = false
  @Published private(set) var webVPNSessionStatus: WebVPNSessionStatus = .notAttempted

  private(set) var rememberedCredential: SavedCredential?
  var canRetryWebVPNSession: Bool { rememberedCredential != nil }
  private let authClient: AuthSessionClient
  private let credentialStore: CredentialStore
  private let cookieStore: CookieClearing
  private var didRestore = false
  private var toastTask: Task<Void, Never>?

  init(
    authClient: AuthSessionClient = CasClient(),
    credentialStore: CredentialStore = KeychainManager(),
    cookieStore: CookieClearing = AppCookieStore()
  ) {
    self.authClient = authClient
    self.credentialStore = credentialStore
    self.cookieStore = cookieStore
  }

  /// 启动时先验证现有 Cookie；确认失效后才用钥匙串凭据静默重登一次。
  func restoreSession() async {
    guard !didRestore else { return }
    didRestore = true
    defer { isRestoring = false }
    do {
      rememberedCredential = try credentialStore.read()
    } catch {
      AppLog.auth.error("读取钥匙串失败：\(error.localizedDescription, privacy: .private)")
      notice = "无法读取已保存的账号，请手动登录"
    }
    do {
      let verifiedUser = try await authClient.validateSession()
      user = verifiedUser
      isLoggedIn = true
      showToast("学校会话已验证，登录成功")
      if let credential = rememberedCredential {
        Task { await prepareWebVPNSession(username: credential.username, password: credential.password) }
      }
      return
    } catch CasClientError.sessionInvalid {
      // 已确认无效，才允许尝试静默重登。
    } catch {
      AppLog.auth.error("启动会话验证失败：\(error.localizedDescription, privacy: .private)")
      notice = "暂时无法验证登录状态，请检查网络后手动登录"
      return
    }
    guard let credential = rememberedCredential else { return }
    restoreMessage = "会话已失效，正在自动登录…"
    do {
      let verifiedUser: UserData
      switch try await authClient.fetchLoginPage() {
      case .existingSession:
        verifiedUser = try await authClient.loginWithExistingSession()
      case .loginPage(let page):
        guard page.captcha == nil else {
          notice = "自动登录需要验证码，请手动完成登录"
          return
        }
        verifiedUser = try await authClient.login(
          page: page, username: credential.username,
          password: credential.password, captchaText: nil
        )
      }
      user = verifiedUser
      isLoggedIn = true
      notice = nil
      showToast("自动登录成功，学校会话已验证")
      Task { await prepareWebVPNSession(username: credential.username, password: credential.password) }
    } catch {
      AppLog.auth.error("自动登录失败：\(error.localizedDescription, privacy: .private)")
      notice = "自动登录未完成，请手动登录"
    }
  }

  func completeLogin(_ verifiedUser: UserData, username: String, password: String, rememberPassword: Bool) throws {
    if rememberPassword {
      let credential = SavedCredential(username: username, password: password)
      try credentialStore.save(credential)
      rememberedCredential = credential
    } else {
      try credentialStore.delete()
      rememberedCredential = nil
    }
    user = verifiedUser
    isLoggedIn = true
    notice = nil
    showToast("登录成功，学校会话已验证")
  }

  func acceptExistingSession(_ verifiedUser: UserData) {
    user = verifiedUser
    isLoggedIn = true
    notice = nil
    showToast("学校会话已验证，登录成功")
  }

  func prepareWebVPNSession(username: String, password: String) async {
    guard let preparer = authClient as? WebVPNSessionPreparing else { return }
    guard webVPNSessionStatus != .preparing else { return }
    webVPNSessionStatus = .preparing
    do {
      try await preparer.establishWebVPNSession(username: username, password: password)
      webVPNSessionStatus = .ready
      showToast("WebVPN CAS 会话已验证，正在核对签到状态")
      if notice == "学校登录成功，但 WebVPN 会话未建立；签到状态暂时无法核对" {
        notice = nil
      }
    } catch {
      let networkError = error as NSError
      AppLog.network.error(
        "WebVPN CAS session bootstrap failed error_domain=\(networkError.domain, privacy: .public) error_code=\(networkError.code)"
      )
      if case CasClientError.captchaRequired = error {
        webVPNSessionStatus = .requiresCaptcha
        showToast("WebVPN 登录需要验证码，签到状态暂未确认", isError: true)
      } else {
        webVPNSessionStatus = .unavailable
        showToast("签到 WebVPN 会话未准备，状态暂无法确认", isError: true)
      }
      notice = "学校登录成功，但 WebVPN 会话未建立；签到状态暂时无法核对"
    }
  }

  func retryWebVPNSession() async {
    guard let credential = rememberedCredential else {
      showToast("签到服务需要重新登录学校账号以建立会话", isError: true)
      return
    }
    await prepareWebVPNSession(username: credential.username, password: credential.password)
  }

  func markWebVPNSessionUnavailable() {
    guard webVPNSessionStatus != .preparing else { return }
    webVPNSessionStatus = .unavailable
  }

  /// 业务系统报未登录时调用：UC 复核确认无效才清本地会话。
  @discardableResult
  func confirmSessionAfterAuthFailure() async throws -> Bool {
    do {
      user = try await authClient.validateSession()
      isLoggedIn = true
      return true
    } catch CasClientError.sessionInvalid {
      cookieStore.clearAll()
      user = nil
      isLoggedIn = false
      notice = "登录已过期，请重新登录"
      return false
    }
  }

  func logout() async {
    notice = nil
    var remoteFailed = false
    do {
      try await authClient.logout()
    } catch {
      remoteFailed = true
      AppLog.auth.error("上游登出失败：\(error.localizedDescription, privacy: .private)")
    }
    do {
      try credentialStore.delete()
      rememberedCredential = nil
    } catch {
      AppLog.auth.error("登出时清理钥匙串失败：\(error.localizedDescription, privacy: .private)")
      notice = "已退出本机，但钥匙串清理失败，请在系统钥匙串中检查"
    }
    cookieStore.clearAll()
    user = nil
    isLoggedIn = false
    webVPNSessionStatus = .notAttempted
    toastTask?.cancel()
    toast = nil
    if notice == nil {
      notice = remoteFailed ? "已退出本机，学校服务暂未确认登出" : "已退出登录"
    }
  }

  func showToast(_ message: String, isError: Bool = false) {
    toastTask?.cancel()
    toast = message
    toastIsError = isError
    toastTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled else { return }
      self?.toast = nil
    }
  }

}

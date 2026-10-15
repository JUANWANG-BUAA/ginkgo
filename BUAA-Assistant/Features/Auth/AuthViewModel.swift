import Foundation
import SwiftUI
import AppKit

/// 登录表单状态与 CAS 流程（ROADMAP Step 1）。
@MainActor
final class AuthViewModel: ObservableObject {
  @Published var username: String = ""
  @Published var password: String = ""
  @Published var captchaText: String = ""
  @Published var captcha: CaptchaChallenge?
  @Published var captchaImage: NSImage?
  @Published var rememberPassword: Bool = false
  @Published var isLoading: Bool = false
  @Published var error: String?
  @Published var statusMessage: String?
  private let casClient: CasClient
  private var preparedPage: LoginPageInfo?
  private var didPrefill = false

  init(casClient: CasClient = CasClient()) {
    self.casClient = casClient
  }

  var canSubmit: Bool {
    !username.trimmingCharacters(in: .whitespaces).isEmpty
      && !password.isEmpty
      && (captcha == nil || !captchaText.isEmpty)
      && !isLoading
  }

  func prefill(from credential: SavedCredential?) {
    guard !didPrefill else { return }
    didPrefill = true
    guard let credential else { return }
    username = credential.username
    password = credential.password
    rememberPassword = true
  }

  func login(appState: AppState) {
    guard canSubmit else { return }
    isLoading = true
    error = nil
    statusMessage = preparedPage == nil ? "正在连接北航统一身份认证…" : "正在提交验证码并验证会话…"
    Task {
      defer { isLoading = false }
      do {
        if preparedPage == nil {
          switch try await casClient.fetchLoginPage() {
          case .existingSession:
            statusMessage = "已找到学校会话，正在验证…"
            let user = try await casClient.loginWithExistingSession()
            appState.acceptExistingSession(user)
            return
          case .loginPage(let page):
            preparedPage = page
            statusMessage = "已收到认证页面"
            if let challenge = page.captcha {
              captcha = challenge
              statusMessage = "认证服务要求验证码，正在获取图片…"
              let data = try await casClient.fetchCaptchaImage(for: challenge)
              captchaImage = NSImage(data: data)
              if captchaImage == nil { throw CasClientError.invalidPageEncoding }
              statusMessage = "请输入验证码后再次点击登录"
              return
            }
          }
        }
        guard let page = preparedPage else { throw CasClientError.missingExecution }
        statusMessage = "认证页面已返回，正在提交并验证学校会话…"
        let user = try await casClient.login(
          page: page, username: username.trimmingCharacters(in: .whitespacesAndNewlines),
          password: password, captchaText: captchaText
        )
        do {
          try appState.completeLogin(
            user, username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password, rememberPassword: rememberPassword
          )
        } catch {
          AppLog.auth.error("登录后保存凭据失败：\(error.localizedDescription, privacy: .private)")
          appState.acceptExistingSession(user)
          appState.notice = "已登录，但本机保存登录凭据失败，请检查钥匙串"
        }
      } catch {
        AppLog.auth.error("登录流程失败：\(error.localizedDescription, privacy: .private)")
        self.error = (error as? LocalizedError)?.errorDescription ?? "网络不可用，请检查连接后重试"
        statusMessage = nil
        // CAS execution 通常只能用一次；失败后下次从新登录页开始。
        preparedPage = nil
        captcha = nil
        captchaImage = nil
        captchaText = ""
      }
    }
  }
}

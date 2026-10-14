import SwiftUI

/// 登录界面（骨架态）。布局与控件遵循 ARCHITECTURE.md §10 的 HIG 约束：
/// 语义色、系统文本样式、控件 28pt 高度、内容内边距 16pt。
struct LoginView: View {
  @StateObject private var viewModel = AuthViewModel()

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "graduationcap.fill")
        .font(.system(size: 56))
        .foregroundStyle(.tint)
        .padding(.top, 48)

      Text("BUAA Assistant")
        .font(.largeTitle.weight(.bold))

      Text("北航校园服务 · macOS 原生客户端")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Form {
        TextField("学号", text: $viewModel.username)
          .accessibilityLabel("学号输入框")
        SecureField("密码", text: $viewModel.password)
          .accessibilityLabel("密码输入框")

        if let captcha = viewModel.captcha {
          HStack(spacing: 12) {
            AsyncImage(url: captcha.imageURL)
              .frame(width: 120, height: 40)
              .accessibilityLabel("验证码图片")
            TextField("验证码", text: $viewModel.captchaText)
              .accessibilityLabel("验证码输入框")
          }
        }

        Button {
          viewModel.login()
        } label: {
          if viewModel.isLoading {
            ProgressView()
              .controlSize(.small)
              .frame(maxWidth: .infinity)
          } else {
            Text("登录")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSubmit)
        .accessibilityLabel("登录按钮")
      }
      .frame(maxWidth: 360)
      .padding(.horizontal, 16)

      if let error = viewModel.error {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.callout)
          .foregroundStyle(.orange)
          .padding(.horizontal)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

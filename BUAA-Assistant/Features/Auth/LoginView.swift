import SwiftUI

/// CAS 登录界面。布局与控件遵循 UI-DESIGN.md §4.1：
/// 语义色、系统文本样式、控件 28pt 高度、内容内边距 16pt。
struct LoginView: View {
  @StateObject private var viewModel = AuthViewModel()
  @EnvironmentObject private var appState: AppState

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "graduationcap.fill")
          .font(.largeTitle)
          .foregroundStyle(.tint)
          .frame(width: 64, height: 64)
          .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        Spacer()
        Text("你的校园，\n一目了然。")
          .font(.system(.largeTitle, design: .rounded, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        Text("课程、成绩与校园服务，集中在 Mac 上。")
          .font(.body)
          .foregroundStyle(.secondary)
        Spacer()
        Text("BUAA ASSISTANT")
          .font(.caption.weight(.semibold))
          .tracking(1.5)
          .foregroundStyle(.secondary)
      }
      .padding(36)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(Color(nsColor: .controlBackgroundColor))

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          PageHeading(eyebrow: "SECURE SIGN IN", title: "登录", subtitle: "使用北航统一身份认证账号")
          VStack(alignment: .leading, spacing: 12) {
            Text("学号").font(.subheadline.weight(.medium))
            TextField("请输入学号", text: $viewModel.username)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("学号输入框")
            Text("密码").font(.subheadline.weight(.medium))
            SecureField("请输入密码", text: $viewModel.password)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("密码输入框")
            if viewModel.captcha != nil {
              Text("验证码").font(.subheadline.weight(.medium))
              HStack(spacing: 12) {
                if let image = viewModel.captchaImage {
                  Image(nsImage: image).resizable().scaledToFit()
                    .frame(width: 120, height: 40).accessibilityLabel("验证码图片")
                }
                TextField("请输入验证码", text: $viewModel.captchaText)
                  .textFieldStyle(.roundedBorder)
                  .accessibilityLabel("验证码输入框")
              }
            }
          }
          Toggle("记住密码，下次自动登录", isOn: $viewModel.rememberPassword)
            .accessibilityHint("密码仅保存在本机钥匙串；关闭后登录会删除已保存的凭据")
          Button {
            viewModel.login(appState: appState)
          } label: {
            HStack {
              if viewModel.isLoading { ProgressView().controlSize(.small) }
              Text(viewModel.isLoading ? "正在登录…" : "登录")
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(!viewModel.canSubmit)
          .accessibilityLabel("登录按钮")
          if let status = viewModel.statusMessage {
            StatusNotice(message: status, kind: .information)
          }
          if let error = viewModel.error {
            StatusNotice(message: error, kind: .warning)
          }
          if let notice = appState.notice {
            StatusNotice(message: notice, kind: .information)
          }
          Text("登录状态由学校服务确认。仅勾选记住密码时，凭据才会保存到本机钥匙串。")
            .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: 360)
        .padding(36)
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear { viewModel.prefill(from: appState.rememberedCredential) }
  }
}

import SwiftUI

/// CAS 登录界面（应用首页）。左侧品牌简介 + 右侧登录表单。
/// 布局遵循 UI-DESIGN.md §4.1：语义色、系统文本样式、系统控件。
/// 动效只做轻微的位移/淡入与图标呼吸；开启「减少动态效果」时全部跳过。
struct LoginView: View {
  @StateObject private var viewModel = AuthViewModel()
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  @State private var glow = false

  var body: some View {
    HStack(spacing: 0) {
      brandPanel
      formPanel
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      viewModel.prefill(from: appState.rememberedCredential)
      if reduceMotion {
        appeared = true
      } else {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { glow = true }
      }
    }
  }

  // MARK: - 品牌区

  private var brandPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        appIcon
        VStack(alignment: .leading, spacing: 2) {
          Text("Ginkgo").font(.system(.title3, design: .rounded).weight(.semibold))
          Text("北航校园工作台").font(.caption).foregroundStyle(.secondary)
        }
      }
      .modifier(EntranceModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05))

      Spacer(minLength: 32)

      VStack(alignment: .leading, spacing: 0) {
        Text("你的校园，\n一目了然。")
          .font(.system(.largeTitle, design: .rounded, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
          .minimumScaleFactor(0.85)
        Text("课程、成绩与校园服务，集中在 Mac 上。")
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)
        VStack(alignment: .leading, spacing: 10) {
          FeatureLine(symbol: "calendar", text: "课表 · 今日课程与考试安排")
          FeatureLine(symbol: "checkmark.seal", text: "签到 · iclass 状态核对")
          FeatureLine(symbol: "books.vertical", text: "预约 · 图书馆座位与实时人数")
        }
        .padding(.top, 26)
      }
      .modifier(EntranceModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.14))

      Spacer(minLength: 32)

      Text("开源 · MIT License · 数据只留本机")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .modifier(EntranceModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.22))
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(brandBackground)
    .overlay(alignment: .trailing) { Divider() }
  }

  private var appIcon: some View {
    Image(systemName: "graduationcap.fill")
      .font(.system(size: 22, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 46, height: 46)
      .background(
        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .shadow(color: Color.accentColor.opacity(glow ? 0.38 : 0.16), radius: glow ? 14 : 8, y: 4)
      .accessibilityHidden(true)
  }

  /// 很淡的品牌底色：窗口背景上叠一层 accent 渐变，避免大面积纯色空白。
  private var brandBackground: some View {
    ZStack {
      Color(nsColor: .underPageBackgroundColor)
      LinearGradient(colors: [Color.accentColor.opacity(0.10), Color.accentColor.opacity(0.02), .clear],
                     startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  // MARK: - 表单区

  private var formPanel: some View {
    GeometryReader { geometry in
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
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 360)
        .padding(40)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// 品牌区的功能点行。
private struct FeatureLine: View {
  let symbol: String
  let text: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.callout)
        .foregroundStyle(.tint)
        .frame(width: 20)
      Text(text)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }
}

/// 轻微入场动画；「减少动态效果」时直接显示。
private struct EntranceModifier: ViewModifier {
  let appeared: Bool
  let reduceMotion: Bool
  let delay: Double

  func body(content: Content) -> some View {
    content
      .opacity(appeared ? 1 : 0)
      .offset(y: appeared || reduceMotion ? 0 : 10)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay), value: appeared)
  }
}

import SwiftUI

/// Login screen built with the same native Form primitives an iOS Settings or
/// account screen uses. It keeps the brand identity, but removes the desktop
/// split-panel/card composition.
struct IOSLoginView: View {
  @StateObject private var viewModel = AuthViewModel()
  @EnvironmentObject private var appState: AppState
  @FocusState private var focusedField: Field?
  @AppStorage(UpstreamRoutePreference.storageKey) private var upstreamRoute = UpstreamRoutePreference.automatic.rawValue

  private enum Field: Hashable {
    case username
    case password
    case captcha
  }

  private var selectedUpstreamRoute: UpstreamRoutePreference {
    UpstreamRoutePreference(rawValue: upstreamRoute) ?? .automatic
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
              .font(.system(size: 40, weight: .semibold))
              .foregroundStyle(.white)
              .frame(width: 76, height: 76)
              .background(
                LinearGradient(
                  colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
              )
              .shadow(color: Color.accentColor.opacity(0.20), radius: 12, y: 5)
              .accessibilityHidden(true)

            Text("Ginkgo")
              .font(.system(.title, design: .rounded, weight: .bold))
            Text("北航校园工作台")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .listRowBackground(Color.clear)
        }

        Section {
          LabeledContent("学号") {
            TextField("请输入学号", text: $viewModel.username)
              .multilineTextAlignment(.trailing)
              .textContentType(.username)
              .keyboardType(.asciiCapable)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .focused($focusedField, equals: .username)
              .submitLabel(.next)
              .onSubmit { focusedField = .password }
              .accessibilityLabel("学号输入框")
              .accessibilityIdentifier("login-username")
          }

          LabeledContent("密码") {
            SecureField("请输入密码", text: $viewModel.password)
              .multilineTextAlignment(.trailing)
              .textContentType(.password)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .focused($focusedField, equals: .password)
              .submitLabel(viewModel.captcha == nil ? .go : .next)
              .onSubmit {
                if viewModel.captcha == nil, viewModel.canSubmit {
                  viewModel.login(appState: appState)
                } else if viewModel.captcha != nil {
                  focusedField = .captcha
                }
              }
              .accessibilityLabel("密码输入框")
              .accessibilityIdentifier("login-password")
          }

          if viewModel.captcha != nil {
            VStack(alignment: .leading, spacing: 8) {
              if let image = viewModel.captchaImage {
                Image(ginkgoPlatformImage: image)
                  .resizable()
                  .interpolation(.none)
                  .scaledToFit()
                  .frame(maxWidth: 180, maxHeight: 56)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .accessibilityLabel("验证码图片")
              }
              TextField("验证码", text: $viewModel.captchaText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focusedField, equals: .captcha)
                .submitLabel(.go)
                .onSubmit {
                  if viewModel.canSubmit { viewModel.login(appState: appState) }
                }
                .accessibilityLabel("验证码输入框")
            }
          }

          Toggle("记住密码，下次自动登录", isOn: $viewModel.rememberPassword)
            .accessibilityHint("密码仅保存在本机钥匙串；关闭后登录会删除已保存的凭据")
        } header: {
          Text("统一身份认证")
        } footer: {
          Text("登录状态由学校服务确认。只有勾选“记住密码”时，凭据才会保存到系统钥匙串。")
        }

        if let status = viewModel.statusMessage {
          Section {
            Label(status, systemImage: "arrow.triangle.2.circlepath")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        if let error = viewModel.error {
          Section {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }

        if let notice = appState.notice {
          Section {
            Label(notice, systemImage: "info.circle.fill")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          Button {
            focusedField = nil
            viewModel.login(appState: appState)
          } label: {
            HStack {
              Spacer()
              if viewModel.isLoading {
                ProgressView().controlSize(.small)
              }
              Text(viewModel.isLoading ? "正在登录…" : "登录")
                .fontWeight(.semibold)
              Spacer()
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(viewModel.canSubmit == false)
          .accessibilityLabel("登录按钮")
          .accessibilityIdentifier("login-button")
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
      }
      .navigationTitle("登录")
      .navigationBarTitleDisplayMode(.large)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            ForEach(UpstreamRoutePreference.allCases) { route in
              Button {
                upstreamRoute = route.rawValue
              } label: {
                if selectedUpstreamRoute == route {
                  Label(route.title, systemImage: "checkmark")
                } else {
                  Text(route.title)
                }
              }
            }
          } label: {
            Label(selectedUpstreamRoute.title, systemImage: "network")
              .labelStyle(.titleAndIcon)
              .font(.caption.weight(.medium))
          }
          .accessibilityLabel("校园服务路线：\(selectedUpstreamRoute.title)")
          .accessibilityHint(selectedUpstreamRoute.detail)
        }
      }
      .onChange(of: upstreamRoute) { _, _ in
        AppCookieStore().clearAll()
        viewModel.resetForRouteChange()
      }
      .onAppear {
        viewModel.prefill(from: appState.rememberedCredential)
      }
      .onChange(of: viewModel.captcha) { _, challenge in
        if challenge != nil { focusedField = .captcha }
      }
    }
  }
}

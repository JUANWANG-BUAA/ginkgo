import SwiftUI

// 这些修饰符只服务于 macOS 页面；iOS 使用原生 Form/List 交互，因此不编译本文件。
private struct GinkgoPagePaddingModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 24)
      .padding(.vertical, 24)
  }
}

private struct GinkgoSheetSizingModifier: ViewModifier {
  let minWidth: CGFloat
  let minHeight: CGFloat
  let idealWidth: CGFloat?
  let idealHeight: CGFloat?

  func body(content: Content) -> some View {
    content.frame(
      minWidth: minWidth,
      idealWidth: idealWidth,
      maxWidth: nil,
      minHeight: minHeight,
      idealHeight: idealHeight,
      maxHeight: nil
    )
  }
}

extension View {
  /// Compact iPhone layouts need tighter edge spacing while iPad and macOS keep
  /// the roomier desktop rhythm.
  func ginkgoPagePadding() -> some View {
    modifier(GinkgoPagePaddingModifier())
  }

  /// Sheets that use explicit mac widths must become full-width on iPhone.
  func ginkgoSheetSizing(
    minWidth: CGFloat,
    minHeight: CGFloat,
    idealWidth: CGFloat? = nil,
    idealHeight: CGFloat? = nil
  ) -> some View {
    modifier(GinkgoSheetSizingModifier(
      minWidth: minWidth,
      minHeight: minHeight,
      idealWidth: idealWidth,
      idealHeight: idealHeight
    ))
  }

  /// iOS keyboard/autofill hints. These modifiers do not exist on macOS, so the
  /// shared login view opts into them through no-op desktop fallbacks.
  func ginkgoUsernameEntry() -> some View { self }

  func ginkgoPasswordEntry() -> some View { self }

  func ginkgoCaptchaEntry() -> some View { self }

  /// 指针悬停反馈。
  func ginkgoOnHover(perform action: @escaping (Bool) -> Void) -> some View {
    onHover(perform: action)
  }

  /// Esc 关闭弹层。
  func ginkgoOnExitCommand(perform action: @escaping () -> Void) -> some View {
    onExitCommand(perform: action)
  }

  /// 系统链接按钮样式。
  func ginkgoLinkButtonStyle() -> some View { buttonStyle(.link) }
}

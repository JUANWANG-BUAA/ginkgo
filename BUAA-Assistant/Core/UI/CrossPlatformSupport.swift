import SwiftUI

#if os(macOS)
import AppKit
typealias GinkgoPlatformImage = NSImage
#elseif os(iOS)
import UIKit
typealias GinkgoPlatformImage = UIImage
#endif

/// Semantic colors keep the feature views shared between macOS and iOS while
/// still using each platform's native appearance and accessibility contrast.
extension Color {
  static var ginkgoWindowBackground: Color {
    #if os(macOS)
    Color(nsColor: .windowBackgroundColor)
    #else
    Color(uiColor: .systemBackground)
    #endif
  }

  static var ginkgoSidebarBackground: Color {
    #if os(macOS)
    Color(nsColor: .underPageBackgroundColor)
    #else
    Color(uiColor: .systemGroupedBackground)
    #endif
  }

  static var ginkgoCardBackground: Color {
    #if os(macOS)
    Color(nsColor: .controlBackgroundColor)
    #else
    Color(uiColor: .secondarySystemGroupedBackground)
    #endif
  }

  static var ginkgoFieldBackground: Color {
    #if os(macOS)
    Color(nsColor: .textBackgroundColor)
    #else
    Color(uiColor: .secondarySystemBackground)
    #endif
  }

  static var ginkgoSeparator: Color {
    #if os(macOS)
    Color(nsColor: .separatorColor)
    #else
    Color(uiColor: .separator)
    #endif
  }
}

extension Image {
  init(ginkgoPlatformImage: GinkgoPlatformImage) {
    #if os(macOS)
    self.init(nsImage: ginkgoPlatformImage)
    #else
    self.init(uiImage: ginkgoPlatformImage)
    #endif
  }
}

import AppKit
import UserNotifications

@MainActor
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = AppNotificationDelegate()

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    Task { @MainActor in
      AppWindowRouter.shared.focusMainWindow()
    }
    completionHandler()
  }
}

@MainActor
final class AppWindowRouter {
  static let shared = AppWindowRouter()

  private var openMainWindow: (() -> Void)?

  func setOpenMainWindow(_ action: @escaping () -> Void) {
    openMainWindow = action
  }

  func focusMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: \.canBecomeMain) {
      if window.isMiniaturized { window.deminiaturize(nil) }
      window.makeKeyAndOrderFront(nil)
    } else {
      openMainWindow?()
    }
  }
}

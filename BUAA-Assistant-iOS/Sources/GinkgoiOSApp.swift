import SwiftUI
import UserNotifications

@main
struct GinkgoiOSApp: App {
  @StateObject private var appState = AppState()
  @StateObject private var courseReminders = CourseReminderScheduler()

  init() {
    IOSStoragePolicy.excludeSensitiveCachesFromBackup()
    #if DEBUG
    if ProcessInfo.processInfo.environment["GINKGO_UI_TESTING"] == "1" {
      try? KeychainManager().delete()
      AppCookieStore().clearAll()
    }
    #endif
    UNUserNotificationCenter.current().delegate = GinkgoNotificationDelegate.shared
  }

  var body: some Scene {
    WindowGroup {
      IOSRootView()
        .environmentObject(appState)
        .environmentObject(courseReminders)
    }
  }
}

/// iOS needs an explicit foreground presentation delegate; otherwise scheduled
/// reminders are silent while the user is already in the app.
final class GinkgoNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = GinkgoNotificationDelegate()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}

import UserNotifications

@MainActor
protocol CheckInNotificationServing: AnyObject {
  func authorizationStatus() async -> UNAuthorizationStatus
  func requestAuthorization() async throws -> Bool
  func sendStatusChangeNotification()
}

@MainActor
final class SystemCheckInNotificationClient: CheckInNotificationServing {
  private let center = UNUserNotificationCenter.current()

  func authorizationStatus() async -> UNAuthorizationStatus {
    await center.notificationSettings().authorizationStatus
  }

  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }

  func sendStatusChangeNotification() {
    let content = UNMutableNotificationContent()
    content.title = "课程签到状态已更新"
    content.body = "iclass 已确认课程签到状态变化，打开 BUAA Assistant 查看详情。"
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "check-in-status-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    center.add(request) { error in
      if let error {
        let notificationError = error as NSError
        AppLog.network.error(
          "发送签到状态通知失败 error_domain=\(notificationError.domain, privacy: .public) error_code=\(notificationError.code)"
        )
      }
    }
  }
}

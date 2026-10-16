import CryptoKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class CourseReminderScheduler: ObservableObject {
  private static let enabledKey = "courseRemindersEnabled"
  private static let identifierPrefix = "course-reminder-"
  private static let horizonDays = 14

  @Published private(set) var isEnabled: Bool
  @Published private(set) var scheduledCount = 0
  @Published private(set) var statusMessage: String

  private let center: UNUserNotificationCenter
  private let defaults: UserDefaults
  private var generation = 0
  private var updateTask: Task<Void, Never>?

  init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
    self.center = center
    self.defaults = defaults
    let remindersEnabled = defaults.bool(forKey: Self.enabledKey)
    isEnabled = remindersEnabled
    statusMessage = remindersEnabled ? "正在读取课表并安排提醒…" : "课前提醒已关闭"
  }

  func setEnabled(_ enabled: Bool) {
    guard isEnabled != enabled else { return }
    generation += 1
    isEnabled = enabled
    defaults.set(enabled, forKey: Self.enabledKey)
    if enabled {
      statusMessage = "正在读取课表并安排提醒…"
    } else {
      scheduledCount = 0
      statusMessage = "课前提醒已关闭"
    }
  }

  func update(snapshot: ScheduleSnapshot?) async {
    generation += 1
    let currentGeneration = generation
    let previousTask = updateTask

    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      if let previousTask { await previousTask.value }
      guard currentGeneration == self.generation else { return }
      await self.reschedule(snapshot: snapshot, generation: currentGeneration)
      if currentGeneration == self.generation { self.updateTask = nil }
    }
    updateTask = task
    await task.value
  }

  private func reschedule(snapshot: ScheduleSnapshot?, generation currentGeneration: Int) async {
    guard currentGeneration == generation else { return }
    guard isEnabled else {
      await removeScheduledRequests(generation: currentGeneration)
      guard currentGeneration == generation else { return }
      statusMessage = "课前提醒已关闭"
      scheduledCount = 0
      return
    }

    let authorization = await center.notificationSettings().authorizationStatus
    guard currentGeneration == generation else { return }
    switch authorization {
    case .authorized, .provisional, .ephemeral:
      break
    case .denied:
      await removeScheduledRequests(generation: currentGeneration)
      guard currentGeneration == generation else { return }
      scheduledCount = 0
      statusMessage = "系统通知未授权；请在 macOS 系统设置中开启"
      return
    case .notDetermined:
      await removeScheduledRequests(generation: currentGeneration)
      guard currentGeneration == generation else { return }
      scheduledCount = 0
      statusMessage = "请先授权 macOS 通知，再安排课程提醒"
      return
    @unknown default:
      await removeScheduledRequests(generation: currentGeneration)
      guard currentGeneration == generation else { return }
      scheduledCount = 0
      statusMessage = "无法读取系统通知权限状态"
      return
    }

    guard let snapshot else {
      await removeScheduledRequests(generation: currentGeneration)
      guard currentGeneration == generation else { return }
      scheduledCount = 0
      statusMessage = "登录并读取课表后安排提醒"
      return
    }

    let plan = Self.makeRequests(snapshot: snapshot, now: Date())
    await removeScheduledRequests(generation: currentGeneration)
    guard currentGeneration == generation else { return }

    var added = 0
    var failed = 0
    for request in plan.requests {
      guard currentGeneration == generation, !Task.isCancelled else { return }
      do {
        try await center.add(request)
        added += 1
      } catch {
        failed += 1
        let notificationError = error as NSError
        AppLog.network.error(
          "安排课程提醒失败 error_domain=\(notificationError.domain, privacy: .public) error_code=\(notificationError.code)"
        )
      }
    }

    guard currentGeneration == generation else { return }
    scheduledCount = added
    if failed > 0 {
      statusMessage = "已安排 \(added) 条，另有 \(failed) 条未能安排；请检查系统通知设置"
    } else if plan.coveredWeeks == 0 {
      statusMessage = "未来两周的课程周次尚未缓存；打开课表同步后安排提醒"
    } else if added == 0 {
      statusMessage = "未来两周没有可安排的课程提醒"
    } else {
      statusMessage = "已安排 \(added) 条课程提醒（未来 14 天）"
    }
  }

  private func removeScheduledRequests(generation currentGeneration: Int) async {
    let pending = await center.pendingNotificationRequests()
    guard currentGeneration == generation else { return }
    let identifiers = pending
      .map(\.identifier)
      .filter { $0.hasPrefix(Self.identifierPrefix) }
    guard !identifiers.isEmpty else { return }
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  private static func makeRequests(snapshot: ScheduleSnapshot, now: Date) -> (requests: [UNNotificationRequest], coveredWeeks: Int) {
    var calendar = ScheduleSnapshot.schoolCalendar
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
    var requests: [UNNotificationRequest] = []
    var identifiers = Set<String>()
    var coveredWeeks = 0

    for week in snapshot.weeks {
      guard let weekEndExclusive = calendar.date(
        byAdding: .day,
        value: 1,
        to: calendar.startOfDay(for: week.end)
      ), week.start <= horizon, weekEndExclusive > now else { continue }
      let meetings: [CourseMeeting]
      if week.number == snapshot.weekNumber {
        meetings = snapshot.courses
      } else if let cached = snapshot.termCourses?[String(week.number)] {
        meetings = cached
      } else {
        continue
      }
      coveredWeeks += 1

      for meeting in meetings {
        guard (1...7).contains(meeting.day),
              let (hour, minute) = clockTime(meeting.startTime),
              let meetingDate = calendar.date(
                byAdding: .day,
                value: meeting.day - 1,
                to: calendar.startOfDay(for: week.start)
              ),
              let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: meetingDate),
              start > now,
              start <= horizon,
              let fireDate = calendar.date(byAdding: .minute, value: -10, to: start),
              fireDate > now else { continue }

        let identifier = requestIdentifier(meetingID: meeting.id, date: meetingDate)
        guard identifiers.insert(identifier).inserted else { continue }

        let content = UNMutableNotificationContent()
        content.title = "课程即将开始"
        content.body = "10 分钟后有课程，打开 Ginkgo 查看课表。"
        content.sound = .default
        content.threadIdentifier = "course-reminders"

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        requests.append(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
      }
    }

    return (requests.sorted { lhs, rhs in
      guard let left = lhs.trigger as? UNCalendarNotificationTrigger,
            let right = rhs.trigger as? UNCalendarNotificationTrigger,
            let leftDate = calendar.date(from: left.dateComponents),
            let rightDate = calendar.date(from: right.dateComponents) else { return lhs.identifier < rhs.identifier }
      return leftDate < rightDate
    }, coveredWeeks)
  }

  private static func clockTime(_ value: String?) -> (hour: Int, minute: Int)? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "：", with: ":")
    let parts = normalized.split(separator: ":", omittingEmptySubsequences: false)
    let hour: Int
    let minute: Int
    if parts.count == 2, let parsedHour = Int(parts[0]), let parsedMinute = Int(parts[1]) {
      hour = parsedHour
      minute = parsedMinute
    } else if parts.count == 1, let compact = Int(normalized), (3...4).contains(normalized.count) {
      hour = compact / 100
      minute = compact % 100
    } else {
      return nil
    }
    guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
    return (hour, minute)
  }

  private static func requestIdentifier(meetingID: String, date: Date) -> String {
    var calendar = ScheduleSnapshot.schoolCalendar
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let dateKey = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    let digest = SHA256.hash(data: Data(meetingID.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    return "\(identifierPrefix)\(dateKey)-\(digest)"
  }
}

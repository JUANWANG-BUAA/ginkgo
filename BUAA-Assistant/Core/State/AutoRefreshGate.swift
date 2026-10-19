import Foundation

/// 页面切换、回到前台和网络恢复都会触发自动刷新。这里集中节流策略：
/// 冷却期内不重复请求（强制刷新 5 秒、普通 30 秒）；加载中收到的请求只排队一次，
/// 当前请求结束后补做。手动刷新不经过这里。
struct AutoRefreshGate {
  private var lastAttemptAt: Date?
  private var isPending = false

  mutating func deferWhileLoading(queue: Bool) {
    if queue { isPending = true }
  }

  /// 通过冷却检查时记录本次尝试并返回 true。
  mutating func allowsAttempt(force: Bool, bypassCooldown: Bool, now: Date = Date()) -> Bool {
    let cooldown: TimeInterval = force ? 5 : 30
    if !bypassCooldown, let lastAttemptAt, now.timeIntervalSince(lastAttemptAt) < cooldown { return false }
    lastAttemptAt = now
    return true
  }

  /// 取出排队的刷新请求（至多一次）。
  mutating func takePending() -> Bool {
    defer { isPending = false }
    return isPending
  }

  mutating func cancelPending() {
    isPending = false
  }

  mutating func reset() {
    lastAttemptAt = nil
    isPending = false
  }
}

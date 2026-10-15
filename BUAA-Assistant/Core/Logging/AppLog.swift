import OSLog

/// 统一记录诊断事件；凭据、票据和页面正文不得写入日志。
enum AppLog {
  static let auth = Logger(subsystem: "com.buaaassistant.app", category: "auth")
  static let network = Logger(subsystem: "com.buaaassistant.app", category: "network")
}

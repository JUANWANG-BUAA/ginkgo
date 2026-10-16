import OSLog

/// 统一记录诊断事件；凭据、票据和页面正文不得写入日志。
enum AppLog {
  static let auth = Logger(subsystem: "com.buaaassistant.app", category: "auth")
  static let network = Logger(subsystem: "com.buaaassistant.app", category: "network")
  static let storage = Logger(subsystem: "com.buaaassistant.app", category: "storage")

  static func cacheWriteFailed(feature: String, error: Error) {
    let failure = error as NSError
    storage.error(
      "cache write failed feature=\(feature, privacy: .public) error_domain=\(failure.domain, privacy: .public) error_code=\(failure.code)"
    )
  }

  static func operationFailed(feature: String, stage: String, error: Error) {
    let failure = error as NSError
    network.error(
      "operation failed feature=\(feature, privacy: .public) stage=\(stage, privacy: .public) error_domain=\(failure.domain, privacy: .public) error_code=\(failure.code)"
    )
  }

  static func responseFormatChanged(feature: String, stage: String) {
    network.error(
      "upstream response format changed feature=\(feature, privacy: .public) stage=\(stage, privacy: .public)"
    )
  }
}

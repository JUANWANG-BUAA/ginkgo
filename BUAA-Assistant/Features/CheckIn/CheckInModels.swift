import Foundation

enum CheckInStatus: String, Codable, Equatable {
  case notSigned
  case signed
  case unknown

  init(rawValue: Int?) {
    switch rawValue {
    case 0: self = .notSigned
    case 1: self = .signed
    default: self = .unknown
    }
  }
}

struct CheckInItem: Identifiable, Equatable, Codable {
  let id: String
  let courseName: String
  let beginsAt: String
  let endsAt: String
  let status: CheckInStatus
  let signInAllowed: Bool
  let mergedRecordCount: Int

  init(
    id: String,
    courseName: String,
    beginsAt: String,
    endsAt: String,
    status: CheckInStatus,
    signInAllowed: Bool = true,
    mergedRecordCount: Int = 1
  ) {
    self.id = id
    self.courseName = courseName
    self.beginsAt = beginsAt
    self.endsAt = endsAt
    self.status = status
    self.signInAllowed = signInAllowed
    self.mergedRecordCount = mergedRecordCount
  }
}

struct CheckInSnapshot: Equatable, Codable {
  let items: [CheckInItem]
  let fetchedAt: Date
  let schoolDate: String
}

struct CheckInActionResult: Equatable {
  let succeeded: Bool
  let message: String
  var requiresStatusRefresh = false
  var responseFormatUnrecognized = false
}

enum CheckInError: LocalizedError, Equatable {
  case sessionExpired
  case serviceSessionRejected
  case loginNameUnavailable
  case invalidResponse
  case unavailable
  case webVPNUnavailable

  var errorDescription: String? {
    switch self {
    case .sessionExpired: "学校会话已失效，请重新登录后刷新签到状态"
    case .serviceSessionRejected: "iclass 暂未确认签到状态；这不代表学校账号已退出。可稍后刷新；已保存登录凭据时也可重建签到会话"
    case .loginNameUnavailable: "iclass 认证信息暂不可用，请稍后重试"
    case .invalidResponse: "iclass 返回的数据格式发生变化，暂时无法确认状态"
    case .unavailable: "iclass 服务暂时不可用，当前状态未能确认"
    case .webVPNUnavailable: "iclass 未识别当前 WebVPN 登录态，签到状态未确认；请重新登录学校账号后重试"
    }
  }
}

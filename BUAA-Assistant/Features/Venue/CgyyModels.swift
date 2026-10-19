import Foundation

struct CgyyVenueSite: Codable, Equatable, Identifiable, Hashable {
  let id: Int
  let siteName: String
  let venueName: String
  let campusName: String
  let seatCount: Int?
  let reservationSpaceCount: Int?
  let siteTelephone: String?
  let openStartDate: String?
  let openEndDate: String?

  var displayName: String {
    [campusName, venueName, siteName].filter { !$0.isEmpty }.joined(separator: " · ")
  }
}

struct CgyyPurposeType: Codable, Equatable, Identifiable, Hashable {
  let id: Int
  let name: String
}

struct CgyyTimeSlot: Codable, Equatable, Identifiable, Hashable {
  let id: Int
  let beginTime: String
  let endTime: String

  var label: String { "\(beginTime)–\(endTime)" }
}

struct CgyySlotStatus: Codable, Equatable, Identifiable, Hashable {
  let timeID: Int
  let status: Int
  let isReservable: Bool
  let startDate: String?
  let endDate: String?
  let tradeNo: String?
  let orderID: Int?
  let useNum: Int?
  let alreadyNum: Int?
  let takeUp: Bool?
  let takeUpExplain: String?

  var id: Int { timeID }

  var statusText: String {
    if isReservable { return "可预约" }
    if let takeUpExplain, takeUpExplain.isEmpty == false { return takeUpExplain }
    if takeUp == true { return "已占用" }
    if tradeNo != nil || orderID != nil { return "已预约" }
    return "不可预约"
  }
}

struct CgyySpaceAvailability: Codable, Equatable, Identifiable, Hashable {
  let id: Int
  let name: String
  let venueSiteID: Int
  let groupID: Int?
  let slots: [CgyySlotStatus]

  var reservableSlots: [CgyySlotStatus] { slots.filter(\.isReservable) }
}

struct CgyyDayInfo: Codable, Equatable {
  let siteID: Int
  let date: String
  let availableDates: [String]
  let timeSlots: [CgyyTimeSlot]
  let spaces: [CgyySpaceAvailability]
  let reservationToken: String?
  let reservationTotalNum: Int?
}

struct CgyyOrderSelection: Codable, Hashable {
  let spaceID: Int
  let timeID: Int
  let groupID: Int?

  enum CodingKeys: String, CodingKey {
    case spaceID = "spaceId"
    case timeID = "timeId"
    case groupID = "venueSpaceGroupId"
  }
}

struct CgyyOrder: Codable, Equatable, Identifiable {
  let id: Int
  let tradeNo: String?
  let venueSiteID: Int?
  let reservationDate: String?
  let reservationDateDetail: String?
  let venueSpaceName: String?
  let campusName: String?
  let venueName: String?
  let siteName: String?
  let reservationStartDate: String?
  let reservationEndDate: String?
  let phone: String?
  let orderStatus: Int?
  let payStatus: Int?
  let checkStatus: Int?
  let theme: String?
  let purposeType: Int?
  let joinerNum: Int?
  let activityContent: String?
  let joiners: String?
  let checkContent: String?
  let handleReason: String?
  let remark: String?

  var displayTitle: String {
    [venueSpaceName, theme].compactMap { $0 }.first { !$0.isEmpty } ?? "研讨室预约"
  }

  var displayLocation: String {
    [campusName, venueName, siteName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
  }

  var displayTime: String {
    let date = reservationDate ?? ""
    let detail = reservationDateDetail ?? ""
    if detail.isEmpty == false { return [date, detail].filter { !$0.isEmpty }.joined(separator: " ") }
    if let start = reservationStartDate, let end = reservationEndDate {
      return "\(start) – \(end)"
    }
    return date.isEmpty ? "时间待确认" : date
  }

  var displayStatus: CgyyOrderStatus {
    if let checkStatus, checkStatus < 0 {
      return CgyyOrderStatus(title: CgyyOrderStatus.checkText(checkStatus), detail: CgyyOrderStatus.checkText(checkStatus), isError: true, isSuccess: false, canCancel: false)
    }
    if orderStatus == 2 {
      return CgyyOrderStatus(title: "已取消", detail: nil, isError: true, isSuccess: false, canCancel: false)
    }
    if orderStatus == 1, checkStatus == 1 {
      return CgyyOrderStatus(title: "审批通过", detail: "审批通过", isError: false, isSuccess: true, canCancel: true)
    }
    if orderStatus == 1, (checkStatus ?? 0) > 0 {
      return CgyyOrderStatus(title: "待审批", detail: CgyyOrderStatus.checkText(checkStatus), isError: false, isSuccess: false, canCancel: true)
    }
    if orderStatus == 3 {
      return CgyyOrderStatus(title: "占用", detail: nil, isError: false, isSuccess: false, canCancel: true)
    }
    if orderStatus == 1 {
      return CgyyOrderStatus(title: "正常", detail: nil, isError: false, isSuccess: true, canCancel: true)
    }
    return CgyyOrderStatus(
      title: orderStatus.map { "状态 \($0)" } ?? "状态待确认",
      detail: nil,
      isError: false,
      isSuccess: false,
      canCancel: false
    )
  }

  func canCancel(at date: Date = Date()) -> Bool {
    guard displayStatus.canCancel else { return false }
    guard let start = Self.date(from: reservationStartDate) else {
      return Self.date(from: reservationEndDate).map { $0 > date } ?? true
    }
    return date < start.addingTimeInterval(-4 * 60 * 60)
  }

  static func date(from raw: String?) -> Date? {
    guard let raw, raw.isEmpty == false else { return nil }
    return SchoolTime.date(from: raw.replacingOccurrences(of: "T", with: " "), formats: ["yyyy-MM-dd HH:mm:ss"])
  }
}

struct CgyyOrderStatus: Equatable {
  let title: String
  let detail: String?
  let isError: Bool
  let isSuccess: Bool
  let canCancel: Bool

  static func checkText(_ value: Int?) -> String {
    switch value {
    case 1: "审批通过"
    case 2: "待辅导员审批"
    case -2: "辅导员审批驳回"
    case 3: "待副书记/副处长审批"
    case -3: "副书记/副处长审批驳回"
    case 4: "待宣传部审批"
    case -4: "宣传部审批驳回"
    case 5: "待国交处备案"
    case -5: "国交处备案驳回"
    case 6: "待教务处审批"
    case -6: "教务处驳回"
    default: "待审批"
    }
  }
}

struct CgyyLockCodeInfo: Equatable {
  let qrCode: String?
  let dueDate: String?
  let tradeNo: String?
  let venueName: String?
  let siteName: String?
  let spaceName: String?
  let orderName: String?
  let reservationDate: String?
  let reservationDateDetail: String?
  let reservationStartDate: String?
  let reservationEndDate: String?

  var hasLockCode: Bool {
    guard let qrCode else { return false }
    return qrCode.isEmpty == false && qrCode != "null"
  }

  var hasUpcomingReservation: Bool {
    [tradeNo, reservationDate, reservationStartDate].contains { value in
      guard let value else { return false }
      return value.isEmpty == false && value != "null"
    }
  }

  var displayLocation: String {
    [venueName, siteName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
  }

  var displayTime: String {
    if let detail = reservationDateDetail, detail.isEmpty == false { return detail }
    if let start = reservationStartDate, let end = reservationEndDate { return "\(start) – \(end)" }
    return reservationDate ?? "时间待确认"
  }
}

struct CgyyCaptchaChallenge: Equatable {
  let secretKey: String
  let token: String
  let originalImageBase64: String
  let jigsawImageBase64: String
}

struct CgyyCaptchaSolution: Equatable {
  let offset: Int
  let pointJSON: String
}

enum CgyyError: LocalizedError {
  case authentication
  case uncertain
  case unavailable
  case invalidResponse(String)
  case upstream(String)
  case captcha(String)
  case operation(String)

  var errorDescription: String? {
    switch self {
    case .uncertain: "操作结果待核实，请先查看我的预约，勿重复提交。"
    case .authentication: "研讨室登录未完成：场馆列表可以浏览，查看可预约时段/预约需要学校 SSO。请重新登录学校账号后重试"
    case .unavailable: "研讨室系统暂时不可用，请稍后重试"
    case .invalidResponse(let stage): "研讨室系统返回结构无法识别：\(stage)"
    case .upstream(let message): message
    case .captcha(let message): "验证码处理失败：\(message)"
    case .operation(let message): message
    }
  }
}

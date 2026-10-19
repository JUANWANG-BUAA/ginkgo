import SwiftUI

/// 上游状态的展示口径（文案、图标、语义色）在两个平台保持一致，
/// 页面只负责排版，不再各自维护一份 switch。

extension CheckInStatus {
  var title: String {
    switch self {
    case .notSigned: "未签到"
    case .signed: "已签到"
    case .unknown: "待确认"
    }
  }

  var tint: Color {
    switch self {
    case .notSigned: .orange
    case .signed: .green
    case .unknown: .secondary
    }
  }

  var symbol: String {
    switch self {
    case .notSigned: "circle"
    case .signed: "checkmark.circle.fill"
    case .unknown: "questionmark.circle.fill"
    }
  }
}

extension HomeworkStatus {
  var title: String {
    switch self {
    case .pending: "待处理"
    case .submitted: "已提交"
    case .overdue: "已逾期"
    case .unknown: "待确认"
    }
  }

  var tint: Color {
    switch self {
    case .pending: .accentColor
    case .submitted: .green
    case .overdue: .orange
    case .unknown: .secondary
    }
  }

  var symbol: String {
    switch self {
    case .pending: "doc.text"
    case .submitted: "checkmark.circle.fill"
    case .overdue: "exclamationmark.circle.fill"
    case .unknown: "questionmark.circle.fill"
    }
  }
}

extension GraduateCourseProgressStatus {
  var tint: Color {
    switch self {
    case .completed: .green
    case .inProgress: .blue
    case .notPassed: .red
    case .needsReview: .orange
    case .remaining: .secondary
    }
  }
}

extension CgyyOrder {
  var statusTint: Color {
    if displayStatus.isError { return .orange }
    if displayStatus.isSuccess { return .green }
    return .accentColor
  }
}

import Foundation
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
  @Published private(set) var status: SMAppService.Status
  @Published private(set) var errorMessage: String?

  private let service: SMAppService

  init() {
    let service = SMAppService.mainApp
    self.service = service
    status = service.status
  }

  var isRegistered: Bool {
    status == .enabled || status == .requiresApproval
  }

  var requiresApproval: Bool {
    status == .requiresApproval
  }

  var statusDescription: String {
    switch status {
    case .enabled:
      "已启用"
    case .requiresApproval:
      "等待系统批准"
    case .notRegistered:
      "已关闭"
    case .notFound:
      "macOS 尚未找到此启动项"
    @unknown default:
      "启动项状态未知"
    }
  }

  func refresh() {
    status = service.status
  }

  func setEnabled(_ enabled: Bool) {
    errorMessage = nil
    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
      refresh()
    } catch {
      refresh()
      errorMessage = enabled
        ? "无法注册登录启动项：\(error.localizedDescription)"
        : "无法关闭登录启动项：\(error.localizedDescription)"
    }
  }

  func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}

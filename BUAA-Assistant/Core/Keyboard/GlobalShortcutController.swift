import AppKit
import Carbon
import Combine
import OSLog

private let globalShortcutSignature: OSType = 0x42554141
private let globalShortcutIdentifier: UInt32 = 1

private let globalShortcutEventHandler: EventHandlerProcPtr = { _, event, _ in
  var receivedID = EventHotKeyID()
  let status = GetEventParameter(
    event,
    EventParamName(kEventParamDirectObject),
    EventParamType(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &receivedID
  )

  guard status == noErr,
        receivedID.signature == globalShortcutSignature,
        receivedID.id == globalShortcutIdentifier else {
    return OSStatus(eventNotHandledErr)
  }

  Task { @MainActor in
    focusMainWindow()
  }
  return noErr
}

@MainActor
private func focusMainWindow() {
  NSApp.activate(ignoringOtherApps: true)
  guard let window = NSApp.windows.first(where: \.canBecomeMain) else { return }
  if window.isMiniaturized { window.deminiaturize(nil) }
  window.makeKeyAndOrderFront(nil)
}

/// Registers an optional system-wide shortcut. The shortcut is off by default and
/// can be toggled from the application's menu.
final class GlobalShortcutController: ObservableObject {
  private static let preferenceKey = "globalShortcutEnabled"

  @Published private(set) var isEnabled = false

  private var hotKey: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?
  private let logger = Logger(subsystem: "com.buaaassistant.app", category: "keyboard")

  init() {
    if UserDefaults.standard.bool(forKey: Self.preferenceKey) {
      setEnabled(true)
    }
  }

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else { return }

    if enabled {
      let status = registerShortcut()
      guard status == noErr else {
        UserDefaults.standard.set(false, forKey: Self.preferenceKey)
        logger.error("全局快捷键注册失败，状态码：\(status, privacy: .public)")
        return
      }
    } else {
      unregisterShortcut()
    }

    isEnabled = enabled
    UserDefaults.standard.set(enabled, forKey: Self.preferenceKey)
  }

  private func registerShortcut() -> OSStatus {
    if eventHandler == nil {
      var eventType = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard),
        eventKind: UInt32(kEventHotKeyPressed)
      )
      let handlerStatus = InstallEventHandler(
        GetApplicationEventTarget(),
        globalShortcutEventHandler,
        1,
        &eventType,
        nil,
        &eventHandler
      )
      guard handlerStatus == noErr else { return handlerStatus }
    }

    var registeredHotKey: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(kVK_ANSI_B),
      UInt32(controlKey | optionKey),
      EventHotKeyID(signature: globalShortcutSignature, id: globalShortcutIdentifier),
      GetApplicationEventTarget(),
      0,
      &registeredHotKey
    )
    if status == noErr {
      hotKey = registeredHotKey
    }
    return status
  }

  private func unregisterShortcut() {
    guard let hotKey else { return }
    let status = UnregisterEventHotKey(hotKey)
    if status != noErr {
      logger.error("全局快捷键注销失败，状态码：\(status, privacy: .public)")
    }
    self.hotKey = nil
  }

  deinit {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let eventHandler { RemoveEventHandler(eventHandler) }
  }
}

import Foundation
import Security

struct SavedCredential: Codable, Equatable {
  let username: String
  let password: String
}

protocol CredentialStore {
  func read() throws -> SavedCredential?
  func save(_ credential: SavedCredential) throws
  func delete() throws
}

enum KeychainError: LocalizedError {
  case unexpectedData
  case operationFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .unexpectedData: "钥匙串中的账号数据无法读取"
    case .operationFailed: "钥匙串操作失败，请检查系统设置"
    }
  }
}

/// 账号和密码保存在同一条设备专属钥匙串记录中；不写入 UserDefaults。
final class KeychainManager: CredentialStore {
  private let service: String
  private let account = "remembered-login"

  init(service: String = "com.buaaassistant.credentials") {
    self.service = service
  }

  func read() throws -> SavedCredential? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainError.operationFailed(status) }
    guard let data = result as? Data,
          let credential = try? JSONDecoder().decode(SavedCredential.self, from: data)
    else { throw KeychainError.unexpectedData }
    return credential
  }

  func save(_ credential: SavedCredential) throws {
    let data = try JSONEncoder().encode(credential)
    var attributes = baseQuery
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status = SecItemAdd(attributes as CFDictionary, nil)
    if status == errSecSuccess { return }
    guard status == errSecDuplicateItem else { throw KeychainError.operationFailed(status) }
    let update: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
    guard updateStatus == errSecSuccess else { throw KeychainError.operationFailed(updateStatus) }
  }

  func delete() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.operationFailed(status)
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}

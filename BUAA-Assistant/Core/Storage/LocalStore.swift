import CryptoKit
import Foundation

/// 本机查询快照统一保存在 `Application Support/BUAA-Assistant/<模块>/<名称>.json`。
/// 个人数据以账号的 SHA-256 摘要作文件名来隔离账号；摘要不是加密，内容仍是明文 JSON。
struct LocalStore: Sendable {
  let directory: URL

  /// `directory` 仅供测试注入临时目录。
  init(module: String, directory: URL? = nil) {
    self.directory = directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("BUAA-Assistant/\(module)", isDirectory: true)
  }

  static func accountKey(_ account: String) -> String {
    SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  /// 文件不存在返回 nil；内容无法解码（旧版本或已损坏）同样返回 nil，由调用方重新请求上游。
  func read<Value: Decodable>(_ type: Value.Type, name: String) -> Value? {
    guard let data = try? Data(contentsOf: file(name)) else { return nil }
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      AppLog.storage.notice("cache decode failed module=\(directory.lastPathComponent, privacy: .public)")
      return nil
    }
  }

  func write<Value: Encodable>(_ value: Value, name: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(value).write(to: file(name), options: .atomic)
  }

  func remove(name: String) throws {
    let target = file(name)
    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
  }

  func read<Value: Decodable>(_ type: Value.Type, account: String) -> Value? {
    read(type, name: Self.accountKey(account))
  }

  func write<Value: Encodable>(_ value: Value, account: String) throws {
    try write(value, name: Self.accountKey(account))
  }

  func remove(account: String) throws {
    try remove(name: Self.accountKey(account))
  }

  private func file(_ name: String) -> URL {
    directory.appendingPathComponent(name + ".json")
  }
}

/// 每个账号一份快照的缓存。读取在 actor 上执行，避免主线程做文件 IO；
/// 写入失败由调用方记日志并保留内存中的结果（失败刷新不覆盖旧缓存）。
actor SnapshotCache<Value: Codable & Sendable> {
  private let store: LocalStore

  init(module: String, directory: URL? = nil) {
    store = LocalStore(module: module, directory: directory)
  }

  func read(account: String) -> Value? {
    store.read(Value.self, account: account)
  }

  func save(_ value: Value, account: String) throws {
    try store.write(value, account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

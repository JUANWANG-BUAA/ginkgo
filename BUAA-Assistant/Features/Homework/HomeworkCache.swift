import CryptoKit
import Foundation

actor HomeworkCache {
  private let directory: URL

  init(directory: URL? = nil) {
    self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("BUAA-Assistant/Homework", isDirectory: true)
  }

  func read(account: String) -> HomeworkSnapshot? {
    guard let data = try? Data(contentsOf: file(for: account)) else { return nil }
    return try? JSONDecoder().decode(HomeworkSnapshot.self, from: data)
  }

  func save(_ snapshot: HomeworkSnapshot, account: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(snapshot).write(to: file(for: account), options: .atomic)
  }

  func clear(account: String) throws {
    let target = file(for: account)
    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
  }

  private func file(for account: String) -> URL {
    let digest = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(digest + ".json")
  }
}

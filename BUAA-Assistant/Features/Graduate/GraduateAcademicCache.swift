import Foundation

/// 研究生教务快照使用版本化信封：语义变化时提升版本号，旧版本快照不再读入，下次成功刷新覆盖。
actor GraduateAcademicCache {
  private struct Envelope: Codable {
    let version: Int
    let snapshot: GraduateAcademicSnapshot
  }

  private static let currentVersion = 2
  private let store: LocalStore

  init(directory: URL? = nil) {
    store = LocalStore(module: "GraduateAcademic", directory: directory)
  }

  func read(account: String) -> GraduateAcademicSnapshot? {
    guard let envelope = store.read(Envelope.self, account: account),
          envelope.version == Self.currentVersion else { return nil }
    return envelope.snapshot
  }

  func save(_ snapshot: GraduateAcademicSnapshot, account: String) throws {
    try store.write(Envelope(version: Self.currentVersion, snapshot: snapshot), account: account)
  }

  func clear(account: String) throws {
    try store.remove(account: account)
  }
}

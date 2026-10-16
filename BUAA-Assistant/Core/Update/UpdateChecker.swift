import Foundation

/// GitHub Release 的下载资产。
struct UpdateAsset: Decodable, Equatable {
  let name: String
  let browserDownloadURL: URL
  let size: Int

  enum CodingKeys: String, CodingKey {
    case name
    case browserDownloadURL = "browser_download_url"
    case size
  }
}

/// 一个可供更新的 Release。
struct UpdateRelease: Equatable {
  let tagName: String
  /// 去掉前缀 v 的版本号。
  let version: AppVersion
  let name: String
  let notes: String
  let pageURL: URL
  let dmg: UpdateAsset?
  let zip: UpdateAsset?
  let checksums: UpdateAsset?

  var displayVersion: String { version.description }

  init?(json: [String: Any]) {
    guard let tag = json["tag_name"] as? String,
          let version = AppVersion(tag),
          let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
    tagName = tag
    self.version = version
    name = json["name"] as? String ?? tag
    notes = json["body"] as? String ?? ""
    pageURL = page
    let assets = (json["assets"] as? [[String: Any]] ?? []).compactMap { asset -> UpdateAsset? in
      guard let name = asset["name"] as? String,
            let url = (asset["browser_download_url"] as? String).flatMap(URL.init(string:)) else { return nil }
      return UpdateAsset(name: name, browserDownloadURL: url, size: asset["size"] as? Int ?? 0)
    }
    dmg = assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    zip = assets.first { $0.name.lowercased().hasSuffix(".zip") }
    checksums = assets.first { $0.name.lowercased() == "checksums.txt" }
  }
}

enum UpdateError: LocalizedError {
  case unavailable
  case rateLimited
  case installLocationNotWritable(String)
  case noInstallableAsset
  case verificationFailed
  case installFailed(String)

  var errorDescription: String? {
    switch self {
    case .unavailable: return "无法连接 GitHub，请稍后再试"
    case .rateLimited: return "GitHub 接口访问过于频繁，请稍后再试"
    case .installLocationNotWritable(let path): return "当前应用位置不可写入，无法自动更新：\(path)"
    case .noInstallableAsset: return "该版本没有可自动安装的 zip 包，请在发布页手动下载"
    case .verificationFailed: return "更新包校验失败，已取消安装"
    case .installFailed(let reason): return "自动更新失败：\(reason)"
    }
  }
}

/// 读取本仓库 GitHub Releases，判断是否有比当前版本更新的发布。
struct UpdateChecker {
  let session: URLSession
  static let repository = "JUANWANG-BUAA/ginkgo"

  init(session: URLSession = APIClient.shared.session) { self.session = session }

  /// 返回最新的、比 `current` 更新的 Release；没有更新返回 nil。
  func availableUpdate(current: AppVersion) async throws -> UpdateRelease? {
    var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases?per_page=10")!)
    request.timeoutInterval = 20
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("Ginkgo/\(current.description) (macOS)", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw UpdateError.unavailable }
    if http.statusCode == 403 || http.statusCode == 429 { throw UpdateError.rateLimited }
    guard (200..<300).contains(http.statusCode) else { throw UpdateError.unavailable }
    guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      throw UpdateError.unavailable
    }
    let releases = list
      .filter { ($0["draft"] as? Bool) != true }
      .compactMap(UpdateRelease.init(json:))
      .sorted { $0.version > $1.version }
    guard let latest = releases.first, latest.version > current else { return nil }
    return latest
  }
}

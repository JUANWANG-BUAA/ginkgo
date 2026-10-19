import CryptoKit
import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)
/// 报告下载进度（URLSessionDownloadDelegate 的回调在会话队列上触发，用闭包回传主线程）。
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  private let onProgress: @Sendable (Double) -> Void

  init(onProgress: @escaping @Sendable (Double) -> Void) { self.onProgress = onProgress }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {}

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    onProgress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
  }
}
#endif

/// 应用内更新中心：从 GitHub Releases 检查新版本、提示并就地安装。
///
/// 设计约束：
/// - 只读取本仓库的公开 Releases，不发送任何账号或使用数据；
/// - 安装新版本只替换应用包本身，不触碰 Application Support / Keychain / UserDefaults，
///   因此课表、成绩、作业缓存与本机待办都会保留；
/// - 自动检查每天最多一次，手动检查不受限制；失败只影响本次提示，不改变应用状态。
@MainActor
final class UpdateCenter: ObservableObject {
  enum Phase: Equatable {
    case idle
    case checking
    case downloading
    case installing
    case failed(String)
  }

  @Published private(set) var phase: Phase = .idle
  @Published private(set) var latest: UpdateRelease?
  @Published private(set) var statusMessage: String?
  @Published private(set) var lastCheckedAt: Date?
  @Published private(set) var downloadProgress: Double?

  /// 更新包下载源。国内直连 GitHub 资产常被限速，默认优先镜像并可自动回退。
  enum DownloadSource: String, CaseIterable {
    case automatic, direct, mirror

    var title: String {
      switch self {
      case .automatic: return "自动（优先镜像）"
      case .direct: return "直连 GitHub"
      case .mirror: return "镜像 gh-proxy"
      }
    }
  }

  static let downloadSourceKey = "update.downloadSource"

  /// 根据设置生成候选下载地址（可测试）。
  static func downloadSourceURLs(for assetURL: URL, source: DownloadSource) -> [URL] {
    let absolute = assetURL.absoluteString
    let mirrors = ["https://gh-proxy.com/", "https://ghproxy.net/"].compactMap { URL(string: $0 + absolute) }
    switch source {
    case .direct: return [assetURL]
    case .mirror: return mirrors
    case .automatic: return mirrors + [assetURL]
    }
  }

  let currentVersion: AppVersion
  private let checker: UpdateChecker
  private let defaults: UserDefaults
  private let session: URLSession
  private static let autoCheckKey = "update.lastAutoCheckAt"

  init(
    checker: UpdateChecker = UpdateChecker(),
    session: URLSession = APIClient.shared.session,
    defaults: UserDefaults = .standard
  ) {
    self.checker = checker
    self.session = session
    self.defaults = defaults
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    currentVersion = AppVersion(short) ?? AppVersion("0.1.0")!
  }

  var currentVersionDescription: String { currentVersion.description }
  var updateAvailable: Bool { latest != nil }
  var isBusy: Bool { phase == .checking || phase == .downloading || phase == .installing }
  var hasError: Bool { if case .failed = phase { return true }; return false }

  private var ignoredTag: String? { defaults.string(forKey: Self.ignoredTagKey) }
  static let ignoredTagKey = "update.ignoredTag"

  /// 被用户忽略的版本不再提示；更新的版本仍会正常提示（可测试）。
  static func shouldOffer(release: UpdateRelease, ignoredTag: String?) -> Bool {
    release.tagName != ignoredTag
  }

  /// 忽略当前提示的版本，保留手动检查与发布页入口。
  func ignoreCurrent() {
    guard let release = latest else { return }
    defaults.set(release.tagName, forKey: Self.ignoredTagKey)
    latest = nil
    statusMessage = "已忽略 \(release.displayVersion)；有新版本时会再次提示"
  }

  /// 检查更新；`manual` 为 true 时即使无更新也会给出“已是最新”的反馈。
  func check(manual: Bool) async {
    guard !isBusy else { return }
    phase = .checking
    statusMessage = manual ? nil : statusMessage
    defer {
      lastCheckedAt = Date()
      if phase == .checking { phase = .idle }
    }
    do {
      let found = try await checker.availableUpdate(current: currentVersion)
      if let found, !Self.shouldOffer(release: found, ignoredTag: ignoredTag) {
        latest = nil
        if manual { statusMessage = "已是最新版本（\(found.displayVersion) 已忽略，可在发布页手动下载）" }
      } else if let found {
        latest = found
        statusMessage = "发现新版本 \(found.displayVersion)"
      } else {
        latest = nil
        if manual { statusMessage = "已是最新版本" }
      }
    } catch {
      AppLog.network.error("检查更新失败：\(error.localizedDescription, privacy: .private)")
      statusMessage = error.localizedDescription
      if manual { phase = .failed(error.localizedDescription) }
    }
  }

  /// 启动后自动检查：每天最多一次。
  func autoCheckIfDue() async {
    let last = defaults.object(forKey: Self.autoCheckKey) as? Date ?? .distantPast
    guard Date().timeIntervalSince(last) >= 24 * 3600 else { return }
    defaults.set(Date(), forKey: Self.autoCheckKey)
    await check(manual: false)
  }

#if os(macOS)
  func openReleasePage(_ release: UpdateRelease? = nil) {
    let url = (release ?? latest)?.pageURL
      ?? URL(string: "https://github.com/\(UpdateChecker.repository)/releases")!
    NSWorkspace.shared.open(url)
  }

  /// 下载 zip 更新包、校验（如发布页提供 checksums.txt）、替换应用包并重启。
  func install() async {
    guard let release = latest, !isBusy else { return }
    guard let zip = release.zip else {
      statusMessage = UpdateError.noInstallableAsset.errorDescription
      phase = .failed(UpdateError.noInstallableAsset.errorDescription ?? "")
      return
    }
    phase = .downloading
    downloadProgress = nil
    statusMessage = "正在下载 \(release.displayVersion)…"
    do {
      let archive = try await download(zip, version: release.displayVersion)
      // 校验和可用时严格比对（不匹配则中止）；取不到校验和时只记录，不阻断安装。
      if let expected = await expectedChecksum(for: zip.name, in: release.checksums) {
        guard try sha256(of: archive) == expected else { throw UpdateError.verificationFailed }
      }
      phase = .installing
      downloadProgress = nil
      statusMessage = "正在安装，完成后会自动重启…"
      try await swapAndRelaunch(archive: archive)
    } catch {
      AppLog.network.error("自动更新失败 domain=\((error as NSError).domain, privacy: .public) code=\((error as NSError).code) message=\(error.localizedDescription, privacy: .private)")
      phase = .failed(error.localizedDescription)
      downloadProgress = nil
      statusMessage = error.localizedDescription
    }
  }

  // MARK: - 下载与校验

  /// 按设置依次尝试镜像与直连；先成功的源生效。
  private func download(_ asset: UpdateAsset, version: String) async throws -> URL {
    let source = DownloadSource(rawValue: defaults.string(forKey: Self.downloadSourceKey) ?? "") ?? .automatic
    let sources = Self.downloadSourceURLs(for: asset.browserDownloadURL, source: source)
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("ginkgo-update-\(UUID().uuidString)-\(asset.name)")
    var lastError: Error?
    for (index, url) in sources.enumerated() {
      do {
        return try await download(from: url, to: destination, version: version, attempt: index + 1, total: sources.count)
      } catch {
        lastError = error
        AppLog.network.error("更新下载源失败（\(index + 1)/\(sources.count)）：\(error.localizedDescription, privacy: .private)")
      }
    }
    throw lastError ?? UpdateError.unavailable
  }

  private func download(from url: URL, to destination: URL, version: String, attempt: Int, total: Int) async throws -> URL {
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    request.setValue("Ginkgo/\(currentVersion.description) (macOS)", forHTTPHeaderField: "User-Agent")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    // 直连允许更长时间（可能很慢）；镜像若 90 秒仍无结果就换下一个源。
    configuration.timeoutIntervalForResource = url.host?.contains("github") == true ? 900 : 90
    let delegate = DownloadProgressDelegate { [weak self] fraction in
      Task { @MainActor [weak self] in
        self?.downloadProgress = fraction
        let prefix = total > 1 ? "第 \(attempt)/\(total) 个源 · " : ""
        self?.statusMessage = "\(prefix)正在下载 \(version)… \(Int(fraction * 100))%"
      }
    }
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    let (file, response) = try await session.download(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw UpdateError.unavailable
    }
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.moveItem(at: file, to: destination)
    return destination
  }

  /// 读取发布页的 checksums.txt（同样走镜像回退）；取不到时返回 nil，由调用方决定是否继续。
  private func expectedChecksum(for assetName: String, in checksums: UpdateAsset?) async -> String? {
    guard let checksums else { return nil }
    let source = DownloadSource(rawValue: defaults.string(forKey: Self.downloadSourceKey) ?? "") ?? .automatic
    for url in Self.downloadSourceURLs(for: checksums.browserDownloadURL, source: source) {
      var request = URLRequest(url: url)
      request.timeoutInterval = 45
      request.setValue("Ginkgo/\(currentVersion.description) (macOS)", forHTTPHeaderField: "User-Agent")
      do {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let text = String(data: data, encoding: .utf8) else { continue }
        if let checksum = Self.parseChecksum(assetName: assetName, text: text) { return checksum }
      } catch {
        AppLog.network.error("获取校验和失败 domain=\((error as NSError).domain, privacy: .public) code=\((error as NSError).code)")
      }
    }
    return nil
  }

#endif

  /// 从 `sha256  filename` 格式的文本中取出指定文件的校验和（可测试）。
  static func parseChecksum(assetName: String, text: String) -> String? {
    for line in text.split(separator: "\n") {
      let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
      guard parts.count >= 2 else { continue }
      let file = parts.last!.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
      if file == assetName, parts[0].count == 64 { return parts[0].lowercased() }
    }
    return nil
  }

#if os(macOS)
  private func sha256(of file: URL) throws -> String {
    let data = try Data(contentsOf: file, options: .mappedIfSafe)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - 就地安装

  private func swapAndRelaunch(archive: URL) async throws {
    let fileManager = FileManager.default
    let workDir = fileManager.temporaryDirectory
      .appendingPathComponent("ginkgo-update-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)

    let unzip = Process()
    unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    unzip.arguments = ["-x", "-k", archive.path, workDir.path]
    try unzip.run()
    unzip.waitUntilExit()
    guard unzip.terminationStatus == 0 else { throw UpdateError.installFailed("解压失败") }
    try? fileManager.removeItem(at: archive)

    guard let newApp = try fileManager.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
      .first(where: { $0.pathExtension == "app" }) else {
      throw UpdateError.installFailed("更新包中没有找到应用")
    }
    let plist = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
    guard plist?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier else {
      throw UpdateError.verificationFailed
    }

    let target = Bundle.main.bundleURL
    let parent = target.deletingLastPathComponent()
    guard fileManager.isWritableFile(atPath: parent.path) else {
      throw UpdateError.installLocationNotWritable(parent.path)
    }

    // 用一段短脚本在应用退出后替换应用包并重启；不触碰任何缓存目录。
    let script = workDir.appendingPathComponent("update.sh")
    let pid = ProcessInfo.processInfo.processIdentifier
    let body = """
    #!/bin/sh
    while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.3; done
    /bin/rm -rf "\(target.path)"
    /usr/bin/ditto "\(newApp.path)" "\(target.path)"
    /usr/bin/xattr -dr com.apple.quarantine "\(target.path)" 2>/dev/null
    /usr/bin/open "\(target.path)"
    /bin/rm -rf "\(workDir.path)"
    """
    try body.write(to: script, atomically: true, encoding: .utf8)
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

    let runner = Process()
    runner.executableURL = URL(fileURLWithPath: "/bin/sh")
    runner.arguments = [script.path]
    try runner.run()

    statusMessage = "正在重启完成更新；课表、成绩缓存与本机待办都会保留。"
    try? await Task.sleep(nanoseconds: 900_000_000)
    NSApplication.shared.terminate(nil)
  }
#endif
}

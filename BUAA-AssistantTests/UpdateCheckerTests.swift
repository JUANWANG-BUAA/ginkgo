import Foundation
import XCTest
@testable import BUAA_Assistant

final class AppVersionTests: XCTestCase {
  func testParsesTagsWithPrefixAndPrerelease() {
    XCTAssertEqual(AppVersion("v0.1.0-alpha.2")?.description, "0.1.0-alpha.2")
    XCTAssertEqual(AppVersion("1.2")?.description, "1.2.0")
    XCTAssertEqual(AppVersion("0.1.0")?.prerelease, [])
    XCTAssertNil(AppVersion("main"))
  }

  func testSemanticOrdering() {
    XCTAssertLessThan(AppVersion("0.1.0-alpha.1")!, AppVersion("0.1.0-alpha.2")!)
    XCTAssertLessThan(AppVersion("0.1.0-alpha.2")!, AppVersion("0.1.0")!)
    XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.1.1")!)
    XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.2.0")!)
    XCTAssertGreaterThan(AppVersion("v1.0.0")!, AppVersion("0.9.9")!)
    XCTAssertEqual(AppVersion("v0.1.0-alpha.2"), AppVersion("0.1.0-alpha.2"))
  }
}

final class UpdateCheckerTests: XCTestCase {
  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [UpdateMockURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private let releasesJSON = """
  [
    {
      "tag_name": "v0.1.0-alpha.3",
      "name": "Ginkgo v0.1.0-alpha.3",
      "draft": false,
      "prerelease": false,
      "html_url": "https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/v0.1.0-alpha.3",
      "body": "更新说明",
      "assets": [
        {"name": "Ginkgo-v0.1.0-alpha.3.zip", "browser_download_url": "https://example.com/g.zip", "size": 100},
        {"name": "Ginkgo-v0.1.0-alpha.3.dmg", "browser_download_url": "https://example.com/g.dmg", "size": 200},
        {"name": "checksums.txt", "browser_download_url": "https://example.com/checksums.txt", "size": 10}
      ]
    },
    {
      "tag_name": "v0.9.9-alpha.1",
      "name": "Draft 更高版本",
      "draft": true,
      "prerelease": false,
      "html_url": "https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/v0.9.9-alpha.1",
      "body": "",
      "assets": []
    },
    {
      "tag_name": "v0.1.0-alpha.2",
      "name": "阿旧版本",
      "draft": false,
      "prerelease": true,
      "html_url": "https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/v0.1.0-alpha.2",
      "body": "",
      "assets": []
    }
  ]
  """

  func testFindsNewerReleaseAndParsesAssets() async throws {
    UpdateMockURLProtocol.handler = { _ in (200, [:], Data(self.releasesJSON.utf8)) }
    defer { UpdateMockURLProtocol.handler = nil }
    let checker = UpdateChecker(session: makeSession())

    let release = try await checker.availableUpdate(current: AppVersion("0.1.0-alpha.2")!)
    let found = try XCTUnwrap(release)
    XCTAssertEqual(found.displayVersion, "0.1.0-alpha.3")
    XCTAssertEqual(found.zip?.name, "Ginkgo-v0.1.0-alpha.3.zip")
    XCTAssertEqual(found.dmg?.name, "Ginkgo-v0.1.0-alpha.3.dmg")
    XCTAssertEqual(found.checksums?.name, "checksums.txt")
  }

  func testIgnoresDraftsAndOlderReleases() async throws {
    UpdateMockURLProtocol.handler = { _ in (200, [:], Data(self.releasesJSON.utf8)) }
    defer { UpdateMockURLProtocol.handler = nil }
    let checker = UpdateChecker(session: makeSession())

    let newerThanLatest = try await checker.availableUpdate(current: AppVersion("0.1.0-alpha.3")!)
    XCTAssertNil(newerThanLatest)
    let stableCurrent = try await checker.availableUpdate(current: AppVersion("0.1.0")!)
    XCTAssertNil(stableCurrent)
  }

  func testRateLimitIsReported() async {
    UpdateMockURLProtocol.handler = { _ in (403, [:], Data()) }
    defer { UpdateMockURLProtocol.handler = nil }
    let checker = UpdateChecker(session: makeSession())

    do {
      _ = try await checker.availableUpdate(current: AppVersion("0.1.0-alpha.1")!)
      XCTFail("应该抛出限流错误")
    } catch let error as UpdateError {
      guard case .rateLimited = error else { return XCTFail("错误类型：\(error)") }
    } catch {
      XCTFail("意外错误：\(error)")
    }
  }
}

@MainActor
final class UpdateDownloadSourceTests: XCTestCase {
  func testDownloadSourceFallbackOrder() throws {
    let url = try XCTUnwrap(URL(string: "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/v1/Ginkgo.zip"))
    XCTAssertEqual(UpdateCenter.downloadSourceURLs(for: url, source: .direct), [url])

    let mirrors = UpdateCenter.downloadSourceURLs(for: url, source: .mirror)
    XCTAssertEqual(mirrors.count, 2)
    XCTAssertTrue(mirrors.allSatisfy { $0.absoluteString.contains("gh-proxy.com/") || $0.absoluteString.contains("ghproxy.net/") })

    let automatic = UpdateCenter.downloadSourceURLs(for: url, source: .automatic)
    XCTAssertEqual(automatic.count, 3)
    XCTAssertEqual(automatic.last, url)
  }

  func testIgnoredReleaseIsNotOffered() throws {
    let json: [String: Any] = [
      "tag_name": "v0.1.0-alpha.3",
      "name": "Ginkgo v0.1.0-alpha.3",
      "html_url": "https://example.com/release",
      "body": "",
      "draft": false,
      "assets": []
    ]
    let release = try XCTUnwrap(UpdateRelease(json: json))
    XCTAssertTrue(UpdateCenter.shouldOffer(release: release, ignoredTag: nil))
    XCTAssertFalse(UpdateCenter.shouldOffer(release: release, ignoredTag: "v0.1.0-alpha.3"))
    XCTAssertTrue(UpdateCenter.shouldOffer(release: release, ignoredTag: "v0.1.0-alpha.2"))
  }

  func testParsesChecksumFile() {
    let text = """
    bb6323128df41a6d806b63e1d6151134a9196aaaf8addfcb86f75eee4c15bdca  Ginkgo-v0.1.0-alpha.2.dmg
    deeb9ee18a1ac55d67582a0cdc82b2e6e645a32dae781ae6e2f13ded4ba95532  Ginkgo-v0.1.0-alpha.2.zip
    """
    XCTAssertEqual(UpdateCenter.parseChecksum(assetName: "Ginkgo-v0.1.0-alpha.2.zip", text: text),
                   "deeb9ee18a1ac55d67582a0cdc82b2e6e645a32dae781ae6e2f13ded4ba95532")
    XCTAssertNil(UpdateCenter.parseChecksum(assetName: "other.zip", text: text))
  }
}

private final class UpdateMockURLProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, [String: String], Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let (status, headers, data) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

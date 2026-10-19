import Foundation
import XCTest
@testable import BUAA_Assistant

final class UpstreamRouteTests: XCTestCase {
  func testCampusHostsUseWebVPNButGatewayDoesNotGetDoubleWrapped() throws {
    let ucURL = try XCTUnwrap(URL(string: "https://uc.buaa.edu.cn/api/uc/status"))
    let byxtURL = try XCTUnwrap(URL(string: "https://byxt.buaa.edu.cn/jwapp/"))
    let rootURL = try XCTUnwrap(URL(string: "https://buaa.edu.cn/"))
    let gatewayURL = try XCTUnwrap(URL(string: "https://d.buaa.edu.cn/login"))
    let githubURL = try XCTUnwrap(URL(string: "https://github.com/JUANWANG-BUAA/ginkgo"))

    XCTAssertTrue(UpstreamRequestRouting.shouldUseWebVPN(ucURL))
    XCTAssertTrue(UpstreamRequestRouting.shouldUseWebVPN(byxtURL))
    XCTAssertTrue(UpstreamRequestRouting.shouldUseWebVPN(rootURL))
    XCTAssertFalse(UpstreamRequestRouting.shouldUseWebVPN(gatewayURL))
    XCTAssertFalse(UpstreamRequestRouting.shouldUseWebVPN(githubURL))
  }

  func testWebVPNRouteWrapsURLAndBrowserHeadersAndStripsDirectCookie() throws {
    let upstream = try XCTUnwrap(URL(string: "https://spoc.buaa.edu.cn/spocnewht/inco/ht/queryOne"))
    var request = URLRequest(url: upstream)
    request.setValue("https://spoc.buaa.edu.cn/pjxt/", forHTTPHeaderField: "Referer")
    request.setValue("https://spoc.buaa.edu.cn", forHTTPHeaderField: "Origin")
    request.setValue("CASTGC=must-not-leak", forHTTPHeaderField: "Cookie")
    let payload = Data(#"{"token":"fixture"}"#.utf8)
    request.httpBody = payload

    let routed = try UpstreamRequestRouting.route(request, using: .webVPN)
    let routedURL = try XCTUnwrap(routed.url)
    XCTAssertEqual(routedURL.host, "d.buaa.edu.cn")
    XCTAssertEqual(WebVPNRouter.unwrap(routedURL), upstream)
    XCTAssertEqual(routed.httpBody, payload)
    XCTAssertNil(routed.value(forHTTPHeaderField: "Cookie"))

    let referer = try XCTUnwrap(routed.value(forHTTPHeaderField: "Referer").flatMap(URL.init(string:)))
    let origin = try XCTUnwrap(routed.value(forHTTPHeaderField: "Origin").flatMap(URL.init(string:)))
    XCTAssertEqual(referer.host, "d.buaa.edu.cn")
    XCTAssertEqual(origin.host, "d.buaa.edu.cn")
  }

  func testDirectRouteKeepsRequestUntouched() throws {
    let upstream = try XCTUnwrap(URL(string: "https://uc.buaa.edu.cn/api/uc/status"))
    var request = URLRequest(url: upstream)
    request.setValue("CASTGC=direct-cookie", forHTTPHeaderField: "Cookie")

    let routed = try UpstreamRequestRouting.route(request, using: .direct)
    XCTAssertEqual(routed.url, upstream)
    XCTAssertEqual(routed.value(forHTTPHeaderField: "Cookie"), "CASTGC=direct-cookie")
  }

  func testAutomaticFallbackSwitchesToWebVPNOnlyOnce() throws {
    let suiteName = "UpstreamRouteTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(UpstreamRoutePreference.automatic.rawValue, forKey: UpstreamRoutePreference.storageKey)

    XCTAssertTrue(UpstreamRoutePreference.activateAutomaticWebVPNFallback(in: defaults))
    XCTAssertEqual(UpstreamRoutePreference.current(in: defaults), .webVPN)
    XCTAssertFalse(UpstreamRoutePreference.activateAutomaticWebVPNFallback(in: defaults))
  }

  func testGatewayRelativeRedirectResolvesToUpstreamURL() throws {
    let upstream = try XCTUnwrap(URL(string: "https://uc.buaa.edu.cn/api/uc/status?x=1"))
    let wrapped = try WebVPNRouter.wrap(upstream)
    let location = wrapped.path + (wrapped.query.map { "?" + $0 } ?? "")
    let resolved = try XCTUnwrap(WebVPNRouter.resolveRedirect(location, relativeTo: upstream))
    XCTAssertEqual(WebVPNRouter.unwrap(resolved), upstream)
  }
}

import Foundation

protocol CookieClearing {
  func clearAll()
}

struct AppCookieStore: CookieClearing {
  func clearAll() {
    for cookie in HTTPCookieStorage.shared.cookies ?? [] {
      HTTPCookieStorage.shared.deleteCookie(cookie)
    }
    let webVPNStorage = APIClient.shared.webVPNCookieStorage
    for cookie in webVPNStorage.cookies ?? [] {
      webVPNStorage.deleteCookie(cookie)
    }
  }
}

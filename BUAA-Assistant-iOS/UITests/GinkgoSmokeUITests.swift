import XCTest

final class GinkgoSmokeUITests: XCTestCase {
  private var app = XCUIApplication()

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
  }

  func testLoginScreenSupportsBasicInput() throws {
    app.launchEnvironment["GINKGO_UI_TESTING"] = "1"
    app.launchEnvironment["GINKGO_DEMO_MODE"] = "0"
    app.launch()
    XCTAssertTrue(app.staticTexts["Ginkgo"].waitForExistence(timeout: 12))

    let username = app.textFields["login-username"]
    XCTAssertTrue(username.waitForExistence(timeout: 8))
    username.tap()
    username.typeText("sy2501001")

    let password = app.secureTextFields["login-password"]
    XCTAssertTrue(password.exists)
    password.tap()
    password.typeText("ui-test-placeholder")

    let login = app.buttons["login-button"]
    XCTAssertTrue(login.exists)
    XCTAssertTrue(login.isEnabled)

    attachScreenshot(named: "iOS login screen")
  }

  func testAuthenticatedShellIsReachable() throws {
    app.launchEnvironment["GINKGO_DEMO_MODE"] = "1"
    app.launch()

    XCTAssertTrue(app.navigationBars["今天"].waitForExistence(timeout: 15))

    let demoSuccessToast = app.staticTexts["学校会话已验证，登录成功"]
    if demoSuccessToast.waitForExistence(timeout: 2) {
      _ = demoSuccessToast.waitForNonExistence(timeout: 10)
    }

    attachScreenshot(named: "iOS today")

    let tabBar = app.tabBars.firstMatch
    if tabBar.exists {
      for title in ["课表", "作业", "图书馆", "更多"] {
        XCTAssertTrue(tabBar.buttons[title].exists, "缺少主 Tab：\(title)")
      }

      tabBar.buttons["课表"].tap()
      XCTAssertTrue(app.navigationBars["课表"].waitForExistence(timeout: 8))
      attachScreenshot(named: "iOS schedule")

      tabBar.buttons["作业"].tap()
      XCTAssertTrue(app.navigationBars["学校作业"].waitForExistence(timeout: 8))
      attachScreenshot(named: "iOS homework")

      tabBar.buttons["图书馆"].tap()
      XCTAssertTrue(app.navigationBars["图书馆"].waitForExistence(timeout: 8))
      attachScreenshot(named: "iOS library")

      tabBar.buttons["更多"].tap()
      XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 8))
      attachScreenshot(named: "iOS more")
    } else if app.staticTexts["工作台"].waitForExistence(timeout: 4) {
      openSidebarItem("课表", heading: "课表", screenshotName: "iOS schedule")
      openSidebarItem("研究生教务", heading: "研究生教务", screenshotName: "iOS graduate academic")
      openSidebarItem("博雅", heading: "博雅", screenshotName: "iOS bykc")
      openSidebarItem("学校作业", heading: "学校作业", screenshotName: "iOS homework")
      openSidebarItem("图书馆", heading: "图书馆", screenshotName: "iOS library")
      openSidebarItem("研讨室", heading: "研讨室", screenshotName: "iOS seminar")
      openSidebarItem("成绩", heading: "成绩", screenshotName: "iOS grades")
      openSidebarItem("空教室", heading: "空教室", screenshotName: "iOS classroom")
      openSidebarItem("待办", heading: "待办", screenshotName: "iOS tasks")
      openSidebarItem("设置", heading: "设置", screenshotName: "iOS settings")
    } else {
      openAdaptiveTab("课表", heading: "课表", screenshotName: "iOS schedule")
      openAdaptiveTab("作业", heading: "学校作业", screenshotName: "iOS homework")
      openAdaptiveTab("图书馆", heading: "图书馆", screenshotName: "iOS library")
      openAdaptiveTab("更多", heading: "更多", screenshotName: "iOS more")
    }

    if app.navigationBars["更多"].exists {
      openMoreItem("研究生教务", heading: "研究生教务", screenshotName: "iOS graduate academic")
      openMoreItem("博雅", heading: "博雅", screenshotName: "iOS bykc")
      openMoreItem("成绩", heading: "成绩", screenshotName: "iOS grades")
      openMoreItem("研讨室", heading: "研讨室", screenshotName: "iOS seminar")
      openMoreItem("空教室", heading: "空教室", screenshotName: "iOS classroom")
      openMoreItem("待办", heading: "待办", screenshotName: "iOS tasks")
      openMoreItem("设置", heading: "设置", screenshotName: "iOS settings")
    }
  }

  private func openSidebarItem(_ title: String, heading: String, screenshotName: String) {
    let cell = app.cells.containing(.staticText, identifier: title).firstMatch
    let button = app.buttons[title].firstMatch
    let label = app.staticTexts[title].firstMatch
    let item = cell.exists ? cell : (button.exists ? button : label)
    XCTAssertTrue(item.waitForExistence(timeout: 8), "侧栏缺少入口：\(title)")
    item.tap()
    let navigationTitle = app.navigationBars[heading]
    let pageTitle = app.staticTexts[heading].firstMatch
    XCTAssertTrue(
      navigationTitle.waitForExistence(timeout: 8) || pageTitle.waitForExistence(timeout: 2),
      "\(title)页面未显示标题"
    )
    attachScreenshot(named: screenshotName)
  }

  private func openAdaptiveTab(_ title: String, heading: String, screenshotName: String) {
    let item = app.buttons[title].firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 8), "宽屏自适应 Tab 栏缺少入口：\(title)")
    item.tap()
    XCTAssertTrue(app.navigationBars[heading].waitForExistence(timeout: 8), "\(title)页面未显示导航标题")
    attachScreenshot(named: screenshotName)
  }

  /// Run only when a maintainer explicitly supplies live credentials in the
  /// test process environment. Credentials are never written to the repository.
  func testLiveSessionWhenCredentialsProvided() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let username = environment["GINKGO_LIVE_USERNAME"],
          let password = environment["GINKGO_LIVE_PASSWORD"],
          username.isEmpty == false,
          password.isEmpty == false else {
      throw XCTSkip("未提供 GINKGO_LIVE_USERNAME / GINKGO_LIVE_PASSWORD，跳过真实账号验收")
    }

    let liveApp = XCUIApplication()
    liveApp.launchEnvironment["GINKGO_UI_TESTING"] = "1"
    liveApp.launchEnvironment["GINKGO_DEMO_MODE"] = "0"
    liveApp.launch()

    let usernameField = liveApp.textFields["login-username"]
    XCTAssertTrue(usernameField.waitForExistence(timeout: 15))
    usernameField.tap()
    usernameField.typeText(username)

    let passwordField = liveApp.secureTextFields["login-password"]
    XCTAssertTrue(passwordField.exists)
    passwordField.tap()
    passwordField.typeText(password)

    let login = liveApp.buttons["login-button"]
    XCTAssertTrue(login.exists)
    XCTAssertTrue(login.isEnabled)
    login.tap()

    let authenticated = liveApp.navigationBars["今天"].waitForExistence(timeout: 60)
      || liveApp.tabBars.firstMatch.waitForExistence(timeout: 5)
    let attachment = XCTAttachment(screenshot: liveApp.screenshot())
    attachment.name = authenticated ? "Live session verified" : "Live session login result"
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertTrue(authenticated, "真实账号登录后未进入工作台，请检查验证码、密码或上游状态")
    if authenticated {
      verifyLiveDataScreens(liveApp)
    }
  }

  private func verifyLiveDataScreens(_ app: XCUIApplication) {
    let tabBar = app.tabBars.firstMatch
    if tabBar.exists {
      tabBar.buttons["更多"].tap()
    }

    openLiveItem(app, title: "博雅", heading: "博雅", marker: "课程库", screenshotName: "Live BYKC courses")
    openLiveItem(app, title: "研究生教务", heading: "研究生教务", marker: "学籍摘要", screenshotName: "Live graduate academic")
    openLiveItem(app, title: "研讨室", heading: "研讨室", marker: "seminar-rooms-loaded", screenshotName: "Live seminar rooms")
  }

  private func openLiveItem(
    _ app: XCUIApplication,
    title: String,
    heading: String,
    marker: String,
    screenshotName: String
  ) {
    let entry = app.buttons[title].firstMatch
    XCTAssertTrue(entry.waitForExistence(timeout: 12), "缺少入口：\(title)")
    if entry.isHittable == false {
      app.swipeUp()
    }
    entry.tap()
    XCTAssertTrue(app.navigationBars[heading].waitForExistence(timeout: 12), "\(title)页面未打开")
    XCTAssertTrue(
      app.staticTexts[marker].waitForExistence(timeout: 90),
      "\(title)未读取到真实数据标记：\(marker)"
    )
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = screenshotName
    attachment.lifetime = .keepAlways
    add(attachment)

    let back = app.navigationBars[heading].buttons.firstMatch
    if back.exists {
      back.tap()
    }
  }

  private func openMoreItem(_ title: String, heading: String, screenshotName: String) {
    let item = app.buttons[title].firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 8), "更多页缺少入口：\(title)")
    item.tap()
    let navigationTitle = app.navigationBars[heading]
    let visibleHeading = app.staticTexts[heading].firstMatch
    XCTAssertTrue(
      navigationTitle.waitForExistence(timeout: 8) || visibleHeading.waitForExistence(timeout: 2),
      "\(title)页面未显示标题"
    )
    attachScreenshot(named: screenshotName)

    let back = app.navigationBars.buttons.firstMatch
    if back.exists {
      back.tap()
      XCTAssertTrue(app.navigationBars["更多"].waitForExistence(timeout: 8))
    }
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

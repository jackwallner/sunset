import XCTest

/// Persona audit walk: larger text, imperfect vision, one-handed reach.
/// Every test attaches screenshots and a frame report; none asserts on
/// layout quality, so the run always yields evidence.
final class AccessibilityAuditTests: XCTestCase {
    private static let xxxl = "ax5"
    private static let ax3 = "ax3"

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ extra: [String], size: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var args = extra
        if let size { args += ["-DynamicType", size] }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Lists every button/link/switch on screen with its frame and flags
    /// those under 44 x 44 pt or partly off screen.
    private func report(_ app: XCUIApplication, _ name: String) {
        let screen = app.windows.firstMatch.frame
        var lines = ["screen \(Int(screen.width))x\(Int(screen.height))"]
        let types: Set<XCUIElement.ElementType> = [.button, .link, .switch, .cell, .segmentedControl]
        func walk(_ node: XCUIElementSnapshot) {
            let f = node.frame
            if types.contains(node.elementType), f.width > 0, f.height > 0 {
                var flags: [String] = []
                if f.height < 44 || f.width < 44 { flags.append("SMALL") }
                if f.maxY > screen.height + 1 || f.minX < -1 || f.maxX > screen.width + 1 { flags.append("OFFSCREEN") }
                lines.append("\(node.elementType.rawValue) '\(node.label)' \(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height)) \(flags.joined(separator: ","))")
            }
            node.children.forEach(walk)
        }
        if let snapshot = try? app.snapshot() { walk(snapshot) } else { lines.append("snapshot failed") }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "frames-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func look(_ app: XCUIApplication, _ name: String) {
        shot(app, name)
        report(app, name)
    }

    private let demo = ["-DemoLocation", "-DemoForecast"]

    // MARK: Onboarding

    func testOnboardingWalkDefaultSize() {
        let app = launch(["-OnboardingStep", "0"])
        look(app, "onb0-default-welcome")
        app.buttons["Continue"].tap()
        look(app, "onb1-default-watch")
        app.buttons["Continue"].tap()
        look(app, "onb2-default-alerts")
    }

    func testOnboardingPagesAccessibilityXXXL() {
        for step in 0 ... 3 {
            let app = launch(["-OnboardingStep", "\(step)"], size: Self.xxxl)
            sleep(2)
            look(app, "onb\(step)-xxxl")
            app.terminate()
        }
    }

    func testOnboardingAlertsPageXXXLWithRestoreAndLinks() {
        let app = launch(["-OnboardingStep", "3"], size: Self.xxxl)
        sleep(7)
        look(app, "onb3-xxxl-after-wait")
    }

    // MARK: Today / Outlook / Settings

    func testTodayDefaultAndAX3() {
        var app = launch(demo)
        sleep(2)
        look(app, "today-default-top")
        app.swipeUp()
        look(app, "today-default-scrolled")
        app.terminate()

        app = launch(demo, size: Self.ax3)
        sleep(2)
        look(app, "today-ax3-top")
        app.swipeUp()
        look(app, "today-ax3-scroll1")
        app.swipeUp()
        look(app, "today-ax3-scroll2")
        app.swipeUp()
        look(app, "today-ax3-scroll3")
        app.swipeUp()
        look(app, "today-ax3-scroll4")
    }

    func testTodayHeroDetailAX3() {
        let app = launch(demo, size: Self.ax3)
        sleep(2)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'score'")).firstMatch.tap()
        sleep(1)
        look(app, "detail-ax3-top")
        app.swipeUp()
        look(app, "detail-ax3-scroll")
    }

    func testOutlookFreeAndAX3() {
        var app = launch(demo)
        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        look(app, "outlook-default")
        app.swipeUp()
        look(app, "outlook-default-scrolled")
        app.terminate()

        app = launch(demo, size: Self.ax3)
        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        look(app, "outlook-ax3")
        app.swipeUp()
        look(app, "outlook-ax3-scrolled")
    }

    func testSettingsAndAlertSheetAX3() {
        let app = launch(demo, size: Self.ax3)
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        look(app, "settings-ax3")
        app.swipeUp()
        look(app, "settings-ax3-scrolled")
        app.swipeDown()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Alerts'")).firstMatch.tap()
        sleep(1)
        look(app, "alertsheet-ax3-free")
        app.swipeUp()
        look(app, "alertsheet-ax3-free-scrolled")
    }

    func testAlertSheetProDefault() {
        let app = launch(demo + ["-DemoPro", "-ScreenshotScene", "alerts"])
        sleep(2)
        look(app, "alertsheet-pro-default")
        app.swipeUp()
        look(app, "alertsheet-pro-default-scrolled")
    }

    // MARK: Paywall

    func testPaywallDefaultAndAX3() {
        var app = launch(["-PaywallSnapshot"])
        sleep(3)
        look(app, "paywall-default")
        app.terminate()
        app = launch(["-PaywallSnapshot"], size: Self.ax3)
        sleep(3)
        look(app, "paywall-ax3")
        app.swipeUp()
        look(app, "paywall-ax3-scrolled")
    }

    func testPaywallFromTodayCloseReach() {
        let app = launch(demo)
        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        app.swipeUp()
        look(app, "outlook-locked-default")
        let unlock = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sun+' OR label CONTAINS[c] 'unlock' OR label CONTAINS[c] 'week'")).firstMatch
        if unlock.waitForExistence(timeout: 3) { unlock.tap() }
        sleep(2)
        look(app, "paywall-sheet-from-outlook")
    }
}

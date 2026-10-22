import XCTest

/// Newcomer walk-through used by the persona audit. Every step attaches a
/// screenshot; touch-target sizes are attached as text.
final class NewcomerAuditUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func sizes(_ app: XCUIApplication, _ labels: [String]) {
        var lines: [String] = []
        for label in labels {
            let match = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            if match.exists {
                let f = match.frame
                lines.append("\(label): \(Int(f.width))x\(Int(f.height)) at y=\(Int(f.minY)) hittable=\(match.isHittable)")
            } else {
                lines.append("\(label): not found")
            }
        }
        note("target-sizes", lines.joined(separator: "\n"))
    }

    /// Taps a system permission alert if one shows up. Returns its text.
    @discardableResult
    private func answerSystemAlert(allow: Bool, wait: TimeInterval = 6) -> String? {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: wait) else { return nil }
        let text = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
        shot("system-alert-\(allow ? "allow" : "deny")")
        let names = allow
            ? ["Allow While Using App", "Allow", "OK"]
            : ["Don\u{2019}t Allow", "Don't Allow"]
        for name in names where alert.buttons[name].exists {
            alert.buttons[name].tap()
            break
        }
        return text
    }

    // MARK: First run

    func testFirstRunAllowEverything() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        shot("01-welcome")
        sizes(app, ["Continue"])

        app.buttons["Continue"].tap()
        let locationText = answerSystemAlert(allow: true)
        note("location-alert-text", locationText ?? "none")
        sleep(1)
        shot("02-watch")

        app.buttons["Continue"].tap()
        sleep(1)
        shot("03-alerts")
        sizes(app, ["Turn on alerts", "Not now"])

        app.buttons["Turn on alerts"].tap()
        let notifText = answerSystemAlert(allow: true)
        note("notification-alert-text", notifText ?? "none")
        sleep(2)
        shot("04-plus")
        sizes(app, ["Get Started", "Restore", "Terms", "Privacy"])

        app.buttons["Get Started"].tap()
        sleep(3)
        shot("05-today-after-onboarding-t3")
        sleep(12)
        shot("06-today-after-onboarding-t15")
        sleep(15)
        shot("07-today-after-onboarding-t30")
    }

    func testFirstRunDenyLocationAndNotifications() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        app.buttons["Continue"].tap()
        answerSystemAlert(allow: false)
        sleep(1)
        shot("10-watch-after-location-deny")
        app.buttons["Continue"].tap()
        sleep(1)
        app.buttons["Turn on alerts"].tap()
        answerSystemAlert(allow: false)
        sleep(2)
        shot("11-plus-after-notification-deny")
        app.buttons["Get Started"].tap()
        sleep(3)
        shot("12-today-location-denied")
    }

    func testFirstRunSunriseOnlyAndSkip() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        app.buttons["Continue"].tap()
        answerSystemAlert(allow: false)
        sleep(1)
        shot("20-watch-default")
        // Both are on by default; turn sunset off, then try to turn sunrise off too.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sunset'")).firstMatch.tap()
        sleep(1)
        shot("21-watch-sunrise-only")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sunrise'")).firstMatch.tap()
        sleep(1)
        shot("22-watch-try-none")
        app.buttons["Continue"].tap()
        sleep(1)
        shot("23-alerts-sunrise-only")
        app.buttons["Not now"].tap()
        sleep(1)
        shot("24-plus-after-not-now")
        app.buttons["Restore"].tap()
        sleep(3)
        shot("25-restore-feedback")
    }

    // MARK: Core action with a fixed forecast

    private func demoApp(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-DemoLocation", "-DemoForecast"] + extra
        app.launch()
        return app
    }

    func testTodayOutlookSettingsFree() {
        let app = demoApp()
        XCTAssertTrue(app.staticTexts["What makes the score"].waitForExistence(timeout: 15))
        sleep(1)
        shot("30-today-top")
        sizes(app, ["Today", "Outlook", "Settings"])
        app.swipeUp()
        shot("31-today-scrolled-1")
        app.swipeUp()
        shot("32-today-scrolled-2")
        app.swipeUp()
        shot("33-today-scrolled-3")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)

        let hero = app.buttons.matching(NSPredicate(format: "label CONTAINS 'score'")).firstMatch
        if hero.exists {
            hero.tap()
            sleep(1)
            shot("34-hero-detail")
            app.swipeUp()
            shot("35-hero-detail-scrolled")
            app.navigationBars.buttons.firstMatch.tap()
        }

        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        shot("40-outlook")
        app.swipeUp()
        shot("41-outlook-locked")
        let unlock = app.buttons["Unlock with Sun+"]
        if unlock.exists {
            unlock.tap()
            sleep(2)
            shot("42-paywall-from-outlook")
            sizes(app, ["Close", "Restore purchases"])
            if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        }

        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        shot("50-settings")
        app.swipeUp()
        shot("51-settings-bottom")
        app.swipeDown()
        app.buttons["Update location"].tap()
        sleep(1)
        shot("52-update-location-feedback")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Alerts'")).firstMatch.tap()
        sleep(1)
        shot("53-alert-sheet")
        app.swipeUp()
        shot("54-alert-sheet-bottom")
    }

    func testTodayAlertsCardAndLockedRows() {
        let app = demoApp()
        XCTAssertTrue(app.staticTexts["What makes the score"].waitForExistence(timeout: 15))
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        let turnOn = app.buttons["Turn on alerts"]
        if turnOn.waitForExistence(timeout: 3) {
            shot("60-today-alerts-card")
            turnOn.tap()
            sleep(1)
            shot("61-alert-sheet-after-card")
            app.switches.firstMatch.tap()
            answerSystemAlert(allow: false)
            sleep(1)
            shot("62-alert-sheet-denied")
        }
    }

    func testProTodayAndOutlook() {
        let app = demoApp(extra: ["-DemoPro"])
        XCTAssertTrue(app.staticTexts["What makes the score"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        shot("70-outlook-pro")
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        shot("71-settings-pro")
    }

    func testSettingsWatchToggle() {
        let app = demoApp()
        XCTAssertTrue(app.staticTexts["What makes the score"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        let toggles = app.switches
        shot("80-settings-before")
        toggles.element(boundBy: 0).tap()
        sleep(1)
        shot("81-settings-one-off")
        app.tabBars.buttons["Today"].tap()
        sleep(1)
        shot("82-today-sunrise-or-sunset-only")
        app.tabBars.buttons["Outlook"].tap()
        sleep(1)
        shot("83-outlook-one-watched")
    }

    func testPaywallFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["-PaywallSnapshot"]
        app.launch()
        sleep(4)
        shot("90-paywall-snapshot")
        app.swipeUp()
        shot("91-paywall-snapshot-bottom")
    }
}

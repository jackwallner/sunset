import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1OnboardingToOfferAndToday() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast", "-OnboardingStep", "0"])
        checkpoint("welcome", button: "Continue", in: app)
        tap("Continue", in: app)
        allowLocation()
        checkpoint("watch", button: "Continue", in: app)
        tap("Continue", in: app)
        checkpoint("alerts", button: "Not now", in: app)
        tap("Not now", in: app)
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-offer", paywall: true)
        tap("Get Started", in: app)
        today("first-today", in: app)
    }

    func test2TabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast"])
        today("today", in: app)
        tapTab("Outlook", in: app)
        QA.checkpoint(app, "outlook")
        tapTab("Settings", in: app)
        QA.checkpoint(app, "settings")
        let plus = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Sun+")).firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "upgrade", paywall: true)
        tap("Close", in: app)
        tapTab("Today", in: app)
        today("today-after-upgrade", in: app)
        QA.interrupt(app)
        today("today-after-background", in: app)
        QA.relaunch(app)
        today("today-after-relaunch", in: app)
    }

    /// The welcome page asks for one location fix on the way out.
    private func allowLocation() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once", "Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Allow While Using App" ? 5 : 1) {
                button.tap()
                return
            }
        }
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name)
    }

    private func today(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Today"].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, name)
    }
}

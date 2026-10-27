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

    /// Core loop: choose which show to watch and read its score on Today. The
    /// hero follows the watch toggles, and the choice survives a relaunch.
    func testCoreLoopWatchChoiceDrivesTodayScore() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast"])
        today("today", in: app)
        let both = hero(in: app)
        XCTAssertTrue(both.waitForExistence(timeout: 15))
        XCTAssertTrue(both.label.contains("score"), both.label)

        tapTab("Settings", in: app)
        setWatch("Sunrise", on: false, in: app)
        QA.checkpoint(app, "sunrise-off")
        tapTab("Today", in: app)
        assertHero("sunset", in: app)
        QA.checkpoint(app, "today-sunset-only")

        tapTab("Settings", in: app)
        setWatch("Sunrise", on: true, in: app)
        setWatch("Sunset", on: false, in: app)
        QA.checkpoint(app, "sunset-off")
        tapTab("Today", in: app)
        assertHero("sunrise", in: app)
        QA.checkpoint(app, "today-sunrise-only")

        QA.relaunch(app)
        today("today-after-relaunch", in: app)
        assertHero("sunrise", in: app)
        tapTab("Settings", in: app)
        assertWatch("Sunrise", on: true, in: app)
        assertWatch("Sunset", on: false, in: app)
        QA.checkpoint(app, "settings-after-relaunch")

        // Leave the install watching both, as the other journeys expect.
        setWatch("Sunset", on: true, in: app)
        tapTab("Today", in: app)
        today("today-restored", in: app)
    }

    private func hero(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", ", score ")).firstMatch
    }

    private func assertHero(_ event: String, in app: XCUIApplication) {
        let hero = hero(in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(hero.label.lowercased().contains(event), "hero \(hero.label) should be a \(event)")
        XCTAssertTrue(hero.label.contains("score"), hero.label)
    }

    private func watchSwitch(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches[name].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "\(name) switch")
        return toggle
    }

    private func assertWatch(_ name: String, on: Bool, in app: XCUIApplication) {
        XCTAssertEqual(watchSwitch(name, in: app).value as? String, on ? "1" : "0", name)
    }

    private func setWatch(_ name: String, on: Bool, in app: XCUIApplication) {
        let toggle = watchSwitch(name, in: app)
        if (toggle.value as? String) != (on ? "1" : "0") { toggle.tap() }
        assertWatch(name, on: on, in: app)
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

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name, journey: journey)
    }

    private func today(_ name: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.tabBars.buttons["Today"].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, name, journey: journey)
    }
}

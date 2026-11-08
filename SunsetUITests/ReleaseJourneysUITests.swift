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
        // Unfolded, the Outlook is the trailing pane and has no tab.
        if tabButton("Outlook", in: app).waitForExistence(timeout: 3) { tapTab("Outlook", in: app) }
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
        let toggle = watchSwitch(name, in: app)
        let settled = NSPredicate(format: "value == %@", on ? "1" : "0")
        let wait = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: toggle)], timeout: 5)
        XCTAssertEqual(wait, .completed, "\(name) should be \(on ? "on" : "off")")
    }

    private func setWatch(_ name: String, on: Bool, in app: XCUIApplication) {
        let toggle = watchSwitch(name, in: app)
        let target = on ? "1" : "0"
        guard (toggle.value as? String) != target else { return assertWatch(name, on: on, in: app) }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let settled = NSPredicate(format: "value == %@", target)
        let wait = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: toggle)], timeout: 3)
        // A tap can miss while the row is still settling; retry only if nothing changed.
        if wait != .completed, (toggle.value as? String) != target { toggle.tap() }
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

    /// The bottom bar is a tab bar on a phone and a floating capsule on the
    /// unfolded Duo, where it is not a `tabBars` element; the Outlook is a
    /// separate pane there, not a tab.
    private func tabButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let bar = app.tabBars.buttons[label].firstMatch
        if bar.exists { return bar }
        let capsule = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        return capsule.exists ? capsule : bar
    }

    /// A tap can miss the unfolded Duo's capsule; a short press on the
    /// button's own coordinate selects it there too.
    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = tabButton(label, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        let selected = NSPredicate(format: "isSelected == true")
        let wait = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: button)], timeout: 3)
        if wait != .completed {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name, journey: journey)
    }

    private func today(_ name: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(tabButton("Today", in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, name, journey: journey)
    }
}

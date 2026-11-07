import XCTest

/// Audit 2026-11-06 B5: the onboarding bottom bar stays live while a page
/// slides in, so a quick second tap used to run the next page's action and
/// skip pages, including the Sun+ offer.
@MainActor
final class OnboardingDoubleTapUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(step: Int) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast", "-OnboardingStep", "\(step)"])
        return app
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 20), "precondition: \(label) is on screen")
        return button
    }

    /// Answers the notification prompt if iOS raises it.
    private func answerNotificationPrompt() -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        guard allow.waitForExistence(timeout: 4) else { return false }
        allow.tap()
        return true
    }

    func testDoubleTapOnWatchLandsOnAlertsWithoutPrompt() {
        let app = launch(step: 1)
        button("Continue", in: app).doubleTap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let prompted = springboard.buttons["Allow"].waitForExistence(timeout: 3)
        if prompted { springboard.buttons["Allow"].tap() }
        XCTAssertFalse(prompted, "the second tap raised the notification prompt over a page never read")
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5), "double tap skipped the alerts page")
        XCTAssertFalse(app.buttons["Get Started"].exists, "double tap landed on the Sun+ offer")
    }

    func testDoubleTapOnNotNowStaysOnOffer() {
        let app = launch(step: 2)
        button("Not now", in: app).doubleTap()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 5), "double tap left onboarding without the offer")
        sleep(2)
        XCTAssertTrue(app.buttons["Get Started"].exists, "double tap left onboarding without the offer")
    }

    func testDoubleTapOnTurnOnAlertsStaysOnOffer() {
        let app = launch(step: 2)
        button("Turn on alerts", in: app).doubleTap()
        _ = answerNotificationPrompt()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10), "double tap left onboarding without the offer")
        sleep(2)
        XCTAssertTrue(app.buttons["Get Started"].exists, "double tap left onboarding without the offer")
    }
}

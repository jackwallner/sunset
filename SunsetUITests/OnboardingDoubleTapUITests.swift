import XCTest

/// Audit 2026-11-06 B5: the onboarding bottom bar stays live while a page
/// slides in, so a quick second tap used to run the next page's action and
/// skip pages, including the Sun+ offer.
///
/// `-DemoNotificationPrompt` answers the notification prompt with Allow one
/// second after it is raised, because GitHub's simulators do not always show
/// the system prompt.
@MainActor
final class OnboardingDoubleTapUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(step: Int) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast", "-DemoNotificationPrompt", "-OnboardingStep", "\(step)"])
        return app
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 20), "precondition: \(label) is on screen")
        return button
    }

    /// The second tap used to be "Turn on alerts": the prompt went up over a
    /// page never read, and its answer moved on to the offer.
    func testDoubleTapOnWatchLandsOnAlerts() {
        let app = launch(step: 1)
        button("Continue", in: app).doubleTap()
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5), "double tap skipped the alerts page")
        sleep(3)
        XCTAssertTrue(app.buttons["Not now"].exists, "the second tap asked for notifications and left the alerts page")
        XCTAssertFalse(app.buttons["Get Started"].exists, "double tap landed on the Sun+ offer")
    }

    /// The second tap used to be "Get Started", in the same slot as "Not now".
    func testDoubleTapOnNotNowStaysOnOffer() {
        let app = launch(step: 2)
        button("Not now", in: app).doubleTap()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 5), "double tap left onboarding without the offer")
        sleep(2)
        XCTAssertTrue(app.buttons["Get Started"].exists, "double tap left onboarding without the offer")
    }

    /// Both taps used to await the prompt and advance, the second past the offer.
    func testDoubleTapOnTurnOnAlertsStaysOnOffer() {
        let app = launch(step: 2)
        button("Turn on alerts", in: app).doubleTap()
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 10), "double tap left onboarding without the offer")
        sleep(3)
        XCTAssertTrue(app.buttons["Get Started"].exists, "double tap left onboarding without the offer")
    }
}

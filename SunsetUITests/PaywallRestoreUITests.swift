import XCTest

/// Audit 2026-11-06 B4: a successful Restore from the paywall left it open on
/// the plans with a live buy button and no word that Sun+ was back.
@MainActor
final class PaywallRestoreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        // `-DemoRestore` starts every launch free; one more launch clears the
        // Sun+ this test restored, so later journeys see a free install.
        addTeardownBlock { @MainActor in
            let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
            app.launchArguments = ["-DemoLocation", "-DemoForecast", "-DemoRestore"]
            app.launch()
            sleep(3)
            app.terminate()
        }
    }

    func testRestoreOnPaywallClosesItForAMember() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        QA.launch(app, arguments: ["-DemoLocation", "-DemoForecast", "-DemoRestore"])
        let settingsTab = app.tabBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 20), "precondition: tab bar")
        settingsTab.tap()
        let plus = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Sun+")).firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "precondition: a free install shows the Sun+ row")
        plus.tap()

        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15), "precondition: the paywall is open")
        let restore = app.scrollViews.buttons["Restore purchases"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 15), "precondition: the paywall's Restore button")
        for _ in 0 ..< 4 where !restore.isHittable { app.scrollViews.firstMatch.swipeUp() }
        restore.tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed,
                       "the paywall stayed open with a live buy button after Sun+ was restored")
        XCTAssertTrue(app.staticTexts["Sun+ is on"].waitForExistence(timeout: 5))
    }
}

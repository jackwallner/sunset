import XCTest

@MainActor
final class ZZProbeUITests: XCTestCase {
    func testProbeSingleTapTurnOnAlerts() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.sunset")
        app.launchArguments = ["-DemoLocation", "-DemoForecast", "-OnboardingStep", "2"]
        app.launch()
        let button = app.buttons["Turn on alerts"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        sleep(5)
        button.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for second in 0 ..< 10 {
            sleep(1)
            let alerts = springboard.alerts.allElementsBoundByIndex.map(\.label)
            print("PROBE t=\(second) alerts=\(alerts) getStarted=\(app.buttons["Get Started"].exists) turnOn=\(app.buttons["Turn on alerts"].exists)")
            let allow = springboard.alerts.buttons["Allow"]
            if allow.exists { print("PROBE tapping Allow"); allow.tap() }
        }
    }
}

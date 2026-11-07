import UserNotifications
import XCTest
@testable import Sunset

/// Regression tests for the 2026-11-06 state machine audit fixes
/// (`project-docs/audits/state-machines-2026-11-06-fixes.md`).
@MainActor
final class StateMachineFixTests: XCTestCase {
    // MARK: B1, B2 alerts follow the iOS permission

    /// B1: a denial leaves the toggle on (the user still wants alerts) but the
    /// app reports alerts as blocked. B2: a later grant is picked up and
    /// rebuilds the alerts, and only a real change rebuilds them.
    func testNotificationPermissionIsReconciledWithAlertsToggle() async {
        let settings = AlertSettings.shared
        let saved = settings.alertsEnabled
        defer { settings.alertsEnabled = saved }
        settings.alertsEnabled = true
        await settings.syncNotificationPermission(.authorized)
        XCTAssertFalse(settings.alertsBlocked, "precondition: allowed alerts are not blocked")

        let revoked = await settings.syncNotificationPermission(.denied)
        XCTAssertTrue(revoked, "a revoke rebuilds the alerts")
        XCTAssertTrue(settings.alertsBlocked, "denied by iOS while on must read as blocked")
        XCTAssertTrue(settings.alertsEnabled, "a denial never clears the user's toggle")

        let unchanged = await settings.syncNotificationPermission(.denied)
        XCTAssertFalse(unchanged, "no change, no rebuild")

        let granted = await settings.syncNotificationPermission(.authorized)
        XCTAssertTrue(granted, "a grant in iOS Settings rebuilds the alerts")
        XCTAssertFalse(settings.alertsBlocked)

        settings.alertsEnabled = false
        await settings.syncNotificationPermission(.denied)
        XCTAssertFalse(settings.alertsBlocked, "alerts the user turned off are off, not blocked")
    }
}

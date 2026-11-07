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

    // MARK: B3 a widget-fresh snapshot still gets alerts

    private func waitUntil(timeout: Double = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
    }

    /// Cold launch on a snapshot the widget fetched: the forecast is fresh and
    /// for this place, so no fetch runs, but alerts must still be rebuilt from
    /// it.
    func testFreshSnapshotNoAlertWasBuiltFromIsRescheduledOnRefresh() async {
        let here = ForecastCache.Location(latitude: 45.63, longitude: -122.52, placeName: "Vancouver, WA")
        let snapshot = SunsetForecast(
            latitude: here.latitude, longitude: here.longitude, placeName: here.placeName,
            timeZoneID: "America/Los_Angeles", fetched: .now, days: [], skyEvents: []
        )
        let store = ForecastStore(forecast: snapshot)
        XCTAssertFalse(snapshot.isStale(), "precondition: the widget's snapshot is fresh")
        XCTAssertNil(store.alertsPlannedFrom, "precondition: nothing planned in this launch")

        store.refresh(location: here)
        await waitUntil { store.alertsPlannedFrom != nil }
        XCTAssertEqual(store.alertsPlannedFrom, snapshot.fetched, "alerts were not rebuilt from the widget's snapshot")
        XCTAssertFalse(store.isLoading, "a fresh snapshot needs no fetch")
    }

    // MARK: B6 a fix that lands while a load runs is not dropped

    private let vancouver = ForecastCache.Location(latitude: 45.63, longitude: -122.52, placeName: "Vancouver, WA")
    private let tokyo = ForecastCache.Location(latitude: 35.68, longitude: 139.69, placeName: "Tokyo")

    private func waitForIdle(_ store: ForecastStore, timeout: Double = 40) async {
        let deadline = Date().addingTimeInterval(timeout)
        try? await Task.sleep(for: .milliseconds(300))
        while store.isLoading, Date() < deadline { try? await Task.sleep(for: .milliseconds(250)) }
        try? await Task.sleep(for: .seconds(2))
        while store.isLoading, Date() < deadline { try? await Task.sleep(for: .milliseconds(250)) }
    }

    /// Control: with nothing in flight, a fix for a new place loads that place.
    /// Real Open-Meteo network, as in the audit's repro.
    func testFixWithNothingInFlightLoadsThatPlace() async throws {
        let store = ForecastStore(forecast: nil)
        await store.load(location: vancouver)
        XCTAssertEqual(try XCTUnwrap(store.forecast, "precondition: network works").latitude, 45.63, accuracy: 0.01)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        XCTAssertEqual(try XCTUnwrap(store.forecast).latitude, 35.68, accuracy: 0.01)
    }

    /// Cold start: the cached place (Vancouver) starts a load, then the real
    /// fix (Tokyo) arrives before it finishes. The newer place must win.
    func testFixArrivingDuringLoadIsNotDropped() async throws {
        let store = ForecastStore(forecast: nil)
        store.refresh(location: vancouver, force: true)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        let forecast = try XCTUnwrap(store.forecast, "precondition: some forecast loaded")
        XCTAssertEqual(forecast.latitude, 35.68, accuracy: 0.01,
                       "store shows lat \(forecast.latitude) place \(forecast.placeName ?? "nil"); the second fix was ignored")
        XCTAssertEqual(forecast.placeName, "Tokyo")
        XCTAssertFalse(store.isLoading)
    }
}

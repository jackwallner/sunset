import UserNotifications
import XCTest
@testable import Sunset

/// State machine audit repro (2026-11-06). Failing tests are the claims, each
/// preceded by its own precondition asserts. `*Control` tests must pass.
@MainActor
final class StateMachineAuditRepro: XCTestCase {
    // MARK: Helpers

    private func date(_ zone: TimeZone, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, year: Int = 2026) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func show(_ event: SunEvent, _ time: Date, score: Int) -> SunShow {
        var result = SunsetScorer.score(.clear, event: event)
        result.total = score
        return SunShow(event: event, time: time, conditions: .clear, score: result)
    }

    private func forecast(zone: TimeZone, month: Int, day: Int, sunrise: (Int, Int), sunset: (Int, Int)) -> SunsetForecast {
        let today = SunsetDay(
            sunrise: show(.sunrise, date(zone, month, day, sunrise.0, sunrise.1), score: 80),
            sunset: show(.sunset, date(zone, month, day, sunset.0, sunset.1), score: 80)
        )
        return SunsetForecast(
            latitude: 64.1, longitude: -21.9, placeName: nil, timeZoneID: zone.identifier,
            fetched: date(zone, month, day, 9), days: [today], skyEvents: []
        )
    }

    private func sunsetAlert(_ forecast: SunsetForecast, zone: TimeZone, month: Int, day: Int, lead: Int) throws -> NotificationService.Planned {
        let planned = NotificationService.plan(
            forecast: forecast, watched: [.sunset], threshold: 70, leadMinutes: lead,
            skyEventKinds: [], now: date(zone, month, day, 9)
        )
        XCTAssertEqual(planned.count, 1, "precondition: the 80-score sunset plans exactly one alert")
        return try XCTUnwrap(planned.first)
    }

    // MARK: B1 sunset alerts ignore quiet hours

    /// Control: the quiet-hours helper works, and an ordinary sunset alert is
    /// outside it.
    func testQuietHoursControl() throws {
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertTrue(NotificationService.isQuiet(date(la, 6, 21, 23), zone: la), "precondition: 23:00 is quiet")
        XCTAssertFalse(NotificationService.isQuiet(date(la, 6, 21, 17), zone: la), "precondition: 17:00 is not quiet")
        let f = forecast(zone: la, month: 6, day: 21, sunrise: (5, 40), sunset: (20, 35))
        let alert = try sunsetAlert(f, zone: la, month: 6, day: 21, lead: 45)
        XCTAssertFalse(NotificationService.isQuiet(alert.fireDate, zone: la), "fire \(alert.fireDate)")
    }

    /// Reykjavik, midnight sun: sunset 23:58, default 45 min lead.
    func testSunsetAlertNeverFiresInQuietHours_Reykjavik() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Atlantic/Reykjavik"))
        XCTAssertTrue(NotificationService.isQuiet(date(zone, 6, 21, 23), zone: zone), "precondition: 23:00 is quiet")
        let f = forecast(zone: zone, month: 6, day: 21, sunrise: (3, 0), sunset: (23, 58))
        let alert = try sunsetAlert(f, zone: zone, month: 6, day: 21, lead: 45)
        XCTAssertEqual(alert.fireDate, date(zone, 6, 21, 23, 13), "precondition: fire is sunset minus lead")
        XCTAssertFalse(
            NotificationService.isQuiet(alert.fireDate, zone: zone),
            "sunset alert planned for \(alert.fireDate) (23:13 local), inside 22:00-07:00 quiet hours"
        )
    }

    /// Helsinki, summer: sunset 22:50, default 45 min lead -> 22:05.
    func testSunsetAlertNeverFiresInQuietHours_Helsinki() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Helsinki"))
        let f = forecast(zone: zone, month: 6, day: 21, sunrise: (3, 54), sunset: (22, 50))
        let alert = try sunsetAlert(f, zone: zone, month: 6, day: 21, lead: 45)
        XCTAssertEqual(alert.fireDate, date(zone, 6, 21, 22, 5), "precondition: fire is sunset minus lead")
        XCTAssertFalse(NotificationService.isQuiet(alert.fireDate, zone: zone), "fire 22:05 local")
    }

    // MARK: B2 calendar trigger is read in the device zone, not the forecast zone

    /// `reschedule` builds the trigger from components computed in the forecast
    /// zone and never sets `timeZone` on them (NotificationService.swift:52-61).
    /// This replays those lines. The device is in New York, the forecast in
    /// Los Angeles (a traveller before the app has been opened again).
    func testTriggerFiresAtPlannedInstant_DeviceZoneDiffersFromForecastZone() throws {
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let ny = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let fire = date(la, 10, 8, 17, 45, year: 2031)
        XCTAssertNotEqual(la.secondsFromGMT(for: fire), ny.secondsFromGMT(for: fire), "precondition: zones differ")

        let saved = NSTimeZone.default
        defer { NSTimeZone.default = saved }
        NSTimeZone.default = ny

        var calendar = Calendar.current
        calendar.timeZone = la
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        XCTAssertEqual(components.hour, 17, "precondition: components are LA wall clock")
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let next = try XCTUnwrap(trigger.nextTriggerDate(), "precondition: trigger has a next date")
        XCTAssertEqual(next, fire, "trigger fires at \(next), planned \(fire)")
    }

    func testTriggerControl_SameZone() throws {
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let fire = date(la, 10, 8, 17, 45, year: 2031)
        let saved = NSTimeZone.default
        defer { NSTimeZone.default = saved }
        NSTimeZone.default = la
        var calendar = Calendar.current
        calendar.timeZone = la
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        XCTAssertEqual(try XCTUnwrap(trigger.nextTriggerDate()), fire)
    }

    // MARK: B3 a location fix that lands while a load is running is dropped

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
    func testForecastStoreControl_FixWithNothingInFlightLoads() async throws {
        let store = ForecastStore.shared
        await store.load(location: vancouver)
        XCTAssertEqual(try XCTUnwrap(store.forecast, "precondition: network works, Vancouver loaded").latitude, 45.63, accuracy: 0.01)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        XCTAssertEqual(try XCTUnwrap(store.forecast).latitude, 35.68, accuracy: 0.01)
    }

    /// Cold start: the cached location (Vancouver) starts a load, then the real
    /// fix (Tokyo) arrives before it finishes. `refresh` documents "Refreshes
    /// when ... the location moved" (ForecastStore.swift:326).
    func testFixArrivingDuringLoadIsNotDropped() async throws {
        let store = ForecastStore.shared
        store.refresh(location: vancouver, force: true)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        let forecast = try XCTUnwrap(store.forecast, "precondition: some forecast loaded")
        XCTAssertEqual(forecast.latitude, 35.68, accuracy: 0.01,
                       "store shows lat \(forecast.latitude) place \(forecast.placeName ?? "nil"); the second fix was ignored")
    }

    // MARK: Invariant controls

    /// Watched never empties (AlertSettings.swift:193 "Never empty").
    func testWatchedNeverEmptyControl() {
        let settings = AlertSettings.shared
        let saved = settings.watched
        defer { settings.watched = saved }
        settings.watched = [.sunrise]
        XCTAssertEqual(settings.watched, [.sunrise], "precondition")
        settings.watched = []
        XCTAssertEqual(settings.watched, [.sunrise])
        XCTAssertEqual(ForecastCache.watchedEvents, [.sunrise])
    }

    /// Lapsed Sun+ uses the defaults (AlertSettings.swift:89).
    func testEffectiveValuesControl() {
        let settings = AlertSettings.shared
        let saved = (settings.threshold, settings.leadMinutes)
        defer { (settings.threshold, settings.leadMinutes) = saved }
        settings.threshold = 90
        settings.leadMinutes = 120
        XCTAssertEqual(settings.effectiveThreshold(isPro: true), 90, "precondition")
        XCTAssertEqual(settings.effectiveThreshold(isPro: false), 70)
        XCTAssertEqual(settings.effectiveLead(isPro: false), 45)
    }
}

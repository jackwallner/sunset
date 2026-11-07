import XCTest
@testable import Sunset

@MainActor
final class StateMachineFixTests: XCTestCase {
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
        let store = ForecastStore.shared
        await store.load(location: vancouver)
        XCTAssertEqual(try XCTUnwrap(store.forecast, "precondition: network works").latitude, 45.63, accuracy: 0.01)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        XCTAssertEqual(try XCTUnwrap(store.forecast).latitude, 35.68, accuracy: 0.01)
    }

    /// Cold start: the cached place (Vancouver) starts a load, then the real
    /// fix (Tokyo) arrives before it finishes. The newer place must win.
    func testFixArrivingDuringLoadIsNotDropped() async throws {
        let store = ForecastStore.shared
        store.refresh(location: vancouver, force: true)
        store.refresh(location: tokyo)
        await waitForIdle(store)
        let forecast = try XCTUnwrap(store.forecast, "precondition: some forecast loaded")
        XCTAssertEqual(forecast.latitude, 35.68, accuracy: 0.01,
                       "store shows lat \(forecast.latitude) place \(forecast.placeName ?? "nil"); the second fix was ignored")
        XCTAssertEqual(forecast.placeName, "Tokyo")
        XCTAssertFalse(store.isLoading)
    }

    // MARK: B9 sunset alerts keep the quiet hours

    private func date(_ zone: TimeZone, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func show(_ event: SunEvent, _ time: Date, score: Int) -> SunShow {
        var result = SunsetScorer.score(.clear, event: event)
        result.total = score
        return SunShow(event: event, time: time, conditions: .clear, score: result)
    }

    private func sunsetAlert(zone: TimeZone, sunset: (Int, Int), lead: Int) throws -> NotificationService.Planned {
        let day = SunsetDay(
            sunrise: show(.sunrise, date(zone, 6, 21, 3, 30), score: 80),
            sunset: show(.sunset, date(zone, 6, 21, sunset.0, sunset.1), score: 80)
        )
        let forecast = SunsetForecast(
            latitude: 60, longitude: 0, placeName: nil, timeZoneID: zone.identifier,
            fetched: date(zone, 6, 21, 9), days: [day], skyEvents: []
        )
        let planned = NotificationService.plan(
            forecast: forecast, watched: [.sunset], threshold: 70, leadMinutes: lead,
            skyEventKinds: [], now: date(zone, 6, 21, 9)
        )
        XCTAssertEqual(planned.count, 1, "precondition: the 80-score sunset plans exactly one alert")
        return try XCTUnwrap(planned.first)
    }

    func testSunsetAlertOutsideQuietHoursKeepsItsLead() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let alert = try sunsetAlert(zone: zone, sunset: (20, 35), lead: 45)
        XCTAssertEqual(alert.fireDate, date(zone, 6, 21, 19, 50))
    }

    /// Helsinki (sunset 22:50, fires 22:05 at the default lead), Reykjavik
    /// (23:58) and Oslo at the Sun+ 30 min lead (22:44, fires 22:14) all land in
    /// 22:00-07:00. They move to 8 pm that evening instead.
    func testSunsetAlertNeverFiresInQuietHours() throws {
        let cases: [(String, (Int, Int), Int)] = [
            ("Europe/Helsinki", (22, 50), 45),
            ("Atlantic/Reykjavik", (23, 58), 45),
            ("Europe/Oslo", (22, 44), 30),
        ]
        for (id, sunset, lead) in cases {
            let zone = try XCTUnwrap(TimeZone(identifier: id))
            XCTAssertTrue(
                NotificationService.isQuiet(date(zone, 6, 21, sunset.0, sunset.1 - lead), zone: zone),
                "precondition: \(id) sunset minus lead is quiet"
            )
            let alert = try sunsetAlert(zone: zone, sunset: sunset, lead: lead)
            XCTAssertFalse(NotificationService.isQuiet(alert.fireDate, zone: zone), "\(id) fires at \(alert.fireDate), inside quiet hours")
            XCTAssertEqual(alert.fireDate, date(zone, 6, 21, 20), "\(id) moves to 8 pm that evening")
        }
    }

}

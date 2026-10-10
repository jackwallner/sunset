import XCTest
@testable import Sunset

final class SkyEventDetectorTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!

    private func date(_ hour: Int, day: Int = 8) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func testSunIsLowInLateAfternoonAndDownAtNight() {
        let afternoon = SolarPosition.elevation(at: date(17), latitude: 45.6, longitude: -122.5)
        let noon = SolarPosition.elevation(at: date(13), latitude: 45.6, longitude: -122.5)
        let night = SolarPosition.elevation(at: date(23), latitude: 45.6, longitude: -122.5)
        XCTAssertTrue((2 ... 20).contains(afternoon), "5 pm elevation \(afternoon)")
        XCTAssertTrue((30 ... 45).contains(noon), "noon elevation \(noon)")
        XCTAssertLessThan(night, 0)
    }

    func testShowersUnderBrokenSkyWithLowSunAreARainbowChance() {
        let showers = SkyEventDetector.Hour(time: date(17), weatherCode: 80, cloudCover: 55,
                                            precipitation: 0.6, precipitationChance: 60, visibility: 20_000)
        XCTAssertEqual(SkyEventDetector.kinds(for: showers, sunElevation: 15), [.rainbow])
        XCTAssertEqual(SkyEventDetector.kinds(for: showers, sunElevation: 50), [])
        var overcast = showers
        overcast.cloudCover = 100
        XCTAssertEqual(SkyEventDetector.kinds(for: overcast, sunElevation: 15), [])
        var dry = showers
        dry.precipitation = 0
        XCTAssertEqual(SkyEventDetector.kinds(for: dry, sunElevation: 15), [])
    }

    func testFogFromCodeOrVisibility() {
        let foggy = SkyEventDetector.Hour(time: date(6), weatherCode: 45, cloudCover: 100,
                                          precipitation: 0, precipitationChance: 0, visibility: 5_000)
        XCTAssertEqual(SkyEventDetector.kinds(for: foggy, sunElevation: -5), [.fog])
        let murky = SkyEventDetector.Hour(time: date(6), weatherCode: 3, cloudCover: 100,
                                          precipitation: 0, precipitationChance: 0, visibility: 400)
        XCTAssertEqual(SkyEventDetector.kinds(for: murky, sunElevation: -5), [.fog])
    }

    func testSeparateRunsStaySeparate() {
        let hours = [9, 10, 14].map {
            SkyEventDetector.Hour(time: date($0), weatherCode: 95, cloudCover: 90,
                                  precipitation: 3, precipitationChance: 80, visibility: 10_000)
        }
        let events = SkyEventDetector.detect(hours, latitude: 45.6, longitude: -122.5)
        XCTAssertEqual(events.map(\.kind), [.thunderstorm, .thunderstorm])
        XCTAssertEqual(events[0].end, date(11))
    }
}

@MainActor
final class AlertPlanTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!

    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 8) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func show(_ event: SunEvent, _ time: Date, score: Int) -> SunShow {
        var result = SunsetScorer.score(.clear, event: event)
        result.total = score
        return SunShow(event: event, time: time, conditions: .clear, score: result)
    }

    private func forecast(events: [SkyEvent] = []) -> SunsetForecast {
        let day = SunsetDay(sunrise: show(.sunrise, date(7, 18, day: 9), score: 80),
                            sunset: show(.sunset, date(18, 30), score: 75))
        let later = SunsetDay(sunrise: show(.sunrise, date(7, 19, day: 10), score: 40),
                              sunset: show(.sunset, date(18, 28, day: 9), score: 50))
        return SunsetForecast(latitude: 45.6, longitude: -122.5, placeName: nil, timeZoneID: zone.identifier,
                              fetched: date(9), days: [day, later], skyEvents: events)
    }

    func testFreeShowAlertsUseThresholdAndSunriseArrivesTheEveningBefore() {
        let planned = NotificationService.plan(forecast: forecast(), watched: [.sunrise, .sunset],
                                               threshold: 70, leadMinutes: 45, skyEventKinds: [], now: date(9))
        XCTAssertEqual(planned.map(\.fireDate), [date(17, 45), date(20)])
        XCTAssertTrue(planned[1].title.contains("sunrise tomorrow"))
    }

    func testWatchedFiltersShows() {
        let planned = NotificationService.plan(forecast: forecast(), watched: [.sunrise],
                                               threshold: 70, leadMinutes: 45, skyEventKinds: [], now: date(9))
        XCTAssertEqual(planned.count, 1)
    }

    func testSkyEventsNeedTheirKindAndSkipQuietHours() {
        let storm = SkyEvent(kind: .thunderstorm, start: date(15), end: date(17))
        let overnightFog = SkyEvent(kind: .fog, start: date(5, day: 9), end: date(9, day: 9))
        let planned = NotificationService.plan(forecast: forecast(events: [storm, overnightFog]), watched: [],
                                               threshold: 70, leadMinutes: 45,
                                               skyEventKinds: [.thunderstorm, .fog], now: date(9))
        XCTAssertEqual(planned.map(\.fireDate), [date(14), date(20)])
        XCTAssertEqual(NotificationService.plan(forecast: forecast(events: [storm]), watched: [],
                                                threshold: 70, leadMinutes: 45, skyEventKinds: [.fog],
                                                now: date(9)).count, 0)
    }
}

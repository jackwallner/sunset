import UserNotifications
import XCTest
@testable import Sunset

/// Regressions from the 2026-11-08 deep pre-submit review.
@MainActor
final class PresubmitDeepFixTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!

    private func date(_ hour: Int, _ minute: Int = 0, day: Int, in zone: TimeZone? = nil) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone ?? self.zone
        return calendar.date(from: DateComponents(year: 2030, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func show(_ event: SunEvent, _ time: Date) -> SunShow {
        SunShow(event: event, time: time, conditions: .clear, score: SunsetScorer.score(.clear, event: event))
    }

    private func week() -> SunsetForecast {
        let days = (10 ..< 15).map { day in
            SunsetDay(sunrise: show(.sunrise, date(5, 30, day: day)), sunset: show(.sunset, date(20, 50, day: day)))
        }
        return SunsetForecast(latitude: 45.6, longitude: -122.5, placeName: nil, timeZoneID: zone.identifier,
                              fetched: date(9, day: 10), days: days, skyEvents: [])
    }

    /// The trigger fires at the planned instant even when the forecast's
    /// place is on another clock than the device.
    func testAlertTriggerFiresAtThePlannedInstantInTheForecastZone() throws {
        let kiritimati = TimeZone(identifier: "Pacific/Kiritimati")!
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!
        let device = TimeZone.current.secondsFromGMT() == kiritimati.secondsFromGMT() ? honolulu : kiritimati
        let fire = date(19, 15, day: 10, in: device)
        let trigger = NotificationService.trigger(firing: fire, zone: device)
        XCTAssertEqual(try XCTUnwrap(trigger.nextTriggerDate()), fire)
    }

    /// Free accounts get today and tomorrow. Watching sunsets only, Up next
    /// showed the day after tomorrow, which the Outlook keeps behind Sun+.
    func testFreeUpNextStopsAtTheOutlooksFreeDays() {
        let now = date(12, day: 10)
        let free = TodayView.upNext(forecast: week(), watched: [.sunset], isPro: false, now: now)
        XCTAssertEqual(free.map(\.time), [date(20, 50, day: 11)])
        let pro = TodayView.upNext(forecast: week(), watched: [.sunset], isPro: true, now: now)
        XCTAssertEqual(pro.map(\.time), [date(20, 50, day: 11), date(20, 50, day: 12)])
        let both = TodayView.upNext(forecast: week(), watched: [.sunrise, .sunset], isPro: false, now: now)
        XCTAssertEqual(both.map(\.time), [date(5, 30, day: 11), date(20, 50, day: 11)])
    }
}

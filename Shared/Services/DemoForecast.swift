#if DEBUG
import Foundation

/// A fixed, good-looking week for screenshots and offline review runs
/// (`-DemoForecast`). Real scorer, made-up skies.
enum DemoForecast {
    static func make(now: Date = .now, zone: TimeZone = .current) -> SunsetForecast {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: now)

        // (low here, mid, high, low toward the sun, humidity, visibility km, rain %)
        let sunsets: [(Double, Double, Double, Double, Double, Double, Double)] = [
            (5, 28, 52, 6, 42, 32, 5), (10, 35, 30, 25, 55, 26, 10), (70, 55, 20, 85, 85, 10, 60),
            (3, 22, 48, 4, 40, 35, 0), (20, 40, 60, 35, 60, 20, 20), (85, 60, 10, 90, 90, 8, 75),
            (8, 30, 45, 15, 50, 28, 5), (15, 25, 40, 20, 52, 24, 10),
        ]
        let sunrises: [(Double, Double, Double, Double, Double, Double, Double)] = [
            (20, 30, 40, 30, 80, 18, 10), (8, 25, 45, 10, 70, 24, 5), (40, 50, 30, 50, 88, 12, 30),
            (60, 40, 10, 70, 92, 9, 40), (10, 30, 55, 12, 68, 22, 5), (5, 20, 50, 5, 65, 28, 0),
            (50, 45, 20, 60, 90, 10, 35), (15, 35, 35, 25, 75, 20, 10),
        ]

        func sky(_ v: (Double, Double, Double, Double, Double, Double, Double)) -> SkyConditions {
            SkyConditions(cloudLow: v.0, cloudMid: v.1, cloudHigh: v.2, cloudLowTowardSun: v.3,
                          humidity: v.4, visibility: v.5 * 1000, precipitationChance: v.6)
        }
        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            let date = calendar.date(byAdding: .day, value: day, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        }

        let days = (0 ..< 8).map { index -> SunsetDay in
            let rise = sky(sunrises[index])
            let set = sky(sunsets[index])
            return SunsetDay(
                sunrise: SunShow(event: .sunrise, time: at(index, 7, 14 + index),
                                 conditions: rise, score: SunsetScorer.score(rise, event: .sunrise)),
                sunset: SunShow(event: .sunset, time: at(index, 18, 31 - 2 * index),
                                conditions: set, score: SunsetScorer.score(set, event: .sunset))
            )
        }
        let events = [
            SkyEvent(kind: .rainbow, start: at(1, 17, 0), end: at(1, 18, 0)),
            SkyEvent(kind: .fog, start: at(2, 6, 0), end: at(2, 9, 0)),
            SkyEvent(kind: .thunderstorm, start: at(2, 15, 0), end: at(2, 18, 0)),
            SkyEvent(kind: .thunderstorm, start: at(5, 14, 0), end: at(5, 16, 0)),
        ]
        return SunsetForecast(latitude: 45.63, longitude: -122.52, placeName: "Vancouver, WA",
                              timeZoneID: zone.identifier, fetched: now, days: days, skyEvents: events)
    }
}
#endif

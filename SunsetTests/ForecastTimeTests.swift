import XCTest
@testable import Sunset

/// Open-Meteo writes every time of a point on one clock, the UTC offset in
/// force when the request was made (`utc_offset_seconds`), for the whole
/// window. A daylight saving change inside the window does not move the labels
/// (24 per day, always), and with `timezone=auto` each of the three points gets
/// its own clock, so an ocean point comes back as an `Etc/GMT` zone.
/// Fixtures follow live responses (2026-10-31).
final class ForecastTimeTests: XCTestCase {
    private func utc(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func local(_ date: Date, _ zone: String) -> (hour: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return (calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }

    private func point(zone: String, offset: Int, days: [String], low: [Double?]? = nil,
                       sunrise: [String], sunset: [String]) -> String {
        let times = days.flatMap { day in (0 ..< 24).map { "\"\(day)T\(String(format: "%02d", $0)):00\"" } }
        func list(_ values: [Double?]) -> String { values.map { $0.map { String($0) } ?? "null" }.joined(separator: ",") }
        func fill(_ value: Double) -> String { list(Array(repeating: value, count: times.count)) }
        func quoted(_ values: [String]) -> String { values.map { "\"\($0)\"" }.joined(separator: ",") }
        return """
        {"timezone":"\(zone)","utc_offset_seconds":\(offset),"hourly":{"time":[\(times.joined(separator: ","))],
        "cloud_cover_low":[\(low.map(list) ?? fill(0))],"cloud_cover_mid":[\(fill(20))],"cloud_cover_high":[\(fill(45))],
        "relative_humidity_2m":[\(fill(50))],"visibility":[\(fill(24_000))],"precipitation_probability":[\(fill(0))]},
        "daily":{"sunrise":[\(quoted(sunrise))],"sunset":[\(quoted(sunset))]}}
        """
    }

    private func parse(_ here: String, west: String? = nil, east: String? = nil) throws -> SunsetForecast {
        let json = "[\(here),\(west ?? here),\(east ?? here)]"
        return try ForecastService.parse(Data(json.utf8), latitude: 45.63, longitude: -122.52)
    }

    /// 2027-03-14 02:00 PST jumps to 03:00 PDT. A request made on the 13th is
    /// labelled on the -8 h clock, so the 14th still has a 02:00 row, a local
    /// time that does not exist in Los Angeles. The whole forecast used to be
    /// refused for the week before the change (and on the day itself).
    func testTheWeekBeforeSpringForwardStillLoads() throws {
        let here = point(zone: "America/Los_Angeles", offset: -28_800, days: ["2027-03-13", "2027-03-14"],
                         sunrise: ["2027-03-13T06:26", "2027-03-14T06:24"],
                         sunset: ["2027-03-13T18:13", "2027-03-14T18:14"])
        let forecast = try parse(here)

        XCTAssertEqual(forecast.days.count, 2)
        XCTAssertEqual(forecast.timeZoneID, "America/Los_Angeles")
        // 18:14 on the -8 h clock is 02:14 UTC: 7:14 PM once the clocks moved.
        let sunset = forecast.days[1].sunset.time
        XCTAssertEqual(sunset, utc("2027-03-15T02:14:00Z"))
        XCTAssertEqual(local(sunset, "America/Los_Angeles").hour, 19)
        XCTAssertEqual(local(forecast.days[1].sunrise.time, "America/Los_Angeles").hour, 7)
    }

    /// 2026-11-01 02:00 PDT falls back to 01:00 PST. A request made on the 31st
    /// is labelled on the -7 h clock for all of it, so the 1st's 17:56 is
    /// 16:56 in Los Angeles. It used to be read as 17:56 PST, an hour late:
    /// the sunset shown, the best-light window and the alert all an hour off.
    func testTheWeekBeforeFallBackKeepsTheRealMoments() throws {
        let here = point(zone: "America/Los_Angeles", offset: -25_200, days: ["2026-10-31", "2026-11-01"],
                         sunrise: ["2026-10-31T07:48", "2026-11-01T07:50"],
                         sunset: ["2026-10-31T17:58", "2026-11-01T17:56"])
        let forecast = try parse(here)

        XCTAssertEqual(forecast.days.count, 2)
        let before = forecast.days[0]
        XCTAssertEqual(before.sunset.time, utc("2026-11-01T00:58:00Z"))
        XCTAssertEqual(local(before.sunset.time, "America/Los_Angeles").hour, 17)

        let after = forecast.days[1]
        XCTAssertEqual(after.sunset.time, utc("2026-11-02T00:56:00Z"))
        XCTAssertEqual(local(after.sunset.time, "America/Los_Angeles").hour, 16)
        XCTAssertEqual(after.sunrise.time, utc("2026-11-01T14:50:00Z"))
        XCTAssertEqual(local(after.sunrise.time, "America/Los_Angeles").hour, 6)
        // Best light is written around the real sunset too.
        XCTAssertEqual(after.sunset.bestWindowStart, utc("2026-11-02T00:46:00Z"))
    }

    /// An ocean point is resolved to an `Etc/GMT` zone, one hour behind Los
    /// Angeles in daylight saving time (San Diego sunsets, Honolulu, Lisbon,
    /// Cape Town and every east-coast sunrise do the same). Its rows must be
    /// matched by moment, not by position.
    func testASunwardPointOnAnotherClockIsReadAtTheSameMoment() throws {
        var westLow = Array(repeating: Double?(0), count: 48)
        // West labels 17:00 and 18:00 on the -8 h clock are 18:00 and 19:00 PDT.
        westLow[17] = 90
        westLow[18] = 90
        let days = ["2026-10-08", "2026-10-09"]
        let here = point(zone: "America/Los_Angeles", offset: -25_200, days: days,
                         sunrise: ["2026-10-08T07:18", "2026-10-09T07:19"],
                         sunset: ["2026-10-08T18:30", "2026-10-09T18:28"])
        let west = point(zone: "Etc/GMT+8", offset: -28_800, days: days, low: westLow,
                         sunrise: ["2026-10-08T06:18", "2026-10-09T06:19"],
                         sunset: ["2026-10-08T17:30", "2026-10-09T17:28"])
        let forecast = try parse(here, west: west)

        XCTAssertEqual(forecast.days[0].sunset.conditions.cloudLowTowardSun, 90, accuracy: 0.01)
        XCTAssertEqual(forecast.days[0].sunset.conditions.cloudLow, 0, accuracy: 0.01)
    }

    /// The east point one hour ahead (Denver beside Los Angeles) for a sunrise.
    func testAnEastPointAheadOfTheUserIsReadAtTheSameMoment() throws {
        var eastLow = Array(repeating: Double?(0), count: 48)
        // East labels 08:00 and 09:00 on the -6 h clock are 07:00 and 08:00 PDT.
        eastLow[8] = 80
        eastLow[9] = 80
        let days = ["2026-10-08", "2026-10-09"]
        let here = point(zone: "America/Los_Angeles", offset: -25_200, days: days,
                         sunrise: ["2026-10-08T07:18", "2026-10-09T07:19"],
                         sunset: ["2026-10-08T18:30", "2026-10-09T18:28"])
        let east = point(zone: "America/Denver", offset: -21_600, days: days, low: eastLow,
                         sunrise: ["2026-10-08T08:18", "2026-10-09T08:19"],
                         sunset: ["2026-10-08T19:30", "2026-10-09T19:28"])
        let forecast = try parse(here, east: east)

        XCTAssertEqual(forecast.days[0].sunrise.conditions.cloudLowTowardSun, 80, accuracy: 0.01)
    }

    /// Clocks half an hour apart blend the sunward rows at the moment instead
    /// of snapping to one. St. John's keeps UTC-2:30 in summer; the Atlantic
    /// east of it is `Etc/GMT+3`.
    func testRowsAHalfHourApartAreBlendedAtTheMoment() throws {
        let ramp = (0 ..< 48).map { Double?(Double($0 % 24) * 4) }
        let days = ["2026-10-08", "2026-10-09"]
        let here = point(zone: "America/St_Johns", offset: -9_000, days: days,
                         sunrise: ["2026-10-08T07:18", "2026-10-09T07:19"],
                         sunset: ["2026-10-08T18:40", "2026-10-09T18:28"])
        let east = point(zone: "Etc/GMT+3", offset: -10_800, days: days, low: ramp,
                         sunrise: ["2026-10-08T06:48", "2026-10-09T06:49"],
                         sunset: ["2026-10-08T18:10", "2026-10-09T17:58"])
        let forecast = try parse(here, east: east)

        // 07:18 on the -2:30 clock is 09:48 UTC, label 06:48 on the -3:00
        // clock: rows 06 (24) and 07 (28), 0.8 of the way between them.
        XCTAssertEqual(forecast.days[0].sunrise.conditions.cloudLowTowardSun, 27.2, accuracy: 0.01)
    }

    /// Older responses and cached fixtures carry no offset: the named zone
    /// still reads them, as before.
    func testWithoutAnOffsetTheNamedZoneReadsTheLabels() throws {
        let json = point(zone: "America/Los_Angeles", offset: 0, days: ["2026-10-08", "2026-10-09"],
                         sunrise: ["2026-10-08T07:18", "2026-10-09T07:19"],
                         sunset: ["2026-10-08T18:30", "2026-10-09T18:28"])
            .replacingOccurrences(of: "\"utc_offset_seconds\":0,", with: "")
        let forecast = try parse(json)

        XCTAssertEqual(forecast.days[0].sunset.time, utc("2026-10-09T01:30:00Z"))
    }
}

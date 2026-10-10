import XCTest
@testable import Sunset

final class ForecastServiceTests: XCTestCase {
    private func point(timezone: String, lows: [Double?], highs: [Double?], codes: [Double?]? = nil) -> String {
        let hours = (0 ..< 48).map { hour -> String in
            let day = hour < 24 ? "2026-10-08" : "2026-10-09"
            return "\"\(day)T\(String(format: "%02d", hour % 24)):00\""
        }
        func list(_ values: [Double?]) -> String {
            values.map { $0.map { String($0) } ?? "null" }.joined(separator: ",")
        }
        let codeList = codes.map { ",\"weather_code\":[\(list($0))]" } ?? ""
        return """
        {"timezone":"\(timezone)","hourly":{"time":[\(hours.joined(separator: ","))],
        "cloud_cover_low":[\(list(lows))],"cloud_cover_mid":[\(list(Array(repeating: 20, count: 48)))],
        "cloud_cover_high":[\(list(highs))],"relative_humidity_2m":[\(list(Array(repeating: 50, count: 48)))],
        "visibility":[\(list(Array(repeating: 24140, count: 48)))],"precipitation_probability":[\(list(Array(repeating: 0, count: 48)))]\(codeList)},
        "daily":{"sunrise":["2026-10-08T07:18","2026-10-09T07:19"],"sunset":["2026-10-08T18:30","2026-10-09T18:28"]}}
        """
    }

    private var zero: [Double?] { Array(repeating: Double?(0), count: 48) }

    func testParsesThreePointsAndScoresEachShowAgainstItsOwnHorizon() throws {
        var highs = zero
        highs[7] = 40
        highs[8] = 40
        highs[18] = 40
        highs[19] = 60
        var westLows = zero
        westLows[18] = 90
        westLows[19] = 90
        var eastLows = zero
        eastLows[7] = 70
        eastLows[8] = 70
        let json = "[\(point(timezone: "America/Los_Angeles", lows: zero, highs: highs)),"
            + "\(point(timezone: "America/Los_Angeles", lows: westLows, highs: highs)),"
            + "\(point(timezone: "America/Los_Angeles", lows: eastLows, highs: highs))]"

        let forecast = try ForecastService.parse(Data(json.utf8), latitude: 45.63, longitude: -122.52, now: .now)

        XCTAssertEqual(forecast.days.count, 2)
        XCTAssertEqual(forecast.timeZoneID, "America/Los_Angeles")
        let sunset = forecast.days[0].sunset
        // 18:30 sits halfway between the 18:00 and 19:00 rows.
        XCTAssertEqual(sunset.event, .sunset)
        XCTAssertEqual(sunset.conditions.cloudHigh, 50, accuracy: 0.01)
        XCTAssertEqual(sunset.conditions.cloudLowTowardSun, 90, accuracy: 0.01)
        XCTAssertEqual(sunset.conditions.cloudLow, 0, accuracy: 0.01)
        XCTAssertLessThan(sunset.score.total, 45)

        let sunrise = forecast.days[0].sunrise
        XCTAssertEqual(sunrise.event, .sunrise)
        XCTAssertEqual(sunrise.conditions.cloudLowTowardSun, 70, accuracy: 0.01)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(calendar.component(.hour, from: sunset.time), 18)
        XCTAssertEqual(calendar.component(.minute, from: sunset.time), 30)
        XCTAssertEqual(calendar.component(.hour, from: sunrise.time), 7)
    }

    func testMissingValuesFallBackInsteadOfFailing() throws {
        let empty = Array(repeating: Double?(nil), count: 48)
        let one = point(timezone: "Europe/London", lows: empty, highs: empty)
        let forecast = try ForecastService.parse(Data("[\(one),\(one),\(one)]".utf8), latitude: 51.5, longitude: -0.1)
        XCTAssertEqual(forecast.days.first?.sunset.conditions.cloudHigh, 0)
        XCTAssertEqual(forecast.skyEvents, [])
    }

    func testThunderstormHoursBecomeOneEvent() throws {
        var codes = Array(repeating: Double?(1), count: 48)
        codes[15] = 95
        codes[16] = 95
        codes[17] = 96
        let here = point(timezone: "America/Chicago", lows: zero, highs: zero, codes: codes)
        let other = point(timezone: "America/Chicago", lows: zero, highs: zero)
        let forecast = try ForecastService.parse(Data("[\(here),\(other),\(other)]".utf8), latitude: 41.9, longitude: -87.6)
        let storms = forecast.skyEvents.filter { $0.kind == .thunderstorm }
        XCTAssertEqual(storms.count, 1)
        XCTAssertEqual(storms.first.map { $0.end.timeIntervalSince($0.start) }, 3 * 3600)
    }

    func testFewerThanThreePointsIsRejected() {
        let one = point(timezone: "Europe/London", lows: zero, highs: zero)
        XCTAssertThrowsError(try ForecastService.parse(Data(one.utf8), latitude: 0, longitude: 0))
        XCTAssertThrowsError(try ForecastService.parse(Data("[\(one),\(one)]".utf8), latitude: 0, longitude: 0))
    }

    func testOffsetPointsMoveAboutEightyKilometres() {
        let west = ForecastService.westPoint(latitude: 45.63, longitude: -122.52)
        XCTAssertEqual(west.latitude, 45.63)
        XCTAssertEqual(west.longitude, -123.55, accuracy: 0.02)
        let east = ForecastService.eastPoint(latitude: 45.63, longitude: -122.52)
        XCTAssertEqual(east.longitude, -121.49, accuracy: 0.02)
        let polar = ForecastService.westPoint(latitude: 89, longitude: 0)
        XCTAssertGreaterThanOrEqual(polar.longitude, -3)
        XCTAssertGreaterThan(ForecastService.westPoint(latitude: 0, longitude: -179.9).longitude, 0)
        XCTAssertLessThan(ForecastService.eastPoint(latitude: 0, longitude: 179.9).longitude, 0)
    }

    func testURLSendsRoundedCoordinatesAndAllThreePoints() throws {
        let url = try ForecastService.url(latitude: 45.63412, longitude: -122.52199, days: 8)
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("latitude=45.63,45.63,45.63"))
        XCTAssertTrue(query.contains("longitude=-122.52,-123.55,-121.49"))
        XCTAssertTrue(query.contains("cloud_cover_high"))
        XCTAssertTrue(query.contains("weather_code"))
        XCTAssertTrue(query.contains("forecast_days=8"))
    }

    func testUpcomingShowsSkipFinishedOnesAndRespectWatched() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func show(_ event: SunEvent, _ offset: TimeInterval) -> SunShow {
            SunShow(event: event, time: now.addingTimeInterval(offset), conditions: .clear, score: SunsetScorer.score(.clear))
        }
        let today = SunsetDay(sunrise: show(.sunrise, -10 * 3600), sunset: show(.sunset, -3600))
        let tomorrow = SunsetDay(sunrise: show(.sunrise, 10 * 3600), sunset: show(.sunset, 22 * 3600))
        let forecast = SunsetForecast(latitude: 0, longitude: 0, placeName: nil, timeZoneID: "UTC",
                                      fetched: now, days: [today, tomorrow], skyEvents: [])
        XCTAssertEqual(forecast.upcomingShows(from: now).first, tomorrow.sunrise)
        XCTAssertEqual(forecast.upcomingShows([.sunset], from: now).first, tomorrow.sunset)
        XCTAssertEqual(forecast.upcomingShows([.sunset], from: now.addingTimeInterval(-3600 - 20 * 60)).first, today.sunset)
        XCTAssertEqual(forecast.upcomingDays(from: now), [tomorrow])
    }
}

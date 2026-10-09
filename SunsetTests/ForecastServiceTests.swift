import XCTest
@testable import Sunset

final class ForecastServiceTests: XCTestCase {
    private func point(timezone: String, lows: [Double?], highs: [Double?]) -> String {
        let hours = (0 ..< 48).map { hour -> String in
            let day = hour < 24 ? "2026-10-08" : "2026-10-09"
            return "\"\(day)T\(String(format: "%02d", hour % 24)):00\""
        }
        func list(_ values: [Double?]) -> String {
            values.map { $0.map { String($0) } ?? "null" }.joined(separator: ",")
        }
        return """
        {"timezone":"\(timezone)","hourly":{"time":[\(hours.joined(separator: ","))],
        "cloud_cover_low":[\(list(lows))],"cloud_cover_mid":[\(list(Array(repeating: 20, count: 48)))],
        "cloud_cover_high":[\(list(highs))],"relative_humidity_2m":[\(list(Array(repeating: 50, count: 48)))],
        "visibility":[\(list(Array(repeating: 24140, count: 48)))],"precipitation_probability":[\(list(Array(repeating: 0, count: 48)))]},
        "daily":{"sunrise":["2026-10-08T07:18","2026-10-09T07:19"],"sunset":["2026-10-08T18:30","2026-10-09T18:28"]}}
        """
    }

    func testParsesTwoPointsAndScoresSunsetHour() throws {
        var lows = Array(repeating: Double?(0), count: 48)
        var highs = Array(repeating: Double?(0), count: 48)
        highs[18] = 40
        highs[19] = 60
        lows[18] = 0
        var westLows = Array(repeating: Double?(0), count: 48)
        westLows[18] = 90
        westLows[19] = 90
        let json = "[\(point(timezone: "America/Los_Angeles", lows: lows, highs: highs)),\(point(timezone: "America/Los_Angeles", lows: westLows, highs: highs))]"

        let forecast = try ForecastService.parse(Data(json.utf8), latitude: 45.63, longitude: -122.52, now: .now)

        XCTAssertEqual(forecast.days.count, 2)
        XCTAssertEqual(forecast.timeZoneID, "America/Los_Angeles")
        let tonight = forecast.days[0]
        // 18:30 sits halfway between the 18:00 and 19:00 rows.
        XCTAssertEqual(tonight.conditions.cloudHigh, 50, accuracy: 0.01)
        XCTAssertEqual(tonight.conditions.cloudLowWest, 90, accuracy: 0.01)
        XCTAssertEqual(tonight.conditions.cloudLow, 0, accuracy: 0.01)
        XCTAssertLessThan(tonight.score.total, 45)

        var zone = Calendar(identifier: .gregorian)
        zone.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(zone.component(.hour, from: tonight.sunset), 18)
        XCTAssertEqual(zone.component(.minute, from: tonight.sunset), 30)
    }

    func testMissingValuesFallBackInsteadOfFailing() throws {
        let lows = Array(repeating: Double?(nil), count: 48)
        let highs = Array(repeating: Double?(nil), count: 48)
        let json = "[\(point(timezone: "Europe/London", lows: lows, highs: highs)),\(point(timezone: "Europe/London", lows: lows, highs: highs))]"
        let forecast = try ForecastService.parse(Data(json.utf8), latitude: 51.5, longitude: -0.1)
        XCTAssertEqual(forecast.days.first?.conditions.cloudHigh, 0)
    }

    func testSinglePointResponseIsRejected() {
        let json = point(timezone: "Europe/London", lows: [], highs: [])
        XCTAssertThrowsError(try ForecastService.parse(Data(json.utf8), latitude: 0, longitude: 0))
    }

    func testWestPointMovesAboutEightyKilometres() {
        let west = ForecastService.westPoint(latitude: 45.63, longitude: -122.52)
        XCTAssertEqual(west.latitude, 45.63)
        XCTAssertEqual(west.longitude, -123.55, accuracy: 0.02)
        let polar = ForecastService.westPoint(latitude: 89, longitude: 0)
        XCTAssertGreaterThanOrEqual(polar.longitude, -3)
        let wrap = ForecastService.westPoint(latitude: 0, longitude: -179.9)
        XCTAssertGreaterThan(wrap.longitude, 0)
    }

    func testURLSendsRoundedCoordinatesAndBothPoints() throws {
        let url = try ForecastService.url(latitude: 45.63412, longitude: -122.52199, days: 8)
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("latitude=45.63,45.63"))
        XCTAssertTrue(query.contains("longitude=-122.52,-123.55"))
        XCTAssertTrue(query.contains("cloud_cover_high"))
        XCTAssertTrue(query.contains("forecast_days=8"))
    }

    func testUpcomingSkipsFinishedSunsets() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let past = SunsetDay(sunrise: now, sunset: now.addingTimeInterval(-3600), conditions: .clear, score: SunsetScorer.score(.clear))
        let next = SunsetDay(sunrise: now, sunset: now.addingTimeInterval(20 * 3600), conditions: .clear, score: SunsetScorer.score(.clear))
        let forecast = SunsetForecast(latitude: 0, longitude: 0, placeName: nil, timeZoneID: "UTC", fetched: now, days: [past, next])
        XCTAssertEqual(forecast.upcoming(from: now)?.sunset, next.sunset)
        XCTAssertEqual(forecast.upcoming(from: now.addingTimeInterval(-3600 - 20 * 60))?.sunset, past.sunset)
    }
}

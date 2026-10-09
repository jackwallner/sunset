import Foundation

/// Fetches the sunset-hour sky from Open-Meteo and scores each evening.
///
/// One request carries two points: the user's location and a point about
/// 80 km toward the sunset, whose low cloud decides whether the light gets
/// through at all. No key, no account, and only rounded coordinates leave the
/// device.
enum ForecastService {
    enum Failure: Error, Equatable {
        case badResponse
        case noSunset
    }

    static let westOffsetKilometres = 80.0

    static func fetch(latitude: Double, longitude: Double, days: Int = 8) async throws -> SunsetForecast {
        let request = URLRequest(url: try url(latitude: latitude, longitude: longitude, days: days))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw Failure.badResponse
        }
        return try parse(data, latitude: latitude, longitude: longitude)
    }

    static func url(latitude: Double, longitude: Double, days: Int) throws -> URL {
        let here = rounded(latitude: latitude, longitude: longitude)
        let west = westPoint(latitude: here.latitude, longitude: here.longitude)
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(here.latitude),\(west.latitude)"),
            URLQueryItem(name: "longitude", value: "\(here.longitude),\(west.longitude)"),
            URLQueryItem(name: "hourly", value: "cloud_cover_low,cloud_cover_mid,cloud_cover_high,relative_humidity_2m,visibility,precipitation_probability"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: String(days)),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    /// Two decimals is about a kilometre, which is all a regional cloud
    /// forecast can resolve anyway.
    static func rounded(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        ((latitude * 100).rounded() / 100, (longitude * 100).rounded() / 100)
    }

    static func westPoint(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        let kmPerDegree = 111.32 * max(0.2, cos(latitude * .pi / 180))
        let offset = min(3, westOffsetKilometres / kmPerDegree)
        var lon = longitude - offset
        if lon < -180 { lon += 360 }
        return (latitude, (lon * 100).rounded() / 100)
    }

    static func parse(_ data: Data, latitude: Double, longitude: Double, now: Date = .now) throws -> SunsetForecast {
        let decoded = try JSONDecoder().decode([OpenMeteoPoint].self, from: data)
        guard decoded.count == 2 else { throw Failure.badResponse }
        let here = decoded[0]
        let west = decoded[1]
        guard let zone = TimeZone(identifier: here.timezone) else { throw Failure.badResponse }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourDates = here.hourly.time.compactMap { formatter.date(from: $0) }
        guard hourDates.count == here.hourly.time.count, !hourDates.isEmpty else { throw Failure.badResponse }

        var days: [SunsetDay] = []
        for (index, sunsetString) in here.daily.sunset.enumerated() {
            guard let sunset = formatter.date(from: sunsetString),
                  index < here.daily.sunrise.count,
                  let sunrise = formatter.date(from: here.daily.sunrise[index]) else { continue }
            guard let position = hourDates.lastIndex(where: { $0 <= sunset }) else { continue }
            let next = min(position + 1, hourDates.count - 1)
            let weight = next == position ? 0 : sunset.timeIntervalSince(hourDates[position]) / 3600
            let before = conditions(here, west, at: position)
            let after = conditions(here, west, at: next)
            let sky = SunsetScorer.interpolate(before, after, weight: weight)
            days.append(SunsetDay(sunrise: sunrise, sunset: sunset, conditions: sky, score: SunsetScorer.score(sky)))
        }
        guard !days.isEmpty else { throw Failure.noSunset }

        return SunsetForecast(
            latitude: latitude, longitude: longitude, placeName: nil,
            timeZoneID: here.timezone, fetched: now, days: days
        )
    }

    private static func conditions(_ here: OpenMeteoPoint, _ west: OpenMeteoPoint, at index: Int) -> SkyConditions {
        func value(_ array: [Double?], _ fallback: Double) -> Double {
            guard index < array.count, let v = array[index] else { return fallback }
            return v
        }
        return SkyConditions(
            cloudLow: value(here.hourly.cloudLow, 0),
            cloudMid: value(here.hourly.cloudMid, 0),
            cloudHigh: value(here.hourly.cloudHigh, 0),
            cloudLowWest: value(west.hourly.cloudLow, value(here.hourly.cloudLow, 0)),
            humidity: value(here.hourly.humidity, 60),
            visibility: value(here.hourly.visibility, 20_000),
            precipitationChance: value(here.hourly.precipitationChance, 0)
        )
    }
}

struct OpenMeteoPoint: Decodable {
    let timezone: String
    let hourly: Hourly
    let daily: Daily

    struct Hourly: Decodable {
        let time: [String]
        let cloudLow: [Double?]
        let cloudMid: [Double?]
        let cloudHigh: [Double?]
        let humidity: [Double?]
        let visibility: [Double?]
        let precipitationChance: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case cloudLow = "cloud_cover_low"
            case cloudMid = "cloud_cover_mid"
            case cloudHigh = "cloud_cover_high"
            case humidity = "relative_humidity_2m"
            case visibility
            case precipitationChance = "precipitation_probability"
        }
    }

    struct Daily: Decodable {
        let sunrise: [String]
        let sunset: [String]
    }
}

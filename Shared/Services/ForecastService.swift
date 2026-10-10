import Foundation

/// Fetches the sky from Open-Meteo, scores each sunrise and sunset, and
/// picks out storms, rainbow chances and fog.
///
/// One request carries three points: the user's location and points about
/// 80 km west and east, whose low cloud decides whether the sunset and
/// sunrise light gets through at all. No key, no account, and only rounded
/// coordinates leave the device.
enum ForecastService {
    enum Failure: Error, Equatable {
        case badResponse
        case noSunset
    }

    static let sunwardOffsetKilometres = 80.0

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
        let east = eastPoint(latitude: here.latitude, longitude: here.longitude)
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(here.latitude),\(west.latitude),\(east.latitude)"),
            URLQueryItem(name: "longitude", value: "\(here.longitude),\(west.longitude),\(east.longitude)"),
            URLQueryItem(name: "hourly", value: "cloud_cover_low,cloud_cover_mid,cloud_cover_high,relative_humidity_2m,visibility,precipitation_probability,precipitation,cloud_cover,weather_code"),
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
        offsetPoint(latitude: latitude, longitude: longitude, sign: -1)
    }

    static func eastPoint(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        offsetPoint(latitude: latitude, longitude: longitude, sign: 1)
    }

    private static func offsetPoint(latitude: Double, longitude: Double, sign: Double) -> (latitude: Double, longitude: Double) {
        let kmPerDegree = 111.32 * max(0.2, cos(latitude * .pi / 180))
        let offset = min(3, sunwardOffsetKilometres / kmPerDegree)
        var lon = longitude + sign * offset
        if lon < -180 { lon += 360 }
        if lon > 180 { lon -= 360 }
        return (latitude, (lon * 100).rounded() / 100)
    }

    static func parse(_ data: Data, latitude: Double, longitude: Double, now: Date = .now) throws -> SunsetForecast {
        let decoded = try JSONDecoder().decode([OpenMeteoPoint].self, from: data)
        guard decoded.count == 3 else { throw Failure.badResponse }
        let here = decoded[0]
        let west = decoded[1]
        let east = decoded[2]
        guard let zone = TimeZone(identifier: here.timezone) else { throw Failure.badResponse }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourDates = here.hourly.time.compactMap { formatter.date(from: $0) }
        guard hourDates.count == here.hourly.time.count, !hourDates.isEmpty else { throw Failure.badResponse }

        func show(_ event: SunEvent, at time: Date) -> SunShow? {
            guard let position = hourDates.lastIndex(where: { $0 <= time }) else { return nil }
            let toward = event == .sunset ? west : east
            let next = min(position + 1, hourDates.count - 1)
            let weight = next == position ? 0 : time.timeIntervalSince(hourDates[position]) / 3600
            let sky = SunsetScorer.interpolate(
                conditions(here, toward, at: position),
                conditions(here, toward, at: next),
                weight: weight
            )
            return SunShow(event: event, time: time, conditions: sky, score: SunsetScorer.score(sky, event: event))
        }

        var days: [SunsetDay] = []
        for (index, sunsetString) in here.daily.sunset.enumerated() {
            guard let sunsetTime = formatter.date(from: sunsetString),
                  index < here.daily.sunrise.count,
                  let sunriseTime = formatter.date(from: here.daily.sunrise[index]),
                  let sunset = show(.sunset, at: sunsetTime),
                  let sunrise = show(.sunrise, at: sunriseTime) else { continue }
            days.append(SunsetDay(sunrise: sunrise, sunset: sunset))
        }
        guard !days.isEmpty else { throw Failure.noSunset }

        let hours = hourDates.indices.map { index in
            SkyEventDetector.Hour(
                time: hourDates[index],
                weatherCode: here.hourly.weatherCode?.element(index).map { Int($0) },
                cloudCover: here.hourly.cloudCover?.element(index),
                precipitation: here.hourly.precipitation?.element(index),
                precipitationChance: here.hourly.precipitationChance.element(index),
                visibility: here.hourly.visibility.element(index)
            )
        }

        return SunsetForecast(
            latitude: latitude, longitude: longitude, placeName: nil,
            timeZoneID: here.timezone, fetched: now, days: days,
            skyEvents: SkyEventDetector.detect(hours, latitude: latitude, longitude: longitude)
        )
    }

    private static func conditions(_ here: OpenMeteoPoint, _ toward: OpenMeteoPoint, at index: Int) -> SkyConditions {
        func value(_ array: [Double?], _ fallback: Double) -> Double {
            guard index < array.count, let v = array[index] else { return fallback }
            return v
        }
        return SkyConditions(
            cloudLow: value(here.hourly.cloudLow, 0),
            cloudMid: value(here.hourly.cloudMid, 0),
            cloudHigh: value(here.hourly.cloudHigh, 0),
            cloudLowTowardSun: value(toward.hourly.cloudLow, value(here.hourly.cloudLow, 0)),
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
        /// Optional so an older cached response shape still decodes.
        let precipitation: [Double?]?
        let cloudCover: [Double?]?
        let weatherCode: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case cloudLow = "cloud_cover_low"
            case cloudMid = "cloud_cover_mid"
            case cloudHigh = "cloud_cover_high"
            case humidity = "relative_humidity_2m"
            case visibility
            case precipitationChance = "precipitation_probability"
            case precipitation
            case cloudCover = "cloud_cover"
            case weatherCode = "weather_code"
        }
    }

    struct Daily: Decodable {
        let sunrise: [String]
        let sunset: [String]
    }
}

private extension Array where Element == Double? {
    func element(_ index: Int) -> Double? {
        index < count ? self[index] : nil
    }
}

import Foundation

let sunsetAppGroupID = "group.com.jackwallner.sunset"

/// The sky at sunset, as the forecast models see it. Every value is 0 to 100
/// except `visibility`, which is metres.
struct SkyConditions: Codable, Equatable, Sendable {
    /// Local cloud cover by altitude band.
    var cloudLow: Double
    var cloudMid: Double
    var cloudHigh: Double
    /// Low cloud roughly 80 km toward the sunset. The last light reaches you
    /// from that direction, so a bank of stratus there hides the show even
    /// when the sky overhead is open.
    var cloudLowWest: Double
    var humidity: Double
    var visibility: Double
    var precipitationChance: Double

    static let clear = SkyConditions(
        cloudLow: 0, cloudMid: 0, cloudHigh: 0, cloudLowWest: 0,
        humidity: 40, visibility: 30_000, precipitationChance: 0
    )
}

/// How the sunset is expected to look, 0 to 100, with the factors behind it.
struct SunsetScore: Codable, Equatable, Sendable {
    var total: Int
    var color: Int
    var streaks: Int
    var horizon: Int
    var clarity: Int
    var rainChance: Int
    var summary: String

    enum Grade: String, Codable, Sendable, CaseIterable {
        case dull = "Dull"
        case fair = "Fair"
        case good = "Good"
        case great = "Great"
        case epic = "Epic"

        init(total: Int) {
            switch total {
            case ..<30: self = .dull
            case ..<50: self = .fair
            case ..<70: self = .good
            case ..<85: self = .great
            default: self = .epic
            }
        }
    }

    var grade: Grade { Grade(total: total) }

    struct Factor: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let value: Int
        let detail: String
    }

    var factors: [Factor] {
        [
            Factor(id: "color", name: "Color", value: color,
                   detail: "High and mid clouds that catch the light"),
            Factor(id: "streaks", name: "Streaks", value: streaks,
                   detail: "Thin cirrus with room to glow"),
            Factor(id: "horizon", name: "Horizon", value: horizon,
                   detail: "Open sky toward the sun"),
            Factor(id: "clarity", name: "Clarity", value: clarity,
                   detail: "Dry, clean air for vivid tones"),
        ]
    }
}

/// One evening: when the sun sets and what the sky should do.
struct SunsetDay: Codable, Equatable, Identifiable, Sendable {
    var sunrise: Date
    var sunset: Date
    var conditions: SkyConditions
    var score: SunsetScore

    var id: Date { sunset }

    /// The light peaks just after the sun drops, so the window to be outside
    /// opens shortly before and runs past sunset.
    var bestWindowStart: Date { sunset.addingTimeInterval(-10 * 60) }
    var bestWindowEnd: Date { sunset.addingTimeInterval(25 * 60) }
}

struct SunsetForecast: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var placeName: String?
    var timeZoneID: String
    var fetched: Date
    var days: [SunsetDay]

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The next sunset that has not finished yet, so the hero never shows a
    /// sunset that already happened. "Tonight" rolls to tomorrow half an hour
    /// after the sun is down.
    func upcoming(from now: Date = .now) -> SunsetDay? {
        days.first { $0.sunset.addingTimeInterval(30 * 60) > now }
    }

    func isStale(now: Date = .now, maxAge: TimeInterval = 3 * 3600) -> Bool {
        now.timeIntervalSince(fetched) > maxAge
    }
}

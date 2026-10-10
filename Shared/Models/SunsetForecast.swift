import Foundation

let sunsetAppGroupID = "group.com.jackwallner.sunset"

/// The two shows a day puts on. Sunrise light comes from the east, sunset
/// light from the west, so each is scored against its own horizon.
enum SunEvent: String, Codable, CaseIterable, Sendable {
    case sunrise
    case sunset

    var title: String {
        switch self {
        case .sunrise: "Sunrise"
        case .sunset: "Sunset"
        }
    }

    var symbol: String {
        switch self {
        case .sunrise: "sunrise.fill"
        case .sunset: "sunset.fill"
        }
    }

    /// The side the light arrives from, for copy.
    var direction: String {
        switch self {
        case .sunrise: "east"
        case .sunset: "west"
        }
    }
}

/// The sky at sunrise or sunset, as the forecast models see it. Every value
/// is 0 to 100 except `visibility`, which is metres.
struct SkyConditions: Codable, Equatable, Sendable {
    /// Local cloud cover by altitude band.
    var cloudLow: Double
    var cloudMid: Double
    var cloudHigh: Double
    /// Low cloud roughly 80 km toward the sun (west at sunset, east at
    /// sunrise). The light reaches you from that direction, so a bank of
    /// stratus there hides the show even when the sky overhead is open.
    var cloudLowTowardSun: Double
    var humidity: Double
    var visibility: Double
    var precipitationChance: Double

    static let clear = SkyConditions(
        cloudLow: 0, cloudMid: 0, cloudHigh: 0, cloudLowTowardSun: 0,
        humidity: 40, visibility: 30_000, precipitationChance: 0
    )
}

/// How the sky is expected to look, 0 to 100, with the factors behind it.
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

/// One sunrise or one sunset: when it happens and what the sky should do.
struct SunShow: Codable, Equatable, Identifiable, Sendable {
    var event: SunEvent
    var time: Date
    var conditions: SkyConditions
    var score: SunsetScore

    var id: Date { time }

    /// Color peaks just before sunrise and just after sunset, so the window
    /// leans to the dark side of the moment.
    var bestWindowStart: Date {
        time.addingTimeInterval(event == .sunset ? -10 * 60 : -25 * 60)
    }

    var bestWindowEnd: Date {
        time.addingTimeInterval(event == .sunset ? 25 * 60 : 10 * 60)
    }

    /// A show stays "current" until half an hour after the moment, then the
    /// next one takes over.
    func isOver(at now: Date) -> Bool {
        time.addingTimeInterval(30 * 60) <= now
    }
}

/// Weather worth looking up for, beyond the sunrise and sunset.
struct SkyEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case thunderstorm
        case rainbow
        case fog

        var title: String {
            switch self {
            case .thunderstorm: "Thunderstorms"
            case .rainbow: "Rainbow chance"
            case .fog: "Fog"
            }
        }

        var symbol: String {
            switch self {
            case .thunderstorm: "cloud.bolt.fill"
            case .rainbow: "rainbow"
            case .fog: "cloud.fog.fill"
            }
        }

        var detail: String {
            switch self {
            case .thunderstorm: "Lightning in the forecast near you"
            case .rainbow: "Showers with a low sun breaking through"
            case .fog: "Low visibility that softens the light"
            }
        }
    }

    var kind: Kind
    var start: Date
    var end: Date

    var id: String { "\(kind.rawValue)-\(Int(start.timeIntervalSince1970))" }
}

/// One calendar day: its sunrise, its sunset.
struct SunsetDay: Codable, Equatable, Identifiable, Sendable {
    var sunrise: SunShow
    var sunset: SunShow

    var id: Date { sunset.time }

    func show(_ event: SunEvent) -> SunShow {
        event == .sunrise ? sunrise : sunset
    }
}

struct SunsetForecast: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var placeName: String?
    var timeZoneID: String
    var fetched: Date
    var days: [SunsetDay]
    var skyEvents: [SkyEvent]

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// Every watched sunrise and sunset that is not over yet, in order, so
    /// the hero never shows a show that already happened.
    func upcomingShows(_ events: Set<SunEvent> = Set(SunEvent.allCases), from now: Date = .now) -> [SunShow] {
        days.flatMap { [$0.sunrise, $0.sunset] }
            .filter { events.contains($0.event) && !$0.isOver(at: now) }
            .sorted { $0.time < $1.time }
    }

    /// The days from today on, dropping a day once both its shows are over.
    func upcomingDays(from now: Date = .now) -> [SunsetDay] {
        days.filter { !$0.sunset.isOver(at: now) }
    }

    func upcomingSkyEvents(from now: Date = .now, within interval: TimeInterval? = nil) -> [SkyEvent] {
        skyEvents.filter { event in
            event.end > now && (interval.map { event.start < now.addingTimeInterval($0) } ?? true)
        }
    }

    func skyEvents(on day: SunsetDay) -> [SkyEvent] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return skyEvents.filter { calendar.isDate($0.start, inSameDayAs: day.sunset.time) }
    }

    func isStale(now: Date = .now, maxAge: TimeInterval = 3 * 3600) -> Bool {
        now.timeIntervalSince(fetched) > maxAge
    }
}

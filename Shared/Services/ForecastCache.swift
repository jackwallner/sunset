import Foundation

/// The App Group snapshot the widget reads and the app writes. Also holds the
/// last location fix, because the widget cannot run CoreLocation itself.
enum ForecastCache {
    /// Bumped when `SunsetForecast` changes shape, so an old snapshot is
    /// dropped instead of failing to decode forever.
    private static let forecastKey = "sunset.forecast.v2"
    private static let latitudeKey = "sunset.location.latitude"
    private static let longitudeKey = "sunset.location.longitude"
    private static let placeKey = "sunset.location.place"
    static let proKey = "sunset.isPro"
    private static let watchedKey = "sunset.watched"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: sunsetAppGroupID) ?? .standard
    }

    static var forecast: SunsetForecast? {
        get {
            guard let data = defaults.data(forKey: forecastKey) else { return nil }
            return try? JSONDecoder().decode(SunsetForecast.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: forecastKey)
            } else {
                defaults.removeObject(forKey: forecastKey)
            }
        }
    }

    struct Location: Equatable, Sendable {
        var latitude: Double
        var longitude: Double
        var placeName: String?
    }

    static var location: Location? {
        get {
            guard defaults.object(forKey: latitudeKey) != nil else { return nil }
            return Location(
                latitude: defaults.double(forKey: latitudeKey),
                longitude: defaults.double(forKey: longitudeKey),
                placeName: defaults.string(forKey: placeKey)
            )
        }
        set {
            guard let newValue else {
                [latitudeKey, longitudeKey, placeKey].forEach(defaults.removeObject(forKey:))
                return
            }
            defaults.set(newValue.latitude, forKey: latitudeKey)
            defaults.set(newValue.longitude, forKey: longitudeKey)
            defaults.set(newValue.placeName, forKey: placeKey)
        }
    }

    static var isPro: Bool {
        get { defaults.bool(forKey: proKey) }
        set { defaults.set(newValue, forKey: proKey) }
    }

    /// Which shows the user picked in onboarding. Lives here so the widget
    /// shows the same next show as the app.
    static var watchedEvents: Set<SunEvent> {
        get {
            let raw = defaults.stringArray(forKey: watchedKey) ?? SunEvent.allCases.map(\.rawValue)
            let events = Set(raw.compactMap(SunEvent.init(rawValue:)))
            return events.isEmpty ? Set(SunEvent.allCases) : events
        }
        set {
            defaults.set(SunEvent.allCases.filter(newValue.contains).map(\.rawValue), forKey: watchedKey)
        }
    }
}

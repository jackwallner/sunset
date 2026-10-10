import Foundation

/// Finds thunderstorms, rainbow chances and fog in the hourly forecast.
///
/// Each hour is classified on its own, then runs of the same kind merge into
/// one event, so a three-hour storm is one alert, not three. Pure, so the
/// rules are pinned by tests.
enum SkyEventDetector {
    struct Hour: Equatable, Sendable {
        var time: Date
        /// WMO weather interpretation code, as Open-Meteo reports it.
        var weatherCode: Int?
        var cloudCover: Double?
        var precipitation: Double?
        var precipitationChance: Double?
        var visibility: Double?
    }

    static func detect(_ hours: [Hour], latitude: Double, longitude: Double) -> [SkyEvent] {
        var events: [SkyEvent] = []
        for hour in hours {
            let elevation = SolarPosition.elevation(at: hour.time, latitude: latitude, longitude: longitude)
            for kind in kinds(for: hour, sunElevation: elevation) {
                let end = hour.time.addingTimeInterval(3600)
                if let index = events.lastIndex(where: { $0.kind == kind }), events[index].end >= hour.time {
                    events[index].end = end
                } else {
                    events.append(SkyEvent(kind: kind, start: hour.time, end: end))
                }
            }
        }
        return events.sorted { $0.start < $1.start }
    }

    static func kinds(for hour: Hour, sunElevation: Double) -> [SkyEvent.Kind] {
        var kinds: [SkyEvent.Kind] = []
        let code = hour.weatherCode ?? -1
        if (95 ... 99).contains(code) {
            kinds.append(.thunderstorm)
        }
        if isRainbowHour(hour, code: code, sunElevation: sunElevation) {
            kinds.append(.rainbow)
        }
        if code == 45 || code == 48 || (hour.visibility ?? .infinity) < 1_000 {
            kinds.append(.fog)
        }
        return kinds
    }

    /// A rainbow needs falling rain and direct sun at once, with the sun
    /// below 42 degrees so the bow clears the horizon. Showers (or light rain
    /// that is actually falling) under a broken sky is the forecastable part.
    private static func isRainbowHour(_ hour: Hour, code: Int, sunElevation: Double) -> Bool {
        guard (2 ... 42).contains(sunElevation) else { return false }
        guard let cover = hour.cloudCover, cover >= 20, cover <= 75 else { return false }
        let showery = (80 ... 82).contains(code) || (51 ... 63).contains(code)
        let wet = (hour.precipitation ?? 0) >= 0.1 && (hour.precipitationChance ?? 0) >= 35
        return showery && wet
    }
}

/// Sun elevation from the NOAA approximation, good to a fraction of a
/// degree, which is plenty for "is the sun low and up".
enum SolarPosition {
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let days = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let meanLongitude = normalize(280.460 + 0.985_647_4 * days)
        let meanAnomaly = radians(normalize(357.528 + 0.985_600_3 * days))
        let eclipticLongitude = radians(meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly))
        let obliquity = radians(23.439 - 0.000_000_4 * days)
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))

        let siderealHours = 18.697_374_558 + 24.065_709_824_419_08 * days
        let localSidereal = radians(normalize(siderealHours * 15 + longitude))
        let hourAngle = localSidereal - rightAscension
        let lat = radians(latitude)
        let sine = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return asin(min(1, max(-1, sine))) * 180 / .pi
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}

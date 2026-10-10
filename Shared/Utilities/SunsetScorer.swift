import Foundation

/// Turns the forecast sky into a 0 to 100 score for a sunrise or sunset.
///
/// The model follows what sunset chasers and the SunsetWx-style forecasts
/// agree on: colour needs something up high to light up (cirrus and mid
/// cloud around half cover), the horizon toward the sun has to be open or the
/// light never arrives, and dry clean air keeps the tones vivid instead of
/// washing them out. Low cloud is the killer, and low cloud toward the sun
/// (west at sunset, east at sunrise) is worse than low cloud overhead. Rain
/// at the moment dampens everything.
///
/// Pure and deterministic so it is pinned by tests and runs in the widget.
enum SunsetScorer {
    static func score(_ sky: SkyConditions, event: SunEvent = .sunset) -> SunsetScore {
        let highBell = bell(sky.cloudHigh, center: 50, width: 32)
        let midBell = bell(sky.cloudMid, center: 35, width: 30)

        // Clear skies still make a clean, if plain, sunset: the floor is 30.
        let lift: Double = 0.65 * highBell + 0.35 * midBell
        let color: Double = 30 + 70 * lift

        // Streaks are cirrus with nothing underneath hiding them.
        let midShade: Double = 1 - 0.5 * sky.cloudMid / 100
        let lowShade: Double = 1 - 0.7 * sky.cloudLow / 100
        let streaks: Double = 100 * highBell * midShade * lowShade

        let lowCover: Double = 0.35 * sky.cloudLow + 0.65 * sky.cloudLowTowardSun
        let horizon: Double = 100 * (1 - lowCover / 100)

        let visibilityScore = clamp((sky.visibility - 5_000) / 20_000)
        let humidityScore = clamp((95 - sky.humidity) / 50)
        let clarity = 100 * (0.5 * visibilityScore + 0.5 * humidityScore)

        // An open horizon is a prerequisite more than a bonus, so it scales the
        // rest rather than adding to it, and it bites early: half low cloud
        // toward the sun already halves the show.
        let horizonGate: Double = 0.15 + 0.85 * pow(horizon / 100, 1.5)
        let rainFactor: Double = switch sky.precipitationChance {
        case ..<40: 1
        case ..<70: 0.8
        default: 0.55
        }

        let base: Double = 0.6 * color + 0.2 * streaks + 0.2 * clarity
        let raw: Double = base * horizonGate * rainFactor
        let total = Int(clamp(raw / 100) * 100 + 0.5)

        let score = SunsetScore(
            total: total,
            color: Int(color + 0.5),
            streaks: Int(streaks + 0.5),
            horizon: Int(horizon + 0.5),
            clarity: Int(clarity + 0.5),
            rainChance: Int(sky.precipitationChance + 0.5),
            summary: ""
        )
        return SunsetScore(
            total: score.total, color: score.color, streaks: score.streaks,
            horizon: score.horizon, clarity: score.clarity, rainChance: score.rainChance,
            summary: summary(for: score, sky: sky, event: event)
        )
    }

    /// One plain sentence naming the thing that decides the show.
    static func summary(for score: SunsetScore, sky: SkyConditions, event: SunEvent = .sunset) -> String {
        let moment = event == .sunset ? "sunset" : "sunrise"
        if sky.precipitationChance >= 70 {
            return "Rain is likely at \(moment), so the show will probably be rained out."
        }
        if max(sky.cloudLow, sky.cloudLowTowardSun) >= 80 {
            if sky.cloudLowTowardSun > sky.cloudLow {
                return event == .sunset
                    ? "A bank of low cloud to the west should block the last light."
                    : "A bank of low cloud to the east should block the first light."
            }
            return event == .sunset
                ? "Low cloud overhead should hide the sun before it reaches the horizon."
                : "Low cloud overhead should hide the sun as it clears the horizon."
        }
        if max(sky.cloudLow, sky.cloudLowTowardSun) >= 55 {
            return "Low cloud is likely to get in the way, with a chance of a brief glow at the horizon."
        }
        if sky.cloudHigh >= 25 && sky.cloudHigh <= 75 && score.clarity >= 50 {
            return sky.cloudMid >= 20
                ? "High and mid clouds over an open horizon, which is the recipe for a colorful sky."
                : "Thin high clouds should catch the light over a clear horizon."
        }
        if sky.cloudHigh > 75 {
            return "A thick layer of high cloud may glow, but there is little gap for the light to come through."
        }
        if sky.cloudMid >= 20 && sky.cloudMid <= 70 {
            return event == .sunset
                ? "Scattered mid-level cloud should pick up some color after the sun drops."
                : "Scattered mid-level cloud should pick up some color before the sun comes up."
        }
        if sky.cloudHigh < 10 && sky.cloudMid < 10 {
            return score.clarity >= 60
                ? "A clear sky, so expect a clean gold glow rather than fireworks."
                : "A clear but hazy sky, so colors will be soft and muted."
        }
        return "Mixed cloud with some chance of color near the horizon."
    }

    /// Weights an hour on each side of the moment so a 6:40 sunset leans on
    /// the 7 pm hour more than the 6 pm one.
    static func interpolate(_ before: SkyConditions, _ after: SkyConditions, weight: Double) -> SkyConditions {
        let w = clamp(weight)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * w }
        return SkyConditions(
            cloudLow: mix(before.cloudLow, after.cloudLow),
            cloudMid: mix(before.cloudMid, after.cloudMid),
            cloudHigh: mix(before.cloudHigh, after.cloudHigh),
            cloudLowTowardSun: mix(before.cloudLowTowardSun, after.cloudLowTowardSun),
            humidity: mix(before.humidity, after.humidity),
            visibility: mix(before.visibility, after.visibility),
            precipitationChance: mix(before.precipitationChance, after.precipitationChance)
        )
    }

    private static func bell(_ value: Double, center: Double, width: Double) -> Double {
        let z = (value - center) / width
        return exp(-z * z)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

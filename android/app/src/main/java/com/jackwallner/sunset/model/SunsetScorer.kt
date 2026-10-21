package com.jackwallner.sunset.model

import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * Turns the forecast sky into a 0 to 100 score for a sunrise or sunset.
 * Straight port of `SunsetScorer.swift`; the weights and their reasons live
 * in `.claude/rules/scoring.md`. Pure, so it is pinned by tests and runs in
 * the widget.
 */
object SunsetScorer {
    fun score(sky: SkyConditions, event: SunEvent = SunEvent.SUNSET): SunsetScore {
        val highBell = bell(sky.cloudHigh, center = 50.0, width = 32.0)
        val midBell = bell(sky.cloudMid, center = 35.0, width = 30.0)

        // Clear skies still make a clean, if plain, sunset: the floor is 30.
        val lift = 0.65 * highBell + 0.35 * midBell
        val color = 30 + 70 * lift

        // Streaks are cirrus with nothing underneath hiding them.
        val midShade = 1 - 0.5 * sky.cloudMid / 100
        val lowShade = 1 - 0.7 * sky.cloudLow / 100
        val streaks = 100 * highBell * midShade * lowShade

        val lowCover = 0.35 * sky.cloudLow + 0.65 * sky.cloudLowTowardSun
        val horizon = 100 * (1 - lowCover / 100)

        val visibilityScore = clamp((sky.visibility - 5_000) / 20_000)
        val humidityScore = clamp((95 - sky.humidity) / 50)
        val clarity = 100 * (0.5 * visibilityScore + 0.5 * humidityScore)

        // An open horizon is a prerequisite more than a bonus, so it scales the rest.
        val horizonGate = 0.15 + 0.85 * (horizon / 100).pow(1.5)
        val rainFactor = when {
            sky.precipitationChance < 40 -> 1.0
            sky.precipitationChance < 70 -> 0.8
            else -> 0.55
        }

        val base = 0.6 * color + 0.2 * streaks + 0.2 * clarity
        val raw = base * horizonGate * rainFactor
        val score = SunsetScore(
            total = round(clamp(raw / 100) * 100),
            color = round(color),
            streaks = round(streaks),
            horizon = round(horizon),
            clarity = round(clarity),
            rainChance = round(sky.precipitationChance),
            summary = "",
        )
        return score.copy(summary = summary(score, sky, event))
    }

    /** One plain sentence naming the thing that decides the show. */
    fun summary(score: SunsetScore, sky: SkyConditions, event: SunEvent = SunEvent.SUNSET): String {
        val sunset = event == SunEvent.SUNSET
        val moment = if (sunset) "sunset" else "sunrise"
        val lowMax = max(sky.cloudLow, sky.cloudLowTowardSun)
        return when {
            sky.precipitationChance >= 70 -> "Rain is likely at $moment, so the show will probably be rained out."
            lowMax >= 80 && sky.cloudLowTowardSun > sky.cloudLow ->
                if (sunset) "A bank of low cloud to the west should block the last light."
                else "A bank of low cloud to the east should block the first light."
            lowMax >= 80 ->
                if (sunset) "Low cloud overhead should hide the sun before it reaches the horizon."
                else "Low cloud overhead should hide the sun as it clears the horizon."
            lowMax >= 55 -> "Low cloud is likely to get in the way, with a chance of a brief glow at the horizon."
            sky.cloudHigh in 25.0..75.0 && score.clarity >= 50 ->
                if (sky.cloudMid >= 20) "High and mid clouds over an open horizon, which is the recipe for a colorful sky."
                else "Thin high clouds should catch the light over a clear horizon."
            sky.cloudHigh > 75 -> "A thick layer of high cloud may glow, but there is little gap for the light to come through."
            sky.cloudMid in 20.0..70.0 ->
                if (sunset) "Scattered mid-level cloud should pick up some color after the sun drops."
                else "Scattered mid-level cloud should pick up some color before the sun comes up."
            sky.cloudHigh < 10 && sky.cloudMid < 10 ->
                if (score.clarity >= 60) "A clear sky, so expect a clean gold glow rather than fireworks."
                else "A clear but hazy sky, so colors will be soft and muted."
            else -> "Mixed cloud with some chance of color near the horizon."
        }
    }

    /** Weights an hour on each side of the moment so a 6:40 sunset leans on the 7 pm hour. */
    fun interpolate(before: SkyConditions, after: SkyConditions, weight: Double): SkyConditions {
        val w = clamp(weight)
        fun mix(a: Double, b: Double) = a + (b - a) * w
        return SkyConditions(
            cloudLow = mix(before.cloudLow, after.cloudLow),
            cloudMid = mix(before.cloudMid, after.cloudMid),
            cloudHigh = mix(before.cloudHigh, after.cloudHigh),
            cloudLowTowardSun = mix(before.cloudLowTowardSun, after.cloudLowTowardSun),
            humidity = mix(before.humidity, after.humidity),
            visibility = mix(before.visibility, after.visibility),
            precipitationChance = mix(before.precipitationChance, after.precipitationChance),
        )
    }

    private fun bell(value: Double, center: Double, width: Double): Double {
        val z = (value - center) / width
        return exp(-z * z)
    }

    private fun clamp(value: Double) = min(1.0, max(0.0, value))

    /** Swift's `Int(x + 0.5)`: truncation toward zero after adding a half. */
    private fun round(value: Double) = (value + 0.5).toInt()
}

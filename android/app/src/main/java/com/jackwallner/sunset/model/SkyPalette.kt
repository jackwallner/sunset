package com.jackwallner.sunset.model

import kotlin.math.max
import kotlin.math.min

/** A colour as three 0 to 1 channels, so the sky maths stays pure and testable. */
data class Rgb(val red: Double, val green: Double, val blue: Double) {
    fun scaled(factor: Double) = Rgb(red * factor, green * factor, blue * factor)

    /** [amount] of the way from this colour to [other]. */
    fun mixed(other: Rgb, amount: Double) = Rgb(
        red + (other.red - red) * amount,
        green + (other.green - green) * amount,
        blue + (other.blue - blue) * amount,
    )
}

/**
 * The sky a score promises, ported from `Theme.swift`. Dull evenings are
 * grey-blue, an epic one runs violet through crimson into gold at the
 * horizon, and dawn leans pink and blue.
 */
object SkyPalette {
    private val STOPS: List<Pair<Double, List<Rgb>>> = listOf(
        0.0 to listOf(Rgb(0.55, 0.60, 0.68), Rgb(0.72, 0.74, 0.78), Rgb(0.86, 0.85, 0.84)),
        0.3 to listOf(Rgb(0.42, 0.46, 0.66), Rgb(0.80, 0.68, 0.64), Rgb(0.96, 0.84, 0.70)),
        0.55 to listOf(Rgb(0.36, 0.30, 0.60), Rgb(0.93, 0.56, 0.40), Rgb(1.00, 0.82, 0.45)),
        0.8 to listOf(Rgb(0.28, 0.18, 0.50), Rgb(0.90, 0.36, 0.46), Rgb(1.00, 0.70, 0.30)),
        1.0 to listOf(Rgb(0.20, 0.10, 0.42), Rgb(0.86, 0.22, 0.44), Rgb(1.00, 0.62, 0.20)),
    )
    private val DAWN = listOf(Rgb(0.40, 0.52, 0.80), Rgb(0.98, 0.60, 0.62), Rgb(1.00, 0.84, 0.60))
    val NIGHT = Rgb(0.06, 0.05, 0.14)
    private val DEEP = Rgb(0.05, 0.04, 0.10)

    /** Top, middle and horizon colours for a score. */
    fun sky(score: Int, event: SunEvent = SunEvent.SUNSET): List<Rgb> {
        val t = min(100, max(0, score)) / 100.0
        var lower = STOPS.first()
        var upper = STOPS.last()
        for (index in 0 until STOPS.size - 1) {
            if (t >= STOPS[index].first && t <= STOPS[index + 1].first) {
                lower = STOPS[index]
                upper = STOPS[index + 1]
                break
            }
        }
        val span = upper.first - lower.first
        val w = if (span == 0.0) 0.0 else (t - lower.first) / span
        val colors = lower.second.zip(upper.second) { a, b -> a.mixed(b, w) }
        if (event != SunEvent.SUNRISE) return colors
        return colors.zip(DAWN) { c, d ->
            Rgb(c.red * 0.6 + d.red * 0.4, c.green * 0.6 + d.green * 0.4, c.blue * 0.6 + d.blue * 0.4)
        }
    }

    /**
     * A full-screen sky: night overhead, the forecast colours down to a
     * glowing horizon at [horizon] (0 top, 1 bottom), then the same sky
     * reflected in still water below it, dimmer and deepening.
     */
    fun backdropStops(score: Int, event: SunEvent, horizon: Double): List<Pair<Double, Rgb>> {
        val sky = sky(score, event)
        // Dull skies are pale greys; dim them so white text still reads.
        val dim = 0.62 + 0.30 * min(100, max(0, score)) / 100.0
        val h = min(0.95, max(0.08, horizon))
        val water = 1 - h
        return listOf(
            0.0 to NIGHT.mixed(sky[0], 0.35),
            h * 0.45 to sky[0].scaled(dim),
            h * 0.82 to sky[1].scaled(dim),
            h to sky[2].scaled(min(1.0, dim + 0.08)),
            h + 0.01 to sky[2].scaled(0.5),
            h + water * 0.22 to sky[1].scaled(0.42),
            h + water * 0.55 to sky[0].scaled(0.36),
            1.0 to DEEP,
        ).map { (location, color) -> min(1.0, location) to color }
    }

    fun glow(score: Int, event: SunEvent): Rgb = sky(score, event)[2]

    /** Solid colour for chips and bars, the warmest stop of the sky. */
    fun tone(score: Int): Rgb = sky(score)[1]
}

package com.jackwallner.sunset.ui.theme

import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sunset.R
import com.jackwallner.sunset.model.Rgb
import com.jackwallner.sunset.model.SkyPalette
import com.jackwallner.sunset.model.SunEvent

/** `Theme.swift`: every screen sits on a forecast sky, so text is light everywhere. */
object Sky {
    val textPrimary = Color.White
    val textSecondary = Color.White.copy(alpha = 0.74f)
    val hairline = Color.White.copy(alpha = 0.18f)
    /** A list row over the sky. */
    val row = Color.Black.copy(alpha = 0.24f)
    /** Text on the white primary button. */
    val ink = Color(0.17f, 0.10f, 0.24f)

    val ember = Color(0.96f, 0.45f, 0.22f)
    val gold = Color(1.0f, 0.78f, 0.32f)
    val rose = Color(0.93f, 0.36f, 0.48f)
    val violet = Color(0.42f, 0.30f, 0.62f)
    val dusk = Color(0.20f, 0.18f, 0.38f)
    val mint = Color(0.25f, 0.78f, 0.58f)
    val night = SkyPalette.NIGHT.color

    val cardRadius = 22.dp

    val accent: Brush get() = Brush.linearGradient(listOf(gold, ember))

    fun sky(score: Int, event: SunEvent = SunEvent.SUNSET): List<Color> = SkyPalette.sky(score, event).map { it.color }

    fun skyGradient(score: Int, event: SunEvent = SunEvent.SUNSET): Brush = Brush.verticalGradient(sky(score, event))

    fun glow(score: Int, event: SunEvent): Color = SkyPalette.glow(score, event).color

    /** Solid colour for chips and bars, the warmest stop of the sky. */
    fun tone(score: Int): Color = SkyPalette.tone(score).color
}

val Rgb.color: Color get() = Color(red.toFloat().coerceIn(0f, 1f), green.toFloat().coerceIn(0f, 1f), blue.toFloat().coerceIn(0f, 1f))

private val weights = listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold, FontWeight.Bold)

@OptIn(ExperimentalTextApi::class)
/** Nunito is variable: each weight is an axis setting on the one file. SF Rounded's open-licence stand-in. */
val Rounded = FontFamily(
    weights.map { Font(R.font.nunito, it, FontStyle.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(it.weight))) },
)

/** iOS Dynamic Type sizes at the default setting, in light text. */
object SkyType {
    fun rounded(size: TextUnit, weight: FontWeight = FontWeight.Bold) =
        TextStyle(fontFamily = Rounded, fontWeight = weight, fontSize = size, color = Color.White, fontFeatureSettings = "tnum")

    val largeTitle = TextStyle(fontSize = 32.sp, lineHeight = 39.sp, fontWeight = FontWeight.Bold, color = Color.White)
    val title2 = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold, color = Color.White)
    val title3 = TextStyle(fontSize = 20.sp, lineHeight = 25.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
    val headline = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
    val body = TextStyle(fontSize = 17.sp, lineHeight = 23.sp, color = Color.White)
    val subheadline = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, color = Color.White)
    val footnote = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, color = Sky.textSecondary)
    val caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp, color = Sky.textSecondary)
    val caption2 = TextStyle(fontSize = 11.sp, lineHeight = 14.sp, color = Sky.textSecondary)
}

@Composable
fun SunsetTheme(content: @Composable () -> Unit) {
    val scheme = darkColorScheme(
        primary = Sky.ember,
        onPrimary = Color.White,
        secondary = Sky.gold,
        background = Sky.night,
        surface = Color(0xFF1C1830),
        onSurface = Color.White,
        surfaceContainerHigh = Color(0xFF26203E),
    )
    MaterialTheme(colorScheme = scheme) {
        CompositionLocalProvider(
            LocalTextSelectionColors provides TextSelectionColors(Sky.ember, Sky.ember.copy(alpha = 0.3f)),
            content = content,
        )
    }
}

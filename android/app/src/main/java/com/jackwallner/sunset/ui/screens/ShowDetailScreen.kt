package com.jackwallner.sunset.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.theme.FactorRow
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyCard
import com.jackwallner.sunset.ui.theme.SkyHero
import com.jackwallner.sunset.ui.theme.SkyType
import java.util.Locale

/** `ShowDetailView`: one sunrise or sunset, its factors and the cloud cover behind them. */
@Composable
fun ShowDetailScreen(show: SunShow, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val forecast = graph.forecastStore.forecast
    val zone = forecast?.zone ?: java.time.ZoneId.systemDefault()
    Box(Modifier.fillMaxSize().testTag("show-detail")) {
        SkyBackdrop(show.score.total, event = show.event, horizon = 0.42f)
        Column(Modifier.fillMaxSize()) {
            SkyTopBar(SunsetFormat.monthDay(show.time, zone), onBack = onClose, background = Color.Black.copy(alpha = 0.28f))
            BoxWithConstraints(Modifier.weight(1f)) {
                val heroHeight = maxOf(240.dp, maxHeight * 0.34f)
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).navigationBarsPadding().padding(bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    SkyHero(
                        show, zone, SunsetFormat.headline(show, zone), forecast?.placeName,
                        Modifier.fillMaxWidth().height(heroHeight).padding(bottom = 12.dp),
                    )
                    SkyCard {
                        Text(show.score.summary, style = SkyType.body)
                        CardDivider()
                        Row {
                            Stat("Best light", SunsetFormat.range(show.bestWindowStart, show.bestWindowEnd, zone), Modifier.weight(1f))
                            Stat("Rain", "${show.score.rainChance}%")
                        }
                    }
                    SkyCard(Modifier.testTag("factors")) {
                        show.score.factors.forEach { FactorRow(it, Sky.tone(show.score.total)) }
                    }
                    SkyCard(Modifier.testTag("cloud-cover")) {
                        Text("Cloud cover at ${show.event.title.lowercase()}", style = SkyType.headline)
                        CloudRow("High", show.conditions.cloudHigh)
                        CloudRow("Mid", show.conditions.cloudMid)
                        CloudRow("Low", show.conditions.cloudLow)
                        CloudRow("Low, ${show.event.direction} toward the sun", show.conditions.cloudLowTowardSun)
                        Text(
                            "Humidity ${show.conditions.humidity.toInt()}% · Visibility ${visibilityLabel(show.conditions.visibility)}",
                            style = SkyType.caption,
                        )
                    }
                }
            }
        }
    }
}

fun visibilityLabel(metres: Double): String {
    val km = metres / 1000
    return if (km >= 10) "${km.toInt()} km" else String.format(Locale.US, "%.1f km", km)
}

@Composable
private fun CloudRow(label: String, value: Double) {
    Row(Modifier.fillMaxWidth()) {
        Text(label, style = SkyType.subheadline, modifier = Modifier.weight(1f))
        Text("${value.toInt()}%", style = SkyType.subheadline.copy(color = Sky.textSecondary, fontFeatureSettings = "tnum"))
    }
}

package com.jackwallner.sunset.ui.screens

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.Overlay
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetDay
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.theme.PrimaryButton
import com.jackwallner.sunset.ui.theme.ShowRow
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.Symbols
import com.jackwallner.sunset.ui.theme.glass
import com.jackwallner.sunset.ui.theme.skyEventTint

/** Today and tomorrow are free; the rest of the week is Sun+, shown blurred so the free tier sees what it is missing. */
const val FREE_DAYS = 2

/** `OutlookView.swift`: the week, one card per day on that day's own sky. */
@Composable
fun OutlookScreen() {
    val graph = LocalGraph.current
    val next = graph.nextShow
    val isPro = graph.subscriptions.isPro
    Box(Modifier.fillMaxSize()) {
        SkyBackdrop(next?.score?.total ?: 60, event = next?.event ?: SunEvent.SUNSET, horizon = 0.14f)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 16.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LargeTitle("Outlook")
            val forecast = graph.forecastStore.forecast
            if (forecast == null) {
                Text(
                    "The outlook appears once the forecast has loaded.",
                    style = SkyType.body.copy(color = Sky.textSecondary),
                    modifier = Modifier.padding(top = 60.dp).fillMaxWidth(),
                    textAlign = TextAlign.Center,
                )
            } else {
                val days = forecast.upcomingDays().take(7)
                days.take(if (isPro) days.size else FREE_DAYS).forEach { day ->
                    DayCard(day, forecast, graph.settings.watched) { graph.navigator.push(Overlay.ShowDetail(it)) }
                }
                if (!isPro && days.size > FREE_DAYS) {
                    LockedWeek(days.drop(FREE_DAYS), forecast) { graph.navigator.push(Overlay.Paywall("outlook")) }
                }
            }
        }
    }
}

/** The real days, blurred past reading, under one unlock card. */
@Composable
private fun LockedWeek(days: List<SunsetDay>, forecast: SunsetForecast, onUnlock: () -> Unit) {
    val graph = LocalGraph.current
    Box(Modifier.fillMaxWidth().testTag("locked-week")) {
        // Three days show what is behind the lock without a long scroll of blur.
        // Blur needs API 31; older devices get the cards faded past reading instead.
        val hidden = if (Build.VERSION.SDK_INT >= 31) Modifier.blur(9.dp) else Modifier.alpha(0.12f)
        Column(hidden.clearAndSetSemantics {}, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            days.take(3).forEach { DayCard(it, forecast, graph.settings.watched, onOpen = null) }
        }
        Column(
            Modifier.padding(top = 40.dp, start = 8.dp, end = 8.dp).fillMaxWidth().glass(tint = 0.3f).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(Icons.Rounded.Lock, null, tint = Sky.ember, modifier = Modifier.size(28.dp))
            Text("The rest of the week", style = SkyType.title3)
            val last = days.lastOrNull()?.let { SunsetFormat.weekday(it.sunset.time, forecast.zone) } ?: "the week"
            Text(
                "Every sunrise and sunset score through $last, plus storm, rainbow and fog alerts.",
                style = SkyType.subheadline.copy(color = Sky.textSecondary),
                textAlign = TextAlign.Center,
            )
            PrimaryButton("Unlock with Sun+", onUnlock, tag = "unlock-week")
        }
    }
}

@Composable
private fun DayCard(day: SunsetDay, forecast: SunsetForecast, watched: Set<SunEvent>, onOpen: ((SunShow) -> Unit)?) {
    val zone = forecast.zone
    val shows = SunEvent.entries.filter { it in watched }.map(day::show)
    val events = forecast.skyEvents(day)
    // The sunset colours the card when it is watched, otherwise the sunrise.
    val lead = if (SunEvent.SUNSET in watched || watched.isEmpty()) day.sunset else day.sunrise
    val shape = RoundedCornerShape(Sky.cardRadius)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Brush.linearGradient(Sky.sky(lead.score.total, lead.event), start = Offset.Zero, end = Offset.Infinite))
            .background(Brush.horizontalGradient(listOf(Color.Black.copy(alpha = 0.42f), Color.Black.copy(alpha = 0.18f))))
            .border(1.dp, Color.White.copy(alpha = 0.14f), shape)
            .padding(18.dp)
            .testTag("day-card"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(SunsetFormat.dayLabel(day.sunset.time, zone), style = SkyType.title3, modifier = Modifier.weight(1f))
            Text(SunsetFormat.monthDay(day.sunset.time, zone), style = SkyType.subheadline.copy(color = Sky.textSecondary))
        }
        shows.forEach { show ->
            ShowRow(show, zone, showsChevron = onOpen != null, onClick = onOpen?.let { open -> { open(show) } })
        }
        if (events.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                events.forEach { event ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Symbols.skyEvent(event.kind), null, tint = skyEventTint(event.kind), modifier = Modifier.size(14.dp))
                        Text(
                            "${event.kind.title} ${SunsetFormat.time(event.start, zone)}",
                            style = SkyType.caption.copy(fontWeight = FontWeight.Medium),
                        )
                    }
                }
            }
        }
    }
}

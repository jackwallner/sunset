package com.jackwallner.sunset.ui.screens

import android.app.Activity
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.DebugLaunchOptions
import com.jackwallner.sunset.Overlay
import com.jackwallner.sunset.data.LocationService
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.openAppSettings
import com.jackwallner.sunset.ui.requestPlayReview
import com.jackwallner.sunset.ui.theme.FactorRow
import com.jackwallner.sunset.ui.theme.PlusCapsule
import com.jackwallner.sunset.ui.theme.PrimaryButton
import com.jackwallner.sunset.ui.theme.ShowRow
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyCard
import com.jackwallner.sunset.ui.theme.SkyEventRow
import com.jackwallner.sunset.ui.theme.SkyHero
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.TextAction
import java.time.Duration
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** `TodayView.swift`: the next watched show as the hero, then why, what's next, sky events and alerts. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(activity: Activity) {
    val graph = LocalGraph.current
    val forecast = graph.forecastStore.forecast
    val hero = forecast?.upcomingShows(graph.settings.watched)?.firstOrNull()
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    var eventsY by remember { mutableFloatStateOf(-1f) }

    LaunchedEffect(Unit) {
        if (graph.isAutomationRun) return@LaunchedEffect
        val score = graph.nextShow?.score?.total ?: return@LaunchedEffect
        if (graph.settings.shouldRequestReview(score)) requestPlayReview(activity)
    }
    // Debug `screen events`: open on the sky events card for store captures.
    LaunchedEffect(eventsY) {
        if (DebugLaunchOptions.screen == "events" && eventsY > 0) {
            delay(400)
            scroll.animateScrollTo((eventsY - 300).toInt().coerceAtLeast(0))
        }
    }

    Box(Modifier.fillMaxSize()) {
        SkyBackdrop(hero?.score?.total ?: 40, event = hero?.event ?: SunEvent.SUNSET, horizon = 0.46f)
        PullToRefreshBox(
            isRefreshing = graph.forecastStore.isLoading && forecast != null,
            onRefresh = { graph.location.location?.let { fix -> scope.launch { graph.forecastStore.load(fix) } } },
            modifier = Modifier.fillMaxSize(),
        ) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val heroHeight = maxOf(260.dp, maxHeight * 0.40f)
                Column(
                    Modifier.fillMaxSize().verticalScroll(scroll).statusBarsPadding().padding(horizontal = 16.dp).padding(bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    if (forecast != null && hero != null) {
                        Content(forecast, hero, heroHeight, onEventsPositioned = { eventsY = it })
                    } else {
                        EmptyState(activity)
                    }
                }
            }
        }
        StatusBarFade(hero?.score?.total ?: 40, hero?.event ?: SunEvent.SUNSET)
    }
}

@Composable
private fun ColumnScope.Content(forecast: SunsetForecast, hero: SunShow, heroHeight: Dp, onEventsPositioned: (Float) -> Unit) {
    val graph = LocalGraph.current
    val zone = forecast.zone
    val nav = graph.navigator
    Box(
        Modifier
            .padding(top = 18.dp, bottom = 4.dp)
            .fillMaxWidth()
            .height(heroHeight)
            .testTag("hero")
            .clickableNoRipple { nav.push(Overlay.ShowDetail(hero)) },
    ) {
        SkyHero(hero, zone, SunsetFormat.headline(hero, zone), forecast.placeName, Modifier.fillMaxSize())
    }

    SkyCard {
        Text(hero.score.summary, style = SkyType.body, modifier = Modifier.testTag("summary"))
        CardDivider()
        Row {
            Stat("Best light", SunsetFormat.range(hero.bestWindowStart, hero.bestWindowEnd, zone), Modifier.weight(1f))
            Stat("Rain chance", "${hero.score.rainChance}%")
        }
    }

    SkyCard {
        Text("What makes the score", style = SkyType.headline)
        hero.score.factors.forEach { FactorRow(it, Sky.tone(hero.score.total)) }
    }

    val next = forecast.upcomingShows(graph.settings.watched).drop(1).take(2)
    if (next.isNotEmpty()) {
        SkyCard {
            Text("Up next", style = SkyType.headline)
            next.forEach { show ->
                ShowRow(show, zone, title = SunsetFormat.headline(show, zone)) { nav.push(Overlay.ShowDetail(show)) }
            }
        }
    }

    SkyEventsCard(forecast, Modifier.onGloballyPositioned { onEventsPositioned(it.positionInParent().y) })
    AlertsCard()

    graph.forecastStore.errorMessage?.let {
        Text(it, style = SkyType.footnote, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
    }
    Text(
        "Forecast by Open-Meteo, updated ${SunsetFormat.time(forecast.fetched)}.",
        style = SkyType.caption,
        modifier = Modifier.testTag("updated"),
    )
}

@Composable
private fun SkyEventsCard(forecast: SunsetForecast, modifier: Modifier) {
    val graph = LocalGraph.current
    val isPro = graph.subscriptions.isPro
    val events = forecast.upcomingSkyEvents(within = Duration.ofHours(48))
    SkyCard(modifier.testTag("sky-events")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Sky events", style = SkyType.headline, modifier = Modifier.weight(1f))
            if (!isPro) PlusCapsule()
        }
        if (events.isEmpty()) {
            Text("No storms, rainbow chances or fog in the next two days.", style = SkyType.subheadline.copy(color = Sky.textSecondary))
        } else {
            events.forEach { SkyEventRow(it, forecast.zone) }
        }
        if (!isPro) {
            TextAction(
                "Get alerted before them",
                { graph.navigator.push(Overlay.Paywall("today_sky_events")) },
                color = Sky.ember,
                tag = "sky-events-upsell",
                modifier = Modifier.graphicsLayer { translationX = -8.dp.toPx() },
            )
        }
    }
}

@Composable
private fun AlertsCard() {
    val graph = LocalGraph.current
    val settings = graph.settings
    val threshold = settings.effectiveThreshold(graph.subscriptions.isPro)
    val subtitle = if (settings.alertsEnabled) {
        "You'll hear before any ${SunsetFormat.watchedNoun(settings.watched)} scoring $threshold or higher."
    } else {
        "A heads-up before the ${SunsetFormat.watchedNoun(settings.watched, plural = true)} worth going out for. Free."
    }
    SkyCard {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Alerts", style = SkyType.headline)
            Text(subtitle, style = SkyType.subheadline.copy(color = Sky.textSecondary), modifier = Modifier.testTag("alerts-subtitle"))
        }
        PrimaryButton(
            if (settings.alertsEnabled) "Change alerts" else "Turn on alerts",
            { graph.navigator.push(Overlay.AlertSetup) },
            tag = "alerts-button",
        )
    }
}

@Composable
private fun EmptyState(activity: Activity) {
    val graph = LocalGraph.current
    val location = graph.location
    Column(
        Modifier.fillMaxWidth().padding(top = 80.dp, start = 12.dp, end = 12.dp).testTag("empty-state"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(Icons.Rounded.WbTwilight, null, tint = Sky.gold, modifier = Modifier.size(52.dp))
        val loading = graph.forecastStore.isLoading || location.status is LocationService.Status.Waiting
        when {
            loading -> {
                CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                Text("Reading the sky", style = SkyType.subheadline.copy(color = Sky.textSecondary))
            }
            location.isDenied -> {
                Text("Location is off", style = SkyType.title3)
                Text(
                    "Sunset needs your approximate location to fetch the cloud forecast for your horizon. Turn it on in Settings.",
                    style = SkyType.body.copy(color = Sky.textSecondary),
                    textAlign = TextAlign.Center,
                )
                PrimaryButton("Open Settings", { activity.openAppSettings() })
            }
            graph.forecastStore.errorMessage != null -> {
                Text(graph.forecastStore.errorMessage.orEmpty(), style = SkyType.body.copy(color = Sky.textSecondary), textAlign = TextAlign.Center)
                PrimaryButton("Try again", { graph.refreshForecast(force = true) }, tag = "retry")
            }
            else -> {
                Text("Finding your sky", style = SkyType.title3)
                Text(
                    "Allow location once and today's scores appear here.",
                    style = SkyType.body.copy(color = Sky.textSecondary),
                    textAlign = TextAlign.Center,
                )
                PrimaryButton("Use my location", { location.request { graph.forecastStore.refresh(it) } }, tag = "use-location")
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

/** The hero is one big button; the sky itself is the pressed state, so no ripple over it. */
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClickLabel = "Show cloud cover and the full breakdown",
        onClick = onClick,
    )

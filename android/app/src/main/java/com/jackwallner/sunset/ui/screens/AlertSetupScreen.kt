package com.jackwallner.sunset.ui.screens

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.Overlay
import com.jackwallner.sunset.data.AlertSettings
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetScore
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.openAppSettings
import com.jackwallner.sunset.ui.theme.RowIcon
import com.jackwallner.sunset.ui.theme.PlusCapsule
import com.jackwallner.sunset.ui.theme.RowDivider
import com.jackwallner.sunset.ui.theme.SelectionMark
import com.jackwallner.sunset.ui.theme.Segmented
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyRow
import com.jackwallner.sunset.ui.theme.SkySection
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.Symbols
import com.jackwallner.sunset.ui.theme.ToggleRow
import kotlinx.coroutines.launch

/**
 * Alert settings, the iOS `AlertSetupSheet`. Sunrise and sunset alerts are
 * free at the default threshold and lead; Sun+ unlocks both and sky events.
 * Asks for the notification permission the first time alerts go on.
 */
@Composable
fun AlertSetupScreen(activity: Activity, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val settings = graph.settings
    val isPro = graph.subscriptions.isPro
    val scope = rememberCoroutineScope()
    var denied by remember { mutableStateOf(false) }
    val paywall = { graph.navigator.push(Overlay.Paywall("alert_settings")) }

    LaunchedEffect(Unit) {
        if (settings.alertsEnabled) denied = graph.alerts.isDenied
    }

    fun setEnabled(on: Boolean) {
        if (!on) {
            settings.updateAlertsEnabled(false)
            return
        }
        settings.updateAlertsEnabled(true)
        scope.launch {
            denied = !graph.alerts.requestAuthorization()
            graph.rescheduleAlerts()
        }
    }

    Box(Modifier.fillMaxSize().testTag("alert-setup")) {
        val next = graph.nextShow
        SkyBackdrop(next?.score?.total ?: 70, event = next?.event ?: SunEvent.SUNSET, horizon = 0.14f)
        Column(Modifier.fillMaxSize()) {
            SkyTopBar("Alerts", trailing = "Done", onTrailing = onClose)
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).navigationBarsPadding().padding(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                Spacer(Modifier.width(0.dp))
                SkySection(
                    footer = "Alerts are rebuilt from the latest forecast each time the app refreshes, so a sky that clouds over loses its alert. Sunrise alerts arrive the evening before.",
                ) {
                    ToggleRow("Alerts", settings.alertsEnabled, ::setEnabled, tag = "alerts-toggle")
                }

                SkySection(header = "Alert me when the score is at least") {
                    if (isPro) {
                        AlertSettings.THRESHOLDS.forEachIndexed { index, value ->
                            if (index > 0) RowDivider()
                            SkyRow(onClick = { settings.updateThreshold(value) }, tag = "threshold-$value") {
                                Text("$value · ${SunsetScore.Grade.of(value).title}", style = SkyType.body, modifier = Modifier.weight(1f))
                                if (settings.threshold == value) SelectionMark(true)
                            }
                        }
                    } else {
                        LockedRow("Score", "${AlertSettings.DEFAULT_THRESHOLD} · Great", "locked-threshold", paywall)
                    }
                }

                SkySection(header = "How far before sunset") {
                    if (isPro) {
                        Box(Modifier.padding(12.dp)) {
                            Segmented(AlertSettings.LEAD_OPTIONS, settings.leadMinutes, SunsetFormat::minutes, settings::updateLeadMinutes, tag = "lead")
                        }
                    } else {
                        LockedRow("Lead time", SunsetFormat.minutes(AlertSettings.DEFAULT_LEAD), "locked-lead", paywall)
                    }
                }

                SkySection(
                    header = "Sky events",
                    footer = "An hour's warning before storms, rainbow chances and fog, moved to the evening before when they fall overnight.",
                ) {
                    SkyEvent.Kind.entries.forEachIndexed { index, kind ->
                        if (index > 0) RowDivider()
                        if (isPro) {
                            ToggleRow(kind.title, kind in settings.skyEventKinds, { settings.setSkyEvent(kind, it) }, icon = Symbols.skyEvent(kind), tag = "sky-${kind.raw}")
                        } else {
                            SkyRow(onClick = paywall, tag = "locked-sky-${kind.raw}") {
                                RowIcon(Symbols.skyEvent(kind))
                                Text(kind.title, style = SkyType.body, modifier = Modifier.weight(1f))
                                PlusCapsule()
                            }
                        }
                    }
                }

                if (denied) {
                    SkySection {
                        SkyRow {
                            Text(
                                "Notifications are turned off for Sunset. Enable them in Settings to receive alerts.",
                                style = SkyType.body.copy(color = Sky.textSecondary),
                            )
                        }
                        RowDivider()
                        SkyRow(onClick = { activity.openAppSettings() }) {
                            Text("Open Settings", style = SkyType.body.copy(color = Sky.ember))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LockedRow(label: String, value: String, tag: String, onClick: () -> Unit) {
    SkyRow(onClick = onClick, tag = tag) {
        Text(label, style = SkyType.body, modifier = Modifier.weight(1f))
        Text(value, style = SkyType.body.copy(color = Sky.textSecondary))
        Spacer(Modifier.width(10.dp))
        PlusCapsule()
    }
}

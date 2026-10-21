package com.jackwallner.sunset.ui.screens

import android.app.Activity
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.BuildConfig
import com.jackwallner.sunset.Overlay
import com.jackwallner.sunset.model.ConversionCopy
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.Links
import com.jackwallner.sunset.ui.openUrl
import com.jackwallner.sunset.ui.theme.PlusCapsule
import com.jackwallner.sunset.ui.theme.RowDivider
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyRow
import com.jackwallner.sunset.ui.theme.SkySection
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.Symbols
import com.jackwallner.sunset.ui.theme.ToggleRow
import kotlinx.coroutines.launch

/** `SettingsView.swift`: Sun+, what to watch, alerts, location, about. */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun SettingsScreen(activity: Activity) {
    val graph = LocalGraph.current
    val settings = graph.settings
    val store = graph.subscriptions
    val scope = rememberCoroutineScope()
    var restoreMessage by remember { mutableStateOf<String?>(null) }
    var reviewerEntry by remember { mutableStateOf(false) }
    val next = graph.nextShow

    Box(Modifier.fillMaxSize()) {
        SkyBackdrop(next?.score?.total ?: 70, event = next?.event ?: SunEvent.SUNSET, horizon = 0.14f)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 16.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            LargeTitle("Settings")

            SkySection {
                if (store.isPro) {
                    SkyRow(tag = "pro-on") {
                        Icon(Icons.Rounded.Verified, null, tint = Sky.gold, modifier = Modifier.size(22.dp))
                        Spacer(Modifier.width(12.dp))
                        Text("Sun+ is on", style = SkyType.body)
                    }
                } else {
                    SkyRow(onClick = { graph.navigator.push(Overlay.Paywall("settings")) }, tag = "settings-plus") {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text("Sun+", style = SkyType.headline)
                            Text("The full week, storm, rainbow and fog alerts", style = SkyType.subheadline.copy(color = Sky.textSecondary))
                        }
                        PlusCapsule()
                    }
                }
            }

            SkySection(header = "Watch", footer = "Today, the outlook, the widget and alerts follow what you watch.") {
                SunEvent.entries.forEachIndexed { index, event ->
                    if (index > 0) RowDivider()
                    ToggleRow(
                        event.title,
                        event in settings.watched,
                        { settings.toggle(event) },
                        icon = Symbols.event(event),
                        enabled = settings.watched != setOf(event),
                        tag = "watch-${event.raw}",
                    )
                }
            }

            SkySection(header = "Alerts") {
                SkyRow(onClick = { graph.navigator.push(Overlay.AlertSetup) }, tag = "settings-alerts") {
                    Text("Alerts", style = SkyType.body, modifier = Modifier.weight(1f))
                    val status = if (!settings.alertsEnabled) "Off" else
                        "${settings.effectiveThreshold(store.isPro)}+ · ${SunsetFormat.minutes(settings.effectiveLead(store.isPro))} before"
                    Text(status, style = SkyType.body.copy(color = Sky.textSecondary))
                }
            }

            SkySection(header = "Location") {
                SkyRow {
                    Text("Forecast for", style = SkyType.body, modifier = Modifier.weight(1f))
                    Text(graph.location.location?.placeName ?: "Not set", style = SkyType.body.copy(color = Sky.textSecondary))
                }
                RowDivider()
                LinkRow("Update location", "update-location") {
                    graph.location.request { graph.forecastStore.refresh(it, force = true) }
                }
            }

            SkySection(header = "About") {
                LinkRow("Rate Sunset") { activity.openUrl(Links.PLAY_LISTING) }
                RowDivider()
                LinkRow("Support") { activity.openUrl(Links.SUPPORT) }
                RowDivider()
                LinkRow("Privacy Policy") { activity.openUrl(Links.PRIVACY) }
                RowDivider()
                LinkRow("Terms of Use") { activity.openUrl(Links.TERMS) }
                RowDivider()
                LinkRow("Restore purchases", "restore") {
                    scope.launch {
                        store.restore()
                        restoreMessage = if (store.isPro) "Sun+ is restored." else store.errorMessage ?: ConversionCopy.RESTORE_NONE
                        store.clearError()
                    }
                }
                RowDivider()
                LinkRow("Weather data by Open-Meteo") { activity.openUrl(Links.OPEN_METEO) }
            }

            if (BuildConfig.DEBUG) {
                SkySection(header = "Developer") {
                    ToggleRow("Sun+ override", store.isPro, store::setLocalOverride, tag = "pro-override")
                }
            }

            // Long-press opens Play reviewer access, which unlocks Sun+ without a purchase.
            Text(
                "Scores are a forecast of cloud, humidity and visibility at sunrise and sunset, not a promise. Version ${BuildConfig.VERSION_NAME}",
                style = SkyType.footnote,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).testTag("version")
                    .combinedClickable(onClick = {}, onLongClick = { reviewerEntry = true }, onClickLabel = null),
            )
        }
    }

    restoreMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { restoreMessage = null },
            confirmButton = { TextButton(onClick = { restoreMessage = null }) { Text("OK", color = Sky.ember) } },
            title = { Text("Restore purchases") },
            text = { Text(message, modifier = Modifier.semantics { testTagsAsResourceId = true }.testTag("restore-message")) },
        )
    }
    if (reviewerEntry) ReviewerAccessDialog(onDismiss = { reviewerEntry = false })
}

@Composable
private fun LinkRow(label: String, tag: String? = null, onClick: () -> Unit) {
    SkyRow(onClick = onClick, tag = tag) {
        Text(label, style = SkyType.body.copy(color = Sky.ember))
    }
}

/** Play review access: a code from the App access notes unlocks Sun+ on this install. */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun ReviewerAccessDialog(onDismiss: () -> Unit) {
    val graph = LocalGraph.current
    var code by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            // A dialog is its own window: test tags need resource ids again here.
            TextButton(
                onClick = { if (graph.subscriptions.activateReviewAccess(code)) onDismiss() else failed = true },
                modifier = Modifier.semantics { testTagsAsResourceId = true }.testTag("reviewer-unlock"),
            ) { Text("Unlock", color = Sky.ember) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Sky.textSecondary) } },
        title = { Text("Reviewer access") },
        text = {
            Column(Modifier.semantics { testTagsAsResourceId = true }, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it; failed = false },
                    label = { Text("Access code") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier.testTag("reviewer-code"),
                )
                if (failed) Text("That code didn't match.", color = Sky.gold, modifier = Modifier.testTag("reviewer-failed"))
            }
        },
    )
}

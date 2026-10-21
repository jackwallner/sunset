package com.jackwallner.sunset.ui.screens

import android.app.Activity
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Thunderstorm
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sunset.data.PackageKind
import com.jackwallner.sunset.data.Plan
import com.jackwallner.sunset.data.PurchaseOutcome
import com.jackwallner.sunset.model.ConversionCopy
import com.jackwallner.sunset.model.PlusBenefit
import com.jackwallner.sunset.ui.Links
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.openUrl
import com.jackwallner.sunset.ui.theme.PrimaryButton
import com.jackwallner.sunset.ui.theme.SelectionMark
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.Symbols
import com.jackwallner.sunset.ui.theme.TextAction
import com.jackwallner.sunset.ui.theme.glass
import kotlinx.coroutines.launch

fun PlusBenefit.icon(): ImageVector = when (this) {
    PlusBenefit.WEEK -> Icons.Rounded.CalendarMonth
    PlusBenefit.STORMS -> Icons.Rounded.Thunderstorm
    PlusBenefit.RAINBOWS -> Symbols.Rainbow
    PlusBenefit.FOG -> Symbols.Fog
    PlusBenefit.CUSTOM -> Icons.Rounded.Tune
}

@Composable
fun BenefitList(modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(13.dp)) {
        PlusBenefit.entries.forEach { item ->
            Row(verticalAlignment = Alignment.Top) {
                Icon(item.icon(), null, tint = Sky.gold, modifier = Modifier.width(24.dp).size(22.dp))
                Spacer(Modifier.width(12.dp))
                Text(item.text, style = SkyType.subheadline)
            }
        }
    }
}

/** The 56 pt rounded "Sun+" wordmark with its soft drop shadow. */
@Composable
fun PlusWordmark(modifier: Modifier = Modifier) {
    Text(
        "Sun+",
        style = SkyType.rounded(56.sp).copy(shadow = Shadow(Color.Black.copy(alpha = 0.18f), androidx.compose.ui.geometry.Offset(0f, 8f), 24f)),
        modifier = modifier,
    )
}

/** `PaywallView.swift`: every plan, yearly preselected, the billed amount above the button. */
@Composable
fun PaywallScreen(activity: Activity, source: String, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.subscriptions
    val scope = rememberCoroutineScope()
    var selectedId by remember { mutableStateOf<String?>(null) }
    var isRestoring by remember { mutableStateOf(false) }
    val plans = store.plans
    val selected = plans.firstOrNull { it.packageId == selectedId } ?: store.yearlyPlan ?: plans.firstOrNull()

    LaunchedEffect(Unit) {
        store.trackPaywallImpression("sunset_paywall_$source")
        if (plans.isEmpty() && !store.isLoadingProducts) store.start(forceRefresh = true)
    }
    LaunchedEffect(store.isPro) { if (store.isPro) onClose() }
    DisposableEffect(Unit) { onDispose { store.clearError() } }

    Box(Modifier.fillMaxSize().testTag("paywall")) {
        SkyBackdrop(92, horizon = 0.13f)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().navigationBarsPadding().padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Box(Modifier.fillMaxWidth()) {
                TextAction("Close", onClose, color = Color.White, tag = "paywall-close", modifier = Modifier.align(Alignment.CenterStart))
            }
            PlusWordmark()
            Text(
                "See further and catch more. Today, tomorrow and your sunrise and sunset alerts stay free.",
                style = SkyType.body.copy(color = Sky.textSecondary),
                textAlign = TextAlign.Center,
            )
            BenefitList(Modifier.fillMaxWidth())

            plans.forEach { plan ->
                PlanCard(
                    plan = plan,
                    detail = if (plan.kind == PackageKind.LIFETIME) "One-time purchase" else store.eligibleIntroLabel(plan),
                    isSelected = selected?.packageId == plan.packageId,
                    enabled = !store.isLoading,
                ) { selectedId = plan.packageId }
            }

            if (plans.isEmpty()) {
                if (store.isLoadingProducts || store.errorMessage == null) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                    Text("Loading plans", style = SkyType.subheadline.copy(color = Sky.textSecondary))
                } else {
                    Text("Purchase options are unavailable right now.", style = SkyType.subheadline.copy(color = Sky.textSecondary))
                    TextAction("Try again", { scope.launch { store.start(forceRefresh = true) } }, color = Sky.ember, tag = "plans-retry")
                }
            }

            store.errorMessage?.let {
                Text(it, style = SkyType.caption.copy(color = Color(0xFFFF6B6B)), textAlign = TextAlign.Center, modifier = Modifier.testTag("paywall-error"))
            }

            if (selected != null) {
                Column(
                    Modifier.semantics(mergeDescendants = true) {},
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text("BILLED AMOUNT", style = SkyType.caption2.copy(fontWeight = FontWeight.SemiBold))
                    Text(ConversionCopy.billedAmount(selected.priceLabel), style = SkyType.title2, modifier = Modifier.testTag("billed-amount"))
                    Text(
                        if (selected.kind == PackageKind.LIFETIME) "One-time purchase" else ConversionCopy.billedNote(store.eligibleIntroLabel(selected)),
                        style = SkyType.caption,
                    )
                }
            }

            PrimaryButton(
                if (store.isLoading) "Processing..." else ConversionCopy.CTA_LABEL,
                {
                    val plan = selected ?: return@PrimaryButton
                    scope.launch { if (store.purchase(activity, plan) == PurchaseOutcome.PURCHASED) onClose() }
                },
                enabled = selected != null && !store.isLoading,
                loading = store.isLoading,
                tag = "paywall-cta",
            )

            Text(disclosure(selected, store.eligibleIntroLabel(selected)), style = SkyType.caption2, textAlign = TextAlign.Center, modifier = Modifier.testTag("disclosure"))

            if (isRestoring) {
                CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
            } else {
                TextAction("Restore purchases", {
                    scope.launch {
                        isRestoring = true
                        store.restore()
                        isRestoring = false
                    }
                }, color = Sky.ember, tag = "paywall-restore")
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                TextAction("Terms", { activity.openUrl(Links.TERMS) })
                Text("·", style = SkyType.caption)
                TextAction("Privacy", { activity.openUrl(Links.PRIVACY) })
            }
        }
    }
}

private fun disclosure(plan: Plan?, trialLabel: String?): String = when {
    plan == null -> ConversionCopy.PRICES_UNKNOWN
    plan.kind == PackageKind.LIFETIME -> ConversionCopy.lifetimeDisclosure(plan.priceLabel)
    else -> ConversionCopy.disclosure(trialLabel, plan.priceLabel)
}

private fun com.jackwallner.sunset.data.SubscriptionService.eligibleIntroLabel(plan: Plan?): String? = plan?.let { this.eligibleIntroLabel(it) }

@Composable
private fun PlanCard(plan: Plan, detail: String?, isSelected: Boolean, enabled: Boolean, onSelect: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .glass(18.dp, tint = 0.24f)
            .border(2.dp, if (isSelected) Sky.gold else Color.Transparent, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onSelect)
            .padding(18.dp)
            .testTag("plan-${plan.kind.name.lowercase()}")
            .semantics(mergeDescendants = true) {
                contentDescription = "${plan.displayName}, ${plan.priceLabel}"
                selected = isSelected
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SelectionMark(isSelected)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(plan.displayName, style = SkyType.headline)
            if (detail != null) Text(detail, style = SkyType.caption.copy(color = Sky.mint))
        }
        Spacer(Modifier.width(8.dp))
        Text(plan.priceLabel, style = SkyType.body.copy(fontWeight = FontWeight.SemiBold))
    }
}

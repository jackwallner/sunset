package com.jackwallner.sunset.ui.screens

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sunset.DebugLaunchOptions
import com.jackwallner.sunset.data.PurchaseOutcome
import com.jackwallner.sunset.model.ConversionCopy
import com.jackwallner.sunset.model.DemoForecast
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.ui.Links
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.openUrl
import com.jackwallner.sunset.ui.theme.PrimaryButton
import com.jackwallner.sunset.ui.theme.SelectionMark
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyBackdrop
import com.jackwallner.sunset.ui.theme.SkyHero
import com.jackwallner.sunset.ui.theme.SkySwatch
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.TextAction
import com.jackwallner.sunset.ui.theme.glass
import java.time.ZoneId
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class Step { WELCOME, WATCH, ALERTS, PLUS }

private val PREVIEW = DemoForecast.preview()

/**
 * `OnboardingView.swift`: four short pages on a forecast sky, then the Sun+
 * offer with "Get Started" as the free way in. The bottom bar reserves the
 * same slots on every page, so the primary button never moves.
 */
@Composable
fun OnboardingScreen(activity: Activity) {
    val graph = LocalGraph.current
    val settings = graph.settings
    val store = graph.subscriptions
    val scope = rememberCoroutineScope()
    var step by remember { mutableStateOf(Step.entries.getOrElse(DebugLaunchOptions.onboardingStep ?: 0) { Step.WELCOME }) }
    var forward by remember { mutableStateOf(true) }
    var isPurchasing by remember { mutableStateOf(false) }
    var purchaseError by remember { mutableStateOf<String?>(null) }
    var ctaWaitExpired by remember { mutableStateOf(false) }
    var showPlans by remember { mutableStateOf(false) }

    fun finish() {
        if (!settings.hasOnboarded) settings.updateHasOnboarded(true)
    }

    fun advance() {
        val next = Step.entries.getOrNull(step.ordinal + 1) ?: return finish()
        forward = true
        step = next
    }

    // The offer buys monthly, like the fleet's best converters.
    val plan = store.monthlyPlan ?: store.yearlyPlan
    val trialLabel = plan?.let { store.eligibleIntroLabel(it) }
    val ctaReady = plan != null && (plan.introOfferLabel == null || store.introEligibilityResolved)
    val showsSpinner = step == Step.PLUS && (isPurchasing || (!ctaReady && !ctaWaitExpired))

    LaunchedEffect(step) {
        if (step != Step.PLUS) return@LaunchedEffect
        store.trackPaywallImpression("sunset_onboarding")
        // Never a dead end: after a few seconds without a price the button opens the plan picker.
        delay(6_000)
        ctaWaitExpired = true
    }
    LaunchedEffect(store.isPro) { if (store.isPro) finish() }
    BackHandler(enabled = step != Step.WELCOME && !showPlans) {
        forward = false
        step = Step.entries[step.ordinal - 1]
    }

    fun primaryAction() {
        when (step) {
            Step.WELCOME -> {
                // The location dialog goes up on the way out of the welcome page, over the next page.
                graph.location.request { graph.forecastStore.refresh(it) }
                advance()
            }
            Step.WATCH -> advance()
            Step.ALERTS -> scope.launch {
                settings.updateAlertsEnabled(graph.alerts.requestAuthorization())
                graph.rescheduleAlerts()
                advance()
            }
            Step.PLUS -> {
                val chosen = plan ?: run { showPlans = true; return }
                purchaseError = null
                isPurchasing = true
                scope.launch {
                    val outcome = store.purchase(activity, chosen)
                    isPurchasing = false
                    if (outcome == PurchaseOutcome.PURCHASED) finish() else purchaseError = store.errorMessage
                    store.clearError()
                }
            }
        }
    }

    val primaryLabel = when (step) {
        Step.WELCOME, Step.WATCH -> "Continue"
        Step.ALERTS -> "Turn on alerts"
        Step.PLUS -> when {
            plan == null -> "See Sun+ plans"
            trialLabel != null -> "Start $trialLabel"
            else -> ConversionCopy.CTA_LABEL
        }
    }

    Box(Modifier.fillMaxSize().testTag("onboarding")) {
        SkyBackdrop(if (step == Step.PLUS) 92 else PREVIEW.score.total, horizon = if (step == Step.ALERTS) 0.56f else 0.4f)
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Progress(step, Modifier.align(Alignment.CenterHorizontally).padding(top = 12.dp))
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    val direction = if (forward) 1 else -1
                    (slideInHorizontally(tween(300)) { it * direction } + fadeIn(tween(300))) togetherWith
                        (slideOutHorizontally(tween(300)) { -it * direction } + fadeOut(tween(300)))
                },
                modifier = Modifier.weight(1f).fillMaxWidth(),
                label = "onboardingPage",
            ) { page ->
                when (page) {
                    Step.WELCOME -> WelcomePage()
                    Step.WATCH -> WatchPage()
                    Step.ALERTS -> AlertsPage()
                    Step.PLUS -> PlusPage()
                }
            }
            Column(Modifier.padding(horizontal = 22.dp).padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.fillMaxWidth().height(104.dp), contentAlignment = Alignment.BottomCenter) {
                    when (step) {
                        Step.WELCOME -> Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
                            Icon(Icons.Rounded.Lock, null, tint = Sky.textSecondary, modifier = Modifier.size(13.dp))
                            Spacer(Modifier.width(5.dp))
                            Text("One approximate location fix. No account.", style = SkyType.caption)
                        }
                        Step.WATCH -> Unit
                        Step.ALERTS -> TextAction("Not now", ::advance, Modifier.fillMaxWidth(), tag = "not-now")
                        Step.PLUS -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            TextAction("Get Started", ::finish, Modifier.fillMaxWidth().height(32.dp), tag = "get-started")
                            Text(
                                plan?.priceLabel ?: " ",
                                style = SkyType.rounded(22.sp, FontWeight.SemiBold),
                                modifier = Modifier.testTag("offer-price"),
                            )
                            val terms = purchaseError ?: plan?.let { ConversionCopy.compactDisclosure(trialLabel, it.priceLabel) } ?: ConversionCopy.PRICES_UNKNOWN
                            Text(
                                terms,
                                style = SkyType.caption2.copy(color = if (purchaseError != null) Sky.gold else Sky.textSecondary),
                                textAlign = TextAlign.Center,
                                modifier = Modifier.testTag("offer-terms"),
                            )
                        }
                    }
                }
                PrimaryButton(primaryLabel, ::primaryAction, enabled = !showsSpinner, loading = showsSpinner, tag = "onboarding-continue")
                Box(Modifier.fillMaxWidth().height(22.dp), contentAlignment = Alignment.Center) {
                    if (step == Step.PLUS) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            FooterLink("Restore") {
                                scope.launch {
                                    store.restore()
                                    // Success flips isPro, which finishes onboarding.
                                    if (!store.isPro) purchaseError = store.errorMessage
                                    store.clearError()
                                }
                            }
                            Text("  ·  ", style = SkyType.caption)
                            FooterLink("Terms") { activity.openUrl(Links.TERMS) }
                            Text("  ·  ", style = SkyType.caption)
                            FooterLink("Privacy") { activity.openUrl(Links.PRIVACY) }
                        }
                    }
                }
            }
        }
        if (showPlans) {
            Box(Modifier.fillMaxSize().background(Sky.night)) {
                PaywallScreen(activity, "onboarding_plans", onClose = {
                    showPlans = false
                    if (store.isPro) finish()
                })
            }
            BackHandler { showPlans = false }
        }
    }
}

@Composable
private fun FooterLink(label: String, onClick: () -> Unit) {
    Text(
        label,
        style = SkyType.caption,
        modifier = Modifier.clickable(role = Role.Button, onClick = onClick).padding(vertical = 2.dp).testTag("footer-${label.lowercase()}"),
    )
}

@Composable
private fun Progress(step: Step, modifier: Modifier) {
    Row(
        modifier.clearAndSetSemantics { contentDescription = "Step ${step.ordinal + 1} of ${Step.entries.size}" },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Step.entries.forEach { item ->
            val width by animateDpAsState(if (item == step) 22.dp else 8.dp, tween(250), label = "dot")
            Box(
                Modifier.width(width).height(8.dp).background(
                    if (item.ordinal <= step.ordinal) Color.White else Sky.hairline,
                    CircleShape,
                ),
            )
        }
    }
}

private val headerShadow = Shadow(Color.Black.copy(alpha = 0.25f), androidx.compose.ui.geometry.Offset(0f, 4f), 16f)

@Composable
private fun PageHeader(title: String, subtitle: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, style = SkyType.largeTitle.copy(shadow = headerShadow), textAlign = TextAlign.Center)
        Text(subtitle, style = SkyType.body.copy(color = Color.White.copy(alpha = 0.86f), shadow = headerShadow), textAlign = TextAlign.Center)
    }
}

@Composable
private fun WelcomePage() {
    BoxWithConstraints(Modifier.fillMaxSize().padding(horizontal = 22.dp)) {
        val heroHeight = maxHeight * 0.42f
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            SkyHero(PREVIEW, ZoneId.systemDefault(), "Example", null, Modifier.fillMaxWidth().height(heroHeight).clearAndSetSemantics {})
            Column(
                Modifier.padding(top = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("Know before you go", style = SkyType.largeTitle, textAlign = TextAlign.Center)
                Text(
                    "Every sunrise and sunset gets a score from the cloud, humidity and visibility forecast. Catch the great ones instead of hearing about them later.",
                    style = SkyType.body.copy(color = Sky.textSecondary),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun WatchPage() {
    val settings = LocalGraph.current.settings
    Column(
        Modifier.fillMaxSize().padding(horizontal = 22.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        PageHeader("What do you want to catch?", "Pick one or both. You can change this in Settings.")
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SunEvent.entries.forEach { event ->
                WatchChoice(event, event in settings.watched) { settings.toggle(event) }
            }
        }
        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun WatchChoice(event: SunEvent, isOn: Boolean, toggle: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .glass(18.dp)
            .border(2.dp, if (isOn) Sky.gold else Color.Transparent, shape)
            .clickable(role = Role.Checkbox, onClick = toggle)
            .padding(16.dp)
            .testTag("watch-choice-${event.raw}")
            .semantics(mergeDescendants = true) { selected = isOn },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SkySwatch(80, event, size = 52.dp, radius = 12.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(event.title, style = SkyType.headline)
            Text("Scored against the ${if (event == SunEvent.SUNRISE) "eastern" else "western"} horizon", style = SkyType.subheadline.copy(color = Sky.textSecondary))
        }
        SelectionMark(isOn)
    }
}

@Composable
private fun AlertsPage() {
    val settings = LocalGraph.current.settings
    val shows = SunsetFormat.watchedNoun(settings.watched, plural = true)
    Column(
        Modifier.fillMaxSize().padding(horizontal = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        Icon(Icons.Rounded.NotificationsActive, null, tint = Sky.gold, modifier = Modifier.size(58.dp))
        PageHeader("Get a heads-up, free", "A notification before the $shows scoring 70 or more, so you only step outside for the good ones.")
        AlertPreview(settings.watched)
        Spacer(Modifier.height(24.dp))
    }
}

/** A sample of the notification the alerts page is asking for. */
@Composable
private fun AlertPreview(watched: Set<SunEvent>) {
    val event = if (SunEvent.SUNSET in watched) SunEvent.SUNSET else SunEvent.SUNRISE
    Row(
        Modifier.fillMaxWidth().glass(20.dp).padding(14.dp).clearAndSetSemantics { contentDescription = "Example alert" },
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SkySwatch(85, event, size = 38.dp, radius = 9.dp)
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row {
                Text("SUNSET", style = SkyType.caption2.copy(fontWeight = FontWeight.SemiBold), modifier = Modifier.weight(1f))
                Text(if (event == SunEvent.SUNSET) "45m before" else "8:00 PM", style = SkyType.caption2)
            }
            Text(
                if (event == SunEvent.SUNSET) "Epic sunset tonight: 88" else "Great sunrise tomorrow: 78",
                style = SkyType.subheadline.copy(fontWeight = FontWeight.SemiBold),
            )
            Text(
                "High and mid clouds over an open horizon, which is the recipe for a colorful sky.",
                style = SkyType.footnote,
                maxLines = 2,
            )
        }
    }
}

@Composable
private fun PlusPage() {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp).padding(top = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        PlusWordmark()
        Text("The whole week, and the rest of the sky", style = SkyType.title2, textAlign = TextAlign.Center)
        BenefitList(Modifier.fillMaxWidth().glass().padding(18.dp))
    }
}


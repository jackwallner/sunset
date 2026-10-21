package com.jackwallner.sunset.ui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.sunset.AppGraph
import com.jackwallner.sunset.Overlay
import com.jackwallner.sunset.ui.screens.AlertSetupScreen
import com.jackwallner.sunset.ui.screens.OnboardingScreen
import com.jackwallner.sunset.ui.screens.OutlookScreen
import com.jackwallner.sunset.ui.screens.PaywallScreen
import com.jackwallner.sunset.ui.screens.SettingsScreen
import com.jackwallner.sunset.ui.screens.ShowDetailScreen
import com.jackwallner.sunset.ui.screens.TodayScreen
import com.jackwallner.sunset.ui.theme.Sky

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("AppGraph not provided") }

/** Onboarding, or the three tabs with their pushes and sheets on top. */
@Composable
fun RootScreen(activity: Activity) {
    val graph = LocalGraph.current
    Box(Modifier.fillMaxSize().background(Sky.night)) {
        if (!graph.settings.hasOnboarded) {
            OnboardingScreen(activity)
        } else {
            // Under a sheet the tabs are neither readable by TalkBack nor tappable.
            val covered = graph.navigator.overlays.isNotEmpty()
            Box(if (covered) Modifier.clearAndSetSemantics {} else Modifier) { Tabs(graph, activity) }
            Overlays(graph, activity)
        }
    }
}

/** Play's In-App Review card, with no question in front of it. Quota may silently show nothing. */
fun requestPlayReview(activity: Activity) {
    val manager = ReviewManagerFactory.create(activity)
    manager.requestReviewFlow().addOnCompleteListener { request ->
        if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
    }
}

fun Activity.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, url.toUri())) }
}

/** The app's own page in system Settings, where a refused permission can be turned back on. */
fun Activity.openAppSettings() {
    runCatching {
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
    }
}

@Composable
private fun Tabs(graph: AppGraph, activity: Activity) {
    val nav = graph.navigator
    BackHandler(enabled = nav.tab != 0 && nav.overlays.isEmpty()) { nav.tab = 0 }
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when (nav.tab) {
                0 -> TodayScreen(activity)
                1 -> OutlookScreen()
                else -> SettingsScreen(activity)
            }
        }
        NavigationBar(containerColor = Color(0xF20D0B1E), tonalElevation = 0.dp) {
            TabItems.forEachIndexed { index, item ->
                NavigationBarItem(
                    selected = nav.tab == index,
                    onClick = { nav.tab = index },
                    icon = { Icon(item.icon, null) },
                    label = { Text(item.title) },
                    modifier = Modifier.testTag("tab-${item.title.lowercase()}"),
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Sky.ember,
                        selectedTextColor = Sky.ember,
                        indicatorColor = Color.White.copy(alpha = 0.10f),
                        unselectedIconColor = Sky.textSecondary,
                        unselectedTextColor = Sky.textSecondary,
                    ),
                )
            }
        }
    }
}

private data class TabItem(val title: String, val icon: ImageVector)

private val TabItems = listOf(
    TabItem("Today", Icons.Rounded.WbTwilight),
    TabItem("Outlook", Icons.Rounded.CalendarMonth),
    TabItem("Settings", Icons.Rounded.Tune),
)

/** Every overlay in the stack, bottom to top: detail pushes in from the side, sheets slide up. */
@Composable
private fun Overlays(graph: AppGraph, activity: Activity) {
    val nav = graph.navigator
    nav.overlays.forEachIndexed { index, overlay ->
        key(overlay) { OverlayHost(overlay, activity, isTop = index == nav.overlays.lastIndex) }
    }
}

@Composable
private fun OverlayHost(overlay: Overlay, activity: Activity, isTop: Boolean) {
    val graph = LocalGraph.current
    val close = { graph.navigator.remove(overlay) }
    BackHandler(enabled = isTop) { close() }
    val visible = remember { MutableTransitionState(false).apply { targetState = true } }
    val enter = if (overlay is Overlay.ShowDetail) {
        slideInHorizontally(tween(300)) { it / 3 } + fadeIn(tween(200))
    } else {
        slideInVertically(tween(320)) { it / 4 } + fadeIn(tween(220))
    }
    AnimatedVisibility(visibleState = visible, enter = enter) {
        Box(Modifier.fillMaxSize().background(Sky.night).blockTouchesBelow()) {
            when (overlay) {
                is Overlay.ShowDetail -> ShowDetailScreen(overlay.show, onClose = close)
                is Overlay.AlertSetup -> AlertSetupScreen(activity, onClose = close)
                is Overlay.Paywall -> PaywallScreen(activity, overlay.source, onClose = close)
            }
        }
    }
}

/** A sheet swallows every touch its content leaves unhandled, so nothing reaches the tabs behind it. */
private fun Modifier.blockTouchesBelow() = pointerInput(Unit) {
    awaitPointerEventScope {
        while (true) awaitPointerEvent().changes.forEach { it.consume() }
    }
}

package com.jackwallner.sunset

import android.Manifest
import android.graphics.Color
import android.os.Bundle
import android.text.format.DateFormat
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.lifecycle.lifecycleScope
import com.jackwallner.sunset.data.RefreshWorker
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.ui.LocalGraph
import com.jackwallner.sunset.ui.RootScreen
import com.jackwallner.sunset.ui.theme.SunsetTheme
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    private val graph: AppGraph get() = (application as SunsetApplication).graph
    private var permissionAnswer: CompletableDeferred<Boolean>? = null

    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        permissionAnswer?.complete(granted)
        permissionAnswer = null
    }

    private suspend fun ask(name: String): Boolean {
        val answer = CompletableDeferred<Boolean>()
        permissionAnswer = answer
        permission.launch(name)
        return answer.await()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = graph
        SunsetFormat.use24Hour = DateFormat.is24HourFormat(this)
        graph.location.requestPermission = { ask(Manifest.permission.ACCESS_COARSE_LOCATION) }
        graph.alerts.requestPermission = { ask(Manifest.permission.POST_NOTIFICATIONS) }
        if (savedInstanceState == null) {
            DebugLaunchOptions.apply(graph, intent)
            graph.settings.recordOpen()
            // Before onboarding, the permission dialog waits for "Continue" instead of covering the pitch.
            if (graph.settings.hasOnboarded && !DebugLaunchOptions.demoLocation) {
                graph.location.request { graph.forecastStore.refresh(it) }
            }
            graph.refreshForecast()
        }
        // The window is always a forecast sky, so the bars always carry light icons.
        val bars = SystemBarStyle.dark(Color.TRANSPARENT)
        enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
        lifecycleScope.launch { graph.subscriptions.start() }
        RefreshWorker.schedule(this)
        setContent {
            CompositionLocalProvider(LocalGraph provides graph) {
                SunsetTheme {
                    // Test tags double as resource ids so UI Automator and capture scripts can find controls.
                    Box(Modifier.semantics { testTagsAsResourceId = true }) {
                        RootScreen(this@MainActivity)
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        // The scene-active refresh: a new fix if the user moved, and a forecast older than three hours.
        if (graph.settings.hasOnboarded && !DebugLaunchOptions.demoLocation) graph.location.refresh()
        graph.refreshForecast()
        lifecycleScope.launch { graph.subscriptions.refreshCustomerInfo() }
    }

    override fun onDestroy() {
        if (isFinishing) {
            graph.location.requestPermission = null
            graph.alerts.requestPermission = null
        }
        super.onDestroy()
    }
}

package com.jackwallner.sunset.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.model.SkyPalette
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.ui.theme.Sky
import com.jackwallner.sunset.ui.theme.SkyType
import com.jackwallner.sunset.ui.theme.TextAction
import com.jackwallner.sunset.ui.theme.color

/**
 * With no bar, the status-bar strip fades from the night at the top of the
 * sky, so cards scrolling under the clock dissolve instead of colliding with it.
 */
@Composable
fun BoxScope.StatusBarFade(score: Int, event: SunEvent) {
    val night = SkyPalette.backdropStops(score, event, 0.46).first().second.color
    Column(Modifier.align(Alignment.TopCenter).fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(night))
        Box(Modifier.fillMaxWidth().height(24.dp).background(Brush.verticalGradient(listOf(night, night.copy(alpha = 0f)))))
    }
}

/** The iOS inline navigation bar: centred title, optional back or Done/Close. */
@Composable
fun SkyTopBar(
    title: String,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    trailing: String? = null,
    onTrailing: (() -> Unit)? = null,
    background: Color = Color.Transparent,
) {
    Box(modifier.fillMaxWidth().background(background).statusBarsPadding().height(52.dp).padding(horizontal = 4.dp)) {
        Text(
            title,
            style = SkyType.headline,
            textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.Center).semantics { heading() },
        )
        if (onBack != null) {
            IconButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart).testTag("back")) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back", tint = Color.White)
            }
        }
        if (trailing != null && onTrailing != null) {
            Row(Modifier.align(Alignment.CenterEnd)) {
                TextAction(trailing, onTrailing, color = Color.White, tag = "bar-${trailing.lowercase()}")
            }
        }
    }
}

/** A large title at the top of a tab, the iOS large navigation title. */
@Composable
fun LargeTitle(title: String) {
    Text(
        title,
        style = SkyType.largeTitle.copy(fontWeight = FontWeight.Bold),
        modifier = Modifier.fillMaxWidth().padding(start = 4.dp, top = 12.dp, bottom = 8.dp).semantics { heading() },
    )
}

/** A label over a value, the iOS `stat` block. */
@Composable
fun Stat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label.uppercase(), style = SkyType.caption2.copy(fontWeight = FontWeight.SemiBold))
        Text(value, style = SkyType.subheadline.copy(fontWeight = FontWeight.SemiBold))
    }
}

@Composable
fun CardDivider() {
    Box(Modifier.fillMaxWidth().height(0.5.dp).background(Sky.hairline))
}

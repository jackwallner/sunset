package com.jackwallner.sunset.ui.theme

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.LocationOn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SkyPalette
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetScore
import java.time.ZoneId

/**
 * The forecast sky behind a whole screen: the score's own colours down to a
 * glowing horizon at [horizon] (0 top, 1 bottom), reflected in water below.
 */
@Composable
fun SkyBackdrop(score: Int, modifier: Modifier = Modifier, event: SunEvent = SunEvent.SUNSET, horizon: Float = 0.42f) {
    val animatedScore by animateFloatAsState(score.toFloat(), tween(600), label = "skyScore")
    val animatedHorizon by animateFloatAsState(horizon, tween(600), label = "skyHorizon")
    Box(
        modifier.fillMaxSize().clearAndSetSemantics {}.drawBehind {
            val s = animatedScore.toInt()
            val stops = SkyPalette.backdropStops(s, event, animatedHorizon.toDouble())
                .map { (location, rgb) -> location.toFloat() to rgb.color }
                .toTypedArray()
            drawRect(Brush.verticalGradient(*stops, startY = 0f, endY = size.height))
            // The sun just under the horizon: a warm bloom that grows with the score.
            val glow = Sky.glow(s, event).copy(alpha = (0.25f + 0.4f * s / 100f).coerceIn(0f, 1f))
            val center = Offset(size.width / 2, size.height * animatedHorizon)
            drawRect(
                Brush.radialGradient(listOf(glow, Color.Transparent), center = center, radius = size.width * 0.75f),
                blendMode = BlendMode.Screen,
            )
        },
    )
}

/** Frosted glass over the sky: a touch darker, with a fine light edge. */
fun Modifier.glass(radius: Dp = Sky.cardRadius, tint: Float = 0.2f): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .clip(shape)
        .background(Color.White.copy(alpha = 0.08f))
        .background(Color.Black.copy(alpha = tint))
        .border(1.dp, Color.White.copy(alpha = 0.12f), shape)
}

/** A glass card with the iOS 18 pt padding and 14 pt spacing. */
@Composable
fun SkyCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().glass().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        content = content,
    )
}

/** The hero: the next sunrise or sunset written straight onto its sky. */
@Composable
fun SkyHero(show: SunShow, zone: ZoneId, title: String, placeName: String?, modifier: Modifier = Modifier) {
    val time = SunsetFormat.time(show.time, zone)
    Column(
        modifier.padding(horizontal = 6.dp, vertical = 8.dp).semantics(mergeDescendants = true) {
            contentDescription = "$title, score ${show.score.total}, ${show.score.grade.title}. ${show.event.title} at $time"
        },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = SkyType.headline.copy(color = Color.White.copy(alpha = 0.9f)), modifier = Modifier.weight(1f))
            if (placeName != null) {
                Icon(Icons.Rounded.LocationOn, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    placeName,
                    style = SkyType.subheadline.copy(fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.9f)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.widthIn(max = 200.dp),
                )
            }
        }
        Spacer(Modifier.weight(1f))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                "${show.score.total}",
                style = SkyType.rounded(112.sp).copy(lineHeight = 112.sp),
                modifier = Modifier.testTag("hero-score"),
            )
            Spacer(Modifier.width(10.dp))
            Text(
                show.score.grade.title,
                style = SkyType.rounded(28.sp, FontWeight.SemiBold),
                modifier = Modifier.padding(bottom = 22.dp),
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Symbols.event(show.event), null, tint = Color.White.copy(alpha = 0.92f), modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                "${show.event.title} $time",
                style = SkyType.title3.copy(fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.92f)),
            )
        }
    }
}

/** A small square of the show's own sky with its symbol. */
@Composable
fun SkySwatch(score: Int, event: SunEvent, size: Dp = 44.dp, radius: Dp = 10.dp, icon: ImageVector = Symbols.event(event)) {
    val shape = RoundedCornerShape(radius)
    Box(
        Modifier.size(size).clip(shape).background(Sky.skyGradient(score, event)).border(1.dp, Color.White.copy(alpha = 0.2f), shape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(size * 0.5f))
    }
}

/** A sunrise or sunset as one row: swatch, when, grade, score. */
@Composable
fun ShowRow(show: SunShow, zone: ZoneId, title: String? = null, showsChevron: Boolean = true, onClick: (() -> Unit)? = null) {
    val base = if (onClick != null) Modifier.clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick) else Modifier
    Row(
        base.fillMaxWidth().semantics(mergeDescendants = true) {}.testTag("show-${show.event.raw}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SkySwatch(show.score.total, show.event)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title ?: show.event.title, style = SkyType.headline)
            Text(
                "${SunsetFormat.time(show.time, zone)} · ${show.score.grade.title}",
                style = SkyType.subheadline.copy(color = Sky.textSecondary),
            )
        }
        ScoreChip(show.score)
        if (showsChevron) Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Sky.textSecondary)
    }
}

/** A storm, rainbow chance or fog, with when. */
@Composable
fun SkyEventRow(event: SkyEvent, zone: ZoneId) {
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Symbols.skyEvent(event.kind), null, tint = skyEventTint(event.kind), modifier = Modifier.size(24.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(event.kind.title, style = SkyType.headline)
            Text(
                "${SunsetFormat.dayLabel(event.start, zone)}, ${SunsetFormat.range(event.start, event.end, zone)}",
                style = SkyType.subheadline.copy(color = Sky.textSecondary),
            )
        }
    }
}

/** iOS draws these multicolour; a single warm or cool tint reads the same at a glance. */
fun skyEventTint(kind: SkyEvent.Kind): Color = when (kind) {
    SkyEvent.Kind.THUNDERSTORM -> Sky.gold
    SkyEvent.Kind.RAINBOW -> Sky.rose
    SkyEvent.Kind.FOG -> Color.White
}

@Composable
fun FactorRow(factor: SunsetScore.Factor, tone: Color) {
    Column(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {
            contentDescription = "${factor.name} ${factor.value} out of 100. ${factor.detail}"
        },
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row {
            Text(factor.name, style = SkyType.headline, modifier = Modifier.weight(1f))
            Text("${factor.value}", style = SkyType.headline.copy(color = Sky.textSecondary, fontFeatureSettings = "tnum"))
        }
        BoxWithConstraints(Modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Sky.hairline)) {
            val width = (maxWidth * (factor.value / 100f)).coerceAtLeast(8.dp)
            Box(Modifier.width(width).height(8.dp).clip(CircleShape).background(tone))
        }
        Text(factor.detail, style = SkyType.caption)
    }
}

@Composable
fun ScoreChip(score: SunsetScore) {
    Text(
        "${score.total}",
        style = SkyType.subheadline.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum"),
        modifier = Modifier
            .clip(CircleShape)
            .background(Sky.tone(score.total))
            .border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape)
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .semantics { contentDescription = "Score ${score.total}, ${score.grade.title}" },
    )
}

@Composable
fun PlusCapsule() {
    Text(
        "Sun+",
        style = SkyType.caption.copy(fontWeight = FontWeight.Bold, color = Color.White),
        modifier = Modifier.clip(CircleShape).background(Sky.accent).padding(horizontal = 9.dp, vertical = 4.dp),
    )
}

/** White button with ink text, the one primary action on a screen. */
@Composable
fun PrimaryButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    tag: String? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shape = RoundedCornerShape(17.dp)
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .shadow(10.dp, shape, ambientColor = Color.Black.copy(alpha = 0.18f), spotColor = Color.Black.copy(alpha = 0.18f))
            .clip(shape)
            .background(Color.White)
            .alpha(if (pressed || !enabled) 0.85f else 1f)
            .clickable(interaction, ripple(), enabled = enabled && !loading, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 18.dp, vertical = 15.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(color = Sky.ink, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
        } else {
            Text(label, style = SkyType.headline.copy(color = Sky.ink), textAlign = TextAlign.Center)
        }
    }
}

/** A plain text action in the secondary colour. */
@Composable
fun TextAction(label: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Sky.textSecondary, tag: String? = null) {
    Box(
        modifier
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(8.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = SkyType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = color))
    }
}

/** An iOS inset-grouped section: optional header, rows on a dark glass plate, optional footer. */
@Composable
fun SkySection(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        if (header != null) {
            Text(header.uppercase(), style = SkyType.footnote, modifier = Modifier.padding(start = 16.dp, bottom = 7.dp))
        }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Sky.row), content = content)
        if (footer != null) {
            Text(footer, style = SkyType.footnote, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 7.dp))
        }
    }
}

@Composable
fun RowDivider() {
    Box(Modifier.padding(start = 16.dp).fillMaxWidth().height(0.5.dp).background(Sky.hairline))
}

/** A tappable list row. */
@Composable
fun SkyRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    tag: String? = null,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
fun ToggleRow(
    label: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    tag: String? = null,
) {
    SkyRow(
        Modifier.semantics { role = Role.Switch }.alpha(if (enabled) 1f else 0.6f),
        onClick = if (enabled) ({ onChange(!checked) }) else null,
        tag = tag,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Sky.ember, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(12.dp))
        }
        Text(label, style = SkyType.body, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = if (enabled) onChange else null,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedTrackColor = Sky.ember,
                checkedThumbColor = Color.White,
                uncheckedTrackColor = Color.White.copy(alpha = 0.16f),
                uncheckedThumbColor = Color.White.copy(alpha = 0.85f),
                uncheckedBorderColor = Color.Transparent,
                disabledCheckedTrackColor = Sky.ember.copy(alpha = 0.6f),
                disabledCheckedThumbColor = Color.White,
            ),
        )
    }
}

/** A white selection ring: filled check when on. */
@Composable
fun SelectionMark(selected: Boolean) {
    Box(
        Modifier.size(24.dp).clip(CircleShape)
            .then(if (selected) Modifier.background(Sky.gold) else Modifier.border(BorderStroke(2.dp, Sky.textSecondary), CircleShape)),
        contentAlignment = Alignment.Center,
    ) {
        if (selected) Icon(Icons.Rounded.Check, null, tint = Sky.ink, modifier = Modifier.size(16.dp))
    }
}

/** An iOS segmented picker. */
@Composable
fun <T> Segmented(options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit, tag: String? = null) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Color.White.copy(alpha = 0.12f)).padding(2.dp),
    ) {
        options.forEach { option ->
            val isOn = option == selected
            Box(
                Modifier
                    .weight(1f)
                    .heightIn(min = 36.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .background(if (isOn) Color.White.copy(alpha = 0.32f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onSelect(option) }
                    .semantics { this.selected = isOn }
                    .then(if (tag != null) Modifier.testTag("$tag-$option") else Modifier),
                contentAlignment = Alignment.Center,
            ) {
                Text(label(option), style = SkyType.footnote.copy(color = Color.White, fontWeight = if (isOn) FontWeight.SemiBold else FontWeight.Normal))
            }
        }
    }
}


/** A leading row icon in the accent colour, the iOS `Label` icon. */
@Composable
fun RowIcon(icon: ImageVector) {
    Icon(icon, null, tint = Sky.ember, modifier = Modifier.size(22.dp))
    Spacer(Modifier.width(12.dp))
}

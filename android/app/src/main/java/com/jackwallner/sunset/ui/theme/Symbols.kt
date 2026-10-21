package com.jackwallner.sunset.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Thunderstorm
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SunEvent

/**
 * The SF Symbols the iOS app uses that Material has no match for: sunrise and
 * sunset (half sun with an arrow), rainbow and fog. 24 dp, filled, tinted by
 * the caller.
 */
object Symbols {
    val Sunrise: ImageVector = icon(
        "Sunrise",
        "M2,17h20v2H2z",
        "M7,16a5,5 0 0,1 10,0z",
        "M12,2l3.5,3.5l-1.4,1.4l-1.1,-1.1V10h-2V5.8l-1.1,1.1l-1.4,-1.4z",
    )

    val Sunset: ImageVector = icon(
        "Sunset",
        "M2,17h20v2H2z",
        "M7,16a5,5 0 0,1 10,0z",
        "M12,10l-3.5,-3.5l1.4,-1.4l1.1,1.1V2h2v4.2l1.1,-1.1l1.4,1.4z",
    )

    val Rainbow: ImageVector = icon(
        "Rainbow",
        "M2,18a10,10 0 0,1 20,0h-2.2a7.8,7.8 0 0,0 -15.6,0z",
        "M6.4,18a5.6,5.6 0 0,1 11.2,0h-2.2a3.4,3.4 0 0,0 -6.8,0z",
    )

    val Fog: ImageVector = icon(
        "Fog",
        "M7,13.5a4,4 0 0,1 0.6,-7.95a5.5,5.5 0 0,1 10.2,2.1a3,3 0 0,1 -0.3,5.85z",
        "M3,15.5h18v1.8H3z",
        "M5,19h14v1.8H5z",
    )

    fun event(event: SunEvent): ImageVector = if (event == SunEvent.SUNRISE) Sunrise else Sunset

    fun skyEvent(kind: SkyEvent.Kind): ImageVector = when (kind) {
        SkyEvent.Kind.THUNDERSTORM -> Icons.Rounded.Thunderstorm
        SkyEvent.Kind.RAINBOW -> Rainbow
        SkyEvent.Kind.FOG -> Fog
    }

    private fun icon(name: String, vararg paths: String): ImageVector {
        val builder = ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f)
        paths.forEach { builder.addPath(addPathNodes(it), fill = SolidColor(Color.Black)) }
        return builder.build()
    }
}

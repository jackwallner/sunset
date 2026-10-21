package com.jackwallner.sunset.model

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/** Ports `SunsetFormat.swift`, with the Android 12/24-hour setting in place of the iOS locale default. */
object SunsetFormat {
    /** Set from the system clock setting at launch; null follows the locale. */
    @Volatile var use24Hour: Boolean? = null

    fun time(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String {
        val locale = Locale.getDefault()
        val formatter = when (use24Hour) {
            true -> DateTimeFormatter.ofPattern("HH:mm", locale)
            false -> DateTimeFormatter.ofPattern("h:mm a", locale)
            null -> DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale)
        }
        return formatter.format(instant.atZone(zone))
    }

    /** "Today", "Tomorrow", then the weekday. */
    fun dayLabel(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), now: Instant = Instant.now()): String {
        val date = instant.atZone(zone).toLocalDate()
        val today = now.atZone(zone).toLocalDate()
        return when (date) {
            today -> "Today"
            today.plusDays(1) -> "Tomorrow"
            else -> weekday(instant, zone)
        }
    }

    /** "Tonight's sunset", "Tomorrow's sunrise", "Friday's sunset". */
    fun headline(show: SunShow, zone: ZoneId = ZoneId.systemDefault(), now: Instant = Instant.now()): String {
        val event = show.event.title.lowercase()
        val date = show.time.atZone(zone).toLocalDate()
        val today = now.atZone(zone).toLocalDate()
        return when (date) {
            today -> if (show.event == SunEvent.SUNSET) "Tonight's $event" else "This morning's $event"
            today.plusDays(1) -> "Tomorrow's $event"
            else -> "${weekday(show.time, zone)}'s $event"
        }
    }

    /** "today", "tonight", "tomorrow", "on Friday", for alert titles. */
    fun relativeDay(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), now: Instant = Instant.now()): String {
        val local = instant.atZone(zone)
        val today = now.atZone(zone).toLocalDate()
        return when (local.toLocalDate()) {
            today -> if (local.hour >= 17) "tonight" else "today"
            today.plusDays(1) -> if (local.hour < 12) "tomorrow morning" else "tomorrow"
            else -> "on ${weekday(instant, zone)}"
        }
    }

    /** "sunset", "sunrise", "sunrise or sunset"; plural "sunrises and sunsets". */
    fun watchedNoun(events: Set<SunEvent>, plural: Boolean = false): String =
        SunEvent.entries.filter { it in events }
            .joinToString(if (plural) " and " else " or ") { it.raw + if (plural) "s" else "" }

    fun weekday(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofPattern("EEEE", Locale.getDefault()).format(instant.atZone(zone))

    fun monthDay(instant: Instant, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ofPattern("MMM d", Locale.getDefault()).format(instant.atZone(zone))

    fun minutes(minutes: Int): String {
        if (minutes % 60 == 0 && minutes >= 60) {
            val hours = minutes / 60
            return if (hours == 1) "1 hour" else "$hours hours"
        }
        return "$minutes min"
    }

    /** "6:21 PM–6:56 PM", the iOS en dash range. */
    fun range(start: Instant, end: Instant, zone: ZoneId): String = "${time(start, zone)}–${time(end, zone)}"
}

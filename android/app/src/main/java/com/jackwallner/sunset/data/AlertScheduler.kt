package com.jackwallner.sunset.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.jackwallner.sunset.MainActivity
import com.jackwallner.sunset.R
import com.jackwallner.sunset.SunsetApplication
import com.jackwallner.sunset.model.AlertPlanner
import com.jackwallner.sunset.model.SunsetForecast
import java.time.Instant

/**
 * Local alerts for the skies worth going outside for, the Android side of
 * `NotificationService.swift`. Every refresh rewrites the whole set from the
 * latest forecast, so a show that drops below the threshold loses its alert.
 * Inexact alarms (a ten-minute window) need no exact-alarm declaration.
 */
class AlertScheduler(private val context: Context, private val defaults: KeyValueStore) {
    /** Set by the activity on API 33+: shows the system dialog and returns whether it was granted. */
    var requestPermission: (suspend () -> Boolean)? = null

    val isAuthorized: Boolean
        get() {
            if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) return false
            return NotificationManagerCompat.from(context).areNotificationsEnabled()
        }

    /** Refused, as opposed to never asked: iOS `.denied` versus `.notDetermined`. */
    val isDenied: Boolean get() = !isAuthorized && (Build.VERSION.SDK_INT < 33 || defaults.getBoolean(ASKED))

    suspend fun requestAuthorization(): Boolean {
        if (isAuthorized) return true
        if (Build.VERSION.SDK_INT < 33) return false
        val ask = requestPermission ?: return false
        defaults.putBoolean(ASKED, true)
        return ask()
    }

    fun reschedule(forecast: SunsetForecast?, settings: AlertSettings, isPro: Boolean, now: Instant = Instant.now()) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        defaults.getStringSet(SCHEDULED).forEach { alarms.cancel(pendingIntent(it, null, null)) }
        defaults.putStringSet(SCHEDULED, emptySet())

        if (!settings.alertsEnabled || forecast == null || !isAuthorized) return
        val planned = AlertPlanner.plan(
            forecast = forecast,
            watched = settings.watched,
            threshold = settings.effectiveThreshold(isPro),
            leadMinutes = settings.effectiveLead(isPro),
            skyEventKinds = settings.effectiveSkyEvents(isPro),
            now = now,
        )
        for (alert in planned) {
            alarms.setWindow(AlarmManager.RTC_WAKEUP, alert.fireDate.toEpochMilli(), WINDOW_MS, pendingIntent(alert.identifier, alert.title, alert.body))
        }
        defaults.putStringSet(SCHEDULED, planned.map { it.identifier }.toSet())
    }

    private fun pendingIntent(identifier: String, title: String?, body: String?): PendingIntent {
        val intent = Intent(context, AlertReceiver::class.java).apply {
            action = ACTION
            // The identifier in the data URI keeps every alert's PendingIntent distinct.
            data = android.net.Uri.parse("sunset-alert://$identifier")
            putExtra(EXTRA_ID, identifier)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    companion object {
        const val CHANNEL = "sunset.alerts"
        const val ACTION = "com.jackwallner.sunset.ALERT"
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        private const val SCHEDULED = "sunset.alerts.scheduled"
        private const val ASKED = "sunset.notifications.asked"
        private const val WINDOW_MS = 10 * 60 * 1000L

        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            val channel = NotificationChannel(CHANNEL, context.getString(R.string.notification_channel), NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = context.getString(R.string.notification_channel_description)
            manager.createNotificationChannel(channel)
        }
    }
}

/** Posts one planned alert when its alarm fires. */
class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(AlertScheduler.EXTRA_ID) ?: return
        val title = intent.getStringExtra(AlertScheduler.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(AlertScheduler.EXTRA_BODY).orEmpty()
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        AlertScheduler.ensureChannel(context)
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, AlertScheduler.CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(0xFFF57338.toInt())
            .setGroup("sunset.alerts")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id.hashCode(), notification) }
    }
}

private val RESCHEDULE_ACTIONS = setOf(
    Intent.ACTION_BOOT_COMPLETED,
    Intent.ACTION_MY_PACKAGE_REPLACED,
    Intent.ACTION_TIMEZONE_CHANGED,
    Intent.ACTION_TIME_CHANGED,
)

/** Alarms die with a reboot or an app update; rebuild them from the cached forecast. */
class AlertRescheduler : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in RESCHEDULE_ACTIONS) return
        val graph = (context.applicationContext as SunsetApplication).graph
        graph.rescheduleAlerts()
        RefreshWorker.schedule(context)
    }
}

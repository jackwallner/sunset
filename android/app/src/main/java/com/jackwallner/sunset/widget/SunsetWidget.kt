package com.jackwallner.sunset.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.jackwallner.sunset.MainActivity
import com.jackwallner.sunset.R
import com.jackwallner.sunset.data.ForecastCache
import com.jackwallner.sunset.data.RefreshWorker
import com.jackwallner.sunset.data.SharedPreferencesStore
import com.jackwallner.sunset.model.Rgb
import com.jackwallner.sunset.model.SkyPalette
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetForecast
import java.time.Instant

/**
 * The next watched sunrise or sunset on the Home Screen, the iOS
 * `SunsetWidget`. Reads the snapshot the app writes; when that is stale and a
 * location is cached it asks the background worker to fetch, so the widget
 * stays right even if the app has not been opened for days. The system
 * redraws it every 30 minutes, which rolls it to the next show half an hour
 * after this one.
 */
class SunsetWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cache = ForecastCache(SharedPreferencesStore(context))
        val forecast = cache.forecast
        if ((forecast == null || forecast.isStale()) && cache.location != null) RefreshWorker.refreshSoon(context)
        ids.forEach { manager.updateAppWidget(it, views(context, forecast, cache.watchedEvents, manager.getAppWidgetOptions(it))) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        val cache = ForecastCache(SharedPreferencesStore(context))
        manager.updateAppWidget(id, views(context, cache.forecast, cache.watchedEvents, options))
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SunsetWidget::class.java))
            if (ids.isEmpty()) return
            context.sendBroadcast(
                Intent(context, SunsetWidget::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }

        fun views(context: Context, forecast: SunsetForecast?, watched: Set<SunEvent>, options: Bundle?): RemoteViews {
            val now = Instant.now()
            val show: SunShow? = forecast?.upcomingShows(watched, now)?.firstOrNull()
            val wide = (options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0) >= 220
            val views = RemoteViews(context.packageName, R.layout.widget_sunset)
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(android.R.id.background, open)
            if (show == null || forecast == null) {
                views.setImageViewBitmap(R.id.widget_sky, sky(SkyPalette.sky(55)))
                views.setTextViewText(R.id.widget_headline, "")
                views.setTextViewText(R.id.widget_score, "")
                views.setTextViewText(R.id.widget_grade, "")
                views.setTextViewText(R.id.widget_time, context.getString(R.string.widget_empty))
                views.setViewVisibility(R.id.widget_summary, View.GONE)
                return views
            }
            val zone = forecast.zone
            val time = SunsetFormat.time(show.time, zone)
            views.setImageViewBitmap(R.id.widget_sky, sky(SkyPalette.sky(show.score.total, show.event)))
            views.setTextViewText(R.id.widget_headline, SunsetFormat.headline(show, zone, now))
            views.setTextViewText(R.id.widget_score, "${show.score.total}")
            views.setTextViewTextSize(R.id.widget_score, android.util.TypedValue.COMPLEX_UNIT_SP, if (wide) 52f else 44f)
            views.setTextViewText(R.id.widget_grade, show.score.grade.title)
            views.setTextViewText(R.id.widget_time, "${show.event.title} $time")
            views.setTextViewText(R.id.widget_summary, show.score.summary)
            views.setViewVisibility(R.id.widget_summary, if (wide) View.VISIBLE else View.GONE)
            views.setContentDescription(
                android.R.id.background,
                "${SunsetFormat.headline(show, zone, now)}, score ${show.score.total}, ${show.score.grade.title}. ${show.event.title} at $time",
            )
            return views
        }

        /** The show's own sky, top to bottom, with rounded corners for launchers that do not clip widgets. */
        private fun sky(colors: List<Rgb>): Bitmap {
            val size = 240
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, 0f, size.toFloat(), colors.map(::argb).toIntArray(), null, Shader.TileMode.CLAMP)
            }
            Canvas(bitmap).drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), 24f, 24f, paint)
            return bitmap
        }

        private fun argb(rgb: Rgb): Int {
            fun channel(value: Double) = (value.coerceIn(0.0, 1.0) * 255 + 0.5).toInt()
            return (0xFF shl 24) or (channel(rgb.red) shl 16) or (channel(rgb.green) shl 8) or channel(rgb.blue)
        }
    }
}

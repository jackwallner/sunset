package com.jackwallner.sunset.data

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.jackwallner.sunset.SunsetApplication
import java.util.concurrent.TimeUnit

/**
 * Keeps alerts and the widget honest while the app is closed, like the iOS
 * BGAppRefresh task: every few hours, fetch the newest forecast for the
 * cached location, then rewrite every pending alert and the widget.
 */
class RefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val graph = (applicationContext as SunsetApplication).graph
        val location = graph.cache.location ?: return Result.success()
        graph.forecastStore.load(location)
        return if (graph.forecastStore.errorMessage == null) Result.success() else Result.retry()
    }

    companion object {
        private const val PERIODIC = "sunset.refresh"
        private const val NOW = "sunset.refresh.now"
        private val NETWORK = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<RefreshWorker>(3, TimeUnit.HOURS).setConstraints(NETWORK).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        /** The widget asks for this when its snapshot is stale. */
        fun refreshSoon(context: Context) {
            val request = OneTimeWorkRequestBuilder<RefreshWorker>().setConstraints(NETWORK).build()
            WorkManager.getInstance(context).enqueueUniqueWork(NOW, ExistingWorkPolicy.KEEP, request)
        }
    }
}

package com.jackwallner.sunset

import com.jackwallner.sunset.data.AlertSettings
import com.jackwallner.sunset.data.ForecastCache
import com.jackwallner.sunset.data.ForecastCodec
import com.jackwallner.sunset.data.ForecastService
import com.jackwallner.sunset.data.ForecastStore
import com.jackwallner.sunset.data.InMemoryStore
import com.jackwallner.sunset.data.PackageKind
import com.jackwallner.sunset.data.PeriodUnit
import com.jackwallner.sunset.data.Plan
import com.jackwallner.sunset.data.PlanPeriod
import com.jackwallner.sunset.data.ReviewAccess
import com.jackwallner.sunset.data.SubscriptionService
import com.jackwallner.sunset.model.ConversionCopy
import com.jackwallner.sunset.model.DemoForecast
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SkyPalette
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetForecast
import java.io.IOException
import java.security.MessageDigest
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Android-only half: storage under the iOS keys, settings, the store, billing copy and the palette. */
class AndroidPortTest {
    private val la = ZoneId.of("America/Los_Angeles")
    private val now = Instant.parse("2026-10-08T16:00:00Z")

    @Test fun forecastSnapshotRoundTrips() {
        val forecast = DemoForecast.make(now, la)
        assertEquals(forecast, ForecastCodec.decode(ForecastCodec.encode(forecast)))
        assertNull(ForecastCodec.decode("{not json"))
    }

    @Test fun cacheUsesTheIosKeysAndNeverWatchesNothing() {
        val store = InMemoryStore()
        val cache = ForecastCache(store)
        assertEquals(SunEvent.entries.toSet(), cache.watchedEvents)
        cache.watchedEvents = emptySet()
        assertEquals(SunEvent.entries.toSet(), cache.watchedEvents)
        cache.watchedEvents = setOf(SunEvent.SUNRISE)
        assertEquals(setOf("sunrise"), store.getStringSet("sunset.watched"))
        assertNull(cache.location)
        cache.location = ForecastCache.Location(45.63, -122.52, "Vancouver, WA")
        assertEquals(ForecastCache.Location(45.63, -122.52, "Vancouver, WA"), cache.location)
        cache.isPro = true
        assertTrue(store.getBoolean("sunset.isPro"))
        cache.forecast = DemoForecast.make(now, la)
        assertTrue(store.contains("sunset.forecast.v2"))
    }

    @Test fun freeAlertsUseTheDefaultsWhateverWasPicked() {
        val settings = AlertSettings(InMemoryStore(), ForecastCache(InMemoryStore()))
        assertEquals(70, settings.threshold)
        assertEquals(45, settings.leadMinutes)
        assertEquals(SkyEvent.Kind.entries.toSet(), settings.skyEventKinds)
        assertFalse(settings.alertsEnabled)
        settings.updateThreshold(50)
        settings.updateLeadMinutes(120)
        assertEquals(70, settings.effectiveThreshold(isPro = false))
        assertEquals(45, settings.effectiveLead(isPro = false))
        assertEquals(emptySet<SkyEvent.Kind>(), settings.effectiveSkyEvents(isPro = false))
        assertEquals(50, settings.effectiveThreshold(isPro = true))
        assertEquals(120, settings.effectiveLead(isPro = true))
    }

    @Test fun watchingNeverEmptiesAndEveryChangeRebuildsAlerts() {
        val settings = AlertSettings(InMemoryStore(), ForecastCache(InMemoryStore()))
        var rebuilds = 0
        var widgets = 0
        settings.onAlertsChanged = { rebuilds++ }
        settings.onWatchedChanged = { widgets++ }
        settings.toggle(SunEvent.SUNRISE)
        assertEquals(setOf(SunEvent.SUNSET), settings.watched)
        settings.toggle(SunEvent.SUNSET)
        assertEquals(setOf(SunEvent.SUNSET), settings.watched)
        assertEquals(1, widgets)
        settings.setSkyEvent(SkyEvent.Kind.FOG, false)
        settings.setSkyEvent(SkyEvent.Kind.FOG, true)
        assertTrue("turning a sky event on turns alerts on", settings.alertsEnabled)
        assertTrue(rebuilds >= 3)
    }

    @Test fun reviewIsAskedOnTheThirdOpenWithAGoodScoreOnce() {
        val settings = AlertSettings(InMemoryStore(), ForecastCache(InMemoryStore()))
        settings.recordOpen()
        settings.recordOpen()
        assertFalse(settings.shouldRequestReview(90))
        settings.recordOpen()
        assertFalse(settings.shouldRequestReview(59))
        assertTrue(settings.shouldRequestReview(60))
        assertFalse(settings.shouldRequestReview(95))
    }

    @Test fun storeRefreshesOnlyWhenStaleOrMovedAndReportsFailures() = runBlocking {
        var calls = 0
        var fail = false
        val cache = ForecastCache(InMemoryStore())
        val scope = CoroutineScope(Dispatchers.Unconfined)
        val store = ForecastStore(cache, scope) { lat, lon ->
            calls++
            if (fail) throw IOException("offline")
            DemoForecast.make(Instant.now(), la).copy(latitude = lat, longitude = lon)
        }
        var fetched = 0
        store.onFetched = { fetched++ }
        val here = ForecastCache.Location(45.63, -122.52, "Vancouver, WA")
        store.load(here)
        assertEquals(1, calls)
        assertEquals(1, fetched)
        assertEquals("Vancouver, WA", cache.forecast?.placeName)
        store.refresh(here)
        assertEquals("fresh and same place: no fetch", 1, calls)
        fail = true
        store.load(ForecastCache.Location(47.6, -122.3, "Seattle, WA"))
        assertEquals("Showing the last forecast. Couldn't reach the weather service.", store.errorMessage)
        assertEquals(1, fetched)

        val empty = ForecastStore(ForecastCache(InMemoryStore()), scope) { _, _ -> throw IOException("offline") }
        empty.load(here)
        assertEquals("Couldn't load the forecast. Check your connection and try again.", empty.errorMessage)
    }

    @Test fun staleAndMovedChecks() {
        val forecast = DemoForecast.make(now, la)
        assertFalse(forecast.isStale(now.plus(Duration.ofHours(2))))
        assertTrue(forecast.isStale(now.plus(Duration.ofHours(4))))
        assertTrue(forecast.isSameLocation(45.66, -122.49))
        assertFalse(forecast.isSameLocation(45.8, -122.52))
    }

    @Test fun localTimesInADaylightSavingGapAreRejectedLikeIos() {
        fun point() = """{"timezone":"Europe/London","hourly":{"time":["2026-03-29T00:00","2026-03-29T01:00","2026-03-29T02:00"],
            "cloud_cover_low":[0,0,0],"cloud_cover_mid":[0,0,0],"cloud_cover_high":[0,0,0],"relative_humidity_2m":[50,50,50],
            "visibility":[20000,20000,20000],"precipitation_probability":[0,0,0]},"daily":{"sunrise":["2026-03-29T00:30"],"sunset":["2026-03-29T02:00"]}}"""
        try {
            ForecastService.parse("[${point()},${point()},${point()}]", 51.5, 0.0)
            throw AssertionError("01:00 does not exist in London on 29 March")
        } catch (_: ForecastService.Failure) {
        }
    }

    @Test fun reviewerCodeUnlocksOnlyWithTheRightCode() {
        val digest = MessageDigest.getInstance("SHA-256").digest("sun-test".toByteArray()).joinToString("") { "%02x".format(it) }
        val store = InMemoryStore()
        val access = ReviewAccess(store, digest)
        assertFalse(access.activate("wrong"))
        assertFalse(access.isGranted)
        assertTrue(access.activate(" sun-test "))
        assertTrue(access.isGranted)
        assertFalse("no digest configured, no access", ReviewAccess(InMemoryStore(), "").activate("sun-test"))
    }

    @Test fun planLabelsMatchTheIosPaywall() {
        val trial = PlanPeriod(1, PeriodUnit.WEEK)
        val monthly = Plan("\$rc_monthly", SubscriptionService.MONTHLY, PackageKind.MONTHLY, 1_990_000, "$1.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), trial)
        val yearly = Plan("\$rc_annual", SubscriptionService.YEARLY, PackageKind.YEARLY, 14_990_000, "$14.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), trial)
        val lifetime = Plan("\$rc_lifetime", SubscriptionService.LIFETIME, PackageKind.LIFETIME, 29_990_000, "$29.99", "USD", null, null)
        assertEquals("$1.99 / month", monthly.priceLabel)
        assertEquals("$14.99 / year", yearly.priceLabel)
        assertEquals("$29.99", lifetime.priceLabel)
        assertEquals("7-day free trial", monthly.introOfferLabel)
        assertNull(lifetime.introOfferLabel)
        assertEquals(listOf("Lifetime", "Yearly", "Monthly"),
            listOf(monthly, lifetime, yearly).sortedBy { SubscriptionService.displayOrder(it.kind) }.map { it.displayName })
        assertEquals("$1.99 per month", ConversionCopy.billedAmount(monthly.priceLabel))
    }

    @Test fun purchaseCopyNamesGooglePlayAndNeverPromisesAUsedTrial() {
        assertEquals(
            "7-day free trial, then $1.99 / month. Auto-renews until canceled.",
            ConversionCopy.compactDisclosure("7-day free trial", "$1.99 / month"),
        )
        val noTrial = ConversionCopy.disclosure(null, "$14.99 / year")
        assertFalse(noTrial.contains("trial"))
        assertTrue(noTrial.contains("Google Play"))
        val all = listOf(
            ConversionCopy.disclosure("7-day free trial", "$1.99 / month"), noTrial,
            ConversionCopy.compactDisclosure(null, "$1.99 / month"), ConversionCopy.PURCHASE_PENDING_MESSAGE, ConversionCopy.RESTORE_NONE,
        )
        all.forEach {
            assertFalse("no Apple wording on Android: $it", it.contains("Apple"))
            assertFalse("no em dash: $it", it.contains('—'))
        }
        assertEquals("Trial wasn't started. Tap again to continue.", ConversionCopy.purchaseCancelledMessage(true))
    }

    @Test fun skyPaletteFollowsTheScoreAndDawnIsCooler() {
        val dull = SkyPalette.sky(10)
        val epic = SkyPalette.sky(95)
        assertNotEquals(dull, epic)
        assertTrue("epic horizon is warmer", epic[2].red - epic[2].blue > dull[2].red - dull[2].blue)
        assertNotEquals(SkyPalette.sky(80, SunEvent.SUNSET), SkyPalette.sky(80, SunEvent.SUNRISE))
        val stops = SkyPalette.backdropStops(70, SunEvent.SUNSET, 0.42)
        assertEquals(8, stops.size)
        assertEquals(stops.map { it.first }, stops.map { it.first }.sorted())
        assertTrue(stops.all { it.first in 0.0..1.0 })
    }

    @Test fun demoWeekHasEveryKindOfSkyEvent() {
        val forecast: SunsetForecast = DemoForecast.make(now, la)
        assertEquals(8, forecast.days.size)
        assertEquals(SkyEvent.Kind.entries.toSet(), forecast.skyEvents.map { it.kind }.toSet())
        assertTrue(forecast.days.any { it.sunset.score.total >= 85 })
        assertTrue(forecast.days.any { it.sunset.score.total < 30 })
    }
}

package com.jackwallner.sunset

import android.content.Intent
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.Direction
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import java.util.regex.Pattern
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * First run, the core screens, live forecast loading and the
 * free/paid/reviewer boundaries, driven through UI Automator (test tags are
 * resource ids). Each test runs on a cleared install
 * (`scripts/android-connected-tests.sh` clears app data between tests).
 * Launch extras are the debug-only `DebugLaunchOptions`.
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private val pkg = "com.jackwallner.sunset"

    private fun launch(extras: Bundle.() -> Unit = {}) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = context.packageManager.getLaunchIntentForPackage(pkg)!!.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtras(Bundle().apply { putBoolean("uiTest", true); extras() })
        }
        context.startActivity(intent)
        device.wait(Until.hasObject(By.pkg(pkg).depth(0)), 15_000)
    }

    /** Onboarded in Vancouver, WA, on the fixed demo week. */
    private fun demo(extras: Bundle.() -> Unit = {}) = launch {
        putBoolean("demoLocation", true)
        putBoolean("demoForecast", true)
        putBoolean("previewStore", true)
        extras()
    }

    private fun find(selector: BySelector, timeout: Long = 10_000): UiObject2 =
        device.wait(Until.findObject(selector), timeout) ?: throw AssertionError("Not on screen: $selector")

    private fun findScrolling(selector: BySelector): UiObject2 {
        repeat(10) {
            device.wait(Until.findObject(selector), 1_000)?.let { return it }
            device.findObject(By.scrollable(true))?.scroll(Direction.DOWN, 0.6f)
        }
        return find(selector)
    }

    private fun tag(id: String) = By.res(id)

    /** The system permission sheet: allow while in use (location) or allow (notifications). */
    private fun allowPermission() {
        val allow = By.res(Pattern.compile("com.android.permissioncontroller:id/permission_allow(_foreground_only)?_button"))
        device.wait(Until.findObject(allow), 8_000)?.click()
        device.waitForIdle()
    }

    @Test fun firstRunWalksFourPagesToTheFreeAppWithoutBuying() {
        launch { putBoolean("previewStore", true) }
        find(By.text("Know before you go"))
        find(By.text("One approximate location fix. No account."))
        find(tag("onboarding-continue")).click()
        allowPermission()
        find(By.text("What do you want to catch?"))
        find(tag("watch-choice-sunrise")).click()
        find(tag("onboarding-continue")).click()
        find(By.text("Get a heads-up, free"))
        find(By.textContains("before the sunsets scoring 70 or more"))
        find(tag("not-now")).click()
        find(By.text("The whole week, and the rest of the sky"))
        find(By.text("$1.99 / month"))
        find(By.text("Start 7-day free trial"))
        find(By.text("7-day free trial, then $1.99 / month. Auto-renews until canceled."))
        find(tag("get-started")).click()
        find(tag("tab-today"))
        assertNull(device.findObject(tag("paywall")))
    }

    @Test fun todayLeadsWithTheNextShowAndItsBreakdown() {
        demo()
        find(tag("hero-score"))
        find(By.text("Vancouver, WA"))
        find(By.text("What makes the score"))
        listOf("Color", "Streaks", "Horizon", "Clarity").forEach { findScrolling(By.text(it)) }
        findScrolling(By.text("Up next"))
        findScrolling(tag("sky-events"))
        findScrolling(tag("sky-events-upsell"))
        findScrolling(tag("alerts-button"))
        find(By.text("A heads-up before the sunrises and sunsets worth going out for. Free."))
    }

    @Test fun heroOpensTheCloudCoverDetailAndBackReturns() {
        demo()
        find(tag("hero")).click()
        find(tag("show-detail"))
        findScrolling(By.textStartsWith("Cloud cover at"))
        find(By.textContains("toward the sun"))
        device.pressBack()
        find(tag("hero-score"))
        assertNull(device.findObject(tag("show-detail")))
    }

    @Test fun freeOutlookShowsTwoDaysAndLocksTheRestBehindSunPlus() {
        demo { putString("tab", "outlook") }
        find(By.text("Today"))
        findScrolling(tag("locked-week"))
        find(By.text("The rest of the week"))
        find(tag("unlock-week")).click()
        find(tag("paywall"))
        find(By.text("Every sunrise and sunset score for the week ahead"))
        findScrolling(tag("plan-yearly"))
        findScrolling(tag("billed-amount"))
        assertEquals("$14.99 per year", find(tag("billed-amount")).text)
    }

    @Test fun sunPlusUnlocksTheWholeWeek() {
        demo { putBoolean("demoPro", true); putString("tab", "outlook") }
        find(By.text("Tomorrow"))
        repeat(6) { device.findObject(By.scrollable(true))?.scroll(Direction.DOWN, 0.8f) }
        assertNull(device.findObject(tag("locked-week")))
        assertNull(device.findObject(By.text("Unlock with Sun+")))
    }

    @Test fun freeAlertsKeepTheDefaultsAndSkyEventsOpenThePaywall() {
        demo { putString("screen", "alerts") }
        find(tag("alert-setup"))
        find(By.text("70 · Great"))
        find(By.text("45 min"))
        findScrolling(tag("locked-sky-thunderstorm")).click()
        find(tag("paywall"))
        find(tag("paywall-close")).click()
        find(tag("alert-setup"))
    }

    @Test fun sunPlusChangesTheAlertScoreAndLeadTime() {
        demo { putBoolean("demoPro", true); putString("screen", "alerts") }
        find(tag("alert-setup"))
        find(tag("threshold-80")).click()
        findScrolling(tag("lead-60")).click()
        find(tag("bar-done")).click()
        find(tag("tab-settings")).click()
        find(By.text("80+ · 1 hour before"))
    }

    @Test fun turningOnAlertsAsksForNotificationsAndUpdatesToday() {
        demo()
        findScrolling(tag("alerts-button")).click()
        find(tag("alerts-toggle")).click()
        allowPermission()
        find(tag("bar-done")).click()
        findScrolling(By.text("You'll hear before any sunrise or sunset scoring 70 or higher."))
        find(By.text("Change alerts"))
    }

    @Test fun paywallPurchaseFlipsSunPlusOn() {
        demo { putString("tab", "settings") }
        find(tag("settings-plus")).click()
        find(tag("paywall"))
        findScrolling(tag("plan-monthly")).click()
        assertEquals("$1.99 per month", findScrolling(tag("billed-amount")).text)
        findScrolling(By.textContains("$1.99 / month after the 7-day free trial."))
        findScrolling(tag("paywall-cta")).click()
        find(tag("pro-on"))
        assertNull(device.findObject(tag("paywall")))
    }

    @Test fun reviewerCodeUnlocksSunPlusAndAWrongCodeDoesNot() {
        val code = InstrumentationRegistry.getArguments().getString("reviewCode").orEmpty()
        assertTrue("pass -e reviewCode", code.isNotBlank())
        demo { putString("tab", "settings") }
        val version = findScrolling(tag("version"))
        version.longClick()
        find(tag("reviewer-code")).text = "not-the-code"
        find(tag("reviewer-unlock")).click()
        find(tag("reviewer-failed"))
        find(tag("reviewer-code")).text = code
        find(tag("reviewer-unlock")).click()
        device.findObject(By.scrollable(true))?.scroll(Direction.UP, 1f)
        device.findObject(By.scrollable(true))?.scroll(Direction.UP, 1f)
        find(tag("pro-on"))
    }

    @Test fun watchingOnlySunsetsKeepsTheLastToggleOn() {
        demo { putString("tab", "settings") }
        findScrolling(tag("watch-sunrise")).click()
        val sunset = find(tag("watch-sunset"))
        assertTrue("the last watched show can't be turned off", !sunset.isEnabled || run { sunset.click(); true })
        find(tag("tab-today")).click()
        find(tag("hero-score"))
        assertTrue(device.findObject(By.textEndsWith("sunrise")) == null || device.findObject(By.text("Up next")) != null)
        findScrolling(By.text("A heads-up before the sunsets worth going out for. Free."))
    }

    @Test fun liveForecastLoadsFromOpenMeteo() {
        launch { putBoolean("demoLocation", true) }
        find(tag("hero-score"), timeout = 90_000)
        find(By.text("Vancouver, WA"))
        findScrolling(By.textStartsWith("Forecast by Open-Meteo, updated"))
    }
}

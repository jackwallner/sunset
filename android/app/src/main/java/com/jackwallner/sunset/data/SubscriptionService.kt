package com.jackwallner.sunset.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sunset.BuildConfig
import com.jackwallner.sunset.model.ConversionCopy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import kotlin.coroutines.cancellation.CancellationException

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

internal fun purchaseOutcome(code: PurchasesErrorCode, userCancelled: Boolean): PurchaseOutcome? = when {
    userCancelled || code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.CANCELLED
    code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.PENDING
    else -> null
}

private fun Period.toPlanPeriod(): PlanPeriod? {
    val unit = when (unit) {
        Period.Unit.DAY -> PeriodUnit.DAY
        Period.Unit.WEEK -> PeriodUnit.WEEK
        Period.Unit.MONTH -> PeriodUnit.MONTH
        Period.Unit.YEAR -> PeriodUnit.YEAR
        else -> return null
    }
    return PlanPeriod(value, unit)
}

/**
 * RevenueCat behind Sun+, the Android side of `StoreService.swift`. Debug
 * builds use the project's Test Store key and release builds the Play key;
 * neither ever runs on the other. The `pro` entitlement unlocks Sun+.
 */
class SubscriptionService(
    private val context: Context,
    private val defaults: KeyValueStore,
    private val cache: ForecastCache,
) {
    /** Called whenever Sun+ turns on or off, so alerts and the widget follow. */
    var onProChanged: () -> Unit = {}

    private val reviewAccess = ReviewAccess(defaults, BuildConfig.PLAY_REVIEW_CODE_SHA256)
    private var entitlementActive by mutableStateOf(cache.isPro)
    private var overrideActive by mutableStateOf(BuildConfig.DEBUG && defaults.getBoolean(LOCAL_OVERRIDE))
    private var reviewGranted by mutableStateOf(reviewAccess.isGranted)

    /** The single gate the whole app reads. */
    val isPro: Boolean get() = entitlementActive || overrideActive || reviewGranted

    val hasReviewAccess: Boolean get() = reviewGranted

    var isConfigured by mutableStateOf(false)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isLoadingProducts by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var plans by mutableStateOf<List<Plan>>(emptyList())
        private set
    /** Until customer info has answered, never promise a trial (it may already be used). */
    var introEligibilityResolved by mutableStateOf(false)
        private set
    private var hasSubscriptionHistory by mutableStateOf(false)

    private var packages: List<Package> = emptyList()
    private var offering: Offering? = null
    private var customerInfoLoaded = false
    private var isPreview = false
    private val impressionsThisSession = mutableSetOf<String>()

    val monthlyPlan: Plan? get() = plans.firstOrNull { it.kind == PackageKind.MONTHLY }
    val yearlyPlan: Plan? get() = plans.firstOrNull { it.kind == PackageKind.YEARLY }

    fun setLocalOverride(value: Boolean) {
        if (!BuildConfig.DEBUG) return
        val was = isPro
        defaults.putBoolean(LOCAL_OVERRIDE, value)
        overrideActive = value
        publish(was)
    }

    /** Debug screenshots and UI tests: a local plan stack with no store behind it. */
    fun loadPreviewPlans(preview: List<Plan>, trialUsed: Boolean = false) {
        if (!BuildConfig.DEBUG) return
        plans = preview
        packages = emptyList()
        hasSubscriptionHistory = trialUsed
        introEligibilityResolved = true
        isConfigured = true
        isPreview = true
        errorMessage = null
    }

    fun activateReviewAccess(code: String): Boolean {
        if (!reviewAccess.activate(code)) return false
        val was = isPro
        reviewGranted = true
        publish(was)
        return true
    }

    suspend fun start(forceRefresh: Boolean = false) {
        if (isPreview) return
        if (!configureIfNeeded()) {
            errorMessage = UNAVAILABLE
            return
        }
        refreshCustomerInfo()
        fetchProducts(forceRefresh)
    }

    suspend fun refreshCustomerInfo() {
        if (isPreview || !configureIfNeeded()) return
        runCatching { Purchases.sharedInstance.awaitCustomerInfo() }
            .onSuccess(::apply)
            .onFailure { if (it is CancellationException) throw it }
    }

    private suspend fun fetchProducts(@Suppress("UNUSED_PARAMETER") forceRefresh: Boolean) {
        if (isLoadingProducts) return
        isLoadingProducts = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val offering = offerings.all[OFFERING_ID] ?: offerings.current
            val loaded = offering?.availablePackages.orEmpty().sortedBy { displayOrder(kind(it)) }
            this.offering = offering
            packages = loaded
            plans = loaded.map(::plan)
            errorMessage = if (loaded.isEmpty()) UNAVAILABLE else null
            if (!customerInfoLoaded) refreshCustomerInfo()
            introEligibilityResolved = customerInfoLoaded
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            errorMessage = UNAVAILABLE
        } finally {
            isLoadingProducts = false
        }
    }

    /** Defaults to not eligible until RevenueCat answers, so nobody is promised a trial they already used. */
    fun isEligibleForIntroOffer(plan: Plan): Boolean =
        plan.trial != null && introEligibilityResolved && !hasSubscriptionHistory

    fun eligibleIntroLabel(plan: Plan): String? = if (isEligibleForIntroOffer(plan)) plan.introOfferLabel else null

    /** RevenueCat's paywall encounters, once per id per session; a custom paywall emits none of its own. */
    fun trackPaywallImpression(id: String) {
        if (!impressionsThisSession.add(id) || !isConfigured || isPreview) return
        val params = offering?.let { CustomPaywallImpressionParams(id, it) } ?: CustomPaywallImpressionParams(id)
        runCatching { Purchases.sharedInstance.trackCustomPaywallImpression(params) }
    }

    /** A cancel is an outcome, not an error; [errorMessage] carries what to show. Null means it failed. */
    suspend fun purchase(activity: Activity, plan: Plan): PurchaseOutcome? {
        val eligible = isEligibleForIntroOffer(plan)
        errorMessage = null
        if (isPreview) {
            setLocalOverride(true)
            return PurchaseOutcome.PURCHASED
        }
        val pkg = packages.firstOrNull { it.identifier == plan.packageId }
        if (!configureIfNeeded() || pkg == null) {
            errorMessage = UNAVAILABLE
            return null
        }
        val option = if (eligible) pkg.product.defaultOption else pkg.product.subscriptionOptions?.basePlan
        val params = if (option != null) {
            PurchaseParams.Builder(activity, option).presentedOfferingContext(pkg.presentedOfferingContext).build()
        } else {
            PurchaseParams.Builder(activity, pkg).build()
        }
        isLoading = true
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(params)
            apply(result.customerInfo)
            if (!entitlementActive) refreshCustomerInfo()
            if (entitlementActive) {
                PurchaseOutcome.PURCHASED
            } else {
                errorMessage = ConversionCopy.PURCHASE_PENDING_MESSAGE
                PurchaseOutcome.PENDING
            }
        } catch (error: PurchasesTransactionException) {
            when (purchaseOutcome(error.code, error.userCancelled)) {
                PurchaseOutcome.CANCELLED -> {
                    errorMessage = ConversionCopy.purchaseCancelledMessage(eligible)
                    PurchaseOutcome.CANCELLED
                }
                PurchaseOutcome.PENDING -> {
                    errorMessage = ConversionCopy.PURCHASE_PENDING_MESSAGE
                    PurchaseOutcome.PENDING
                }
                else -> {
                    errorMessage = ConversionCopy.purchaseFailedMessage(eligible)
                    null
                }
            }
        } finally {
            isLoading = false
        }
    }

    /** Leaves [errorMessage] set when nothing was restored, like iOS. */
    suspend fun restore() {
        errorMessage = null
        if (isPreview) {
            errorMessage = if (isPro) null else ConversionCopy.RESTORE_NONE
            return
        }
        if (!configureIfNeeded()) {
            errorMessage = UNAVAILABLE
            return
        }
        isLoading = true
        try {
            apply(Purchases.sharedInstance.awaitRestore())
            if (!isPro) errorMessage = ConversionCopy.RESTORE_NONE
        } catch (error: CancellationException) {
            throw error
        } catch (error: PurchasesException) {
            errorMessage = if (error.code == PurchasesErrorCode.PaymentPendingError) {
                ConversionCopy.PURCHASE_PENDING_MESSAGE
            } else {
                ConversionCopy.RESTORE_FAILED
            }
        } catch (_: Throwable) {
            errorMessage = ConversionCopy.RESTORE_FAILED
        } finally {
            isLoading = false
        }
    }

    fun clearError() {
        errorMessage = null
    }

    private fun apply(info: CustomerInfo) {
        val was = isPro
        customerInfoLoaded = true
        hasSubscriptionHistory = info.allExpirationDatesByProduct.isNotEmpty()
        introEligibilityResolved = packages.isNotEmpty()
        entitlementActive = info.entitlements.active.containsKey(ENTITLEMENT)
        cache.isPro = entitlementActive
        publish(was)
    }

    private fun publish(was: Boolean) {
        cache.isPro = isPro
        if (was != isPro) onProChanged()
    }

    private fun configureIfNeeded(): Boolean {
        if (isConfigured) return true
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // Never the production Play key in a debug build, and never a test key in release.
        if (BuildConfig.DEBUG && key.startsWith("goog_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        Purchases.configure(PurchasesConfiguration.Builder(context, key).build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        isConfigured = true
        return true
    }

    private fun kind(pkg: Package): PackageKind = when (pkg.packageType) {
        PackageType.LIFETIME -> PackageKind.LIFETIME
        PackageType.ANNUAL -> PackageKind.YEARLY
        PackageType.MONTHLY -> PackageKind.MONTHLY
        else -> PackageKind.fromIdentifiers(pkg.identifier, pkg.product.id)
    }

    private fun plan(pkg: Package): Plan {
        val price = pkg.product.price
        val free = pkg.product.subscriptionOptions?.firstOrNull { it.freePhase != null }?.freePhase
            ?: pkg.product.defaultOption?.freePhase
        return Plan(
            packageId = pkg.identifier,
            productId = pkg.product.id,
            kind = kind(pkg),
            priceMicros = price.amountMicros,
            priceFormatted = price.formatted,
            currencyCode = price.currencyCode,
            period = pkg.product.period?.toPlanPeriod(),
            trial = free?.billingPeriod?.toPlanPeriod(),
            title = pkg.product.title,
        )
    }

    companion object {
        /** iOS lists Lifetime, Yearly, Monthly. */
        fun displayOrder(kind: PackageKind): Int = when (kind) {
            PackageKind.LIFETIME -> 0
            PackageKind.YEARLY -> 1
            PackageKind.MONTHLY -> 2
            PackageKind.OTHER -> 3
        }

        const val ENTITLEMENT = "pro"
        const val MONTHLY = "com.jackwallner.sunset.monthly"
        const val YEARLY = "com.jackwallner.sunset.yearly"
        const val LIFETIME = "com.jackwallner.sunset.lifetime"
        private const val OFFERING_ID = "default"
        private const val LOCAL_OVERRIDE = "subscription.localProOverride"
        private const val UNAVAILABLE = "Couldn't load purchase options. Check your connection and try again."
    }
}

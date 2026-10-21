package com.jackwallner.sunset.model

/**
 * Purchase copy, ported from `ConversionCopy.swift` with Google Play's
 * wording. Trial versus paid is eligibility, not a different product, so
 * every line takes it as input and never promises a used trial.
 */
object ConversionCopy {
    /** The button carries no price so the billed amount above it stays the loudest pricing element. */
    const val CTA_LABEL = "Continue with Sun+"

    const val MANAGE = "Manage or cancel in Google Play › Payments & subscriptions."

    fun billedAmount(priceLabel: String): String = priceLabel.replace(" / ", " per ")

    fun billedNote(trialLabel: String?): String =
        if (!trialLabel.isNullOrEmpty()) "${trialLabel.lowercase()} included · Cancel anytime"
        else "Billed automatically · Cancel anytime"

    fun disclosure(trialLabel: String?, priceLabel: String): String {
        val renew = "Auto-renews unless cancelled before the end of the current period. $MANAGE"
        return if (!trialLabel.isNullOrEmpty()) "$priceLabel after the ${trialLabel.lowercase()}. $renew"
        else "$priceLabel. $renew"
    }

    /** The onboarding offer's one line of terms under the billed amount. */
    fun compactDisclosure(trialLabel: String?, priceLabel: String): String =
        if (!trialLabel.isNullOrEmpty()) {
            "${trialLabel.replaceFirstChar(Char::uppercaseChar)}, then $priceLabel. Auto-renews until canceled."
        } else {
            "Auto-renews until canceled. Cancel anytime in Google Play."
        }

    fun lifetimeDisclosure(priceLabel: String): String =
        "$priceLabel. One-time purchase with no subscription or automatic renewal."

    fun purchaseCancelledMessage(eligibleForTrial: Boolean): String =
        if (eligibleForTrial) "Trial wasn't started. Tap again to continue." else "Purchase wasn't completed. Tap again to continue."

    fun purchaseFailedMessage(eligibleForTrial: Boolean): String =
        if (eligibleForTrial) "Couldn't start your trial. Please try again." else "Couldn't complete the purchase. Please try again."

    const val PURCHASE_PENDING_MESSAGE =
        "Waiting on Google Play to confirm this purchase. Sun+ turns on by itself as soon as it goes through."

    const val RESTORE_NONE = "No active Sun+ purchase was found for this Google Play account."
    const val RESTORE_FAILED = "Restore failed. Please try again."
    const val PRICES_UNKNOWN = "Prices are shown before you buy and vary by region."
}

/** What Sun+ adds, in the order the paywall and onboarding list it. */
enum class PlusBenefit(val text: String) {
    WEEK("Every sunrise and sunset score for the week ahead"),
    STORMS("Alerts before thunderstorms roll in"),
    RAINBOWS("A heads-up when showers and low sun could make a rainbow"),
    FOG("Fog alerts for soft, moody light"),
    CUSTOM("Your own alert score and lead time"),
}

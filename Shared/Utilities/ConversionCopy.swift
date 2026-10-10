import Foundation

/// Purchase copy. StoreKit always sells the same package; trial versus paid is
/// eligibility, not a different product, so every line here takes it as input
/// and never promises a free week a used-trial account will not get.
enum ConversionCopy {
    /// The button carries no price so the billed amount above it stays the
    /// loudest pricing element (Apple 3.1.2).
    static let ctaLabel = "Continue with Sun+"

    static func billedAmount(priceLabel: String) -> String {
        priceLabel.replacingOccurrences(of: " / ", with: " per ")
    }

    static func billedNote(trialLabel: String?) -> String {
        if let trialLabel, !trialLabel.isEmpty {
            return "\(trialLabel.lowercased()) included · Cancel anytime"
        }
        return "Billed automatically · Cancel anytime"
    }

    static func disclosure(trialLabel: String?, priceLabel: String) -> String {
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions."
        if let trialLabel, !trialLabel.isEmpty {
            return "\(priceLabel) after the \(trialLabel.lowercased()). \(renew)"
        }
        return "\(priceLabel). \(renew)"
    }

    /// The same terms in three short lines, for the onboarding offer where
    /// the slot above the button has a fixed height.
    static func compactDisclosure(trialLabel: String?, priceLabel: String) -> String {
        let renew = "Auto-renews unless cancelled at least 24 hours before renewal. Cancel in Settings › Apple ID › Subscriptions."
        if let trialLabel, !trialLabel.isEmpty {
            return "\(trialLabel.prefix(1).uppercased() + trialLabel.dropFirst()), then \(priceLabel). \(renew)"
        }
        return "\(priceLabel). \(renew)"
    }

    static func purchaseCancelledMessage(eligibleForTrial: Bool) -> String {
        eligibleForTrial
            ? "Trial wasn't started. Tap again to continue."
            : "Purchase wasn't completed. Tap again to continue."
    }

    static func purchaseFailedMessage(eligibleForTrial: Bool) -> String {
        eligibleForTrial
            ? "Couldn't start your trial. Please try again."
            : "Couldn't complete the purchase. Please try again."
    }

    static let purchasePendingMessage =
        "Waiting on Apple to confirm this purchase. Sun+ turns on by itself as soon as it goes through."
}

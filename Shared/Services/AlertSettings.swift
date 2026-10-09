import Combine
import Foundation

/// What the user asked to be told about, backed by the App Group so the
/// widget can read the threshold too.
@MainActor
final class AlertSettings: ObservableObject {
    static let shared = AlertSettings()

    private let defaults = ForecastCache.defaults
    private enum Key {
        static let enabled = "sunset.alerts.enabled"
        static let threshold = "sunset.alerts.threshold"
        static let leadMinutes = "sunset.alerts.lead"
        static let onboarded = "sunset.onboarded"
        static let opens = "sunset.opens"
        static let reviewAsked = "sunset.reviewAsked"
    }

    static let thresholds = [50, 60, 70, 80, 90]
    static let leadOptions = [30, 45, 60, 90, 120]

    @Published var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: Key.enabled) }
    }

    /// Only evenings scoring at or above this fire an alert.
    @Published var threshold: Int {
        didSet { defaults.set(threshold, forKey: Key.threshold) }
    }

    /// Minutes before sunset to send the alert.
    @Published var leadMinutes: Int {
        didSet { defaults.set(leadMinutes, forKey: Key.leadMinutes) }
    }

    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Key.onboarded) }
    }

    private(set) var openCount: Int {
        get { defaults.integer(forKey: Key.opens) }
        set { defaults.set(newValue, forKey: Key.opens) }
    }

    var reviewAsked: Bool {
        get { defaults.bool(forKey: Key.reviewAsked) }
        set { defaults.set(newValue, forKey: Key.reviewAsked) }
    }

    private init() {
        alertsEnabled = defaults.bool(forKey: Key.enabled)
        let storedThreshold = defaults.integer(forKey: Key.threshold)
        threshold = storedThreshold == 0 ? 70 : storedThreshold
        let storedLead = defaults.integer(forKey: Key.leadMinutes)
        leadMinutes = storedLead == 0 ? 45 : storedLead
        hasOnboarded = defaults.bool(forKey: Key.onboarded)
    }

    func recordOpen() {
        openCount += 1
    }

    /// The third open while looking at a sunset worth seeing is the moment to
    /// ask, once, straight through `requestReview()`.
    func shouldRequestReview(score: Int) -> Bool {
        guard !reviewAsked, openCount >= 3, score >= 60 else { return false }
        reviewAsked = true
        return true
    }
}

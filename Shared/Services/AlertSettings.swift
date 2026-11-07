import Combine
import Foundation
import UserNotifications
import WidgetKit

/// What the user watches and wants to be told about, backed by the App Group
/// so the widget reads the same choices.
@MainActor
final class AlertSettings: ObservableObject {
    static let shared = AlertSettings()

    private let defaults = ForecastCache.defaults
    private enum Key {
        static let enabled = "sunset.alerts.enabled"
        static let threshold = "sunset.alerts.threshold"
        static let leadMinutes = "sunset.alerts.lead"
        static let skyEvents = "sunset.alerts.skyEvents"
        static let onboarded = "sunset.onboarded"
        static let opens = "sunset.opens"
        static let firstOpen = "sunset.firstOpen"
        static let reviewAsked = "sunset.reviewAsked"
    }

    nonisolated static let thresholds = [50, 60, 70, 80, 90]
    nonisolated static let leadOptions = [30, 45, 60, 90, 120]
    /// Free alerts use these; Sun+ can change them.
    nonisolated static let defaultThreshold = 70
    nonisolated static let defaultLead = 45

    /// Sunrise, sunset, or both. Never empty.
    @Published var watched: Set<SunEvent> {
        didSet {
            if watched.isEmpty { watched = oldValue; return }
            guard watched != oldValue else { return }
            ForecastCache.watchedEvents = watched
            WidgetCenter.shared.reloadAllTimelines()
            Task { await ForecastStore.shared.rescheduleAlerts() }
        }
    }

    /// Free: an alert before every watched sunrise or sunset that clears the
    /// threshold.
    @Published var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: Key.enabled) }
    }

    /// Only shows scoring at or above this fire an alert. Sun+ to change.
    @Published var threshold: Int {
        didSet { defaults.set(threshold, forKey: Key.threshold) }
    }

    /// Minutes before sunset to send the alert. Sun+ to change.
    @Published var leadMinutes: Int {
        didSet { defaults.set(leadMinutes, forKey: Key.leadMinutes) }
    }

    /// Sun+: which sky events alert. All on by default once Sun+ is.
    @Published var skyEventKinds: Set<SkyEvent.Kind> {
        didSet { defaults.set(skyEventKinds.map(\.rawValue).sorted(), forKey: Key.skyEvents) }
    }

    /// iOS blocks Sunset's notifications. Never turns `alertsEnabled` off:
    /// the user still wants alerts, iOS just won't deliver them yet.
    @Published private(set) var notificationsDenied = false
    private var notificationStatus: UNAuthorizationStatus?

    /// Alerts are on here but iOS will not show them.
    var alertsBlocked: Bool { alertsEnabled && notificationsDenied }

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
        watched = ForecastCache.watchedEvents
        alertsEnabled = defaults.bool(forKey: Key.enabled)
        let storedThreshold = defaults.integer(forKey: Key.threshold)
        threshold = storedThreshold == 0 ? Self.defaultThreshold : storedThreshold
        let storedLead = defaults.integer(forKey: Key.leadMinutes)
        leadMinutes = storedLead == 0 ? Self.defaultLead : storedLead
        if let raw = defaults.stringArray(forKey: Key.skyEvents) {
            skyEventKinds = Set(raw.compactMap(SkyEvent.Kind.init(rawValue:)))
        } else {
            skyEventKinds = Set(SkyEvent.Kind.allCases)
        }
        hasOnboarded = defaults.bool(forKey: Key.onboarded)
    }

    /// Reads the iOS permission and rebuilds alerts when it changed since the
    /// last read, so a grant in iOS Settings schedules tonight's alert at once.
    /// `status` stands in for the system read in tests.
    @discardableResult
    func syncNotificationPermission(_ status: UNAuthorizationStatus? = nil) async -> Bool {
        let current: UNAuthorizationStatus
        if let status { current = status } else { current = await NotificationService.authorizationStatus() }
        let previous = notificationStatus
        notificationStatus = current
        notificationsDenied = current == .denied
        guard let previous, previous != current else { return false }
        await ForecastStore.shared.rescheduleAlerts()
        return true
    }

    func toggle(_ event: SunEvent) {
        if watched.contains(event) { watched.remove(event) } else { watched.insert(event) }
    }

    /// The values alerts actually use: free accounts always get the defaults,
    /// whatever was picked during a lapsed subscription.
    func effectiveThreshold(isPro: Bool) -> Int { isPro ? threshold : Self.defaultThreshold }
    func effectiveLead(isPro: Bool) -> Int { isPro ? leadMinutes : Self.defaultLead }

    func recordOpen(now: Date = .now) {
        if defaults.object(forKey: Key.firstOpen) == nil { defaults.set(now, forKey: Key.firstOpen) }
        openCount += 1
    }

    /// Asked once, on the way back from a show worth seeing that the user
    /// opened themselves, and only after they have lived with the app for a
    /// couple of days. Never on launch.
    func shouldRequestReview(score: Int, now: Date = .now) -> Bool {
        let first = defaults.object(forKey: Key.firstOpen) as? Date
        let days = first.map { Int(now.timeIntervalSince($0) / 86_400) } ?? 0
        guard Self.reviewEligible(
            asked: reviewAsked, onboarded: hasOnboarded,
            opens: openCount, daysSinceFirstOpen: days, score: score
        ) else { return false }
        reviewAsked = true
        return true
    }

    nonisolated static let reviewMinimumOpens = 3
    nonisolated static let reviewMinimumDays = 2
    nonisolated static let reviewMinimumScore = 60

    nonisolated static func reviewEligible(
        asked: Bool, onboarded: Bool, opens: Int, daysSinceFirstOpen: Int, score: Int
    ) -> Bool {
        !asked && onboarded
            && opens >= reviewMinimumOpens
            && daysSinceFirstOpen >= reviewMinimumDays
            && score >= reviewMinimumScore
    }
}

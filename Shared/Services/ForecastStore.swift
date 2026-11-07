import Combine
import Foundation
import os
import WidgetKit

/// The forecast the app shows. Loads from the App Group cache first so the
/// screen is never blank, refreshes from Open-Meteo when the cache is stale,
/// and rewrites alerts and widgets after every successful fetch.
@MainActor
final class ForecastStore: ObservableObject {
    static let shared = ForecastStore()

    @Published private(set) var forecast: SunsetForecast?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let logger = Logger(subsystem: "com.jackwallner.sunset", category: "Forecast")
    private var inFlight: Task<Void, Never>?
    private var inFlightLocation: ForecastCache.Location?
    /// Counts loads, so one that a newer load superseded leaves no trace.
    private var loadGeneration = 0
    /// When the forecast the pending alerts were built from was fetched.
    private(set) var alertsPlannedFrom: Date?

    init(forecast: SunsetForecast? = ForecastCache.forecast) {
        self.forecast = forecast
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DemoForecast") {
            self.forecast = DemoForecast.make()
        }
        #endif
    }

    /// The next watched sunrise or sunset that is not over yet.
    var nextShow: SunShow? { forecast?.upcomingShows(AlertSettings.shared.watched).first }

    /// Refreshes when the cache is older than three hours or the location
    /// moved. `force` skips both checks for pull-to-refresh.
    func refresh(location: ForecastCache.Location, force: Bool = false) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DemoForecast") { return }
        #endif
        if !force, let forecast, !forecast.isStale(), forecast.isSameLocation(as: location) {
            apply(placeName: location.placeName)
            // The widget refreshes the shared snapshot without touching
            // alerts, so a cold launch can find a fresh forecast no alert was
            // built from.
            if alertsPlannedFrom != forecast.fetched { Task { await rescheduleAlerts() } }
            return
        }
        // A fix for a new place replaces the load still running for the old
        // one; the same place again waits for it.
        if inFlight != nil, !force, let inFlightLocation, inFlightLocation.isSamePlace(as: location) { return }
        inFlightLocation = location
        inFlight = Task { await load(location: location) }
    }

    func load(location: ForecastCache.Location) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DemoForecast") { return }
        #endif
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false; inFlight = nil; inFlightLocation = nil }
        }
        do {
            var fresh = try await ForecastService.fetch(latitude: location.latitude, longitude: location.longitude)
            guard generation == loadGeneration else { return }
            fresh.placeName = location.placeName
            forecast = fresh
            errorMessage = nil
            ForecastCache.forecast = fresh
            WidgetCenter.shared.reloadAllTimelines()
            await rescheduleAlerts()
        } catch {
            guard generation == loadGeneration else { return }
            logger.error("Forecast fetch failed: \(String(describing: error), privacy: .public)")
            errorMessage = forecast == nil
                ? "Couldn't load the forecast. Check your connection and try again."
                : "Showing the last forecast. Couldn't reach the weather service."
        }
    }

    func rescheduleAlerts() async {
        alertsPlannedFrom = forecast?.fetched
        await NotificationService.reschedule(
            forecast: forecast, settings: AlertSettings.shared, isPro: StoreService.shared.isPro
        )
    }

    private func apply(placeName: String?) {
        guard let placeName, forecast?.placeName != placeName else { return }
        forecast?.placeName = placeName
        ForecastCache.forecast = forecast
    }
}

extension SunsetForecast {
    func isSameLocation(as location: ForecastCache.Location) -> Bool {
        abs(latitude - location.latitude) < 0.05 && abs(longitude - location.longitude) < 0.05
    }
}

extension ForecastCache.Location {
    func isSamePlace(as other: ForecastCache.Location) -> Bool {
        abs(latitude - other.latitude) < 0.05 && abs(longitude - other.longitude) < 0.05
    }
}

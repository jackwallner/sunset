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

    private init() {
        forecast = ForecastCache.forecast
    }

    var tonight: SunsetDay? { forecast?.upcoming() }

    /// Refreshes when the cache is older than three hours or the location
    /// moved. `force` skips both checks for pull-to-refresh.
    func refresh(location: ForecastCache.Location, force: Bool = false) {
        if !force, let forecast, !forecast.isStale(), forecast.isSameLocation(as: location) {
            apply(placeName: location.placeName)
            return
        }
        if let inFlight, !force { _ = inFlight; return }
        inFlight = Task { await load(location: location) }
    }

    func load(location: ForecastCache.Location) async {
        isLoading = true
        defer { isLoading = false; inFlight = nil }
        do {
            var fresh = try await ForecastService.fetch(latitude: location.latitude, longitude: location.longitude)
            fresh.placeName = location.placeName
            forecast = fresh
            errorMessage = nil
            ForecastCache.forecast = fresh
            WidgetCenter.shared.reloadAllTimelines()
            await NotificationService.reschedule(
                forecast: fresh, settings: AlertSettings.shared, isPro: StoreService.shared.isPro
            )
        } catch {
            logger.error("Forecast fetch failed: \(String(describing: error), privacy: .public)")
            errorMessage = forecast == nil
                ? "Couldn't load the forecast. Check your connection and try again."
                : "Showing the last forecast. Couldn't reach the weather service."
        }
    }

    func rescheduleAlerts() async {
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

import CoreLocation
import Foundation
import os

/// One coarse fix, reverse geocoded to a town name, cached for the widget.
/// No tracking and no background updates: the forecast needs a region, not a
/// street.
@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    enum Status: Equatable {
        case unknown
        case waiting
        case denied
        case located(ForecastCache.Location)
    }

    @Published private(set) var status: Status = .unknown

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let logger = Logger(subsystem: "com.jackwallner.sunset", category: "Location")
    private var onFix: ((ForecastCache.Location) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        if let cached = ForecastCache.location {
            status = .located(cached)
        }
    }

    var location: ForecastCache.Location? {
        if case .located(let fix) = status { return fix }
        return ForecastCache.location
    }

    var isDenied: Bool {
        switch manager.authorizationStatus {
        case .denied, .restricted: true
        default: false
        }
    }

    var isAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
    }

    /// Fires `onFix` when a new fix lands. Calling with no closure just refreshes.
    func request(onFix: ((ForecastCache.Location) -> Void)? = nil) {
        if let onFix { self.onFix = onFix }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .waiting
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        default:
            refresh()
        }
    }

    func refresh() {
        guard isAuthorized else { return }
        if case .unknown = status { status = .waiting }
        manager.requestLocation()
    }

    #if DEBUG
    /// Simulator runs have no GPS. A fixed location keeps the forecast real.
    func useDemoLocation() {
        let demo = ForecastCache.Location(latitude: 45.63, longitude: -122.52, placeName: "Vancouver, WA")
        ForecastCache.location = demo
        status = .located(demo)
        onFix?(demo)
    }
    #endif

    private func store(latitude: Double, longitude: Double) async {
        var fix = ForecastCache.Location(latitude: latitude, longitude: longitude, placeName: ForecastCache.location?.placeName)
        if let place = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)).first {
            fix.placeName = [place.locality ?? place.subAdministrativeArea, place.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        ForecastCache.location = fix
        status = .located(fix)
        onFix?(fix)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        Task { @MainActor in
            await self.store(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = String(describing: error)
        Task { @MainActor in
            self.logger.error("Location failed: \(message, privacy: .public)")
            if ForecastCache.location == nil { self.status = .unknown }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        Task { @MainActor in
            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse: self.refresh()
            case .denied, .restricted: self.status = .denied
            default: break
            }
        }
    }
}

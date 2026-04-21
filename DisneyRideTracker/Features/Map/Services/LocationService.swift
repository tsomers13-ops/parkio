// LocationService.swift — Core Location wrapper for live GPS tracking.
//
// Responsibilities:
//   • Request and monitor CLLocationManager authorization.
//   • Publish the user's current CLLocation and heading.
//   • Surface authorizationStatus so UI can adapt (button states, empty states).
//
// Usage:
//   Inject once at app root via .environment(LocationService()).
//   Views and view models read userLocation / authorizationStatus reactively
//   because LocationService is @Observable.
//
// Threading:
//   @MainActor — all published state mutations happen on the main queue.
//   CLLocationManagerDelegate callbacks dispatch to main explicitly.

import CoreLocation
import Observation

// MARK: - LocationService

@Observable
@MainActor
final class LocationService: NSObject {

    // ── Published state ───────────────────────────────────────────────────────

    /// Most recent GPS fix, or nil if location is unavailable or unauthorized.
    private(set) var userLocation: CLLocation? = nil

    /// Most recent compass heading, or nil if heading is unavailable.
    private(set) var heading: CLHeading? = nil

    /// Current Core Location authorization status.
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // ── Private ───────────────────────────────────────────────────────────────

    private let manager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = 5       // publish update after 5 m of movement
        // Read the current status synchronously so UI is correct before the first
        // delegate callback fires.
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    /// Request "when in use" authorization.
    /// Safe to call multiple times — a no-op if already authorized or denied.
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    /// Start streaming location updates (and heading if supported).
    /// Call after authorization is confirmed.
    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    /// Stop all active updates. Call when the map view disappears.
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // MARK: - Convenience

    /// True when the app has sufficient authorization to receive location events.
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse
            || authorizationStatus == .authorizedAlways
    }

    /// True when authorization is permanently denied — the user must visit Settings.
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.userLocation = latest
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        Task { @MainActor in
            self.heading = newHeading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            // Auto-start streaming once the user grants permission.
            if self.isAuthorized {
                self.startUpdating()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Errors like kCLErrorLocationUnknown are transient — silently ignore them.
        // kCLErrorDenied is already covered by locationManagerDidChangeAuthorization.
    }
}

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

    /// Views currently asking for a stream. Hardware stays on until the last
    /// one releases, so a handoff from the EPCOT canvas to a MapKit park
    /// (or the reverse) does not stop updates.
    private(set) var locationClientCount = 0

    /// True while this service has asked Core Location to stream.
    private(set) var isStreamingLocation = false

    // ── Private ───────────────────────────────────────────────────────────────

    private let manager = CLLocationManager()
    private var locationStopPending = false

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

    /// Take one hold on the location stream. The first hold starts Core
    /// Location. A matching `releaseLocationUpdates()` drops the hold.
    func acquireLocationUpdates() {
        locationClientCount += 1
        locationStopPending = false
        beginStreamingLocation()
    }

    /// Drop one hold. The stream stops only after the last hold is gone,
    /// and only on the next turn, so a view that acquires in the same
    /// handoff keeps the stream running.
    func releaseLocationUpdates() {
        guard locationClientCount > 0 else { return }
        locationClientCount -= 1
        guard locationClientCount == 0 else { return }
        locationStopPending = true
        Task { @MainActor in
            guard self.locationClientCount == 0, self.locationStopPending else { return }
            self.locationStopPending = false
            self.endStreamingLocation()
        }
    }

    /// Start streaming without taking a hold. Used by the authorization
    /// callback and the location button, which are not paired with a release.
    func startUpdating() {
        beginStreamingLocation()
    }

    /// Stop streaming only when no view holds it. A hold from the other map
    /// surface wins over this call.
    func stopUpdating() {
        guard locationClientCount == 0 else { return }
        locationStopPending = false
        endStreamingLocation()
    }

    private func beginStreamingLocation() {
        guard !isStreamingLocation else { return }
        isStreamingLocation = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    private func endStreamingLocation() {
        guard isStreamingLocation else { return }
        isStreamingLocation = false
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

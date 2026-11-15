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

    /// Holds currently asking for a stream, each with the accuracy it wants.
    /// Hardware stays on until the last one releases, so a handoff from the
    /// EPCOT canvas to a MapKit park (or the reverse) does not stop updates.
    private var locationHolds: [UUID: CLLocationAccuracy] = [:]

    var locationClientCount: Int { locationHolds.count }

    /// The accuracy actually requested. Overlapping holds use the most
    /// precise one. `kCLLocationAccuracyBest` is the smallest value.
    private(set) var desiredLocationAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest

    /// True only after Core Location has actually been started.
    /// A hold recorded before permission does not set this.
    private(set) var isStreamingLocation = false

    // ── Private ───────────────────────────────────────────────────────────────

    private let manager = CLLocationManager()
    private var locationStopPending = false

    #if DEBUG
    /// Tests set this to false so a late Core Location callback cannot
    /// overwrite a status the test just applied.
    internal var acceptsManagerAuthorizationUpdates = true
    #endif

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

    /// Take one hold on the location stream. The hold is recorded even when
    /// location is not authorized. Hardware starts only once permission
    /// exists. Release the returned id to drop this hold.
    /// Map holds use best accuracy. The foreground hold uses hundred meters.
    @discardableResult
    func acquireLocationUpdates(
        accuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    ) -> UUID {
        let id = UUID()
        locationHolds[id] = accuracy
        locationStopPending = false
        applyDesiredAccuracy()
        guard isAuthorized else { return id }
        beginStreamingLocation()
        return id
    }

    /// Drop one hold. The stream stops only after the last hold is gone,
    /// and only on the next turn, so a view that acquires in the same
    /// handoff keeps the stream running. Accuracy falls back to whatever
    /// the remaining holds requested.
    func releaseLocationUpdates(_ hold: UUID) {
        guard locationHolds.removeValue(forKey: hold) != nil else { return }
        applyDesiredAccuracy()
        guard locationHolds.isEmpty else { return }
        locationStopPending = true
        Task { @MainActor in
            guard self.locationHolds.isEmpty, self.locationStopPending else { return }
            self.locationStopPending = false
            self.endStreamingLocation()
        }
    }

    private func applyDesiredAccuracy() {
        let accuracy = locationHolds.values.min() ?? kCLLocationAccuracyHundredMeters
        desiredLocationAccuracy = accuracy
        manager.desiredAccuracy = accuracy
    }

    /// Start streaming without taking a hold. This is the location-button
    /// path. It does nothing until authorization is granted, and it does
    /// not set `isStreamingLocation` unless the hardware start runs.
    func startUpdating() {
        guard isAuthorized else { return }
        beginStreamingLocation()
    }

    private func beginStreamingLocation() {
        guard isAuthorized, !isStreamingLocation else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        isStreamingLocation = true
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
            #if DEBUG
            guard self.acceptsManagerAuthorizationUpdates else { return }
            #endif
            self.noteAuthorizationStatus(status)
        }
    }

    /// Applies an authorization result. A grant starts the hardware only
    /// when at least one view holds the stream. A denial stops it and
    /// leaves the hold in place. Tests call this with the same statuses
    /// Core Location reports.
    func noteAuthorizationStatus(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if isAuthorized {
            if !locationHolds.isEmpty {
                beginStreamingLocation()
            }
        } else {
            endStreamingLocation()
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

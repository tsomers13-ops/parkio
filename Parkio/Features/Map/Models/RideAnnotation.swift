// RideAnnotation.swift — Value type bridging MapRideAnnotation → MapKit Annotation.
//
// RideAnnotation is the model consumed by RealMapScreen's Map { ForEach } body.
// It carries:
//   • The real GPS coordinate from MapCoordinateService
//   • The display name for the Annotation label
//   • The ride category (for icon selection in the marker view)
//   • A priority (1–3) sourced from RideCoordinateTable that controls zoom-gated
//     visibility on the real map
//
// ── Zoom-gate thresholds (revised) ───────────────────────────────────────────
//
//   priority 1 — always visible  (hero rides, guaranteed on screen at any zoom)
//   priority 2 — visible when latDelta < 0.025  (~2.8 km span)
//               Covers ALL default park views (MK: 0.013, EPCOT: 0.016, etc.)
//               so named rides like Peter Pan, Pirates, and Soarin' appear on
//               the default map without zooming.
//   priority 3 — visible when latDelta < 0.010  (~1.1 km, "land zoom" level)
//               Secondary kiddie / transport rides appear when the user has
//               zoomed in to roughly one themed area.
//
// The old thresholds (P2: 0.012, P3: 0.005) were calibrated for a zoomed-in
// state, not the default park overview. At the default MK span of 0.013, ALL
// P2 rides were hidden — only 5 P1 hero rides ever appeared. The new thresholds
// ensure all named rides show at normal browsing zoom.
//
// ── Identity ─────────────────────────────────────────────────────────────────
//
//   id matches MapRideAnnotation.id so visibleMarkers lookups in MapViewModel
//   continue to work without changes.

import CoreLocation
import MapKit

// MARK: - RideAnnotation

struct RideAnnotation: Identifiable {

    // ── Core fields ───────────────────────────────────────────────────────────

    /// Stable identifier — matches MapRideAnnotation.id for cross-system lookup.
    let id: String

    /// Real-world GPS coordinate from MapCoordinateService.
    let coordinate: CLLocationCoordinate2D

    /// Display name used in Annotation label and accessibility strings.
    let name: String

    /// The land / themed area the ride belongs to (e.g. "Tomorrowland").
    let land: String

    /// Park backend id (e.g. "magic-kingdom").
    let parkId: String

    /// Ride type hint — used to select the correct SF Symbol in the marker view.
    let category: RideCategory

    /// Display priority (1–3). Controls zoom-gated visibility on the MapKit layer.
    ///   1 = always visible
    ///   2 = visible at default park zoom and closer (latDelta < 0.025)
    ///   3 = visible only when zoomed to ~land level (latDelta < 0.010)
    let priority: Int

    // MARK: - Factory

    /// Build a RideAnnotation from the coordinate-service annotation.
    /// Priority is resolved from RideCoordinateTable — defaults to 2 if unlisted.
    init(from source: MapRideAnnotation) {
        self.id         = source.id
        self.coordinate = source.coordinate
        self.name       = source.rideName
        self.land       = source.land
        self.parkId     = source.parkId
        self.category   = source.category
        self.priority   = RideCoordinateTable.priority(
            for: source.rideName,
            parkId: source.parkId
        )
    }
}

// MARK: - Visibility helper

extension RideAnnotation {

    /// Returns true when this annotation should be shown at the given map span.
    ///
    /// Threshold guide (approx. screen coverage at 390 pt viewport width):
    ///   0.025° ≈ 2.8 km   — fits an entire park with breathing room
    ///   0.013° ≈ 1.5 km   — Magic Kingdom default camera
    ///   0.016° ≈ 1.8 km   — EPCOT default camera
    ///   0.010° ≈ 1.1 km   — roughly "one themed land" view
    ///   0.005° ≈ 550 m    — very tight zoom, single attraction area
    func isVisible(at latitudeDelta: CLLocationDegrees) -> Bool {
        switch priority {
        case 1:  return true
        default: return latitudeDelta < 0.025  // all rides visible at park zoom and closer
        // Previously P3 used 0.010, hiding ~7 MK rides (Dumbo, Astro Orbiter, Speedway,
        // Mad Tea Party, Magic Carpets, Liberty Belle, Railroad) at every default view.
        // Declutter already handles density — the zoom gate is redundant and harmful.
        }
    }
}

// MARK: - Equatable / Hashable for diffing

extension RideAnnotation: Equatable, Hashable {
    static func == (lhs: RideAnnotation, rhs: RideAnnotation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Distance formatting

extension RideAnnotation {

    /// Human-readable distance string from the user's current location.
    /// Returns nil if distance is nil (location unavailable).
    static func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded()))m"
        } else {
            let km = meters / 1000
            return String(format: "%.1f km", km)
        }
    }
}

// MARK: - CLLocationCoordinate2D validity

extension CLLocationCoordinate2D {

    /// True when the coordinate is within legal geographic bounds and is not the
    /// default zero value that indicates a missing / unset position.
    ///
    /// Rides with invalid coordinates are stripped from the pipeline before any
    /// zoom-gate or filter logic runs (Stage 2 in MapViewModel.buildVisibleAnnotations).
    var isValid: Bool {
        // Guard against the default CLLocationCoordinate2D() == (0, 0)
        guard latitude != 0 || longitude != 0 else { return false }
        // Guard against out-of-range values (parse errors, typos in JSON)
        return latitude  >= -90  && latitude  <= 90
            && longitude >= -180 && longitude <= 180
    }
}

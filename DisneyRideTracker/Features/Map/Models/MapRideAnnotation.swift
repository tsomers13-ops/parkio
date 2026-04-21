// MapRideAnnotation.swift — Static ride position + enriched marker model.
//
// MapRideAnnotation: loaded from MapCoordinates.json, holds the ride's
// GPS coordinate and basic static data.
//
// EnrichedMarker: the view-ready type that merges static annotation data
// with live wait state and user state (ridden today, in plan).

import SwiftUI
import MapKit

// MARK: - MapRideAnnotation

/// A single ride's position on the park map.
struct MapRideAnnotation: Identifiable, Decodable {
    let id: String          // matches Ride.id stableID ("Magic Kingdom|Land|Name")
    let rideName: String    // display name — also used to cross-reference WaitTimeCache
    let land: String
    let parkId: String      // backendId, e.g. "magic-kingdom"

    /// GPS latitude.
    let latitude: Double
    /// GPS longitude.
    let longitude: Double

    /// Category hint for icon selection.
    let category: RideCategory

    /// Convenience CLLocationCoordinate2D for MapKit.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, rideName, land, parkId, category
        case latitude  = "lat"
        case longitude = "lon"
    }
}

// MARK: - RideCategory

enum RideCategory: String, Decodable, CaseIterable {
    case thrill        = "thrill"
    case family        = "family"
    case kiddie        = "kiddie"
    case darkRide      = "dark_ride"
    case waterRide     = "water_ride"
    case show          = "show"
    case transport     = "transport"
    case unknown       = "unknown"

    var systemImage: String {
        switch self {
        case .thrill:     return "bolt.fill"
        case .family:     return "star.fill"
        case .kiddie:     return "figure.and.child.holdinghands"
        case .darkRide:   return "moon.fill"
        case .waterRide:  return "drop.fill"
        case .show:       return "theatermasks.fill"
        case .transport:  return "tram.fill"
        case .unknown:    return "mappin.fill"
        }
    }
}

// MARK: - EnrichedMarker

/// View-ready merge of a MapRideAnnotation + live state + user state.
/// Computed by MapViewModel and passed directly to marker views.
struct EnrichedMarker: Identifiable {
    // Static
    let annotation: MapRideAnnotation
    var id: String { annotation.id }

    // Live wait state (nil until first fetch completes)
    let liveState: LiveRideState?

    // User state
    let isRidden: Bool
    let isLoggedToday: Bool
    let isPlanned: Bool

    // MARK: - Computed display properties

    /// Primary badge text shown on the map pin.
    var badgeText: String? {
        guard let live = liveState, live.status.isRideable else { return nil }
        guard let mins = live.waitMinutes else { return nil }
        return mins == 0 ? "✓" : "\(mins)"
    }

    /// Color applied to the marker pill/badge.
    var markerColor: Color {
        if let live = liveState {
            if !live.status.isRideable { return AppColor.textTertiary }
            if let mins = live.waitMinutes { return AppColor.waitColor(minutes: mins) }
        }
        return AppColor.textSecondary
    }

    /// Filled vs outline style — filled = not yet ridden.
    var isFilled: Bool { !isRidden }

    /// Accessibility label for the marker — spoken by VoiceOver when navigating the map.
    /// Covers: name, wait/status, trend direction, ridden state, and plan membership.
    var accessibilityLabel: String {
        var parts = [annotation.rideName]
        if let live = liveState {
            if live.status.isRideable {
                parts.append("\(live.waitDisplay) wait")
                if live.trend == .rising  { parts.append("wait time rising") }
                if live.trend == .falling { parts.append("wait time falling") }
            } else {
                // e.g. "Temporarily Closed", "Closed"
                parts.append(live.status.displayLabel)
            }
        }
        if isRidden  { parts.append("already ridden") }
        if isPlanned { parts.append("in your plan") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - EnrichedMarkerWithSelection

/// Wraps an EnrichedMarker with a selection flag so MapViewModel can tag
/// one marker as selected without mutating the underlying value type.
struct EnrichedMarkerWithSelection: Identifiable {
    let base: EnrichedMarker
    let selected: Bool
    var id: String { base.id }
}

// MARK: - MapRideAnnotation stub factory

extension MapRideAnnotation {
    static func stub(
        id: String,
        name: String,
        lat: Double = 28.4177,
        lon: Double = -81.5812,
        parkId: String = "magic-kingdom",
        land: String = "Test Land",
        category: RideCategory = .family
    ) -> MapRideAnnotation {
        let json = """
        {
            "id": "\(id)",
            "rideName": "\(name)",
            "land": "\(land)",
            "parkId": "\(parkId)",
            "lat": \(lat),
            "lon": \(lon),
            "category": "\(category.rawValue)"
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(MapRideAnnotation.self, from: json)
    }
}

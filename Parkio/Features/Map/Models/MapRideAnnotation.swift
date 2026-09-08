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

    /// ThemeParks.wiki attraction entity UUID, e.g. "fe75b6ef-07b3-4d4f-b3d0-3498e1b88a23".
    /// `nil` until populated via GET /entity/{park.themeparksEntityId}/live.
    /// Used for direct ID-first wait-time lookup and coordinate verification.
    let entityId: String?

    /// Convenience CLLocationCoordinate2D for MapKit.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, rideName, land, parkId, category, entityId
        case latitude  = "lat"
        case longitude = "lon"
    }
}

// MARK: - RideCategory

enum RideCategory: String, CaseIterable {
    case thrill        = "thrill"
    case family        = "family"
    case kiddie        = "kiddie"
    case darkRide      = "dark_ride"
    case waterRide     = "water_ride"
    case show          = "show"
    case characterMeet = "character_meet"
    case transport     = "transport"
    /// Quick service, table service, snack, or lounge map pin.
    /// Added when dining venues first got map coordinates — see MapCoordinates.json.
    case dining        = "dining"
    /// Shopping map pin — added for Priority 5 (Shopping). Backed by `MasterShop`,
    /// not `MasterAttraction`/`AttractionType` — see ShopMasterData.swift.
    case shopping      = "shopping"
    /// Guest Service map pins — added for Priority 6 (Guest Services). Backed
    /// by `GuestServicePOI`, not `MasterAttraction`/`MasterShop` — see
    /// GuestServicePOI.swift. Raw values match `GuestServiceCategory.
    /// rideCategoryRawValue` exactly. Rendered via a separate pipeline from
    /// rides/dining/shopping (see MapViewModel's guestServiceAnnotations) —
    /// these cases exist purely for JSON category decoding + icon selection,
    /// not for the ride declutter/filter pipeline.
    case restroom             = "restroom"
    case firstAid              = "first_aid"
    case guestRelations        = "guest_relations"
    case babyCare               = "baby_care"
    case lockers                = "lockers"
    case atm                    = "atm"
    case accessibilityService  = "accessibility_service"
    case unknown       = "unknown"

    var systemImage: String {
        switch self {
        case .thrill:         return "bolt.fill"
        case .family:         return "star.fill"
        case .kiddie:         return "figure.and.child.holdinghands"
        case .darkRide:       return "moon.fill"
        case .waterRide:      return "drop.fill"
        case .show:           return "theatermasks.fill"
        case .characterMeet:  return "person.fill.checkmark"
        case .transport:      return "tram.fill"
        case .dining:         return "fork.knife"
        case .shopping:       return "bag.fill"
        case .restroom:             return "toilet.fill"
        case .firstAid:              return "cross.case.fill"
        case .guestRelations:        return "info.circle.fill"
        case .babyCare:               return "stroller.fill"
        case .lockers:                return "lock.fill"
        case .atm:                    return "banknote.fill"
        case .accessibilityService:  return "figure.roll"
        case .unknown:        return "mappin.fill"
        }
    }
}

// MARK: - RideCategory Decodable (hardened)
//
// A plain synthesized Decodable would THROW on any raw value it doesn't
// recognize. MapCoordinateService decodes each park's annotation array in one
// shot (see MapCoordinatesFile) — a single unrecognized `category` string
// (a future typo, a case added to the JSON before the app ships it, etc.)
// would fail that whole park's array and silently drop every ride, dining,
// and shopping pin for that park. Introducing `.shopping` here made this
// worth closing now: any unrecognized value degrades to `.unknown` instead
// of aborting the decode. Priority 6's seven new Guest Service cases are
// automatically covered by this same hardening — no further decode work
// was needed to add them safely.
extension RideCategory: Decodable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RideCategory(rawValue: raw) ?? .unknown
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
        category: RideCategory = .family,
        entityId: String? = nil
    ) -> MapRideAnnotation {
        let entityIdJSON = entityId.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
            "id": "\(id)",
            "rideName": "\(name)",
            "land": "\(land)",
            "parkId": "\(parkId)",
            "lat": \(lat),
            "lon": \(lon),
            "category": "\(category.rawValue)",
            "entityId": \(entityIdJSON)
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(MapRideAnnotation.self, from: json)
    }
}

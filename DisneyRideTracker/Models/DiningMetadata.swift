// DiningMetadata.swift — Supporting types for the Parkio dining catalog.
//
// Architecture
// ────────────
// PriceTier      — rough per-person spend bracket ($–$$$$).
// DietaryFlag    — accommodation / dietary preference tags shown as filter chips.
// DiningMetadata — static editorial data attached to a dining MasterAttraction.
//
// All values here are Parkio editorial — not sourced from live APIs and not
// user-generated. For future user-generated ratings, see DiningReview.swift.
//
// No SwiftData involvement. DiningMetadata is a plain struct; the static catalog
// is owned by RideMasterData+Dining.swift. Dining venues are seeded into the
// existing Ride SwiftData model via RideSeeder (no schema migration required).

import Foundation

// MARK: - PriceTier

/// Approximate per-person spend, before tax and tip.
enum PriceTier: Int, Comparable, CaseIterable, Sendable {
    case budget    = 1  // $    — under $15
    case moderate  = 2  // $$   — $15–$25
    case upscale   = 3  // $$$  — $25–$60
    case signature = 4  // $$$$ — $60+

    static func < (lhs: PriceTier, rhs: PriceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// "$", "$$", "$$$", "$$$$"
    var displayString: String { String(repeating: "$", count: rawValue) }

    var label: String {
        switch self {
        case .budget:    return "Budget"
        case .moderate:  return "Moderate"
        case .upscale:   return "Upscale"
        case .signature: return "Signature Dining"
        }
    }
}

// MARK: - DietaryFlag

/// Broad dietary accommodation tags used as filter chips and accessibility icons.
enum DietaryFlag: String, CaseIterable, Sendable {
    case vegetarianFriendly = "Vegetarian"
    case veganOptions       = "Vegan"
    case glutenFriendly     = "Gluten-Friendly"
    case dairyFree          = "Dairy-Free"
    case nutFree            = "Nut-Free"
    case halal              = "Halal"
    case kidsMenu           = "Kids Menu"

    var systemImage: String {
        switch self {
        case .vegetarianFriendly: return "leaf"
        case .veganOptions:       return "leaf.fill"
        case .glutenFriendly:     return "g.circle"
        case .dairyFree:          return "drop.slash"
        case .nutFree:            return "exclamationmark.triangle"
        case .halal:              return "moon.stars"
        case .kidsMenu:           return "figure.child"
        }
    }
}

// MARK: - DiningMetadata

/// Static editorial metadata for a dining venue in the Parkio catalog.
///
/// Owned entirely by the Parkio editorial team. When the review layer is ready,
/// `DiningReview` (user-generated ratings) sits beside this struct, not inside it.
///
/// Attached to `MasterAttraction` via its `dining` field. Always nil when
/// `attraction.type.isDining == false`.
struct DiningMetadata: Sendable {

    // MARK: Editorial

    /// Rough per-person cost bracket.
    let priceTier: PriceTier

    /// Parkio editorial score, 1–10. Drives dining sort order and recommendations.
    ///   9–10 = unmissable  ·  7–8 = strongly recommended  ·  5–6 = solid backup
    let parkioScore: Int

    /// One-line verdict shown under the venue name. Target ≤ 80 chars.
    let shortVerdict: String

    // MARK: Menu signals

    /// Two or three must-order items, displayed as horizontal chips.
    let signatureItems: [String]

    // MARK: Logistics

    /// Guest can order ahead via My Disney Experience / Disneyland apps.
    let mobileOrderAvailable: Bool

    /// Venue has climate-controlled interior seating.
    let indoorSeating: Bool

    /// Generally suitable for families with young children.
    let kidFriendly: Bool

    // MARK: Dietary filters

    /// Applicable dietary accommodation flags for filter UI.
    let dietaryFlags: Set<DietaryFlag>

    // MARK: Convenience init (short label names for catalog readability)

    init(
        price:       PriceTier,
        score:       Int,
        verdict:     String,
        signature:   [String]         = [],
        mobileOrder: Bool             = false,
        indoor:      Bool             = true,
        kids:        Bool             = true,
        dietary:     Set<DietaryFlag> = []
    ) {
        priceTier            = price
        parkioScore          = score
        shortVerdict         = verdict
        signatureItems       = signature
        mobileOrderAvailable = mobileOrder
        indoorSeating        = indoor
        kidFriendly          = kids
        dietaryFlags         = dietary
    }
}

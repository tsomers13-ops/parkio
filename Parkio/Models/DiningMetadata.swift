// DiningMetadata.swift — Supporting types for the Parkio dining catalog.
//
// Architecture
// ────────────
// PriceTier      — Disney's per-adult dining price band ($–$$$$).
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

/// Disney's per-adult dining price band.
///
/// `bandText` is the only copy of Disney's legend. The price key, the dining
/// detail, and VoiceOver all read it from here.
enum PriceTier: Int, Comparable, CaseIterable, Sendable {
    case budget    = 1  // $
    case moderate  = 2  // $$
    case upscale   = 3  // $$$
    case signature = 4  // $$$$

    static func < (lhs: PriceTier, rhs: PriceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// "$", "$$", "$$$", "$$$$"
    var displayString: String { String(repeating: "$", count: rawValue) }

    /// Disney's range for this band, including "per adult". A venue with no
    /// tier shows neither this nor `displayString`.
    var bandText: String {
        switch self {
        case .budget:    return "$14.99 and under per adult"
        case .moderate:  return "$15 to $34.99 per adult"
        case .upscale:   return "$35 to $59.99 per adult"
        case .signature: return "over $60 per adult"
        }
    }

    /// The band text. Kept so older call sites cannot drift onto a second wording.
    var label: String { bandText }

    /// Spoken form for a row that shows this tier. Dollar signs are counted
    /// in words so VoiceOver does not spell "$" four times.
    var accessibilityLabel: String {
        switch self {
        case .budget:
            return "One dollar sign, 14 dollars and 99 cents and under per adult"
        case .moderate:
            return "Two dollar signs, 15 to 34 dollars and 99 cents per adult"
        case .upscale:
            return "Three dollar signs, 35 to 59 dollars and 99 cents per adult"
        case .signature:
            return "Four dollar signs, over 60 dollars per adult"
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

    /// Rough per-person cost bracket. Nil when no tier is assigned; the UI
    /// shows no price in that case, rather than a placeholder "$".
    let priceTier: PriceTier?

    /// Parkio editorial score, 1–10. Nil when no score has been authored.
    ///   9–10 = unmissable  ·  7–8 = strongly recommended  ·  5–6 = solid backup
    let parkioScore: Int?

    /// One-line verdict shown under the venue name. Nil when none has been
    /// authored. Target ≤ 80 chars when present.
    let shortVerdict: String?

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

    /// `price` may be nil. `score` and `verdict` stay nil for a tier-only
    /// entry so a price is never paired with an invented editorial.
    init(
        price:       PriceTier? = nil,
        score:       Int? = nil,
        verdict:     String? = nil,
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

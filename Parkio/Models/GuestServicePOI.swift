// GuestServicePOI.swift — Parkio Guest Services architecture + pilot (Priority 6).
//
// Architecture
// ────────────
// Guest Services is a third peer content domain alongside Attraction/Dining
// (MasterAttraction) and Shopping (MasterShop) — exactly the "(future) Guest
// Service / Utility POI — a third peer struct" ShopMasterData.swift already
// anticipated. It is deliberately ONE struct (`GuestServicePOI`) with a
// `GuestServiceCategory` enum discriminator, not seven separate structs
// (RestroomPOI, FirstAidPOI, ...). Every category shares the exact same
// shape — a name, a park, a land, a coordinate, map eligibility — so a
// per-type struct would only duplicate that shape seven times for zero
// structural benefit. If a category ever needs data the others genuinely
// don't (e.g. an accessibility-service point needing a phone number), that
// becomes an optional field on this struct, the same way `ShoppingMetadata`
// is optional on `MasterShop` — not a reason to fork the type.
//
// This model is deliberately small. No score, tier, or rating of any kind —
// a restroom does not need a Parkio score, and a First Aid station is not
// "recommended" or "notable." `ShoppingTier` and `ShoppingMetadata` have no
// analog here on purpose.
//
// Accessibility handling: this pilot does NOT attach "wheelchair accessible"
// / "ADA compliant" claims to any POI — that would be a factual claim Parkio
// cannot verify or keep current. `.accessibilityService` exists as a
// category for representing an actual accessibility Guest Services touch
// point (e.g. a dedicated accessibility desk), not as a mechanism for rating
// every other POI's accessibility. No POI in this pilot uses that category —
// no verified accessibility-service-specific location was identified for
// either park (see Unresolved in the Priority 6 report).
//
// Seeding: like Shopping, Guest Services is NOT seeded into SwiftData. There
// is no "visited this restroom" concept. This keeps Guest Services fully out
// of Best Next Ride and DiningRecommendationService, exactly like Shopping.
//
// Map integration: reuses the existing MapCoordinates.json / MapRideAnnotation
// / RideCategory pipeline (see the new .restroom/.firstAid/.guestRelations/
// .babyCare/.lockers/.atm/.accessibilityService cases added to RideCategory
// in MapRideAnnotation.swift). MapCoordinateService.validate()'s
// `mapVisibleIDs` set is broadened to include map-visible Guest Service
// stableIDs — the SAME validation pipeline Attractions and Shopping already
// use, not a duplicate one.
//
// Guest Service pins are NOT fed into MapViewModel's ride declutter/filter
// pipeline (MapFilterState, buildVisibleAnnotations) — that pipeline's
// semantics (showRidden, hideClosed, planOnly, onlyLowWait) are ride-specific
// and don't apply to a restroom. Guest Services get their own, much simpler
// visibility mechanism: `MapViewModel.activeGuestServiceCategories:
// Set<GuestServiceCategory>`, default empty — nothing shows until a guest
// opts into a category. See RealMapScreen.swift / MapOverlayFilterBar.swift
// for the rendering + filter UI this drives.
//
// Coordinate policy — MORE conservative than Shopping's, per explicit
// instruction ("a wrong restroom pin or First Aid pin can materially hurt
// the guest experience"). No coordinate here is guessed, eyeballed, land-
// centered, or inferred from mere proximity to a restaurant. Every pilot
// coordinate below was sourced from OpenStreetMap's public map data
// (api.openstreetmap.org /api/0.6/map, queried against this app's own
// verified EPCOT/Hollywood Studios bounding boxes) — cross-verified against
// Disney's official descriptions gathered separately (Disney's own Guest
// Relations page, and well-corroborated secondary sources for First Aid /
// Baby Care / restroom locations). Several OSM nodes used here carry their
// own corroborating signal: a `website` tag pointing directly at
// disneyworld.disney.go.com/guest-services/restrooms/ or
// .../baby-care-centers/, an explicit `name` tag ("First Aid", "Baby Care
// Center", "Guest Relations", "Germany Restrooms"), or a `check_date` as
// recent as 2026-09-05 showing active community verification. This is the
// "highly reliable geographic source cross-verified against Disney" tier
// from the sourcing brief — not tier 1 (Disney's own map data isn't
// programmatically accessible to this environment), but well above
// eyeballing. Every per-POI comment below states its evidence.
//
// NOTE ON A PRIOR PHASE'S "Unresolved": Priority 5B's ShopMasterData.swift
// recorded that "OSM/Nominatim/Overpass/Google Maps are blocked to this
// environment." That was true for the Overpass API specifically
// (overpass-api.de and overpass.kumi.systems both failed/reset this
// session too) — but OpenStreetMap's own raw data API
// (api.openstreetmap.org/api/0.6/map) is reachable and was used for every
// coordinate in this file. This does not retroactively fix any Shopping
// coordinate — Shopping is out of scope this phase — but it is a capability
// worth revisiting if a future Shopping phase wants to close that gap.
//
// Restroom naming: no restroom in this pilot has a Disney-assigned proper
// name (Disney doesn't name most restrooms) — display names use the
// "Restrooms — [Land/Location]" or "Restrooms near [Landmark]" pattern
// specified in the brief. The two exceptions are EPCOT's Germany restrooms,
// which OSM independently tags with the literal name "Germany Restrooms"
// (a genuine on-the-ground designation, not manufactured here).
//
// Shared facilities: EPCOT's First Aid and Baby Care Center are verified
// co-located in the Odyssey Center building (OSM coordinates ~9m apart:
// 28.3719563,-81.5477466 vs 28.371894,-81.5476995 — two real, distinct
// rooms in one building, not a fabricated split). Hollywood Studios' First
// Aid and Guest Relations are verified co-located in the main-entrance
// building (~16m apart: 28.3578889,-81.5586416 vs 28.3580267,-81.5586409).
// Because the underlying OSM data already resolves these as distinct real
// coordinates, no artificial offset was invented and no forced-identical
// coordinate was needed — see MapCoordinateService.validate() for how the
// duplicate-coordinate check now distinguishes true duplicates (same
// category, same coordinate) from legitimate co-location (different
// category, same or adjacent coordinate).

import Foundation

// MARK: - GuestServiceCategory

/// The seven Guest Service categories this domain is scoped to. Deliberately
/// matches the category list from the Priority 6 brief exactly — not
/// expanded speculatively.
enum GuestServiceCategory: String, Sendable, CaseIterable {
    case restroom
    case firstAid
    case guestRelations
    case babyCare
    case lockers
    case atm
    case accessibilityService

    var label: String {
        switch self {
        case .restroom:             return "Restrooms"
        case .firstAid:              return "First Aid"
        case .guestRelations:        return "Guest Relations"
        case .babyCare:               return "Baby Care"
        case .lockers:                return "Lockers"
        case .atm:                    return "ATM"
        case .accessibilityService:  return "Accessibility Services"
        }
    }

    /// Matches the raw value used for this category's `RideCategory` case in
    /// MapRideAnnotation.swift, so a MasterGuestService's JSON map entry and
    /// its canonical model data always agree on category naming.
    var rideCategoryRawValue: String {
        switch self {
        case .restroom:             return "restroom"
        case .firstAid:              return "first_aid"
        case .guestRelations:        return "guest_relations"
        case .babyCare:               return "baby_care"
        case .lockers:                return "lockers"
        case .atm:                    return "atm"
        case .accessibilityService:  return "accessibility_service"
        }
    }

    /// Typed bridge to the map's `RideCategory` (icon/JSON-category type),
    /// used by MapViewModel's Guest Service filtering. Force-unwrap is safe:
    /// every case here has a matching `RideCategory` case with an identical
    /// raw value (added together in MapRideAnnotation.swift for Priority 6).
    var rideCategory: RideCategory {
        // swiftlint:disable:next force_unwrapping
        RideCategory(rawValue: rideCategoryRawValue)!
    }
}

// MARK: - GuestServicePOI

/// One Guest Service location in the Parkio catalog. Deliberately minimal —
/// see the architecture note at the top of this file for why. No tier, no
/// score, no editorial metadata struct: there is nothing here for one to
/// attach to.
struct GuestServicePOI: Sendable {
    /// Display name — also the final component of stableID. Uses the
    /// "Restrooms — [Land/Location]" / "Restrooms near [Landmark]" pattern
    /// for unnamed facilities; a real on-the-ground name (e.g. "First Aid",
    /// "Germany Restrooms") when Disney/OSM actually gives it one.
    let name: String
    let park: Park
    /// Canonical land name — must match an entry in `park.lands`.
    let land: String
    let category: GuestServiceCategory
    /// Map pin priority: 1 = always visible, 2 = default zoom, 3 = zoomed in,
    /// nil = no verified coordinate — not map-visible. Every pilot POI in
    /// this file has a verified coordinate (map: 1), since an unlocatable
    /// Guest Service POI is dropped entirely per the sourcing policy above,
    /// not entered with map: nil the way a coordinate-less Shop is — a
    /// Guest Service record with no coordinate has no purpose in this
    /// map-first domain.
    let mapPriority: Int?
    /// Alternate search terms (e.g. ["bathroom", "toilet"] for a restroom).
    /// Optional, never fabricated beyond obvious synonyms.
    let aliases: [String]

    init(
        _ name: String,
        park: Park,
        land: String,
        category: GuestServiceCategory,
        map: Int? = nil,
        aliases: [String] = []
    ) {
        self.name = name
        self.park = park
        self.land = land
        self.category = category
        self.mapPriority = map
        self.aliases = aliases
    }

    /// "{Park.rawValue}|{land}|{name}" — same shape and per-park namespace as
    /// MasterAttraction.stableID and MasterShop.stableID.
    var stableID: String { "\(park.rawValue)|\(land)|\(name)" }

    var parkId: String { park.backendId }

    var shouldAppearOnMap: Bool { mapPriority != nil }

    /// Always `.guestService` — see `ContentCategory` in ShopMasterData.swift.
    var contentCategory: ContentCategory { .guestService }
}

// MARK: - GuestServiceMasterData

enum GuestServiceMasterData {

    // MARK: - Pilot catalog (Priority 6)
    //
    // 14 POIs across EPCOT (8) and Hollywood Studios (6) — a representative
    // architecture pilot per the brief's explicit "~8-15 total, do NOT
    // populate every restroom" scope. Every coordinate is sourced from
    // OpenStreetMap's live map data (queried this session against this
    // app's own verified park bounding boxes — see MapCoordinateService.
    // roughParkBounds) and cross-checked against independently-researched
    // Disney/secondary-source descriptions. See the file-level doc comment
    // for the full sourcing methodology.

    static let all: [GuestServicePOI] = [

        // ── EPCOT — World Discovery ──────────────────────────────────────
        //
        // First Aid + Baby Care Center are verified co-located in the
        // Odyssey Center building (OSM: node/1323019830 "First Aid",
        // healthcare=clinic, emergency=yes; node/3144081712 "Baby Care
        // Center", healthcare=clinic, website=disneyworld.disney.go.com/
        // guest-services/baby-care-centers/ — both explicitly named by OSM,
        // ~9m apart). Physically the Odyssey building sits between the
        // World Discovery cluster (Test Track, Mission: SPACE) and the
        // World Showcase bridge to Mexico; independent research could not
        // fully resolve whether Disney's current signage tags this
        // building "World Celebration" or "World Discovery" (both were
        // reported by different current sources). Land assignment here
        // uses World Discovery on physical-proximity grounds (closest
        // existing verified coordinates: Test Track 28.372856,-81.5472181,
        // Mission: SPACE 28.3739006,-81.5467164) — flagged as medium
        // confidence; see Unresolved in the Priority 6 report.
        GuestServicePOI(
            "First Aid — Odyssey Center",
            park: .epcot, land: "World Discovery",
            category: .firstAid, map: 1
        ),
        GuestServicePOI(
            "Baby Care Center — Odyssey Center",
            park: .epcot, land: "World Discovery",
            category: .babyCare, map: 1
        ),
        GuestServicePOI(
            "Restrooms — Odyssey Center",
            park: .epcot, land: "World Discovery",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── EPCOT — World Celebration ─────────────────────────────────────
        //
        // Guest Relations: OSM node/2988933030, explicitly named "Guest
        // Relations" (tourism=information), ~90m from Spaceship Earth.
        // Matches Disney's official Guest Relations page, which lists a
        // "Guest Relations Lobby in World Celebration."
        GuestServicePOI(
            "Guest Relations — World Celebration",
            park: .epcot, land: "World Celebration",
            category: .guestRelations, map: 1
        ),
        // Restrooms near CommuniCore Hall: OSM node/13404480039, check_date
        // 2026-09-05 (most recently verified node in this pilot), ~50m from
        // Spaceship Earth / GEO-82. Matches independent research's
        // "CommuniCore Hall restrooms" finding.
        GuestServicePOI(
            "Restrooms — CommuniCore Hall",
            park: .epcot, land: "World Celebration",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── EPCOT — World Nature ──────────────────────────────────────────
        //
        // OSM node/1329743806, ~75m from Soarin' Around the World. Matches
        // independent research's "The Land pavilion restrooms" finding.
        GuestServicePOI(
            "Restrooms — The Land Pavilion",
            park: .epcot, land: "World Nature",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── EPCOT — World Showcase ────────────────────────────────────────
        //
        // OSM node/2436679482 — independently named "Germany Restrooms" by
        // OSM itself (not manufactured here), between the Germany and Italy
        // pavilions. Matches independent research's "Germany/Italy border
        // restrooms" finding exactly.
        GuestServicePOI(
            "Germany Restrooms",
            park: .epcot, land: "World Showcase",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),
        // OSM node/594273066, check_date 2026-04-17, ~20m from Remy's
        // Ratatouille Adventure. Matches independent research's "France
        // Pavilion restrooms... along the newer walkway built for Remy's
        // Ratatouille Adventure" finding.
        GuestServicePOI(
            "Restrooms near France Pavilion",
            park: .epcot, land: "World Showcase",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── Hollywood Studios — Hollywood Boulevard ───────────────────────
        //
        // First Aid + Guest Relations verified co-located in the main-
        // entrance building (OSM: node/1323030268 "First Aid",
        // healthcare=clinic, emergency=yes; node/3295740763 "Guest
        // Relations", tourism=information — ~16m apart). Matches
        // independent research: Disney's official Guest Relations page
        // lists a Guest Relations Lobby + Window at Hollywood Studios, and
        // secondary sources place First Aid in the same entrance-plaza
        // building. No verified Baby Care Center node was found here (see
        // Unresolved) — not fabricated.
        GuestServicePOI(
            "First Aid — Main Entrance",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .firstAid, map: 1
        ),
        GuestServicePOI(
            "Guest Relations — Main Entrance",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .guestRelations, map: 1
        ),

        // ── Hollywood Studios — Echo Lake ─────────────────────────────────
        //
        // OSM way/159469841 (building) centroid, ~1m from Backlot Express.
        // Matches independent research's "Across from Backlot Express,
        // facing Echo Lake" finding almost exactly.
        GuestServicePOI(
            "Restrooms near Backlot Express",
            park: .hollywoodStudios, land: "Echo Lake",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── Hollywood Studios — Sunset Boulevard ──────────────────────────
        //
        // OSM way/294883734 (building) centroid, ~65m from The Twilight
        // Zone Tower of Terror. Matches independent research's "Near Tower
        // of Terror" finding.
        GuestServicePOI(
            "Restrooms near Tower of Terror",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── Hollywood Studios — Toy Story Land ────────────────────────────
        //
        // OSM node/6419360168, ~13m from Alien Swirling Saucers. Matches
        // independent research's "Near Alien Swirling Saucers" finding.
        GuestServicePOI(
            "Restrooms near Alien Swirling Saucers",
            park: .hollywoodStudios, land: "Toy Story Land",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        ),

        // ── Hollywood Studios — Star Wars: Galaxy's Edge ──────────────────
        //
        // OSM node/10000541128, tagged operator="Disney Parks and Resorts"
        // (an explicit operator tag, not just a generic community-mapped
        // toilet), ~110m from Millennium Falcon: Smugglers Run. Matches
        // independent research's "restrooms within the marketplace area,
        // near Droid Depot" finding (same general Galaxy's Edge cluster).
        GuestServicePOI(
            "Restrooms — Star Wars: Galaxy's Edge",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .restroom, map: 2,
            aliases: ["bathroom", "toilet"]
        )
    ]

    static func pois(for park: Park) -> [GuestServicePOI] {
        all.filter { $0.park == park }
    }

    static func pois(for park: Park, category: GuestServiceCategory) -> [GuestServicePOI] {
        all.filter { $0.park == park && $0.category == category }
    }

    /// Map-visible POIs, grouped for MapViewModel's independent Guest
    /// Service loading path (never merged into the ride/dining/shopping
    /// annotation array).
    static func mapVisiblePOIs(for park: Park) -> [GuestServicePOI] {
        pois(for: park).filter(\.shouldAppearOnMap)
    }
}

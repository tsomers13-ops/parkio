// ShopMasterData.swift — Parkio Shopping catalog (Priority 5 pilot).
//
// Architecture
// ────────────
// Shopping is a first-class Parkio content domain, deliberately NOT modeled as
// an `AttractionType` case. A shop is not a guest "experience" the way a ride,
// show, or dining venue is — `AttractionType` stays scoped to those, and this
// file introduces a parallel, smaller model instead of expanding that enum
// into a generic content bucket.
//
// Conceptually:
//
//   Parkio Content
//     → Attraction   (MasterAttraction, type.isDining == false)
//     → Dining       (MasterAttraction, type.isDining == true)
//     → Shopping     (MasterShop — this file)
//     → (future) Guest Service / Utility POI — a third peer struct, added the
//        same way, when that content domain is actually built. Nothing here
//        blocks it.
//
// `ContentCategory` is the shared vocabulary across domains. `MasterAttraction`
// does not store one — the whole point of this design is that Attraction and
// Dining behavior is untouched — but it can be read off `type.isDining`
// (see `MasterAttraction.contentCategory` below, purely additive). `MasterShop`
// always reports `.shopping`.
//
// No repo-wide rename. `MasterAttraction` keeps its name and every existing
// call site is unchanged — this file adds a sibling model, not a rewrite.
//
// Seeding
// ───────
// Shopping is intentionally NOT seeded into SwiftData (no `Ride` row, no
// stableID insertion via RideSeeder). There is no "visited this shop" /
// "log a shop stop" concept in Parkio today, so there is nothing to seed.
// This also keeps Shopping fully out of Best Next Ride and out of
// DiningRecommendationService — both operate over `RideMasterData.all` /
// `MasterAttraction`, which `MasterShop` is not part of.
//
// Map integration
// ────────────────
// Shopping reuses the existing MapCoordinates.json / MapRideAnnotation /
// RideCategory pipeline exactly like Dining already does — a shop with a
// verified coordinate gets a `"category": "shopping"` entry in
// MapCoordinates.json (see RideCategory.shopping in MapRideAnnotation.swift).
// No new map view-model code is required; MapCoordinateService.validate()'s
// `mapVisibleIDs` set is broadened to include map-visible shop stableIDs so
// shopping pins are checked by the SAME validation dining and attractions
// already use, not a duplicate pipeline.
//
// A shop with no verified coordinate is still a fully valid Shopping record —
// it is simply not map-visible (`mapPriority == nil`), the same supported
// pattern already used for seed:false / map:nil MasterAttraction entries
// (e.g. Liberty Belle Riverboat). Coordinates are never guessed or
// eyeballed — see the per-shop notes in the pilot data below.

import Foundation

// MARK: - ContentCategory

/// Shared top-level classification across Parkio's content domains.
/// `MasterAttraction` derives this from `type.isDining`; `MasterShop` is
/// always `.shopping`. Not currently used for cross-domain iteration (no
/// consumer needs that yet) — it exists so the three domains have one
/// shared name, ready for a real merge point (e.g. unified search) later
/// without inventing new vocabulary at that time.
enum ContentCategory: String, Sendable {
    case attraction
    case dining
    case shopping
    /// Priority 6 — see GuestServicePOI.swift. `GuestServicePOI` always
    /// reports this; `MasterAttraction`/`MasterShop` are unaffected.
    case guestService
}

// MARK: - ShoppingCategory

/// Small, deliberately non-exhaustive shopping taxonomy. Optimized for useful
/// filtering, not Disney-catalog completeness.
enum ShoppingCategory: String, Sendable, CaseIterable {
    /// Broad park/character merchandise — apparel, plush, souvenirs.
    case generalMerchandise
    /// Themed or country-specific goods not found generically elsewhere
    /// (e.g. imported goods, artisan items, land-specific theming).
    case specialty
    /// Shop tied directly to a specific attraction, typically its exit shop.
    case attractionMerchandise
    /// Candy, confectionery, and other food-as-souvenir retail — distinct
    /// from a dining venue: this is retail, not a meal.
    case foodConfectionery

    var label: String {
        switch self {
        case .generalMerchandise:   return "General Merchandise"
        case .specialty:            return "Specialty"
        case .attractionMerchandise: return "Attraction Merchandise"
        case .foodConfectionery:    return "Food & Confectionery"
        }
    }
}

// MARK: - ShoppingTier

/// Guest-interest prioritization signal — display-only, mirrors
/// `EntertainmentTier`'s role for entertainment content. Exists because most
/// Disney shops sell broadly similar generic merchandise; without a tier,
/// every shop would compete for equal visual weight in any future discovery
/// surface regardless of actual guest value.
enum ShoppingTier: String, Sendable {
    /// Useful local/general merchandise — the default.
    case standard
    /// Stronger theme, specialty merchandise, or above-average guest interest.
    case notable
    /// A location some guests intentionally seek out and plan around.
    case destination
}

// MARK: - ShoppingMetadata

/// Static editorial metadata for a shop in the Parkio catalog. Mirrors
/// `DiningMetadata`'s factual-vs-editorial split: always optional, never
/// fabricated, and never a claim Parkio cannot keep current.
///
/// Deliberately excludes anything Parkio cannot reliably maintain: live
/// inventory, current stock, exact item availability, prices, or "exclusive
/// item" claims. `ShoppingTier` — not a field here — carries the "worth a
/// stop" signal, so there is no redundant boolean alongside it.
struct ShoppingMetadata: Sendable {
    /// One-line note on what makes this shop notable. Target ≤ 80 chars.
    let notableFor: String?

    /// Broad merchandise focus tags (e.g. ["Star Wars collectibles"]) —
    /// categories, not a live inventory list.
    let merchandiseFocus: [String]

    /// Optional planning note (e.g. "worth timing around a slower moment").
    let planningNote: String?

    init(
        notableFor: String? = nil,
        merchandiseFocus: [String] = [],
        planningNote: String? = nil
    ) {
        self.notableFor       = notableFor
        self.merchandiseFocus = merchandiseFocus
        self.planningNote     = planningNote
    }
}

// MARK: - MasterShop

/// One shopping location in the Parkio catalog. Parallel to `MasterAttraction`
/// in shape (name/park/land/stableID/map/entityId) but intentionally its own
/// type — see the architecture note at the top of this file for why.
struct MasterShop: Sendable {
    /// Canonical display name — also the final component of stableID.
    let name: String
    let park: Park
    /// Canonical land name — must match an entry in `park.lands`.
    let land: String
    let category: ShoppingCategory
    let tier: ShoppingTier
    /// Map pin priority: 1 = always visible, 2 = default zoom, 3 = zoomed in,
    /// nil = no verified coordinate — not map-visible this pass.
    let mapPriority: Int?
    /// ThemeParks.wiki entity UUID, when a real entity legitimately identifies
    /// this exact location (not borrowed from a different guest experience).
    /// Disney Shopping locations are largely untracked by ThemeParks.wiki —
    /// `nil` here is the expected norm, not a data gap.
    let entityId: String?
    /// Parkio editorial metadata. Optional; never fabricated.
    let editorial: ShoppingMetadata?

    init(
        _ name: String,
        park: Park,
        land: String,
        category: ShoppingCategory,
        tier: ShoppingTier = .standard,
        map: Int? = nil,
        entityId: String? = nil,
        editorial: ShoppingMetadata? = nil
    ) {
        self.name      = name
        self.park      = park
        self.land      = land
        self.category  = category
        self.tier      = tier
        self.mapPriority = map
        self.entityId  = entityId
        self.editorial = editorial
    }

    /// "{Park.rawValue}|{land}|{name}" — same shape and same per-park
    /// namespace as MasterAttraction.stableID, so MapCoordinates.json and
    /// MapCoordinateService validation treat Shopping pins identically.
    var stableID: String { "\(park.rawValue)|\(land)|\(name)" }

    var parkId: String { park.backendId }

    var shouldAppearOnMap: Bool { mapPriority != nil }

    /// Always `.shopping` — see `ContentCategory` doc comment.
    var contentCategory: ContentCategory { .shopping }
}

// MARK: - MasterAttraction bridge (purely additive)

extension MasterAttraction {
    /// Read-only classification bridge so Attraction/Dining/Shopping share one
    /// vocabulary. Derived, not stored — zero change to any existing
    /// `MasterAttraction` call site or stored layout.
    var contentCategory: ContentCategory { type.isDining ? .dining : .attraction }
}

// MARK: - ShopMasterData

enum ShopMasterData {

    // MARK: - Pilot catalog (Priority 5)
    //
    // 7 shops across EPCOT and Hollywood Studios — a representative pilot,
    // not the full ~34-shop audit. Every entry below was independently
    // verified as currently open via Disney's own shop pages (not
    // ThemeParks.wiki alone, which does not track Shopping as an entity
    // type at all — confirmed by querying both parks' /children endpoints).
    //
    // An 8th candidate, Karamell-Küche, was deliberately dropped from this
    // pilot: it already exists in Parkio as a Dining venue (same entity ID,
    // same physical counter — it sells both a walk-up caramel snack and
    // packaged retail candy). Adding it again under Shopping would collide
    // on stableID for the same real-world location. See Unresolved for the
    // broader hybrid-venue question this raises.
    //
    // Coordinate policy for this pilot: never guessed. Two shops that are
    // physically the exit/host shop of an already coordinate-verified
    // MasterAttraction reuse that exact coordinate (flagged inline as
    // co-located, same handling as Priority 4C's co-located POIs — real
    // shared geography, not a fabricated pin). The remaining five have no
    // coordinate available through any permitted source (no ThemeParks.wiki
    // entity, no embedded geo on Disney's shop pages, and OSM/Nominatim/
    // Overpass/Google Maps are blocked to this environment) and are
    // deliberately left `map: nil` rather than estimated — see Unresolved.

    static let all: [MasterShop] = [

        // ── EPCOT — World Celebration ────────────────────────────────────
        MasterShop(
            "Creations Shop",
            park: .epcot, land: "World Celebration",
            category: .generalMerchandise, tier: .standard
            // No coordinate available (see policy note above).
        ),

        // ── EPCOT — World Showcase ───────────────────────────────────────
        MasterShop(
            "Mitsukoshi Department Store",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .notable
            // The only Mitsukoshi store in North America — genuinely
            // distinctive, but no coordinate available (see policy note).
        ),

        // ── EPCOT — World Discovery ───────────────────────────────────────
        // Cargo Bay is Mission: SPACE's exit shop — same building/plaza.
        // Coordinate is Mission: SPACE's own verified attraction coordinate,
        // reused because this is the same physical structure, not a guess.
        // entityId intentionally left nil: that ID identifies the ride, not
        // this shop, and ThemeParks.wiki has no separate entity for the shop.
        MasterShop(
            "Mission: SPACE Cargo Bay",
            park: .epcot, land: "World Discovery",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),

        // ── Hollywood Studios — Hollywood Boulevard ──────────────────────
        MasterShop(
            "Mickey's of Hollywood",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .generalMerchandise, tier: .standard
            // No coordinate available (see policy note above).
        ),

        // ── Hollywood Studios — Sunset Boulevard ─────────────────────────
        // Tower Hotel Gifts is the queue-exit shop for The Twilight Zone
        // Tower of Terror — same building. Coordinate reused from that
        // already-verified MasterAttraction entry; entityId left nil for
        // the same reason as Cargo Bay above.
        MasterShop(
            "Tower Hotel Gifts",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),

        MasterShop(
            "Beverly Sunset Boutique",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .generalMerchandise, tier: .standard
            // No coordinate available (see policy note above).
        ),

        // ── Hollywood Studios — Star Wars: Galaxy's Edge ─────────────────
        // Required Galaxy's Edge test case. A standalone destination shop —
        // not co-located with a single attraction, so no coordinate to
        // legitimately reuse; left map: nil rather than estimated.
        MasterShop(
            "Dok-Ondar's Den of Antiquities",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .destination,
            editorial: ShoppingMetadata(
                notableFor: "Curated, rotating collection of in-universe Star Wars artifacts and lightsabers.",
                merchandiseFocus: ["Legacy lightsabers", "Kyber crystals", "Collectibles"]
            )
        ),

        // ══════════════════════════════════════════════════════════════════
        // Priority 5B — EPCOT + Hollywood Studios Shopping completion.
        // All entries below are verified via Disney's official shop
        // directory (disneyworld.disney.go.com/shops/...) and/or official
        // individual shop pages, current as of this pass. entityId is nil
        // throughout: ThemeParks.wiki has no MERCHANDISE entity type for
        // either park (confirmed by direct API query), so nil here is the
        // expected norm, not a data gap. Coordinates are reused ONLY where
        // a shop is the confirmed same-building exit/host shop of an
        // already-verified MasterAttraction; all other new entries are
        // deliberately left map: nil rather than estimated — see the
        // Priority 5B report's "Coordinate Coverage" section.
        // ══════════════════════════════════════════════════════════════════

        // ── EPCOT — World Celebration (additions) ───────────────────────
        MasterShop(
            "Gateway Gifts",
            park: .epcot, land: "World Celebration",
            category: .generalMerchandise, tier: .standard
            // Near Spaceship Earth / the park entrance, but not confirmed as
            // literally the same structure — no coordinate reused, left
            // unmapped rather than guessed.
        ),
        MasterShop(
            "Pin Traders - Camera Center",
            park: .epcot, land: "World Celebration",
            category: .specialty, tier: .standard
            // Pin trading headquarters + camera/photo accessories. No
            // coordinate available.
        ),

        // ── EPCOT — World Discovery (additions) ───────────────────────
        // Treasures of Xandar is Guardians of the Galaxy: Cosmic Rewind's
        // confirmed exit shop — same building. Coordinate reused from that
        // already-verified MasterAttraction; entityId nil for the same
        // reason as Mission: SPACE Cargo Bay above.
        MasterShop(
            "Treasures of Xandar",
            park: .epcot, land: "World Discovery",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),
        // Test Track Gear Shop is Test Track's official exit shop — same
        // building. Coordinate reused from Test Track's verified attraction
        // entry.
        MasterShop(
            "Test Track Gear Shop",
            park: .epcot, land: "World Discovery",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),

        // ── EPCOT — World Nature (new land coverage) ────────────────────
        // SeaBase Gift Shop is the exit shop of The Seas with Nemo & Friends
        // pavilion — same building. Coordinate reused from that verified
        // attraction entry. First Shopping coverage for World Nature.
        MasterShop(
            "SeaBase Gift Shop",
            park: .epcot, land: "World Nature",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),

        // ── EPCOT — World Showcase: Mexico ───────────────────────────────
        MasterShop(
            "Plaza de los Amigos",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "El Ranchito del Norte",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Handcrafted Mexican goods (serapes, sombreros, pottery).
            // Reopened September 2025 after a multi-year closure.
        ),
        MasterShop(
            "La Princesa de Cristal",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Hand-blown glass and crystal figurines.
        ),
        MasterShop(
            "La Tienda Encantada",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
        ),

        // ── EPCOT — World Showcase: Norway ────────────────────────────────
        MasterShop(
            "The Fjording",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
        ),

        // ── EPCOT — World Showcase: Germany ───────────────────────────────
        MasterShop(
            "Der Teddybar",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Steiff and other collectible teddy bears/toys.
        ),
        MasterShop(
            "Das Kaufhaus",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "Glaskunst",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Engraved crystal/glassware with in-pavilion glass-blowing
            // demonstrations.
        ),

        // ── EPCOT — World Showcase: Italy ─────────────────────────────────
        MasterShop(
            "Il Bel Cristallo",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Murano glass, Venetian carnival masks, Italian goods.
        ),
        MasterShop(
            "La Bottega Italiana",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
        ),

        // ── EPCOT — World Showcase: China ─────────────────────────────────
        MasterShop(
            "House of Good Fortune",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
        ),

        // ── EPCOT — World Showcase: France ────────────────────────────────
        MasterShop(
            "Plume et Palette",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .notable,
            editorial: ShoppingMetadata(
                notableFor: "Exclusive fragrance and accessory house not widely available elsewhere at Walt Disney World.",
                merchandiseFocus: ["Designer fragrances", "Handbags", "French beauty brands"]
            )
        ),

        // ── EPCOT — World Showcase: Canada ────────────────────────────────
        MasterShop(
            "Trading Post",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Hand-carved wood gifts and Canadian maple syrup.
        ),

        // ── EPCOT — World Showcase: United Kingdom ────────────────────────
        MasterShop(
            "The Crown & Crest",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Personalized family-crest and heraldry goods, Beatles
            // memorabilia.
        ),
        MasterShop(
            "The Tea Caddy",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // Twinings tea and British confectionery/merchandise.
        ),

        // ── EPCOT — World Showcase Plaza / Outpost / International Gateway ─
        MasterShop(
            "Disney Traders",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "Port of Entry",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "World Traveler",
            park: .epcot, land: "World Showcase",
            category: .generalMerchandise, tier: .standard
            // At the International Gateway entrance.
        ),
        MasterShop(
            "Village Traders",
            park: .epcot, land: "World Showcase",
            category: .specialty, tier: .standard
            // "The Outpost" — African-themed instruments, wood carvings,
            // soapstone sculptures.
        ),

        // ── Hollywood Studios — Hollywood Boulevard (additions) ──────────
        MasterShop(
            "Sid Cahuenga's One-of-a-Kind",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .generalMerchandise, tier: .standard
            // Per Disney's own shop page, primarily PhotoPass + general
            // merchandise — not the "rare memorabilia" framing some
            // secondary sources use.
        ),
        MasterShop(
            "Keystone Clothiers",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "Celebrity 5 & 10",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "Crossroads of the World",
            park: .hollywoodStudios, land: "Hollywood Boulevard",
            category: .generalMerchandise, tier: .standard
            // Main-entrance plaza shop; Park.lands has no separate "Main
            // Entrance" land, so this is filed under Hollywood Boulevard.
        ),

        // ── Hollywood Studios — Sunset Boulevard (additions) ─────────────
        MasterShop(
            "Legends of Hollywood",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .generalMerchandise, tier: .standard
        ),
        MasterShop(
            "Once Upon a Time",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .generalMerchandise, tier: .standard
        ),
        // Rock Around the Shop is Rock 'n' Roller Coaster's confirmed
        // exit-adjacent shop — same building. Coordinate reused from that
        // verified attraction entry.
        MasterShop(
            "Rock Around the Shop",
            park: .hollywoodStudios, land: "Sunset Boulevard",
            category: .attractionMerchandise, tier: .standard,
            map: 3
        ),

        // ── Hollywood Studios — Echo Lake (new land coverage) ────────────
        MasterShop(
            "Tatooine Traders",
            park: .hollywoodStudios, land: "Echo Lake",
            category: .specialty, tier: .standard
            // Pre-Galaxy's Edge Star Wars merchandise shop — a distinct
            // location from the Galaxy's Edge shops below.
        ),
        MasterShop(
            "Frozen Fractal Gifts",
            park: .hollywoodStudios, land: "Echo Lake",
            category: .specialty, tier: .standard
        ),

        // ── Hollywood Studios — Toy Story Land (new land coverage) ───────
        MasterShop(
            "Jessie's Trading Post",
            park: .hollywoodStudios, land: "Toy Story Land",
            category: .generalMerchandise, tier: .standard
        ),

        // ── Hollywood Studios — Star Wars: Galaxy's Edge (additions) ─────
        // Droid Depot and Savi's Workshop are reservation-based,
        // build-your-own experiences ($129.99+ and $274.99+ respectively)
        // that guests specifically plan their visit around — the bar this
        // pilot set for `.destination`, matching Dok-Ondar's above.
        MasterShop(
            "Droid Depot",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .destination,
            editorial: ShoppingMetadata(
                notableFor: "Build-your-own astromech droid experience; reservation strongly recommended.",
                merchandiseFocus: ["Custom droids", "Droid parts", "Star Wars collectibles"]
            )
        ),
        MasterShop(
            "Savi's Workshop - Handbuilt Lightsabers",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .destination,
            editorial: ShoppingMetadata(
                notableFor: "Build-your-own lightsaber workshop experience; reservation required.",
                merchandiseFocus: ["Custom lightsabers", "Kyber crystals"]
            )
        ),
        MasterShop(
            "Black Spire Outfitters",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .generalMerchandise, tier: .standard
            // Star Wars-themed apparel.
        ),
        MasterShop(
            "Creature Stall",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .standard
            // Galactic creature plush and collectibles.
        ),
        MasterShop(
            "First Order Cargo",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .standard
        ),
        MasterShop(
            "Resistance Supply",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .standard
        ),
        MasterShop(
            "Toydarian Toymaker",
            park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
            category: .specialty, tier: .standard
            // Handcrafted toys "by Zabaka the Toydarian."
        ),
    ]

    // MARK: - Lookups (data-architecture support for search/filtering)
    //
    // No dedicated Shopping screen exists yet — these are the minimum
    // additive API surface so a future screen (or the website) can query
    // Shopping without a second database. See Priority 5 report,
    // "App Integration" section, for why this isn't wired into
    // AttractionsListView this phase.

    /// All shops for a given park.
    static func shops(for park: Park) -> [MasterShop] {
        all.filter { $0.park == park }
    }

    /// Shops in a specific land of a park.
    static func shops(for park: Park, land: String) -> [MasterShop] {
        all.filter { $0.park == park && $0.land == land }
    }

    /// Shops matching a shopping category, optionally scoped to a park.
    static func shops(category: ShoppingCategory, park: Park? = nil) -> [MasterShop] {
        all.filter { $0.category == category && (park == nil || $0.park == park) }
    }

    /// Case-insensitive substring search over shop names.
    static func search(_ query: String) -> [MasterShop] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let needle = query.lowercased()
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    /// O(1) stableID lookup — mirrors RideMasterData.typeByStableID's role.
    static let byStableID: [String: MasterShop] = {
        var map = [String: MasterShop](minimumCapacity: all.count)
        for s in all { map[s.stableID] = s }
        return map
    }()
}

// MARK: - DEBUG validation

#if DEBUG
extension ShopMasterData {

    /// Run at app launch (DEBUG only), alongside RideMasterData.validate().
    /// Applies the same class of checks to the Shopping domain rather than
    /// inventing a separate validation pipeline.
    static func validate() {
        var issues = 0

        // ── 1. Duplicate stable IDs within Shopping ─────────────────────
        let ids = all.map(\.stableID)
        let dupIDs = Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }.keys.sorted()
        for id in dupIDs {
            print("⚠️ ShopMasterData: duplicate stableID '\(id)'")
            issues += 1
        }

        // ── 2. Cross-domain stableID collisions ─────────────────────────
        //    Shopping shares the same per-park id namespace as Attractions/
        //    Dining in MapCoordinates.json — a collision there would let one
        //    map entry silently shadow the other.
        let attractionIDs = Set(RideMasterData.all.map(\.stableID))
        let collisions = Set(ids).intersection(attractionIDs).sorted()
        for id in collisions {
            print("⚠️ ShopMasterData: stableID '\(id)' collides with an existing MasterAttraction — Shopping and Attraction/Dining IDs must be unique across domains.")
            issues += 1
        }

        // ── 3. Park / land consistency against Park.lands ───────────────
        for s in all where !s.park.lands.contains(s.land) {
            print("⚠️ ShopMasterData: '\(s.name)' land '\(s.land)' is not in Park.lands for \(s.park.rawValue)")
            issues += 1
        }

        // ── 4. Entity ID coverage (informational — expected to be sparse) ─
        let withEntityId = all.filter { $0.entityId != nil }
        print("ℹ️ ShopMasterData: entity ID coverage \(withEntityId.count)/\(all.count) — ThemeParks.wiki does not track Shopping as an entity type, so this is expected to stay low.")

        // ── 5. Coordinate coverage (informational) ──────────────────────
        let withMap = all.filter { $0.shouldAppearOnMap }
        print("ℹ️ ShopMasterData: coordinate coverage \(withMap.count)/\(all.count) — see per-shop comments in ShopMasterData.all for why the rest are unresolved.")

        if issues == 0 {
            print("✅ ShopMasterData: all \(all.count) shops passed validation (\(withMap.count) map-visible)")
        } else {
            print("⚠️ ShopMasterData: \(issues) issue(s) found — see above")
        }
    }
}
#endif

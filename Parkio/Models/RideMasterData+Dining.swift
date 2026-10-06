// RideMasterData+Dining.swift — Parkio dining catalog MVP.
//
// Architecture
// ────────────
// Each park gets a static [MasterAttraction] array (mkDining, epcotDining, …).
// These are concatenated into RideMasterData.all in RideMasterData.swift so the
// full catalog stays a single flat array — one lookup table for all feature layers.
//
// Seeding
// ───────
// dining: true → RideSeeder inserts a Ride SwiftData record with the stableID.
// No schema migration is required; Ride is type-agnostic by design.
// Type lookup at display time: RideMasterData.typeByStableID[ride.id]
// Dining lookup at display time: RideMasterData.diningByStableID[ride.id]
//
// Coverage goal
// ─────────────
// MVP = 5–10 venues per park, weighted toward:
//   • best quick service (where guests spend most meals)
//   • iconic snacks (the things people specifically plan around)
//   • best value table service (where reservations exist but are worth it)
//
// Map pins
// ────────
// All seeded dining venues have map: 3 (visible when zoomed in).
// Coordinates for MapCoordinates.json must be verified on-device or via Google
// Maps before adding — left out of this pass to avoid wrong pins.
//
// Editorial conventions
// ─────────────────────
// score 9–10 = unmissable; plan your day around it
// score 7–8  = strongly recommended; stop in if nearby
// score 5–6  = solid backup; reliable when others are packed
// shortVerdict ≤ 80 chars; plain language, no marketing phrasing

import Foundation

// MARK: - Type aliases (file-private for catalog readability)

private typealias MA = MasterAttraction
private typealias DM = DiningMetadata

// MARK: - Walt Disney World — Magic Kingdom

extension RideMasterData {

    // 31 venues — reconciled to the full official Magic Kingdom dining directory.
    // Pre-existing venues keep their editorial DiningMetadata. Newly added venues
    // are factual-only (dining: nil) — no editorial score/verdict has been
    // authored for them yet, and none is invented here.
    // "Columbia Harbour House" (formerly in this list) was removed: it is not
    // part of the reconciled 31-venue directory this catalog now tracks.
    static let mkDining: [MasterAttraction] = [

        // ── Main Street, U.S.A. ──────────────────────────────────────────────────
        MA("Tony's Town Square Restaurant",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .tableService, outdoor: false, map: 3, seed: true),

        MA("Main Street Bakery",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: false, map: 3, seed: true),

        MA("The Plaza Restaurant",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .tableService, outdoor: false, map: 3, seed: true),

        MA("Plaza Ice Cream Parlor",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Casey's Corner",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: true, map: 3, seed: true),

        MA("The Crystal Palace",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .tableService, outdoor: false, map: 3, seed: true),

        // ── Adventureland ─────────────────────────────────────────────────────
        MA("Spring Roll Snack Cart",
           park: .magicKingdom, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Sunshine Tree Terrace",
           park: .magicKingdom, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Jungle Navigation Co. LTD Skipper Canteen",
           park: .magicKingdom, land: "Adventureland",
           type: .tableService, outdoor: false, map: 3, seed: true),

        MA("Aloha Isle",
           park: .magicKingdom, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("The Beak and Barrel",
           park: .magicKingdom, land: "Adventureland",
           type: .lounge, outdoor: true, map: 3, seed: true),

        // ── Frontierland ──────────────────────────────────────────────────────
        MA("Golden Oak Outpost",
           park: .magicKingdom, land: "Frontierland",
           type: .quickService, outdoor: true, map: 3, seed: true),

        MA("Pecos Bill Tall Tale Inn and Cafe",
           park: .magicKingdom, land: "Frontierland",
           type: .quickService, outdoor: false, map: 3, seed: true),

        // ── Liberty Square ────────────────────────────────────────────────────
        MA("The Diamond Horseshoe",
           park: .magicKingdom, land: "Liberty Square",
           type: .quickService, outdoor: false, map: 3, seed: true),

        MA("Liberty Tree Tavern",
           park: .magicKingdom, land: "Liberty Square",
           type: .tableService, outdoor: false, map: 3, seed: true),

        MA("Sleepy Hollow",
           park: .magicKingdom, land: "Liberty Square",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 7,
                      verdict: "Grab a fresh funnel cake and eat by the waterfront. Peak afternoon snack.",
                      signature: ["Funnel Cake", "Waffle Sandwich"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly])),

        // ── Fantasyland ───────────────────────────────────────────────────────
        MA("Pinocchio Village Haus",
           park: .magicKingdom, land: "Fantasyland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Watch riders emerge from it's a small world while you eat. Great location.",
                      signature: ["Flatbread Pizza", "Pasta Bolognese"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        MA("Cinderella's Royal Table",
           park: .magicKingdom, land: "Fantasyland",
           type: .tableService, outdoor: false, map: 3, seed: true),

        MA("The Friar's Nook",
           park: .magicKingdom, land: "Fantasyland",
           type: .quickService, outdoor: true, map: 3, seed: true),

        MA("Storybook Treats",
           park: .magicKingdom, land: "Fantasyland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        // Be Our Guest is technically table service at dinner, quick-service at
        // lunch (walk-up). Table service type reflects the stronger use case.
        MA("Be Our Guest Restaurant",
           park: .magicKingdom, land: "Fantasyland",
           type: .tableService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 8,
                      verdict: "The most immersive dining room in MK. Book dinner or walk up for lunch.",
                      signature: ["French Onion Soup", "The Grey Stuff"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        MA("Gaston's Tavern",
           park: .magicKingdom, land: "Fantasyland",
           type: .snackStand, outdoor: false, map: 3, seed: true,
           dining: DM(price: .budget, score: 9,
                      verdict: "Best themed snack in MK. Cinnamon roll is unmissable.",
                      signature: ["LeFou's Brew", "Giant Cinnamon Roll"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly])),

        MA("Prince Eric's Village Market",
           park: .magicKingdom, land: "Fantasyland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Cheshire Café",
           park: .magicKingdom, land: "Fantasyland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Energy Bytes",
           park: .magicKingdom, land: "Tomorrowland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Cosmic Ray's Starlight Café",
           park: .magicKingdom, land: "Tomorrowland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Largest QS in MK. Reliable backup when everywhere else is slammed.",
                      signature: ["Rotisserie Chicken", "Half Pound Burger"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        MA("Auntie Gravity's Galactic Goodies",
           park: .magicKingdom, land: "Tomorrowland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("AstroFizz Hosted by Coca-Cola",
           park: .magicKingdom, land: "Tomorrowland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Joffrey's Coffee & Tea Company",
           park: .magicKingdom, land: "Tomorrowland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("The Lunching Pad",
           park: .magicKingdom, land: "Tomorrowland",
           type: .snackStand, outdoor: true, map: 3, seed: true),

        MA("Fireworks Dessert Parties at Tomorrowland Terrace Restaurant",
           park: .magicKingdom, land: "Tomorrowland",
           type: .tableService, outdoor: true, map: 3, seed: true),
    ]
}

// MARK: - Walt Disney World — EPCOT

extension RideMasterData {

    static let epcotDining: [MasterAttraction] = [

        // ── World Nature ──────────────────────────────────────────────────────
        MA("Sunshine Seasons",
           park: .epcot, land: "World Nature",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best quick service in EPCOT. Massive variety; the salmon is legitimately good.",
                      signature: ["Oak-Grilled Salmon", "Rotisserie Chicken", "Sushi Rolls"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly, .kidsMenu])),

        // ── World Showcase ────────────────────────────────────────────────────
        // Japan pavilion
        MA("Katsura Grill",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best QS in World Showcase. Peaceful garden seating; don't skip the udon.",
                      signature: ["Udon Noodle Bowl", "Gyoza", "Green Tea Soft Serve"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // Morocco pavilion
        MA("Tangierine Café",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "74f13ee5-8e10-41a7-a19d-38e9c9582652",
           dining: DM(price: .moderate, score: 8,
                      verdict: "Underrated gem. Generous portions and the best hummus in any park.",
                      signature: ["Chicken Shawarma Platter", "Hummus & Pita", "Lamb Wrap"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly])),

        // Mexico pavilion
        MA("La Cantina de San Angel",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Lagoon-side QS. The tacos are decent; the view of IllumiNations is the real menu item.",
                      signature: ["Tacos", "Empanadas", "Nachos"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // France pavilion
        MA("Les Halles Boulangerie-Patisserie",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 9,
                      verdict: "Best bakery in any Disney park. The croissants are legitimately excellent.",
                      signature: ["Butter Croissant", "Napoleon Pastry", "Quiche Lorraine"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly])),

        // France pavilion
        MA("L'Artisan des Glaces",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 9,
                      verdict: "Best dessert in EPCOT. The ice cream macaron sandwich is the park's top snack.",
                      signature: ["Ice Cream Macaron Sandwich", "Sorbet"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly])),

        // America pavilion
        MA("Regal Eagle Smokehouse",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "ce284609-9d86-444e-af5a-6c0adb68b0aa",
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid BBQ for a theme park. Large portions; kids love the mac & cheese.",
                      signature: ["St. Louis Ribs", "Pulled Pork Sandwich", "Mac & Cheese"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        // ── World Showcase: Mexico pavilion (Priority 4 — factual-only, no
        // editorial metadata authored yet; see DiningMetadata doc comment) ──
        MA("San Angel Inn Restaurante",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "07263f57-0431-4da2-a8b6-77d2965a6f83"),

        MA("La Hacienda de San Angel",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "5b7cf10a-763b-45ba-9049-87140270826f"),

        MA("La Cava del Tequila",
           park: .epcot, land: "World Showcase",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "736b2e6c-daaf-45c4-ba9e-fb60d7cf92d6"),

        MA("Choza de Margarita",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "419df435-6213-4d65-b0fc-8c0ad8379e11"),

        // ── World Showcase: Norway pavilion ──────────────────────────────
        // Kringla Bakeri og Kafe does not appear in the current ThemeParks.wiki
        // EPCOT entity list — not added; see Unresolved in the implementation report.
        MA("Akershus Royal Banquet Hall",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "eb6a60d7-b354-47a1-a091-0beb11b24188"),

        // ── World Showcase: China pavilion ───────────────────────────────
        // Lotus Blossom Café does not appear in the current ThemeParks.wiki
        // EPCOT entity list — not added; see Unresolved in the implementation report.
        MA("Nine Dragons Restaurant",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "e8dccc86-cfb4-44c3-9a90-e95b88edbd21"),

        // ── World Showcase: Germany pavilion ─────────────────────────────
        MA("Biergarten Restaurant",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "c9e1d1f6-021f-43f2-a14b-3e67f65adbc4"),

        MA("Sommerfest",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "3f3ef6db-69de-418a-8861-f541309cdb01"),

        MA("Karamell-K\u{00FC}che",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           aliases: ["Karamell-Kueche"],
           entityId: "85352291-58dd-4dd9-86d3-cba21cebb684"),

        // ── World Showcase: Italy pavilion ───────────────────────────────
        // Pizza al Taglio shares an identical ThemeParks.wiki coordinate with
        // Tutto Gusto Wine Cellar (same building) — omitted this pass rather
        // than invent a distinct pin; see Unresolved.
        MA("Tutto Italia Ristorante",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "e14e439d-d1aa-4f3a-90e9-60c524bd0b5a"),

        MA("Via Napoli Ristorante e Pizzeria",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "b83b6dc9-9573-4e15-ab00-9ed8a2334770"),

        MA("Tutto Gusto Wine Cellar",
           park: .epcot, land: "World Showcase",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "802b79b0-6491-434d-b4b5-145387d62172"),

        // ── World Showcase: The American Adventure pavilion ──────────────
        // Regal Eagle Smokehouse already existed (see above, Priority 1).
        MA("Fife & Drum Tavern",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "0e673d4b-eee4-4735-ab65-be39bcd28d11"),

        MA("Block & Hans",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "25ec84ef-112f-424d-9fe0-5fc1fa9620a9"),

        // ── World Showcase: Japan pavilion ───────────────────────────────
        // Katsura Grill already existed (see above).
        MA("Teppan Edo",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "17d51899-7d6d-4cd7-93bb-4064a47d501b"),

        MA("Takumi-Tei",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "8410885a-115d-4a5f-9cd5-08d0e659a603"),

        MA("Shiki-Sai: Sushi Izakaya",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "48e7f9f2-ddc3-4ced-8d11-a5cd968085c2"),

        // ── World Showcase: Morocco pavilion ─────────────────────────────
        // Tangierine Café already existed (see above, Priority 1). "Spice Road
        // Table Bar" is the same physical venue as Spice Road Table (identical
        // ThemeParks.wiki coordinate) — not added as a separate entry.
        MA("Spice Road Table",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "dbf4a977-a7b5-41db-a9b7-ecad65f9aa0f"),

        // ── World Showcase: France pavilion ──────────────────────────────
        // Les Halles Boulangerie-Patisserie and L'Artisan des Glaces already
        // existed (see above) but have no verified coordinate in ThemeParks.wiki
        // or elsewhere in this pass — still missing a map pin; see Unresolved.
        // Crêpes À Emporter shares an identical coordinate with La Crêperie de
        // Paris (same building) — omitted this pass; see Unresolved.
        MA("Monsieur Paul",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "93843fb0-ee5a-49c6-91a8-40a042e93865"),

        MA("Chefs de France",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "4807262a-ad16-4d43-a0d7-64b24603ef36"),

        MA("Les Vins des Chefs de France",
           park: .epcot, land: "World Showcase",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "1cf38b60-d075-495b-a92f-5a6a59d9e3db"),

        MA("La Cr\u{00EA}perie de Paris",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           aliases: ["La Creperie de Paris"],
           entityId: "fc64aa10-290f-472e-9fab-4d649f53ab2d"),

        // ── World Showcase: United Kingdom pavilion ──────────────────────
        MA("Rose & Crown Dining Room",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "6ecdbfc8-85c2-436d-893b-6db0f437b74a"),

        MA("Rose & Crown Pub",
           park: .epcot, land: "World Showcase",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "91e9cda9-b39f-4a24-b63e-57bc1ba612f5"),

        MA("UK Beer Cart",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "c63e29ac-f57f-4cd0-b998-799a2849dfa1"),

        MA("Yorkshire County Fish Shop",
           park: .epcot, land: "World Showcase",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "67186665-6756-4c29-9010-6efc222b2d9b"),

        // ── World Showcase: Canada pavilion ──────────────────────────────
        MA("Le Cellier Steakhouse",
           park: .epcot, land: "World Showcase",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "3206e3a6-cbc3-4960-9700-163764bc47d6"),

        MA("La Poutinerie",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "195fac06-ab2f-4655-8af7-b27adcdad54e"),

        // ── World Showcase: Refreshment Outpost (between Germany and China,
        // not tied to a single country pavilion) — Priority 4B ────────────
        MA("Refreshment Outpost",
           park: .epcot, land: "World Showcase",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "58404f45-7e74-4c0c-b037-b903fa1066d2"),

        // ── World Celebration (Priority 4B — factual-only) ────────────────
        MA("Connections Eatery",
           park: .epcot, land: "World Celebration",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "c7444c22-4b35-4a9e-9cca-56ecc05376cc"),

        MA("GEO-82",
           park: .epcot, land: "World Celebration",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "95ab66f4-4e47-4f76-875f-45ae70831e2f"),

        MA("GRAB-N-GOOF",
           park: .epcot, land: "World Celebration",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "302d424d-3c56-40e7-9785-fba2f62e5854"),

        // ── World Discovery (Priority 4B) ─────────────────────────────────
        MA("Space 220 Restaurant",
           park: .epcot, land: "World Discovery",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "b772df79-1fca-4c0a-a2f3-88b22e63e7c3"),

        // Space 220 Lounge shares the exact ThemeParks.wiki coordinate with
        // Space 220 Restaurant (same building, upper-level walk-in lounge vs.
        // main dining room). Placing both at an identical map coordinate would
        // stack two SwiftUI Annotation views on top of each other with no
        // clustering configured in RealMapScreen — the bottom pin becomes
        // fully untappable. Rather than invent a fake offset, this entry is
        // map-ineligible (map: nil) and remains fully valid for search/browse/
        // dining picker. See the Priority 4B report for the full recommendation.
        MA("Space 220 Lounge",
           park: .epcot, land: "World Discovery",
           type: .lounge, outdoor: false, map: nil, seed: true,
           entityId: "15107c34-65a3-473c-aaeb-655b508f529d"),

        // ── World Nature (Priority 4B) ─────────────────────────────────────
        // Coral Reef Restaurant (inside The Seas with Nemo & Friends) is
        // confirmed CLOSED for refurbishment as of this pass, reopening
        // November 4, 2026 per current reporting — intentionally not added;
        // see Unresolved in the implementation report.
        MA("Garden Grill Restaurant",
           park: .epcot, land: "World Nature",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "d4179c4c-eb08-4559-aa7c-f9802fda641b"),
    ]
}

// MARK: - Walt Disney World — Hollywood Studios

extension RideMasterData {

    static let dhsDining: [MasterAttraction] = [

        // ── Hollywood Boulevard ───────────────────────────────────────────────
        // The Hollywood Brown Derby Lounge is the walk-up bar counter of the
        // adjacent signature restaurant — no reservation required.
        MA("The Hollywood Brown Derby Lounge",
           park: .hollywoodStudios, land: "Hollywood Boulevard",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "d2af9650-9f91-45ef-98be-de44b4b44c32",
           dining: DM(price: .upscale, score: 8,
                      verdict: "Walk-up bar bites from a signature restaurant. Order the Cobb salad and grapefruit cake.",
                      signature: ["Cobb Salad", "Grapefruit Cake", "Brown Derby Old Fashioned"],
                      mobileOrder: false, indoor: false, kids: false,
                      dietary: [.vegetarianFriendly])),

        // The Hollywood Brown Derby is the adjacent signature restaurant that the
        // Lounge above shares a building with. Distinct reservation-based experience.
        // Priority 4C — factual-only.
        MA("The Hollywood Brown Derby",
           park: .hollywoodStudios, land: "Hollywood Boulevard",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "917783a5-da9c-4c55-ac51-0ac1f8253131"),

        // ── Echo Lake ─────────────────────────────────────────────────────────
        MA("Backlot Express",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "83edcec8-7ff2-495e-9f61-fe596aa92447",
           dining: DM(price: .budget, score: 6,
                      verdict: "Reliable and fast. Good backup when Woody's Lunch Box line is too long.",
                      signature: ["Cheeseburger", "Chicken Tenders"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        // Priority 4C — factual-only additions.
        MA("50's Prime Time Cafe",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "c600282c-227b-4ffc-b1ee-b5987609ee4f"),

        MA("Hollywood & Vine",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "7bf05bdc-8279-427b-8a6d-50fc62ef31cb"),

        MA("Tune-In Lounge",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "0beccd84-7a6d-454a-94d3-c8a3265e7e8d"),

        MA("Dockside Diner",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "e2e6cccf-acf4-48f4-bbfb-47b712714583"),

        // ── Commissary Lane ───────────────────────────────────────────────────
        // Priority 4C — factual-only.
        MA("ABC Commissary",
           park: .hollywoodStudios, land: "Commissary Lane",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "1ae86482-6627-4229-814d-0f1ccebb20d4"),

        MA("Sci-Fi Dine-In Theater Restaurant",
           park: .hollywoodStudios, land: "Commissary Lane",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "d9dbd260-9e34-406d-abb7-19f9d733e577"),

        // ── Grand Avenue ───────────────────────────────────────────────────────
        // Priority 4C — factual-only.
        MA("BaseLine Tap House",
           park: .hollywoodStudios, land: "Grand Avenue",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "07fc0229-4e50-419a-ba10-0ce07cc54a53"),

        // ── Sunset Boulevard ──────────────────────────────────────────────────
        // Sunset Ranch Market cluster. Priority 4C — factual-only.
        MA("Catalina Eddie's",
           park: .hollywoodStudios, land: "Sunset Boulevard",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "a595b641-4472-4d2b-92b5-5a0e31785193"),

        MA("Fairfax Fare",
           park: .hollywoodStudios, land: "Sunset Boulevard",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "904887b2-82b5-426c-b2b0-0b5d6977ff94"),

        MA("Rosie's All-American Cafe",
           park: .hollywoodStudios, land: "Sunset Boulevard",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "a8804f66-ed5c-4daa-99a1-bcddd2f1fca6"),

        // ── Toy Story Land ────────────────────────────────────────────────────
        MA("Woody's Lunch Box",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "07b8c193-a185-4559-a403-4d950c3b386d",
           dining: DM(price: .budget, score: 9,
                      verdict: "Best quick service in DHS. The totchos are a must; lines move fast.",
                      signature: ["Totchos (Loaded Tater Tots)", "S'more French Toast Sandwich", "Lunch Box Tart"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // Priority 4C — factual-only.
        MA("Roundup Rodeo BBQ",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "7a73a6df-4d33-4648-b3e3-57985f84f0ae"),

        // ── Star Wars: Galaxy's Edge ──────────────────────────────────────────
        MA("Ronto Roasters",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "4ea1129c-749c-4be8-a0f9-9700740213fc",
           dining: DM(price: .moderate, score: 9,
                      verdict: "The Ronto Wrap is the best handheld in any Disney park. Get here early.",
                      signature: ["Ronto Wrap", "Meiloorun Fruit Juice"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        MA("Docking Bay 7 Food and Cargo",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "451855cc-d19e-40c3-838a-33c8fefe4af8",
           dining: DM(price: .moderate, score: 8,
                      verdict: "Most immersive dining in Galaxy's Edge. Food quality punches above QS price.",
                      signature: ["Fried Endorian Tip-Yip", "Smoked Kaadu Ribs", "Outpost Mix"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        MA("Oga's Cantina",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "f020b5e3-d26d-4339-83f9-0f1f858a0e40",
           dining: DM(price: .upscale, score: 9,
                      verdict: "The most fun 45 minutes in WDW. Order the Fuzzy Tauntaun. Book in advance.",
                      signature: ["Fuzzy Tauntaun", "Bespin Fizz", "Blue Milk"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly])),

        // Priority 4C — factual-only.
        MA("Kat Saka's Kettle",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "43891eb1-27bb-429e-b6b9-430b54f57858"),

        MA("Milk Stand",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "6a696644-26ba-496e-8e2b-efbaad615785"),
    ]
}

// MARK: - Walt Disney World — Animal Kingdom

extension RideMasterData {

    // Animal Kingdom parity expansion (2026-10-05): 22 venues added below
    // alongside the original 5. All new venues are factual-only — no
    // DiningMetadata, no invented scores/verdicts/signature items — per
    // Product decision. entityId + map: 3 set only where a coordinate was
    // verified via the ThemeParks.wiki API (see MapCoordinates.json); venues
    // without a verified coordinate have map omitted (no pin expected yet),
    // consistent with the Coverage contract in MapCoordinates.json.
    //
    // Excluded by Product decision: Mr. Kamal's, Royal Anandapur Tea Company
    // (insufficient first-party evidence), Trek Snacks Grab and Go (possible
    // duplicate of Thirsty River Bar & Trek Snacks), Restaurantosaurus,
    // Dino-Bite Snacks, Trilo-Bites (DinoLand U.S.A., closed).
    //
    // Excluded (2026-10-05, resolved): Zuri's Sweet Shop (Africa) — surfaced
    // by the ThemeParks.wiki API during implementation (tagged RESTAURANT
    // there), but Disney's own site lists it under /shops/, not /dining/,
    // and its own page describes it as a confectionery shop. First-party
    // classification wins: this is Shopping, not Dining, so it is not part
    // of this catalog. Resolved by Product review on 2026-10-05 — no
    // further action pending.
    static let akDining: [MasterAttraction] = [

        // ── Discovery Island ──────────────────────────────────────────────────
        MA("Flame Tree Barbecue",
           park: .animalKingdom, land: "Discovery Island",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "6730b8bb-f592-40cd-8e6f-e7788f3f175b",
           dining: DM(price: .moderate, score: 8,
                      verdict: "Beautiful waterfront outdoor seating. Best BBQ in any WDW park.",
                      signature: ["Ribs & Chicken Combo", "Pulled Pork Sandwich", "Baked Beans"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        MA("Tiffins Restaurant",
           park: .animalKingdom, land: "Discovery Island",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "e12fb6d6-0985-44e5-bdd3-65ff74433063",
           dining: DM(price: .upscale, score: 9,
                      verdict: "Best theme park restaurant you've never tried. Signature quality, zero pretension.",
                      signature: ["Pan-Seared Grouper", "Braised Short Rib", "Whole-Fried Sustainable Fish"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly])),

        // factual-only — Product decision 2026-10-05
        MA("Pizzafari",
           park: .animalKingdom, land: "Discovery Island",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "625821c3-5bd2-4c08-b449-257f3c81cbde"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Creature Comforts",
           park: .animalKingdom, land: "Discovery Island",
           type: .quickService, outdoor: false, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Nomad Lounge & Cocktail Bar",
           park: .animalKingdom, land: "Discovery Island",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "f210842b-8c9b-4088-9f48-6284e9ce389a"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Isle of Java",
           park: .animalKingdom, land: "Discovery Island",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Eight Spoon Café",
           park: .animalKingdom, land: "Discovery Island",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("The Smiling Crocodile",
           park: .animalKingdom, land: "Discovery Island",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "9a64300c-4861-4bed-9713-b4f49e55e566"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Terra Treats and Snack Shop",
           park: .animalKingdom, land: "Discovery Island",
           type: .snackStand, outdoor: true, seed: true),

        // ── Africa ────────────────────────────────────────────────────────────
        MA("Harambe Market",
           park: .animalKingdom, land: "Africa",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "665cc4c1-1bcd-4e5e-a44d-adb6a6889abc",
           dining: DM(price: .moderate, score: 7,
                      verdict: "Themed open-air market. Great atmosphere and the grilled corn is addictive.",
                      signature: ["Cheeseburger Kotlet", "Chicken Skewers", "Grilled Corn"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),
        // NOTE (2026-10-05): Harambe Market's menu changed substantially
        // after an Oct 2025–Feb 2026 refurbishment (shifted away from the
        // African-inspired items referenced above). This DiningMetadata is
        // likely stale. Flagged per Product decision 2026-10-05 — NOT
        // rewritten in this gate; requires separate editorial authorization.

        // factual-only — Product decision 2026-10-05
        MA("Tusker House Restaurant",
           park: .animalKingdom, land: "Africa",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "d58db4d0-3bad-4655-937b-1cbc9ed0e880"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Kusafiri Coffee Shop & Bakery",
           park: .animalKingdom, land: "Africa",
           type: .quickService, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Dawa Bar",
           park: .animalKingdom, land: "Africa",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "1286aad3-bdbe-401b-99ef-4097477c556d"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Tamu Tamu Refreshments",
           park: .animalKingdom, land: "Africa",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Harambe Fruit Market",
           park: .animalKingdom, land: "Africa",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Mahindi",
           park: .animalKingdom, land: "Africa",
           type: .snackStand, outdoor: true, seed: true),

        // ── Asia ──────────────────────────────────────────────────────────────
        MA("Yak & Yeti Local Food Cafes",
           park: .animalKingdom, land: "Asia",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Solid counter service for a midday break. Better value than the sit-down next door.",
                      signature: ["Fried Chicken Pot Sticker", "Asian Chicken Sandwich"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),
        // NOTE: no verified ThemeParks.wiki coordinate found for this venue
        // specifically (distinct from "Yak & Yeti Restaurant" below) —
        // existing map: 3 / no-coordinate gap left unchanged, per Product
        // instruction to leave absent coordinates absent rather than guess.

        // factual-only — Product decision 2026-10-05
        MA("Yak & Yeti Restaurant",
           park: .animalKingdom, land: "Asia",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "cea213d9-bf4f-408a-ac61-768e7709ab7d"),

        // factual-only — Product decision 2026-10-05: canonical identity for
        // the Thirsty River / Trek Snacks ambiguity. "Trek Snacks Grab and
        // Go" intentionally NOT added as a separate venue.
        MA("Thirsty River Bar & Trek Snacks",
           park: .animalKingdom, land: "Asia",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "88d5c6ad-fd4a-4c8b-8ed3-656e3ee3a4eb"),

        // factual-only — Product decision 2026-10-05
        MA("Yak & Yeti Quality Beverages",
           park: .animalKingdom, land: "Asia",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "84f51faa-72a3-4491-9449-20a999e5885c"),

        // factual-only — Product decision 2026-10-05 (type: .lounge, per PO)
        MA("Warung Outpost",
           park: .animalKingdom, land: "Asia",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "f609fcf6-0aef-44ef-b838-f10ff3b8543b"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Drinkwallah",
           park: .animalKingdom, land: "Asia",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Caravan Road",
           park: .animalKingdom, land: "Asia",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Anandapur Ice Cream Truck",
           park: .animalKingdom, land: "Asia",
           type: .snackStand, outdoor: true, seed: true),

        // ── Pandora ───────────────────────────────────────────────────────────
        MA("Satu'li Canteen",
           park: .animalKingdom, land: "Pandora",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "7aa4f221-7b52-445e-bc27-f7baac4530ad",
           dining: DM(price: .moderate, score: 9,
                      verdict: "Best quick service in any WDW park. The bowls are fresh, filling, and genuinely good.",
                      signature: ["Cheeseburger Pod", "Vegetable Curry Bowl", "Blue Milk"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly, .kidsMenu])),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Pongu Pongu",
           park: .animalKingdom, land: "Pandora",
           type: .snackStand, outdoor: true, seed: true),

        // ── Main Entrance ─────────────────────────────────────────────────────
        // factual-only — Product decision 2026-10-05: included as an Animal
        // Kingdom Dining venue at its truthful location (Main Entrance, not
        // inside a themed land), per explicit Product instruction.
        MA("Rainforest Cafe at Disney's Animal Kingdom",
           park: .animalKingdom, land: "Main Entrance",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "224d803c-cd7a-45d8-bfab-d843f2030983"),
    ]
}

// MARK: - Disneyland

extension RideMasterData {

    // Disneyland parity expansion (2026-10-05): 28 venues added below alongside
    // the original 7. All new venues are factual-only — no DiningMetadata, no
    // invented scores/verdicts/signature items — per Product decision.
    // entityId + map: 3 set only where a coordinate was verified via the
    // ThemeParks.wiki API; venues without a verified coordinate have map
    // omitted (no pin expected yet), consistent with the Coverage contract in
    // MapCoordinates.json. Alien Pizza Planet and The Tropical Hideaway were
    // matched via ThemeParks.wiki's "...Express" sub-listing for the same
    // physical building (a separate mobile-order-counter entity at that
    // location), not an exact name match — flagged here for future
    // maintainers.
    //
    // Identity corrections approved 2026-10-05:
    //   Hungry Bear Restaurant (Critter Country) → Hungry Bear Barbecue
    //     Jamboree (Bayou Country) — name + land, atomic (see Park.swift).
    //   Tropical Hideaway → The Tropical Hideaway (display-name-only).
    //   Café Orleans → Cafe Orleans (display-name-only).
    //
    // Excluded by Product decision: the six park-wide umbrella cart
    // categories (Churro/Fruit/Lemonade/Popcorn/Pretzel/Turkey Leg Carts —
    // span multiple physical locations, don't map to Park|Land|Name),
    // Fantasmic! Dining Packages and Plaza Inn Dining Package (reservation
    // products on existing kitchens, not separate physical venues),
    // Tomorrowland Skyline Terrace (Disney tags it "Dining Events" like the
    // two packages above, its own page omits a specific land, and it was
    // confirmed temporarily unavailable as of 2026-10-05), Club 33
    // (membership-gated, absent from Disney's public dining directory),
    // Ship to Shore Marketplace and Tropical Imports (absent from Disney's
    // current directory — stale names; South Seas Traders is the real
    // current venue).
    static let disneylandDining: [MasterAttraction] = [

        // ── Main Street, U.S.A. ──────────────────────────────────────────────
        // factual-only — Product decision 2026-10-05
        MA("Carnation Café",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "c7ce633e-1f6b-4699-98c9-6772bb196b16"),

        // factual-only — Product decision 2026-10-05
        MA("Gibson Girl Ice Cream Parlor",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "2215958d-c6b0-4513-912c-706dbf3e46e9"),

        // factual-only — Product decision 2026-10-05
        MA("Jolly Holiday Bakery Cafe",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "d295c224-299f-4fda-9d14-1d7780401929"),

        // factual-only — Product decision 2026-10-05
        MA("Little Red Wagon",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "1cdd0f00-de40-4f7f-bf1b-014926d51aca"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Market House",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: false, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Refreshment Corner",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "27ab9530-4fd5-4e9c-a5b1-d553fed56655"),

        // factual-only — Product decision 2026-10-05
        MA("Plaza Inn",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "8deb6338-b65f-467c-9dd3-56ed8c02c355"),

        // ── Adventureland ─────────────────────────────────────────────────────
        MA("The Tropical Hideaway",
           park: .disneyland, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "3c8d7efa-b0a5-4e2d-811e-9da29d65f2f0",
           dining: DM(price: .budget, score: 9,
                      verdict: "More Dole Whip flavors than the Tiki Bar and almost always a shorter line.",
                      signature: ["Dole Whip", "Coconut Soft Serve", "Tropical Float"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.veganOptions, .vegetarianFriendly, .dairyFree])),
        // NOTE: renamed from "Tropical Hideaway" — Disney's current official
        // name is "The Tropical Hideaway." Display-name-only; stableID
        // changes accordingly (no venueKey existed yet, so no migration cost).

        MA("Bengal Barbecue",
           park: .disneyland, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "7bf706cd-0cf5-4640-a079-23a7a46f4f5b",
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best walk-up snack in Disneyland. Grab a beef skewer while waiting for Indiana Jones.",
                      signature: ["Outback Skewer (Beef)", "Pretzel Bread", "Chicken Skewer"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("South Seas Traders",
           park: .disneyland, land: "Adventureland",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Tiki Juice Bar",
           park: .disneyland, land: "Adventureland",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "c48369cc-e341-4066-96b8-3687ccad1e49"),

        // ── New Orleans Square ────────────────────────────────────────────────
        MA("Blue Bayou Restaurant",
           park: .disneyland, land: "New Orleans Square",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "4784fd0f-9ba3-4a5d-a4b9-ed33b93c4489",
           dining: DM(price: .upscale, score: 9,
                      verdict: "Dine inside Pirates of the Caribbean. The atmosphere alone justifies the ADR.",
                      signature: ["Jambalaya", "Monte Cristo Sandwich", "Bayou Trio"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        MA("Cafe Orleans",
           park: .disneyland, land: "New Orleans Square",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "3665b38e-3e56-4c84-ad20-3e39672079a1",
           dining: DM(price: .upscale, score: 8,
                      verdict: "Better food than Blue Bayou, lower profile. The Monte Cristo is iconic.",
                      signature: ["Monte Cristo Sandwich", "Pommes Frites", "Beignets"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),
        // NOTE: renamed from "Café Orleans" — Disney's current official
        // spelling omits the accent ("Cafe Orleans"). Display-name-only.

        // factual-only — Product decision 2026-10-05
        MA("Harbour Galley",
           park: .disneyland, land: "New Orleans Square",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "92f45ae9-5e6d-4923-88d4-7f676c2d10b2"),

        // factual-only — Product decision 2026-10-05
        MA("Mint Julep Bar",
           park: .disneyland, land: "New Orleans Square",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "2e0d0726-07c7-42f6-b839-68a56a41e268"),

        // factual-only — Product decision 2026-10-05
        MA("Royal Street Veranda",
           park: .disneyland, land: "New Orleans Square",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "d2feb649-41ea-4097-a45b-10cfb48d13aa"),

        // factual-only — Product decision 2026-10-05
        MA("Tiana's Palace",
           park: .disneyland, land: "New Orleans Square",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "f0f57b5c-5bc5-49d6-8b7f-34e4aa03c2e8"),

        // ── Bayou Country ─────────────────────────────────────────────────────
        MA("Hungry Bear Barbecue Jamboree",
           park: .disneyland, land: "Bayou Country",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "fb686e53-e10d-4cd5-836c-7a4a93207361",
           dining: DM(price: .budget, score: 7,
                      verdict: "Hidden gem. Waterfront outdoor seating, consistently short lines, surprisingly good.",
                      signature: ["Funnel Cake Fries", "Fried Chicken Sandwich"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),
        // NOTE: renamed and relocated from "Hungry Bear Restaurant" in
        // "Critter Country" — Disney renamed the land to "Bayou Country" and
        // the venue to "Hungry Bear Barbecue Jamboree" in Oct/Nov 2024. Name
        // + land identity migration, approved 2026-10-05 (no venueKey existed
        // yet, so no cross-repo migration cost). See Park.swift for the
        // corresponding land rename.

        // ── Frontierland ──────────────────────────────────────────────────────
        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("The Golden Horseshoe",
           park: .disneyland, land: "Frontierland",
           type: .quickService, outdoor: false, seed: true),

        MA("Rancho del Zocalo Restaurante",
           park: .disneyland, land: "Frontierland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid Mexican QS with generous portions. Convenient before or after Big Thunder.",
                      signature: ["Carne Asada Plate", "Fish Tacos", "Cheese Enchiladas"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),
        // NOTE: no verified ThemeParks.wiki coordinate found for this venue
        // specifically — existing map: 3 / no-coordinate gap left unchanged,
        // per Product instruction to leave absent coordinates absent.

        // factual-only — Product decision 2026-10-05
        MA("River Belle Terrace",
           park: .disneyland, land: "Frontierland",
           type: .tableService, outdoor: true, map: 3, seed: true,
           entityId: "057872ed-3f27-496f-80e2-edd3639ba084"),

        // factual-only — Product decision 2026-10-05
        MA("Stage Door Café",
           park: .disneyland, land: "Frontierland",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "fae2515c-777b-4f37-b647-06383c1904d3"),

        // ── Fantasyland ───────────────────────────────────────────────────────
        // factual-only — Product decision 2026-10-05
        MA("Edelweiss Snacks",
           park: .disneyland, land: "Fantasyland",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "fbee3a16-4be3-47f3-97a7-70ef09aff088"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Maurice's Treats",
           park: .disneyland, land: "Fantasyland",
           type: .quickService, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Red Rose Taverne",
           park: .disneyland, land: "Fantasyland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "1db8443f-624c-4d95-967c-1766a52b24ec"),

        // factual-only — Product decision 2026-10-05
        MA("Troubadour Tavern",
           park: .disneyland, land: "Fantasyland",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "3a63d923-413a-4512-b873-c690596fb479"),

        // ── Mickey's Toontown ─────────────────────────────────────────────────
        // factual-only — Product decision 2026-10-05
        MA("Café Daisy",
           park: .disneyland, land: "Mickey's Toontown",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "f8d61baa-dc1a-4e82-ab6b-f24bdd83e6e1"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Good Boy! Grocers",
           park: .disneyland, land: "Mickey's Toontown",
           type: .snackStand, outdoor: true, seed: true),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Galactic Grill",
           park: .disneyland, land: "Tomorrowland",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "e88cbd63-e385-423b-9565-fbe5faeb9050",
           dining: DM(price: .budget, score: 6,
                      verdict: "Quick lunch before Space Mountain or Buzz. Nothing special; fast and convenient.",
                      signature: ["Poe's Shakshuka", "Space Tacos", "Cosmic Burger"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // factual-only — Product decision 2026-10-05
        MA("Alien Pizza Planet",
           park: .disneyland, land: "Tomorrowland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "ce05c344-81fc-4b32-8717-cb1c26c65292"),

        // ── Star Wars: Galaxy's Edge ──────────────────────────────────────────
        // factual-only — Product decision 2026-10-05
        MA("Docking Bay 7 Food and Cargo",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "8abfd370-4c29-4154-bb96-41e031b78d29"),

        // factual-only; no verified coordinate — Product decision 2026-10-05
        MA("Kat Saka's Kettle",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-05
        MA("Milk Stand",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "94453dec-3f16-43a6-94c9-be55144606b8"),

        // factual-only — Product decision 2026-10-05
        MA("Oga's Cantina at the Disneyland Resort",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "eb29424b-42ed-41a2-891c-d4c9494eab12"),

        // factual-only — Product decision 2026-10-05
        MA("Ronto Roasters",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "1822fb68-5f64-4329-b7e2-d4065f7159ac"),
    ]
}

// MARK: - Disney California Adventure

extension RideMasterData {

    // DCA six-park-completion expansion (2026-10-06): 32 venues added alongside
    // the original 6, bringing DCA to its approved target of 38. All 32 new
    // venues are factual-only — no DiningMetadata, no invented scores/verdicts
    // — per Product decision, same discipline as the Disneyland expansion.
    // entityId + map: 3 set only where a coordinate was verified via the
    // ThemeParks.wiki API (28 of 38 total, including all 6 pre-existing
    // venues, which previously had none); venues without a verified
    // coordinate have map omitted, per the Coverage contract in
    // MapCoordinates.json. Cozy Cone Motel's entityId references the first of
    // five identically-coordinated ThemeParks.wiki sub-entities ("Cozy Cone
    // Motel 1 - Churros" through "5 - Popcone") — one physical stand exposed
    // as five menu-window entities; treated as a single Parkio identity, not
    // five, matching the Alien Pizza Planet / Tropical Hideaway alias
    // precedent from the Disneyland expansion.
    //
    // Land taxonomy: Park.swift's .californiaAdventure.lands gained exactly
    // two additions this gate — San Fransokyo Square and Performance
    // Corridor — both pure additions (no rename, no removal); see Park.swift.
    //
    // Product decisions approved 2026-10-06:
    //   Magic Key Terrace - Magic Key Holder Dining — INCLUDE. Real permanent
    //     physical venue (Performance Corridor), first-party verified; the
    //     Magic Key access restriction does not make the physical venue
    //     cease to exist. Modeled with its exact current Disney name; the
    //     access restriction itself is not modeled as metadata this gate.
    //   Lamplight Lounge - Boardwalk Dining — EXCLUDED as a separate
    //     identity. Same building as Lamplight Lounge (confirmed via
    //     identical ThemeParks.wiki coordinates); represented entirely
    //     through the single existing Lamplight Lounge identity below.
    //
    // Excluded by Product decision: Boudin Bread Cart (no retrievable
    // first-party page, land not first-party verifiable, cart-class
    // identity); the six park-wide umbrella cart categories (Churro/Fruit/
    // Lemonade/Popcorn/Pretzel/Turkey Leg Carts — span multiple physical
    // locations, don't map to Park|Land|Name); three seasonal marketplaces
    // (Festive Food Marketplace, Food & Wine Festival Marketplaces, Lunar
    // New Year Marketplaces — temporary/multi-location, not permanent fixed
    // venues); four reservation/dining products (Oogie Boogie Bash Dessert
    // Party, Sip and Savor Pass, World of Color Dessert Party, World of
    // Color Dining Package — ticketed experiences/packages layered on
    // existing kitchens, not separate physical venues).
    static let dcaDining: [MasterAttraction] = [

        // ── Avengers Campus ───────────────────────────────────────────────────
        MA("Pym Test Kitchen",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "bbfe672e-075a-477a-b066-1117cf80030c",
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best themed QS in DCA. The Pym-ini is a solid sandwich with great presentation.",
                      signature: ["Pym-ini Sandwich", "Not So Little Chicken Sandwich", "Cosmic Cream Orange Cake"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // factual-only — Product decision 2026-10-06
        MA("Pym Tasting Lab",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "ca4b4068-02a7-4d98-92a6-f781ad5711d3"),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Shawarma Palace",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .quickService, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Terran Treats",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .quickService, outdoor: true, seed: true),

        // ── Cars Land ─────────────────────────────────────────────────────────
        MA("Flo's V8 Café",
           park: .californiaAdventure, land: "Cars Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "85201274-b743-41ca-95a1-d575a07811d0",
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid QS with great Cars Land theming. Best seat is outside near the fountain.",
                      signature: ["Radiator Springs Rotisserie Chicken", "Chili Mac", "Flo's Float"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // factual-only — Product decision 2026-10-06; entityId references the
        // first of five identically-coordinated ThemeParks.wiki sub-entities
        // ("Cozy Cone Motel 1 - Churros" .. "5 - Popcone") — one physical
        // stand, five menu windows, treated as a single identity.
        MA("Cozy Cone Motel",
           park: .californiaAdventure, land: "Cars Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "7025ea53-9d7f-4e7f-a0ad-0ea9523c3c01"),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Fillmore's Taste-In",
           park: .californiaAdventure, land: "Cars Land",
           type: .snackStand, outdoor: true, seed: true),

        // ── Pixar Pier ────────────────────────────────────────────────────────
        MA("Lamplight Lounge",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "1214912c-de6d-4493-9344-c245357f7af6",
           dining: DM(price: .upscale, score: 9,
                      verdict: "Best restaurant in DCA. Walk-up bar menu rivals the full reservation experience.",
                      signature: ["Lobster Nachos", "Pixar Short Rib Toast", "Passion Fruit Old Fashioned"],
                      mobileOrder: false, indoor: true, kids: false,
                      dietary: [.vegetarianFriendly])),

        MA("Adorable Snowman Frosted Treats",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "e8d7db35-0bc1-42e4-9e6b-a0bc7edbafb1",
           dining: DM(price: .budget, score: 8,
                      verdict: "Best soft serve in DCA. The lemon flavor is bright and weirdly refreshing.",
                      signature: ["Lemon Soft Serve", "Citrus Float"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .veganOptions])),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Angry Dogs",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Jack-Jack Cookie Num Nums",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Poultry Palace",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .quickService, outdoor: true, seed: true),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Señor Buzz Churros",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .snackStand, outdoor: true, seed: true),

        // ── Paradise Gardens Park ─────────────────────────────────────────────
        MA("Corn Dog Castle",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "c4034870-5e87-4514-832f-9da5506f9cf9",
           dining: DM(price: .budget, score: 9,
                      verdict: "One of the best corn dogs on the West Coast. The Monte Cristo version is spectacular.",
                      signature: ["Classic Hand-Dipped Corn Dog", "Monte Cristo Corn Dog"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // factual-only — Product decision 2026-10-06
        MA("Boardwalk Pizza & Pasta",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "0ccdca1c-2e60-4f7c-8395-2adce67e34ba"),

        // factual-only — Product decision 2026-10-06
        MA("Paradise Garden Grill",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "f7ff4406-5bd6-4067-9ed1-92ea1efdcc63"),

        // factual-only — Product decision 2026-10-06
        MA("Bayside Brews",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "2f9b48bb-ad41-44e6-be57-82e62d154b0e"),

        // ── Grizzly Peak ──────────────────────────────────────────────────────
        MA("Smokejumpers Grill",
           park: .californiaAdventure, land: "Grizzly Peak",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "5cd413b8-09da-4860-bdea-a88df9fe6c0d",
           dining: DM(price: .budget, score: 6,
                      verdict: "Reliable burgers near Grizzly River Run. Good spot to eat while your clothes dry.",
                      signature: ["Smokejumper Burger", "Pulled Pork Sandwich"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        // ── Buena Vista Street ────────────────────────────────────────────────
        // factual-only — Product decision 2026-10-06
        MA("Carthay Circle Restaurant",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "753b558a-ff18-4ed9-a3c2-70e76b421618"),

        // factual-only — Product decision 2026-10-06
        MA("Carthay Circle Lounge",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "1bef32e2-73b4-4de3-bb07-f71c3f301f22"),

        // factual-only — Product decision 2026-10-06
        MA("Clarabelle's Hand-Scooped Ice Cream",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .snackStand, outdoor: false, map: 3, seed: true,
           entityId: "40217671-2e04-467b-b462-10d97fbca69d"),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Fiddler, Fifer & Practical Cafe",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .quickService, outdoor: false, seed: true),

        // ── Hollywood Land ────────────────────────────────────────────────────
        // factual-only — Product decision 2026-10-06
        MA("Award Wieners",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "13dbf6c5-2118-4e2a-8609-a3600bf17d1f"),

        // factual-only — Product decision 2026-10-06
        MA("Studio Catering Co.",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "ceb71f40-b730-4209-80be-ef89c114dfdf"),

        // factual-only — Product decision 2026-10-06
        MA("Hollywood Lounge",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "8c153230-8203-4351-bc5a-485a67527b55"),

        // factual-only; no verified coordinate — Product decision 2026-10-06
        MA("Fairfax Market",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .snackStand, outdoor: true, seed: true),

        // factual-only — Product decision 2026-10-06
        MA("Schmoozies!",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "167199e4-933e-4647-9154-75b13975eea3"),

        // ── San Fransokyo Square ──────────────────────────────────────────────
        // factual-only — Product decision 2026-10-06
        MA("Ghirardelli® Soda Fountain and Chocolate Shop",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .quickService, outdoor: false, seed: true),
        // NOTE: no verified ThemeParks.wiki coordinate found for this venue —
        // left without a pin, per Product instruction to leave absent
        // coordinates absent rather than approximate.

        // factual-only — Product decision 2026-10-06
        MA("Cocina Cucamonga Mexican Grill",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "33be9d07-5da1-42b4-a8bb-2486209693bc"),

        // factual-only — Product decision 2026-10-06
        MA("Lucky Fortune Cookery",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "38df151c-f563-406f-8dbc-7e824c7afc75"),

        // factual-only — Product decision 2026-10-06
        MA("Aunt Cass Café",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .quickService, outdoor: false, map: 3, seed: true,
           entityId: "778f814e-7113-4599-adce-b598a39d6cd9"),

        // factual-only — Product decision 2026-10-06
        MA("Port of San Fransokyo Cervecería",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .lounge, outdoor: false, map: 3, seed: true,
           entityId: "884a2e75-ef8a-4676-b65c-67320e732bb1"),

        // factual-only — Product decision 2026-10-06
        MA("Rita's Turbine Blenders",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "431e008b-505c-42fd-9db1-a2e4d5feae78"),

        // factual-only — Product decision 2026-10-06
        MA("Cappuccino Cart",
           park: .californiaAdventure, land: "San Fransokyo Square",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           entityId: "0eefcad3-0b3f-4cb9-b91a-9d493af7222a"),

        // ── Performance Corridor ──────────────────────────────────────────────
        // factual-only — Product decision 2026-10-06
        MA("Wine Country Trattoria",
           park: .californiaAdventure, land: "Performance Corridor",
           type: .tableService, outdoor: false, map: 3, seed: true,
           entityId: "048f854a-97d8-4295-8b7f-2575605259c6"),

        // factual-only — Product decision 2026-10-06
        MA("Sonoma Terrace",
           park: .californiaAdventure, land: "Performance Corridor",
           type: .quickService, outdoor: true, map: 3, seed: true,
           entityId: "13bc1b70-3a42-41eb-9cb5-7fa8615af2ca"),

        // factual-only — Product decision 2026-10-06
        MA("Mendocino Terrace",
           park: .californiaAdventure, land: "Performance Corridor",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "4ff553fa-008a-4d99-b6b0-30dd69d3453f"),

        // factual-only — Product decision 2026-10-06; Magic Key access
        // restriction is a real-world constraint, not modeled as metadata
        // this gate — see Product decision note above.
        MA("Magic Key Terrace - Magic Key Holder Dining",
           park: .californiaAdventure, land: "Performance Corridor",
           type: .lounge, outdoor: true, map: 3, seed: true,
           entityId: "a098bd7c-f1a9-4ffb-97db-e85925509f19"),
    ]
}

// MARK: - Dining convenience lookups (extend RideMasterData)

extension RideMasterData {

    /// O(1) dining metadata lookup by stableID. Returns nil for non-dining attractions.
    static let diningByStableID: [String: DiningMetadata] = {
        var map = [String: DiningMetadata](minimumCapacity: 64)
        for a in all { if let d = a.dining { map[a.stableID] = d } }
        return map
    }()

    /// All seeded dining venues, sorted by parkioScore descending.
    static var topDining: [MasterAttraction] {
        all.filter { $0.shouldAppearInDiningPicker }
           .sorted { ($0.dining?.parkioScore ?? 0) > ($1.dining?.parkioScore ?? 0) }
    }

    /// Seeded dining venues for a specific park, sorted by parkioScore descending.
    static func topDining(for park: Park) -> [MasterAttraction] {
        all.filter { $0.park == park && $0.shouldAppearInDiningPicker }
           .sorted { ($0.dining?.parkioScore ?? 0) > ($1.dining?.parkioScore ?? 0) }
    }
}

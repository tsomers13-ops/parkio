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

    static let mkDining: [MasterAttraction] = [

        // ── Fantasyland ───────────────────────────────────────────────────────
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

        MA("Pinocchio Village Haus",
           park: .magicKingdom, land: "Fantasyland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Watch riders emerge from it's a small world while you eat. Great location.",
                      signature: ["Flatbread Pizza", "Pasta Bolognese"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Liberty Square ────────────────────────────────────────────────────
        MA("Columbia Harbour House",
           park: .magicKingdom, land: "Liberty Square",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best quick service in MK. Quiet upstairs seating, solid seafood.",
                      signature: ["Clam Chowder in a Bread Bowl", "Lobster Roll"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        MA("Sleepy Hollow",
           park: .magicKingdom, land: "Liberty Square",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 7,
                      verdict: "Grab a fresh funnel cake and eat by the waterfront. Peak afternoon snack.",
                      signature: ["Funnel Cake", "Waffle Sandwich"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly])),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Cosmic Ray's Starlight Café",
           park: .magicKingdom, land: "Tomorrowland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Largest QS in MK. Reliable backup when everywhere else is slammed.",
                      signature: ["Rotisserie Chicken", "Half Pound Burger"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),
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

    static let akDining: [MasterAttraction] = [

        // ── Discovery Island ──────────────────────────────────────────────────
        MA("Flame Tree Barbecue",
           park: .animalKingdom, land: "Discovery Island",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Beautiful waterfront outdoor seating. Best BBQ in any WDW park.",
                      signature: ["Ribs & Chicken Combo", "Pulled Pork Sandwich", "Baked Beans"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        MA("Tiffins Restaurant",
           park: .animalKingdom, land: "Discovery Island",
           type: .tableService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 9,
                      verdict: "Best theme park restaurant you've never tried. Signature quality, zero pretension.",
                      signature: ["Pan-Seared Grouper", "Braised Short Rib", "Whole-Fried Sustainable Fish"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly])),

        // ── Africa ────────────────────────────────────────────────────────────
        MA("Harambe Market",
           park: .animalKingdom, land: "Africa",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Themed open-air market. Great atmosphere and the grilled corn is addictive.",
                      signature: ["Cheeseburger Kotlet", "Chicken Skewers", "Grilled Corn"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Asia ──────────────────────────────────────────────────────────────
        MA("Yak & Yeti Local Food Cafes",
           park: .animalKingdom, land: "Asia",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Solid counter service for a midday break. Better value than the sit-down next door.",
                      signature: ["Fried Chicken Pot Sticker", "Asian Chicken Sandwich"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // ── Pandora ───────────────────────────────────────────────────────────
        MA("Satu'li Canteen",
           park: .animalKingdom, land: "Pandora",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 9,
                      verdict: "Best quick service in any WDW park. The bowls are fresh, filling, and genuinely good.",
                      signature: ["Cheeseburger Pod", "Vegetable Curry Bowl", "Blue Milk"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .glutenFriendly, .kidsMenu])),
    ]
}

// MARK: - Disneyland

extension RideMasterData {

    static let disneylandDining: [MasterAttraction] = [

        // ── Adventureland ─────────────────────────────────────────────────────
        MA("Tropical Hideaway",
           park: .disneyland, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 9,
                      verdict: "More Dole Whip flavors than the Tiki Bar and almost always a shorter line.",
                      signature: ["Dole Whip", "Coconut Soft Serve", "Tropical Float"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.veganOptions, .vegetarianFriendly, .dairyFree])),

        MA("Bengal Barbecue",
           park: .disneyland, land: "Adventureland",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best walk-up snack in Disneyland. Grab a beef skewer while waiting for Indiana Jones.",
                      signature: ["Outback Skewer (Beef)", "Pretzel Bread", "Chicken Skewer"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // ── New Orleans Square ────────────────────────────────────────────────
        MA("Blue Bayou Restaurant",
           park: .disneyland, land: "New Orleans Square",
           type: .tableService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 9,
                      verdict: "Dine inside Pirates of the Caribbean. The atmosphere alone justifies the ADR.",
                      signature: ["Jambalaya", "Monte Cristo Sandwich", "Bayou Trio"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        MA("Café Orleans",
           park: .disneyland, land: "New Orleans Square",
           type: .tableService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 8,
                      verdict: "Better food than Blue Bayou, lower profile. The Monte Cristo is iconic.",
                      signature: ["Monte Cristo Sandwich", "Pommes Frites", "Beignets"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Critter Country ───────────────────────────────────────────────────
        MA("Hungry Bear Restaurant",
           park: .disneyland, land: "Critter Country",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 7,
                      verdict: "Hidden gem. Waterfront outdoor seating, consistently short lines, surprisingly good.",
                      signature: ["Funnel Cake Fries", "Fried Chicken Sandwich"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // ── Frontierland ──────────────────────────────────────────────────────
        MA("Rancho del Zocalo Restaurante",
           park: .disneyland, land: "Frontierland",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid Mexican QS with generous portions. Convenient before or after Big Thunder.",
                      signature: ["Carne Asada Plate", "Fish Tacos", "Cheese Enchiladas"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Galactic Grill",
           park: .disneyland, land: "Tomorrowland",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Quick lunch before Space Mountain or Buzz. Nothing special; fast and convenient.",
                      signature: ["Poe's Shakshuka", "Space Tacos", "Cosmic Burger"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),
    ]
}

// MARK: - Disney California Adventure

extension RideMasterData {

    static let dcaDining: [MasterAttraction] = [

        // ── Avengers Campus ───────────────────────────────────────────────────
        MA("Pym Test Kitchen",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Best themed QS in DCA. The Pym-ini is a solid sandwich with great presentation.",
                      signature: ["Pym-ini Sandwich", "Not So Little Chicken Sandwich", "Cosmic Cream Orange Cake"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Cars Land ─────────────────────────────────────────────────────────
        MA("Flo's V8 Café",
           park: .californiaAdventure, land: "Cars Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid QS with great Cars Land theming. Best seat is outside near the fountain.",
                      signature: ["Radiator Springs Rotisserie Chicken", "Chili Mac", "Flo's Float"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Pixar Pier ────────────────────────────────────────────────────────
        MA("Lamplight Lounge",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .lounge, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 9,
                      verdict: "Best restaurant in DCA. Walk-up bar menu rivals the full reservation experience.",
                      signature: ["Lobster Nachos", "Pixar Short Rib Toast", "Passion Fruit Old Fashioned"],
                      mobileOrder: false, indoor: true, kids: false,
                      dietary: [.vegetarianFriendly])),

        MA("Adorable Snowman Frosted Treats",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 8,
                      verdict: "Best soft serve in DCA. The lemon flavor is bright and weirdly refreshing.",
                      signature: ["Lemon Soft Serve", "Citrus Float"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .veganOptions])),

        // ── Paradise Gardens Park ─────────────────────────────────────────────
        MA("Corn Dog Castle",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .snackStand, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 9,
                      verdict: "One of the best corn dogs on the West Coast. The Monte Cristo version is spectacular.",
                      signature: ["Classic Hand-Dipped Corn Dog", "Monte Cristo Corn Dog"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        // ── Grizzly Peak ──────────────────────────────────────────────────────
        MA("Smokejumpers Grill",
           park: .californiaAdventure, land: "Grizzly Peak",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Reliable burgers near Grizzly River Run. Good spot to eat while your clothes dry.",
                      signature: ["Smokejumper Burger", "Pulled Pork Sandwich"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),
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

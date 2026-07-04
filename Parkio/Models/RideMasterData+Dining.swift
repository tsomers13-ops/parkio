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
           dining: DM(price: .moderate, score: 7,
                      verdict: "Solid BBQ for a theme park. Large portions; kids love the mac & cheese.",
                      signature: ["St. Louis Ribs", "Pulled Pork Sandwich", "Mac & Cheese"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),
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
           dining: DM(price: .upscale, score: 8,
                      verdict: "Walk-up bar bites from a signature restaurant. Order the Cobb salad and grapefruit cake.",
                      signature: ["Cobb Salad", "Grapefruit Cake", "Brown Derby Old Fashioned"],
                      mobileOrder: false, indoor: false, kids: false,
                      dietary: [.vegetarianFriendly])),

        // ── Echo Lake ─────────────────────────────────────────────────────────
        MA("Backlot Express",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .budget, score: 6,
                      verdict: "Reliable and fast. Good backup when Woody's Lunch Box line is too long.",
                      signature: ["Cheeseburger", "Chicken Tenders"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        // ── Toy Story Land ────────────────────────────────────────────────────
        MA("Woody's Lunch Box",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .budget, score: 9,
                      verdict: "Best quick service in DHS. The totchos are a must; lines move fast.",
                      signature: ["Totchos (Loaded Tater Tots)", "S'more French Toast Sandwich", "Lunch Box Tart"],
                      mobileOrder: true, indoor: false, kids: true,
                      dietary: [.vegetarianFriendly, .kidsMenu])),

        // ── Star Wars: Galaxy's Edge ──────────────────────────────────────────
        MA("Ronto Roasters",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: true, map: 3, seed: true,
           dining: DM(price: .moderate, score: 9,
                      verdict: "The Ronto Wrap is the best handheld in any Disney park. Get here early.",
                      signature: ["Ronto Wrap", "Meiloorun Fruit Juice"],
                      mobileOrder: false, indoor: false, kids: true,
                      dietary: [.kidsMenu])),

        MA("Docking Bay 7 Food and Cargo",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .quickService, outdoor: false, map: 3, seed: true,
           dining: DM(price: .moderate, score: 8,
                      verdict: "Most immersive dining in Galaxy's Edge. Food quality punches above QS price.",
                      signature: ["Fried Endorian Tip-Yip", "Smoked Kaadu Ribs", "Outpost Mix"],
                      mobileOrder: true, indoor: true, kids: true,
                      dietary: [.kidsMenu])),

        MA("Oga's Cantina",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .lounge, outdoor: false, map: 3, seed: true,
           dining: DM(price: .upscale, score: 9,
                      verdict: "The most fun 45 minutes in WDW. Order the Fuzzy Tauntaun. Book in advance.",
                      signature: ["Fuzzy Tauntaun", "Bespin Fizz", "Blue Milk"],
                      mobileOrder: false, indoor: true, kids: true,
                      dietary: [.vegetarianFriendly])),
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

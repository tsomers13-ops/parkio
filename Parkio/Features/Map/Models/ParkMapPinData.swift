// ParkMapPinData.swift — Embedded normalized (0–1) pin position data for the
// custom park map canvas.
//
// Positions are starter estimates calibrated to each park's general layout,
// except Magic Kingdom, which is calibrated to the numbered directory markers
// on the real magic_kingdom_map artwork (see docs/MK-MAP-PROVENANCE.md).
// Use ParkMapViewModel.debugMode = true to see the calibration overlay.
//
// Deliberately Foundation/CoreGraphics-only (no SwiftUI, no UIKit) so every
// pin — including all 31 Magic Kingdom dining pins — is directly unit
// testable via `swift test` without dragging in the view layer.

import CoreGraphics

enum ParkMapPinData {

    /// Convenience factory — reduces boilerplate in the embedded datasets below.
    static func pin(
        _ rideId: String,
        _ parkId: String,
        _ name: String,
        x: Double, y: Double,
        vx: CGFloat = 0, vy: CGFloat = 0,
        lx: CGFloat = 0, ly: CGFloat = -18,
        anchor: PinAnchorType = .bottomCenter,
        priority: Int = 2
    ) -> ParkMapPin {
        ParkMapPin(
            internalRideId: rideId,
            parkId: parkId,
            displayName: name,
            mapX: x, mapY: y,
            visualOffsetX: vx, visualOffsetY: vy,
            labelOffsetX: lx, labelOffsetY: ly,
            anchorType: anchor,
            priority: priority
        )
    }

    static let embeddedPins: [String: [ParkMapPin]] = [
        "magic-kingdom":      magicKingdomPins,
        "epcot":              epcotPins,
        "hollywood-studios":  hollywoodStudiosPins,
        "animal-kingdom":     animalKingdomPins,
        "disneyland":         disneylandPins,
        "california-adventure": californiaAdventurePins,
    ]

    // MARK: Magic Kingdom

    // Calibrated to numbered directory markers on magic_kingdom_map (see
    // docs/MK-MAP-PROVENANCE.md). "mk|liberty-belle" has no numbered marker
    // on the current official map and keeps its prior general-layout estimate.
    static let magicKingdomPins: [ParkMapPin] = [
        // Tomorrowland (east)
        pin("mk|tron",            "magic-kingdom", "TRON Lightcycle / Run",        x: 0.905, y: 0.285, priority: 1),
        pin("mk|space-mountain",  "magic-kingdom", "Space Mountain",               x: 0.944, y: 0.451, priority: 1),
        pin("mk|buzz",            "magic-kingdom", "Buzz Lightyear",               x: 0.767, y: 0.535, priority: 2),
        pin("mk|astro-orbiter",   "magic-kingdom", "Astro Orbiter",                x: 0.871, y: 0.517, priority: 3),
        pin("mk|speedway",        "magic-kingdom", "Tomorrowland Speedway",        x: 0.784, y: 0.394, priority: 3),
        // Fantasyland (north center)
        pin("mk|seven-dwarfs",    "magic-kingdom", "Seven Dwarfs Mine Train",      x: 0.638, y: 0.232, priority: 1),
        pin("mk|peter-pan",       "magic-kingdom", "Peter Pan's Flight",           x: 0.448, y: 0.259, priority: 1),
        pin("mk|small-world",     "magic-kingdom", "it's a small world",           x: 0.461, y: 0.206, priority: 2),
        pin("mk|winnie-the-pooh", "magic-kingdom", "Winnie the Pooh",              x: 0.647, y: 0.272, priority: 2),
        pin("mk|little-mermaid",  "magic-kingdom", "Little Mermaid",               x: 0.690, y: 0.140, priority: 2),
        pin("mk|dumbo",           "magic-kingdom", "Dumbo",                        x: 0.875, y: 0.193, priority: 3),
        pin("mk|mad-tea-party",   "magic-kingdom", "Mad Tea Party",                x: 0.668, y: 0.285, priority: 3),
        // Liberty Square / Frontierland (west center)
        pin("mk|haunted-mansion", "magic-kingdom", "Haunted Mansion",              x: 0.323, y: 0.263, priority: 1),
        pin("mk|liberty-belle",   "magic-kingdom", "Liberty Belle Riverboat",      x: 0.34, y: 0.49, priority: 3),
        pin("mk|big-thunder",     "magic-kingdom", "Big Thunder Mountain",         x: 0.103, y: 0.329, priority: 1),
        pin("mk|tiana",           "magic-kingdom", "Tiana's Bayou Adventure",      x: 0.078, y: 0.364, priority: 1),
        // Adventureland (southwest)
        pin("mk|pirates",         "magic-kingdom", "Pirates of the Caribbean",     x: 0.153, y: 0.578, priority: 1),
        pin("mk|jungle-cruise",   "magic-kingdom", "Jungle Cruise",                x: 0.250, y: 0.587, priority: 2),
        pin("mk|magic-carpets",   "magic-kingdom", "Magic Carpets of Aladdin",     x: 0.246, y: 0.539, priority: 3),
        // Transport
        pin("mk|wdw-railroad",    "magic-kingdom", "WDW Railroad",                 x: 0.517, y: 0.802, priority: 3),

        // ── Dining — calibrated to numbered directory markers on magic_kingdom_map ──
        // Main Street, U.S.A.
        pin("mk|dining|tonys-town-square",        "magic-kingdom", "Tony's Town Square Restaurant",                     x: 0.578, y: 0.745, priority: 2),
        pin("mk|dining|main-street-bakery",       "magic-kingdom", "Main Street Bakery",                                x: 0.526, y: 0.605, priority: 2),
        pin("mk|dining|plaza-restaurant",         "magic-kingdom", "The Plaza Restaurant",                              x: 0.578, y: 0.570, priority: 2),
        pin("mk|dining|plaza-ice-cream-parlor",   "magic-kingdom", "Plaza Ice Cream Parlor",                            x: 0.547, y: 0.570, priority: 3),
        pin("mk|dining|caseys-corner",            "magic-kingdom", "Casey's Corner",                                    x: 0.509, y: 0.570, priority: 2),
        pin("mk|dining|crystal-palace",           "magic-kingdom", "The Crystal Palace",                                x: 0.448, y: 0.570, priority: 2),
        // Adventureland
        pin("mk|dining|spring-roll-cart",         "magic-kingdom", "Spring Roll Snack Cart",                            x: 0.414, y: 0.500, priority: 3),
        pin("mk|dining|sunshine-tree-terrace",    "magic-kingdom", "Sunshine Tree Terrace",                             x: 0.397, y: 0.513, priority: 3),
        pin("mk|dining|skipper-canteen",          "magic-kingdom", "Jungle Navigation Co. LTD Skipper Canteen",         x: 0.362, y: 0.513, priority: 2),
        pin("mk|dining|aloha-isle",               "magic-kingdom", "Aloha Isle",                                       x: 0.224, y: 0.508, priority: 2),
        pin("mk|dining|beak-and-barrel",          "magic-kingdom", "The Beak and Barrel",                               x: 0.134, y: 0.578, priority: 3),
        // Frontierland
        pin("mk|dining|golden-oak-outpost",       "magic-kingdom", "Golden Oak Outpost",                                x: 0.082, y: 0.495, priority: 3),
        pin("mk|dining|pecos-bill",               "magic-kingdom", "Pecos Bill Tall Tale Inn and Cafe",                 x: 0.177, y: 0.478, priority: 2),
        // Liberty Square
        pin("mk|dining|diamond-horseshoe",        "magic-kingdom", "The Diamond Horseshoe",                             x: 0.315, y: 0.465, priority: 3),
        pin("mk|dining|liberty-tree-tavern",      "magic-kingdom", "Liberty Tree Tavern",                               x: 0.358, y: 0.430, priority: 2),
        pin("mk|dining|sleepy-hollow",            "magic-kingdom", "Sleepy Hollow",                                     x: 0.427, y: 0.377, priority: 3),
        // Fantasyland
        pin("mk|dining|pinocchio-village-haus",   "magic-kingdom", "Pinocchio Village Haus",                            x: 0.513, y: 0.219, priority: 2),
        pin("mk|dining|cinderellas-royal-table",  "magic-kingdom", "Cinderella's Royal Table",                          x: 0.517, y: 0.307, priority: 1),
        pin("mk|dining|friars-nook",              "magic-kingdom", "The Friar's Nook",                                  x: 0.569, y: 0.263, priority: 3),
        pin("mk|dining|storybook-treats",         "magic-kingdom", "Storybook Treats",                                  x: 0.586, y: 0.263, priority: 3),
        pin("mk|dining|be-our-guest",             "magic-kingdom", "Be Our Guest Restaurant",                           x: 0.616, y: 0.131, priority: 1),
        pin("mk|dining|gastons-tavern",           "magic-kingdom", "Gaston's Tavern",                                   x: 0.638, y: 0.092, priority: 2),
        pin("mk|dining|prince-erics-village-market", "magic-kingdom", "Prince Eric's Village Market",                   x: 0.703, y: 0.180, priority: 3),
        pin("mk|dining|cheshire-cafe",            "magic-kingdom", "Cheshire Café",                                     x: 0.651, y: 0.316, priority: 3),
        // Tomorrowland
        pin("mk|dining|energy-bytes",             "magic-kingdom", "Energy Bytes",                                      x: 0.875, y: 0.311, priority: 3),
        pin("mk|dining|cosmic-rays",              "magic-kingdom", "Cosmic Ray's Starlight Café",                       x: 0.694, y: 0.377, priority: 2),
        pin("mk|dining|auntie-gravitys",          "magic-kingdom", "Auntie Gravity's Galactic Goodies",                 x: 0.780, y: 0.456, priority: 3),
        pin("mk|dining|astrofizz",                "magic-kingdom", "AstroFizz Hosted by Coca-Cola",                     x: 0.849, y: 0.465, priority: 3),
        pin("mk|dining|joffreys",                 "magic-kingdom", "Joffrey's Coffee & Tea Company",                    x: 0.910, y: 0.508, priority: 3),
        pin("mk|dining|lunching-pad",             "magic-kingdom", "The Lunching Pad",                                  x: 0.780, y: 0.504, priority: 3),
        pin("mk|dining|tomorrowland-terrace-dessert-party", "magic-kingdom", "Fireworks Dessert Parties at Tomorrowland Terrace Restaurant", x: 0.629, y: 0.565, priority: 3),
    ]

    // MARK: EPCOT
    //
    // World Showcase dining is laid out along the ep-ws-south composition arc
    // (ParkCompositions.swift) in real-world clockwise pavilion order starting
    // from the entrance: Mexico, Norway, China, Germany, Italy, America, Japan,
    // Morocco, France, United Kingdom, Canada — 11 evenly-spaced pavilion
    // anchors (x: 0.08...0.90), each venue clustered around its pavilion's x
    // with a small y/x stagger so multi-venue pavilions (France ×6, Mexico ×5)
    // don't stack pins directly on top of one another. "Frozen Ever After" and
    // "Remy's Ratatouille" (Norway/France attractions) were nudged from their
    // original starter-estimate x to sit with their own pavilion's dining
    // cluster — the only change to previously-embedded EPCOT attraction pins.
    //
    // Only venues flagged map: 3 in RideMasterData+Dining.swift get a pin.
    // "Space 220 Lounge" is map: nil there (identical coordinate to Space 220
    // Restaurant, same building) and is deliberately not duplicated here.
    //
    // Starter calibration against the authored composition's zone layout, same
    // methodology as every non-Magic-Kingdom park in this file — refinable
    // in-app via CalibrationViewModel if closer precision is wanted later.
    static let epcotPins: [ParkMapPin] = [
        // World Discovery (northeast)
        pin("ep|guardians",     "epcot", "Guardians: Cosmic Rewind",  x: 0.63, y: 0.20, priority: 1),
        pin("ep|test-track",    "epcot", "Test Track",                x: 0.71, y: 0.27, priority: 1),
        pin("ep|mission-space", "epcot", "Mission: SPACE",            x: 0.67, y: 0.28, priority: 2),
        // World Nature (northwest)
        pin("ep|soarin",        "epcot", "Soarin'",                   x: 0.27, y: 0.35, priority: 1),
        pin("ep|living-land",   "epcot", "Living with the Land",      x: 0.23, y: 0.40, priority: 2),
        pin("ep|nemo",          "epcot", "The Seas with Nemo",        x: 0.19, y: 0.35, priority: 2),
        // World Showcase (south loop) — nudged to sit with their own pavilion's
        // dining cluster (Norway x≈0.162, France x≈0.736); see header note.
        pin("ep|frozen",        "epcot", "Frozen Ever After",         x: 0.162, y: 0.76, priority: 1),
        pin("ep|ratatouille",   "epcot", "Remy's Ratatouille",        x: 0.736, y: 0.76, priority: 1),
        // World Celebration (center)
        pin("ep|figment",       "epcot", "Journey Into Imagination",  x: 0.35, y: 0.32, priority: 2),

        // ── Dining — World Celebration ────────────────────────────────────
        pin("ep|dining|connections-eatery", "epcot", "Connections Eatery", x: 0.50, y: 0.36, priority: 2),
        pin("ep|dining|geo-82",             "epcot", "GEO-82",             x: 0.44, y: 0.38, priority: 3),
        pin("ep|dining|grab-n-goof",        "epcot", "GRAB-N-GOOF",        x: 0.56, y: 0.38, priority: 3),

        // ── Dining — World Discovery ───────────────────────────────────────
        pin("ep|dining|space-220",          "epcot", "Space 220 Restaurant", x: 0.74, y: 0.24, priority: 2),

        // ── Dining — World Nature (The Land pavilion) ─────────────────────
        pin("ep|dining|sunshine-seasons",   "epcot", "Sunshine Seasons",     x: 0.23, y: 0.33, priority: 1),
        pin("ep|dining|garden-grill",       "epcot", "Garden Grill Restaurant", x: 0.21, y: 0.37, priority: 2),

        // ── Dining — World Showcase: Mexico pavilion (x ≈ 0.08) ───────────
        pin("ep|dining|la-cantina-de-san-angel", "epcot", "La Cantina de San Angel", x: 0.075, y: 0.80, priority: 2),
        pin("ep|dining|san-angel-inn",            "epcot", "San Angel Inn Restaurante", x: 0.085, y: 0.84, priority: 2),
        pin("ep|dining|la-hacienda-de-san-angel",  "epcot", "La Hacienda de San Angel", x: 0.065, y: 0.84, priority: 2),
        pin("ep|dining|la-cava-del-tequila",       "epcot", "La Cava del Tequila", x: 0.09, y: 0.88, priority: 3),
        pin("ep|dining|choza-de-margarita",        "epcot", "Choza de Margarita", x: 0.07, y: 0.88, priority: 3),

        // ── Dining — World Showcase: Norway pavilion (x ≈ 0.162) ──────────
        pin("ep|dining|akershus",           "epcot", "Akershus Royal Banquet Hall", x: 0.162, y: 0.82, priority: 2),

        // ── Dining — World Showcase: China pavilion (x ≈ 0.244) ───────────
        pin("ep|dining|nine-dragons",       "epcot", "Nine Dragons Restaurant", x: 0.244, y: 0.82, priority: 2),

        // ── Dining — World Showcase: between Germany and China ───────────
        pin("ep|dining|refreshment-outpost", "epcot", "Refreshment Outpost", x: 0.285, y: 0.78, priority: 3),

        // ── Dining — World Showcase: Germany pavilion (x ≈ 0.326) ─────────
        pin("ep|dining|biergarten",         "epcot", "Biergarten Restaurant", x: 0.316, y: 0.80, priority: 2),
        pin("ep|dining|sommerfest",         "epcot", "Sommerfest", x: 0.336, y: 0.84, priority: 3),
        pin("ep|dining|karamell-kuche",     "epcot", "Karamell-K\u{00FC}che", x: 0.326, y: 0.88, priority: 3),

        // ── Dining — World Showcase: Italy pavilion (x ≈ 0.408) ───────────
        pin("ep|dining|tutto-italia",       "epcot", "Tutto Italia Ristorante", x: 0.398, y: 0.80, priority: 2),
        pin("ep|dining|via-napoli",         "epcot", "Via Napoli Ristorante e Pizzeria", x: 0.418, y: 0.84, priority: 2),
        pin("ep|dining|tutto-gusto",        "epcot", "Tutto Gusto Wine Cellar", x: 0.408, y: 0.88, priority: 3),

        // ── Dining — World Showcase: The American Adventure (x ≈ 0.49) ───
        pin("ep|dining|regal-eagle",        "epcot", "Regal Eagle Smokehouse", x: 0.48, y: 0.80, priority: 2),
        pin("ep|dining|fife-and-drum",      "epcot", "Fife & Drum Tavern", x: 0.50, y: 0.84, priority: 3),
        pin("ep|dining|block-and-hans",     "epcot", "Block & Hans", x: 0.49, y: 0.88, priority: 3),

        // ── Dining — World Showcase: Japan pavilion (x ≈ 0.572) ───────────
        pin("ep|dining|katsura-grill",      "epcot", "Katsura Grill", x: 0.562, y: 0.80, priority: 2),
        pin("ep|dining|teppan-edo",         "epcot", "Teppan Edo", x: 0.582, y: 0.82, priority: 2),
        pin("ep|dining|takumi-tei",         "epcot", "Takumi-Tei", x: 0.572, y: 0.86, priority: 3),
        pin("ep|dining|shiki-sai",          "epcot", "Shiki-Sai: Sushi Izakaya", x: 0.552, y: 0.88, priority: 3),

        // ── Dining — World Showcase: Morocco pavilion (x ≈ 0.654) ─────────
        pin("ep|dining|tangierine-cafe",    "epcot", "Tangierine Café", x: 0.644, y: 0.80, priority: 2),
        pin("ep|dining|spice-road-table",   "epcot", "Spice Road Table", x: 0.664, y: 0.84, priority: 2),

        // ── Dining — World Showcase: France pavilion (x ≈ 0.736) ──────────
        pin("ep|dining|les-halles",         "epcot", "Les Halles Boulangerie-Patisserie", x: 0.716, y: 0.78, priority: 2),
        pin("ep|dining|artisan-des-glaces", "epcot", "L'Artisan des Glaces", x: 0.736, y: 0.80, priority: 2),
        pin("ep|dining|monsieur-paul",      "epcot", "Monsieur Paul", x: 0.756, y: 0.82, priority: 3),
        pin("ep|dining|chefs-de-france",    "epcot", "Chefs de France", x: 0.726, y: 0.84, priority: 2),
        pin("ep|dining|les-vins",           "epcot", "Les Vins des Chefs de France", x: 0.746, y: 0.86, priority: 3),
        pin("ep|dining|la-creperie-de-paris", "epcot", "La Cr\u{00EA}perie de Paris", x: 0.736, y: 0.88, priority: 3),

        // ── Dining — World Showcase: United Kingdom pavilion (x ≈ 0.818) ──
        pin("ep|dining|rose-and-crown-dining", "epcot", "Rose & Crown Dining Room", x: 0.80, y: 0.80, priority: 2),
        pin("ep|dining|rose-and-crown-pub",     "epcot", "Rose & Crown Pub", x: 0.818, y: 0.82, priority: 2),
        pin("ep|dining|uk-beer-cart",            "epcot", "UK Beer Cart", x: 0.838, y: 0.84, priority: 3),
        pin("ep|dining|yorkshire-fish-shop",     "epcot", "Yorkshire County Fish Shop", x: 0.80, y: 0.86, priority: 3),

        // ── Dining — World Showcase: Canada pavilion (x ≈ 0.90) ───────────
        pin("ep|dining|le-cellier",         "epcot", "Le Cellier Steakhouse", x: 0.878, y: 0.80, priority: 2),
        pin("ep|dining|la-poutinerie",      "epcot", "La Poutinerie", x: 0.86, y: 0.84, priority: 3),
    ]

    // MARK: Hollywood Studios

    static let hollywoodStudiosPins: [ParkMapPin] = [
        // Star Wars: Galaxy's Edge (southwest)
        pin("hs|rise",             "hollywood-studios", "Rise of the Resistance",   x: 0.20, y: 0.72, priority: 1),
        pin("hs|falcon",           "hollywood-studios", "Millennium Falcon",         x: 0.28, y: 0.65, priority: 1),
        // Toy Story Land (southeast)
        pin("hs|slinky",           "hollywood-studios", "Slinky Dog Dash",          x: 0.73, y: 0.68, priority: 1),
        pin("hs|toy-story-mania",  "hollywood-studios", "Toy Story Mania!",         x: 0.68, y: 0.60, priority: 2),
        pin("hs|alien",            "hollywood-studios", "Alien Swirling Saucers",   x: 0.77, y: 0.73, priority: 3),
        // Sunset Boulevard (east)
        pin("hs|tower-of-terror",  "hollywood-studios", "Tower of Terror",          x: 0.73, y: 0.37, priority: 1),
        pin("hs|rocknroller",      "hollywood-studios", "Rock 'n' Roller Coaster",  x: 0.68, y: 0.44, priority: 1),
        // Hollywood Boulevard (center-north)
        pin("hs|runaway-railway",  "hollywood-studios", "Runaway Railway",          x: 0.50, y: 0.29, priority: 1),
    ]

    // MARK: Animal Kingdom

    static let animalKingdomPins: [ParkMapPin] = [
        // Pandora (south)
        pin("ak|flight-of-passage", "animal-kingdom", "Flight of Passage",      x: 0.53, y: 0.73, priority: 1),
        pin("ak|navi-river",        "animal-kingdom", "Na'vi River Journey",    x: 0.44, y: 0.73, priority: 2),
        // Asia (east)
        pin("ak|everest",           "animal-kingdom", "Expedition Everest",     x: 0.73, y: 0.37, priority: 1),
        pin("ak|kali",              "animal-kingdom", "Kali River Rapids",      x: 0.68, y: 0.44, priority: 2),
        // Africa (northwest)
        pin("ak|safaris",           "animal-kingdom", "Kilimanjaro Safaris",    x: 0.27, y: 0.31, priority: 1),
    ]

    // MARK: Disneyland

    static let disneylandPins: [ParkMapPin] = [
        // New Orleans Square (west center)
        pin("dl|haunted-mansion",  "disneyland", "Haunted Mansion",            x: 0.27, y: 0.46, priority: 1),
        pin("dl|pirates",          "disneyland", "Pirates of the Caribbean",   x: 0.23, y: 0.52, priority: 1),
        pin("dl|tiana",            "disneyland", "Tiana's Bayou Adventure",    x: 0.25, y: 0.50, priority: 1),
        // Adventureland (southwest)
        pin("dl|jungle-cruise",    "disneyland", "Jungle Cruise",              x: 0.19, y: 0.57, priority: 2),
        pin("dl|indiana-jones",    "disneyland", "Indiana Jones Adventure",    x: 0.17, y: 0.62, priority: 1),
        // Frontierland (west)
        pin("dl|big-thunder",      "disneyland", "Big Thunder Mountain",       x: 0.15, y: 0.46, priority: 1),
        // Star Wars: Galaxy's Edge (far southwest)
        pin("dl|rise",             "disneyland", "Rise of the Resistance",     x: 0.13, y: 0.73, priority: 1),
        pin("dl|falcon",           "disneyland", "Millennium Falcon",          x: 0.21, y: 0.68, priority: 1),
        // Fantasyland (north center)
        pin("dl|matterhorn",       "disneyland", "Matterhorn Bobsleds",        x: 0.59, y: 0.27, priority: 1),
        pin("dl|peter-pan",        "disneyland", "Peter Pan's Flight",         x: 0.44, y: 0.31, priority: 2),
        pin("dl|small-world",      "disneyland", "it's a small world",         x: 0.39, y: 0.27, priority: 2),
        // Tomorrowland (east)
        pin("dl|space-mountain",   "disneyland", "Space Mountain",             x: 0.71, y: 0.47, priority: 1),
        pin("dl|buzz",             "disneyland", "Buzz Lightyear",             x: 0.73, y: 0.53, priority: 2),
        // Mickey's Toontown (far north)
        pin("dl|runaway-railway",  "disneyland", "Runaway Railway",            x: 0.53, y: 0.17, priority: 1),
        pin("dl|roger-rabbit",     "disneyland", "Roger Rabbit's Car Toon",   x: 0.59, y: 0.17, priority: 2),
        // Transport
        pin("dl|railroad",         "disneyland", "Disneyland Railroad",        x: 0.50, y: 0.87, priority: 3),
    ]

    // MARK: California Adventure

    static let californiaAdventurePins: [ParkMapPin] = [
        // Avengers Campus (northeast)
        pin("dca|web-slingers",      "california-adventure", "WEB SLINGERS",                   x: 0.73, y: 0.27, priority: 1),
        // Hollywood Land (north center)
        pin("dca|guardians",         "california-adventure", "Guardians: BREAKOUT!",           x: 0.65, y: 0.21, priority: 1),
        // Cars Land (east center)
        pin("dca|radiator-springs",  "california-adventure", "Radiator Springs Racers",        x: 0.76, y: 0.52, priority: 1),
        pin("dca|maters",            "california-adventure", "Mater's Junkyard Jamboree",      x: 0.79, y: 0.59, priority: 2),
        pin("dca|luigis",            "california-adventure", "Luigi's Rollickin' Roadsters",   x: 0.72, y: 0.59, priority: 3),
        // Grizzly Peak (center)
        pin("dca|soarin",            "california-adventure", "Soarin' Around the World",       x: 0.40, y: 0.46, priority: 1),
        pin("dca|grizzly",           "california-adventure", "Grizzly River Run",              x: 0.45, y: 0.41, priority: 2),
        // Pixar Pier (south)
        pin("dca|incredicoaster",    "california-adventure", "Incredicoaster",                 x: 0.61, y: 0.79, priority: 1),
        pin("dca|toy-story-midway",  "california-adventure", "Toy Story Midway Mania!",        x: 0.56, y: 0.74, priority: 2),
        pin("dca|inside-out",        "california-adventure", "Inside Out Emotional Whirlwind", x: 0.50, y: 0.80, priority: 2),
    ]
}

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
    // Fractions are the drawn building or label on epcot_map, measured from
    // the 3x artwork (1170×1152) with a top-left origin. Several venues share
    // one pavilion, so extra pins are spread inside that building's box.
    // Refreshment Outpost, GRAB-N-GOOF, and Disney Character Spot have no
    // dedicated building on this art and are not pinned.

    static let epcotPins: [ParkMapPin] = [
        pin("ep|spaceship-earth", "epcot", "Spaceship Earth", x: 0.4641, y: 0.8056, anchor: .center, priority: 2),
        pin("ep|geo-82", "epcot", "GEO-82", x: 0.5188, y: 0.8056, anchor: .center, priority: 3),
        pin("ep|journey-into-imagination-with-figment", "epcot", "Journey Into Imagination With Figment", x: 0.6545, y: 0.5951, anchor: .center, priority: 2),
        pin("ep|figment-at-imageworks", "epcot", "Figment at ImageWorks", x: 0.7207, y: 0.5951, anchor: .center, priority: 3),
        pin("ep|guardians-of-the-galaxy-cosmic-rewind", "epcot", "Guardians of the Galaxy: Cosmic Rewind", x: 0.3462, y: 0.7925, anchor: .center, priority: 1),
        pin("ep|mission-space", "epcot", "Mission: SPACE", x: 0.2232, y: 0.6910, anchor: .center, priority: 2),
        pin("ep|space-220-restaurant", "epcot", "Space 220 Restaurant", x: 0.2691, y: 0.6910, anchor: .center, priority: 3),
        pin("ep|test-track", "epcot", "Test Track", x: 0.2333, y: 0.6098, anchor: .center, priority: 1),
        pin("ep|soarin-around-the-world", "epcot", "Soarin' Around the World", x: 0.7511, y: 0.6414, anchor: .center, priority: 1),
        pin("ep|living-with-the-land", "epcot", "Living with the Land", x: 0.8506, y: 0.6414, anchor: .center, priority: 2),
        pin("ep|sunshine-seasons", "epcot", "Sunshine Seasons", x: 0.7511, y: 0.7180, anchor: .center, priority: 3),
        pin("ep|garden-grill-restaurant", "epcot", "Garden Grill Restaurant", x: 0.8506, y: 0.7180, anchor: .center, priority: 3),
        pin("ep|the-seas-with-nemo-friends", "epcot", "The Seas with Nemo & Friends", x: 0.6157, y: 0.8121, anchor: .center, priority: 2),
        pin("ep|turtle-talk-with-crush", "epcot", "Turtle Talk with Crush", x: 0.6835, y: 0.8121, anchor: .center, priority: 3),
        pin("ep|journey-of-water-inspired-by-moana", "epcot", "Journey of Water, Inspired by Moana", x: 0.5897, y: 0.7587, anchor: .center, priority: 2),
        pin("ep|frozen-ever-after", "epcot", "Frozen Ever After", x: 0.1770, y: 0.4108, anchor: .center, priority: 1),
        pin("ep|akershus-royal-banquet-hall", "epcot", "Akershus Royal Banquet Hall", x: 0.2308, y: 0.4108, anchor: .center, priority: 3),
        pin("ep|gran-fiesta-tour", "epcot", "Gran Fiesta Tour", x: 0.2442, y: 0.4786, anchor: .center, priority: 3),
        pin("ep|san-angel-inn-restaurante", "epcot", "San Angel Inn Restaurante", x: 0.3190, y: 0.4786, anchor: .center, priority: 3),
        pin("ep|la-hacienda-de-san-angel", "epcot", "La Hacienda de San Angel", x: 0.2442, y: 0.5035, anchor: .center, priority: 3),
        pin("ep|la-cava-del-tequila", "epcot", "La Cava del Tequila", x: 0.3190, y: 0.5035, anchor: .center, priority: 3),
        pin("ep|choza-de-margarita", "epcot", "Choza de Margarita", x: 0.2442, y: 0.5283, anchor: .center, priority: 3),
        pin("ep|la-cantina-de-san-angel", "epcot", "La Cantina de San Angel", x: 0.3190, y: 0.5283, anchor: .center, priority: 3),
        pin("ep|nine-dragons-restaurant", "epcot", "Nine Dragons Restaurant", x: 0.1630, y: 0.3518, anchor: .center, priority: 2),
        pin("ep|biergarten-restaurant", "epcot", "Biergarten Restaurant", x: 0.2046, y: 0.1319, anchor: .center, priority: 2),
        pin("ep|sommerfest", "epcot", "Sommerfest", x: 0.2696, y: 0.1319, anchor: .center, priority: 3),
        pin("ep|karamell-kuche", "epcot", "Karamell-Küche", x: 0.2046, y: 0.1850, anchor: .center, priority: 3),
        pin("ep|tutto-italia-ristorante", "epcot", "Tutto Italia Ristorante", x: 0.3599, y: 0.1042, anchor: .center, priority: 2),
        pin("ep|via-napoli-ristorante-e-pizzeria", "epcot", "Via Napoli Ristorante e Pizzeria", x: 0.4236, y: 0.1042, anchor: .center, priority: 3),
        pin("ep|tutto-gusto-wine-cellar", "epcot", "Tutto Gusto Wine Cellar", x: 0.3599, y: 0.1555, anchor: .center, priority: 3),
        pin("ep|the-american-adventure", "epcot", "The American Adventure", x: 0.4625, y: 0.0935, anchor: .center, priority: 2),
        pin("ep|regal-eagle-smokehouse", "epcot", "Regal Eagle Smokehouse", x: 0.5242, y: 0.0935, anchor: .center, priority: 3),
        pin("ep|fife-drum-tavern", "epcot", "Fife & Drum Tavern", x: 0.4625, y: 0.1479, anchor: .center, priority: 3),
        pin("ep|block-hans", "epcot", "Block & Hans", x: 0.5242, y: 0.1479, anchor: .center, priority: 3),
        pin("ep|teppan-edo", "epcot", "Teppan Edo", x: 0.5816, y: 0.0945, anchor: .center, priority: 2),
        pin("ep|takumi-tei", "epcot", "Takumi-Tei", x: 0.6400, y: 0.0945, anchor: .center, priority: 3),
        pin("ep|shiki-sai-sushi-izakaya", "epcot", "Shiki-Sai: Sushi Izakaya", x: 0.5816, y: 0.1430, anchor: .center, priority: 3),
        pin("ep|katsura-grill", "epcot", "Katsura Grill", x: 0.6400, y: 0.1430, anchor: .center, priority: 3),
        pin("ep|tangierine-cafe", "epcot", "Tangierine Café", x: 0.7189, y: 0.1592, anchor: .center, priority: 2),
        pin("ep|spice-road-table", "epcot", "Spice Road Table", x: 0.7708, y: 0.1592, anchor: .center, priority: 3),
        pin("ep|remy-s-ratatouille-adventure", "epcot", "Remy's Ratatouille Adventure", x: 0.7721, y: 0.1898, anchor: .center, priority: 2),
        pin("ep|monsieur-paul", "epcot", "Monsieur Paul", x: 0.8279, y: 0.1898, anchor: .center, priority: 3),
        pin("ep|chefs-de-france", "epcot", "Chefs de France", x: 0.7721, y: 0.2068, anchor: .center, priority: 3),
        pin("ep|les-vins-des-chefs-de-france", "epcot", "Les Vins des Chefs de France", x: 0.8279, y: 0.2068, anchor: .center, priority: 3),
        pin("ep|la-creperie-de-paris", "epcot", "La Crêperie de Paris", x: 0.7721, y: 0.2238, anchor: .center, priority: 3),
        pin("ep|les-halles-boulangerie-patisserie", "epcot", "Les Halles Boulangerie-Patisserie", x: 0.8279, y: 0.2238, anchor: .center, priority: 3),
        pin("ep|l-artisan-des-glaces", "epcot", "L'Artisan des Glaces", x: 0.7721, y: 0.2409, anchor: .center, priority: 3),
        pin("ep|rose-crown-dining-room", "epcot", "Rose & Crown Dining Room", x: 0.7796, y: 0.3883, anchor: .center, priority: 2),
        pin("ep|rose-crown-pub", "epcot", "Rose & Crown Pub", x: 0.8223, y: 0.3883, anchor: .center, priority: 3),
        pin("ep|uk-beer-cart", "epcot", "UK Beer Cart", x: 0.7796, y: 0.4595, anchor: .center, priority: 3),
        pin("ep|yorkshire-county-fish-shop", "epcot", "Yorkshire County Fish Shop", x: 0.8223, y: 0.4595, anchor: .center, priority: 3),
        pin("ep|le-cellier-steakhouse", "epcot", "Le Cellier Steakhouse", x: 0.7062, y: 0.5254, anchor: .center, priority: 2),
        pin("ep|la-poutinerie", "epcot", "La Poutinerie", x: 0.7699, y: 0.5254, anchor: .center, priority: 3),
        pin("ep|connections-eatery", "epcot", "Connections Eatery", x: 0.4291, y: 0.6715, anchor: .center, priority: 2),
        pin("ep|luminous", "epcot", "Luminous The Symphony of Us", x: 0.5067, y: 0.3177, anchor: .center, priority: 1),
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

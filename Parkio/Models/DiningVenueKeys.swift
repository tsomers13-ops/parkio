// DiningVenueKeys.swift — GENERATED. Do not edit by hand.
//
// Source of truth: Parkio-Website-Live/lib/diningVenueKeys.ts
// Regenerate with:
//   npm run dining:venuekeys:swift -- --output <iOS>/Parkio/Models/DiningVenueKeys.swift \
//                                      --sidecar <iOS>/Tools/VenueKeys/DiningVenueKeys.json
//
// sourceSha256: a7e844bd8b3be46f20ae7e295dc197573c06e4cad9880b3300e7d98c79d29968
// entries: 93
//
// venueKey is the Website-owned immutable identity a Community Rating is filed
// against. It is NOT a slug, NOT a stableID and NOT a display name, and it is
// never derived from a name at runtime — the mapping below is exhaustive and
// explicit, so an unmapped venue is simply not rateable rather than guessed at.
//
// The dictionary is keyed by the iOS stableID, "{Park.rawValue}|{land}|{name}",
// which is the same string the Website registry already uses as its key.

import Foundation

enum DiningVenueKeys {

    /// stableID → venueKey, for every venue the ratings backend accepts today.
    static let byStableID: [String: String] = [
        "EPCOT|World Celebration|Connections Eatery": "ep-connections-eatery",
        "EPCOT|World Celebration|GEO-82": "ep-geo-82",
        "EPCOT|World Celebration|GRAB-N-GOOF": "ep-grab-n-goof",
        "EPCOT|World Discovery|Space 220 Lounge": "ep-space-220-lounge",
        "EPCOT|World Discovery|Space 220 Restaurant": "ep-space-220",
        "EPCOT|World Nature|Garden Grill Restaurant": "ep-garden-grill",
        "EPCOT|World Nature|Sunshine Seasons": "ep-sunshine-seasons",
        "EPCOT|World Showcase|Akershus Royal Banquet Hall": "ep-akershus",
        "EPCOT|World Showcase|Biergarten Restaurant": "ep-biergarten",
        "EPCOT|World Showcase|Block & Hans": "ep-block-and-hans",
        "EPCOT|World Showcase|Chefs de France": "ep-chefs-de-france",
        "EPCOT|World Showcase|Choza de Margarita": "ep-choza-de-margarita",
        "EPCOT|World Showcase|Fife & Drum Tavern": "ep-fife-and-drum",
        "EPCOT|World Showcase|Karamell-Küche": "ep-karamell-kuche",
        "EPCOT|World Showcase|Katsura Grill": "ep-katsura-grill",
        "EPCOT|World Showcase|L'Artisan des Glaces": "ep-lartisan-des-glaces",
        "EPCOT|World Showcase|La Cantina de San Angel": "ep-la-cantina",
        "EPCOT|World Showcase|La Cava del Tequila": "ep-la-cava",
        "EPCOT|World Showcase|La Crêperie de Paris": "ep-la-creperie",
        "EPCOT|World Showcase|La Hacienda de San Angel": "ep-la-hacienda",
        "EPCOT|World Showcase|La Poutinerie": "ep-la-poutinerie",
        "EPCOT|World Showcase|Le Cellier Steakhouse": "ep-le-cellier",
        "EPCOT|World Showcase|Les Halles Boulangerie-Patisserie": "ep-les-halles",
        "EPCOT|World Showcase|Les Vins des Chefs de France": "ep-les-vins-de-france",
        "EPCOT|World Showcase|Monsieur Paul": "ep-monsieur-paul",
        "EPCOT|World Showcase|Nine Dragons Restaurant": "ep-nine-dragons",
        "EPCOT|World Showcase|Refreshment Outpost": "ep-refreshment-outpost",
        "EPCOT|World Showcase|Regal Eagle Smokehouse": "ep-regal-eagle",
        "EPCOT|World Showcase|Rose & Crown Dining Room": "ep-rose-and-crown",
        "EPCOT|World Showcase|Rose & Crown Pub": "ep-rose-and-crown-pub",
        "EPCOT|World Showcase|San Angel Inn Restaurante": "ep-san-angel-inn",
        "EPCOT|World Showcase|Shiki-Sai: Sushi Izakaya": "ep-shiki-sai",
        "EPCOT|World Showcase|Sommerfest": "ep-sommerfest",
        "EPCOT|World Showcase|Spice Road Table": "ep-spice-road-table",
        "EPCOT|World Showcase|Takumi-Tei": "ep-takumi-tei",
        "EPCOT|World Showcase|Tangierine Café": "ep-tangierine-cafe",
        "EPCOT|World Showcase|Teppan Edo": "ep-teppan-edo",
        "EPCOT|World Showcase|Tutto Gusto Wine Cellar": "ep-tutto-gusto",
        "EPCOT|World Showcase|Tutto Italia Ristorante": "ep-tutto-italia",
        "EPCOT|World Showcase|UK Beer Cart": "ep-uk-beer-cart",
        "EPCOT|World Showcase|Via Napoli Ristorante e Pizzeria": "ep-via-napoli",
        "EPCOT|World Showcase|Yorkshire County Fish Shop": "ep-yorkshire-fish-shop",
        "Hollywood Studios|Commissary Lane|ABC Commissary": "hs-abc-commissary",
        "Hollywood Studios|Commissary Lane|Sci-Fi Dine-In Theater Restaurant": "hs-sci-fi-dine-in",
        "Hollywood Studios|Echo Lake|50's Prime Time Cafe": "hs-50s-prime-time",
        "Hollywood Studios|Echo Lake|Backlot Express": "hs-backlot-express",
        "Hollywood Studios|Echo Lake|Dockside Diner": "hs-dockside-diner",
        "Hollywood Studios|Echo Lake|Hollywood & Vine": "hs-hollywood-and-vine",
        "Hollywood Studios|Echo Lake|Tune-In Lounge": "hs-tune-in-lounge",
        "Hollywood Studios|Grand Avenue|BaseLine Tap House": "hs-baseline-tap-house",
        "Hollywood Studios|Hollywood Boulevard|The Hollywood Brown Derby": "hs-brown-derby",
        "Hollywood Studios|Hollywood Boulevard|The Hollywood Brown Derby Lounge": "hs-brown-derby-lounge",
        "Hollywood Studios|Star Wars: Galaxy's Edge|Docking Bay 7 Food and Cargo": "hs-docking-bay-7",
        "Hollywood Studios|Star Wars: Galaxy's Edge|Kat Saka's Kettle": "hs-kat-sakas-kettle",
        "Hollywood Studios|Star Wars: Galaxy's Edge|Milk Stand": "hs-milk-stand",
        "Hollywood Studios|Star Wars: Galaxy's Edge|Oga's Cantina": "hs-ogas-cantina",
        "Hollywood Studios|Star Wars: Galaxy's Edge|Ronto Roasters": "hs-ronto-roasters",
        "Hollywood Studios|Sunset Boulevard|Catalina Eddie's": "hs-catalina-eddies",
        "Hollywood Studios|Sunset Boulevard|Fairfax Fare": "hs-fairfax-fare",
        "Hollywood Studios|Sunset Boulevard|Rosie's All-American Cafe": "hs-rosies",
        "Hollywood Studios|Toy Story Land|Roundup Rodeo BBQ": "hs-roundup-rodeo",
        "Hollywood Studios|Toy Story Land|Woody's Lunch Box": "hs-woodys-lunch-box",
        "Magic Kingdom|Adventureland|Aloha Isle": "mk-aloha-isle",
        "Magic Kingdom|Adventureland|Jungle Navigation Co. LTD Skipper Canteen": "mk-skipper-canteen",
        "Magic Kingdom|Adventureland|Spring Roll Snack Cart": "mk-spring-roll-cart",
        "Magic Kingdom|Adventureland|Sunshine Tree Terrace": "mk-sunshine-tree-terrace",
        "Magic Kingdom|Adventureland|The Beak and Barrel": "mk-beak-and-barrel",
        "Magic Kingdom|Fantasyland|Be Our Guest Restaurant": "mk-be-our-guest",
        "Magic Kingdom|Fantasyland|Cheshire Café": "mk-cheshire-cafe",
        "Magic Kingdom|Fantasyland|Cinderella's Royal Table": "mk-cinderellas-royal-table",
        "Magic Kingdom|Fantasyland|Gaston's Tavern": "mk-gastons-tavern",
        "Magic Kingdom|Fantasyland|Pinocchio Village Haus": "mk-pinocchio-village-haus",
        "Magic Kingdom|Fantasyland|Prince Eric's Village Market": "mk-prince-erics-village-market",
        "Magic Kingdom|Fantasyland|Storybook Treats": "mk-storybook-treats",
        "Magic Kingdom|Fantasyland|The Friar's Nook": "mk-friars-nook",
        "Magic Kingdom|Frontierland|Golden Oak Outpost": "mk-golden-oak-outpost",
        "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe": "mk-pecos-bill",
        "Magic Kingdom|Liberty Square|Liberty Tree Tavern": "mk-liberty-tree-tavern",
        "Magic Kingdom|Liberty Square|Sleepy Hollow": "mk-sleepy-hollow",
        "Magic Kingdom|Liberty Square|The Diamond Horseshoe": "mk-diamond-horseshoe",
        "Magic Kingdom|Main Street, U.S.A.|Casey's Corner": "mk-caseys-corner",
        "Magic Kingdom|Main Street, U.S.A.|Main Street Bakery": "mk-main-street-bakery",
        "Magic Kingdom|Main Street, U.S.A.|Plaza Ice Cream Parlor": "mk-plaza-ice-cream-parlor",
        "Magic Kingdom|Main Street, U.S.A.|The Crystal Palace": "mk-crystal-palace",
        "Magic Kingdom|Main Street, U.S.A.|The Plaza Restaurant": "mk-plaza-restaurant",
        "Magic Kingdom|Main Street, U.S.A.|Tony's Town Square Restaurant": "mk-tonys-town-square",
        "Magic Kingdom|Tomorrowland|AstroFizz Hosted by Coca-Cola": "mk-astrofizz",
        "Magic Kingdom|Tomorrowland|Auntie Gravity's Galactic Goodies": "mk-auntie-gravitys",
        "Magic Kingdom|Tomorrowland|Cosmic Ray's Starlight Café": "mk-cosmic-rays",
        "Magic Kingdom|Tomorrowland|Energy Bytes": "mk-energy-bytes",
        "Magic Kingdom|Tomorrowland|Fireworks Dessert Parties at Tomorrowland Terrace Restaurant": "mk-tomorrowland-terrace-dessert-party",
        "Magic Kingdom|Tomorrowland|Joffrey's Coffee & Tea Company": "mk-joffreys",
        "Magic Kingdom|Tomorrowland|The Lunching Pad": "mk-lunching-pad",
    ]

    /// Number of venues the backend currently accepts. Guards against a
    /// silent partial regeneration.
    static let expectedCount = 93

    /// The venueKey for a venue, or nil when it is not rateable yet.
    static func venueKey(forStableID stableID: String) -> String? {
        byStableID[stableID]
    }

    /// Whether this venue can currently be rated.
    static func isRateable(stableID: String) -> Bool {
        byStableID[stableID] != nil
    }
}

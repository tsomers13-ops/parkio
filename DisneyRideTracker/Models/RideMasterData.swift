// RideMasterData.swift — Canonical single source of truth for all park attractions.
//
// Architecture
// ────────────
// AttractionType  — high-level classification (ride / show / walkthrough / transport / future).
// MasterAttraction— one struct per attraction; owns every attribute needed by any feature.
// RideMasterData  — namespace with the full static list + computed bridges for:
//                     • RideSeeder    (seedableAttractions)
//                     • RideEnvironmentTable (outdoorStableIDs)
//                     • WaitTimeViewModel / MapViewModel (matchingAliases)
//
// Stable ID contract
// ──────────────────
// stableID = "\(park.rawValue)|\(land)|\(name)"
// This MUST match what RideSeeder.Seed.stableID produces and the `id` field in
// MapCoordinates.json. Never rename `name` or `land` without also updating the
// seeder's migration logic (byParkName lookup) so existing user ride logs survive.
//
// Alias system
// ────────────
// `aliases` holds alternative names the live-data API (ThemeParks.wiki / QueueTimes)
// may return for the same physical attraction. Aliases are normalised and checked in
// WaitTimeViewModel.fastLiveState and MapViewModel.liveMatchKeys so a rename at the
// park (e.g. Aerosmith → The Muppets) doesn't silently break wait-time display.
//
// Data issues fixed vs. scattered per-file approach
// ─────────────────────────────────────────────────
//   • Rock 'n' Roller Coaster: API may still return "Starring Aerosmith" after the
//     2025 rebrand to "Starring The Muppets" — alias ensures matching never breaks.
//   • Journey Into Imagination With Figment: was completely missing from RideSeeder
//     and MapCoordinates.json despite being a live-wait ride at EPCOT.
//   • Gran Fiesta Tour / Expedition Everest / PeopleMover / Barnstormer: display names
//     in MapCoordinates.json differ from seeder names; aliases provide O(1) exact
//     lookup instead of relying solely on the O(M) substring fallback.
//   • Indiana Jones Adventure (Disneyland): API sometimes appends the full subtitle;
//     alias ensures the match doesn't fall through to a false positive.
//   • Animal Kingdom trails + Wildlife Express Train: included as non-seeded
//     entries so future map pins need no per-file additions.
//   • Outdoor/indoor classification is now in one place instead of duplicated
//     between RideEnvironmentTable and scattered comments.

import Foundation

// MARK: - AttractionType

enum AttractionType: String, Sendable {
    /// Traditional ride with a live wait time — tracked in SwiftData and shown in Best Next Ride.
    case ride
    /// Scheduled theatrical show — no personal wait time (may have general queue / seating).
    case show
    /// Character meet-and-greet experience — no queue; shows scheduled times ("Times vary").
    case characterMeet
    /// Self-paced walkthrough experience — no queue, not tracked.
    case walkthrough
    /// Park transportation (railroad, monorail, riverboat).
    case transport
    /// Announced or under construction — not currently operating.
    case future
}

// MARK: - MasterAttraction

struct MasterAttraction: Sendable {
    /// Canonical display name — also the final component of stableID.
    let name: String
    let park: Park
    /// Canonical land name — must match an entry in `park.lands`.
    let land: String
    let type: AttractionType
    /// True when guests experience weather during the ride or its outdoor queue.
    let isOutdoor: Bool
    /// Map pin priority: 1 = always visible, 2 = default zoom, 3 = zoomed in, nil = no pin.
    let mapPriority: Int?
    /// True when this attraction is inserted into the SwiftData ride list.
    let shouldSeed: Bool
    /// Alternative names the live-data API may return (normalized at lookup time).
    let aliases: [String]
    /// ThemeParks.wiki attraction entity UUID, e.g. "fe75b6ef-07b3-4d4f-b3d0-3498e1b88a23".
    /// `nil` until confirmed via GET /entity/{park.themeparksEntityId}/live.
    /// When present, enables O(1) ID-first wait-time lookup instead of name matching.
    let themeparksEntityId: String?
    /// True when this attraction posts a live posted wait time via the ThemeParks.wiki API.
    ///
    /// Defaults to `true` for `.ride` and `false` for all other types. Override
    /// explicitly with `hasLiveWaitTime: true` for the rare non-ride that posts a live
    /// wait (e.g. Monsters, Inc. Laugh Floor, Zootopia: Better Zoogether!).
    let hasLiveWaitTime: Bool

    // MARK: Designated init

    init(
        _ name: String,
        park: Park,
        land: String,
        type: AttractionType,
        outdoor: Bool           = false,
        map: Int?               = nil,
        seed: Bool,
        aliases: [String]       = [],
        entityId: String?       = nil,
        hasLiveWaitTime: Bool?  = nil   // nil → infer: true for .ride, false otherwise
    ) {
        self.name                = name
        self.park                = park
        self.land                = land
        self.type                = type
        self.isOutdoor           = outdoor
        self.mapPriority         = map
        self.shouldSeed          = seed
        self.aliases             = aliases
        self.themeparksEntityId  = entityId
        self.hasLiveWaitTime     = hasLiveWaitTime ?? (type == .ride)
    }

    // MARK: Derived

    /// "{Park.rawValue}|{land}|{name}" — matches RideSeeder.Seed.stableID and MapCoordinates.json id.
    var stableID: String { "\(park.rawValue)|\(land)|\(name)" }

    /// Backend park identifier (e.g. "magic-kingdom").
    var parkId: String { park.backendId }

    /// Participates in live wait-time lookup and display.
    /// True for all `.ride` types; also true for the handful of non-ride attractions
    /// (shows, walkthroughs) that post a live standby wait via ThemeParks.wiki.
    var shouldUseLiveWaitTimes: Bool { hasLiveWaitTime }

    /// Eligible for Best Next Ride ranking in HomeView and MapView.
    /// Intentionally kept as `type == .ride` — shows with live wait times must NOT
    /// appear in ride recommendations; only traditional ride queues belong there.
    var shouldBeRecommended: Bool { type == .ride }

    /// Appears in My Day ride picker.
    var shouldAppearInRidePicker: Bool { shouldSeed }

    /// Gets a map pin (coordinate entry in MapCoordinates.json required separately).
    var shouldAppearOnMap: Bool { mapPriority != nil }
}

// MARK: - RideMasterData

enum RideMasterData {

    // ── Master list ───────────────────────────────────────────────────────────

    static let all: [MasterAttraction] =
        mkAttractions + epcotAttractions + dhsAttractions +
        akAttractions + disneylandAttractions + dcaAttractions

    // ── Seeder bridge ─────────────────────────────────────────────────────────

    /// Attractions that RideSeeder should insert into the SwiftData ride list.
    static var seedableAttractions: [MasterAttraction] {
        all.filter(\.shouldSeed)
    }

    // ── Environment table bridge ──────────────────────────────────────────────

    /// stableIDs of all outdoor attractions — drives RideEnvironmentTable.
    static var outdoorStableIDs: Set<String> {
        Set(all.filter(\.isOutdoor).map(\.stableID))
    }

    // ── Type lookup ───────────────────────────────────────────────────────────

    /// O(1) type lookup by stableID — used by AttractionsListView and map marker views
    /// to determine category-aware display without storing type in SwiftData.
    static let typeByStableID: [String: AttractionType] = {
        var map = [String: AttractionType](minimumCapacity: all.count)
        for a in all { map[a.stableID] = a.type }
        return map
    }()

    // ── Alias lookup ──────────────────────────────────────────────────────────

    /// Alternative API names for the attraction whose canonical `name` is given.
    /// Called by WaitTimeViewModel.fastLiveState and MapViewModel.liveMatchKeys.
    static func matchingAliases(forName name: String) -> [String] {
        aliasByName[name] ?? []
    }

    private static let aliasByName: [String: [String]] = {
        var map: [String: [String]] = [:]
        for a in all where !a.aliases.isEmpty {
            map[a.name] = a.aliases
        }
        return map
    }()
}

// MARK: - Private type alias (data-entry convenience)

private typealias MA = MasterAttraction

// MARK: - Walt Disney World — Magic Kingdom

private extension RideMasterData {

    static let mkAttractions: [MasterAttraction] = [

        // ── Main Street, U.S.A. ───────────────────────────────────────────────
        MA("Walt Disney World Railroad",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .transport, outdoor: true, map: 3, seed: true),

        // ── Adventureland ─────────────────────────────────────────────────────
        MA("Pirates of the Caribbean",
           park: .magicKingdom, land: "Adventureland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Jungle Cruise",
           park: .magicKingdom, land: "Adventureland",
           type: .ride, outdoor: true, map: 2, seed: true),

        MA("Magic Carpets of Aladdin",
           park: .magicKingdom, land: "Adventureland",
           type: .ride, outdoor: true, map: 3, seed: true,
           aliases: ["The Magic Carpets of Aladdin"]),

        // Show — not seeded; map pin added if coordinates are provided in MapCoordinates.json.
        MA("Walt Disney's Enchanted Tiki Room",
           park: .magicKingdom, land: "Adventureland",
           type: .show, outdoor: false, map: nil, seed: false),

        // ── Frontierland ──────────────────────────────────────────────────────
        MA("Big Thunder Mountain Railroad",
           park: .magicKingdom, land: "Frontierland",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Tiana's Bayou Adventure",
           park: .magicKingdom, land: "Frontierland",
           type: .ride, outdoor: true, map: 2, seed: true),

        // ── Liberty Square ────────────────────────────────────────────────────
        MA("Haunted Mansion",
           park: .magicKingdom, land: "Liberty Square",
           type: .ride, outdoor: false, map: 1, seed: true,
           aliases: ["The Haunted Mansion"]),

        MA("Liberty Belle Riverboat",
           park: .magicKingdom, land: "Liberty Square",
           type: .transport, outdoor: true, map: 3, seed: false),

        // ── Fantasyland ───────────────────────────────────────────────────────
        MA("Seven Dwarfs Mine Train",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Peter Pan's Flight",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("It's a Small World",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["it's a small world"]),

        MA("The Many Adventures of Winnie the Pooh",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true),

        // En-dash U+2013 in the canonical name; some API responses use an ASCII hyphen.
        // normalizedForMatching() strips both separators to " " (normalizer fix applied),
        // but the alias is included for belt-and-suspenders exact-match speed.
        MA("Under the Sea \u{2013} Journey of The Little Mermaid",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["Under the Sea - Journey of The Little Mermaid"]),

        MA("Prince Charming Regal Carrousel",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Mad Tea Party",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Dumbo the Flying Elephant",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        // Seeder name is "Barnstormer" (stable ID component); official sign says
        // "The Barnstormer". Alias ensures the longer API name still matches.
        MA("Barnstormer",
           park: .magicKingdom, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true,
           aliases: ["The Barnstormer", "The Barnstormer Featuring The Great Goofini"]),

        MA("Mickey's PhilharMagic",
           park: .magicKingdom, land: "Fantasyland",
           type: .show, outdoor: false, map: nil, seed: false),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Space Mountain",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Buzz Lightyear's Space Ranger Spin",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Tomorrowland Speedway",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Astro Orbiter",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true),

        // Seeder name is the short-form "PeopleMover"; official sign and API use
        // the full name. Alias covers exact match before substring fallback fires.
        MA("PeopleMover",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true,
           aliases: ["Tomorrowland Transit Authority PeopleMover"]),

        MA("Tron Lightcycle / Run",
           park: .magicKingdom, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 1, seed: true,
           aliases: ["TRON Lightcycle / Run"]),

        // Monsters, Inc. Laugh Floor — a show-format attraction that posts a live
        // standby wait time via ThemeParks.wiki (hasLiveWaitTime: true).
        MA("Monsters, Inc. Laugh Floor",
           park: .magicKingdom, land: "Tomorrowland",
           type: .show, outdoor: false, map: 3, seed: true,
           hasLiveWaitTime: true),

        // ── Character Meet & Greets ───────────────────────────────────────────
        // map: nil until GPS coordinates are added to MapCoordinates.json.
        // shouldSeed: true so these appear in the All Attractions list.

        MA("Mickey Mouse at Town Square Theater",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .characterMeet, outdoor: false, map: nil, seed: true),

        MA("Princess Fairytale Hall",
           park: .magicKingdom, land: "Fantasyland",
           type: .characterMeet, outdoor: false, map: nil, seed: true,
           aliases: [
               "Princess Fairytale Hall Featuring Cinderella",
               "Princess Fairytale Hall Featuring Rapunzel",
               "Princess Fairytale Hall Featuring Tiana",
           ]),

        MA("Pete's Silly Sideshow",
           park: .magicKingdom, land: "Fantasyland",
           type: .characterMeet, outdoor: false, map: nil, seed: true),

        MA("Tinker Bell at Town Square Theater",
           park: .magicKingdom, land: "Main Street, U.S.A.",
           type: .characterMeet, outdoor: false, map: nil, seed: true),
    ]
}

// MARK: - Walt Disney World — EPCOT

private extension RideMasterData {

    static let epcotAttractions: [MasterAttraction] = [

        // ── World Celebration ─────────────────────────────────────────────────
        MA("Spaceship Earth",
           park: .epcot, land: "World Celebration",
           type: .ride, outdoor: false, map: 2, seed: true),

        // Previously missing from RideSeeder and MapCoordinates.json.
        // Journey Into Imagination With Figment has a live posted wait time
        // and is a guest-favourite EPCOT ride — it must be seeded.
        MA("Journey Into Imagination With Figment",
           park: .epcot, land: "World Celebration",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["Journey Into Imagination with Figment", "Journey Into Imagination"]),

        // ── World Discovery ───────────────────────────────────────────────────
        MA("Guardians of the Galaxy: Cosmic Rewind",
           park: .epcot, land: "World Discovery",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Mission: SPACE",
           park: .epcot, land: "World Discovery",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Test Track",
           park: .epcot, land: "World Discovery",
           type: .ride, outdoor: false, map: 1, seed: true),

        // ── World Nature ──────────────────────────────────────────────────────
        // "Soarin' Across America" variant scheduled to replace "Soarin' Around the World"
        // from July 2, 2026; alias added ahead of the changeover so the wait time
        // continues to display correctly on both versions of the API name.
        MA("Soarin' Around the World",
           park: .epcot, land: "World Nature",
           type: .ride, outdoor: false, map: 1, seed: true,
           aliases: ["Soarin' Across America"]),

        MA("Living with the Land",
           park: .epcot, land: "World Nature",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("The Seas with Nemo & Friends",
           park: .epcot, land: "World Nature",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Turtle Talk with Crush",
           park: .epcot, land: "World Nature",
           type: .show, outdoor: false, map: nil, seed: false),

        // Journey of Water, Inspired by Moana — self-guided outdoor walkthrough;
        // no queue, no posted wait time.
        MA("Journey of Water, Inspired by Moana",
           park: .epcot, land: "World Nature",
           type: .walkthrough, outdoor: true, map: nil, seed: true),

        // ── World Showcase ────────────────────────────────────────────────────
        MA("Frozen Ever After",
           park: .epcot, land: "World Showcase",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Remy's Ratatouille Adventure",
           park: .epcot, land: "World Showcase",
           type: .ride, outdoor: false, map: 2, seed: true),

        // Seeder name is the short-form; JSON rideName is the full name.
        MA("Gran Fiesta Tour",
           park: .epcot, land: "World Showcase",
           type: .ride, outdoor: false, map: 3, seed: true,
           aliases: ["Gran Fiesta Tour Starring The Three Caballeros"]),

        // ── Character Meet & Greets ───────────────────────────────────────────
        MA("Disney Character Spot",
           park: .epcot, land: "World Celebration",
           type: .characterMeet, outdoor: false, map: nil, seed: true),

        // Figment at ImageWorks — character meet inside the Imagination pavilion.
        MA("Figment at ImageWorks",
           park: .epcot, land: "World Celebration",
           type: .characterMeet, outdoor: false, map: nil, seed: true),
    ]
}

// MARK: - Walt Disney World — Hollywood Studios

private extension RideMasterData {

    static let dhsAttractions: [MasterAttraction] = [

        // ── Hollywood Boulevard ───────────────────────────────────────────────
        MA("Mickey & Minnie's Runaway Railway",
           park: .hollywoodStudios, land: "Hollywood Boulevard",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Echo Lake ─────────────────────────────────────────────────────────
        // En-dash U+2013 in name; API may return a colon variant.
        // WaitTimeViewModel.normalizedForMatching converts both separators to space,
        // so matching works without an alias — but include it for exact-match speed.
        MA("Star Tours \u{2013} The Adventures Continue",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["Star Tours: The Adventures Continue"]),

        MA("Indiana Jones Epic Stunt Spectacular!",
           park: .hollywoodStudios, land: "Echo Lake",
           type: .show, outdoor: true, map: nil, seed: false),

        // ── Sunset Boulevard ──────────────────────────────────────────────────
        MA("The Twilight Zone Tower of Terror",
           park: .hollywoodStudios, land: "Sunset Boulevard",
           type: .ride, outdoor: false, map: 1, seed: true),

        // CRITICAL alias: ride was rebranded from Aerosmith to The Muppets (2025).
        // ThemeParks.wiki may still return the Aerosmith name. Without this alias,
        // the live wait time silently fails to match on the Home screen and map.
        MA("Rock 'n' Roller Coaster Starring The Muppets",
           park: .hollywoodStudios, land: "Sunset Boulevard",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: [
               "Rock 'n' Roller Coaster Starring Aerosmith",
               "Rock 'n' Roller Coaster",
           ]),

        // ── Toy Story Land ────────────────────────────────────────────────────
        MA("Slinky Dog Dash",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Alien Swirling Saucers",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Toy Story Mania!",
           park: .hollywoodStudios, land: "Toy Story Land",
           type: .ride, outdoor: false, map: 3, seed: true),

        // ── Star Wars: Galaxy's Edge ──────────────────────────────────────────
        MA("Star Wars: Rise of the Resistance",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Millennium Falcon: Smugglers Run",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .ride, outdoor: false, map: 1, seed: true),

        // ── Character Meet & Greets ───────────────────────────────────────────
        MA("Star Wars Character Experiences",
           park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge",
           type: .characterMeet, outdoor: true, map: nil, seed: true),

        MA("Disney Characters at Launch Bay",
           park: .hollywoodStudios, land: "Hollywood Boulevard",
           type: .characterMeet, outdoor: false, map: nil, seed: true),
    ]
}

// MARK: - Walt Disney World — Animal Kingdom

private extension RideMasterData {

    static let akAttractions: [MasterAttraction] = [

        // ── Discovery Island ──────────────────────────────────────────────────
        // Zootopia: Better Zoogether! is a standby-queue show experience that
        // posts a live wait time — keep seeded and live-wait eligible.
        MA("Zootopia: Better Zoogether!",
           park: .animalKingdom, land: "Discovery Island",
           type: .show, outdoor: true, map: 3, seed: true,
           hasLiveWaitTime: true),

        // ── Africa ────────────────────────────────────────────────────────────
        MA("Kilimanjaro Safaris",
           park: .animalKingdom, land: "Africa",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Gorilla Falls Exploration Trail",
           park: .animalKingdom, land: "Africa",
           type: .walkthrough, outdoor: true, map: nil, seed: false),

        // Wildlife Express Train connects Africa to Rafiki's Planet Watch.
        MA("Wildlife Express Train",
           park: .animalKingdom, land: "Africa",
           type: .transport, outdoor: true, map: nil, seed: false),

        // ── Asia ──────────────────────────────────────────────────────────────
        // Seeder name is the short-form; JSON rideName and API use the full subtitle.
        MA("Expedition Everest",
           park: .animalKingdom, land: "Asia",
           type: .ride, outdoor: true, map: 1, seed: true,
           aliases: [
               "Expedition Everest - Legend of the Forbidden Mountain",
               "Expedition Everest: Legend of the Forbidden Mountain",
           ]),

        MA("Kali River Rapids",
           park: .animalKingdom, land: "Asia",
           type: .ride, outdoor: true, map: 2, seed: true),

        MA("Maharajah Jungle Trek",
           park: .animalKingdom, land: "Asia",
           type: .walkthrough, outdoor: true, map: nil, seed: false),

        // ── Pandora – The World of Avatar ─────────────────────────────────────
        MA("Avatar Flight of Passage",
           park: .animalKingdom, land: "Pandora",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Na'vi River Journey",
           park: .animalKingdom, land: "Pandora",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Shows ─────────────────────────────────────────────────────────────
        // Festival of the Lion King — indoor, Africa theatre; no live wait time.
        MA("Festival of the Lion King",
           park: .animalKingdom, land: "Africa",
           type: .show, outdoor: false, map: nil, seed: true),

        // UP! A Great Bird Adventure — outdoor amphitheatre, Asia.
        MA("UP! A Great Bird Adventure",
           park: .animalKingdom, land: "Asia",
           type: .show, outdoor: false, map: nil, seed: true),

        // Finding Nemo: The Big Blue...and Beyond! — formerly Theater in the Wild
        // (DinoLand U.S.A.); venue persists post-DinoLand transformation (April 2026).
        // Land assignment may need correction once the new area name is confirmed.
        MA("Finding Nemo: The Big Blue...and Beyond!",
           park: .animalKingdom, land: "Discovery Island",
           type: .show, outdoor: false, map: nil, seed: true),

        // ── Character Meet & Greets ───────────────────────────────────────────
        // Canonical stable ID uses the original seeder name.
        // "Adventurers Outpost" is the current ThemeParks.wiki entity name —
        // added as an alias so wait-time and map lookups match without a stableID rename.
        MA("Character Greetings at Discovery Island",
           park: .animalKingdom, land: "Discovery Island",
           type: .characterMeet, outdoor: true, map: nil, seed: true,
           aliases: ["Adventurers Outpost"]),
    ]
}

// MARK: - Disneyland

private extension RideMasterData {

    static let disneylandAttractions: [MasterAttraction] = [

        // ── Main Street, U.S.A. ───────────────────────────────────────────────
        MA("Disneyland Railroad",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .transport, outdoor: true, map: 3, seed: true),

        MA("Main Street Vehicles",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .transport, outdoor: true, map: 3, seed: true),

        // ── Adventureland ─────────────────────────────────────────────────────
        MA("Jungle Cruise",
           park: .disneyland, land: "Adventureland",
           type: .ride, outdoor: true, map: 2, seed: true),

        MA("Indiana Jones Adventure",
           park: .disneyland, land: "Adventureland",
           type: .ride, outdoor: false, map: 1, seed: true,
           aliases: ["Indiana Jones Adventure: Temple of the Forbidden Eye"]),

        MA("Enchanted Tiki Room",
           park: .disneyland, land: "Adventureland",
           type: .show, outdoor: false, map: 3, seed: true),

        // ── New Orleans Square ────────────────────────────────────────────────
        MA("Pirates of the Caribbean",
           park: .disneyland, land: "New Orleans Square",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Haunted Mansion",
           park: .disneyland, land: "New Orleans Square",
           type: .ride, outdoor: false, map: 1, seed: true,
           aliases: ["The Haunted Mansion"]),

        // ── Critter Country ───────────────────────────────────────────────────
        MA("The Many Adventures of Winnie the Pooh",
           park: .disneyland, land: "Critter Country",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Tiana's Bayou Adventure",
           park: .disneyland, land: "Critter Country",
           type: .ride, outdoor: true, map: 2, seed: true),

        // ── Frontierland ──────────────────────────────────────────────────────
        MA("Big Thunder Mountain Railroad",
           park: .disneyland, land: "Frontierland",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Sailing Ship Columbia",
           park: .disneyland, land: "Frontierland",
           type: .transport, outdoor: true, map: 3, seed: true),

        MA("Mark Twain Riverboat",
           park: .disneyland, land: "Frontierland",
           type: .transport, outdoor: true, map: 3, seed: true),

        MA("Pirate's Lair on Tom Sawyer Island",
           park: .disneyland, land: "Frontierland",
           type: .walkthrough, outdoor: true, map: 3, seed: true),

        // ── Fantasyland ───────────────────────────────────────────────────────
        MA("Matterhorn Bobsleds",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("It's a Small World",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 3, seed: true,
           aliases: ["it's a small world"]),

        MA("Peter Pan's Flight",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Snow White's Enchanted Wish",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Pinocchio's Daring Journey",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 3, seed: true),

        MA("Mr. Toad's Wild Ride",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 3, seed: true),

        MA("Alice in Wonderland",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: false, map: 3, seed: true),

        MA("Casey Jr. Circus Train",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Storybook Land Canal Boats",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Dumbo the Flying Elephant",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("King Arthur Carrousel",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Mad Tea Party",
           park: .disneyland, land: "Fantasyland",
           type: .ride, outdoor: true, map: 3, seed: true),

        // ── Mickey's Toontown ─────────────────────────────────────────────────
        MA("Mickey & Minnie's Runaway Railway",
           park: .disneyland, land: "Mickey's Toontown",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Chip 'n' Dale's GADGETcoaster",
           park: .disneyland, land: "Mickey's Toontown",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Roger Rabbit's Car Toon Spin",
           park: .disneyland, land: "Mickey's Toontown",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Tomorrowland ──────────────────────────────────────────────────────
        MA("Space Mountain",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Star Tours \u{2013} The Adventures Continue",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["Star Tours: The Adventures Continue"]),

        MA("Buzz Lightyear Astro Blasters",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Autopia",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Finding Nemo Submarine Voyage",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Astro Orbitor",
           park: .disneyland, land: "Tomorrowland",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Disneyland Monorail",
           park: .disneyland, land: "Tomorrowland",
           type: .transport, outdoor: true, map: 3, seed: true),

        // ── Star Wars: Galaxy's Edge ──────────────────────────────────────────
        MA("Star Wars: Rise of the Resistance",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("Millennium Falcon: Smugglers Run",
           park: .disneyland, land: "Star Wars: Galaxy's Edge",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Character Meet & Greets ───────────────────────────────────────────
        MA("Mickey & Friends Character Greetings",
           park: .disneyland, land: "Mickey's Toontown",
           type: .characterMeet, outdoor: true, map: nil, seed: true),

        MA("Character Greetings at Town Square",
           park: .disneyland, land: "Main Street, U.S.A.",
           type: .characterMeet, outdoor: false, map: nil, seed: true),
    ]
}

// MARK: - Disney California Adventure

private extension RideMasterData {

    static let dcaAttractions: [MasterAttraction] = [

        // ── Buena Vista Street ────────────────────────────────────────────────
        MA("Red Car Trolley",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .transport, outdoor: true, map: 3, seed: true),

        // ── Hollywood Land ────────────────────────────────────────────────────
        MA("Monsters, Inc. Mike & Sulley to the Rescue!",
           park: .californiaAdventure, land: "Hollywood Land",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Avengers Campus ───────────────────────────────────────────────────
        MA("Guardians of the Galaxy \u{2013} Mission: BREAKOUT!",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .ride, outdoor: false, map: 1, seed: true),

        MA("WEB SLINGERS: A Spider-Man Adventure",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .ride, outdoor: false, map: 2, seed: true),

        // ── Cars Land ─────────────────────────────────────────────────────────
        MA("Radiator Springs Racers",
           park: .californiaAdventure, land: "Cars Land",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Luigi's Rollickin' Roadsters",
           park: .californiaAdventure, land: "Cars Land",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Mater's Junkyard Jamboree",
           park: .californiaAdventure, land: "Cars Land",
           type: .ride, outdoor: true, map: 3, seed: true),

        // ── Pixar Pier ────────────────────────────────────────────────────────
        MA("Incredicoaster",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: true, map: 1, seed: true),

        MA("Toy Story Midway Mania!",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: false, map: 2, seed: true),

        MA("Pixar Pal-A-Round",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Inside Out Emotional Whirlwind",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: true, map: 2, seed: true),

        MA("Jessie's Critter Carousel",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("The Little Mermaid \u{2013} Ariel's Undersea Adventure",
           park: .californiaAdventure, land: "Pixar Pier",
           type: .ride, outdoor: false, map: 3, seed: true),

        // ── Paradise Gardens Park ─────────────────────────────────────────────
        MA("Goofy's Sky School",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Silly Symphony Swings",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .ride, outdoor: true, map: 3, seed: true),

        MA("Golden Zephyr",
           park: .californiaAdventure, land: "Paradise Gardens Park",
           type: .ride, outdoor: true, map: 3, seed: true),

        // ── Grizzly Peak ──────────────────────────────────────────────────────
        // DCA's Soarin' may be reported by the API as any of several variant names.
        // The MapViewModel already has a special-case prefix check for "soarin" —
        // aliases are added here for the WaitTimeViewModel path and for completeness.
        // "Soarin' Across America" variant scheduled from July 2, 2026; alias added
        // ahead of the changeover (same as the EPCOT entry).
        MA("Soarin'",
           park: .californiaAdventure, land: "Grizzly Peak",
           type: .ride, outdoor: false, map: 2, seed: true,
           aliases: ["Soarin' Around the World", "Soarin' Over California", "Soarin' Across America"]),

        MA("Grizzly River Run",
           park: .californiaAdventure, land: "Grizzly Peak",
           type: .ride, outdoor: true, map: 2, seed: true),

        // ── Character Meet & Greets ───────────────────────────────────────────
        MA("Marvel Character Greetings",
           park: .californiaAdventure, land: "Avengers Campus",
           type: .characterMeet, outdoor: true, map: nil, seed: true),

        MA("Character Greetings at Buena Vista Street",
           park: .californiaAdventure, land: "Buena Vista Street",
           type: .characterMeet, outdoor: true, map: nil, seed: true),
    ]
}

// MARK: - DEBUG validation

#if DEBUG
extension RideMasterData {

    /// Run at app launch (DEBUG only) to catch data integrity issues early.
    static func validate() {
        var issues = 0

        // ── 1. Duplicate stable IDs ─────────────────────────────────────────
        let ids = all.map(\.stableID)
        let dupIDs = Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }.keys.sorted()
        for id in dupIDs {
            print("⚠️ RideMasterData: duplicate stableID '\(id)'")
            issues += 1
        }

        // ── 2. Missing land ─────────────────────────────────────────────────
        for a in all where a.land.isEmpty {
            print("⚠️ RideMasterData: '\(a.name)' [\(a.park.rawValue)] has an empty land")
            issues += 1
        }

        // ── 3. Park / land consistency against Park.lands ──────────────────
        for a in all {
            if !a.park.lands.contains(a.land) {
                print("⚠️ RideMasterData: '\(a.name)' land '\(a.land)' is not in Park.lands for \(a.park.rawValue)")
                issues += 1
            }
        }

        // ── 4. Seeded rides should have a map priority ─────────────────────
        //    (missing coordinates in MapCoordinates.json is caught separately
        //     by MapCoordinateService.validate — just flag the priority gap here)
        for a in all where a.shouldSeed && a.mapPriority == nil {
            print("ℹ️ RideMasterData: '\(a.name)' [\(a.park.rawValue)] is seeded but has no map priority — add coordinates if it should appear on the map")
        }

        // ── 5. Aliases on non-wait-time attractions ────────────────────────
        //    Aliases drive WaitTimeViewModel name matching; they are also used
        //    by MapViewModel for coordinate lookups. Having them on an attraction
        //    with shouldUseLiveWaitTimes=false is informational (used for map
        //    matching) but won't affect wait-time display. Logged here so the
        //    data author can confirm intent.
        for a in all where !a.shouldUseLiveWaitTimes && !a.aliases.isEmpty {
            print("ℹ️ RideMasterData: '\(a.name)' has aliases but shouldUseLiveWaitTimes=false — aliases used for map matching only")
        }

        // ── 6. DinoLand U.S.A. removed — assert no re-introduction ────────
        //    DINOSAUR and DinoLand U.S.A. were removed from Animal Kingdom
        //    in April 2026. This guard prevents accidental re-addition.
        let dinolandEntries = all.filter {
            $0.park == .animalKingdom && $0.land == "DinoLand U.S.A."
        }
        for entry in dinolandEntries {
            print("⚠️ RideMasterData: '\(entry.name)' is listed under DinoLand U.S.A. (Animal Kingdom) — this land was removed; use a different land or remove the attraction.")
            issues += 1
        }

        // ── 7. ThemeParks entity ID coverage ──────────────────────────────
        //    Seeded rides without a themeparksEntityId fall back to name-based
        //    wait-time matching; flagged as informational (not an error) until
        //    IDs are confirmed via:
        //    GET https://api.themeparks.wiki/v1/entity/{park.themeparksEntityId}/live
        let seedableWithMap   = seedableAttractions.filter { $0.mapPriority != nil }
        let withEntityId      = seedableWithMap.filter { $0.themeparksEntityId != nil }
        let missingEntityId   = seedableWithMap.filter { $0.themeparksEntityId == nil }
        if missingEntityId.isEmpty {
            print("✅ RideMasterData: all \(seedableWithMap.count) map-eligible seeded rides have ThemeParks entity IDs.")
        } else {
            print("ℹ️ RideMasterData: ThemeParks entity ID coverage \(withEntityId.count)/\(seedableWithMap.count) — \(missingEntityId.count) seeded map rides missing IDs:")
            let byPark = Dictionary(grouping: missingEntityId, by: { $0.park.rawValue })
            for parkKey in byPark.keys.sorted() {
                let names = byPark[parkKey]!.map(\.name).sorted()
                print("  [\(parkKey)] — \(names.joined(separator: ", "))")
            }
            print("  → Confirm IDs via GET https://api.themeparks.wiki/v1/entity/{park.themeparksEntityId}/live")
            print("  → Then add entityId: \"<uuid>\" to each MasterAttraction and its MapCoordinates.json entry.")
        }

        if issues == 0 {
            print("✅ RideMasterData: all \(all.count) attractions passed validation (\(seedableAttractions.count) seeded)")
        } else {
            print("⚠️ RideMasterData: \(issues) issue(s) found — see above")
        }
    }
}
#endif

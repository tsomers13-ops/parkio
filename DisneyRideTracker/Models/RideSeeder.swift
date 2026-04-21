//
//  RideSeeder.swift
//  DisneyRideTracker
//
//  Populates the SwiftData store with the canonical ride list on first launch,
//  and migrates older schemas in place so user logs are preserved across
//  structural changes to the park/land hierarchy.
//

import Foundation
import SwiftData

enum RideSeeder {

    /// A structural description of a ride used only for seeding.
    struct Seed {
        let name: String
        let park: Park
        let land: String
    }

    /// Older schemas may have used different park names (e.g. the initial
    /// release grouped all four WDW parks under the single park "Walt Disney
    /// World"). When we look for an existing ride to migrate, we also try
    /// these legacy park names keyed by current park.
    private static let legacyParkNames: [Park: [String]] = [
        .magicKingdom:      ["Walt Disney World"],
        .epcot:             ["Walt Disney World"],
        .hollywoodStudios:  ["Walt Disney World"],
        .animalKingdom:     ["Walt Disney World"]
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Ride>()
        let existing = (try? context.fetch(descriptor)) ?? []

        // Look up existing rides by id AND by (park, name) so we can migrate a
        // ride whose land was renamed — or whose park was split into several
        // sub-parks — without losing the user's logged dates.
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var byParkName: [String: Ride] = [:]
        for ride in existing {
            byParkName["\(ride.park)|\(ride.name)"] = ride
        }

        var seenIDs = Set<String>()

        for (index, seed) in allSeeds.enumerated() {
            let newID = seed.stableID
            seenIDs.insert(newID)

            // 1. Exact id match — schema already current.
            if let ride = byID[newID] {
                ride.order = index
                continue
            }

            // 2. Same current park + ride name — land was renamed.
            if let ride = byParkName["\(seed.park.rawValue)|\(seed.name)"] {
                ride.id = newID
                ride.land = seed.land
                ride.order = index
                byID[newID] = ride
                continue
            }

            // 3. Legacy park rename (e.g. "Walt Disney World" → "Magic Kingdom").
            if let legacy = legacyParkNames[seed.park] {
                var migrated = false
                for legacyPark in legacy {
                    if let ride = byParkName["\(legacyPark)|\(seed.name)"] {
                        ride.id = newID
                        ride.park = seed.park.rawValue
                        ride.land = seed.land
                        ride.order = index
                        byID[newID] = ride
                        migrated = true
                        break
                    }
                }
                if migrated { continue }
            }

            // 4. Brand new ride.
            let ride = Ride(
                id: newID,
                name: seed.name,
                park: seed.park.rawValue,
                land: seed.land,
                order: index
            )
            context.insert(ride)
            byID[newID] = ride
        }

        // Remove rides that are no longer in the canonical list (e.g. retired
        // attractions, or stale rows from an older schema). Logs cascade-delete.
        for ride in existing where !seenIDs.contains(ride.id) {
            context.delete(ride)
        }

        try? context.save()
    }

    // MARK: - Ride List

    static let allSeeds: [Seed] = mkSeeds + epcotSeeds + dhsSeeds + akSeeds + disneylandSeeds + dcaSeeds

    static var canonicalRideIDs: Set<String> {
        Set(allSeeds.map(\.stableID))
    }

    // MARK: Walt Disney World — Magic Kingdom

    private static let mkSeeds: [Seed] = [
        // Adventureland
        Seed(name: "Pirates of the Caribbean",                  park: .magicKingdom, land: "Adventureland"),
        Seed(name: "Walt Disney's Enchanted Tiki Room",         park: .magicKingdom, land: "Adventureland"),

        // Frontierland
        Seed(name: "Big Thunder Mountain Railroad",             park: .magicKingdom, land: "Frontierland"),
        Seed(name: "Tiana's Bayou Adventure",                   park: .magicKingdom, land: "Frontierland"),
        Seed(name: "Country Bear Jamboree",                     park: .magicKingdom, land: "Frontierland"),

        // Liberty Square
        Seed(name: "Haunted Mansion",                           park: .magicKingdom, land: "Liberty Square"),

        // Fantasyland
        Seed(name: "Seven Dwarfs Mine Train",                   park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "Peter Pan's Flight",                        park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "it's a small world",                        park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "The Barnstormer",                           park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "Dumbo the Flying Elephant",                 park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "Under the Sea: Journey of the Little Mermaid", park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "Prince Charming Regal Carrousel",           park: .magicKingdom, land: "Fantasyland"),
        Seed(name: "Mad Tea Party",                             park: .magicKingdom, land: "Fantasyland"),

        // Tomorrowland
        Seed(name: "Space Mountain",                            park: .magicKingdom, land: "Tomorrowland"),
        Seed(name: "Tomorrowland Speedway",                     park: .magicKingdom, land: "Tomorrowland"),
        Seed(name: "Buzz Lightyear's Space Ranger Spin",        park: .magicKingdom, land: "Tomorrowland"),
        Seed(name: "Carousel of Progress",                      park: .magicKingdom, land: "Tomorrowland"),
        Seed(name: "Astro Orbiter",                             park: .magicKingdom, land: "Tomorrowland")
    ]

    // MARK: Walt Disney World — EPCOT

    private static let epcotSeeds: [Seed] = [
        // World Celebration
        Seed(name: "Spaceship Earth",                           park: .epcot, land: "World Celebration"),

        // World Discovery
        Seed(name: "Guardians of the Galaxy: Cosmic Rewind",    park: .epcot, land: "World Discovery"),
        Seed(name: "Test Track",                                park: .epcot, land: "World Discovery"),
        Seed(name: "Mission: SPACE",                            park: .epcot, land: "World Discovery"),

        // World Nature
        Seed(name: "Soarin' Around the World",                  park: .epcot, land: "World Nature"),
        Seed(name: "Journey Into Imagination with Figment",     park: .epcot, land: "World Nature"),
        Seed(name: "Living with the Land",                      park: .epcot, land: "World Nature"),
        Seed(name: "The Seas with Nemo & Friends",              park: .epcot, land: "World Nature"),
        Seed(name: "Journey of Water",                          park: .epcot, land: "World Nature"),

        // World Showcase
        Seed(name: "Remy's Ratatouille Adventure",              park: .epcot, land: "World Showcase"),
        Seed(name: "Gran Fiesta Tour Starring The Three Caballeros", park: .epcot, land: "World Showcase"),
        Seed(name: "Frozen Ever After",                         park: .epcot, land: "World Showcase")
    ]

    // MARK: Walt Disney World — Hollywood Studios

    private static let dhsSeeds: [Seed] = [
        // Hollywood Boulevard
        Seed(name: "Mickey & Minnie's Runaway Railway",         park: .hollywoodStudios, land: "Hollywood Boulevard"),

        // Echo Lake
        Seed(name: "Star Tours",                                park: .hollywoodStudios, land: "Echo Lake"),

        // Sunset Boulevard
        Seed(name: "Tower of Terror",                           park: .hollywoodStudios, land: "Sunset Boulevard"),
        Seed(name: "Rock 'n' Roller Coaster Starring Aerosmith",park: .hollywoodStudios, land: "Sunset Boulevard"),
        Seed(name: "Tiana's Bayou Adventure (DHS)",             park: .hollywoodStudios, land: "Sunset Boulevard"),

        // Toy Story Land
        Seed(name: "Slinky Dog Dash",                           park: .hollywoodStudios, land: "Toy Story Land"),
        Seed(name: "Toy Story Mania!",                          park: .hollywoodStudios, land: "Toy Story Land"),
        Seed(name: "Alien Swirling Saucers",                    park: .hollywoodStudios, land: "Toy Story Land"),

        // Star Wars: Galaxy's Edge
        Seed(name: "Star Wars: Rise of the Resistance",         park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge"),
        Seed(name: "Millennium Falcon: Smugglers Run",          park: .hollywoodStudios, land: "Star Wars: Galaxy's Edge")
    ]

    // MARK: Walt Disney World — Animal Kingdom

    private static let akSeeds: [Seed] = [
        // Pandora – The World of Avatar
        Seed(name: "Avatar Flight of Passage",                  park: .animalKingdom, land: "Pandora"),
        Seed(name: "Na'vi River Journey",                       park: .animalKingdom, land: "Pandora"),

        // Africa
        Seed(name: "Kilimanjaro Safaris",                       park: .animalKingdom, land: "Africa"),
        Seed(name: "Wildlife Express Train",                    park: .animalKingdom, land: "Africa"),

        // Asia
        Seed(name: "Expedition Everest",                        park: .animalKingdom, land: "Asia"),
        Seed(name: "Kali River Rapids",                         park: .animalKingdom, land: "Asia"),

        // DinoLand U.S.A.
        Seed(name: "DINOSAUR",                                  park: .animalKingdom, land: "DinoLand U.S.A."),
        Seed(name: "TriceraTop Spin",                           park: .animalKingdom, land: "DinoLand U.S.A.")
    ]

    // MARK: Disneyland

    private static let disneylandSeeds: [Seed] = [
        // Main Street
        Seed(name: "Disneyland Railroad",                       park: .disneyland, land: "Main Street"),
        Seed(name: "Main Street Vehicles",                      park: .disneyland, land: "Main Street"),

        // Adventureland
        Seed(name: "Pirates of the Caribbean",                  park: .disneyland, land: "Adventureland"),
        Seed(name: "Indiana Jones Adventure",                   park: .disneyland, land: "Adventureland"),
        Seed(name: "Jungle Cruise",                             park: .disneyland, land: "Adventureland"),
        Seed(name: "Enchanted Tiki Room",                       park: .disneyland, land: "Adventureland"),

        // Frontierland
        Seed(name: "Big Thunder Mountain Railroad",             park: .disneyland, land: "Frontierland"),
        Seed(name: "Tiana's Bayou Adventure",                   park: .disneyland, land: "Frontierland"),
        Seed(name: "Mark Twain Riverboat",                      park: .disneyland, land: "Frontierland"),
        Seed(name: "Sailing Ship Columbia",                     park: .disneyland, land: "Frontierland"),
        Seed(name: "Pirate's Lair on Tom Sawyer Island",        park: .disneyland, land: "Frontierland"),

        // Fantasyland
        Seed(name: "Matterhorn Bobsleds",                       park: .disneyland, land: "Fantasyland"),
        Seed(name: "Peter Pan's Flight",                        park: .disneyland, land: "Fantasyland"),
        Seed(name: "it's a small world",                        park: .disneyland, land: "Fantasyland"),
        Seed(name: "Snow White's Enchanted Wish",               park: .disneyland, land: "Fantasyland"),
        Seed(name: "Mr. Toad's Wild Ride",                      park: .disneyland, land: "Fantasyland"),
        Seed(name: "Dumbo the Flying Elephant",                 park: .disneyland, land: "Fantasyland"),
        Seed(name: "King Arthur Carrousel",                     park: .disneyland, land: "Fantasyland"),
        Seed(name: "Mad Tea Party",                             park: .disneyland, land: "Fantasyland"),
        Seed(name: "Pinocchio's Daring Journey",                park: .disneyland, land: "Fantasyland"),

        // Tomorrowland
        Seed(name: "Space Mountain",                            park: .disneyland, land: "Tomorrowland"),
        Seed(name: "Buzz Lightyear Astro Blasters",             park: .disneyland, land: "Tomorrowland"),
        Seed(name: "Autopia",                                   park: .disneyland, land: "Tomorrowland"),
        Seed(name: "Astro Orbitor",                             park: .disneyland, land: "Tomorrowland"),
        Seed(name: "Finding Nemo Submarine Voyage",             park: .disneyland, land: "Tomorrowland"),
        Seed(name: "Star Wars Hyperspace Mountain",             park: .disneyland, land: "Tomorrowland"),

        // Star Wars: Galaxy's Edge
        Seed(name: "Star Wars: Rise of the Resistance",         park: .disneyland, land: "Star Wars: Galaxy's Edge"),
        Seed(name: "Millennium Falcon: Smugglers Run",          park: .disneyland, land: "Star Wars: Galaxy's Edge"),

        // Mickey's Toontown
        Seed(name: "Roger Rabbit's Car Toon Spin",              park: .disneyland, land: "Mickey's Toontown"),
        Seed(name: "Mickey & Minnie's Runaway Railway",         park: .disneyland, land: "Mickey's Toontown"),
        Seed(name: "Chip 'n' Dale's GADGETcoaster",             park: .disneyland, land: "Mickey's Toontown")
    ]

    // MARK: Disney California Adventure

    private static let dcaSeeds: [Seed] = [
        // Buena Vista Street
        Seed(name: "Red Car Trolley",                           park: .californiaAdventure, land: "Buena Vista Street"),

        // Hollywood Land
        Seed(name: "Guardians of the Galaxy: Mission Breakout!", park: .californiaAdventure, land: "Hollywood Land"),
        Seed(name: "WEB SLINGERS: A Spider-Man Adventure",       park: .californiaAdventure, land: "Hollywood Land"),
        Seed(name: "Monsters Inc. Mike & Sulley to the Rescue!", park: .californiaAdventure, land: "Hollywood Land"),

        // Avengers Campus
        Seed(name: "WEB SLINGERS: A Spider-Man Adventure (AC)",  park: .californiaAdventure, land: "Avengers Campus"),
        Seed(name: "Avengers Assemble: Flight Force",            park: .californiaAdventure, land: "Avengers Campus"),

        // Cars Land
        Seed(name: "Radiator Springs Racers",                    park: .californiaAdventure, land: "Cars Land"),
        Seed(name: "Mater's Junkyard Jamboree",                  park: .californiaAdventure, land: "Cars Land"),
        Seed(name: "Luigi's Rollickin' Roadsters",               park: .californiaAdventure, land: "Cars Land"),

        // Grizzly Peak
        Seed(name: "Grizzly River Run",                          park: .californiaAdventure, land: "Grizzly Peak"),
        Seed(name: "Soarin' Around the World",                   park: .californiaAdventure, land: "Grizzly Peak"),

        // Pixar Pier
        Seed(name: "Incredicoaster",                             park: .californiaAdventure, land: "Pixar Pier"),
        Seed(name: "Toy Story Midway Mania!",                    park: .californiaAdventure, land: "Pixar Pier"),
        Seed(name: "Inside Out Emotional Whirlwind",             park: .californiaAdventure, land: "Pixar Pier"),
        Seed(name: "Jessie's Critter Carousel",                  park: .californiaAdventure, land: "Pixar Pier"),
        Seed(name: "Pixar Pal-A-Round",                          park: .californiaAdventure, land: "Pixar Pier"),

        // Paradise Gardens Park
        Seed(name: "Goofy's Sky School",                         park: .californiaAdventure, land: "Paradise Gardens Park"),
        Seed(name: "Jumpin' Jellyfish",                          park: .californiaAdventure, land: "Paradise Gardens Park"),
        Seed(name: "Golden Zephyr",                              park: .californiaAdventure, land: "Paradise Gardens Park")
    ]
}

private extension RideSeeder.Seed {
    /// Deterministic unique ID so we can add new rides in later versions of the
    /// app without duplicating rides that already exist in the user's database.
    var stableID: String {
        "\(park.rawValue)|\(land)|\(name)"
    }
}

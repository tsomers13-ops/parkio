// RideCoordinateTable.swift — Priority assignments for map annotation visibility.
//
// Purpose:
//   RideAnnotation.priority determines zoom-gated visibility on the real MapKit map:
//     1 = always visible (hero rides — the first thing guests look for)
//     2 = visible at park zoom level (~1–2 km span)
//     3 = visible only when zoomed in (~500 m span or tighter)
//
// Lookup:
//   RideCoordinateTable.priority(for:parkId:) accepts a rideName (case-insensitive)
//   and returns 1, 2, or 3. Any ride not listed defaults to 2.
//
// Maintenance:
//   Only add to priority-1 if a ride is genuinely iconic and guests plan their day
//   around it. Currently capped at 4–5 per park to keep the default view readable.

import Foundation

// MARK: - RideCoordinateTable

enum RideCoordinateTable {

    // MARK: - Priority lookup

    /// Returns the display priority (1–3) for a ride by name and park.
    /// Case-insensitive match. Returns 2 for any unregistered ride.
    static func priority(for rideName: String, parkId: String) -> Int {
        let key = rideName.lowercased()
        return tables[parkId]?[key] ?? 2
    }

    // MARK: - Priority tables (per park)

    private static let tables: [String: [String: Int]] = [

        // MARK: Magic Kingdom
        "magic-kingdom": [
            "space mountain":                                    1,
            "tron lightcycle / run":                             1,
            "seven dwarfs mine train":                           1,
            "haunted mansion":                                   1,
            "big thunder mountain railroad":                     1,
            "peter pan's flight":                                2,
            "it's a small world":                                2,
            "pirates of the caribbean":                          2,
            "tiana's bayou adventure":                           2,
            "jungle cruise":                                     2,
            "buzz lightyear's space ranger spin":                2,
            "the many adventures of winnie the pooh":            2,
            "under the sea ~ journey of the little mermaid":     2,
            "mad tea party":                                     3,
            "dumbo the flying elephant":                         3,
            "astro orbiter":                                     3,
            "tomorrowland speedway":                             3,
            "the magic carpets of aladdin":                      3,
            "liberty belle riverboat":                           3,
            "walt disney world railroad":                        3,
        ],

        // MARK: EPCOT
        "epcot": [
            "guardians of the galaxy: cosmic rewind":            1,
            "test track":                                        1,
            "soarin' around the world":                          1,
            "frozen ever after":                                 1,
            "mission: space":                                    2,
            "remy's ratatouille adventure":                      2,
            "living with the land":                              2,
            "the seas with nemo & friends":                      2,
            "journey into imagination with figment":             3,
        ],

        // MARK: Hollywood Studios
        "hollywood-studios": [
            "star wars: rise of the resistance":                 1,
            "slinky dog dash":                                   1,
            "the twilight zone tower of terror":                 1,
            "millennium falcon: smugglers run":                  1,
            "rock 'n' roller coaster starring aerosmith":        2,
            "mickey & minnie's runaway railway":                 2,
            "toy story mania!":                                  2,
            "alien swirling saucers":                            3,
        ],

        // MARK: Animal Kingdom
        "animal-kingdom": [
            "avatar flight of passage":                          1,
            "expedition everest - legend of the forbidden mountain": 1,
            "kilimanjaro safaris":                               1,
            "na'vi river journey":                               2,
            "kali river rapids":                                 2,
            "dinosaur":                                          2,
        ],

        // MARK: Disneyland
        "disneyland": [
            "star wars: rise of the resistance":                 1,
            "indiana jones adventure":                           1,
            "matterhorn bobsleds":                               1,
            "space mountain":                                    1,
            "haunted mansion":                                   1,
            "pirates of the caribbean":                          2,
            "big thunder mountain railroad":                     2,
            "tiana's bayou adventure":                           2,
            "millennium falcon: smugglers run":                  2,
            "mickey & minnie's runaway railway":                 2,
            "jungle cruise":                                     2,
            "peter pan's flight":                                2,
            "it's a small world":                                2,
            "buzz lightyear astro blasters":                     3,
            "roger rabbit's car toon spin":                      3,
            "disneyland railroad":                               3,
        ],

        // MARK: California Adventure
        "california-adventure": [
            "radiator springs racers":                           1,
            "guardians of the galaxy - mission: breakout!":      1,
            "incredicoaster":                                    1,
            "web slingers: a spider-man adventure":              2,
            "grizzly river run":                                 2,
            "soarin' around the world":                          2,
            "inside out emotional whirlwind":                    2,
            "toy story midway mania!":                           2,
            "mater's junkyard jamboree":                         3,
            "luigi's rollickin' roadsters":                      3,
        ],
    ]
}

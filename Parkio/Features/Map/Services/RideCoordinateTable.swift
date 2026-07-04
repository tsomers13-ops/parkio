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
//
// Name matching:
//   Keys are lowercased rideName values from MapCoordinates.json.
//   Special characters (en dashes U+2013, apostrophes) must match exactly.

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
            // P1 — hero attractions
            "space mountain":                                         1,
            "tron lightcycle / run":                                  1,
            "seven dwarfs mine train":                                1,
            "haunted mansion":                                        1,
            "big thunder mountain railroad":                          1,
            // P2 — named rides visible at default park zoom
            "pirates of the caribbean":                               2,
            "jungle cruise":                                          2,
            "tiana's bayou adventure":                                2,
            "peter pan's flight":                                     2,
            "it's a small world":                                     2,
            "the many adventures of winnie the pooh":                 2,
            "under the sea \u{2013} journey of the little mermaid":   2,
            "buzz lightyear's space ranger spin":                     2,
            // P3 — secondary / kiddie / transport
            "magic carpets of aladdin":                               3,
            "prince charming regal carrousel":                        3,
            "mad tea party":                                          3,
            "dumbo the flying elephant":                              3,
            "barnstormer":                                            3,
            "tomorrowland speedway":                                  3,
            "astro orbiter":                                          3,
            "peoplemover":                                            3,
            "tomorrowland transit authority peoplemover":             3,
            "walt disney world railroad":                             3,
        ],

        // MARK: EPCOT
        "epcot": [
            // P1
            "guardians of the galaxy: cosmic rewind":                 1,
            "test track":                                             1,
            "soarin' around the world":                               1,
            "frozen ever after":                                      1,
            // P2
            "spaceship earth":                                        2,
            "journey into imagination with figment":                  2,
            "mission: space":                                         2,
            "remy's ratatouille adventure":                           2,
            "living with the land":                                   2,
            "the seas with nemo & friends":                           2,
            // P3
            "gran fiesta tour":                                       3,
            "gran fiesta tour starring the three caballeros":         3,
        ],

        // MARK: Hollywood Studios
        "hollywood-studios": [
            // P1
            "star wars: rise of the resistance":                      1,
            "slinky dog dash":                                        1,
            "the twilight zone tower of terror":                      1,
            "millennium falcon: smugglers run":                       1,
            // P2
            "rock 'n' roller coaster starring the muppets":           2,
            "mickey & minnie's runaway railway":                      2,
            "star tours: the adventures continue":                    2,
            "star tours \u{2013} the adventures continue":            2,
            // P3
            "alien swirling saucers":                                 3,
            "toy story mania!":                                       3,
        ],

        // MARK: Animal Kingdom
        "animal-kingdom": [
            // P1
            "avatar flight of passage":                               1,
            "expedition everest - legend of the forbidden mountain":  1,
            "kilimanjaro safaris":                                     1,
            // P2
            "na'vi river journey":                                    2,
            "kali river rapids":                                      2,
            // P3
            "zootopia: better zoogether!":                            3,
        ],

        // MARK: Disneyland
        "disneyland": [
            // P1
            "star wars: rise of the resistance":                      1,
            "indiana jones adventure":                                1,
            "matterhorn bobsleds":                                    1,
            "space mountain":                                         1,
            "haunted mansion":                                        1,
            "big thunder mountain railroad":                          1,
            // P2
            "pirates of the caribbean":                               2,
            "tiana's bayou adventure":                                2,
            "millennium falcon: smugglers run":                       2,
            "mickey & minnie's runaway railway":                      2,
            "jungle cruise":                                          2,
            "peter pan's flight":                                     2,
            "snow white's enchanted wish":                            2,
            "the many adventures of winnie the pooh":                 2,
            "buzz lightyear astro blasters":                          2,
            "roger rabbit's car toon spin":                           2,
            "star tours: the adventures continue":                    2,
            "star tours \u{2013} the adventures continue":            2,
            // P3
            "it's a small world":                                     3,
            "disneyland railroad":                                    3,
            "main street vehicles":                                   3,
            "sailing ship columbia":                                  3,
            "mark twain riverboat":                                   3,
            "pirate's lair on tom sawyer island":                     3,
            "enchanted tiki room":                                    3,
            "pinocchio's daring journey":                             3,
            "mr. toad's wild ride":                                   3,
            "alice in wonderland":                                    3,
            "casey jr. circus train":                                 3,
            "storybook land canal boats":                             3,
            "dumbo the flying elephant":                              3,
            "king arthur carrousel":                                  3,
            "mad tea party":                                          3,
            "chip 'n' dale's gadgetcoaster":                          3,
            "autopia":                                                3,
            "finding nemo submarine voyage":                          3,
            "astro orbitor":                                          3,
            "disneyland monorail":                                    3,
        ],

        // MARK: California Adventure
        "california-adventure": [
            // P1
            "radiator springs racers":                                1,
            "guardians of the galaxy \u{2013} mission: breakout!":   1,
            "incredicoaster":                                         1,
            // P2
            "web slingers: a spider-man adventure":                   2,
            "grizzly river run":                                      2,
            "soarin'":                                                2,
            "inside out emotional whirlwind":                         2,
            "toy story midway mania!":                                2,
            "monsters, inc. mike & sulley to the rescue!":            2,
            // P3
            "mater's junkyard jamboree":                              3,
            "luigi's rollickin' roadsters":                           3,
            "pixar pal-a-round":                                      3,
            "jessie's critter carousel":                              3,
            "the little mermaid \u{2013} ariel's undersea adventure": 3,
            "goofy's sky school":                                     3,
            "silly symphony swings":                                  3,
            "golden zephyr":                                          3,
            "red car trolley":                                        3,
        ],
    ]
}

// MARK: - DEBUG validation

#if DEBUG
extension RideCoordinateTable {

    /// Logs any ride annotation whose rideName does not resolve to a known priority entry.
    /// Runs at service init in DEBUG builds to catch name drift after ride list updates.
    static func validatePriorityLookups(annotations: [MapRideAnnotation]) {
        var unregistered: [(String, String)] = []   // (rideName, parkId)
        for ann in annotations {
            let key = ann.rideName.lowercased()
            if tables[ann.parkId]?[key] == nil {
                unregistered.append((ann.rideName, ann.parkId))
            }
        }
        if unregistered.isEmpty {
            print("✅ RideCoordinateTable: all annotations have explicit priority entries")
        } else {
            for (name, parkId) in unregistered {
                print("ℹ️ RideCoordinateTable: '\(name)' [\(parkId)] not in table — defaulting to P2")
            }
        }
    }
}
#endif

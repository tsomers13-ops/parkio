// ParkMapViewModel.swift — Pin position management for the custom map canvas.
//
// Responsibilities:
//   • Load normalized (0–1) ParkMapPin data for the active park.
//   • Expose debugMode toggle and out-of-bounds detection for calibration.
//   • Provide the park map image asset name.
//
// Selection and live wait enrichment remain in MapViewModel so the
// bottom sheet, filter chips, and WaitTimeViewModel wiring keep working.
//
// Image naming convention:
//   Add an asset named "<parkId-with-underscores>_map" to Assets.xcassets.
//   Example: "magic_kingdom_map", "disneyland_map".
//   If the asset is missing, ParkMapCanvasView shows a solid fallback.

import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class ParkMapViewModel {

    // ── Active park ────────────────────────────────────────────────────────────
    var parkId: String {
        didSet {
            guard parkId != oldValue else { return }
            loadPins()
        }
    }

    // ── Pin data ───────────────────────────────────────────────────────────────
    private(set) var pins: [ParkMapPin] = []

    // ── Debug / calibration ───────────────────────────────────────────────────
    var debugMode: Bool = false

    // MARK: - Derived

    var outOfBoundsPins: [ParkMapPin] {
        pins.filter { $0.isOutOfBounds }
    }

    /// Asset name for the park map background image.
    ///
    /// Resolution order (first match wins):
    ///   1. "<parkId>_map_mock"  — used in DEBUG if present (lets you test with placeholder art)
    ///   2. "<parkId>_map"       — production asset name
    ///
    /// Example: "disneyland" → tries "disneyland_map_mock" then "disneyland_map".
    /// Add assets to Assets.xcassets using these names.
    var mapImageName: String {
        let base = parkId.replacingOccurrences(of: "-", with: "_") + "_map"
        #if DEBUG
        if UIImage(named: base + "_mock") != nil { return base + "_mock" }
        #endif
        return base
    }

    /// True when a map image asset actually exists for the current park.
    /// Use this to decide whether to show a placeholder background.
    var hasMapImage: Bool {
        UIImage(named: mapImageName) != nil
    }

    // MARK: - Init

    init(parkId: String) {
        self.parkId = parkId
        loadPins()
    }

    // MARK: - Actions

    func loadPins() {
        pins = Self.embeddedPins[parkId] ?? []
    }

    func pin(forRideId rideId: String) -> ParkMapPin? {
        pins.first { $0.internalRideId == rideId }
    }

    /// Called by CalibrationViewModel.apply(to:) to commit calibrated positions.
    func replacePins(_ newPins: [ParkMapPin]) {
        pins = newPins
    }
}

// MARK: - Embedded pin datasets
// Positions are starter estimates calibrated to each park's general layout.
// Refine mapX/mapY values once real map image assets are added.
// Use ParkMapViewModel.debugMode = true to see the calibration overlay.

private extension ParkMapViewModel {

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

    static let magicKingdomPins: [ParkMapPin] = [
        // Tomorrowland (east)
        pin("mk|tron",            "magic-kingdom", "TRON Lightcycle / Run",        x: 0.75, y: 0.36, priority: 1),
        pin("mk|space-mountain",  "magic-kingdom", "Space Mountain",               x: 0.72, y: 0.42, priority: 1),
        pin("mk|buzz",            "magic-kingdom", "Buzz Lightyear",               x: 0.70, y: 0.47, priority: 2),
        pin("mk|astro-orbiter",   "magic-kingdom", "Astro Orbiter",                x: 0.67, y: 0.50, priority: 3),
        pin("mk|speedway",        "magic-kingdom", "Tomorrowland Speedway",        x: 0.73, y: 0.54, priority: 3),
        // Fantasyland (north center)
        pin("mk|seven-dwarfs",    "magic-kingdom", "Seven Dwarfs Mine Train",      x: 0.52, y: 0.27, priority: 1),
        pin("mk|peter-pan",       "magic-kingdom", "Peter Pan's Flight",           x: 0.44, y: 0.30, priority: 1),
        pin("mk|small-world",     "magic-kingdom", "it's a small world",           x: 0.38, y: 0.24, priority: 2),
        pin("mk|winnie-the-pooh", "magic-kingdom", "Winnie the Pooh",              x: 0.56, y: 0.31, priority: 2),
        pin("mk|little-mermaid",  "magic-kingdom", "Little Mermaid",               x: 0.62, y: 0.27, priority: 2),
        pin("mk|dumbo",           "magic-kingdom", "Dumbo",                        x: 0.48, y: 0.26, priority: 3),
        pin("mk|mad-tea-party",   "magic-kingdom", "Mad Tea Party",                x: 0.51, y: 0.31, priority: 3),
        // Liberty Square / Frontierland (west center)
        pin("mk|haunted-mansion", "magic-kingdom", "Haunted Mansion",              x: 0.32, y: 0.42, priority: 1),
        pin("mk|liberty-belle",   "magic-kingdom", "Liberty Belle Riverboat",      x: 0.34, y: 0.49, priority: 3),
        pin("mk|big-thunder",     "magic-kingdom", "Big Thunder Mountain",         x: 0.20, y: 0.47, priority: 1),
        pin("mk|tiana",           "magic-kingdom", "Tiana's Bayou Adventure",      x: 0.24, y: 0.52, priority: 1),
        // Adventureland (southwest)
        pin("mk|pirates",         "magic-kingdom", "Pirates of the Caribbean",     x: 0.21, y: 0.60, priority: 1),
        pin("mk|jungle-cruise",   "magic-kingdom", "Jungle Cruise",                x: 0.17, y: 0.57, priority: 2),
        pin("mk|magic-carpets",   "magic-kingdom", "Magic Carpets of Aladdin",     x: 0.19, y: 0.65, priority: 3),
        // Transport
        pin("mk|wdw-railroad",    "magic-kingdom", "WDW Railroad",                 x: 0.50, y: 0.87, priority: 3),
    ]

    // MARK: EPCOT

    static let epcotPins: [ParkMapPin] = [
        // World Discovery (northeast)
        pin("ep|guardians",     "epcot", "Guardians: Cosmic Rewind",  x: 0.63, y: 0.20, priority: 1),
        pin("ep|test-track",    "epcot", "Test Track",                x: 0.71, y: 0.27, priority: 1),
        pin("ep|mission-space", "epcot", "Mission: SPACE",            x: 0.67, y: 0.28, priority: 2),
        // World Nature (northwest)
        pin("ep|soarin",        "epcot", "Soarin'",                   x: 0.27, y: 0.35, priority: 1),
        pin("ep|living-land",   "epcot", "Living with the Land",      x: 0.23, y: 0.40, priority: 2),
        pin("ep|nemo",          "epcot", "The Seas with Nemo",        x: 0.19, y: 0.35, priority: 2),
        // World Showcase (south loop)
        pin("ep|frozen",        "epcot", "Frozen Ever After",         x: 0.30, y: 0.76, priority: 1),
        pin("ep|ratatouille",   "epcot", "Remy's Ratatouille",        x: 0.56, y: 0.82, priority: 1),
        // World Celebration (center)
        pin("ep|figment",       "epcot", "Journey Into Imagination",  x: 0.35, y: 0.32, priority: 2),
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

// MARK: - Preview stub

extension ParkMapViewModel {
    /// Quick stub for Xcode previews — includes one intentionally out-of-bounds pin.
    static func previewStub(parkId: String = "disneyland") -> ParkMapViewModel {
        let vm = ParkMapViewModel(parkId: parkId)
        return vm
    }
}

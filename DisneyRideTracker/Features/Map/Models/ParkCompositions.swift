// ParkCompositions.swift — Authored background shape definitions for all six parks.
//
// Each enum implements a single static func make() -> ParkComposition.
// Coordinates are normalized 0–1 within the park's contentSize canvas.
// Colors use MapTokens constants only — no inline Color literals.
//
// Draw order: base=0, water=1–2, land=5–9, entry/promenade=10–12, hub=13–15,
//             landmark=15, decorative=16+

import SwiftUI

// MARK: - Magic Kingdom  (1000 × 1100)

enum MKComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "magic-kingdom",
            contentSize: CGSize(width: 1000, height: 1100),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                // Base
                MapBackgroundShape(
                    id: "mk-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // Rivers of America — northwest water
                MapBackgroundShape(
                    id: "mk-rivers", type: .water,
                    geometry: .ellipse(CGRect(x: 0.04, y: 0.22, width: 0.27, height: 0.38)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.62, drawOrder: 1),

                // Small bay extension north of river
                MapBackgroundShape(
                    id: "mk-bay", type: .water,
                    geometry: .ellipse(CGRect(x: 0.06, y: 0.12, width: 0.18, height: 0.14)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.35, drawOrder: 2),

                // Adventureland — southwest
                MapBackgroundShape(
                    id: "mk-adventureland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.10, y: 0.47),
                        CGPoint(x: 0.36, y: 0.44),
                        CGPoint(x: 0.40, y: 0.55),
                        CGPoint(x: 0.34, y: 0.68),
                        CGPoint(x: 0.12, y: 0.70),
                        CGPoint(x: 0.06, y: 0.60),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.80, drawOrder: 5),

                // Liberty Square + Frontierland — west arc
                MapBackgroundShape(
                    id: "mk-frontierland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.08, y: 0.25),
                        CGPoint(x: 0.34, y: 0.22),
                        CGPoint(x: 0.44, y: 0.30),
                        CGPoint(x: 0.42, y: 0.48),
                        CGPoint(x: 0.28, y: 0.54),
                        CGPoint(x: 0.08, y: 0.50),
                    ]),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.80, drawOrder: 6),

                // Fantasyland — north, widest land
                MapBackgroundShape(
                    id: "mk-fantasyland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.20, y: 0.10),
                        CGPoint(x: 0.74, y: 0.08),
                        CGPoint(x: 0.80, y: 0.18),
                        CGPoint(x: 0.74, y: 0.42),
                        CGPoint(x: 0.58, y: 0.50),
                        CGPoint(x: 0.36, y: 0.48),
                        CGPoint(x: 0.20, y: 0.40),
                    ]),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.78, drawOrder: 7),

                // Tomorrowland — east
                MapBackgroundShape(
                    id: "mk-tomorrowland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.62, y: 0.28),
                        CGPoint(x: 0.92, y: 0.24),
                        CGPoint(x: 0.96, y: 0.34),
                        CGPoint(x: 0.92, y: 0.58),
                        CGPoint(x: 0.76, y: 0.64),
                        CGPoint(x: 0.60, y: 0.56),
                        CGPoint(x: 0.58, y: 0.40),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.78, drawOrder: 8),

                // Toontown — far north-east, isolated bubble
                MapBackgroundShape(
                    id: "mk-toontown", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.58, y: 0.04, width: 0.36, height: 0.20), 24),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.74, drawOrder: 9),

                // Main Street USA — bottom center corridor
                MapBackgroundShape(
                    id: "mk-mainstreet", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.35, y: 0.72, width: 0.30, height: 0.24), 16),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Hub ring — circular path connecting all spokes
                MapBackgroundShape(
                    id: "mk-hub-ring", type: .promenade,
                    geometry: .ellipse(CGRect(x: 0.28, y: 0.44, width: 0.44, height: 0.28)),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.45, drawOrder: 12),

                // Hub plaza
                MapBackgroundShape(
                    id: "mk-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.40, y: 0.56, width: 0.18, height: 0.13)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.84, drawOrder: 13),

                // Castle landmark
                MapBackgroundShape(
                    id: "mk-castle", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.45, y: 0.46, width: 0.10, height: 0.09)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.92, drawOrder: 15),

                MapBackgroundShape(
                    id: "mk-deco-nw", type: .decorative,
                    geometry: .roundedRect(CGRect(x: 0.00, y: 0.04, width: 0.18, height: 0.12), 8),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.20, drawOrder: 16),

                MapBackgroundShape(
                    id: "mk-deco-se", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.82, y: 0.64, width: 0.18, height: 0.22)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.15, drawOrder: 17),
            ]
        )
    }
}

// MARK: - EPCOT  (1000 × 1200)

enum EPCOTComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "epcot",
            contentSize: CGSize(width: 1000, height: 1200),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                MapBackgroundShape(
                    id: "ep-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // World Showcase Lagoon — large central water body
                MapBackgroundShape(
                    id: "ep-lagoon", type: .water,
                    geometry: .ellipse(CGRect(x: 0.16, y: 0.43, width: 0.68, height: 0.36)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.66, drawOrder: 1),

                MapBackgroundShape(
                    id: "ep-lagoon-s", type: .water,
                    geometry: .ellipse(CGRect(x: 0.28, y: 0.72, width: 0.44, height: 0.12)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.38, drawOrder: 2),

                // World Discovery — northeast
                MapBackgroundShape(
                    id: "ep-discovery", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.56, y: 0.12, width: 0.40, height: 0.28), 20),
                    fillColor: MapTokens.landCool, fillOpacity: 0.80, drawOrder: 5),

                // World Nature — northwest
                MapBackgroundShape(
                    id: "ep-nature", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.04, y: 0.12, width: 0.40, height: 0.28), 20),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.80, drawOrder: 6),

                // World Celebration — center-north bridge
                MapBackgroundShape(
                    id: "ep-celebration", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.30, y: 0.26, width: 0.40, height: 0.18), 16),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.76, drawOrder: 7),

                // World Showcase west arc countries
                MapBackgroundShape(
                    id: "ep-ws-west", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.44),
                        CGPoint(x: 0.18, y: 0.44),
                        CGPoint(x: 0.16, y: 0.62),
                        CGPoint(x: 0.08, y: 0.72),
                        CGPoint(x: 0.02, y: 0.66),
                        CGPoint(x: 0.02, y: 0.50),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.78, drawOrder: 8),

                // World Showcase east arc countries
                MapBackgroundShape(
                    id: "ep-ws-east", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.82, y: 0.44),
                        CGPoint(x: 0.96, y: 0.44),
                        CGPoint(x: 0.98, y: 0.66),
                        CGPoint(x: 0.92, y: 0.72),
                        CGPoint(x: 0.84, y: 0.62),
                        CGPoint(x: 0.82, y: 0.48),
                    ]),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.78, drawOrder: 8),

                // World Showcase south arc countries
                MapBackgroundShape(
                    id: "ep-ws-south", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.10, y: 0.74),
                        CGPoint(x: 0.42, y: 0.80),
                        CGPoint(x: 0.58, y: 0.80),
                        CGPoint(x: 0.90, y: 0.74),
                        CGPoint(x: 0.86, y: 0.88),
                        CGPoint(x: 0.50, y: 0.94),
                        CGPoint(x: 0.14, y: 0.88),
                    ]),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.76, drawOrder: 9),

                // Entry plaza south
                MapBackgroundShape(
                    id: "ep-entry", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.36, y: 0.88, width: 0.28, height: 0.10), 12),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Promenade ring — World Showcase walkway
                MapBackgroundShape(
                    id: "ep-promenade", type: .promenade,
                    geometry: .ellipse(CGRect(x: 0.10, y: 0.39, width: 0.80, height: 0.46)),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.35, drawOrder: 12),

                // Hub — Future World central plaza
                MapBackgroundShape(
                    id: "ep-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.41, y: 0.32, width: 0.18, height: 0.12)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.82, drawOrder: 13),

                // Spaceship Earth
                MapBackgroundShape(
                    id: "ep-sse", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.44, y: 0.06, width: 0.12, height: 0.12)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.92, drawOrder: 15),

                MapBackgroundShape(
                    id: "ep-deco-n", type: .decorative,
                    geometry: .roundedRect(CGRect(x: 0.28, y: 0.00, width: 0.44, height: 0.06), 4),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.20, drawOrder: 16),

                MapBackgroundShape(
                    id: "ep-deco-w", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.00, y: 0.78, width: 0.14, height: 0.20)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.16, drawOrder: 17),
            ]
        )
    }
}

// MARK: - Hollywood Studios  (1000 × 1000)

enum HSComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "hollywood-studios",
            contentSize: CGSize(width: 1000, height: 1000),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                MapBackgroundShape(
                    id: "hs-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // Echo Lake — small center-left water
                MapBackgroundShape(
                    id: "hs-echo-lake", type: .water,
                    geometry: .ellipse(CGRect(x: 0.28, y: 0.38, width: 0.24, height: 0.18)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.62, drawOrder: 1),

                // Galaxy's Edge — large northwest
                MapBackgroundShape(
                    id: "hs-galaxys-edge", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.06),
                        CGPoint(x: 0.46, y: 0.06),
                        CGPoint(x: 0.52, y: 0.16),
                        CGPoint(x: 0.48, y: 0.38),
                        CGPoint(x: 0.30, y: 0.46),
                        CGPoint(x: 0.10, y: 0.46),
                        CGPoint(x: 0.02, y: 0.34),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.82, drawOrder: 5),

                // Toy Story Land — northeast, compact
                MapBackgroundShape(
                    id: "hs-toy-story", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.56, y: 0.06, width: 0.40, height: 0.30), 18),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.80, drawOrder: 6),

                // Sunset Boulevard — west strip
                MapBackgroundShape(
                    id: "hs-sunset", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.50),
                        CGPoint(x: 0.30, y: 0.48),
                        CGPoint(x: 0.34, y: 0.60),
                        CGPoint(x: 0.24, y: 0.76),
                        CGPoint(x: 0.04, y: 0.76),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.80, drawOrder: 7),

                // Animation Courtyard + Grand Avenue — east side
                MapBackgroundShape(
                    id: "hs-grand-ave", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.54, y: 0.38, width: 0.42, height: 0.32), 16),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.78, drawOrder: 8),

                // Center corridor land
                MapBackgroundShape(
                    id: "hs-center", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.32, y: 0.52, width: 0.26, height: 0.20), 12),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.72, drawOrder: 9),

                // Entry / Hollywood Boulevard
                MapBackgroundShape(
                    id: "hs-entry", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.36, y: 0.74, width: 0.28, height: 0.22), 14),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Main axis promenade spine
                MapBackgroundShape(
                    id: "hs-spine", type: .promenade,
                    geometry: .roundedRect(CGRect(x: 0.44, y: 0.34, width: 0.12, height: 0.40), 8),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.48, drawOrder: 12),

                MapBackgroundShape(
                    id: "hs-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.41, y: 0.52, width: 0.17, height: 0.12)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.84, drawOrder: 13),

                // Chinese Theatre landmark
                MapBackgroundShape(
                    id: "hs-theatre", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.45, y: 0.42, width: 0.10, height: 0.08)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.90, drawOrder: 15),

                MapBackgroundShape(
                    id: "hs-deco-sw", type: .decorative,
                    geometry: .roundedRect(CGRect(x: 0.02, y: 0.80, width: 0.26, height: 0.16), 6),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.18, drawOrder: 16),

                MapBackgroundShape(
                    id: "hs-deco-se", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.82, y: 0.72, width: 0.18, height: 0.24)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.15, drawOrder: 17),
            ]
        )
    }
}

// MARK: - Animal Kingdom  (1100 × 1200)

enum AKComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "animal-kingdom",
            contentSize: CGSize(width: 1100, height: 1200),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                MapBackgroundShape(
                    id: "ak-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // Discovery River — partial ring around Discovery Island
                MapBackgroundShape(
                    id: "ak-river", type: .water,
                    geometry: .ellipse(CGRect(x: 0.28, y: 0.30, width: 0.44, height: 0.34)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.64, drawOrder: 1),

                // Savanna water — northwest Africa
                MapBackgroundShape(
                    id: "ak-savanna-water", type: .water,
                    geometry: .ellipse(CGRect(x: 0.06, y: 0.12, width: 0.26, height: 0.16)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.38, drawOrder: 2),

                // Africa — large northwest, open savanna feeling
                MapBackgroundShape(
                    id: "ak-africa", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.08),
                        CGPoint(x: 0.46, y: 0.06),
                        CGPoint(x: 0.50, y: 0.20),
                        CGPoint(x: 0.44, y: 0.34),
                        CGPoint(x: 0.28, y: 0.42),
                        CGPoint(x: 0.10, y: 0.40),
                        CGPoint(x: 0.02, y: 0.28),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.82, drawOrder: 5),

                // Asia — northeast, narrower
                MapBackgroundShape(
                    id: "ak-asia", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.56, y: 0.08),
                        CGPoint(x: 0.94, y: 0.10),
                        CGPoint(x: 0.98, y: 0.24),
                        CGPoint(x: 0.96, y: 0.42),
                        CGPoint(x: 0.76, y: 0.50),
                        CGPoint(x: 0.58, y: 0.42),
                        CGPoint(x: 0.54, y: 0.26),
                    ]),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.80, drawOrder: 6),

                // Pandora — southwest, cool distinct color
                MapBackgroundShape(
                    id: "ak-pandora", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.50),
                        CGPoint(x: 0.34, y: 0.48),
                        CGPoint(x: 0.38, y: 0.62),
                        CGPoint(x: 0.26, y: 0.76),
                        CGPoint(x: 0.06, y: 0.74),
                        CGPoint(x: 0.02, y: 0.60),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.82, drawOrder: 7),

                // Dinoland USA — east, compact
                MapBackgroundShape(
                    id: "ak-dinoland", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.64, y: 0.50, width: 0.34, height: 0.26), 16),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.78, drawOrder: 8),

                // Rafiki's Planet Watch — far west spur
                MapBackgroundShape(
                    id: "ak-rafiki", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.02, y: 0.78, width: 0.22, height: 0.14), 12),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.70, drawOrder: 9),

                // Entry — The Oasis
                MapBackgroundShape(
                    id: "ak-entry", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.34, y: 0.78, width: 0.32, height: 0.18), 14),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Promenade — path network radiating from island
                MapBackgroundShape(
                    id: "ak-promenade", type: .promenade,
                    geometry: .ellipse(CGRect(x: 0.22, y: 0.26, width: 0.56, height: 0.40)),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.38, drawOrder: 12),

                // Discovery Island hub
                MapBackgroundShape(
                    id: "ak-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.40, y: 0.38, width: 0.20, height: 0.16)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.86, drawOrder: 13),

                // Tree of Life
                MapBackgroundShape(
                    id: "ak-tree", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.45, y: 0.40, width: 0.10, height: 0.10)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.94, drawOrder: 15),

                // Decorative — jungle canopy fringe north
                MapBackgroundShape(
                    id: "ak-deco-n", type: .decorative,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1.0, height: 0.06)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.22, drawOrder: 16),

                MapBackgroundShape(
                    id: "ak-deco-se", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.76, y: 0.76, width: 0.22, height: 0.20)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.15, drawOrder: 17),
            ]
        )
    }
}

// MARK: - Disneyland  (950 × 1100)

enum DLComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "disneyland",
            contentSize: CGSize(width: 950, height: 1100),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                MapBackgroundShape(
                    id: "dl-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // Rivers of America — west
                MapBackgroundShape(
                    id: "dl-rivers", type: .water,
                    geometry: .ellipse(CGRect(x: 0.04, y: 0.28, width: 0.26, height: 0.34)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.62, drawOrder: 1),

                // New Orleans Square bayou water
                MapBackgroundShape(
                    id: "dl-bayou", type: .water,
                    geometry: .ellipse(CGRect(x: 0.06, y: 0.52, width: 0.18, height: 0.14)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.38, drawOrder: 2),

                // Galaxy's Edge — far west extension
                MapBackgroundShape(
                    id: "dl-galaxys-edge", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.02, y: 0.14),
                        CGPoint(x: 0.30, y: 0.12),
                        CGPoint(x: 0.34, y: 0.24),
                        CGPoint(x: 0.28, y: 0.36),
                        CGPoint(x: 0.04, y: 0.38),
                        CGPoint(x: 0.00, y: 0.28),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.80, drawOrder: 5),

                // Frontierland + New Orleans Square — west arc
                MapBackgroundShape(
                    id: "dl-frontierland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.10, y: 0.38),
                        CGPoint(x: 0.38, y: 0.34),
                        CGPoint(x: 0.44, y: 0.44),
                        CGPoint(x: 0.40, y: 0.60),
                        CGPoint(x: 0.18, y: 0.64),
                        CGPoint(x: 0.06, y: 0.56),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.80, drawOrder: 6),

                // Adventureland — southwest
                MapBackgroundShape(
                    id: "dl-adventureland", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.06, y: 0.62, width: 0.34, height: 0.20), 16),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.78, drawOrder: 7),

                // Fantasyland — north, large spread
                MapBackgroundShape(
                    id: "dl-fantasyland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.22, y: 0.18),
                        CGPoint(x: 0.70, y: 0.16),
                        CGPoint(x: 0.76, y: 0.26),
                        CGPoint(x: 0.70, y: 0.48),
                        CGPoint(x: 0.52, y: 0.54),
                        CGPoint(x: 0.28, y: 0.50),
                        CGPoint(x: 0.20, y: 0.40),
                    ]),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.78, drawOrder: 8),

                // Tomorrowland — east
                MapBackgroundShape(
                    id: "dl-tomorrowland", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.62, y: 0.28),
                        CGPoint(x: 0.92, y: 0.24),
                        CGPoint(x: 0.96, y: 0.36),
                        CGPoint(x: 0.94, y: 0.58),
                        CGPoint(x: 0.76, y: 0.64),
                        CGPoint(x: 0.60, y: 0.56),
                        CGPoint(x: 0.58, y: 0.40),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.78, drawOrder: 9),

                // Toontown — isolated north bubble
                MapBackgroundShape(
                    id: "dl-toontown", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.26, y: 0.04, width: 0.46, height: 0.16), 22),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.75, drawOrder: 9),

                // Entry / Main Street
                MapBackgroundShape(
                    id: "dl-mainstreet", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.36, y: 0.74, width: 0.28, height: 0.22), 14),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Hub ring
                MapBackgroundShape(
                    id: "dl-hub-ring", type: .promenade,
                    geometry: .ellipse(CGRect(x: 0.28, y: 0.48, width: 0.44, height: 0.28)),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.44, drawOrder: 12),

                MapBackgroundShape(
                    id: "dl-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.40, y: 0.58, width: 0.18, height: 0.13)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.84, drawOrder: 13),

                // Sleeping Beauty Castle
                MapBackgroundShape(
                    id: "dl-castle", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.45, y: 0.50, width: 0.10, height: 0.08)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.92, drawOrder: 15),

                MapBackgroundShape(
                    id: "dl-deco-sw", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.04, y: 0.82, width: 0.24, height: 0.14)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.18, drawOrder: 16),

                MapBackgroundShape(
                    id: "dl-deco-e", type: .decorative,
                    geometry: .roundedRect(CGRect(x: 0.88, y: 0.62, width: 0.12, height: 0.28), 6),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.14, drawOrder: 17),
            ]
        )
    }
}

// MARK: - Disney California Adventure  (1050 × 1000)

enum DCAComposition {
    static func make() -> ParkComposition {
        ParkComposition(
            parkId: "california-adventure",
            contentSize: CGSize(width: 1050, height: 1000),
            defaultViewport: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            shapes: [

                MapBackgroundShape(
                    id: "dca-base", type: .landMass,
                    geometry: .rect(CGRect(x: 0, y: 0, width: 1, height: 1)),
                    fillColor: MapTokens.canvasBase, fillOpacity: 1.0, drawOrder: 0),

                // Paradise Bay — large central lagoon
                MapBackgroundShape(
                    id: "dca-lagoon", type: .water,
                    geometry: .ellipse(CGRect(x: 0.24, y: 0.32, width: 0.48, height: 0.38)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.68, drawOrder: 1),

                // Pacific Wharf water extension west
                MapBackgroundShape(
                    id: "dca-water-w", type: .water,
                    geometry: .ellipse(CGRect(x: 0.04, y: 0.38, width: 0.22, height: 0.18)),
                    fillColor: MapTokens.waterBlue, fillOpacity: 0.40, drawOrder: 2),

                // Avengers Campus — northwest, angular
                MapBackgroundShape(
                    id: "dca-avengers", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.04, y: 0.06),
                        CGPoint(x: 0.40, y: 0.04),
                        CGPoint(x: 0.46, y: 0.16),
                        CGPoint(x: 0.42, y: 0.30),
                        CGPoint(x: 0.22, y: 0.38),
                        CGPoint(x: 0.04, y: 0.34),
                    ]),
                    fillColor: MapTokens.landCool, fillOpacity: 0.82, drawOrder: 5),

                // Hollywood Land — north center
                MapBackgroundShape(
                    id: "dca-hollywood", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.44, y: 0.04, width: 0.38, height: 0.28), 16),
                    fillColor: MapTokens.landVibrant, fillOpacity: 0.80, drawOrder: 6),

                // Pixar Pier — east, long narrow boardwalk
                MapBackgroundShape(
                    id: "dca-pixar-pier", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.68, y: 0.28),
                        CGPoint(x: 0.96, y: 0.26),
                        CGPoint(x: 0.98, y: 0.52),
                        CGPoint(x: 0.82, y: 0.64),
                        CGPoint(x: 0.66, y: 0.60),
                        CGPoint(x: 0.64, y: 0.42),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.80, drawOrder: 7),

                // Cars Land — southeast, angular red rock territory
                MapBackgroundShape(
                    id: "dca-cars-land", type: .landMass,
                    geometry: .polygon([
                        CGPoint(x: 0.56, y: 0.66),
                        CGPoint(x: 0.84, y: 0.62),
                        CGPoint(x: 0.90, y: 0.76),
                        CGPoint(x: 0.78, y: 0.94),
                        CGPoint(x: 0.54, y: 0.94),
                        CGPoint(x: 0.46, y: 0.78),
                    ]),
                    fillColor: MapTokens.landWarm, fillOpacity: 0.84, drawOrder: 8),

                // Grizzly Peak / Pacific Wharf — south center-west
                MapBackgroundShape(
                    id: "dca-grizzly", type: .landMass,
                    geometry: .roundedRect(CGRect(x: 0.10, y: 0.56, width: 0.36, height: 0.30), 18),
                    fillColor: MapTokens.landMuted, fillOpacity: 0.78, drawOrder: 9),

                // Entry / Buena Vista Street
                MapBackgroundShape(
                    id: "dca-entry", type: .entry,
                    geometry: .roundedRect(CGRect(x: 0.38, y: 0.82, width: 0.24, height: 0.16), 14),
                    fillColor: MapTokens.entryWarm, fillOpacity: 0.84, drawOrder: 10),

                // Promenade — arc around lagoon
                MapBackgroundShape(
                    id: "dca-promenade", type: .promenade,
                    geometry: .ellipse(CGRect(x: 0.16, y: 0.26, width: 0.66, height: 0.52)),
                    fillColor: MapTokens.promenadeStone, fillOpacity: 0.34, drawOrder: 12),

                // Hub — Carthay Circle plaza
                MapBackgroundShape(
                    id: "dca-hub", type: .hub,
                    geometry: .ellipse(CGRect(x: 0.41, y: 0.42, width: 0.18, height: 0.13)),
                    fillColor: MapTokens.hubNeutral, fillOpacity: 0.84, drawOrder: 13),

                // Carthay Circle Theatre landmark
                MapBackgroundShape(
                    id: "dca-carthay", type: .landmark,
                    geometry: .ellipse(CGRect(x: 0.45, y: 0.34, width: 0.10, height: 0.09)),
                    fillColor: MapTokens.landmarkGold, fillOpacity: 0.92, drawOrder: 15),

                MapBackgroundShape(
                    id: "dca-deco-ne", type: .decorative,
                    geometry: .roundedRect(CGRect(x: 0.82, y: 0.02, width: 0.18, height: 0.08), 4),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.18, drawOrder: 16),

                MapBackgroundShape(
                    id: "dca-deco-sw", type: .decorative,
                    geometry: .ellipse(CGRect(x: 0.02, y: 0.76, width: 0.14, height: 0.20)),
                    fillColor: MapTokens.decorativeLight, fillOpacity: 0.15, drawOrder: 17),
            ]
        )
    }
}

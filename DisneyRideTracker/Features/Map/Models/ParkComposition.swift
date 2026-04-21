// ParkComposition.swift — Authored background composition model for all park maps.
//
// Each park has one static ParkComposition that describes its background shapes.
// Shapes are rendered by ParkMapBackgroundView (CompositionMapCanvas).
// Normalized 0–1 coordinates match the ParkMapPin coordinate space exactly.
//
// Draw order contract:
//   0       base layer
//   1–2     water / large geographic features
//   5–9     land masses
//   10–12   entry areas / promenades
//   13–15   hub plazas
//   15+     landmarks
//   16+     decorative / low-opacity context shapes

import SwiftUI

// MARK: - Shape type

enum MapShapeType: String {
    case landMass       // Primary named land areas
    case hub            // Central plaza / organizing node
    case promenade      // Path corridors connecting lands
    case water          // Rivers, lagoons, moats
    case landmark       // Iconic structures (castle, geosphere)
    case entry          // Arrival / entrance plaza
    case decorative     // Low-emphasis geographic context
}

// MARK: - Shape geometry

enum ShapeGeometry {
    /// Normalized axis-aligned rectangle.
    case rect(CGRect)
    /// Normalized rectangle with continuous corner radius.
    case roundedRect(CGRect, CGFloat)
    /// Normalized ellipse (circle when width == height).
    case ellipse(CGRect)
    /// Normalized polygon — 4–8 vertices, closed automatically.
    case polygon([CGPoint])
}

// MARK: - Background shape

struct MapBackgroundShape: Identifiable {
    let id: String
    let type: MapShapeType
    let geometry: ShapeGeometry
    let fillColor: Color
    let fillOpacity: Double
    let drawOrder: Int
    var label: String? = nil
}

// MARK: - Park composition

struct ParkComposition {
    let parkId: String
    /// Logical canvas size in points. Pins use normalized coords within this space.
    let contentSize: CGSize
    /// Normalized 0–1 rect that should fill the screen on first appearance.
    /// fitScale = min(viewport.w / (cs.w × dv.w), viewport.h / (cs.h × dv.h))
    let defaultViewport: CGRect
    let shapes: [MapBackgroundShape]

    /// Shapes sorted by drawOrder for correct layer rendering.
    var orderedShapes: [MapBackgroundShape] {
        shapes.sorted { $0.drawOrder < $1.drawOrder }
    }
}

// MARK: - Color tokens

/// Shared color vocabulary for all park compositions.
/// Use these constants in every ParkComposition — never introduce inline Color literals.
enum MapTokens {
    // Canvas base — warm off-white parchment
    static let canvasBase      = Color(red: 0.96, green: 0.94, blue: 0.90)

    // Land fills
    static let landMuted       = Color(red: 0.82, green: 0.88, blue: 0.78)   // soft sage
    static let landWarm        = Color(red: 0.88, green: 0.82, blue: 0.72)   // warm tan
    static let landCool        = Color(red: 0.76, green: 0.84, blue: 0.90)   // sky blue-grey
    static let landVibrant     = Color(red: 0.86, green: 0.78, blue: 0.88)   // soft lavender

    // Special zones
    static let hubNeutral      = Color(red: 0.93, green: 0.92, blue: 0.88)   // near-parchment
    static let waterBlue       = Color(red: 0.68, green: 0.82, blue: 0.92)   // calm lake
    static let promenadeStone  = Color(red: 0.90, green: 0.89, blue: 0.85)   // path surface
    static let landmarkGold    = Color(red: 0.92, green: 0.84, blue: 0.62)   // icon accent
    static let entryWarm       = Color(red: 0.94, green: 0.90, blue: 0.84)   // entry plaza
    static let decorativeLight = Color(red: 0.88, green: 0.92, blue: 0.82)   // foliage tint
}

// MARK: - Registry

enum ParkCompositionRegistry {
    static func composition(for parkId: String) -> ParkComposition {
        switch parkId {
        case "magic-kingdom":         return MKComposition.make()
        case "epcot":                 return EPCOTComposition.make()
        case "hollywood-studios":     return HSComposition.make()
        case "animal-kingdom":        return AKComposition.make()
        case "disneyland":            return DLComposition.make()
        case "california-adventure":  return DCAComposition.make()
        default:                      return MKComposition.make()
        }
    }
}

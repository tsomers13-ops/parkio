// MapRoutingDecision.swift — Decides which map renderer the Maps tab uses per park.
//
// Magic Kingdom and EPCOT use the custom pan/zoom canvas
// (ParkMapCanvasView + ParkMapBackgroundView). Magic Kingdom fills that
// canvas with the production map artwork. EPCOT has no georeferenced
// artwork, so the same canvas draws a schematic whose blocks and pins
// come from MapCoordinates.json. Every other park keeps the live MapKit
// experience (RealMapScreen).

enum MapRenderMode: Equatable {
    case customCanvas
    case liveMap
}

enum MapRoutingDecision {
    static func renderMode(forParkId parkId: String) -> MapRenderMode {
        switch parkId {
        case "magic-kingdom", "epcot":
            return .customCanvas
        default:
            return .liveMap
        }
    }
}

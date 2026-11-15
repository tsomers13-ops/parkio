// MapRoutingDecision.swift — Decides which map renderer the Maps tab uses per park.
//
// Magic Kingdom and EPCOT use the custom pan/zoom canvas
// (ParkMapCanvasView + ParkMapBackgroundView) filled with each park's
// production map artwork. Every other park keeps the live MapKit
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

// MapRoutingDecision.swift — Decides which map renderer the Maps tab uses per park.
//
// Magic Kingdom ships the supplied production map artwork as an interactive
// pan/zoom canvas (ParkMapCanvasView + ParkMapBackgroundView). Every other
// park keeps the live MapKit experience (RealMapScreen) — GPS tiles, user
// location, live wait times. This is a pure, parkId-keyed decision, kept free
// of SwiftUI/UIKit so it is directly unit testable via `swift test`.

enum MapRenderMode: Equatable {
    case customCanvas
    case liveMap
}

enum MapRoutingDecision {
    static func renderMode(forParkId parkId: String) -> MapRenderMode {
        parkId == "magic-kingdom" ? .customCanvas : .liveMap
    }
}

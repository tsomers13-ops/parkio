// MapRoutingDecision.swift — the original, single-mode-per-park routing
// decision from before the Explore/Live toggle existed.
//
// Superseded by MapModeAvailability + MapContentView.mapMode (MapTabView.swift),
// which let a park offer both renderers with an Explore/Live toggle. Kept,
// unused by MapTabView, so its tests still record each park's default:
// Magic Kingdom and EPCOT start on the custom canvas; every other park
// starts on the live MapKit map.
//
// This is a pure, parkId-keyed decision, kept free of SwiftUI/UIKit so it is
// directly unit testable.

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

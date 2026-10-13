// MapRoutingDecision.swift — the original, single-mode-per-park routing
// decision from before the Explore/Live toggle existed.
//
// Superseded by MapModeAvailability + MapContentView.mapMode (MapTabView.swift),
// which let a park offer BOTH renderers with a user-facing toggle. Kept,
// unused by MapTabView, purely so its existing test coverage keeps documenting
// each park's original default renderer — delete alongside its test file if
// that historical record stops being useful.
//
// This is a pure, parkId-keyed decision, kept free of SwiftUI/UIKit so it is
// directly unit testable via `swift test`.

enum MapRenderMode: Equatable {
    case customCanvas
    case liveMap
}

enum MapRoutingDecision {
    static func renderMode(forParkId parkId: String) -> MapRenderMode {
        parkId == "magic-kingdom" ? .customCanvas : .liveMap
    }
}

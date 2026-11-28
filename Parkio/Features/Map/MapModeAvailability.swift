// MapModeAvailability.swift — which parks offer the user-toggleable
// Explore Map (original illustrated canvas) alongside the Live Map.
//
// Distinct from MapRoutingDecision: that type picks a park's single, fixed
// renderer from an earlier era (Magic Kingdom locked to the canvas, every
// other park locked to the live map). This type instead answers "does this
// park have a complete, calibrated Explore Map the guest can switch to",
// which MapTabView uses to decide whether to show the Explore/Live toggle at
// all and which mode a park should default into — a park with no Explore Map
// yet always starts on, and stays on, the Live Map.
//
// A park earns a `true` here only once its composition (ParkCompositions.swift)
// and pin data (ParkMapPinData.swift) are both authored and calibrated — adding
// a new park to the Explore Map rollout is exactly one line here.
//
// Pure, parkId-keyed, free of SwiftUI/UIKit — directly unit testable.
enum MapModeAvailability {
    static func isExploreMapAvailable(forParkId parkId: String) -> Bool {
        switch parkId {
        case "magic-kingdom", "epcot":
            return true
        default:
            return false
        }
    }
}

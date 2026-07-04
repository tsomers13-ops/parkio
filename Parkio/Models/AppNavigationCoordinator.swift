// AppNavigationCoordinator.swift — Cross-tab navigation coordinator.
//
// Owns the app's root tab selection and cross-feature navigation state.
// Injected at app root via .environment(coordinator); any view can read
// it with @Environment(AppNavigationCoordinator.self).
//
// Map navigation flow:
//   1. Home or My Day fires showOnMap(rideId:).
//   2. pendingMapRideId is set, then selectedTab switches to 1.
//   3. RealMapScreen attempts to resolve the ride in handlePendingRideIfNeeded(),
//      triggered from onAppear, onChange(pendingMapRideId), and
//      onChange(annotations.count).
//   4. pendingMapRideId is cleared ONLY after the annotation is found and
//      mapVM.selectRide + mapVM.centerOn succeed.  If annotations aren't loaded
//      yet the ID is left in place so the next trigger can retry — this prevents
//      the "first-tap does nothing" race that occurs when MapTabView lazily
//      creates MapViewModel one render cycle after the tab switch.

import SwiftUI

@Observable
@MainActor
final class AppNavigationCoordinator {

    /// Currently selected root tab index (0 = Home, 1 = Map, 2 = My Day, …).
    var selectedTab: Int = 0

    /// When non-nil, the map screen should select and center on this ride ID,
    /// then immediately clear the value so future switches don't re-trigger.
    var pendingMapRideId: String? = nil

    /// Convenience: switch to the Map tab and request a specific ride.
    func showOnMap(rideId: String) {
        pendingMapRideId = rideId
        selectedTab      = 1          // Map tab
    }
}

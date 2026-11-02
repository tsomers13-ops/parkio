// DistanceChip.swift — Compact pill showing routed walk distance and ETA.
//
// Format: "<Ride Name> · <distance> · ~<minutes> min"
//
// Icon rules (via RideProximity):
//   .nearby / .moderate → "figure.walk"
//   .far                → "figure.walk.motion"
// Shown when:
//   • A ride is selected
//   • WalkingRouteModel has a successful pedestrian route

import SwiftUI
import CoreLocation

// MARK: - DistanceChip

struct DistanceChip: View {

    let rideName:  String
    let route: WalkingRoute
    let proximity: RideProximity

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: walkIcon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.textSecondary)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    // MARK: - Helpers

    private var walkIcon: String {
        proximity.walkIcon
    }

    private var label: String {
        "\(rideName) · \(route.formattedDistance) · ~\(route.estimatedMinutes) min"
    }
}

// MARK: - Environment-driven wrapper

/// Reads all data from MapViewModel. Renders nothing when no ride is selected
/// or distance is unavailable. Passes proximity for icon selection.
struct DistanceChipIfNeeded: View {

    @Environment(MapViewModel.self)    private var mapVM
    @Environment(WalkingRouteModel.self) private var walkingRouteModel

    var body: some View {
        if let selectedMarker = mapVM.selectedEnrichedMarker,
           let route = walkingRouteModel.route {
            DistanceChip(
                rideName:  selectedMarker.annotation.rideName,
                route: route,
                proximity: RideProximity(distance: route.distance)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

#Preview("DistanceChip") {
    VStack(spacing: 16) {
        DistanceChip(rideName: "Space Mountain", route: .chipPreview(distance: 85), proximity: .nearby)
        DistanceChip(rideName: "Haunted Mansion", route: .chipPreview(distance: 240), proximity: .moderate)
        DistanceChip(rideName: "Tiana's Bayou Adv.", route: .chipPreview(distance: 1_240), proximity: .far)
    }
    .padding(32)
    .background(AppColor.background)
}

private extension WalkingRoute {
    static func chipPreview(distance: CLLocationDistance) -> WalkingRoute {
        WalkingRoute(distance: distance, expectedTravelTime: max(60, distance / 1.2), coordinates: [])
    }
}

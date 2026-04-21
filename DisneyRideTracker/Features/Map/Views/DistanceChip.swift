// DistanceChip.swift — Compact pill showing walk distance to the selected ride.
//
// Format: "<Ride Name> · <distance>"
//   "Space Mountain · 340m"    "Haunted Mansion · 1.2 km"
//
// Icon rules (via RideProximity):
//   .nearby / .moderate → "figure.walk"
//   .far                → "figure.walk.motion"
//   nil (no GPS yet)    → "figure.walk" (safe fallback)
//
// Shown when:
//   • A ride is selected
//   • LocationService has a valid userLocation
//   • mapVM.distanceToSelectedRide is non-nil

import SwiftUI
import CoreLocation

// MARK: - DistanceChip

struct DistanceChip: View {

    let rideName:  String
    let distance:  CLLocationDistance
    let proximity: RideProximity?       // nil before first GPS fix

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
        proximity?.walkIcon ?? "figure.walk"
    }

    private var label: String {
        "\(rideName) · \(RideAnnotation.formattedDistance(distance))"
    }
}

// MARK: - Environment-driven wrapper

/// Reads all data from MapViewModel. Renders nothing when no ride is selected
/// or distance is unavailable. Passes proximity for icon selection.
struct DistanceChipIfNeeded: View {

    @Environment(MapViewModel.self)    private var mapVM
    @Environment(LocationService.self) private var locationService

    var body: some View {
        if let selectedMarker = mapVM.selectedEnrichedMarker,
           let dist = mapVM.distanceToSelectedRide {
            DistanceChip(
                rideName:  selectedMarker.annotation.rideName,
                distance:  dist,
                proximity: mapVM.selectedRideProximity
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

#Preview("DistanceChip") {
    VStack(spacing: 16) {
        DistanceChip(rideName: "Space Mountain",       distance: 85,    proximity: .nearby)
        DistanceChip(rideName: "Haunted Mansion",      distance: 240,   proximity: .moderate)
        DistanceChip(rideName: "Tiana's Bayou Adv.",   distance: 1_240, proximity: .far)
        DistanceChip(rideName: "Big Thunder Mountain", distance: 340,   proximity: nil)
    }
    .padding(32)
    .background(AppColor.background)
}

// WalkGuidanceCard.swift — Floating card with estimated walk time to selected ride.
//
// Shown when:
//   • A ride is selected
//   • User location is known
//   • Straight-line distance ≤ 400 m (proximity is .nearby or .moderate)
//   • Bottom sheet is NOT at .full
//
// Layout:
//   Icon | Ride name (line 1) · distance
//        | Walk estimate (line 2)   — or "You're here" when distance < 50 m
//
// Walk time:
//   Estimated from straight-line distance at a 1.2 m/s walking pace.
//   Rounded UP to the nearest minute. Minimum displayed: 1 min.
//   This is a rough estimate only — not a routed distance.
//
// Caller responsibilities:
//   • Evaluate the visibility conditions before rendering this view.
//   • Position the card above the bottom sheet using appropriate bottom padding.
//   • Apply a .transition so entrance/exit is animated.
//
// This view reads nothing from the environment. All inputs are explicit.

import SwiftUI
import CoreLocation

// MARK: - WalkGuidanceCard

struct WalkGuidanceCard: View {

    let rideName:  String
    let distance:  CLLocationDistance
    let proximity: RideProximity

    // MARK: - Derived

    /// Distance < 50 m — treat as "arrived".
    private var isArrived: Bool { distance < 50 }

    /// Estimated walk duration at 1.2 m/s, rounded up, minimum 1 minute.
    private var estimatedMinutes: Int {
        guard !isArrived else { return 0 }
        let seconds = distance / 1.2
        return max(1, Int(ceil(seconds / 60.0)))
    }

    private var distanceLabel: String {
        RideAnnotation.formattedDistance(distance)
    }

    private var iconName: String {
        isArrived ? "mappin.circle.fill" : proximity.walkIcon
    }

    private var iconColor: Color {
        isArrived ? Color.green : Color.accentColor
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // ── Icon ────────────────────────────────────────────────────────────
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            // ── Text block ───────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(rideName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)

                if isArrived {
                    Text("You're here")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.green)
                } else {
                    Text("\(distanceLabel) · ~\(estimatedMinutes) min walk")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("WalkGuidanceCard") {
    VStack(spacing: 16) {
        WalkGuidanceCard(rideName: "Space Mountain",       distance: 32,    proximity: .nearby)
        WalkGuidanceCard(rideName: "Haunted Mansion",      distance: 210,   proximity: .moderate)
        WalkGuidanceCard(rideName: "Tiana's Bayou Adventure", distance: 380, proximity: .moderate)
        WalkGuidanceCard(rideName: "Pirates of Caribbean", distance: 95,    proximity: .nearby)
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}

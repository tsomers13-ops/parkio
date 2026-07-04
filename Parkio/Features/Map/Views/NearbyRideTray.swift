// NearbyRideTray.swift — Horizontal scroll tray of nearby rides.
//
// Shown when:
//   • No ride is selected
//   • GPS is available
//   • At least one ride is within 800 m
//
// Hidden when:
//   • A ride is selected
//   • The bottom sheet is fully expanded
//   • GPS is unavailable
//
// Each card shows: ride name, land, distance, wait time / status badge.
// Tapping a card calls onSelect(_:) — the caller handles selectRide + centerOn.
//
// This view is self-contained: it reads nothing from the environment.
// All data and actions are passed explicitly.

import SwiftUI
import CoreLocation

// MARK: - NearbyRideTray

struct NearbyRideTray: View {

    let rides:    [NearbyRide]
    /// Called when the user taps a ride card. Caller handles selectRide + camera center.
    let onSelect: (NearbyRide) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(rides) { ride in
                    NearbyRideCard(ride: ride)
                        .onTapGesture { onSelect(ride) }
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, 2)      // room for card shadows
        }
        .scrollClipDisabled()           // shadows visible at leading/trailing edges
    }
}

// MARK: - NearbyRideCard

private struct NearbyRideCard: View {
    let ride: NearbyRide

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── Header row: category icon + wait badge ─────────────────────────
            HStack {
                Image(systemName: ride.annotation.category.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)

                Spacer(minLength: 0)

                waitBadge
            }

            // ── Ride name ──────────────────────────────────────────────────────
            Text(ride.annotation.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // ── Land + distance ────────────────────────────────────────────────
            HStack(spacing: 4) {
                Text(ride.annotation.land)
                    .lineLimit(1)
                Text("·")
                Text(RideAnnotation.formattedDistance(ride.distance))
            }
            .font(.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
        .padding(12)
        .frame(width: 164, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Wait badge

    @ViewBuilder
    private var waitBadge: some View {
        if ride.isRideable {
            if let mins = ride.waitMinutes {
                // Known wait time
                Text(mins == 0 ? "Walk on" : "\(mins) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.waitColor(minutes: mins))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        AppColor.waitColor(minutes: mins).opacity(0.12),
                        in: Capsule()
                    )
            } else {
                // Rideable but no wait time in feed
                Text("Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
        } else {
            // Temporarily closed, down for maintenance, etc.
            Text("Closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppColor.textTertiary.opacity(0.10), in: Capsule())
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftData

#Preview("NearbyRideTray") {
    // Build a handful of stub rides for layout review.
    let rides: [NearbyRide] = [
        NearbyRide(
            annotation: RideAnnotation(from: .stub(id: "1", name: "Space Mountain",
                                                   land: "Tomorrowland")),
            enriched: nil,
            distance: 85
        ),
        NearbyRide(
            annotation: RideAnnotation(from: .stub(id: "2", name: "Haunted Mansion",
                                                   land: "Liberty Square")),
            enriched: nil,
            distance: 210
        ),
        NearbyRide(
            annotation: RideAnnotation(from: .stub(id: "3", name: "Pirates of the Caribbean",
                                                   land: "Adventureland")),
            enriched: nil,
            distance: 320
        ),
    ]

    ZStack {
        AppColor.background.ignoresSafeArea()

        VStack {
            Spacer()
            NearbyRideTray(rides: rides) { _ in }
                .padding(.bottom, 90)
        }
    }
}
#endif

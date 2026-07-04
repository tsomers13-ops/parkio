// ParkGlanceBar.swift — Live "Park at a Glance" stat bar for the map HUD.
//
// Shows three live stats in a compact 44pt pill directly above the bottom sheet:
//
//   avg wait  │  rides open  │  best now
//   ──────────┼──────────────┼──────────────
//   12 min    │    8 / 11    │  Space Mtn
//
// Data source: MapViewModel computed properties which read from WaitTimeViewModel.liveRides.
// Re-renders automatically when liveRides refreshes (every 3 min polling cycle).
//
// ── Ride count scoping ────────────────────────────────────────────────────────
//
//   openRidesCount / totalRidesCount are scoped to the curated annotation set
//   (MapCoordinates.json — the seeder-curated rides shown as map pins). This
//   matches user expectation: EPCOT shows ~11 rides open, not 31/33 which
//   reflects all API attractions including shows, food-ordering queues, etc.
//
//   The unfiltered API counts are still available as openAttractionsCount /
//   totalAttractionsCount on MapViewModel for debugging in the debug panel.
//
// Transitions: shares WaitTimeLegendView.transition so it slides in/out
// as a visual unit with the filter bar.
//
// contentTransition(.numericText()): each value Text uses .animation(_:value:)
// so numeric rolls play automatically when the stat string changes.

import SwiftUI

// MARK: - ParkGlanceBar

struct ParkGlanceBar: View {

    @Environment(MapViewModel.self) private var mapVM

    var body: some View {
        HStack(spacing: 0) {
            statCell(
                value:      avgWaitText,
                label:      "avg wait",
                valueColor: avgWaitColor
            )
            divider
            statCell(
                value:      openText,
                label:      "rides open",
                valueColor: .primary
            )
            divider
            statCell(
                value:      mapVM.shortestWaitRide ?? "—",
                label:      "best now",
                valueColor: .primary
            )
        }
        .frame(height: 44)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .overlay {
            // Matches WaitTimeLegendView + MapOverlayFilterBar border treatment.
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        // Pull back from screen edges to match the legend / filter bar visual rhythm.
        .padding(.horizontal, AppSpacing.screenEdge)
        // Cap Dynamic Type so stats never overflow the fixed 44pt height.
        .dynamicTypeSize(.large ... .large)
        // Slides in/out with MapOverlayFilterBar as a visual unit.
        .transition(WaitTimeLegendView.transition)
    }

    // MARK: - Computed display values

    /// "12 min" or "—" when no rideable rides have wait data.
    private var avgWaitText: String {
        guard let mins = mapVM.avgWaitMinutes else { return "—" }
        return "\(mins) min"
    }

    /// Wait-band color when data is available; secondary text color for the "—" state.
    private var avgWaitColor: Color {
        guard let mins = mapVM.avgWaitMinutes else { return AppColor.textSecondary }
        return AppColor.waitColor(minutes: mins)
    }

    /// "8 / 11" curated-ride open count string.
    /// Denominator is the seeder-curated annotation set, not all API attractions.
    private var openText: String {
        "\(mapVM.openRidesCount) / \(mapVM.totalRidesCount)"
    }

    // MARK: - Stat cell

    /// Single stat column: bold value row + small label row, equal-width, centered.
    /// contentTransition(.numericText()) is driven by .animation(_:value: value) —
    /// when the string changes on a live-data refresh, the numerals roll in place.
    @ViewBuilder
    private func statCell(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                // Numeric slot-machine roll on live-data refresh.
                .contentTransition(.numericText())
                .animation(AppMotion.standard, value: value)
                // Allow slight shrink before truncation for long ride names in "best now".
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .truncationMode(.tail)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
        }
        // Each cell claims equal width — HStack divides the pill into thirds.
        .frame(maxWidth: .infinity)
    }

    // MARK: - Column divider

    /// Hairline vertical rule between stat columns. Slightly lighter than the pill border.
    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 0.5, height: 22)
    }
}

// MARK: - Preview

#Preview("Glance bar — live data") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        // Preview uses a detached view — wire to a real MapViewModel in context.
        // Shown here with representative hardcoded text to verify layout.
        HStack(spacing: 0) {
            VStack(spacing: 1) {
                Text("18 min")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.waitColor(minutes: 18))
                Text("avg wait")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 0.5, height: 22)

            VStack(spacing: 1) {
                Text("8 / 11")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("rides open")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 0.5, height: 22)

            VStack(spacing: 1) {
                Text("Space Mountain")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("best now")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        .padding(.horizontal, AppSpacing.screenEdge)
    }
}

#Preview("Glance bar — no data") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        HStack(spacing: 0) {
            ForEach(["avg wait", "rides open", "best now"], id: \.self) { label in
                VStack(spacing: 1) {
                    Text("—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                if label != "best now" {
                    Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 0.5, height: 22)
                }
            }
        }
        .frame(height: 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        .padding(.horizontal, AppSpacing.screenEdge)
    }
}

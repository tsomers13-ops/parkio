// StatsHeaderView.swift — Park stats bar (Phase 2 design system)

import SwiftUI

struct StatsHeaderView: View {
    let park: Park
    let rides: [Ride]

    private var totalRides: Int { rides.count }
    private var riddenCount: Int { rides.filter(\.isRidden).count }
    private var totalRideOns: Int { rides.reduce(0) { $0 + $1.rideCount } }

    private var completion: Double {
        guard totalRides > 0 else { return 0 }
        return Double(riddenCount) / Double(totalRides)
    }

    private var percentString: String {
        "\(Int((completion * 100).rounded()))%"
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Stat blocks
            HStack(alignment: .center, spacing: 0) {
                StatBlock(label: "Ridden",    value: "\(riddenCount)/\(totalRides)", color: park.accentColor)
                Divider().frame(height: 32)
                StatBlock(label: "Ride-ons",  value: "\(totalRideOns)",              color: park.accentColor)
                Divider().frame(height: 32)
                StatBlock(label: "Complete",  value: percentString,                   color: AppColor.success)
            }
            .frame(maxWidth: .infinity)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.skeleton)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [park.accentColor.opacity(0.7), park.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * completion, height: 6)
                        .animation(AppMotion.standard, value: completion)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, AppSpacing.md)
        .background(park.accentBackground)
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }
}

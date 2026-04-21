// HomeComponents.swift — Reusable home-screen cards and rows

import SwiftUI
import SwiftData

// MARK: - Stats Card

struct HomeStatsCard: View {
    let ridden: Int
    let total: Int
    let park: Park

    private var completion: Double {
        guard total > 0 else { return 0 }
        return Double(ridden) / Double(total)
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Top row: counts
            HStack {
                StatPill(
                    value: "\(ridden)",
                    label: "Ridden",
                    color: park.accentColor
                )
                Spacer()
                StatPill(
                    value: "\(total - ridden)",
                    label: "Remaining",
                    color: AppColor.textSecondary
                )
                Spacer()
                StatPill(
                    value: "\(Int(completion * 100))%",
                    label: "Complete",
                    color: AppColor.success
                )
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.skeleton)
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [park.accentColor.opacity(0.8), park.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * completion, height: 8)
                        .animation(AppMotion.standard, value: completion)
                }
            }
            .frame(height: 8)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - Wait Ride Card

/// 148×160 pt card showing a ride's live wait time, trend, and lightning lane status.
/// Pass `liveState: nil` before live data arrives — the card renders a neutral loading state.
struct WaitRideCard: View {
    let ride: Ride
    let liveState: LiveRideState?   // nil → loading / no live data yet
    let accentColor: Color

    @State private var showDetail = false

    // ── Derived display values ────────────────────────────────────────────────

    private var waitDisplay: String {
        liveState?.waitDisplay ?? "—"
    }

    private var waitColor: Color {
        liveState?.waitColor ?? AppColor.textTertiary
    }

    private var showTrend: Bool {
        guard let live = liveState else { return false }
        return live.trend != .unknown && live.trend != .stable && live.status.isRideable
    }

    private var trendColor: Color {
        guard let live = liveState else { return AppColor.textTertiary }
        return live.trend == .rising ? AppColor.error : AppColor.success
    }

    var body: some View {
        Button {
            showDetail = true
            AppHaptic.light()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {

                // ── Wait badge + trend arrow ───────────────────────────
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(waitDisplay)
                        .font(.caption.weight(.bold))

                    if showTrend, let live = liveState {
                        Image(systemName: live.trend.systemImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(trendColor)
                    }
                }
                .foregroundStyle(waitColor)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(waitColor.opacity(0.12))
                .clipShape(Capsule())

                // ── Ride name ─────────────────────────────────────────
                Text(ride.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Land label ────────────────────────────────────────
                Text(ride.land)
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)

                Spacer(minLength: 0)

                // ── Bottom row: wait label chip + LL indicator ────────
                HStack(spacing: AppSpacing.xs) {
                    if let live = liveState, live.status.isRideable {
                        Text(AppColor.waitLabel(minutes: live.waitMinutes ?? 0))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 3)
                            .background(waitColor)
                            .clipShape(Capsule())
                    } else if liveState == nil {
                        // Skeleton placeholder while loading
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(AppColor.skeleton)
                            .frame(width: 52, height: 18)
                    } else if let live = liveState {
                        // Not rideable — show status label
                        Text(live.status.displayLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColor.textTertiary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 3)
                            .background(AppColor.skeleton)
                            .clipShape(Capsule())
                    }

                    if liveState?.lightningLaneAvailable == true {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.brandGold)
                    }
                }
            }
            .padding(AppSpacing.md)
            .frame(width: 148, height: 160, alignment: .topLeading)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
            // Dim stale cards subtly
            .opacity(liveState?.isStale == true ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - Recent Log Row

struct RecentLogRow: View {
    let ride: Ride
    let log: RideLog
    let accentColor: Color

    @State private var showDetail = false

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Button {
            showDetail = true
            AppHaptic.light()
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Accent dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(ride.land)
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Self.timeFormatter.localizedString(for: log.date, relativeTo: Date()))
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    if ride.rideCount > 1 {
                        Text("×\(ride.rideCount) total")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - Stale / Offline Banner

/// Shown when wait times are from cache and the device is offline or data is stale.
struct StaleBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
            Text(message)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.warning)
    }
}

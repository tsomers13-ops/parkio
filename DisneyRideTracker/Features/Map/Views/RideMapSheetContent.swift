// RideMapSheetContent.swift — Stateless content rendered inside RideMapBottomSheetView.
//
// Detent routing:
//   .collapsed → SheetCollapsedContent  (brief label; no handle rendered here)
//   .peek      → SheetPeekContent       (ride card + sparkline + quick log)
//   .full      → SheetFullContent       (premium detail panel + directions)
//
// Phase 5 additions:
//   • WaitSparkline         — SwiftUI Path sparkline (60×18 pt, 1.5 pt stroke)
//   • PeekSparklineRow      — sparkline + trend label below LiveStatusRow in peek
//   • LogRideButton upgrade — 1.5 s "Logged ✓" confirmation + haptic feedback
//   • DirectionsChip        — opens Apple Maps walking directions in full detent
//
// Drag handle ownership (Phase 6 gesture fix):
//   SheetDragHandle is no longer rendered inside this view. It was moved to
//   RideMapBottomSheetView.dragHandleStrip so the DragGesture can be wired
//   directly to the pill without sitting in the ScrollView's ancestor chain.
//   SheetDragHandle remains defined here (same module) for reuse.
//
// All action closures injected by parent — this view is side-effect-free.
// Each detent is a separate struct to keep the type-checker fast.

import SwiftUI
import SwiftData
import MapKit

// MARK: - Root content router

struct RideMapSheetContent: View {
    let marker:        EnrichedMarker?
    let detent:        SheetDetent
    let onLogRide:     () -> Bool
    let onAddToMyDay:  () -> Void
    let onDismiss:     () -> Void
    let onExpandSheet: () -> Void

    var body: some View {
        // SheetDragHandle is not rendered here — it lives in
        // RideMapBottomSheetView.dragHandleStrip so the DragGesture is wired
        // directly to the pill as a sibling of this view (not an ancestor).
        // That keeps the full-detent ScrollView outside the gesture's subtree.
        contentForDetent
    }

    @ViewBuilder
    private var contentForDetent: some View {
        switch detent {
        case .collapsed:
            SheetCollapsedContent(marker: marker, onExpand: onExpandSheet)
        case .peek:
            SheetPeekContent(
                marker:       marker,
                onLogRide:    onLogRide,
                onAddToMyDay: onAddToMyDay,
                onDismiss:    onDismiss,
                onExpand:     onExpandSheet
            )
        case .full:
            SheetFullContent(
                marker:       marker,
                onLogRide:    onLogRide,
                onAddToMyDay: onAddToMyDay,
                onDismiss:    onDismiss,
                onCollapse:   onExpandSheet
            )
        }
    }
}

// MARK: - Drag handle

struct SheetDragHandle: View {
    var body: some View {
        Capsule()
            .fill(AppColor.skeleton)
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }
}

// MARK: - Collapsed

private struct SheetCollapsedContent: View {
    let marker:   EnrichedMarker?
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let marker {
                Text(marker.annotation.rideName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let badge = marker.badgeText {
                    Text("\(badge) min")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(marker.markerColor)
                }
            } else {
                Text("Tap a ride to see wait times")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textTertiary)
                Spacer()
            }
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.bottom, AppSpacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { onExpand() }
    }
}

// MARK: - Peek

private struct SheetPeekContent: View {
    let marker:       EnrichedMarker?
    let onLogRide:    () -> Bool
    let onAddToMyDay: () -> Void
    let onDismiss:    () -> Void
    let onExpand:     () -> Void

    var body: some View {
        if let marker {
            peekCard(marker: marker)
        } else {
            peekEmptyState
        }
    }

    private func peekCard(marker: EnrichedMarker) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // ── Header ──────────────────────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.annotation.rideName)
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                    Text(marker.annotation.land)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColor.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // ── Live status (wait badge + open pill) ─────────────────────────
            LiveStatusRow(marker: marker)

            // ── Sparkline + trend label (open rides with known wait only) ────
            if let live = marker.liveState,
               live.status.isRideable,
               let wait = live.waitMinutes,
               wait > 0 {
                PeekSparklineRow(live: live, color: marker.markerColor)
                    .transition(.opacity)
            }

            Divider()

            // ── Quick log button ─────────────────────────────────────────────
            LogRideButton(action: onLogRide)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.bottom, AppSpacing.md)
    }

    private var peekEmptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 32))
                .foregroundStyle(AppColor.textTertiary)
            Text("Tap any ride pin to see wait times and log a ride.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
    }
}

// MARK: - Full (premium detail panel)

private struct SheetFullContent: View {
    let marker:       EnrichedMarker?
    let onLogRide:    () -> Bool
    let onAddToMyDay: () -> Void
    let onDismiss:    () -> Void
    let onCollapse:   () -> Void

    // MyDayStore drives the "Add to My Day" button state so it reflects
    // real plan membership, not just the marker snapshot.
    @Environment(MyDayStore.self) private var myDayStore

    var body: some View {
        if let marker {
            // Compute isPlanned from live store state — updates immediately
            // when the user taps "Add to My Day" without a view re-build.
            let isPlanned = myDayStore.containsRide(marker.annotation.id)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Ride header ─────────────────────────────────────────
                    FullRideHeader(marker: marker, onDismiss: onDismiss)
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.top, AppSpacing.xs)
                        .padding(.bottom, AppSpacing.lg)

                    // ── Wait time hero card ─────────────────────────────────
                    WaitTimeHeroCard(marker: marker)
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, AppSpacing.lg)

                    sheetDivider

                    // ── Ride history ────────────────────────────────────────
                    FullHistorySection(marker: marker)
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.vertical, AppSpacing.lg)

                    sheetDivider

                    // ── Primary actions ─────────────────────────────────────
                    VStack(spacing: AppSpacing.sm) {
                        LogRideButton(action: onLogRide)
                        AddToMyDayButton(isPlanned: isPlanned, action: onAddToMyDay)
                        DirectionsChip(coordinate: marker.annotation.coordinate,
                                       rideName: marker.annotation.rideName)
                    }
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        } else {
            // Guard — full opened with no selection. Fall back to peek empty state.
            SheetPeekContent(
                marker:       nil,
                onLogRide:    onLogRide,
                onAddToMyDay: onAddToMyDay,
                onDismiss:    onDismiss,
                onExpand:     {}
            )
        }
    }

    private var sheetDivider: some View {
        Divider()
            .padding(.horizontal, AppSpacing.screenEdge)
    }
}

// MARK: - Full: header

/// Ride name + land label + category icon + dismiss button.
private struct FullRideHeader: View {
    let marker:    EnrichedMarker
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {

            // Category icon badge
            ZStack {
                Circle()
                    .fill(marker.markerColor.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: marker.annotation.category.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(marker.markerColor)
            }

            // Name + land
            VStack(alignment: .leading, spacing: 3) {
                Text(marker.annotation.rideName)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(marker.annotation.land)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Dismiss
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Full: wait time hero card

/// The primary information block — large wait number, trend, status badges.
/// Uses .thinMaterial so it layers cleanly on the .regularMaterial sheet.
private struct WaitTimeHeroCard: View {
    let marker: EnrichedMarker

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            waitHero
            Spacer(minLength: AppSpacing.md)
            statusBadgeStack
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .strokeBorder(AppColor.skeleton, lineWidth: 0.5)
        )
    }

    // ── Wait display: large number or status for closed rides ─────────────────

    @ViewBuilder
    private var waitHero: some View {
        if let live = marker.liveState {
            if live.status.isRideable {
                openWaitDisplay(live: live)
            } else {
                closedDisplay(live: live)
            }
        } else {
            loadingDisplay
        }
    }

    private func openWaitDisplay(live: LiveRideState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let mins = live.waitMinutes, mins > 0 {
                    Text("\(mins)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(marker.markerColor)
                        .contentTransition(.numericText())
                    Text("min")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.bottom, 6)
                } else {
                    Text("Walk-on")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.success)
                }
            }
            // Trend indicator — only shown when meaningful
            if live.trend == .rising || live.trend == .falling {
                HStack(spacing: 4) {
                    Image(systemName: live.trend.systemImage)
                        .font(.caption2.weight(.bold))
                    Text(live.trend == .rising ? "Wait rising" : "Wait falling")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(live.trend == .rising ? AppColor.error : AppColor.success)
            }
        }
    }

    private func closedDisplay(live: LiveRideState) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: closedIcon(for: live.status))
                .font(.system(size: 24))
                .foregroundStyle(closedColor(for: live.status))
            Text(live.status.displayLabel)
                .font(.title3.bold())
                .foregroundStyle(closedColor(for: live.status))
        }
    }

    private var loadingDisplay: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Skeleton placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColor.skeleton)
                .frame(width: 88, height: 50)
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColor.skeleton)
                .frame(width: 52, height: 14)
        }
    }

    // ── Status badges on the right ────────────────────────────────────────────

    @ViewBuilder
    private var statusBadgeStack: some View {
        if let live = marker.liveState {
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                StatusPill(
                    label: live.status.isRideable ? "Open" : live.status.displayLabel,
                    style: live.status.isRideable ? .open : .closed(live.status.displayLabel)
                )
                if live.lightningLaneAvailable {
                    LightningLanePill()
                }
                if let single = live.singleRiderWaitMinutes {
                    SingleRiderPill(minutes: single)
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func closedIcon(for status: RideStatus) -> String {
        switch status {
        case .down:          return "wrench.and.screwdriver.fill"
        case .refurbishment: return "hammer.fill"
        default:             return "xmark.circle.fill"
        }
    }

    private func closedColor(for status: RideStatus) -> Color {
        switch status {
        case .down, .refurbishment: return AppColor.warning
        default:                    return AppColor.textTertiary
        }
    }
}

// MARK: - Full: history section

private struct FullHistorySection: View {
    let marker: EnrichedMarker

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            Text("RIDE HISTORY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.textTertiary)
                .kerning(0.8)

            HStack(spacing: AppSpacing.md) {
                riddenIcon
                riddenLabel
                Spacer(minLength: 0)
                if marker.isLoggedToday { todayBadge }
            }
        }
    }

    private var riddenIcon: some View {
        ZStack {
            Circle()
                .fill(marker.isRidden
                      ? AppColor.success.opacity(0.12)
                      : AppColor.skeleton.opacity(0.6))
                .frame(width: 40, height: 40)
            Image(systemName: marker.isRidden ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(marker.isRidden ? AppColor.success : AppColor.textTertiary)
        }
    }

    private var riddenLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(marker.isRidden ? "Ridden" : "Not yet ridden")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(marker.isRidden ? AppColor.textPrimary : AppColor.textSecondary)
            Text(marker.isRidden
                 ? "Tap Log Ride to record another"
                 : "Tap Log Ride to track it")
                .font(.caption)
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    private var todayBadge: some View {
        Label("Today", systemImage: "calendar.badge.checkmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.success)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.success.opacity(0.12), in: Capsule())
    }
}

// MARK: - Live status row (peek sheet)

private struct LiveStatusRow: View {
    let marker: EnrichedMarker

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let live = marker.liveState {
                if live.status.isRideable {
                    WaitTimeBadge(live: live, color: marker.markerColor)
                    StatusPill(label: "Open", style: .open)
                    if live.lightningLaneAvailable { LightningLanePill() }
                } else {
                    StatusPill(label: live.status.displayLabel,
                               style: .closed(live.status.displayLabel))
                }
            } else {
                loadingPill
            }
            Spacer(minLength: 0)
        }
    }

    private var loadingPill: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.65).tint(AppColor.textTertiary)
            Text("Loading…")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColor.skeleton, in: Capsule())
    }
}

// MARK: - Wait time badge (peek)

private struct WaitTimeBadge: View {
    let live:  LiveRideState
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(live.waitDisplay)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            if live.trend == .rising || live.trend == .falling {
                Image(systemName: live.trend.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(live.trend == .rising ? AppColor.error : AppColor.success)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Sparkline (peek sheet)

/// Compact SwiftUI Path sparkline — 60×18 pt, 1.5 pt rounded stroke.
/// Points are raw CGFloat values (e.g. wait minutes). Normalization is internal.
private struct WaitSparkline: View {
    let points: [CGFloat]
    let color:  Color

    var body: some View {
        GeometryReader { geo in
            if points.count >= 2 {
                let w      = geo.size.width
                let h      = geo.size.height
                let minV   = points.min() ?? 0
                let maxV   = points.max() ?? 1
                let range  = max(1, maxV - minV)
                let xStep  = w / CGFloat(points.count - 1)

                Path { path in
                    for (i, val) in points.enumerated() {
                        let x = CGFloat(i) * xStep
                        let y = h - ((val - minV) / range * h)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: 60, height: 18)
    }
}

/// Sparkline + trend label row, shown in peek detent below the status row.
private struct PeekSparklineRow: View {
    let live:  LiveRideState
    let color: Color

    // Build 6 synthetic data points from the current wait + trend delta.
    // These represent the last ~30 minutes of implied wait history.
    private var sparklinePoints: [CGFloat] {
        guard let wait = live.waitMinutes else { return [] }
        let w = CGFloat(wait)
        // Use at least a 3-minute delta to ensure visible slope.
        let d = CGFloat(max(3, live.trendDeltaMinutes))
        switch live.trend {
        case .rising:
            // Start lower, end at current wait
            let base = max(0, w - d)
            return [base,
                    base + d * 0.18,
                    base + d * 0.36,
                    base + d * 0.55,
                    base + d * 0.78,
                    w]
        case .falling:
            // Start higher, end at current wait
            let base = w + d
            return [base,
                    base - d * 0.18,
                    base - d * 0.36,
                    base - d * 0.55,
                    base - d * 0.78,
                    w]
        default:
            // Stable/unknown: gentle noise around current value
            return [w - 1, w + 0.5, w - 0.5, w + 1, w - 0.5, w]
        }
    }

    private var trendLabel: String {
        switch live.trend {
        case .rising:  return "Rising ↑"
        case .falling: return "Falling ↓"
        default:       return "Steady →"
        }
    }

    private var trendColor: Color {
        switch live.trend {
        case .rising:  return AppColor.error
        case .falling: return AppColor.success
        default:       return AppColor.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            WaitSparkline(points: sparklinePoints, color: color)
            Text(trendLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(trendColor)
            Spacer(minLength: 0)
        }
        .animation(AppMotion.standard, value: live.trend)
    }
}

// MARK: - Status pill (shared)

struct StatusPill: View {
    enum Style {
        case open
        case closed(String)

        var color: Color {
            switch self {
            case .open:              return AppColor.success
            case .closed(let label):
                let lo = label.lowercased()
                if lo.contains("down") || lo.contains("refurb") { return AppColor.warning }
                return AppColor.textTertiary
            }
        }
    }

    let label: String
    let style: Style

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Lightning lane pill (shared)

struct LightningLanePill: View {
    var body: some View {
        Label("LL", systemImage: "bolt.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColor.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppColor.warning.opacity(0.12), in: Capsule())
    }
}

// MARK: - Single rider pill (full sheet only)

private struct SingleRiderPill: View {
    let minutes: Int

    var body: some View {
        Label("\(minutes) SR", systemImage: "person.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppColor.brandPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppColor.brandPrimary.opacity(0.10), in: Capsule())
    }
}

// MARK: - Action buttons (shared between peek and full)

/// Log Ride button with 1.5 s "Logged ✓" confirmation state and haptic feedback.
///
/// `action` returns `true` on confirmed save, `false` on failure or no-op.
/// The confirmation state and haptic only fire when `action()` returns `true`,
/// so a SwiftData save failure silently does nothing (the parent shows its own alert).
struct LogRideButton: View {
    let action: () -> Bool

    @State private var pressed = false
    @State private var logged  = false

    var body: some View {
        Button {
            guard !logged else { return }
            let success = action()
            guard success else { return }
            // Haptic feedback — only fire on confirmed save.
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            // Confirmation state: show "Logged ✓" for 1.5 seconds then revert.
            withAnimation(AppMotion.quick) { logged = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1500))
                withAnimation(AppMotion.quick) { logged = false }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text(logged ? "Logged ✓" : "Log Ride")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                logged ? AppColor.success.opacity(0.18) : AppColor.success,
                in: RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .foregroundStyle(logged ? AppColor.success : .white)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .disabled(logged)
        .animation(AppMotion.quick, value: pressed)
        .animation(AppMotion.quick, value: logged)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !logged { pressed = true } }
                .onEnded   { _ in pressed = false }
        )
    }
}

struct AddToMyDayButton: View {
    let isPlanned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isPlanned ? "Added to My Day" : "Add to My Day",
                systemImage: isPlanned ? "checkmark" : "plus"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isPlanned ? AppColor.skeleton : AppColor.textPrimary,
                in: RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .foregroundStyle(isPlanned ? AppColor.textSecondary : Color(.systemBackground))
        }
        .buttonStyle(.plain)
        .disabled(isPlanned)
        .animation(AppMotion.quick, value: isPlanned)
    }
}

// MARK: - Directions chip (full sheet only)

/// Opens Apple Maps with walking directions to the selected ride's coordinates.
/// Uses MKMapItem.openInMaps so no MKDirections network request is required.
private struct DirectionsChip: View {
    let coordinate: CLLocationCoordinate2D
    let rideName:   String

    var body: some View {
        Button {
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem   = MKMapItem(placemark: placemark)
            mapItem.name  = rideName
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ])
        } label: {
            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.accentColor.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: AppRadius.md)
                )
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Get walking directions to \(rideName) in Apple Maps")
    }
}

// MARK: - Previews

#Preview("Full — with ride, ridden") {
    let annotation = MapRideAnnotation.stub(
        id: "mk|seven-dwarfs",
        name: "Seven Dwarfs Mine Train",
        land: "Fantasyland",
        category: .thrill
    )
    let marker = EnrichedMarker(
        annotation:    annotation,
        liveState:     nil,
        isRidden:      true,
        isLoggedToday: true,
        isPlanned:     false
    )
    return VStack {
        Spacer()
        ZStack {
            Color(.systemBackground)
            RideMapSheetContent(
                marker: marker,
                detent: .full,
                onLogRide: { false },
                onAddToMyDay: {},
                onDismiss: {},
                onExpandSheet: {}
            )
        }
        .frame(height: 520)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }
    .ignoresSafeArea()
}

#Preview("Peek — with live data") {
    let annotation = MapRideAnnotation.stub(
        id: "mk|haunted-mansion",
        name: "Haunted Mansion",
        land: "Liberty Square",
        category: .darkRide
    )
    let marker = EnrichedMarker(
        annotation:    annotation,
        liveState:     nil,
        isRidden:      false,
        isLoggedToday: false,
        isPlanned:     false
    )
    return VStack {
        Spacer()
        ZStack {
            Color(.systemBackground)
            RideMapSheetContent(
                marker: marker,
                detent: .peek,
                onLogRide: { false },
                onAddToMyDay: {},
                onDismiss: {},
                onExpandSheet: {}
            )
        }
        .frame(height: 260)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }
    .ignoresSafeArea()
}

#Preview("Collapsed — no ride") {
    VStack {
        Spacer()
        ZStack {
            Color(.systemBackground)
            RideMapSheetContent(
                marker: nil,
                detent: .collapsed,
                onLogRide: { false },
                onAddToMyDay: {},
                onDismiss: {},
                onExpandSheet: {}
            )
        }
        .frame(height: 72)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }
    .ignoresSafeArea()
}

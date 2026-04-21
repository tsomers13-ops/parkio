// RideMarkerView.swift — Ambient and selected ride markers for the map canvas.
//
// Design system:
//   Ambient  — 18pt dot (26pt with badge). White ring 1.5pt. Colored fill.
//              Ridden rides: 50% opacity + 55% saturation + checkmark beneath.
//              Optional zoom-gated name label (labelOpacity: 1.0) — single-line
//              9pt medium text, 64pt max-width, suppressed on ridden rides.
//              labelOpacity drives both insertion/removal (via .transition(…))
//              and continuous fades for intermediate values.
//              Trend badge: 11pt circle pinned top-trailing, offset (5, -5)
//              outside the dot boundary. Visible for .rising / .falling only.
//              Suppressed on ridden rides. Derives from marker.liveState?.trend
//              — no call-site changes required.
//   Selected — 48pt accent halo / 44pt white ring / 36pt dot. Shadow radius 12.
//              Category SF Symbol or wait number.
//              Repeating pulse (1.0 → 1.06 → 1.0, 2.4s easeInOut) when
//              Reduce Motion is OFF. Static at scale 1.0 when Reduce Motion ON.
//              Downward stem triangle. Frosted label pill below (80–160pt wide).
//              Stem + label stagger in 0.08s after pin head.
//   Minimal  — 12pt compact dot for priority-3 background context rides.
//              isPlanned: accentColor ring (1.5pt, 0.70 opacity) at 17pt.
//
// ── Anchor contract ───────────────────────────────────────────────────────────
//
//   MapKit uses anchor: .bottom, so the view's BOTTOM EDGE must sit at the
//   geographic coordinate. Any content that extends BELOW the semantic pin
//   point (name label, ridden tick, selected label pill) must NOT participate
//   in the measured layout height — it must render as an overlay.
//
//   Ambient RideMarkerView
//     • Measured height = dotHead only  (dotSize + 3 pt white ring)
//     • anchor: .bottom → dot bottom edge = coordinate  ✓
//     • ridden tick + name label → .overlay(alignment: .bottom) with
//       alignmentGuide(.bottom){ d in d[.top] - gap } so the overlay's
//       top begins `gap` pt below the dot's bottom edge.
//
//   SelectedRideMarkerView
//     • Measured height = pinHead (48 pt) + stem (6 pt) = 54 pt
//     • anchor: .bottom → stem TIP = coordinate  ✓
//     • Stem is always in layout (consistent 54 pt height) — visual appearance
//       driven by detailsVisible opacity/scale rather than conditional insertion.
//     • labelPill → .overlay(alignment: .bottom) with alignmentGuide placing
//       the pill top at the stem tip (0 pt gap, matching original spacing: 0).
//
// Trend badge type note:
//   WaitTrend (WaitTimeCache.swift) already covers rising / falling / stable /
//   unknown, so no WaitTrendDirection enum is defined here. A fileprivate
//   extension on WaitTrend adds the two helpers the badge view needs:
//   `badgeSystemImage` (clean vertical arrows at 7pt) and `isActionable`
//   (filters out noise-only states stable + unknown).
//
// Label animation note:
//   Labels use an asymmetric transition:
//     Reduce Motion OFF:
//       insertion — opacity + offset(y: 4): label starts 4 pt below its resting
//                   position and drifts upward as it fades in.
//       removal   — opacity only.
//     Reduce Motion ON:
//       insertion — opacity only (no translation).
//       removal   — opacity only.
//   Both cases respect the per-marker staggered delay (0.080–0.136 s across
//   8 deterministic buckets from a DJB2-style fold of the annotation's stable
//   composite ID). Delay is kept for Reduce Motion since it prevents
//   simultaneous label pop-in without adding perceptible motion.
//
// All values derive from EnrichedMarker computed properties — no raw data
// access at the view layer. Keeps markers fast and diff-friendly.

import SwiftUI

// MARK: - Ambient marker

struct RideMarkerView: View {
    let marker:       EnrichedMarker
    /// 0.0 = label fully hidden (no layout space consumed).
    /// 1.0 = label fully visible.
    /// Intermediate values are valid for caller-driven partial fades.
    var labelOpacity: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // dotHead is the ONLY measured content.
        // anchor: .bottom therefore places the DOT'S BOTTOM EDGE at the coordinate.
        // The ridden tick and name label live in an overlay so they extend below
        // the dot without affecting the measured layout height.
        dotHead
            .overlay(alignment: .bottom) {
                belowDotContent
            }
            .opacity(marker.isRidden ? 0.50 : 1.0)
            .saturation(marker.isRidden ? 0.55 : 1.0)
            .animation(AppMotion.quick, value: marker.isRidden)
            // Asymmetric label animation:
            //   fade-in  — AppMotion.standard + per-marker staggered delay.
            //   fade-out — AppMotion.quick, no delay.
            // The stagger is preserved under Reduce Motion to avoid simultaneous
            // pop-in; the motion itself is removed via labelTransition above.
            .animation(
                labelOpacity > 0
                    ? AppMotion.standard.delay(labelFadeInDelay)
                    : AppMotion.quick,
                value: labelOpacity
            )
            .dynamicTypeSize(.large ... .large)
    }

    // ── Below-dot overlay ─────────────────────────────────────────────────────
    //
    // Ridden tick OR name label — never both.
    //
    // alignmentGuide(.bottom) { d in d[.top] - belowDotGap } positions the
    // content so its top edge starts `belowDotGap` pt below the dot's bottom:
    //
    //   alignmentGuide reports the content's .bottom as d[.top] - gap = -gap.
    //   The overlay aligns content's .bottom with parent's .bottom (dot bottom).
    //   → content top = dot bottom + gap  ✓
    //
    // belowDotGap = 2 pt for plain dots, 4 pt for badge dots — matches the
    // original VStack(spacing: 2) + .offset(y: 2 for badge dot) behaviour.

    @ViewBuilder
    private var belowDotContent: some View {
        if marker.isRidden {
            riddenTick
                .transition(.opacity)
                .alignmentGuide(.bottom) { d in d[.top] - belowDotGap }
        } else if labelOpacity > 0 {
            nameLabel
                .opacity(labelOpacity)
                .transition(labelTransition)
                .alignmentGuide(.bottom) { d in d[.top] - belowDotGap }
        }
    }

    // ── Accessibility ─────────────────────────────────────────────────────────

    /// Insertion uses an upward drift when Reduce Motion is off; opacity-only
    /// when Reduce Motion is on. Removal is always opacity-only.
    private var labelTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 4)),
                removal:   .opacity
              )
    }

    // ── Per-marker staggered delay ────────────────────────────────────────────

    private static let labelBaseDelay: Double = 0.08

    /// Per-marker extra offset in 0.000 ... 0.056 s (8 buckets × 0.008 s).
    /// Derived from a DJB2-style polynomial fold of the stable annotation ID
    /// ("Park|Land|Name"). Stable across launches — does NOT use Swift's
    /// randomised hashValue. Combined range: 0.080 ... 0.136 s.
    private var labelFadeInDelay: Double {
        let hash = marker.annotation.id.unicodeScalars.reduce(0) { (acc: Int, scalar) in
            (acc &* 31) &+ Int(scalar.value)
        }
        let bucket = abs(hash) % 8
        return Self.labelBaseDelay + Double(bucket) * 0.008
    }

    // ── Dot ──────────────────────────────────────────────────────────────────

    private var dotHead: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: dotSize + 3, height: dotSize + 3)

            Circle()
                .fill(marker.markerColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: marker.markerColor.opacity(0.35), radius: 3, x: 0, y: 1.5)
                .animation(AppMotion.standard, value: marker.markerColor)

            if let badge = marker.badgeText {
                Text(badge)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(AppMotion.standard, value: badge)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !marker.isRidden,
               let trend = marker.liveState?.trend,
               trend.isActionable {
                AmbientTrendBadge(trend: trend)
                    .offset(x: 5, y: -5)
                    .transition(.scale(scale: 0.4, anchor: .topTrailing).combined(with: .opacity))
                    .animation(AppMotion.standard, value: trend)
            }
        }
    }

    // ── Below-dot content views ───────────────────────────────────────────────

    private var riddenTick: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 7, weight: .black))
            .foregroundStyle(marker.markerColor)
    }

    private var nameLabel: some View {
        Text(marker.annotation.rideName)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 64)
    }

    // ── Layout helpers ────────────────────────────────────────────────────────

    /// Gap between the dot's bottom edge and the top of below-dot content.
    /// Badge dot (26 pt) warrants slightly more room than the plain dot (18 pt)
    /// to maintain visual balance — matches the original VStack(spacing: 2) +
    /// .offset(y: 2) for badge-dot behaviour.
    private var belowDotGap: CGFloat { dotSize == 26 ? 4 : 2 }

    private var dotSize: CGFloat {
        marker.badgeText != nil ? 26 : 18
    }
}

// MARK: - Ambient trend badge

private struct AmbientTrendBadge: View {
    let trend: WaitTrend

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: 11, height: 11)
                .shadow(color: badgeColor.opacity(0.45), radius: 2, x: 0, y: 1)
            Image(systemName: trend.badgeSystemImage)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var badgeColor: Color {
        switch trend {
        case .rising:  return AppColor.error
        case .falling: return AppColor.success
        default:       return AppColor.textSecondary
        }
    }
}

// MARK: - WaitTrend badge helpers (fileprivate — RideMarkerView.swift only)

fileprivate extension WaitTrend {

    var badgeSystemImage: String {
        switch self {
        case .rising:  return "arrow.up"
        case .falling: return "arrow.down"
        case .stable:  return "arrow.right"
        case .unknown: return "minus"
        }
    }

    var isActionable: Bool {
        self == .rising || self == .falling
    }
}

// MARK: - Selected marker

struct SelectedRideMarkerView: View {
    let marker: EnrichedMarker

    @State private var pulsed:         Bool = false
    @State private var detailsVisible: Bool = false
    @State private var isLive:         Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Measured layout: pinHead (48 pt) + stem (6 pt) = 54 pt total.
        // anchor: .bottom places the STEM TIP at the geographic coordinate.
        //
        // The stem is always present in the VStack (consistent 54 pt height).
        // Its visual appearance is driven by detailsVisible + opacity/scale —
        // NOT conditional insertion — so the measured height never jumps and
        // the anchor remains stable throughout the appearance animation.
        //
        // The labelPill is rendered in an overlay so it extends below the stem
        // tip without inflating the measured height or shifting the anchor.
        VStack(spacing: 0) {
            pinHead

            // Stem: always in layout for anchor stability.
            // Fades + scales in when detailsVisible = true (AppMotion.spring).
            stem
                .opacity(detailsVisible ? 1 : 0)
                .scaleEffect(detailsVisible ? 1 : 0.4, anchor: .top)
        }
        .overlay(alignment: .bottom) {
            if detailsVisible {
                labelPill
                    // alignmentGuide(.bottom) { d in d[.top] } positions the pill
                    // so its top edge aligns with the VStack's bottom (stem tip).
                    // → 0 pt gap, matching the original VStack(spacing: 0).
                    .alignmentGuide(.bottom) { d in d[.top] }
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .top)))
            }
        }
        .onAppear {
            isLive = true
            // Pulse is skipped entirely when Reduce Motion is on — scaleEffect
            // stays at 1.0 and no repeating animation is scheduled.
            if !reduceMotion { pulsed = true }
            Task {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard isLive else { return }
                withAnimation(AppMotion.spring) { detailsVisible = true }
            }
        }
        .onDisappear {
            isLive         = false
            pulsed         = false
            detailsVisible = false
        }
    }

    // MARK: - Pin head

    private var pinHead: some View {
        ZStack {
            Circle()
                .strokeBorder(marker.markerColor.opacity(0.25), lineWidth: 3)
                .frame(width: 48, height: 48)
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
            Circle()
                .fill(marker.markerColor)
                .frame(width: 36, height: 36)
                .shadow(color: marker.markerColor.opacity(0.55), radius: 12, x: 0, y: 6)
            Group {
                if let badge = marker.badgeText {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: marker.annotation.category.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        // pulsed is never set to true under Reduce Motion, so scaleEffect
        // remains at 1.0 and the repeating animation never fires.
        .scaleEffect(pulsed ? 1.06 : 1.0)
        .animation(
            pulsed
                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.15),
            value: pulsed
        )
    }

    // MARK: - Stem

    private var stem: some View {
        PinStem()
            .fill(marker.markerColor)
            .frame(width: 10, height: 6)
    }

    // MARK: - Label pill

    private var labelPill: some View {
        VStack(spacing: 2) {
            Text(marker.annotation.rideName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .dynamicTypeSize(.large ... .xxLarge)

            if let live = marker.liveState {
                if live.status.isRideable {
                    HStack(spacing: 3) {
                        Text(live.waitDisplay)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(marker.markerColor)
                        if live.trend == .rising || live.trend == .falling {
                            Image(systemName: live.trend.systemImage)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(
                                    live.trend == .rising ? AppColor.error : AppColor.success
                                )
                        }
                    }
                } else {
                    Text(live.status.displayLabel)
                        .font(.caption2)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }

            if marker.isPlanned {
                Label("In Plan", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppColor.success)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        .frame(minWidth: 80, maxWidth: 160)
    }
}

// MARK: - Pin stem (downward triangle)

private struct PinStem: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:    CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Minimal marker (priority 3 — background context rides)

struct MinimalPinView: View {
    let color:     Color
    var isPlanned: Bool = false

    var body: some View {
        ZStack {
            if isPlanned {
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.70), lineWidth: 1.5)
                    .frame(width: 17, height: 17)
            }
            Circle()
                .fill(Color.white)
                .frame(width: 15, height: 15)
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .animation(AppMotion.standard, value: color)
        }
        .opacity(0.75)
    }
}

// MARK: - Previews

#Preview("Ambient markers — label visible") {
    let stubs: [EnrichedMarker] = [
        EnrichedMarker(
            annotation: .stub(id: "1", name: "Space Mountain", category: .thrill),
            liveState: nil, isRidden: false, isLoggedToday: false, isPlanned: false
        ),
        EnrichedMarker(
            annotation: .stub(id: "2", name: "Pirates", category: .darkRide),
            liveState: nil, isRidden: true, isLoggedToday: true, isPlanned: false
        ),
        EnrichedMarker(
            annotation: .stub(id: "3", name: "Small World", category: .family),
            liveState: nil, isRidden: false, isLoggedToday: false, isPlanned: true
        ),
    ]
    return HStack(spacing: 28) {
        ForEach(stubs) { RideMarkerView(marker: $0, labelOpacity: 1) }
    }
    .padding(40)
    .background(AppColor.background)
}

#Preview("Ambient markers — label faded (0.4)") {
    let stub = EnrichedMarker(
        annotation: .stub(id: "1", name: "Haunted Mansion", category: .darkRide),
        liveState: nil, isRidden: false, isLoggedToday: false, isPlanned: false
    )
    return HStack(spacing: 28) {
        VStack(spacing: 8) {
            RideMarkerView(marker: stub, labelOpacity: 1.0)
            Text("opacity 1.0").font(.caption2).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            RideMarkerView(marker: stub, labelOpacity: 0.4)
            Text("opacity 0.4").font(.caption2).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            RideMarkerView(marker: stub, labelOpacity: 0)
            Text("opacity 0").font(.caption2).foregroundStyle(.secondary)
        }
    }
    .padding(40)
    .background(AppColor.background)
}

#Preview("Trend badge — rising / falling") {
    HStack(spacing: 32) {
        VStack(spacing: 8) {
            AmbientTrendBadge(trend: .rising)
            Text("rising").font(.caption2).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            AmbientTrendBadge(trend: .falling)
            Text("falling").font(.caption2).foregroundStyle(.secondary)
        }
    }
    .padding(40)
    .background(AppColor.background)
}

#Preview("Selected marker — no live data") {
    SelectedRideMarkerView(
        marker: EnrichedMarker(
            annotation: .stub(id: "1", name: "Haunted Mansion", category: .darkRide),
            liveState: nil, isRidden: false, isLoggedToday: false, isPlanned: true
        )
    )
    .padding(40)
    .background(AppColor.background)
}

#Preview("Ridden — label suppressed") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            RideMarkerView(marker: EnrichedMarker(
                annotation: .stub(id: "r1", name: "Big Thunder", category: .thrill),
                liveState: nil, isRidden: false, isLoggedToday: false, isPlanned: false
            ), labelOpacity: 1)
            Text("Unridden").font(.caption2).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            RideMarkerView(marker: EnrichedMarker(
                annotation: .stub(id: "r2", name: "Big Thunder", category: .thrill),
                liveState: nil, isRidden: true, isLoggedToday: true, isPlanned: false
            ), labelOpacity: 1)
            Text("Ridden (label hidden)").font(.caption2).foregroundStyle(.secondary)
        }
    }
    .padding(40)
    .background(AppColor.background)
}

#Preview("Minimal — planned vs. unplanned") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            MinimalPinView(color: AppColor.waitColor(minutes: 25), isPlanned: false)
            Text("Unplanned").font(.caption2).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            MinimalPinView(color: AppColor.waitColor(minutes: 25), isPlanned: true)
            Text("In plan").font(.caption2).foregroundStyle(.secondary)
        }
    }
    .padding(40)
    .background(AppColor.background)
}

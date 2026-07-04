// ParkMapCanvasView.swift — Custom image-based park map with normalized pin overlay.
//
// Layout:
//   • Background: park map image asset ("<parkId_with_underscores>_map") or solid fallback.
//   • Pins: GeometryReader converts ParkMapPin.canvasPoint → screen position.
//     Coordinate formula: x = contentSize.width * mapX + visualOffsetX
//                          y = contentSize.height * mapY + visualOffsetY
//   • Selection: reads/writes MapViewModel.selectedRideId.
//   • Live data: each ParkMapPin matched to EnrichedMarkerWithSelection via internalRideId.
//   • Pan/zoom: two .simultaneousGesture modifiers (avoids type-checker crash from
//     `some Gesture` composition with simultaneously(with:)).
//   • Debug: MapDebugOverlayView when ParkMapViewModel.debugMode == true.
//
// Content canvas model:
//   Content canvas = composition.contentSize (e.g. 1000×1100 for Magic Kingdom).
//   fitScale = min(viewport.w / (cs.w × dv.w), viewport.h / (cs.h × dv.h))
//   where dv = composition.defaultViewport (0.90×0.90 for all parks).
//   At fitScale the defaultViewport fills the screen exactly.
//
//   minScale = fitScale × 0.90 → slight over-zoom-out for rubber-band feel
//   fitScale (computed)        → default — park's defaultViewport visible, centered
//   maxScale = fitScale × 6.00 → 6× from fit; comfortable for ride inspection
//
//   Pan clamping: maxOffset = (contentSize × scale − viewport) / 2
//   At fitScale: maxOffset ≈ 0 (full defaultViewport visible, panning minimal).
//   At 2×fitScale: maxOffset = contentSize × fitScale / 2 (meaningful exploration).
//
// Adding a park map image:
//   Add an asset named "<parkId>_map" to Assets.xcassets (e.g. "disneyland_map").
//   ParkMapViewModel.mapImageName derives the name automatically.

import SwiftUI
import SwiftData

// MARK: - Main canvas

struct ParkMapCanvasView: View {
    @Environment(MapViewModel.self)         private var mapVM
    @Environment(ParkMapViewModel.self)     private var parkMapVM
    @Environment(CalibrationViewModel.self) private var calibrationVM

    // ── Transform state ────────────────────────────────────────────────────────
    // scale/baseScale are set to the correct fitScale in .onAppear.
    // They start at 1.0 as a safe non-zero placeholder; the first layout pass
    // immediately corrects them before the view renders its first frame.
    @State private var scale:        CGFloat = 1.0
    @State private var offset:       CGSize  = .zero
    @State private var baseScale:    CGFloat = 1.0
    @State private var baseOffset:   CGSize  = .zero
    /// Captured by GeometryReader so resetZoom() can compute fitScale without
    /// needing a size parameter at the call site (onChange has no size in scope).
    @State private var viewportSize: CGSize  = .zero

    var body: some View {
        GeometryReader { geo in
            canvasStack(size: geo.size)
                .onAppear {
                    // Capture viewport size and snap to the park's correct fit view
                    // on first render. No animation — avoids a zoom-out flash.
                    viewportSize = geo.size
                    let fs = mapVM.fitScale(for: geo.size)
                    scale     = fs
                    baseScale = fs
                }
                // Keep viewportSize current on device rotation / split-screen resize.
                .onChange(of: geo.size) { _, newSize in
                    viewportSize = newSize
                    // Re-fit: if the user hasn't zoomed in, stay at the new fitScale.
                    if !mapVM.isZoomed { resetZoom() }
                }
        }
        .clipped()
        .ignoresSafeArea(edges: .all)
        // When mapVM.isZoomed is cleared (park switch, toolbar reset button), return
        // to the default fit view smoothly.
        .onChange(of: mapVM.isZoomed) { _, zoomed in
            if !zoomed { resetZoom() }
        }
        // Park switches always reset the camera even if isZoomed was already false.
        .onChange(of: mapVM.parkId) { _, _ in
            withAnimation(AppMotion.standard) { resetZoom() }
        }
    }

    // MARK: - Fit scale

    /// Computes the scale at which the park's defaultViewport exactly fills the
    /// given screen viewport. Uses whichever axis is the tighter constraint.
    ///
    /// For MK (1000×1100, defaultViewport 0.9×0.9) on a 390×844 screen:
    ///   fitScale = min(390 / 900, 844 / 990) = min(0.433, 0.852) = 0.433
    ///
    /// minScale = fitScale × 0.90 — slight over-zoom-out for rubber-band feel.
    /// maxScale = fitScale × 6.00 — 6× zoom from fit view (comfortable inspection).
    private func fitScale(for viewport: CGSize) -> CGFloat {
        mapVM.fitScale(for: viewport)
    }

    private func minScale(for viewport: CGSize) -> CGFloat { fitScale(for: viewport) * 0.90 }
    private func maxScale(for viewport: CGSize) -> CGFloat { fitScale(for: viewport) * 6.00 }

    // MARK: - Pan clamping

    /// Clamps a proposed pan offset so the content never scrolls past its edges.
    ///
    /// At fitScale: scaledContent ≈ viewport → maxOffset ≈ 0 (full park visible,
    ///   panning effectively disabled). At 2× fitScale: maxOffset = contentSize/4.
    private func clampedOffset(_ proposed: CGSize, viewport: CGSize) -> CGSize {
        let cs   = mapVM.currentComposition.contentSize
        let maxX = max(0, (cs.width  * scale - viewport.width)  / 2)
        let maxY = max(0, (cs.height * scale - viewport.height) / 2)
        return CGSize(
            width:  min(max(proposed.width,  -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    // MARK: - Canvas stack

    /// Builds the layered map view.
    ///
    /// Structure:
    ///   Color.clear.frame(viewport)        ← viewport-sized anchor for scaleEffect
    ///     .overlay { contentZStack(cs) }   ← content centered on viewport center
    ///   .scaleEffect(scale, .center)       ← zoom from viewport center
    ///   .offset(panOffset)                 ← user pan (clamped to content bounds)
    ///
    /// Why overlay: `.overlay` centers its content on the base view's center (= viewport
    /// center). `.scaleEffect(anchor: .center)` then scales from the same point.
    /// At fitScale the content shrinks to the park's defaultViewport, perfectly centered.
    ///
    /// contentSize source: composition.contentSize (e.g. 1000×1100 for MK).
    /// This is a stable authored value, NOT derived from the viewport dimensions.
    private func canvasStack(size: CGSize) -> some View {
        // ── Composition for the current park ────────────────────────────────────
        // Reading this here (not as a stored property) means it always reflects
        // the current parkId and requires zero extra state in MapViewModel.
        let composition = mapVM.currentComposition
        let cs          = composition.contentSize   // e.g. CGSize(1000, 1100) for MK
        let fs          = fitScale(for: size)

        return Color.clear
            .frame(width: size.width, height: size.height)
            .overlay {
                // Content canvas — renders at cs, centered on viewport by .overlay.
                ZStack(alignment: .topLeading) {
                    // ── Background layer ─────────────────────────────────────────
                    // ParkMapBackgroundView now owns its own frame via composition.contentSize.
                    // No size argument needed — the composition carries the canvas dimensions.
                    ParkMapBackgroundView(composition: composition)

                    if parkMapVM.debugMode {
                        // Calibration mode: draggable pin handles.
                        // PinsLayerView hidden to avoid overlapping with handles.
                        MapCalibrationView()
                    } else {
                        // Normal mode: enriched ride pins with live wait data.
                        // Pins use pin.canvasPoint(in: cs) → CGPoint(x: cs.width * mapX, y: cs.height * mapY)
                        // A pin at mapX=0.5, mapY=0.5 lands at (cs.width/2, cs.height/2) = canvas center. ✓
                        PinsLayerView(size: cs, mapVM: mapVM, parkMapVM: parkMapVM)
                    }
                }
                // Explicit frame pins the ZStack at contentSize so .overlay doesn't
                // shrink it to viewportSize.
                .frame(width: cs.width, height: cs.height)
            }
            // ── Transform ───────────────────────────────────────────────────────
            // anchor: .center → scale from viewport center (guaranteed by Color.clear base)
            .scaleEffect(scale, anchor: .center)
            .offset(x: offset.width, y: offset.height)
            // ── Interaction ──────────────────────────────────────────────────────
            .contentShape(Rectangle())
            .onTapGesture { mapVM.dismiss() }
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        scale = min(
                            max(baseScale * v.magnification, minScale(for: size)),
                            maxScale(for: size)
                        )
                        // Re-clamp offset as content expands/contracts during pinch.
                        offset = clampedOffset(offset, viewport: size)
                    }
                    .onEnded { _ in
                        baseScale = scale
                        if scale > fs + 0.02 || offset != .zero {
                            mapVM.isZoomed = true
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { v in
                        let proposed = CGSize(
                            width:  baseOffset.width  + v.translation.width,
                            height: baseOffset.height + v.translation.height
                        )
                        offset = clampedOffset(proposed, viewport: size)
                    }
                    .onEnded { _ in
                        baseOffset = offset
                        if offset != .zero || scale > fs + 0.02 {
                            mapVM.isZoomed = true
                        }
                    }
            )
    }

    // MARK: - Reset

    /// Returns to the default fit view: the park's defaultViewport fills the screen.
    /// Uses viewportSize (captured by .onAppear) so the correct fitScale is available
    /// in onChange handlers where GeometryReader's size is not in scope.
    private func resetZoom() {
        guard viewportSize != .zero else { return }
        let fs = fitScale(for: viewportSize)
        withAnimation(AppMotion.standard) {
            scale      = fs
            offset     = .zero
            baseScale  = fs
            baseOffset = .zero
        }
    }
}

// MARK: - Pins layer (separate struct keeps type-checker fast)

private struct PinsLayerView: View {
    let size: CGSize
    let mapVM: MapViewModel
    let parkMapVM: ParkMapViewModel

    private var lookup: [String: EnrichedMarkerWithSelection] {
        // Build a lookup from all park annotations (not decluttered — canvas uses its own pin layer).
        Dictionary(
            uniqueKeysWithValues: mapVM.annotations.compactMap { ann -> (String, EnrichedMarkerWithSelection)? in
                guard let enriched = mapVM.enrichedMarker(for: ann.id) else { return nil }
                return (ann.id, enriched)
            }
        )
    }

    private var sortedPins: [ParkMapPin] {
        parkMapVM.pins.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        let lkp = lookup
        ZStack(alignment: .topLeading) {
            ForEach(sortedPins) { pin in
                PinView(
                    pin: pin,
                    size: size,
                    enriched: lkp[pin.internalRideId],
                    isSelected: mapVM.selectedRideId == pin.internalRideId,
                    onTap: { mapVM.selectRide(pin.internalRideId); mapVM.isZoomed = true }
                )
                .zIndex(mapVM.selectedRideId == pin.internalRideId ? 100 : Double(4 - pin.priority))
            }
        }
    }
}

// MARK: - Single pin view

/// Standalone struct so the ForEach closure stays a single expression.
/// All derived values are lazy computed properties — no let bindings in body.
///
/// Animation notes:
///   • Initial appearance — pins stagger in by priority (P1 leads, P3 lags 100ms).
///     Driven by @State appeared + .task(id: pin.id).
///   • Selection — spring animation with asymmetric scale transitions.
///     Ambient → selected: .scale(0.55, anchor: .bottom) — pin inflates upward.
///     Inside SelectedRideMarkerView: pin head expands first; stem + label stagger
///     in 0.08s later growing downward. Pin head pulses with a 2.4s easeInOut loop.
///     Selected → ambient: .scale(0.70, anchor: .bottom) with AppMotion.standard.
///   • Ambient → ambient (wait update): markerView identity is stable — only internal
///     value animations fire (numericText roll, color cross-fade, ridden desaturation).
///   • Ridden ambient markers: 50% opacity + 55% saturation (handled by RideMarkerView).
///   • Priority 3 pins render as MinimalPinView (12pt dot) to reduce visual clutter.
private struct PinView: View {
    let pin: ParkMapPin
    let size: CGSize
    let enriched: EnrichedMarkerWithSelection?
    let isSelected: Bool
    let onTap: () -> Void

    /// Controls initial-appearance animation. Starts false; set true by .task after
    /// a priority-based delay so higher-priority pins appear first.
    @State private var appeared = false

    private var pinX: CGFloat { pin.canvasPoint(in: size).x }
    private var pinY: CGFloat { pin.canvasPoint(in: size).y }
    private var a11yLabel: String { enriched?.base.accessibilityLabel ?? pin.displayName }

    var body: some View {
        markerView
            // ── Selection animation ───────────────────────────────────────────
            // Overrides the ambient withAnimation context from mapVM.selectRide().
            // Spring for selection (physical snap); standard for deselection (brisk exit).
            .animation(isSelected ? AppMotion.spring : AppMotion.standard, value: isSelected)
            // ── Initial appearance ────────────────────────────────────────────
            // Scale and fade in from nothing. After appeared = true these modifiers
            // resolve to identity and do not interfere with selection transitions.
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.5, anchor: .bottom)
            // ── Position ──────────────────────────────────────────────────────
            .position(x: pinX, y: pinY)
            // ── Stagger task ──────────────────────────────────────────────────
            // Fires once when the pin enters the view hierarchy.
            // P1 = 0ms, P2 = 50ms, P3 = 100ms — hero pins lead.
            .task(id: pin.id) {
                let delay = Double(pin.priority - 1) * 0.05
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                withAnimation(AppMotion.spring) { appeared = true }
            }
            // ── Interaction ───────────────────────────────────────────────────
            .onTapGesture { onTap() }
            // ── Accessibility ─────────────────────────────────────────────────
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11yLabel)
            .accessibilityHint("Double tap to view details")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var markerView: some View {
        if let enriched {
            if isSelected {
                // Selected state — full pin with pulsing head, staggered stem + label pill.
                // Inflates upward from the pin base on insertion; deflates on removal.
                SelectedRideMarkerView(marker: enriched.base)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.55, anchor: .bottom).combined(with: .opacity),
                        removal:   .scale(scale: 0.70, anchor: .bottom).combined(with: .opacity)
                    ))
            } else if pin.priority == 3 {
                // Priority 3 — background context rides. Compact 12pt dot, no badge.
                // Reduces visual noise in dense park areas without hiding the ride.
                MinimalPinView(color: enriched.base.markerColor)
                    .transition(.scale(scale: 0.60, anchor: .bottom).combined(with: .opacity))
            } else {
                // Standard ambient marker — 18pt dot (26pt with badge).
                // Ridden markers are desaturated + dimmed inside RideMarkerView.
                RideMarkerView(marker: enriched.base)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.60, anchor: .bottom).combined(with: .opacity),
                        removal:   .scale(scale: 0.80, anchor: .bottom).combined(with: .opacity)
                    ))
            }
        } else {
            // No enriched data yet — static placeholder until first wait-time fetch.
            StaticMapPinView(name: pin.displayName, isSelected: isSelected)
        }
    }
}

// MARK: - Static placeholder pin (shown before first wait-time fetch)

private struct StaticMapPinView: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(AppColor.textTertiary.opacity(0.8))
                .frame(width: isSelected ? 30 : 14, height: isSelected ? 30 : 14)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)

            if isSelected {
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 1)
                    .frame(maxWidth: 120)
            }
        }
    }
}

// MARK: - Reset zoom button

struct MapResetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(10)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter chip strip

struct MapFilterStrip: View {
    @Environment(MapViewModel.self) private var mapVM

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                FilterChip(label: "Unridden only", isActive: !mapVM.filters.showRidden) {
                    mapVM.toggleFilter(\.showRidden)
                }
                FilterChip(label: "< 30 min", isActive: mapVM.filters.onlyLowWait) {
                    mapVM.toggleFilter(\.onlyLowWait)
                }
                FilterChip(label: "Open only", isActive: mapVM.filters.hideClosed) {
                    mapVM.toggleFilter(\.hideClosed)
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .white : AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    isActive ? AppColor.textPrimary : Color(.systemBackground).opacity(0.88),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? Color.clear : AppColor.skeleton, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        .animation(AppMotion.quick, value: isActive)
    }
}

// MARK: - Previews

#Preview("Custom Canvas — Calibration (Debug On)") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM    = WaitTimeViewModel(container: container)
    let mapVM     = MapViewModel(parkId: "disneyland", waitTimeVM: waitVM)
    let parkMapVM = ParkMapViewModel.previewStub(parkId: "disneyland")
    parkMapVM.debugMode = true
    let calVM     = CalibrationViewModel()
    calVM.sync(from: parkMapVM)
    return ParkMapCanvasView()
        .environment(mapVM)
        .environment(parkMapVM)
        .environment(calVM)
        .modelContainer(container)
        .environment(waitVM)
}

#Preview("Custom Canvas — Normal (Debug Off)") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM    = WaitTimeViewModel(container: container)
    let mapVM     = MapViewModel(parkId: "magic-kingdom", waitTimeVM: waitVM)
    let parkMapVM = ParkMapViewModel.previewStub(parkId: "magic-kingdom")
    let calVM     = CalibrationViewModel()
    calVM.sync(from: parkMapVM)
    return ParkMapCanvasView()
        .environment(mapVM)
        .environment(parkMapVM)
        .environment(calVM)
        .modelContainer(container)
        .environment(waitVM)
}

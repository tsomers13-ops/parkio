// RideMapBottomSheetView.swift — Custom overlay bottom sheet for ride detail.
//
// Architecture:
//   • Pure SwiftUI overlay — no UIKit sheet APIs, no .sheet(), no presentationDetents.
//   • Positioned at the bottom of the screen via VStack { Spacer(); panel }.
//   • Reads/writes MapViewModel.sheetDetent as the single source of truth.
//   • Drag gestures snap to the nearest SheetDetent on release.
//   • .regularMaterial background with rounded top corners only.
//
// Gesture contract:
//   • DragGesture is attached exclusively to dragHandleStrip — the visible
//     grab-handle zone at the top of the panel — NOT to the panel VStack itself.
//     This is the critical structural decision: by keeping the gesture on a
//     *sibling* of RideMapSheetContent (not an ancestor), the full-detent
//     ScrollView is never in the DragGesture's ancestor hit-test chain and
//     can scroll freely without any competing recognizer.
//   • minimumDistance 6 prevents false activation on taps.
//   • Fling detection uses DragGesture.Value.velocity.height (true pt/s, iOS 16+).
//     velocity > ±400 pt/s snaps one level in the fling direction. This is the
//     correct signal for "fast flick" — predictedEndTranslation is a projected
//     *position*, not a speed, and misclassifies slow long drags as flings.
//   • Below the velocity threshold, nearest-detent-by-height wins (slow drag).
//   • Sheet drags do not propagate to the map because the sheet panel sits
//     above the map in ZStack order — SwiftUI gives gestures to the topmost
//     hit-tested view first.
//
// Selection contract (enforced by MapViewModel, not this view):
//   • Tap a pin         → selectedRideId set → sheetDetent becomes .peek
//   • Tap map backdrop  → dismiss() → selectedRideId nil, detent .collapsed
//   • Drag to .collapsed → sheetDetent = .collapsed but selection preserved
//     (user can re-expand without re-tapping the pin)
//
// My Day integration (Phase 5):
//   • addSelectedRideToMyDay() writes to MyDayStore via environment injection.
//   • Guard against duplicate additions — MyDayStore.addRide() is idempotent.
//   • MyDayStore is injected at app root; no prop-drilling required here.
//
// Ride logging safety:
//   • ride(matching:) resolves via Ride.id == annotation.id — both use the
//     same stableID format ("Park|Land|Name") seeded at first launch.
//     Direct ID match prevents cross-park collision (e.g. "Space Mountain"
//     at Magic Kingdom vs. Disneyland resolving to the wrong Ride record).
//   • logSelectedRide() returns Bool. On save failure, SwiftData changes are
//     rolled back and an alert is surfaced. LogRideButton shows "Logged ✓"
//     only when true is returned.

import SwiftUI
import SwiftData

// MARK: - RideMapBottomSheetView

struct RideMapBottomSheetView: View {
    @Environment(MapViewModel.self)      private var mapVM
    @Environment(WaitTimeViewModel.self) private var waitTimeVM
    @Environment(MyDayStore.self)        private var myDayStore
    @Environment(\.modelContext)         private var modelContext

    @Query private var allRides: [Ride]

    // Interactive drag offset in screen points.
    // Positive = user dragging the sheet downward (shrinking it).
    // Negative = user dragging upward (growing it) — this is clamped out.
    @State private var dragOffset:    CGFloat = 0
    @State private var showSaveError: Bool    = false

    var body: some View {
        GeometryReader { geo in
            let containerHeight = geo.size.height + geo.safeAreaInsets.bottom
            sheetStack(containerHeight: containerHeight)
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("Couldn't Save Ride", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your ride log couldn't be saved. Please try again.")
        }
    }

    private func sheetStack(containerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            sheetPanel(containerHeight: containerHeight)
        }
    }

    // MARK: - Sheet panel

    private func sheetPanel(containerHeight: CGFloat) -> some View {
        let targetHeight    = mapVM.sheetDetent.height(for: containerHeight)
        let minHeight       = SheetDetent.collapsed.height(for: containerHeight)
        let maxHeight       = SheetDetent.full.height(for: containerHeight)
        // Apply interactive offset while dragging; clamp to valid range.
        let effectiveHeight = max(minHeight, min(maxHeight, targetHeight - dragOffset))

        return VStack(spacing: 0) {
            // ── Drag handle — sole owner of the sheet DragGesture ────────────
            // Lives here as a sibling of RideMapSheetContent so the gesture is
            // never in the ScrollView's ancestor chain. The ScrollView (full
            // detent) therefore gets uncontested ownership of vertical touches
            // below this strip.
            dragHandleStrip(containerHeight: containerHeight)

            // ── Sheet content — no outer DragGesture ─────────────────────────
            // SheetDragHandle rendering was moved here from RideMapSheetContent
            // so the gesture and the pill live in the same view.
            RideMapSheetContent(
                marker:       mapVM.selectedEnrichedMarker,
                detent:       mapVM.sheetDetent,
                onLogRide:    logSelectedRide,
                onAddToMyDay: addSelectedRideToMyDay,
                onDismiss:    { mapVM.dismiss() },
                onExpandSheet: {
                    withAnimation(AppMotion.standard) {
                        mapVM.setSheetDetent(mapVM.sheetDetent.expanded)
                    }
                }
            )
            Spacer(minLength: 0)
        }
        .frame(height: effectiveHeight)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading:     20,
                bottomLeading:  0,
                bottomTrailing: 0,
                topTrailing:    20
            ),
            style: .continuous
        ))
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: -4)
        .animation(dragOffset == 0 ? AppMotion.standard : nil, value: mapVM.sheetDetent)
        .animation(AppMotion.quick, value: effectiveHeight)
        .onChange(of: mapVM.selectedRideId) { _, newId in
            if newId != nil, mapVM.sheetDetent == .collapsed {
                withAnimation(AppMotion.standard) {
                    mapVM.setSheetDetent(.peek)
                }
            }
        }
    }

    // MARK: - Drag handle strip

    /// Renders the visible grab-handle pill and wires the sheet DragGesture to it.
    ///
    /// This view is a *sibling* of RideMapSheetContent in the panel VStack, not
    /// a parent. That structural placement is what solves the scroll conflict:
    /// the DragGesture recognizer is completely outside the ScrollView's ancestor
    /// chain, so the ScrollView in full detent scrolls with zero competition.
    ///
    /// `frame(maxWidth: .infinity)` combined with `contentShape(Rectangle())` gives
    /// a full-width horizontal drag target while keeping the pill visually centered.
    private func dragHandleStrip(containerHeight: CGFloat) -> some View {
        SheetDragHandle()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(sheetDragGesture(containerHeight: containerHeight))
    }

    // MARK: - Drag gesture

    private func sheetDragGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let raw = value.translation.height
                dragOffset = raw > 0 ? raw : raw * 0.25
            }
            .onEnded { value in
                // Use the true fling velocity (pt/s) introduced in iOS 16.
                // DragGesture.Value.velocity is always available on iOS 17+.
                // predictedEndTranslation.height is a projected *position* delta,
                // not a speed — slow long drags produce large predicted positions
                // and are incorrectly classified as flings. velocity.height is
                // always a rate, so it's the right signal here.
                //
                // Fallback (defensive): if the property were somehow unavailable,
                // approximating via (predictedEnd - translation) gives a coarser
                // but directionally correct velocity estimate.
                let velocity: CGFloat = value.velocity.height

                let currentHeight = mapVM.sheetDetent.height(for: containerHeight) - dragOffset
                let nextDetent: SheetDetent

                if velocity < -400 {
                    nextDetent = mapVM.sheetDetent.expanded
                } else if velocity > 400 {
                    nextDetent = mapVM.sheetDetent.reduced
                } else {
                    nextDetent = mapVM.sheetDetent.nearest(to: currentHeight,
                                                           containerHeight: containerHeight)
                }

                withAnimation(AppMotion.standard) {
                    dragOffset = 0
                    mapVM.setSheetDetent(nextDetent)
                }
                AppHaptic.selection()
            }
    }

    // MARK: - Actions

    /// Logs the currently selected ride.
    ///
    /// Returns `true` on confirmed save so the caller (LogRideButton) can show
    /// "Logged ✓". Returns `false` — without showing success UI — when:
    ///   • no ride is selected or the stable-ID lookup finds no SwiftData match
    ///   • the ModelContext save throws (changes are rolled back via rollback())
    @discardableResult
    private func logSelectedRide() -> Bool {
        guard let marker = mapVM.selectedEnrichedMarker,
              let ride   = ride(matching: marker) else { return false }

        let log = RideLog(date: Date())
        ride.logs.append(log)

        do {
            try modelContext.save()
            return true
        } catch {
            // Undo the appended log — roll back all pending context changes.
            modelContext.rollback()
            showSaveError = true
            return false
        }
    }

    /// Add the selected ride to My Day. Idempotent — MyDayStore guards duplicates.
    private func addSelectedRideToMyDay() {
        guard let marker = mapVM.selectedEnrichedMarker else { return }
        myDayStore.addRide(
            rideId:  marker.annotation.id,
            name:    marker.annotation.rideName,
            land:    marker.annotation.land,
            parkId:  marker.annotation.parkId
        )
        AppHaptic.light()
    }

    /// Resolves the selected ride to its SwiftData record.
    ///
    /// Uses a direct Ride.id == annotation.id match. Both identifiers use the
    /// same stableID format ("Park|Land|Name") — see RideSeeder.Seed.stableID —
    /// so a direct match is unambiguous across parks. Name-only matching is
    /// intentionally not used; rides with the same name exist in multiple parks
    /// (e.g. "Space Mountain", "Big Thunder Mountain Railroad").
    private func ride(matching marker: EnrichedMarker) -> Ride? {
        allRides.first { $0.id == marker.annotation.id }
    }
}

// MARK: - Preview

#Preview {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM  = WaitTimeViewModel(container: container)
    let mapVM   = MapViewModel(parkId: "magic-kingdom", waitTimeVM: waitVM)
    mapVM.setSheetDetent(.peek)

    return ZStack {
        AppColor.background.ignoresSafeArea()
        RideMapBottomSheetView()
            .environment(mapVM)
            .environment(waitVM)
            .environment(MyDayStore())
    }
    .modelContainer(container)
}

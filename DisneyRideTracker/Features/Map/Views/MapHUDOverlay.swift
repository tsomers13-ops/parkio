// MapHUDOverlay.swift — Composites WaitTimeLegendView + MapOverlayFilterBar + ParkGlanceBar above the map canvas.
//
// Usage (in your parent map screen):
//
//   GeometryReader { geo in
//       ParkMapCanvasView()
//           .ignoresSafeArea()
//           .overlay(alignment: .bottom) {
//               MapHUDOverlay(bottomInset: geo.safeAreaInsets.bottom)
//           }
//   }
//
// The HUD reads MapViewModel from the environment (already injected by MapTabView).
// No additional environment calls are needed at the call site.
//
// Visibility rules:
//   Legend:     visible when hasLiveData && !sheetIsExpanded
//   Filter bar: visible when !sheetIsExpanded
//   Both:       hidden entirely in compact vertical size class (landscape iPhone)
//
// Animation contract:
//   Entrance — .spring(response: 0.38, dampingFraction: 0.82)   (deliberate, settled)
//   Exit     — .easeIn(duration: 0.22)                          (brisk, stays out of the way)
//
//   Local @State gates (legendVisible / filterBarVisible) are flipped inside
//   withAnimation so SwiftUI sees a structural change and applies the correct
//   transition curve. The views declare only the transition SHAPE (move + opacity
//   + scale); the caller (this file) owns the timing.

import SwiftUI

// MARK: - MapHUDOverlay

struct MapHUDOverlay: View {

    /// Pass geo.safeAreaInsets.bottom from a GeometryReader in the parent screen.
    let bottomInset: CGFloat

    @Environment(MapViewModel.self) private var mapVM
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // Local animation gates. Flipped with asymmetric withAnimation calls.
    @State private var legendVisible:    Bool = false
    @State private var filterBarVisible: Bool = false

    // MARK: - Derived visibility

    private var showLegend:    Bool { mapVM.hasLiveData && !mapVM.sheetIsExpanded }
    private var showFilterBar: Bool { !mapVM.sheetIsExpanded }

    // MARK: - Body

    var body: some View {
        // Entire HUD is suppressed in landscape — map canvas too short to spare vertical space.
        if verticalSizeClass != .compact {
            VStack(spacing: 12) {
                // Legend: conditional presence is handled internally by WaitTimeLegendView.
                WaitTimeLegendView(isVisible: legendVisible)

                // Filter bar + glance bar: conditional presence here triggers the declared transition.
                if filterBarVisible {
                    MapOverlayFilterBar(mapVM: mapVM)
                    ParkGlanceBar()
                }
            }
            // Account for tab bar (49pt) + home indicator / safe area + breathing room.
            .padding(.bottom, bottomInset + 49 + 16)
            // ── Lifecycle ──────────────────────────────────────────────────────────
            .onAppear {
                // Sync without animation on first render — avoids an entrance flash
                // if the map screen appears already in a non-collapsed sheet state.
                legendVisible    = showLegend
                filterBarVisible = showFilterBar
            }
            // ── Animation observers ────────────────────────────────────────────────
            // Asymmetric timing: spring on entrance (feels deliberate), easeIn on
            // exit (brisk — gets out of the way before the sheet expands fully).
            .onChange(of: showLegend) { _, newValue in
                withAnimation(
                    newValue
                        ? .spring(response: 0.38, dampingFraction: 0.82)
                        : .easeIn(duration: 0.22)
                ) {
                    legendVisible = newValue
                }
            }
            .onChange(of: showFilterBar) { _, newValue in
                withAnimation(
                    newValue
                        ? .spring(response: 0.38, dampingFraction: 0.82)
                        : .easeIn(duration: 0.22)
                ) {
                    filterBarVisible = newValue
                }
            }
        }
    }
}

// MARK: - Integration snippet (copy into your parent map screen)

/*
 ┌─────────────────────────────────────────────────────────────────┐
 │  Minimal integration — paste this into your map screen's body.  │
 │  Assumes MapViewModel is already in the environment.            │
 └─────────────────────────────────────────────────────────────────┘

 // Wrap your existing map canvas in a GeometryReader to get safeAreaInsets.
 // If you already have a GeometryReader wrapping the canvas, reuse its proxy.

 GeometryReader { geo in
     ParkMapCanvasView()
         .ignoresSafeArea()
         .overlay(alignment: .bottom) {
             MapHUDOverlay(bottomInset: geo.safeAreaInsets.bottom)
         }
 }

 // If you want the HUD to coexist with the peek sheet (28% height) rather than
 // hide on any sheet appearance, change MapViewModel.sheetIsExpanded to:
 //
 //     var sheetIsExpanded: Bool { sheetDetent == .full }
 //
 // and increase bottomInset at the call site to push the HUD above the sheet handle.
 */

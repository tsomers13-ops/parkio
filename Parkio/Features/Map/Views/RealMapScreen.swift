// RealMapScreen.swift — MapKit park map.
//
// Phase layout history:
//   Phase 2 — Follow mode / speed-gated heading / compass button / bearing polyline
//   Phase 3 — RideProximity / declutter() / WalkGuidanceCard
//   Phase 4 — NearbyRideTray / LandLabel / BestNextRideChip
//   Phase 5 — HUD overlay repositioned to bottom; VStack order corrected so controls
//              never float in the map center.
//   Phase 6 — Annotation pipeline moved to MapViewModel.buildVisibleAnnotations;
//              MyDayStore sync wired for planOnly filter; DEBUG pipeline overlay added.
//   Phase 7 — Park-scope audit: currentLatDelta seeded from MapViewModel.defaultSpan
//              on first appear and on park switch so the first pipeline run always
//              uses the correct zoom level.
//   Phase 8 — Selected-ride label override: selected ride always gets labelOpacity 1.0
//              regardless of p1LabelSafeIds collision result.
//
// ── currentLatDelta seeding ───────────────────────────────────────────────────
//
//   The annotation pipeline needs the current latitudeDelta to apply zoom-gating
//   and declutter correctly. The canonical value comes from .onMapCameraChange,
//   but that callback only fires when the camera moves — not on first render.
//
//   To ensure the first call to buildVisibleAnnotations uses the right delta:
//   1. .onAppear (GeometryReader) seeds currentLatDelta from
//      MapViewModel.defaultSpan(for: mapVM.parkId).
//   2. .onChange(of: mapVM.parkId) resets it immediately when the park changes,
//      before .onMapCameraChange has a chance to fire.
//
// ── HUD layout (bottom to top on screen) ──────────────────────────────────────
//   Tab bar       — system, untouched
//   WaitTimeLegend— smallest, lowest emphasis
//   FilterChipBar — medium weight
//   ParkGlanceBar — summary card, strongest elevation

import SwiftUI
import MapKit

// MARK: - RealMapScreen

struct RealMapScreen: View {

    @Environment(MapViewModel.self)             private var mapVM
    @Environment(LocationService.self)          private var locationService
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(MyDayStore.self)               private var myDayStore
    @Environment(\.verticalSizeClass)           private var verticalSizeClass

    @State private var currentLatDelta:      CLLocationDegrees = 0.015
    @State private var currentViewportWidth: CGFloat           = 390

    // ── HUD animation gates ────────────────────────────────────────────────────
    @State private var legendVisible:    Bool = false
    @State private var filterBarVisible: Bool = false

    // ── Map readiness gate ────────────────────────────────────────────────────
    // Set to true when the GeometryReader / ZStack layer fires onAppear, meaning
    // the MapKit Map view is in the hierarchy and ready to accept camera changes.
    // Reset to false in onDisappear so the gate re-arms whenever the user
    // leaves and returns to the Map tab.
    @State private var isMapReady: Bool = false

#if DEBUG
    @State private var showDebugPanel: Bool = false
#endif

    // MARK: - HUD visibility

    private var showLegend:    Bool { mapVM.hasLiveData && !mapVM.sheetDetent.isExpanded }
    private var showFilterBar: Bool { !mapVM.sheetDetent.isExpanded }

    // MARK: - Annotation pipeline

    /// Final rendered annotation list — produced by the five-stage pipeline in
    /// MapViewModel. All stages (park filter, coord check, zoom gate, filter
    /// state, declutter) run inside buildVisibleAnnotations.
    private var visibleRideAnnotations: [RideAnnotation] {
        mapVM.buildVisibleAnnotations(
            latDelta:      currentLatDelta,
            viewportWidth: currentViewportWidth
        )
    }

    /// Resolved label opacity for a given annotation.
    ///
    /// Priority order:
    ///   1. Selected ride → always 1.0 (user explicitly tapped it; label must show)
    ///   2. P1 + in collision-safe set → 1.0
    ///   3. Everything else → 0.0
    ///
    /// `safeIds` must be the pre-computed set from `body` — do not call
    /// `mapVM.p1LabelSafeIds(...)` here to avoid re-running the pipeline.
    private func labelOpacity(for annotation: RideAnnotation, safeIds: Set<String>) -> CGFloat {
        if mapVM.selectedRideId == annotation.id { return 1 }
        return annotation.priority == 1 && safeIds.contains(annotation.id) ? 1 : 0
    }

    // MARK: - Body

    var body: some View {
        @Bindable var vm = mapVM

        // Compute the annotation pipeline exactly once per render pass.
        // Both visibleRideAnnotations (which mutates stableOutputCache) and
        // p1LabelSafeIds (pure, but reads visible) must not be called more than
        // once per frame — calling them N times in a ForEach or multiple @ViewBuilders
        // would re-run the full 5-stage declutter pipeline on every annotation.
        let visible = visibleRideAnnotations
        let safeIds = mapVM.p1LabelSafeIds(
            among:         visible,
            latDelta:      currentLatDelta,
            viewportWidth: currentViewportWidth
        )

        GeometryReader { geo in
            ZStack {
                // ── 1. MapKit base ───────────────────────────────────────────────
                mapLayer(vm: vm, visible: visible, safeIds: safeIds)
                    .ignoresSafeArea(edges: .all)

                // ── 2. Nearby ride tray (when no ride selected) ─────────────────
                nearbyTrayLayer(geo: geo)

                // ── 3. Walk guidance card (when ride selected + within 400 m) ────
                walkGuidanceLayer(geo: geo)

                // ── 4. Land label (top-center, when zoomed) ──────────────────────
                landLabelLayer(geo: geo, visible: visible)

                // ── 5. Top-right map controls (best-next ride + location) ─────────
                topRightMapControlsLayer(geo: geo)

                // ── 6. Corner controls (compass + distance + location) ────────────
                controlsOverlay
            }
            // ── 7. HUD — floats above tab bar via overlay(alignment: .bottom) ────
            //
            // Placed as an overlay on the ZStack (not inside it) so it anchors to
            // the ZStack's rendered bounds rather than competing with the
            // map layer's .ignoresSafeArea expansion.
            //
            // padding(.bottom, geo.safeAreaInsets.bottom + 80):
            //   geo.safeAreaInsets.bottom  — home-indicator clearance (~34 pt Face ID,
            //                                0 pt Home-button devices)
            //   + 80 pt                    — clears tab bar (49 pt) + visual gap
            //                                without hardcoding the bar height directly.
            .overlay(alignment: .bottom) {
                hudLayer(geo: geo)
            }
            .onAppear {
                currentViewportWidth = geo.size.width
                // Seed latDelta from the park default so the first pipeline run uses
                // the correct zoom level. Without this, currentLatDelta stays at 0.015
                // until .onMapCameraChange fires — which may not happen on first render.
                currentLatDelta  = MapViewModel.defaultSpan(for: mapVM.parkId)
                legendVisible    = showLegend
                filterBarVisible = showFilterBar
                // Mark the map as ready. This is the earliest point at which the
                // MapKit Map view is in the layout tree and can safely accept
                // programmatic camera changes and ride selection.
                isMapReady = true
            }
            .onChange(of: geo.size.width) { _, w in currentViewportWidth = w }
            .onChange(of: showLegend) { _, newValue in
                withAnimation(
                    newValue
                        ? .spring(response: 0.38, dampingFraction: 0.82)
                        : .easeIn(duration: 0.22)
                ) { legendVisible = newValue }
            }
            .onChange(of: showFilterBar) { _, newValue in
                withAnimation(
                    newValue
                        ? .spring(response: 0.38, dampingFraction: 0.82)
                        : .easeIn(duration: 0.22)
                ) { filterBarVisible = newValue }
            }
        }
        .onAppear {
            if locationService.isAuthorized { locationService.startUpdating() }
            mapVM.locationService = locationService
            syncPlannedRides()
            handlePendingRideIfNeeded()
#if DEBUG
            mapVM.logPipeline(latDelta: currentLatDelta, viewportWidth: currentViewportWidth)
#endif
        }
        .onDisappear {
            locationService.stopUpdating()
            // Re-arm the readiness gate so that if the user returns to the Map tab
            // with a pending ride, the gate fires onChange again rather than
            // silently staying true and never triggering a retry.
            isMapReady = false
        }
        .onChange(of: myDayStore.items) { _, _ in
            syncPlannedRides()
        }
        .onChange(of: coordinator.pendingMapRideId) { _, rideId in
            guard rideId != nil else { return }
            handlePendingRideIfNeeded()
        }
        // Retry when the map becomes ready (inner onAppear has fired and the MapKit
        // Map view is in the hierarchy). This is the primary trigger for the
        // Home → Show on Map path: pendingMapRideId is set before the tab switch,
        // so onChange(pendingMapRideId) fires before the map is ready; this
        // onChange fires once isMapReady flips true and retries the selection.
        .onChange(of: isMapReady) { _, ready in
            guard ready else { return }
            handlePendingRideIfNeeded()
        }
        // Retry when the annotation list is (re)populated — covers the case where
        // MapTabView lazily creates MapViewModel after isMapReady is already true,
        // so annotations arrive after both the map-ready and pendingMapRideId
        // triggers have already fired without finding the annotation.
        .onChange(of: mapVM.annotations.count) { _, count in
            guard count > 0 else { return }
            handlePendingRideIfNeeded()
        }
        .onChange(of: mapVM.parkId) { _, newParkId in
            // Reset latDelta immediately so the pipeline uses the new park's default
            // span before .onMapCameraChange gets a chance to fire.
            currentLatDelta = MapViewModel.defaultSpan(for: newParkId)
            mapVM.setFollowMode(.none)
            mapVM.framePark()
        }
        .onChange(of: locationService.userLocation?.coordinate.latitude) { _, _ in
            if let loc = locationService.userLocation {
                mapVM.updateCameraForLocation(loc)
            }
        }
#if DEBUG
        .onChange(of: currentLatDelta) { _, _ in
            mapVM.logPipeline(latDelta: currentLatDelta, viewportWidth: currentViewportWidth)
        }
#endif
    }

    // MARK: - My Day sync

    private func syncPlannedRides() {
        let ids = Set(myDayStore.items.compactMap(\.rideId))
        mapVM.updatePlannedRideIds(ids)
    }

    // MARK: - Map navigation handoff (from Home / My Day "Show on Map")
    //
    // Called from three sites:
    //   • onAppear          — covers tab re-activation and first appearance
    //   • onChange(pendingMapRideId) — covers the common case where the map is
    //                          already visible and only the ride changes
    //   • onChange(annotations.count) — covers the race where MapTabView lazily
    //                          creates MapViewModel *after* pendingMapRideId is set,
    //                          so annotations arrive one render cycle too late for
    //                          the first two triggers to succeed
    //
    // ── Why pendingMapRideId is NOT cleared at the top ────────────────────────
    //
    //   The original code cleared pendingMapRideId unconditionally on entry, then
    //   searched for the annotation.  If annotations were empty (lazy init race)
    //   centerOn never ran, the ID was gone, and no retry was possible — causing
    //   the "first tap does nothing, second tap works" bug.
    //
    //   Fix: the ID is only consumed *after* the annotation is confirmed present.
    //   Every retry site that calls this function checks the guard at the top; if
    //   the annotation still isn't ready it simply returns and waits for the next
    //   trigger.  Once it succeeds the ID is cleared so no second selection fires.

    private func handlePendingRideIfNeeded() {
        // ── Gate 1: nothing pending ───────────────────────────────────────────
        guard let rideId = coordinator.pendingMapRideId else { return }

#if DEBUG
        print("🗺 [pending] received rideId=\(rideId)  isMapReady=\(isMapReady)  annotations=\(mapVM.annotations.count)")
#endif

        // ── Gate 2: map not ready yet ─────────────────────────────────────────
        // The inner onAppear (ZStack/GeometryReader layer) has not fired yet —
        // the MapKit Map view is not in the layout tree. Leave the pending ID in
        // place; onChange(isMapReady) will retry once the map layer appears.
        guard isMapReady else {
#if DEBUG
            print("🗺 [pending] map not ready — will retry when isMapReady fires")
#endif
            return
        }

        // ── Gate 3: annotation not loaded yet ────────────────────────────────
        // MapViewModel.loadAnnotations() hasn't completed or the park ID hasn't
        // matched yet. Leave the pending ID in place; onChange(annotations.count)
        // will retry when annotations arrive.
        guard let ann = mapVM.annotations.first(where: { $0.id == rideId }) else {
#if DEBUG
            print("🗺 [pending] annotation not found — will retry when annotations load")
#endif
            return
        }

        // All three gates passed — consume the pending ID exactly once.
        coordinator.pendingMapRideId = nil

#if DEBUG
        print("🗺 [pending] annotation found: \(ann.rideName) — selecting + centering")
#endif

        mapVM.selectRide(rideId)
        mapVM.centerOn(annotation: ann)

        // selectRide already sets sheetDetent = .peek when id != nil; this guard
        // handles the unlikely case where it arrives collapsed for any other reason.
        if mapVM.sheetDetent == .collapsed {
            withAnimation(AppMotion.standard) {
                mapVM.setSheetDetent(.peek)
            }
        }

#if DEBUG
        print("🗺 [pending] selection succeeded, pendingMapRideId cleared")
#endif
    }

    // MARK: - Map layer

    @ViewBuilder
    private func mapLayer(vm: MapViewModel, visible: [RideAnnotation], safeIds: Set<String>) -> some View {
        @Bindable var vm = vm

        MapReader { proxy in
            Map(position: $vm.cameraPosition) {
                UserAnnotation()

                if let userCoord = locationService.userLocation?.coordinate,
                   let rideCoord = mapVM.selectedRideCoordinate {
                    let color = mapVM.selectedRideProximity?.polylineColor
                        ?? Color.accentColor.opacity(0.45)
                    MapPolyline(coordinates: [userCoord, rideCoord])
                        .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                }

                ForEach(visible) { annotation in
                    Annotation(
                        annotation.name,
                        coordinate: annotation.coordinate,
                        anchor: .bottom
                    ) {
                        RideAnnotationView(
                            annotation:   annotation,
                            enriched:     mapVM.enrichedMarker(for: annotation.id),
                            isSelected:   mapVM.selectedRideId == annotation.id,
                            labelOpacity: labelOpacity(for: annotation, safeIds: safeIds)
                        ) {
                            mapVM.selectRide(annotation.id)
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture(coordinateSpace: .local) { point in
                guard isEmptyMapTap(point, proxy: proxy, visible: visible) else { return }
                mapVM.dismiss()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                currentLatDelta = context.region.span.latitudeDelta
                mapVM.updateLastKnownRegion(context.region)
                if mapVM.followMode == .none {
                    let parkSpan = MapViewModel.defaultSpan(for: mapVM.parkId)
                    if abs(currentLatDelta - parkSpan) > 0.002 { mapVM.isZoomed = true }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { _ in
                    if mapVM.followMode != .none { mapVM.handleUserPanned() }
                }
            )
            .simultaneousGesture(
                MagnifyGesture().onChanged { _ in
                    if mapVM.followMode != .none { mapVM.handleUserPanned() }
                }
            )
        }
    }

    private func isEmptyMapTap(_ point: CGPoint, proxy: MapProxy, visible: [RideAnnotation]) -> Bool {
        guard let coordinate = proxy.convert(point, from: .local) else { return true }

        let degreesPerPoint = currentLatDelta / max(Double(currentViewportWidth), 1)
        let tapRadius = degreesPerPoint * 44

        return !visible.contains { annotation in
            abs(annotation.coordinate.latitude - coordinate.latitude) < tapRadius
                && abs(annotation.coordinate.longitude - coordinate.longitude) < tapRadius
        }
    }

    // MARK: - HUD layer (filter bar + legend, bottom-floating)
    //
    // Returned as the content of .overlay(alignment: .bottom) on the map ZStack.
    // .overlay handles bottom-anchoring, so no frame(maxHeight: .infinity) trick
    // is needed here — the VStack naturally sizes to its content.
    //
    // Bottom padding formula:
    //   geo.safeAreaInsets.bottom — home-indicator clearance (34 pt on Face ID,
    //                               0 pt on Home-button iPhones)
    //   + 80 pt                   — comfortably clears the 49-pt tab bar and
    //                               provides ~30 pt of visual breathing room above it.
    //
    // Landscape (verticalSizeClass == .compact) is suppressed — the horizontal
    // constraint on an iPhone in landscape leaves no room for these controls.

    @ViewBuilder
    private func hudLayer(geo: GeometryProxy) -> some View {
        if verticalSizeClass != .compact {
            VStack(spacing: 12) {
                if filterBarVisible {
                    MapOverlayFilterBar(mapVM: mapVM)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                WaitTimeLegendView(isVisible: legendVisible)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, geo.safeAreaInsets.bottom + 100)
        }
    }

    // MARK: - Nearby ride tray

    @ViewBuilder
    private func nearbyTrayLayer(geo: GeometryProxy) -> some View {
        let rides = mapVM.nearbyRides()

        if mapVM.selectedRideId == nil,
           !mapVM.sheetDetent.isExpanded,
           !rides.isEmpty {

            let containerH = geo.size.height + geo.safeAreaInsets.bottom
            let sheetH     = mapVM.sheetDetent.height(for: containerH)
            let bottomPad  = geo.safeAreaInsets.bottom + 49 + sheetH + 8

            VStack {
                Spacer()
                NearbyRideTray(rides: rides) { ride in
                    mapVM.selectRide(ride.id)
                    mapVM.centerOn(coordinate: ride.annotation.coordinate)
                }
                .padding(.bottom, bottomPad)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Walk guidance card

    @ViewBuilder
    private func walkGuidanceLayer(geo: GeometryProxy) -> some View {
        if let proximity = mapVM.selectedRideProximity,
           proximity != .far,
           !mapVM.sheetDetent.isExpanded,
           let marker = mapVM.selectedEnrichedMarker,
           let dist   = mapVM.distanceToSelectedRide {

            let containerH = geo.size.height + geo.safeAreaInsets.bottom
            let sheetH     = mapVM.sheetDetent.height(for: containerH)
            let bottomPad  = geo.safeAreaInsets.bottom + 49 + sheetH + 8

            VStack {
                Spacer()
                WalkGuidanceCard(
                    rideName:  marker.annotation.rideName,
                    distance:  dist,
                    proximity: proximity
                )
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, bottomPad)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Land label

    @ViewBuilder
    private func landLabelLayer(geo: GeometryProxy, visible: [RideAnnotation]) -> some View {
        if mapVM.isZoomed,
           let land = mapVM.dominantLand(among: visible) {
            VStack {
                HStack {
                    Spacer()
                    Text(land)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
                        .contentTransition(.opacity)
                        .animation(AppMotion.standard, value: land)
                    Spacer()
                }
                .padding(.top, geo.safeAreaInsets.top + 8)
                Spacer()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        }
    }

    // MARK: - Top-right map controls

    @ViewBuilder
    private func topRightMapControlsLayer(geo: GeometryProxy) -> some View {
        if !mapVM.sheetDetent.isExpanded {
            VStack {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Spacer()

                    if mapVM.selectedRideId == nil,
                       let rec = mapVM.bestNextRide {
                        BestNextRideChip(recommendation: rec) {
                            mapVM.selectRide(rec.rideId)
                            mapVM.centerOn(coordinate:
                                mapVM.annotations
                                    .first(where: { $0.id == rec.rideId })
                                    .map { CLLocationCoordinate2D(latitude: $0.latitude,
                                                                  longitude: $0.longitude) }
                                ?? CLLocationCoordinate2D()
                            )
                        }
                    }

                    mapControlsColumn
                }
                .padding(.trailing, AppSpacing.screenEdge)
                // geo.safeAreaInsets.top clears the status bar + navigation bar so the
                // controls land in the first visible row of the map canvas, not behind it.
                .padding(.top, geo.safeAreaInsets.top + 8)
                Spacer()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
        }
    }

    /// Right-edge overlay column for controls that must live on the map canvas.
    ///
    /// "Map Reset" has moved to the navigation bar toolbar (see the
    /// `.toolbar` modifier in `body`) so it sits at the very top of the screen
    /// without floating over map content. Only the location-recenter button
    /// remains here — it needs to be on the canvas so it stays visually
    /// associated with the map, not the navigation chrome.
    @ViewBuilder
    private var mapControlsColumn: some View {
        if locationService.isAuthorized {
            RecenterMapButton { mapVM.setFollowMode(.follow) }
        }
    }

    // MARK: - Corner controls

    private var controlsOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    if mapVM.followMode == .followHeading {
                        CompassResetButton(
                            heading: locationService.heading?.trueHeading ?? 0
                        ) {
                            mapVM.setFollowMode(.follow)
                        }
                        .transition(.scale(scale: 0.75).combined(with: .opacity))
                    }

                    DistanceChipIfNeeded()
                        .environment(mapVM)
                        .environment(locationService)
                        .animation(AppMotion.standard, value: mapVM.selectedRideId)

                    LocationButton()
                        .environment(locationService)
                        .environment(mapVM)
                }
                .padding(.trailing, AppSpacing.screenEdge)
            }
            .padding(.bottom, AppSpacing.md)
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(AppMotion.spring, value: mapVM.followMode)
    }
}

// MARK: - DEBUG: Pipeline overlay

#if DEBUG
extension RealMapScreen {

    // ── Entry point ───────────────────────────────────────────────────────────
    //
    // Receives the same pre-computed `visible` and `safeIds` captured once in
    // `body`. The pipeline does NOT run again here — only pipelineSnapshot()
    // inside debugPill runs an independent pass (acceptable in DEBUG only).
    //
    // Metrics shown (all 8 requested):
    //   1  Selected park          — snap.parkId
    //   2  Total ride count       — snap.parkTotal  (static annotation DB)
    //      Live total             — mapVM.totalAttractionsCount (all API attractions)
    //   3  Open count (API)       — snap.openAttractionsCount  (all API attractions, park-scoped)
    //   4  Rides with coordinates — snap.afterCoordCheck
    //   5  Rides after filters    — snap.afterFilters
    //   6  Rides after declutter  — snap.afterDeclutter  (fresh pipeline run)
    //   7  Final visible pin count— visible.count  (stable-cache output, actual ForEach)
    //   8  P1 labels              — safeIds.count / visible.filter{priority==1}.count

    @ViewBuilder
    func debugOverlayLayer(geo: GeometryProxy, visible: [RideAnnotation], safeIds: Set<String>) -> some View {
        VStack {
            HStack {
                debugPill(visible: visible, safeIds: safeIds)
                    .padding(.leading, AppSpacing.screenEdge)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Pill

    private func debugPill(visible: [RideAnnotation], safeIds: Set<String>) -> some View {
        // pipelineSnapshot runs an independent pipeline pass — DEBUG only, acceptable.
        let snap = mapVM.pipelineSnapshot(
            latDelta:      currentLatDelta,
            viewportWidth: currentViewportWidth
        )

        return Button {
            withAnimation(AppMotion.quick) { showDebugPanel.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: snap.wrongParkCount > 0
                      ? "exclamationmark.triangle.fill"
                      : "ladybug.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                // visible.count — actual stable-cache output rendered in ForEach
                Text("\(visible.count)/\(snap.parkTotal)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                if snap.wrongParkCount > 0 {
                    Text("⚠︎\(snap.wrongParkCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                snap.wrongParkCount > 0
                    ? Color.red.opacity(0.85)
                    : visible.count == snap.parkTotal
                        ? Color.green.opacity(0.85)
                        : Color.orange.opacity(0.85),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if showDebugPanel {
                debugPanel(snap: snap, visible: visible, safeIds: safeIds)
                    .offset(x: 0, y: 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }
        }
    }

    // MARK: - Panel

    private func debugPanel(snap: AnnotationPipelineSnapshot,
                            visible: [RideAnnotation],
                            safeIds: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {

            // ── 1. Selected park ───────────────────────────────────────────────
            Text("🗺  \(snap.parkId)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)

            Divider()

            // ── 2 & 3. Ride counts ─────────────────────────────────────────────
            //    "Park total"    — static coordinate DB count for this park.
            //    "Live total"    — rides returned by the wait-time API (may differ
            //                     before first fetch or when API omits rides).
            //    "Open"          — rideable rides from live data (park-scoped).
            dbRow("Park total",  snap.parkTotal,          snap.parkTotal)
            if snap.wrongParkCount > 0 {
                dbRow("⚠︎ Wrong park", snap.wrongParkCount, snap.parkTotal, tint: .red)
            }
            dbRow("Live total",  mapVM.totalAttractionsCount, snap.parkTotal)
            dbRow("Open (API)", snap.openAttractionsCount,   mapVM.totalAttractionsCount)

            Divider()

            // ── 4–6. Pipeline stages ───────────────────────────────────────────
            //    "Coord valid"    — after (0,0) / out-of-range strip   (metric 4)
            //    "After filters"  — showRidden / hideClosed / planOnly  (metric 5)
            //    "After declutter"— fresh independent pipeline run      (metric 6)
            dbRow("Coord valid",     snap.afterCoordCheck, snap.parkTotal)
            dbRow("After filters",   snap.afterFilters,    snap.parkTotal)
            dbRow("After declutter", snap.afterDeclutter,  snap.parkTotal)

            // ── 7. Final visible pin count ─────────────────────────────────────
            //    actual ForEach count from body's stable-cache output.
            //    May transiently differ from "After declutter" when the stable
            //    output cache holds a prior accepted set across a filter change.
            HStack {
                Text("Visible pins ★")
                    .font(.system(size: 10).weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(visible.count)")
                    .font(.system(size: 10).weight(.bold).monospacedDigit())
                    .foregroundStyle(visible.count == snap.parkTotal
                                     ? AppColor.success
                                     : AppColor.textPrimary)
            }

            // ── 8. P1 label counts ─────────────────────────────────────────────
            p1LabelDebugRow(visible: visible, safeIds: safeIds)

            // ── Suppressed ride lists (non-empty only) ─────────────────────────
            if !snap.suppressedByWrongPark.isEmpty
                || !snap.suppressedByZoom.isEmpty
                || !snap.suppressedByFilter.isEmpty
                || !snap.suppressedByDeclutter.isEmpty {

                Divider()
                if !snap.suppressedByWrongPark.isEmpty {
                    suppressedNames("⚠︎ Wrong park", snap.suppressedByWrongPark, .red)
                }
                if !snap.suppressedByZoom.isEmpty {
                    suppressedNames("Zoom", snap.suppressedByZoom, .blue)
                }
                if !snap.suppressedByFilter.isEmpty {
                    suppressedNames("Filter", snap.suppressedByFilter, .orange)
                }
                if !snap.suppressedByDeclutter.isEmpty {
                    suppressedNames("Declutter", snap.suppressedByDeclutter, .purple)
                }
            }

            Divider()

            // ── Camera + filter state ──────────────────────────────────────────
            Text("latΔ \(String(format: "%.4f", currentLatDelta))  W:\(Int(currentViewportWidth))pt")
                .font(.system(size: 9).monospaced())
                .foregroundStyle(AppColor.textTertiary)

            Text("ridden:\(mapVM.filters.showRidden ? "✓" : "✗")  closed:\(mapVM.filters.hideClosed ? "hide" : "show")  planOnly:\(mapVM.filters.planOnly ? "✓" : "✗")")
                .font(.system(size: 9).monospaced())
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(10)
        .frame(width: 236)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
    }

    // MARK: - Row helpers

    /// Standard two-column metric row.
    /// `tint` overrides the default success/secondary color logic when set.
    @ViewBuilder
    private func dbRow(
        _ label: String,
        _ count: Int,
        _ total: Int,
        tint: Color? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(
                    tint ?? (count == total ? AppColor.success : AppColor.textSecondary)
                )
        }
    }

    /// P1 label summary: safe-label count / total visible P1 count + zoom-gate label.
    @ViewBuilder
    private func p1LabelDebugRow(visible: [RideAnnotation], safeIds: Set<String>) -> some View {
        let safeCount = safeIds.count
        let totalP1   = visible.filter { $0.priority == 1 }.count
        let gate      = currentLatDelta > 0.018 ? "wide"
                      : currentLatDelta < 0.006 ? "tight"
                      : "sweep"
        HStack {
            Text("P1 labels")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text("\(safeCount) / \(totalP1)  (\(gate))")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(safeCount == totalP1 ? AppColor.success : AppColor.textPrimary)
        }
    }

    /// Suppressed ride name list (compact, max 3 lines).
    @ViewBuilder
    private func suppressedNames(_ label: String, _ names: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(label) (\(names.count)):")
                .font(.system(size: 9).weight(.semibold))
                .foregroundStyle(color)
            Text(names.joined(separator: ", "))
                .font(.system(size: 9))
                .foregroundStyle(AppColor.textTertiary)
                .lineLimit(3)
        }
    }
}
#endif

// MARK: - Recenter map button

/// Icon-only floating button that re-centers the map on the user's live position
/// by engaging follow mode. Sits in the top-right overlay column on the map
/// canvas.
///
/// ── Rationale ────────────────────────────────────────────────────────────────
///
///   Users reliably read a circle + arrow icon as "go to my location", which
///   was the source of confusion with the old reset button. Giving them a real
///   location-recenter button where they expect one makes the UI match their
///   mental model instead of fighting it.
///
///   `mapVM.setFollowMode(.follow)` pans the camera to the user's coordinate
///   and enables continuous tracking. A subsequent user pan cancels follow mode
///   (handled by `handleUserPanned()` in the map gesture layer) — no extra
///   logic needed here.
///
/// ── Visibility ───────────────────────────────────────────────────────────────
///
///   Rendered only when `locationService.isAuthorized` (checked at the call
///   site in `mapControlsColumn`). Never shown as a permanently disabled ghost.
///
/// ── Style ────────────────────────────────────────────────────────────────────
///
///   44 × 44 pt circle, `.regularMaterial`, hairline border, same shadow token
///   as `CompassResetButton` so all circular controls share one visual language.
private struct RecenterMapButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Center on My Location")
        .accessibilityHint("Switches the map to follow your current position")
    }
}

// MARK: - Best-next-ride chip

private struct BestNextRideChip: View {
    let recommendation: RideRecommendation
    let action: () -> Void

    private var waitLabel: String {
        guard let mins = recommendation.waitMinutes else { return "Open" }
        return mins == 0 ? "Walk on" : "\(mins) min"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.caption2.weight(.bold))
                Text(recommendation.rideName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("·")
                    .font(.caption)
                Text(waitLabel)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: Color.accentColor.opacity(0.30), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Suggested: \(recommendation.rideName), \(waitLabel)")
    }
}

// MARK: - Compass reset button

private struct CompassResetButton: View {
    let heading: Double
    let action:  () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.north.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .rotationEffect(.degrees(-heading))
                .padding(10)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(AppMotion.standard, value: heading)
        .accessibilityLabel("Reset to north-up")
    }
}

// MARK: - Per-annotation marker view

private struct RideAnnotationView: View {
    let annotation:   RideAnnotation
    let enriched:     EnrichedMarkerWithSelection?
    let isSelected:   Bool
    /// Label opacity for the ambient marker's name label: 1.0 = visible,
    /// 0.0 = hidden (no layout space consumed). Resolved by
    /// RealMapScreen.labelOpacity(for:) — always 1.0 for the selected ride,
    /// otherwise gated by p1LabelSafeIds collision result.
    let labelOpacity: CGFloat
    let onTap:        () -> Void

    var body: some View {
        Group {
            if let enriched {
                if isSelected {
                    SelectedRideMarkerView(marker: enriched.base)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .bottom).combined(with: .opacity),
                            removal:   .scale(scale: 0.70, anchor: .bottom).combined(with: .opacity)
                        ))
                } else if annotation.priority == 3 {
                    MinimalPinView(color: enriched.base.markerColor, isPlanned: enriched.base.isPlanned)
                        .transition(.scale(scale: 0.60, anchor: .bottom).combined(with: .opacity))
                } else {
                    RideMarkerView(marker: enriched.base, labelOpacity: labelOpacity)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.60, anchor: .bottom).combined(with: .opacity),
                            removal:   .scale(scale: 0.80, anchor: .bottom).combined(with: .opacity)
                        ))
                }
            } else {
                StaticRealMapPin(isSelected: isSelected)
            }
        }
        .onTapGesture { onTap() }
        .animation(isSelected ? AppMotion.spring : AppMotion.standard, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(enriched?.base.accessibilityLabel ?? annotation.name)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }
}

private struct StaticRealMapPin: View {
    let isSelected: Bool
    var body: some View {
        Circle()
            .fill(AppColor.textTertiary.opacity(0.8))
            .frame(width: isSelected ? 30 : 14, height: isSelected ? 30 : 14)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftData

#Preview("RealMapScreen") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM = WaitTimeViewModel(container: container)
    let mapVM  = MapViewModel(parkId: "magic-kingdom", waitTimeVM: waitVM)
    let locSvc = LocationService()
    return RealMapScreen()
        .environment(mapVM)
        .environment(waitVM)
        .environment(locSvc)
        .environment(AppNavigationCoordinator())
        .environment(MyDayStore())
        .modelContainer(container)
}
#endif

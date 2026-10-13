// MapTabView.swift — Root coordinator for the Maps tab.
//
// Ownership:
//   MapTabView creates and owns MapViewModel.
//   Lazily initialized on first appear so it can read @Environment(WaitTimeViewModel)
//   at creation time.
//
// Map layer:
//   Two renderers, both sharing the same MapViewModel so ride selection and
//   the bottom sheet (RideMapBottomSheetView) behave identically either way:
//     • ParkMapCanvasView — the Explore Map: an original illustrated map as
//       an interactive pan/zoom canvas (see ParkCompositions.swift / docs/
//       *-MAP-PROVENANCE.md for each park's artwork provenance).
//     • RealMapScreen — the Live Map: the full MapKit tile surface, user
//       location puck, ride annotations, follow mode, bearing polyline, HUD
//       (filter bar + glance bar), and the location / compass buttons.
//   MapModeAvailability.isExploreMapAvailable(forParkId:) decides whether a
//   park offers the Explore/Live toggle at all (MapContentView.topChrome) —
//   a park with no calibrated Explore Map yet stays on the Live Map with no
//   toggle shown, a safe fallback. MapContentView.mapMode (local @State,
//   reset to that park's default whenever selectedPark changes) picks which
//   one actually renders. MapRoutingDecision still exists and is still
//   tested, but is no longer consulted here — see its header comment.
//
// Park switching (single source of truth):
//   switchPark(to:) updates mapVM.parkId and parkMapVM.parkId. MapViewModel's
//   didSet handles annotation reload and camera reset; ParkMapViewModel's
//   didSet reloads its pin set. Called from the single .onChange(of: selectedPark).
//
// ZStack layer order in MapContentView:
//   1. mapSurface   (ParkMapCanvasView or RealMapScreen, per MapRoutingDecision)
//   2. Top overlay  (park selector pill strip, wait-time banner)
//   3. RideMapBottomSheetView (always on top)

import SwiftUI
import SwiftData

// MARK: - MapTabView

struct MapTabView: View {
    @Binding var selectedPark: Park

    @Environment(WaitTimeViewModel.self) private var waitTimeVM

    // Lazily initialized so waitTimeVM is available at creation time.
    @State private var mapVM: MapViewModel?
    // Backs the Magic Kingdom custom canvas. Created alongside mapVM even
    // though only Magic Kingdom renders it — cheap, and keeps park-switch
    // sync in one place instead of lazily standing it up mid-switch.
    @State private var parkMapVM: ParkMapViewModel?
    @State private var calibrationVM = CalibrationViewModel()

    // SwiftData source of truth for ridden/logged state.
    @Query private var allRides: [Ride]

    var body: some View {
        Group {
            if let mapVM, let parkMapVM {
                MapContentView(
                    mapVM:        mapVM,
                    parkMapVM:    parkMapVM,
                    selectedPark: $selectedPark
                )
                .environment(calibrationVM)
                .onChange(of: selectedPark) { _, newPark in
                    switchPark(to: newPark, mapVM: mapVM, parkMapVM: parkMapVM)
                }
                .onChange(of: allRides) { _, rides in
                    mapVM.updateRiddenState(rides: rides)
                }
            } else {
                AppColor.background.ignoresSafeArea()
            }
        }
        .onAppear {
            guard mapVM == nil else {
                mapVM?.onAppear()
                return
            }
            let mVM = MapViewModel(parkId: selectedPark.backendId, waitTimeVM: waitTimeVM)
            let pmVM = ParkMapViewModel(parkId: selectedPark.backendId)
            mapVM = mVM
            parkMapVM = pmVM
            mVM.onAppear()
            mVM.updateRiddenState(rides: allRides)
        }
    }

    // MARK: - Park switch

    private func switchPark(to park: Park, mapVM: MapViewModel, parkMapVM: ParkMapViewModel) {
        // MapViewModel.parkId didSet calls loadAnnotations() + resetCamera() automatically.
        mapVM.parkId = park.backendId
        // ParkMapViewModel.parkId didSet calls loadPins() automatically.
        parkMapVM.parkId = park.backendId
    }
}

// MARK: - MapContentView

/// Full map experience: map surface (routed per park) + park selector + bottom sheet.
private struct MapContentView: View {
    let mapVM:        MapViewModel
    let parkMapVM:    ParkMapViewModel
    @Binding var selectedPark: Park

    /// Which surface is on screen for the current park. Seeded to that park's
    /// default (Explore if available, else Live) at creation, and reset to
    /// the new park's default by .onChange(of: selectedPark) below — switching
    /// parks always lands somewhere safe even if the guest had manually
    /// toggled to Live for a park that does have an Explore Map.
    @State private var mapMode: MapRenderMode

    @Environment(WaitTimeViewModel.self) private var waitTimeVM

    init(mapVM: MapViewModel, parkMapVM: ParkMapViewModel, selectedPark: Binding<Park>) {
        self.mapVM = mapVM
        self.parkMapVM = parkMapVM
        self._selectedPark = selectedPark
        _mapMode = State(initialValue: Self.defaultMode(forParkId: selectedPark.wrappedValue.backendId))
    }

    private static func defaultMode(forParkId parkId: String) -> MapRenderMode {
        MapModeAvailability.isExploreMapAvailable(forParkId: parkId) ? .customCanvas : .liveMap
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Layer 1: map surface (routed per park) ────────────────────────
                mapSurface

                // ── Layer 2: top chrome ──────────────────────────────────────────
                // Park selector strip + transient wait-time banner.
                // Floats above the map; does not overlap the HUD (which is bottom-anchored).
                topChrome

                // ── Layer 3: bottom sheet ────────────────────────────────────────
                RideMapBottomSheetView()
                    .environment(mapVM)
                    .environment(waitTimeVM)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mapToolbar }
            .refreshable { await waitTimeVM.refresh() }
            .onChange(of: selectedPark) { _, newPark in
                mapMode = Self.defaultMode(forParkId: newPark.backendId)
            }
        }
    }

    // MARK: Map surface

    /// Explore Map (original illustrated canvas) or Live Map (MapKit),
    /// per the current mapMode. Both share `mapVM`, so ride selection and the
    /// bottom sheet behave identically regardless of which surface is on screen.
    @ViewBuilder
    private var mapSurface: some View {
        switch mapMode {
        case .customCanvas:
            ParkMapCanvasView()
                .environment(mapVM)
                .environment(parkMapVM)
                .ignoresSafeArea(edges: .bottom)
        case .liveMap:
            // RealMapScreen owns: Apple tile base, UserAnnotation (GPS puck),
            // ride annotations with real coordinates, bearing polyline,
            // MapHUDOverlay (filter bar + glance bar), location / compass buttons.
            // LocationService is already in the environment from ParkioApp.
            RealMapScreen()
                .environment(mapVM)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Top chrome

    private var topChrome: some View {
        VStack(spacing: 0) {
            MapParkSelectorStrip(selectedPark: $selectedPark)
            if MapModeAvailability.isExploreMapAvailable(forParkId: selectedPark.backendId) {
                HStack {
                    Spacer()
                    MapModeToggle(mode: $mapMode)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xs)
            }
            MapWaitTimeBanner(waitTimeVM: waitTimeVM, park: selectedPark)
            Spacer(minLength: 0)
        }
    }

    // MARK: Navigation toolbar

    @ToolbarContentBuilder
    private var mapToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ShowFullParkButton { mapVM.resetCamera() }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            waitTimeStatusItem
        }
    }

    @ViewBuilder
    private var waitTimeStatusItem: some View {
        if waitTimeVM.isLoadingActivePark {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.75)
                .tint(selectedPark.accentColor)
        } else if let error = waitTimeVM.lastError {
            Label(error.shortLabel, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(AppColor.error)
        } else if waitTimeVM.hasDataForActivePark {
            Text(waitTimeVM.lastUpdatedString)
                .font(.caption2)
                .foregroundStyle(waitTimeVM.isStale ? AppColor.warning : AppColor.textTertiary)
        }
    }
}

// MARK: - Map Reset button

/// Compact control that resets the map camera to the default park framing.
///
/// Always renders as a labeled capsule pill (map icon + "Map Reset") with a
/// .regularMaterial background and hairline stroke. Lives in the top header
/// toolbar leading slot so it aligns with the park title and wait-time status.
///
/// The action is always `mapVM.resetCamera()` — no map logic is changed.
private struct ShowFullParkButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Map Reset")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map Reset")
        .accessibilityHint("Resets the map to the full park view")
    }
}

// MARK: - Explore / Live mode toggle

/// Two-segment pill, shown only for parks where
/// MapModeAvailability.isExploreMapAvailable is true. Matches the visual
/// language of MapParkPill (capsule, filled-when-selected) rather than a
/// native segmented control, for consistency with the rest of the Maps tab.
private struct MapModeToggle: View {
    @Binding var mode: MapRenderMode

    var body: some View {
        HStack(spacing: 2) {
            segment(title: "Explore", isSelected: mode == .customCanvas) { mode = .customCanvas }
            segment(title: "Live",    isSelected: mode == .liveMap)      { mode = .liveMap }
        }
        .padding(3)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(AppMotion.quick) { action() }
            AppHaptic.selection()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? AppColor.textPrimary : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) Map")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Park selector strip

private struct MapParkSelectorStrip: View {
    @Binding var selectedPark: Park

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Park.allCases) { park in
                    MapParkPill(park: park, isSelected: park == selectedPark) {
                        withAnimation(AppMotion.quick) { selectedPark = park }
                        AppHaptic.selection()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, AppSpacing.xs)
        }
        .background(.regularMaterial)
    }
}

private struct MapParkPill: View {
    let park:       Park
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: park.systemImageName)
                    .font(.caption2.weight(.semibold))
                Text(park.shortName)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : park.accentColor)
            .background(
                isSelected ? park.accentColor : park.accentBackground,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : park.accentColor.opacity(0.3),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .animation(AppMotion.quick, value: isSelected)
    }
}

// MARK: - Wait-time banner

private struct MapWaitTimeBanner: View {
    let waitTimeVM: WaitTimeViewModel
    let park:       Park

    var body: some View {
        if waitTimeVM.isLoadingActivePark {
            banner(
                icon:  "arrow.triangle.2.circlepath",
                text:  "Fetching \(park.shortName) wait times…",
                color: park.accentColor
            )
        } else if let error = waitTimeVM.lastError {
            banner(
                icon:  "exclamationmark.triangle.fill",
                text:  error.localizedDescription,
                color: AppColor.error
            )
        } else if !waitTimeVM.hasDataForActivePark {
            banner(
                icon:  "wifi.slash",
                text:  "No wait time data for \(park.shortName)",
                color: AppColor.textSecondary
            )
        }
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Preview

#Preview {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM = WaitTimeViewModel(container: container)
    return MapTabView(selectedPark: .constant(.magicKingdom))
        .modelContainer(container)
        .environment(waitVM)
}

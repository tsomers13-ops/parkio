// MapTabView.swift — Root coordinator for the Maps tab.
//
// Ownership:
//   MapTabView creates and owns MapViewModel.
//   Lazily initialized on first appear so it can read @Environment(WaitTimeViewModel)
//   at creation time.
//
// Map layer:
//   RealMapScreen owns the full MapKit tile surface, user location puck, ride
//   annotations, follow mode, bearing polyline, HUD (filter bar + glance bar),
//   and the location / compass buttons.
//   ParkMapCanvasView / ParkMapBackgroundView are NOT rendered.
//
// Park switching (single source of truth):
//   switchPark(to:) updates mapVM.parkId. MapViewModel's didSet handles annotation
//   reload and camera reset. Called from the single .onChange(of: selectedPark).
//
// ZStack layer order in MapContentView:
//   1. RealMapScreen (MapKit tiles + pins + HUD + location controls)
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

    // SwiftData source of truth for ridden/logged state.
    @Query private var allRides: [Ride]

    var body: some View {
        Group {
            if let mapVM {
                MapContentView(
                    mapVM:        mapVM,
                    selectedPark: $selectedPark
                )
                .onChange(of: selectedPark) { _, newPark in
                    switchPark(to: newPark, mapVM: mapVM)
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
            mapVM = mVM
            mVM.onAppear()
            mVM.updateRiddenState(rides: allRides)
        }
    }

    // MARK: - Park switch

    private func switchPark(to park: Park, mapVM: MapViewModel) {
        // MapViewModel.parkId didSet calls loadAnnotations() + resetCamera() automatically.
        mapVM.parkId = park.backendId
    }
}

// MARK: - MapContentView

/// Full map experience: RealMapScreen + park selector + bottom sheet.
private struct MapContentView: View {
    let mapVM:        MapViewModel
    @Binding var selectedPark: Park

    @Environment(WaitTimeViewModel.self) private var waitTimeVM

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Layer 1: Real MapKit map ─────────────────────────────────────
                // RealMapScreen owns: Apple tile base, UserAnnotation (GPS puck),
                // ride annotations with real coordinates, bearing polyline,
                // MapHUDOverlay (filter bar + glance bar), location / compass buttons.
                // LocationService is already in the environment from ParkioApp.
                RealMapScreen()
                    .environment(mapVM)
                    .ignoresSafeArea(edges: .bottom)

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
        }
    }

    // MARK: Top chrome

    private var topChrome: some View {
        VStack(spacing: 0) {
            MapParkSelectorStrip(selectedPark: $selectedPark)
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

// ParkioApp.swift — App entry point.
//
// Wiring summary:
//   • SwiftData schema includes WaitTimeCache (alongside Ride + RideLog).
//   • BGAppRefreshTask handler registered in init() before app finishes launching.
//   • WaitTimeViewModel created once here, injected via .environment().
//   • ConnectivityMonitor singleton injected alongside it.
//   • scenePhase changes drive onBackground() / onForeground() lifecycle hooks.
//   • AppAppearanceManager drives .preferredColorScheme() at the window level.

import SwiftUI
import SwiftData
import BackgroundTasks
import CoreLocation

@main
struct ParkioApp: App {

    // ── SwiftData container ───────────────────────────────────────────────────

    let sharedModelContainer: ModelContainer

    // ── Shared view model ─────────────────────────────────────────────────────

    @State private var waitTimeViewModel: WaitTimeViewModel

    // ── Location service ──────────────────────────────────────────────────────
    // Created once here so the CLLocationManager lifecycle spans the full app session.
    // Injected via .environment(locationService) so any map view can access it.
    @State private var locationService = LocationService()

    // ── My Day store ──────────────────────────────────────────────────────────
    // Owns the ordered checklist of park-day items (rides, food, shows, etc.).
    // JSON-persisted to Documents; injected so any view can read or mutate it.
    @State private var myDayStore = MyDayStore()

    // ── Dining rating store ───────────────────────────────────────────────────
    // Owns all user dining ratings (1–5 stars, favourite, notes).
    // UserDefaults JSON; injected so RideDetailView and DiningRatingSheet can access it.
    @State private var diningRatingStore = DiningRatingStore()

    // ── Navigation coordinator ────────────────────────────────────────────────
    // Single source of truth for root tab selection + cross-tab navigation state
    // (e.g. My Day "Show on Map" → switches to map tab + selects a ride).
    @State private var navigationCoordinator = AppNavigationCoordinator()

    // ── Appearance manager ────────────────────────────────────────────────────
    // Persists the user's Light / Dark / System preference and vends the
    // ColorScheme? applied to the WindowGroup via .preferredColorScheme().
    @State private var appearanceManager = AppAppearanceManager()

    /// One location hold for the whole foreground session. Home and My Day
    /// read `userLocation` without taking their own hold, which is how the
    /// authorization callback used to keep a fix available from launch.
    @State private var foregroundLocationHold: UUID?

    // ── Scene phase ───────────────────────────────────────────────────────────

    @Environment(\.scenePhase) private var scenePhase

    // ── Init ──────────────────────────────────────────────────────────────────

    init() {
        // 1. Build SwiftData container with all three model types.
        let schema = Schema([
            Ride.self,
            RideLog.self,
            WaitTimeCache.self,
            ParkVisit.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Could not create ModelContainer — check schema for conflicts")
        }
        sharedModelContainer = container

        // 2. Register the BGAppRefreshTask handler.
        //    iOS requires this call before the app finishes launching (i.e. in init).
        //    See BackgroundRefreshService.swift for setup checklist.
        BackgroundRefreshService.registerHandler(modelContainer: container)

        // 3. Create the WaitTimeViewModel that drives HomeView and MyDayView.
        _waitTimeViewModel = State(initialValue: WaitTimeViewModel(container: container))
    }

    // ── App body ──────────────────────────────────────────────────────────────

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject shared services so any view can access them via @Environment.
                .environment(waitTimeViewModel)
                .environment(ConnectivityMonitor.shared)
                .environment(locationService)
                .environment(myDayStore)
                .environment(diningRatingStore)
                .environment(navigationCoordinator)
                .environment(appearanceManager)
                // Apply the user's appearance preference to the entire window.
                // nil → Follow System (SwiftUI default). .light / .dark → forced.
                .preferredColorScheme(appearanceManager.colorScheme)
                // Seed static ride catalog on first launch.
                .onAppear {
                    syncForegroundLocation(for: scenePhase)
                    RideSeeder.seedIfNeeded(context: sharedModelContainer.mainContext)
                    // Data-integrity self-check (duplicate IDs, land/park mismatches,
                    // stale DinoLand entries, missing map priorities, entity-ID coverage).
                    // Was defined but never called — MapCoordinateService's own validate()
                    // runs automatically on init, but this higher-level model check did not.
                    // DEBUG-only; has no effect in Release builds.
                    #if DEBUG
                    RideMasterData.validate()
                    ShopMasterData.validate()
                    #endif
                }
                // Start polling + connectivity observer once the view hierarchy is up.
                .task {
                    waitTimeViewModel.onAppear()
                }
                // Pause polling when backgrounded; resume and refresh when foregrounded.
                .onChange(of: scenePhase) { _, newPhase in
                    syncForegroundLocation(for: newPhase)
                    switch newPhase {
                    case .background:
                        waitTimeViewModel.onBackground()
                    case .active:
                        waitTimeViewModel.onForeground()
                    default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Holds a coarse location fix while the app is in the foreground,
    /// including `.inactive`. The hold drops only in `.background`.
    /// There is no location background mode.
    private func syncForegroundLocation(for phase: ScenePhase) {
        let shouldHold = ForegroundLocationPolicy.holdsLocation(phase)
        if shouldHold && foregroundLocationHold == nil {
            foregroundLocationHold = locationService.acquireLocationUpdates(
                accuracy: kCLLocationAccuracyHundredMeters,
                distanceFilter: 25
            )
        } else if !shouldHold, let hold = foregroundLocationHold {
            locationService.releaseLocationUpdates(hold)
            foregroundLocationHold = nil
        }
    }
}

/// The foreground location hold stays up through `.inactive` (Control
/// Center, the app switcher) and drops only when the scene is `.background`.
enum ForegroundLocationPolicy {
    static func holdsLocation(_ phase: ScenePhase) -> Bool {
        phase != .background
    }
}

// DisneyRideTrackerApp.swift — App entry point.
//
// Wiring summary:
//   • SwiftData schema includes WaitTimeCache (alongside Ride + RideLog).
//   • BGAppRefreshTask handler registered in init() before app finishes launching.
//   • WaitTimeViewModel created once here, injected via .environment().
//   • ConnectivityMonitor singleton injected alongside it.
//   • scenePhase changes drive onBackground() / onForeground() lifecycle hooks.

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct DisneyRideTrackerApp: App {

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

    // ── Navigation coordinator ────────────────────────────────────────────────
    // Single source of truth for root tab selection + cross-tab navigation state
    // (e.g. My Day "Show on Map" → switches to map tab + selects a ride).
    @State private var navigationCoordinator = AppNavigationCoordinator()

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
                .environment(navigationCoordinator)
                // Seed static ride catalog on first launch.
                .onAppear {
                    RideSeeder.seedIfNeeded(context: sharedModelContainer.mainContext)
                }
                // Start polling + connectivity observer once the view hierarchy is up.
                .task {
                    waitTimeViewModel.onAppear()
                }
                // Pause polling when backgrounded; resume and refresh when foregrounded.
                .onChange(of: scenePhase) { _, newPhase in
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
}

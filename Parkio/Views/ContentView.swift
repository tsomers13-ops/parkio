// ContentView.swift — 5-tab root shell (Phase 2 design system)
//
// selectedPark is initialized from the persisted backend ID in UserDefaults so
// it stays in sync with WaitTimeViewModel.activeParkId across app launches.
// Changes are propagated one-way: selectedPark → waitTimeVM.activeParkId.
//
// Tab selection is owned by AppNavigationCoordinator (injected from app root)
// so any feature can switch tabs programmatically — e.g. My Day "Show on Map".

import SwiftUI
import SwiftData

struct ContentView: View {

    // Active park filter — initialized from the VM's last-active backend ID.
    @State private var selectedPark: Park = {
        let backendId = UserDefaults.standard.string(
            forKey: UserDefaultsKey.lastActiveParkId
        ) ?? "magic-kingdom"
        return Park.fromBackendId(backendId) ?? .magicKingdom
    }()

    // ViewModel + coordinator injected by ParkioApp.
    @Environment(WaitTimeViewModel.self)        private var waitTimeVM
    @Environment(AppNavigationCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator

        TabView(selection: $coordinator.selectedTab) {

            // ── 0: Home ───────────────────────────────────────────────
            HomeView(selectedPark: $selectedPark)
                .tabItem {
                    Label("Home", systemImage: coordinator.selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            // ── 1: Map ────────────────────────────────────────────────
            MapTabView(selectedPark: $selectedPark)
                .tabItem {
                    Label("Map", systemImage: coordinator.selectedTab == 1 ? "map.fill" : "map")
                }
                .tag(1)

            // ── 2: My Day ─────────────────────────────────────────────
            MyDayView(selectedPark: $selectedPark)
                .tabItem {
                    Label("My Day", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(2)

            // ── 3: History ────────────────────────────────────────────
            HistoryView()
                .tabItem {
                    Label("History", systemImage: coordinator.selectedTab == 3 ? "clock.fill" : "clock")
                }
                .tag(3)

            // ── 4: Profile ────────────────────────────────────────────
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: coordinator.selectedTab == 4 ? "person.fill" : "person")
                }
                .tag(4)
        }
        .tint(selectedPark.accentColor)
        // Propagate park changes into the view model so it fetches the right park.
        .onChange(of: selectedPark) { _, newPark in
            waitTimeVM.activeParkId = newPark.backendId
        }
    }
}


#Preview {
    let schema = Schema([Ride.self, RideLog.self, WaitTimeCache.self, ParkVisit.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return ContentView()
        .modelContainer(container)
        .environment(WaitTimeViewModel(container: container))
        .environment(AppNavigationCoordinator())
        .environment(MyDayStore())
}

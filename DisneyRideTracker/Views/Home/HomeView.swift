// HomeView.swift — Premium Home screen dashboard (Phase 3)
//
// Data sources:
//   • Ride / RideLog       — @Query (SwiftData), drives ridden/unridden counts.
//   • WaitTimeViewModel    — @Environment, live waits + crowd analytics.
//   • MyDayStore           — @Environment, plan items + progress.
//   • AppNavigationCoordinator — @Environment, cross-tab routing.
//
// No MapViewModel dependency — that ViewModel is owned by MapTabView and is not
// available here. Best-next-ride and up-next are derived from WaitTimeViewModel
// + SwiftData ride list, which is accurate enough for home-screen decisions.

import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedPark: Park

    // ── Data ─────────────────────────────────────────────────────────────────
    @Query private var allRides: [Ride]
    @Environment(WaitTimeViewModel.self)        private var waitTimeVM
    @Environment(MyDayStore.self)               private var myDayStore
    @Environment(AppNavigationCoordinator.self) private var coordinator

    // ── Local UI state ────────────────────────────────────────────────────────
    @State private var showQuickLog = false

    // MARK: - Derived: park rides

    private var parkRides: [Ride] {
        allRides
            .filter { $0.park == selectedPark.rawValue }
            .sorted { $0.order < $1.order }
    }

    private var riddenRides:   [Ride] { parkRides.filter(\.isRidden) }
    private var unriddenRides: [Ride] { parkRides.filter { !$0.isRidden } }

    private var recentLogs: [(ride: Ride, log: RideLog)] {
        parkRides
            .flatMap { ride in ride.sortedLogs.prefix(1).map { (ride: ride, log: $0) } }
            .sorted { $0.log.date > $1.log.date }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Derived: live wait data

    /// Up to 6 unridden rides, sorted ascending by live wait. Falls back to
    /// `ride.order` if no live state is present yet so the list is stable.
    private var upNextRides: [Ride] {
        Array(
            unriddenRides
                .sorted { lhs, rhs in
                    let l = waitTimeVM.liveState(matching: lhs)?.waitMinutes ?? (lhs.order + 1000)
                    let r = waitTimeVM.liveState(matching: rhs)?.waitMinutes ?? (rhs.order + 1000)
                    return l < r
                }
                .prefix(6)
        )
    }

    /// All rideable live states for this park (ridden + unridden combined).
    private var liveRideableStates: [LiveRideState] {
        parkRides
            .compactMap { waitTimeVM.liveState(matching: $0) }
            .filter { $0.status.isRideable }
    }

    private var averageWaitMinutes: Int? {
        let waits = liveRideableStates.compactMap(\.waitMinutes)
        guard !waits.isEmpty else { return nil }
        return waits.reduce(0, +) / waits.count
    }

    private var openRideCount: Int { liveRideableStates.count }

    private var crowdLevel: CrowdLevel {
        guard let avg = averageWaitMinutes else { return .unknown }
        return CrowdLevel(averageWait: avg)
    }

    /// The single best recommendation: lowest-wait unridden rideable ride.
    private var bestNextRide: (ride: Ride, state: LiveRideState)? {
        for ride in upNextRides {
            if let state = waitTimeVM.liveState(matching: ride),
               state.status.isRideable {
                return (ride, state)
            }
        }
        return nil
    }

    /// First 4 unchecked My Day items for the preview card, padded with
    /// checked items if fewer than 4 unchecked exist.
    private var myDayPreviewItems: [MyDayItem] {
        let unchecked = myDayStore.items.filter { !$0.isChecked }.prefix(4)
        if unchecked.count < 4 {
            let checked = myDayStore.items
                .filter { $0.isChecked }
                .prefix(4 - unchecked.count)
            return Array(unchecked) + Array(checked)
        }
        return Array(unchecked)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                AppColor.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Stale / offline banner ─────────────────────────
                        if let banner = waitTimeVM.staleBannerText {
                            StaleBanner(message: banner)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // ── Park selector ──────────────────────────────────
                        ParkSelectorRow(selectedPark: $selectedPark)
                            .padding(.top, AppSpacing.sm)
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.md)

                        // ── Greeting ───────────────────────────────────────
                        HomeGreetingHeader(park: selectedPark)
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.lg)

                        // ── Status card ────────────────────────────────────
                        HomeStatusCard(
                            park:        selectedPark,
                            openCount:   openRideCount,
                            totalCount:  parkRides.count,
                            riddenCount: riddenRides.count,
                            averageWait: averageWaitMinutes,
                            crowdLevel:  crowdLevel
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, AppSpacing.sectionGap)

                        // ── Best Next Ride (self-labeled card, no outer header) ─
                        if let best = bestNextRide {
                            HomeBestNextRideCard(
                                ride:  best.ride,
                                state: best.state,
                                park:  selectedPark,
                                onShowOnMap: {
                                    coordinator.showOnMap(rideId: best.ride.id)
                                }
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sectionGap)
                        }

                        // ── Up Next horizontal scroll ──────────────────────
                        if !unriddenRides.isEmpty {
                            HomeSectionHeader(
                                title:       "Up Next",
                                subtitle:    pluralRides(unriddenRides.count) + " to go"
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sm)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    ForEach(upNextRides) { ride in
                                        WaitRideCard(
                                            ride:        ride,
                                            liveState:   waitTimeVM.liveState(matching: ride),
                                            accentColor: selectedPark.accentColor
                                        )
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenEdge)
                                .padding(.vertical, AppSpacing.xs)
                            }
                            .padding(.bottom, AppSpacing.sectionGap)
                        }

                        // ── My Day preview ─────────────────────────────────
                        if !myDayStore.items.isEmpty {
                            HomeSectionHeader(
                                title:       "My Day",
                                subtitle:    "\(myDayStore.remainingCount) remaining · \(myDayStore.completedCount) done",
                                actionLabel: "See all",
                                action:      { coordinator.selectedTab = 2 }
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sm)

                            HomeMyDayPreviewCard(
                                previewItems:   myDayPreviewItems,
                                totalCount:     myDayStore.items.count,
                                onTapItem: { item in
                                    if let rideId = item.rideId {
                                        coordinator.showOnMap(rideId: rideId)
                                    } else {
                                        coordinator.selectedTab = 2
                                    }
                                },
                                onTapSeeAll: { coordinator.selectedTab = 2 }
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sectionGap)
                        }

                        // ── Quick Actions ──────────────────────────────────
                        HomeQuickActionsRow(
                            park:      selectedPark,
                            onOpenMap: { coordinator.selectedTab = 1 },
                            onMyDay:   { coordinator.selectedTab = 2 },
                            onLogRide: { AppHaptic.medium(); showQuickLog = true }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, AppSpacing.sectionGap)

                        // ── Recent rides ───────────────────────────────────
                        if !recentLogs.isEmpty {
                            HomeSectionHeader(
                                title:    "Recent Rides",
                                subtitle: "Your latest logs"
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sm)

                            VStack(spacing: AppSpacing.sm) {
                                ForEach(recentLogs, id: \.log.date) { item in
                                    RecentLogRow(
                                        ride:        item.ride,
                                        log:         item.log,
                                        accentColor: selectedPark.accentColor
                                    )
                                }
                            }
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.bottom, AppSpacing.sectionGap)
                        }

                        // ── Celebration / empty ────────────────────────────
                        if !parkRides.isEmpty && unriddenRides.isEmpty {
                            AllRiddenBanner(park: selectedPark)
                                .padding(.horizontal, AppSpacing.screenEdge)
                                .padding(.bottom, AppSpacing.sectionGap)
                        }

                        if parkRides.isEmpty {
                            EmptyParkState(park: selectedPark)
                                .frame(maxWidth: .infinity)
                                .padding(.top, AppSpacing.xxxl)
                        }

                        Color.clear.frame(height: 100)
                    }
                    .animation(AppMotion.standard, value: waitTimeVM.staleBannerText != nil)
                }
                .refreshable {
                    await waitTimeVM.refresh()
                }

                // ── QuickLog FAB ───────────────────────────────────────────
                QuickLogFAB(accentColor: selectedPark.accentColor) {
                    AppHaptic.medium()
                    showQuickLog = true
                }
                .padding(.trailing, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .navigationTitle(selectedPark.shortName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        if waitTimeVM.isLoadingActivePark {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.75)
                                .tint(selectedPark.accentColor)
                        } else if waitTimeVM.hasDataForActivePark {
                            Text(waitTimeVM.lastUpdatedString)
                                .font(.caption2)
                                .foregroundStyle(
                                    waitTimeVM.isStale ? AppColor.warning : AppColor.textTertiary
                                )
                        }
                        Image(systemName: selectedPark.systemImageName)
                            .foregroundStyle(selectedPark.accentColor)
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showQuickLog) {
                QuickLogSheet(park: selectedPark)
            }
            // Keep WaitTimeViewModel in sync when the user switches parks.
            .onChange(of: selectedPark) { _, newPark in
                waitTimeVM.activeParkId = newPark.backendId
            }
        }
    }

    // MARK: - Helpers

    private func pluralRides(_ count: Int) -> String {
        count == 1 ? "1 ride" : "\(count) rides"
    }
}

// MARK: - Park Selector Row

struct ParkSelectorRow: View {
    @Binding var selectedPark: Park

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Park.allCases) { park in
                    ParkPill(park: park, isSelected: park == selectedPark) {
                        withAnimation(AppMotion.quick) { selectedPark = park }
                        AppHaptic.selection()
                    }
                }
            }
        }
    }
}

// MARK: - Park Pill

private struct ParkPill: View {
    let park: Park
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: park.systemImageName)
                    .font(.caption.weight(.semibold))
                Text(park.shortName)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .foregroundStyle(isSelected ? .white : park.accentColor)
            .background(isSelected ? park.accentColor : park.accentBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : park.accentColor.opacity(0.25),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QuickLog FAB

struct QuickLogFAB: View {
    let accentColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 56, height: 56)
                    .shadow(color: accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(AppMotion.quick, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

// MARK: - All-ridden Banner

private struct AllRiddenBanner: View {
    let park: Park

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(AppColor.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("You've ridden everything!")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Amazing work at \(park.shortName).")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .strokeBorder(AppColor.success.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Empty Park State

private struct EmptyParkState: View {
    let park: Park

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: park.systemImageName)
                .font(.system(size: 48))
                .foregroundStyle(park.accentColor.opacity(0.4))
            Text("Loading \(park.shortName)…")
                .font(.headline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return HomeView(selectedPark: .constant(.magicKingdom))
        .modelContainer(container)
        .environment(WaitTimeViewModel(container: container))
        .environment(MyDayStore())
        .environment(AppNavigationCoordinator())
}

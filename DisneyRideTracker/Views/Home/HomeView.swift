// HomeView.swift — Fast, glanceable park-day dashboard.
//
// Data sources:
//   • Ride / RideLog via @Query
//   • WaitTimeViewModel for live waits
//   • MyDayStore for planning/checklist
//   • AppNavigationCoordinator for tab and map handoff
//   • WeatherService for contextual weather hints and weather-aware ranking
//   • ParkHoursService for park hours, open/close status, and closing-soon signals
//   • LocationService for user GPS position (distance-aware ranking)
//
// Best Next Ride ranking (bestNextRide) — four-tier sort:
//
//   1. Weather preference partition (WeatherSignal-aware)
//      Only active when signal != .none. Preferred rides sort first.
//      .rainSoon / .raining → outdoor rides preferred (ride before it gets wet)
//      .hotDay              → indoor rides preferred  (seek air conditioning)
//      Signal == .none      → tier skipped entirely (original behavior)
//
//   2. Closing-soon feasibility partition
//      Only active when minutesUntilClose <= 120 (park closes within 2 hours).
//      A ride is "feasible" when (waitMinutes + 15) <= minutesUntilClose.
//      The 15-minute buffer covers ride duration + walk-off. Feasible rides
//      always sort before infeasible ones. Nil wait → treated as infeasible
//      (conservative). Park not closing soon → tier skipped entirely.
//
//   3. Distance-aware wait-time comparison
//      When user location is available and two rides have wait times within
//      5 minutes of each other, the closer ride wins. When waits differ by
//      more than 5 minutes, raw wait time takes priority. When location is
//      unavailable, falls back to plain shortest-wait sort (original behavior).
//
//   4. Stable seeder order as final tiebreaker
//
// First-ride onboarding nudge:
//   Shown inline inside HomeBestNextRideCard once, 60 seconds after Home
//   first appears, when the user has zero ride logs and has not previously
//   dismissed it. Dismissal persisted via @AppStorage("hasDismissedFirstRideNudge").
//
// Ride Streak micro-reward:
//   Shown directly below the Best Next Ride card when the user crosses a
//   ride-count milestone (3, 5, 10) during the current session. Auto-dismisses
//   after 4 seconds; tapping dismisses immediately. Each milestone fires at
//   most once per calendar day (UserDefaults key includes the date). The check
//   only runs on live count changes — never retroactively on app launch —
//   because .onChange(of: todayRideLogCount) fires only for transitions that
//   happen while the view is in the SwiftUI graph, not for the initial value.
//
// Park Day Summary card:
//   Shown near the bottom of the scroll view (before Quick Actions) once the
//   user has logged ≥3 rides today. Displays total rides, first ride of the day,
//   and most recent ride. Dismissal is persisted via UserDefaults with a
//   date-scoped key so it reappears automatically the next park day.

import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Binding var selectedPark: Park

    @Query private var allRides: [Ride]
    /// Queried globally (all parks) for both the first-ride nudge and the
    /// streak milestone counter.
    @Query private var allRideLogs: [RideLog]

    @Environment(WaitTimeViewModel.self)        private var waitTimeVM
    @Environment(MyDayStore.self)               private var myDayStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(LocationService.self)          private var locationService

    @State private var weatherService      = WeatherService()
    @State private var parkHoursService    = ParkHoursService()
    @State private var showAttractionsList = false
    @State private var showAddItemSheet    = false

    // ── First-ride nudge ───────────────────────────────────────────────────────
    @State  private var nudgeTimerFired = false
    @AppStorage("hasDismissedFirstRideNudge") private var hasDismissedFirstRideNudge = false

    private var showFirstRideNudge: Bool {
        nudgeTimerFired && !hasDismissedFirstRideNudge && allRideLogs.isEmpty
    }

    // ── Park Day Summary ───────────────────────────────────────────────────────
    /// Tracks whether the summary card has been dismissed today. Loaded from
    /// UserDefaults on appear (date-scoped key), written back on dismiss.
    /// @State rather than @AppStorage because the key is dynamic (includes date).
    @State private var parkDaySummaryDismissed = false

    /// Rides logged today across all parks, used for derived name properties.
    private var todayRideLogs: [RideLog] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRideLogs.filter { $0.date >= startOfDay }
    }

    /// Name of the earliest ride logged today, for the summary card.
    private var todayFirstRideName: String? {
        todayRideLogs.min(by: { $0.date < $1.date })?.ride?.name
    }

    /// Name of the most recently logged ride today, for the summary card.
    private var todayMostRecentRideName: String? {
        todayRideLogs.max(by: { $0.date < $1.date })?.ride?.name
    }

    /// Summary card is visible when ≥3 rides logged today and not dismissed.
    private var showParkDaySummary: Bool {
        todayRideLogCount >= 3 && !parkDaySummaryDismissed
    }

    private func dismissParkDaySummary() {
        UserDefaults.standard.set(
            true,
            forKey: "parkDaySummaryDismissed_\(todayDateKey)"
        )
        withAnimation(AppMotion.standard) { parkDaySummaryDismissed = true }
        AppHaptic.light()
    }

    // ── Ride Streak micro-reward ───────────────────────────────────────────────
    /// The milestone currently being displayed, or nil when the banner is hidden.
    @State private var activeStreakMilestone: Int? = nil
    /// Holds the auto-dismiss task so it can be cancelled on early tap or
    /// view disappearance. Stored in @State so it outlives re-renders.
    @State private var streakDismissTask: Task<Void, Never>? = nil

    /// Count of rides logged today (across all parks), recomputed whenever
    /// allRideLogs changes. Used as the onChange source for streak detection.
    private var todayRideLogCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRideLogs.filter { $0.date >= startOfDay }.count
    }

    /// ISO-8601 date string for today, used to scope UserDefaults keys so
    /// each milestone can fire once per calendar day, not once ever.
    private var todayDateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func streakStorageKey(for milestone: Int) -> String {
        "rideStreak_\(todayDateKey)_m\(milestone)"
    }

    private func hasShownStreakToday(_ milestone: Int) -> Bool {
        UserDefaults.standard.bool(forKey: streakStorageKey(for: milestone))
    }

    private func markStreakShownToday(_ milestone: Int) {
        UserDefaults.standard.set(true, forKey: streakStorageKey(for: milestone))
    }

    /// Exact copy required for each milestone.
    private func streakMessage(for milestone: Int) -> String {
        switch milestone {
        case 3:  return "3 rides logged today 🎯 Smart mode is learning your pace."
        case 5:  return "5 rides logged today ✨ You're building a great park day."
        case 10: return "10 rides logged today 🚀 Big park day unlocked."
        default: return ""
        }
    }

    /// Called from .onChange(of: todayRideLogCount).
    /// Checks whether the transition from oldCount to newCount crossed any
    /// unshown milestone and, if so, triggers the banner for the lowest one.
    ///
    /// Milestones are evaluated in ascending order so the smallest uncelebrated
    /// threshold always wins if the user logs multiple rides at once.
    private func checkStreakMilestone(from oldCount: Int, to newCount: Int) {
        for milestone in [3, 5, 10] {
            // Threshold must be freshly crossed: was below, now at or above.
            guard oldCount < milestone, newCount >= milestone else { continue }
            // Not already shown today.
            guard !hasShownStreakToday(milestone) else { continue }
            markStreakShownToday(milestone)
            triggerStreakBanner(for: milestone)
            break   // one milestone per log event; next crossing triggers next
        }
    }

    private func triggerStreakBanner(for milestone: Int) {
        // Cancel any in-flight auto-dismiss before replacing the banner.
        streakDismissTask?.cancel()

        withAnimation(AppMotion.standard) { activeStreakMilestone = milestone }
        AppHaptic.success()

        // Auto-dismiss after 4 seconds. @MainActor annotation ensures the
        // state mutation happens on the main thread after the async sleep.
        streakDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(AppMotion.standard) { activeStreakMilestone = nil }
        }
    }

    private func dismissStreakBanner() {
        streakDismissTask?.cancel()
        streakDismissTask = nil
        withAnimation(AppMotion.standard) { activeStreakMilestone = nil }
        AppHaptic.light()
    }

    // MARK: - Derived ride lists

    private var parkRides: [Ride] {
        allRides
            .filter { $0.park == selectedPark.rawValue }
            .sorted { $0.order < $1.order }
    }

    private var riddenRides: [Ride] {
        parkRides.filter(\.isRidden)
    }

    private var unriddenRides: [Ride] {
        parkRides.filter { !$0.isRidden }
    }

    private var rideableCandidates: [(ride: Ride, state: LiveRideState)] {
        parkRides.compactMap { ride in
            // Only traditional rides participate in ride-count metrics and Best Next Ride.
            // Shows/walkthroughs/meets that post live waits (e.g. Monsters Inc, Zootopia)
            // appear in the full attractions list but must never be recommended as "rides".
            // NOTE: No ?? fallback — rides not in typeByStableID are EXCLUDED, not defaulted to .ride.
            guard RideMasterData.typeByStableID[ride.id] == .ride else { return nil }
            guard let state = waitTimeVM.fastLiveState(for: ride),
                  state.status.isRideable else {
                return nil
            }
            return (ride: ride, state: state)
        }
    }

    #if DEBUG
    /// Dumps a diagnostic table to the console for the current park.
    /// Call this from .task or .onChange when investigating count mismatches.
    private func debugDumpParkCounts() {
        let park = selectedPark
        let parkName = park.rawValue
        let rides = parkRides

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🏰 DEBUG — \(parkName) | parkRides: \(rides.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for ride in rides {
            let resolvedType = RideMasterData.typeByStableID[ride.id]
            let typeLabel: String
            let source: String
            if let t = resolvedType {
                typeLabel = "\(t)"
                source = "static"
            } else {
                typeLabel = "UNKNOWN"
                source = "⚠️ NOT IN typeByStableID"
            }
            let liveState = waitTimeVM.fastLiveState(for: ride)
            let isRideable = liveState?.status.isRideable ?? false
            let wait = liveState.flatMap(\.waitMinutes).map { "\($0) min" } ?? "nil"
            let included = resolvedType == .ride && isRideable ? "✅ rideableCandidate" : "—"

            print("  \(ride.id)")
            print("    name: \(ride.name) | type: \(typeLabel) [\(source)]")
            print("    isRideable: \(isRideable) | waitMinutes: \(wait) | \(included)")
        }

        let candidates = rideableCandidates
        let upNext = visibleUpNextItems
        let parkWideShortWaits = candidates.filter { ($0.state.waitMinutes ?? Int.max) <= 20 }

        print("────────────────────────────────────────────")
        print("  rideableCandidates : \(candidates.count)  (park-wide open rides)")
        print("  visibleUpNextItems : \(upNext.count)  (Up Next preview, capped at 6)")
        print("  short waits ≤20 min: \(parkWideShortWaits.count)  (park-wide, chip removed)")
        print("────────────────────────────────────────────")
        print("  Up Next breakdown:")
        for item in upNext {
            let wait = item.state.waitMinutes.map { "\($0) min" } ?? "nil"
            let chip = (item.state.waitMinutes ?? 999) <= 20 ? "🟢" : "⚪️"
            print("    \(chip) \(item.ride.name) — \(wait)")
        }

        let noTypeMatch = rides.filter { RideMasterData.typeByStableID[$0.id] == nil }
        if !noTypeMatch.isEmpty {
            print("────────────────────────────────────────────")
            print("  ⚠️ \(noTypeMatch.count) ride(s) with NO typeByStableID entry:")
            for r in noTypeMatch {
                print("    stableID: \(r.id)")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    #endif

    // MARK: - Up Next — single source of truth

    /// Canonical Up Next candidate list. The visible card rows are derived from
    /// this array and capped at 6.
    ///
    /// Inclusion rules (all three must hold):
    ///   1. `type == .ride`  — shows, character meets, walkthroughs excluded
    ///   2. `isRideable`     — open and accepting guests
    ///   3. `waitMinutes != nil` — a posted standby wait is required; rides with
    ///       no posted wait are grey (not green) and must not be counted
    ///
    /// Sort: planned (My Day) rides first, then ascending wait time, then seeder order.
    /// Capped at 6 — the maximum visible rows in the Up Next card.
    private var visibleUpNextItems: [(ride: Ride, state: LiveRideState)] {
        let plannedIds = Set(myDayStore.items.compactMap(\.rideId))
        return parkRides
            .compactMap { ride -> (ride: Ride, state: LiveRideState)? in
                // Rule 1: traditional rides only.
                // NOTE: No ?? fallback — rides not in typeByStableID are EXCLUDED, not defaulted to .ride.
                guard RideMasterData.typeByStableID[ride.id] == .ride else { return nil }
                // Rules 2 & 3: open with a posted wait
                guard let state = waitTimeVM.fastLiveState(for: ride),
                      state.status.isRideable,
                      state.waitMinutes != nil else { return nil }
                return (ride: ride, state: state)
            }
            .sorted { lhs, rhs in
                let lhsPlanned = plannedIds.contains(lhs.ride.id)
                let rhsPlanned = plannedIds.contains(rhs.ride.id)
                if lhsPlanned != rhsPlanned { return lhsPlanned }
                // waitMinutes is guaranteed non-nil by the compactMap filter above
                let lhsWait = lhs.state.waitMinutes!
                let rhsWait = rhs.state.waitMinutes!
                if lhsWait != rhsWait { return lhsWait < rhsWait }
                return lhs.ride.order < rhs.ride.order
            }
            .prefix(6)
            .map { $0 }
    }

    /// Adapts `visibleUpNextItems` to the optional-state signature that
    /// `HomeUpNextPreviewCard` expects (for nil-state empty-state handling).
    private var upNextRides: [(ride: Ride, state: LiveRideState?)] {
        visibleUpNextItems.map { (ride: $0.ride, state: $0.state) }
    }

    // MARK: - Best Next Ride

    private var bestNextRide: (ride: Ride, state: LiveRideState)? {
        let plannedIds  = Set(myDayStore.items.compactMap(\.rideId))
        let signal      = weatherService.current?.signal ?? .none
        let closingMins = parkHoursService.current?.minutesUntilClose
        let userLoc     = locationService.userLocation

        let unriddenOpen = rideableCandidates
            .filter { !plannedIds.contains($0.ride.id) }
            .filter { !unriddenRides.isEmpty ? !($0.ride.isRidden) : true }

        let parkId = selectedPark.backendId
        var distanceCache: [String: CLLocationDistance] = [:]
        if let userLoc {
            for candidate in unriddenOpen {
                if let ann = MapCoordinateService.shared.annotation(
                    forRideId: candidate.ride.id,
                    parkId: parkId
                ) {
                    distanceCache[candidate.ride.id] = userLoc.distance(
                        from: CLLocation(latitude: ann.latitude, longitude: ann.longitude)
                    )
                }
            }
        }

        return unriddenOpen.sorted { lhs, rhs in
            if signal != .none {
                let lhsPref = weatherPreferred(lhs.ride, signal: signal)
                let rhsPref = weatherPreferred(rhs.ride, signal: signal)
                if lhsPref != rhsPref { return lhsPref }
            }

            if let minsLeft = closingMins, minsLeft <= 120 {
                let lhsFeasible = closingFeasible(lhs.state, minsLeft: minsLeft)
                let rhsFeasible = closingFeasible(rhs.state, minsLeft: minsLeft)
                if lhsFeasible != rhsFeasible { return lhsFeasible }
            }

            let lhsWait = lhs.state.waitMinutes ?? 999
            let rhsWait = rhs.state.waitMinutes ?? 999

            if lhsWait < 999, rhsWait < 999, abs(lhsWait - rhsWait) <= 5 {
                let lhsDist = distanceCache[lhs.ride.id]
                let rhsDist = distanceCache[rhs.ride.id]
                if let ld = lhsDist, let rd = rhsDist, ld != rd { return ld < rd }
            }
            if lhsWait != rhsWait { return lhsWait < rhsWait }
            return lhs.ride.order < rhs.ride.order
        }
        .first
    }

    private var bestNextRideDistance: CLLocationDistance? {
        guard let best = bestNextRide,
              let userLoc = locationService.userLocation else { return nil }
        guard let ann = MapCoordinateService.shared.annotation(
            forRideId: best.ride.id,
            parkId: selectedPark.backendId
        ) else { return nil }
        return userLoc.distance(from: CLLocation(latitude: ann.latitude, longitude: ann.longitude))
    }

    private func weatherPreferred(_ ride: Ride, signal: WeatherSignal) -> Bool {
        switch signal {
        case .none:            return true
        case .rainSoon, .raining: return RideEnvironmentTable.isOutdoor(ride)
        case .hotDay:          return !RideEnvironmentTable.isOutdoor(ride)
        }
    }

    private func closingFeasible(_ state: LiveRideState, minsLeft: Int) -> Bool {
        guard let wait = state.waitMinutes else { return false }
        return (wait + 15) <= minsLeft
    }

    // MARK: - Stats

    private var myDayPreviewItems: [MyDayItem] {
        let remaining = myDayStore.items.filter { !$0.isChecked }
        let checked   = myDayStore.items.filter(\.isChecked)
        return Array((remaining + checked).prefix(5))
    }

    private var openRideCount: Int   { rideableCandidates.count }

    private var averageWaitMinutes: Int? {
        let waits = rideableCandidates.compactMap(\.state.waitMinutes)
        guard !waits.isEmpty else { return nil }
        return waits.reduce(0, +) / waits.count
    }

    private var crowdLevel: CrowdLevel {
        averageWaitMinutes.map(CrowdLevel.init(averageWait:)) ?? .unknown
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                        if let banner = waitTimeVM.staleBannerText {
                            StaleBanner(message: banner)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        HomeHeaderView(
                            park: selectedPark,
                            crowdLevel: crowdLevel,
                            lastUpdatedText: waitTimeVM.hasDataForActivePark
                                ? waitTimeVM.lastUpdatedString : nil,
                            weather: weatherService.current,
                            hours: parkHoursService.current
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.top, AppSpacing.sm)

                        ParkSelectorRow(selectedPark: $selectedPark)
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .padding(.top, -AppSpacing.md)

                        // ── Best Next Ride card + streak banner ────────────────
                        // Grouped in a tight VStack so the banner sits flush
                        // below the card without a full sectionGap in between.
                        VStack(spacing: AppSpacing.sm) {
                            if let best = bestNextRide {
                                HomeBestNextRideCard(
                                    ride: best.ride,
                                    state: best.state,
                                    park: selectedPark,
                                    isPlanned: myDayStore.containsRide(best.ride.id),
                                    weather: weatherService.current,
                                    hours: parkHoursService.current,
                                    distanceMeters: bestNextRideDistance,
                                    showFirstRideNudge: showFirstRideNudge,
                                    onNudgeDismiss: {
                                        withAnimation(AppMotion.standard) {
                                            hasDismissedFirstRideNudge = true
                                        }
                                    },
                                    onShowOnMap: {
                                        coordinator.showOnMap(rideId: best.ride.id)
                                    },
                                    onAddToMyDay: {
                                        addRideToMyDay(best.ride)
                                    }
                                )
                            } else {
                                HomeBestNextRideEmptyCard(
                                    park: selectedPark,
                                    hasRides: !parkRides.isEmpty
                                ) {
                                    showAttractionsList = true
                                }
                            }

                            // Streak banner — appears directly below the card,
                            // animated in from the top, auto-dismissed after 4 s.
                            if let milestone = activeStreakMilestone {
                                RideStreakBanner(
                                    message: streakMessage(for: milestone),
                                    onTap: dismissStreakBanner
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .animation(AppMotion.standard, value: activeStreakMilestone)

                        HomeQuickFilterRow(
                            openNowCount: openRideCount,
                            plannedCount: myDayStore.remainingCount,
                            totalRideCount: parkRides.count,
                            onNearby: { coordinator.selectedTab = 1 },
                            onOpenNow: { showAttractionsList = true },
                            onMyPlan: { coordinator.selectedTab = 2 }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)

                        HomeSectionHeader(
                            title: "Up Next",
                            subtitle: "\(openRideCount) open now",
                            actionLabel: "See All",
                            action: {
                                AppHaptic.light()
                                showAttractionsList = true
                            }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, -AppSpacing.md)

                        HomeUpNextPreviewCard(
                            rides: upNextRides,
                            park: selectedPark,
                            onShowOnMap: { coordinator.showOnMap(rideId: $0.id) },
                            onAddToMyDay: { addRideToMyDay($0) }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)

                        HomeSectionHeader(
                            title: "My Day",
                            subtitle: "\(myDayStore.remainingCount) remaining · \(myDayStore.completedCount) done",
                            actionLabel: "Open",
                            action: { coordinator.selectedTab = 2 }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, -AppSpacing.md)

                        HomeMyDayPreviewCard(
                            previewItems: myDayPreviewItems,
                            remainingCount: myDayStore.remainingCount,
                            completedCount: myDayStore.completedCount,
                            onTapItem: { item in
                                if let rideId = item.rideId {
                                    coordinator.showOnMap(rideId: rideId)
                                } else {
                                    coordinator.selectedTab = 2
                                }
                            },
                            onTapSeeAll: { coordinator.selectedTab = 2 },
                            onAddItem: { showAddItemSheet = true }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)

                        // ── Park Day Summary ──────────────────────────────────
                        // Appears once ≥3 rides are logged today. Slides in from
                        // the bottom; dismissed via date-scoped UserDefaults key.
                        if showParkDaySummary {
                            HomeParkDaySummaryCard(
                                rideCount: todayRideLogCount,
                                firstRideName: todayFirstRideName,
                                mostRecentRideName: todayMostRecentRideName,
                                onDismiss: dismissParkDaySummary
                            )
                            .padding(.horizontal, AppSpacing.screenEdge)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        HomeQuickActionsRow(
                            park: selectedPark,
                            onMap: { coordinator.selectedTab = 1 },
                            onMyDay: { coordinator.selectedTab = 2 },
                            onAttractions: { showAttractionsList = true },
                            onAddItem: { showAddItemSheet = true }
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    .padding(.bottom, AppSpacing.xxl)
                    .animation(AppMotion.standard, value: showParkDaySummary)
                }
                .refreshable {
                    // Refresh both wait times and park hours on pull-to-refresh.
                    // forceRefresh() is synchronous (fire-and-forget API fetch);
                    // waitTimeVM.refresh() is awaited so the spinner stays up until
                    // the wait-time network call completes.
                    parkHoursService.forceRefresh()
                    await waitTimeVM.refresh()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showAttractionsList) {
                AttractionsListView(park: selectedPark, rides: parkRides)
            }
            .sheet(isPresented: $showAddItemSheet) {
                AddMyDayItemSheet(park: selectedPark) { item in
                    withAnimation(AppMotion.standard) { myDayStore.add(item) }
                    AppHaptic.light()
                }
            }
            .task {
                weatherService.startPolling(for: selectedPark)
                parkHoursService.start(for: selectedPark)
                // Restore today's park-day summary dismissal state so the card
                // doesn't reappear after the user dismissed it earlier today.
                parkDaySummaryDismissed = UserDefaults.standard.bool(
                    forKey: "parkDaySummaryDismissed_\(todayDateKey)"
                )
                #if DEBUG
                // Give waitTimeVM 1 s to finish its initial fetch before we read counts.
                try? await Task.sleep(for: .seconds(1))
                debugDumpParkCounts()
                #endif
            }
            // First-ride nudge: 60-second countdown.
            // Guard prevents re-running if already fired or permanently dismissed.
            .task(id: "firstRideNudge") {
                guard !hasDismissedFirstRideNudge, !nudgeTimerFired else { return }
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                withAnimation(AppMotion.standard) { nudgeTimerFired = true }
            }
            .onDisappear {
                weatherService.stopPolling()
                parkHoursService.stop()
                // Cancel any pending streak auto-dismiss to avoid a dangling
                // task mutating state after the view leaves the hierarchy.
                streakDismissTask?.cancel()
            }
            .onChange(of: selectedPark) { _, newPark in
                waitTimeVM.activeParkId = newPark.backendId
                weatherService.changePark(newPark)
                parkHoursService.changePark(newPark)
                #if DEBUG
                // Slight delay so waitTimeVM has time to swap its activeParkId
                // before we read fastLiveState. 0.5 s is enough for the index rebuild.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    debugDumpParkCounts()
                }
                #endif
            }
            // Streak milestone detection.
            // .onChange fires only on live transitions — never for the initial
            // value — so old milestones are never shown retroactively on launch.
            .onChange(of: todayRideLogCount) { oldCount, newCount in
                checkStreakMilestone(from: oldCount, to: newCount)
            }
        }
    }

    // MARK: - Helpers

    private func addRideToMyDay(_ ride: Ride) {
        guard !myDayStore.containsRide(ride.id) else {
            AppHaptic.selection()
            return
        }
        myDayStore.addRide(
            rideId: ride.id,
            name: ride.name,
            land: ride.land.isEmpty ? nil : ride.land,
            parkId: selectedPark.backendId
        )
        AppHaptic.success()
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
                        isSelected ? Color.clear : park.accentColor.opacity(0.22),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let schema = Schema([Ride.self, RideLog.self, WaitTimeCache.self, ParkVisit.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return HomeView(selectedPark: .constant(.magicKingdom))
        .modelContainer(container)
        .environment(WaitTimeViewModel(container: container))
        .environment(MyDayStore())
        .environment(AppNavigationCoordinator())
        .environment(LocationService())
}

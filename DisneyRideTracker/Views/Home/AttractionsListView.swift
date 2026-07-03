// AttractionsListView.swift — Full park attractions list, opened from Home "Up Next" section.
//
// Architecture:
//   • Receives the already-loaded park rides from HomeView. This keeps the pushed
//     destination lightweight: no SwiftData @Query is initialized during navigation.
//   • Data: WaitTimeViewModel + MyDayStore from @Environment — no new view models needed.
//   • Search: inline bar above the chip strip; filters by name and land, case-insensitive.
//   • Sorting: four modes — wait ascending, name A–Z, open first, by land.
//   • Filtering: "Open only" chip; stacks with search and sort.
//   • By Land: LazyVStack(pinnedViews: [.sectionHeaders]) gives sticky land headers.
//   • My Day: context menu per row with auto-dismiss toast.
//   • Favorites: star-icon toggle; favorites always sort to the top in all modes.
//     Persisted per-park in UserDefaults as a JSON-encoded Set<String>.
//   • Recently Viewed: tracks the last 10 tapped rides (MRU order); shown as a card
//     below Favorites but above the main list.  Hidden during search.
//     Persisted per-park in UserDefaults as a JSON-encoded [String].
//
// Performance model:
//   The original freeze: liveState(matching:) ran two full linear scans of liveRides,
//   calling normalizedForMatching() on every element on every scan — O(N × 2M) string
//   allocations per makeSnapshot() invocation, where N = rides, M = live states.
//   Combined with @Observable re-rendering the view on every connectivity tick, this
//   continuously saturated the main thread.
//
//   Fix (two files):
//     WaitTimeViewModel now maintains normalizedLiveIndex — a [String: LiveRideState]
//     keyed by pre-normalized name, rebuilt once per liveRides assignment via didSet.
//     Cost: O(M) normalizations, paid once per data fetch (~3 min interval).
//
//     AttractionsListView.makeSnapshot() calls waitTimeVM.fastLiveState(for: ride)
//     per ride.  fastLiveState() normalizes ride.name once (O(1) string work) then
//     does an O(1) dict lookup into normalizedLiveIndex.  Total per-render cost:
//     O(N) normalizations + O(N) lookups — down from O(N × 2M) normalization calls.
//
//     Because fastLiveState() reads normalizedLiveIndex (a tracked @Observable
//     property), views that call it auto-register it as a body dependency and
//     re-render when new fetch data arrives — no manual .onChange or @State cache needed.
//
// Navigation:
//   Pushed via NavigationStack's .navigationDestination(isPresented:) in HomeView.
//   Does NOT wrap in its own NavigationStack.

import SwiftUI
import SwiftData

// MARK: - Category filter

enum AttractionCategoryFilter: String, CaseIterable, Identifiable {
    case all        = "All"
    case rides      = "Rides"
    case shows      = "Shows"
    case characters = "Characters"
    case dining     = "Dining"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:        return "list.bullet"
        case .rides:      return "bolt.fill"
        case .shows:      return "theatermasks.fill"
        case .characters: return "person.fill.checkmark"
        case .dining:     return "fork.knife"
        }
    }

    /// AttractionTypes that pass through this filter. nil = all types allowed.
    var allowedTypes: Set<AttractionType>? {
        switch self {
        case .all:        return nil
        case .rides:      return [.ride, .transport]
        case .shows:      return [.show, .walkthrough]
        case .characters: return [.characterMeet]
        case .dining:     return [.quickService, .snackStand, .tableService, .lounge, .festivalBooth]
        }
    }
}

// MARK: - Sort mode

enum AttractionSort: String, CaseIterable, Identifiable {
    case waitAscending = "Wait: Low → High"
    case nameAZ        = "Name A–Z"
    case statusOpen    = "Open First"
    case byLand        = "By Land"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .waitAscending: return "clock"
        case .nameAZ:        return "textformat.abc"
        case .statusOpen:    return "checkmark.circle"
        case .byLand:        return "map"
        }
    }
}

// MARK: - LandSection

private struct LandSection: Identifiable {
    let land:       String
    let rides:      [Ride]
    let openCount:  Int
    var id: String  { land }
}

// MARK: - RenderSnapshot

/// All derived data computed once per body render.
/// liveMap is keyed by ride.id and built from WaitTimeViewModel.fastLiveState(for:) —
/// O(1) per ride.  plannedIds and favoriteIds use Sets for O(1) membership tests per row.
private struct RenderSnapshot {
    let liveMap:             [String: LiveRideState]   // ride.id → state
    let plannedIds:          Set<String>               // planned ride IDs
    let favoriteIds:         Set<String>               // favorited ride IDs
    let openCount:           Int
    let rides:               [Ride]                    // non-favorite, pre-sorted; empty when byLand
    let sections:            [LandSection]             // pre-grouped, non-favorite; empty when not byLand
    let favoriteRides:       [Ride]                    // favorited rides, name-sorted
    let recentlyViewedRides: [Ride]                    // last ≤10, MRU-ordered; empty during search
}

// MARK: - AttractionsListView

struct AttractionsListView: View {

    let park: Park

    // ── Data ─────────────────────────────────────────────────────────────────
    private let rides: [Ride]
    @Environment(WaitTimeViewModel.self)   private var waitTimeVM
    @Environment(MyDayStore.self)          private var myDayStore
    @Environment(DiningRatingStore.self)   private var diningRatingStore

    // ── UI state ──────────────────────────────────────────────────────────────
    @State private var sort:              AttractionSort           = .waitAscending
    @State private var openOnly:          Bool                     = false
    @State private var categoryFilter:    AttractionCategoryFilter = .all
    @State private var searchText:        String                   = ""
    @State private var toastMessage:      String?        = nil
    @State private var favoriteIds:       Set<String>    = []
    @State private var recentlyViewedIds: [String]       = []
    @FocusState private var searchFocused: Bool

    // MARK: - Init
    //
    // Keep this view free of @Query. SwiftData query setup/fetch happens
    // synchronously as the destination is constructed, before body is evaluated;
    // on larger stores that can stall the Home -> All Attractions push even if
    // this view's body is reduced to a trivial Text.

    init(park: Park, rides: [Ride] = [], initialCategoryFilter: AttractionCategoryFilter = .all) {
        self.park = park
        self.rides = rides
            .filter { $0.park == park.rawValue }
            .sorted { $0.order < $1.order }
        _categoryFilter = State(initialValue: initialCategoryFilter)

        // Load persisted favorites for this park
        let favKey = "favorites_\(park.rawValue)"
        if let data    = UserDefaults.standard.data(forKey: favKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            _favoriteIds = State(initialValue: decoded)
        }

        // Load persisted recently-viewed list for this park
        let rvKey = "recentlyViewed_\(park.rawValue)"
        if let data    = UserDefaults.standard.data(forKey: rvKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            _recentlyViewedIds = State(initialValue: decoded)
        }
    }

    // MARK: - Snapshot builder
    //
    // Called once at the top of body.
    //
    // liveMap construction: O(N) calls to fastLiveState(for:).
    //   fastLiveState normalizes ride.name once, then does an O(1) dict lookup
    //   into WaitTimeViewModel.normalizedLiveIndex (pre-built by the ViewModel).
    //   Reading normalizedLiveIndex registers it as a body dependency, so the
    //   view auto-re-renders when the ViewModel receives new data — no manual
    //   .onChange triggers needed.
    //
    // All subsequent filtering, sorting, and grouping uses liveMap[ride.id] — O(1).

    private func makeSnapshot() -> RenderSnapshot {
        // Build per-render live map — O(N) fastLiveState calls, each O(1)
        var liveMap = [String: LiveRideState](minimumCapacity: rides.count)
        for ride in rides {
            liveMap[ride.id] = waitTimeVM.fastLiveState(for: ride)
        }

        // Planned-ID set — O(MyDayItems) once per render
        let plannedIds = Set(myDayStore.items.compactMap(\.rideId))

        // Park-wide open count (unfiltered — matches chip-strip semantics)
        let openCount = rides.filter {
            liveMap[$0.id]?.status.isRideable == true
        }.count

        // Search filter — pure text match, no ViewModel access
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let isSearching = !trimmed.isEmpty
        let searched: [Ride]
        if trimmed.isEmpty {
            searched = Array(rides)
        } else {
            let q = trimmed.lowercased()
            searched = rides.filter {
                $0.name.lowercased().contains(q) ||
                $0.land.lowercased().contains(q)
            }
        }

        // Open-only filter
        let afterOpenOnly = openOnly
            ? searched.filter { liveMap[$0.id]?.status.isRideable == true }
            : searched

        // Category filter — uses the static O(1) typeByStableID lookup.
        // Character meets and shows without live wait data are always included
        // regardless of the openOnly chip (they have no live state to compare).
        let filtered: [Ride]
        if let allowedTypes = categoryFilter.allowedTypes {
            filtered = afterOpenOnly.filter { ride in
                // Rides not in typeByStableID are excluded from category tabs rather
                // than silently defaulted to .ride, which would mis-categorise them.
                guard let type = RideMasterData.typeByStableID[ride.id] else { return false }
                return allowedTypes.contains(type)
            }
        } else {
            filtered = afterOpenOnly
        }

        // Partition into favorites and non-favorites (both from filtered set)
        let favSet      = favoriteIds
        let favRides    = filtered
            .filter { favSet.contains($0.id) }
            .sorted { $0.name < $1.name }
        let nonFavRides = filtered.filter { !favSet.contains($0.id) }

        // Recently viewed — drawn from full park rides (not filtered by openOnly/search)
        // so a ride you just tapped always appears even if it's currently closed.
        // Suppressed during search to avoid confusing results context.
        // Favorites are excluded here to prevent duplication.
        let recentRides: [Ride]
        if !isSearching {
            recentRides = recentlyViewedIds
                .compactMap { id in rides.first { $0.id == id } }
                .filter { !favSet.contains($0.id) }
        } else {
            recentRides = []
        }

        // ── Sort / group ───────────────────────────────────────────────────────
        // When the Dining filter is active, bypass the ride-star favorites split
        // and apply dining-specific sort: (1) heart-favorited venues first,
        // (2) highest personal rating, (3) A–Z.  Unrated venues (no entry in
        // DiningRatingStore) sort last.  Ride sorting is completely unaffected.
        let currentRides:     [Ride]
        let currentSections:  [LandSection]
        let resolvedFavRides: [Ride]

        if categoryFilter == .dining {
            resolvedFavRides = []
            currentSections  = []
            currentRides     = filtered.sorted { lhs, rhs in
                let lRating = diningRatingStore.rating(for: lhs.id)
                let rRating = diningRatingStore.rating(for: rhs.id)
                let lFav    = lRating?.isFavorite ?? false
                let rFav    = rRating?.isFavorite ?? false
                let lRate   = lRating?.rating ?? 0
                let rRate   = rRating?.rating ?? 0
                if lFav != rFav   { return lFav }
                if lRate != rRate { return lRate > rRate }
                return lhs.name < rhs.name
            }
        } else if sort == .byLand {
            resolvedFavRides = favRides
            currentRides     = []
            currentSections  = makeLandSections(from: nonFavRides, liveMap: liveMap)
        } else {
            resolvedFavRides = favRides
            currentSections  = []
            currentRides     = sortedRides(nonFavRides, liveMap: liveMap)
        }

        return RenderSnapshot(
            liveMap:             liveMap,
            plannedIds:          plannedIds,
            favoriteIds:         favSet,
            openCount:           openCount,
            rides:               currentRides,
            sections:            currentSections,
            favoriteRides:       resolvedFavRides,
            recentlyViewedRides: recentRides
        )
    }

    // MARK: - Sort helper

    private func sortedRides(_ input: [Ride], liveMap: [String: LiveRideState]) -> [Ride] {
        var result = input
        switch sort {
        case .waitAscending:
            result.sort { lhs, rhs in
                let lState = liveMap[lhs.id]
                let rState = liveMap[rhs.id]
                let lOpen  = lState?.status.isRideable ?? false
                let rOpen  = rState?.status.isRideable ?? false
                if lOpen != rOpen { return lOpen }
                if lOpen && rOpen {
                    return (lState?.waitMinutes ?? 999) < (rState?.waitMinutes ?? 999)
                }
                return lhs.name < rhs.name
            }
        case .nameAZ:
            result.sort { $0.name < $1.name }
        case .statusOpen:
            result.sort { lhs, rhs in
                let lOpen = liveMap[lhs.id]?.status.isRideable ?? false
                let rOpen = liveMap[rhs.id]?.status.isRideable ?? false
                if lOpen != rOpen { return lOpen }
                return lhs.name < rhs.name
            }
        case .byLand:
            result.sort { $0.name < $1.name }
        }
        return result
    }

    // MARK: - Land-grouping helper

    private func makeLandSections(
        from input: [Ride],
        liveMap:    [String: LiveRideState]
    ) -> [LandSection] {
        let grouped = Dictionary(grouping: input) {
            $0.land.trimmingCharacters(in: .whitespaces).isEmpty ? "Other" : $0.land
        }

        return grouped
            .map { land, landRides in
                let sorted = landRides.sorted { lhs, rhs in
                    let lState = liveMap[lhs.id]
                    let rState = liveMap[rhs.id]
                    let lOpen  = lState?.status.isRideable ?? false
                    let rOpen  = rState?.status.isRideable ?? false
                    if lOpen != rOpen { return lOpen }
                    if lOpen && rOpen {
                        return (lState?.waitMinutes ?? 999) < (rState?.waitMinutes ?? 999)
                    }
                    return lhs.name < rhs.name
                }
                let sectionOpen = landRides.filter {
                    liveMap[$0.id]?.status.isRideable == true
                }.count
                return LandSection(land: land, rides: sorted, openCount: sectionOpen)
            }
            .sorted { lhs, rhs in
                if lhs.land == "Other" { return false }
                if rhs.land == "Other" { return true }
                return lhs.land < rhs.land
            }
    }

    // MARK: - Favorites helpers

    private func toggleFavorite(for ride: Ride) {
        AppHaptic.selection()
        withAnimation(AppMotion.quick) {
            if favoriteIds.contains(ride.id) {
                favoriteIds.remove(ride.id)
                showToast("Removed from Favorites")
            } else {
                favoriteIds.insert(ride.id)
                showToast("Added to Favorites")
            }
        }
        saveFavorites()
    }

    private func saveFavorites() {
        let key = "favorites_\(park.rawValue)"
        if let data = try? JSONEncoder().encode(favoriteIds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Recently viewed helpers

    private func recordRecentlyViewed(_ ride: Ride) {
        var ids = recentlyViewedIds
        ids.removeAll { $0 == ride.id }
        ids.insert(ride.id, at: 0)
        if ids.count > 10 { ids = Array(ids.prefix(10)) }
        recentlyViewedIds = ids
        saveRecentlyViewed()
    }

    private func saveRecentlyViewed() {
        let key = "recentlyViewed_\(park.rawValue)"
        if let data = try? JSONEncoder().encode(recentlyViewedIds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Empty state helpers (cheap — no ViewModel access)

    private var emptyTitle: String {
        if !searchText.isEmpty { return "No results" }
        if openOnly && categoryFilter != .all { return "No open \(categoryFilter.rawValue.lowercased())" }
        if openOnly             { return "No open attractions" }
        if categoryFilter != .all { return "No \(categoryFilter.rawValue.lowercased()) listed" }
        return "No attractions"
    }

    private var emptySubtitle: String {
        let hasSearch = !searchText.isEmpty
        if hasSearch && openOnly {
            return "No open attractions match \"\(searchText)\". Try clearing the search or filters."
        }
        if hasSearch {
            return "No attractions match \"\(searchText)\". Check the spelling or try a different term."
        }
        if openOnly {
            return "Remove the Open Only filter to see all attractions."
        }
        if categoryFilter != .all {
            return "Switch the category to All to see every attraction."
        }
        return "Attraction data is not available right now. Pull to refresh."
    }

    // MARK: - Body

    var body: some View {
        // Build snapshot once.  liveMap construction reads waitTimeVM.normalizedLiveIndex
        // (tracked) via fastLiveState — registers it as a dependency so the view
        // re-renders automatically when the ViewModel receives fresh fetch data.
        let snap = makeSnapshot()

        // Determine whether anything at all is renderable
        let hasContent: Bool = {
            if sort == .byLand {
                return !snap.sections.isEmpty
                    || !snap.favoriteRides.isEmpty
                    || !snap.recentlyViewedRides.isEmpty
            } else {
                return !snap.rides.isEmpty
                    || !snap.favoriteRides.isEmpty
                    || !snap.recentlyViewedRides.isEmpty
            }
        }()

        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar

                filterChipStrip(openCount: snap.openCount)
                    .padding(.horizontal, AppSpacing.screenEdge)
                    .padding(.vertical, AppSpacing.sm)

                Divider()

                Group {
                    if !hasContent {
                        emptyState
                    } else if sort == .byLand {
                        landGroupedList(snap: snap)
                    } else {
                        rideList(snap: snap)
                    }
                }
            }
        }
        // ── Toast overlay ─────────────────────────────────────────────────────
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.textPrimary.opacity(0.88), in: Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .padding(.bottom, AppSpacing.xxl)
            }
        }
        .animation(AppMotion.standard, value: toastMessage)
        .navigationTitle("All Attractions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { sortMenu }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(AppColor.textTertiary)

            TextField("Search attractions", text: $searchText)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
                .tint(park.accentColor)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { searchFocused = false }

            if !searchText.isEmpty {
                Button {
                    searchText    = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppColor.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 9)
        .background(AppColor.skeleton.opacity(0.55), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
        .animation(AppMotion.quick, value: searchText.isEmpty)
    }

    // MARK: - Filter chip strip

    private func filterChipStrip(openCount: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {

            // Row 1: open count + open-only toggle
            HStack(spacing: AppSpacing.sm) {
                Text("\(openCount) of \(rides.count) open")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .monospacedDigit()

                Spacer()

                Button {
                    withAnimation(AppMotion.quick) { openOnly.toggle() }
                    AppHaptic.selection()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: openOnly ? "checkmark.circle.fill" : "circle")
                            .font(.caption.weight(.semibold))
                        Text("Open only")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(openOnly ? .white : park.accentColor)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(openOnly ? park.accentColor : park.accentColor.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(AppMotion.quick, value: openOnly)
            }

            // Row 2: category selector chips (All / Rides / Shows / Characters)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(AttractionCategoryFilter.allCases) { cat in
                        let selected = categoryFilter == cat
                        Button {
                            withAnimation(AppMotion.quick) { categoryFilter = cat }
                            AppHaptic.selection()
                        } label: {
                            HStack(spacing: AppSpacing.xxs) {
                                Image(systemName: cat.systemImage)
                                    .font(.system(size: 10, weight: .bold))
                                Text(cat.rawValue)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(selected ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xxs + 2)
                            .background(
                                selected
                                    ? park.accentColor
                                    : AppColor.skeleton.opacity(0.55)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .animation(AppMotion.quick, value: selected)
                    }
                }
            }
        }
    }

    // MARK: - Sort menu

    private var sortMenu: some View {
        Menu {
            ForEach(AttractionSort.allCases) { option in
                Button {
                    withAnimation(AppMotion.quick) { sort = option }
                } label: {
                    Label(
                        option.rawValue,
                        systemImage: sort == option ? "checkmark" : option.systemImage
                    )
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(park.accentColor)
        }
    }

    // MARK: - Flat ride list
    //
    // Renders up to three stacked cards:
    //   1. Favorites  — present when favoriteRides is non-empty
    //   2. Recently Viewed — present when recentlyViewedRides is non-empty
    //   3. Main list  — all non-favorite, filtered+sorted rides

    private func rideList(snap: RenderSnapshot) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.md) {

                // ── Favorites card ─────────────────────────────────────────
                if !snap.favoriteRides.isEmpty {
                    rideCard(
                        headerTitle: "Favorites",
                        headerIcon:  "star.fill",
                        headerColor: Color.yellow,
                        rides:       snap.favoriteRides,
                        snap:        snap
                    )
                }

                // ── Recently Viewed card ───────────────────────────────────
                if !snap.recentlyViewedRides.isEmpty {
                    rideCard(
                        headerTitle: "Recently Viewed",
                        headerIcon:  "clock.arrow.circlepath",
                        headerColor: AppColor.textSecondary,
                        rides:       snap.recentlyViewedRides,
                        snap:        snap
                    )
                }

                // ── Main list card ─────────────────────────────────────────
                if !snap.rides.isEmpty {
                    rideCard(
                        headerTitle: nil,
                        headerIcon:  nil,
                        headerColor: nil,
                        rides:       snap.rides,
                        snap:        snap
                    )
                }
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await waitTimeVM.refresh() }
    }

    // MARK: - Ride card (shared by flat list sections)
    //
    // Renders a rounded card with an optional labeled header row followed by
    // AttractionRows separated by indented dividers.
    // Used for Favorites, Recently Viewed, and the unsectioned main list.

    @ViewBuilder
    private func rideCard(
        headerTitle: String?,
        headerIcon:  String?,
        headerColor: Color?,
        rides:       [Ride],
        snap:        RenderSnapshot
    ) -> some View {
        VStack(spacing: 0) {

            // Optional section header inside the card
            if let title = headerTitle,
               let icon  = headerIcon,
               let color = headerColor {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text("\(rides.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

                Divider()
            }

            ForEach(Array(rides.enumerated()), id: \.element.id) { idx, ride in
                AttractionRow(
                    ride:             ride,
                    liveState:        snap.liveMap[ride.id],
                    isPlanned:        snap.plannedIds.contains(ride.id),
                    isFavorite:       snap.favoriteIds.contains(ride.id),
                    onToggleMyDay:    { toggleMyDay(for: ride) },
                    onToggleFavorite: { toggleFavorite(for: ride) },
                    onTap:            { recordRecentlyViewed(ride) }
                )

                if idx < rides.count - 1 {
                    Divider()
                        .padding(.leading, 88)
                }
            }
        }
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Land grouped list
    //
    // Layout order:
    //   1. Favorites section  (sticky header)
    //   2. Recently Viewed section (sticky header)
    //   3. Land sections — non-favorite rides only (sticky headers)
    //
    // LazyVStack(pinnedViews: [.sectionHeaders]) makes each land header stick
    // to the top of the scroll view while that land's rows are on screen.
    // Header backgrounds must be opaque (AppColor.background) so rows beneath
    // don't bleed through during the stick phase.

    private func landGroupedList(snap: RenderSnapshot) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.md, pinnedViews: [.sectionHeaders]) {

                // ── Favorites section ──────────────────────────────────────
                if !snap.favoriteRides.isEmpty {
                    Section {
                        rideCard(
                            headerTitle: nil,
                            headerIcon:  nil,
                            headerColor: nil,
                            rides:       snap.favoriteRides,
                            snap:        snap
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                    } header: {
                        AttractionSectionHeader(
                            title:       "Favorites",
                            systemImage: "star.fill",
                            color:       Color.yellow,
                            count:       snap.favoriteRides.count
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.background)
                    }
                }

                // ── Recently Viewed section ────────────────────────────────
                if !snap.recentlyViewedRides.isEmpty {
                    Section {
                        rideCard(
                            headerTitle: nil,
                            headerIcon:  nil,
                            headerColor: nil,
                            rides:       snap.recentlyViewedRides,
                            snap:        snap
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                    } header: {
                        AttractionSectionHeader(
                            title:       "Recently Viewed",
                            systemImage: "clock.arrow.circlepath",
                            color:       AppColor.textSecondary,
                            count:       snap.recentlyViewedRides.count
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.background)
                    }
                }

                // ── Land sections (non-favorites) ──────────────────────────
                ForEach(snap.sections) { section in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(
                                Array(section.rides.enumerated()),
                                id: \.element.id
                            ) { idx, ride in
                                AttractionRow(
                                    ride:             ride,
                                    liveState:        snap.liveMap[ride.id],
                                    isPlanned:        snap.plannedIds.contains(ride.id),
                                    isFavorite:       snap.favoriteIds.contains(ride.id),
                                    onToggleMyDay:    { toggleMyDay(for: ride) },
                                    onToggleFavorite: { toggleFavorite(for: ride) },
                                    onTap:            { recordRecentlyViewed(ride) }
                                )

                                if idx < section.rides.count - 1 {
                                    Divider()
                                        .padding(.leading, 88)
                                }
                            }
                        }
                        .background(AppColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, AppSpacing.screenEdge)

                    } header: {
                        LandSectionHeaderView(
                            land:       section.land,
                            openCount:  section.openCount,
                            totalCount: section.rides.count
                        )
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.background)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await waitTimeVM.refresh() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: searchText.isEmpty ? "ticket.fill" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(park.accentColor.opacity(0.25))

            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(AppColor.textSecondary)

            Text(emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(AppColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.top, AppSpacing.xxxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - My Day toggle

    private func toggleMyDay(for ride: Ride) {
        AppHaptic.medium()
        if myDayStore.containsRide(ride.id) {
            if let item = myDayStore.items.first(where: { $0.rideId == ride.id }) {
                myDayStore.remove(item)
                showToast("Removed from My Day")
            }
        } else {
            myDayStore.addRide(
                rideId: ride.id,
                name:   ride.name,
                land:   ride.land.isEmpty ? nil : ride.land,
                parkId: park.backendId
            )
            showToast("Added to My Day")
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            toastMessage = nil
        }
    }
}

// MARK: - AttractionSectionHeader
//
// Sticky header used for Favorites and Recently Viewed sections in byLand mode.
// Mirrors the visual style of LandSectionHeaderView but accepts an icon + color.

private struct AttractionSectionHeader: View {
    let title:       String
    let systemImage: String
    let color:       Color
    let count:       Int

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textTertiary)
                .monospacedDigit()
        }
    }
}

// MARK: - Land section header

private struct LandSectionHeaderView: View {
    let land:       String
    let openCount:  Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(land)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Group {
                if openCount == 0 {
                    Text("All closed")
                        .foregroundStyle(AppColor.textTertiary)
                } else if openCount == totalCount {
                    Text("All open")
                        .foregroundStyle(AppColor.success)
                } else {
                    Text("\(openCount) open")
                        .foregroundStyle(AppColor.success)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(
                openCount > 0
                    ? AppColor.success.opacity(0.12)
                    : AppColor.skeleton.opacity(0.6)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - AttractionRow

private struct AttractionRow: View {

    let ride:             Ride
    let liveState:        LiveRideState?
    let isPlanned:        Bool
    let isFavorite:       Bool
    let onToggleMyDay:    () -> Void
    let onToggleFavorite: () -> Void
    let onTap:            () -> Void

    @State private var showDetail = false

    // ── Derived (cheap — all inputs pre-computed by parent) ───────────────────

    /// Type looked up from the static RideMasterData index — O(1), no allocation.
    private var attractionType: AttractionType {
        RideMasterData.typeByStableID[ride.id] ?? .ride
    }

    private var isOpen: Bool {
        liveState?.status.isRideable ?? false
    }

    private var waitText: String {
        guard let live = liveState else {
            // No live state: show a friendly message based on type instead of "—".
            switch attractionType {
            case .characterMeet: return "Times vary"
            case .show:          return "Schedule"
            case .quickService, .snackStand, .tableService, .lounge, .festivalBooth:
                return RideMasterData.diningByStableID[ride.id]?.priceTier.displayString ?? "$"
            default:             return "—"
            }
        }
        if live.status.isRideable {
            guard let mins = live.waitMinutes else {
                // Live data confirms the attraction is open but no wait is posted.
                // Shows/meets use type-aware copy; rides fall through to "Open".
                switch attractionType {
                case .characterMeet: return "Times vary"
                case .show:          return "Schedule"
                default:             return "Open"
                }
            }
            return mins == 0 ? "Walk-on" : "\(mins) min"
        }
        return live.status.shortLabel
    }

    private var waitColor: Color {
        guard let live = liveState else {
            // Dining venues show price-tier text in gold — distinct from the
            // "closed" grey used for attractions with no live data yet.
            if attractionType.isDining { return AppColor.brandGoldDeep }
            return AppColor.textTertiary
        }
        if live.status.isRideable {
            guard let mins = live.waitMinutes else { return AppColor.success }
            return AppColor.waitColor(minutes: mins)
        }
        return AppColor.textTertiary
    }

    private var showTrend: Bool {
        guard let live = liveState else { return false }
        return live.status.isRideable && live.trend != .unknown && live.trend != .stable
    }

    // MARK: - Body

    var body: some View {
        Button {
            onTap()
            showDetail = true
            AppHaptic.light()
        } label: {
            HStack(spacing: 0) {

                // ── Wait badge column (fixed 72 pt) ───────────────────────
                VStack(spacing: 2) {
                    Text(waitText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(waitColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if showTrend, let live = liveState {
                        Image(systemName: live.trend.systemImage)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(
                                live.trend == .rising ? AppColor.error : AppColor.success
                            )
                    }
                }
                .frame(width: 72, alignment: .center)

                // ── Hairline column separator ─────────────────────────────
                Rectangle()
                    .fill(AppColor.skeleton.opacity(0.6))
                    .frame(width: 0.5, height: 36)
                    .padding(.trailing, AppSpacing.md)

                // ── Ride name + land ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(ride.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                isOpen ? AppColor.textPrimary : AppColor.textTertiary
                            )
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if liveState?.lightningLaneAvailable == true {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColor.brandGold)
                        }
                    }

                    Text(ride.land)
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.sm)

                // ── Right accessory: favorite star + My Day + chevron ─────
                HStack(spacing: AppSpacing.xs) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    }
                    if isPlanned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppColor.success)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .padding(.trailing, AppSpacing.screenEdge)
            }
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // ── Favorites ─────────────────────────────────────────────────
            Section {
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorite ? "star.slash.fill" : "star.fill"
                    )
                }
            }
            // ── My Day ────────────────────────────────────────────────────
            Section {
                if isPlanned {
                    Button(role: .destructive) {
                        onToggleMyDay()
                    } label: {
                        Label("Remove from My Day", systemImage: "minus.circle")
                    }
                } else {
                    Button {
                        onToggleMyDay()
                    } label: {
                        Label("Add to My Day", systemImage: "plus.circle.fill")
                    }
                }
            }
            // ── Details ───────────────────────────────────────────────────
            Section {
                Button {
                    showDetail = true
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - RideStatus short label (file-private)

private extension RideStatus {
    var shortLabel: String {
        switch self {
        case .operating:     return "Open"
        case .down:          return "Down"
        case .closed:        return "Closed"
        case .refurbishment: return "Refurb"
        case .unknown:       return "—"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Attractions list") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        AttractionsListView(park: .magicKingdom)
            .environment(WaitTimeViewModel(container: container))
            .environment(MyDayStore())
            .environment(DiningRatingStore())
            .modelContainer(container)
    }
}
#endif

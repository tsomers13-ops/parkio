// MyDayView.swift — Flexible park-day planning checklist with time-grouped sections.
//
// Feature overview:
//   • Four collapsible sections: Morning / Afternoon / Evening / Anytime
//   • Optional time slots per item — displayed as "9:30 AM" in rows
//   • Swipe-to-delete on any row
//   • Toggle checked / unchecked with checkmark animation
//   • Toolbar: Filter menu (funnel icon)  +  Sort menu (↑↓ icon)  +  Add (+)
//   • Contextual filter-empty state when a filter hides all items (separate from true-empty)
//   • Stats row: x remaining, y done
//   • "Show on Map" action for ride/show/character items with a map pin — switches to Map
//   • Long-press row to set / change / remove the scheduled time
//
// Sort modes (Anytime section only):
//   Smart — rides first, open before closed/down, shorter waits before longer.
//   Wait  — rides sorted by live wait time ascending (nil data → end); non-rides after.
//   A–Z   — all items sorted alphabetically by title.
//   Timed sections are unaffected — their time-based order is the user's explicit intent.
//
// Smart mode education layer:
//   • First-time inline explanation card (SmartExplanationCard) — shown once,
//     dismissed permanently via @AppStorage("hasSeenSmartExplanation").
//   • Subtle reinforcement line — "Optimized for your next ride" — visible whenever
//     Smart sort is active. Fades in/out with .transition(.opacity).
//   • Empty state updated to surface Smart mode as a value prop.
//
// Add Item sheet pickers:
//   • Ride      — RidePickerView (SwiftData @Query, seeded rides only)
//   • Show      — MasterAttractionPickerView filtered by .show
//   • Character — MasterAttractionPickerView filtered by .characterMeet
//   • All other types (Food, Shopping, Note, Custom) — free-form text fields
//
// Data: @Environment(MyDayStore.self) — injected once at app root.
// Navigation: @Environment(AppNavigationCoordinator.self) — for map handoff.

import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Filter

private enum MyDayFilter: String, CaseIterable {
    case all       = "All"
    case remaining = "Remaining"
    case completed = "Completed"

    /// Per-item icon shown in the filter menu (replaced by "checkmark" when selected).
    var systemImage: String {
        switch self {
        case .all:       return "list.bullet"
        case .remaining: return "circle"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - SortMode

private enum SortMode: String, CaseIterable, Identifiable {
    case smart = "Smart"
    case wait  = "Wait Time"
    case az    = "A–Z"

    var id: String { rawValue }

    /// Per-item icon shown in the sort menu (replaced by "checkmark" when selected).
    var systemImage: String {
        switch self {
        case .smart: return "sparkles"
        case .wait:  return "clock"
        case .az:    return "textformat.abc"
        }
    }
}

// MARK: - MyDayView

struct MyDayView: View {

    @Binding var selectedPark: Park

    @Environment(MyDayStore.self)                private var store
    @Environment(WaitTimeViewModel.self)         private var waitTimeVM
    @Environment(AppNavigationCoordinator.self)  private var coordinator
    @Environment(\.modelContext)                 private var modelContext

    @State private var filter:            MyDayFilter    = .all
    @State private var sortMode:          SortMode       = .smart
    @State private var isAddingItem:      Bool           = false
    @State private var editingTimeItem:   MyDayItem?     = nil
    @State private var collapsedSections: Set<MyDaySection> = []

    /// Persisted flag: user has read and dismissed the Smart explanation card.
    /// Stored in UserDefaults so it survives app restarts.
    @AppStorage("hasSeenSmartExplanation") private var hasSeenSmartExplanation: Bool = false

    /// All rides in the SwiftData store — used to resolve MyDayItem.rideId → Ride
    /// so that liveState(matching: Ride) can be used instead of liveState(for: String).
    @Query private var allRides: [Ride]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                if store.items.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("My Day")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isAddingItem) {
                AddMyDayItemSheet(park: selectedPark) { item in
                    withAnimation(AppMotion.standard) { store.add(item) }
                    AppHaptic.light()
                }
            }
            // Long-press time picker sheet.
            .sheet(item: $editingTimeItem) { item in
                TimePickerSheet(item: item) { newTime in
                    store.setScheduledTime(newTime, for: item)
                }
            }
        }
    }

    // MARK: - List content

    /// True when the current filter hides every item even though the store is non-empty.
    /// Drives the filter-empty state — distinct from the true-empty state shown when
    /// store.items is itself empty.
    private var isFilterEmpty: Bool {
        guard !store.items.isEmpty else { return false }
        return store.items.allSatisfy { !filterMatches($0) }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            // ── Stats + clear row ──────────────────────────────────────────────
            statsRow
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

            // ── Smart reinforcement text ───────────────────────────────────────
            // Visible whenever Smart sort is active. Fades in/out as the user
            // switches sort modes. No background — intentionally minimal.
            if sortMode == .smart {
                Text("Optimized for your next ride")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .padding(.bottom, AppSpacing.sm)
                    .transition(.opacity)
            }

            // ── First-time Smart explanation card ──────────────────────────────
            // Shown once when Smart sort is active and the user has not yet
            // acknowledged it. Animated in from the top; dismissed permanently.
            if sortMode == .smart && !hasSeenSmartExplanation {
                SmartExplanationCard {
                    withAnimation(AppMotion.standard) {
                        hasSeenSmartExplanation = true
                    }
                    AppHaptic.light()
                }
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Grouped sections  OR  filter-empty state ───────────────────────
            if isFilterEmpty {
                filterEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(MyDaySection.allCases, id: \.self) { section in
                        sectionContent(for: section)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .animation(AppMotion.standard, value: sortMode)
        .animation(AppMotion.standard, value: hasSeenSmartExplanation)
    }

    // MARK: - Section builder

    @ViewBuilder
    private func sectionContent(for section: MyDaySection) -> some View {
        let sectionItems = items(for: section)
        if !sectionItems.isEmpty {
            // Identify the top smart-sort pick: first unchecked ride in the
            // Anytime section while smart sort is active. UUID comparison is
            // O(1) and avoids any string parsing at render time.
            let topPickId: UUID? = (sortMode == .smart && section == .anytime)
                ? sectionItems.first(where: { $0.type == .ride && !$0.isChecked })?.id
                : nil

            Section {
                if !collapsedSections.contains(section) {
                    ForEach(sectionItems) { item in
                        MyDayItemRow(
                            item:        item,
                            matchedRide: matchedRide(for: item),
                            isTopPick:   item.id == topPickId,
                            onToggle:    { withAnimation(AppMotion.quick) { handleToggle(item: item) }; AppHaptic.light() },
                            onSetTime:   { editingTimeItem = item },
                            onShowOnMap: item.rideId != nil && isItemMapVisible(item)
                                ? { showOnMap(item: item) }
                                : nil
                        )
                        .environment(waitTimeVM)
                        // ── Leading swipe: Done / Undo ─────────────────────────
                        // allowsFullSwipe: true so a full swipe completes or un-
                        // completes the item without having to reveal the button.
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation(AppMotion.quick) { handleToggle(item: item) }
                                AppHaptic.light()
                            } label: {
                                if item.isChecked {
                                    Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                                } else {
                                    Label("Done", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .tint(item.isChecked ? Color.accentColor : .green)
                        }
                        // ── Trailing swipe: Delete + Set Time ──────────────────
                        // allowsFullSwipe: false on the trailing edge so Delete
                        // cannot be triggered by accident with a careless full swipe.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Delete — destructive role applies the system red tint
                            // and positions it as the outermost trailing action.
                            Button(role: .destructive) {
                                withAnimation(AppMotion.standard) { handleDelete(item: item) }
                                AppHaptic.light()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            // Set Time — opens the same sheet as the context menu.
                            Button {
                                editingTimeItem = item
                                AppHaptic.selection()
                            } label: {
                                Label(
                                    item.scheduledTime == nil ? "Set Time" : "Change Time",
                                    systemImage: "clock"
                                )
                            }
                            .tint(Color.accentColor)
                        }
                        .listRowInsets(
                            EdgeInsets(top: 4, leading: AppSpacing.screenEdge,
                                       bottom: 4, trailing: AppSpacing.screenEdge)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    // .onDelete keeps edit-mode delete (red minus circles) working
                    // even though trailing swipe is now handled by .swipeActions above.
                    .onDelete(perform: { offsets in
                        deleteFromSection(offsets: offsets, sectionItems: sectionItems)
                    })
                }
            } header: {
                SectionHeaderView(
                    section:     section,
                    itemCount:   sectionItems.count,
                    isCollapsed: collapsedSections.contains(section)
                ) {
                    toggleSection(section)
                }
                // Override the default list section header background.
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
    }

    // MARK: - Filtered + sorted items per section

    private func items(for section: MyDaySection) -> [MyDayItem] {
        let filtered = store.items.filter { $0.section == section && filterMatches($0) }

        if section != .anytime {
            // Timed sections — primary sort is always the user's scheduled time.
            // Sort modes are not applied here: an explicit time slot is the user's
            // own intent and overriding it would break morning/afternoon/evening plans.
            return filtered.sorted {
                guard let a = $0.scheduledTime, let b = $1.scheduledTime else {
                    return $0.scheduledTime != nil // timed items bubble up
                }
                return a < b
            }
        }

        // Anytime — apply selected sort mode.
        switch sortMode {
        case .smart: return applySmartSort(to: filtered)
        case .wait:  return applyWaitSort(to: filtered)
        case .az:    return applyAlphaSort(to: filtered)
        }
    }

    // MARK: - Ride resolution

    /// Resolves a MyDayItem to its SwiftData Ride by matching rideId.
    /// Returns nil for non-ride items or when the ride is not yet seeded.
    /// Used to pass a typed Ride to liveState(matching:) rather than the
    /// unreliable string-based liveState(for: rideId) lookup.
    private func matchedRide(for item: MyDayItem) -> Ride? {
        guard let rideId = item.rideId else { return nil }
        return allRides.first { $0.id == rideId }
    }

    /// True when the item has a rideId that maps to a map-visible attraction
    /// (shouldAppearOnMap == true). Governs whether "Show on Map" is offered.
    ///
    /// • Ride items   — all have a mapPriority → button shown.
    /// • Show items   — only those with a map pin (e.g. Monsters, Inc. Laugh Floor).
    /// • Character items — all have mapPriority == nil → button hidden.
    /// • Free-form items — rideId is nil → caller's nil-guard already blocks this.
    private func isItemMapVisible(_ item: MyDayItem) -> Bool {
        guard let rideId = item.rideId else { return false }
        return RideMasterData.all.first { $0.stableID == rideId }?.shouldAppearOnMap == true
    }

    /// Reorders the Anytime section: rides first (open → short wait → no data → closed/down),
    /// non-rides appended after in original insertion order.
    private func applySmartSort(to items: [MyDayItem]) -> [MyDayItem] {
        let rideItems  = items.filter { $0.type == .ride }
        let otherItems = items.filter { $0.type != .ride }

        let sortedRides = rideItems.sorted { lhs, rhs in
            // Resolve via Ride model so liveState(matching:) can use name-based
            // alias matching rather than the unreliable rideId string lookup.
            let lState = matchedRide(for: lhs).flatMap { waitTimeVM.liveState(matching: $0) }
            let rState = matchedRide(for: rhs).flatMap { waitTimeVM.liveState(matching: $0) }

            // Open (rideable) rides before closed / down rides.
            let lOpen = lState?.status.isRideable == true
            let rOpen = rState?.status.isRideable == true
            if lOpen != rOpen { return lOpen }

            // Among open rides: shorter wait first.
            // Nil wait (no data yet) treated as 999 — sorts after any known wait.
            let lWait = lState?.waitMinutes ?? 999
            let rWait = rState?.waitMinutes ?? 999
            return lWait < rWait
        }

        return sortedRides + otherItems
    }

    /// Reorders by live wait time ascending. Rides with no data sort after known
    /// waits; non-ride items always appear after the ride block.
    private func applyWaitSort(to items: [MyDayItem]) -> [MyDayItem] {
        let rideItems  = items.filter { $0.type == .ride }
        let otherItems = items.filter { $0.type != .ride }

        let sortedRides = rideItems.sorted { lhs, rhs in
            let lWait = matchedRide(for: lhs)
                .flatMap { waitTimeVM.liveState(matching: $0)?.waitMinutes } ?? 999
            let rWait = matchedRide(for: rhs)
                .flatMap { waitTimeVM.liveState(matching: $0)?.waitMinutes } ?? 999
            return lWait < rWait
        }

        return sortedRides + otherItems
    }

    /// Reorders all items in the Anytime section alphabetically by title.
    private func applyAlphaSort(to items: [MyDayItem]) -> [MyDayItem] {
        items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private func filterMatches(_ item: MyDayItem) -> Bool {
        switch filter {
        case .all:       return true
        case .remaining: return !item.isChecked
        case .completed: return item.isChecked
        }
    }

    // MARK: - Section collapse

    private func toggleSection(_ section: MyDaySection) {
        withAnimation(AppMotion.standard) {
            if collapsedSections.contains(section) {
                collapsedSections.remove(section)
            } else {
                collapsedSections.insert(section)
            }
        }
        AppHaptic.selection()
    }

    // MARK: - Map handoff

    private func showOnMap(item: MyDayItem) {
        guard let rideId = item.rideId else { return }
        coordinator.showOnMap(rideId: rideId)
        AppHaptic.light()
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack {
            HStack(spacing: AppSpacing.sm) {
                statBubble(count: store.remainingCount,
                           label: "remaining",
                           color: AppColor.textPrimary)
                statBubble(count: store.completedCount,
                           label: "done",
                           color: AppColor.success)
            }
            Spacer()
            if store.completedCount > 0 {
                Button {
                    withAnimation(AppMotion.standard) { store.clearCompleted() }
                    AppHaptic.light()
                } label: {
                    Text("Clear done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func statBubble(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundStyle(count == 0 ? AppColor.textTertiary : color)
                .contentTransition(.numericText())
                .animation(AppMotion.standard, value: count)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Filter-empty state

    /// Shown when the store has items but the active filter hides all of them.
    /// Gives the user a clear explanation and a one-tap escape back to "All".
    private var filterEmptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: filter == .remaining ? "checkmark.circle" : "circle.dashed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.35))

            VStack(spacing: AppSpacing.xs) {
                Text(filter == .remaining ? "All done for now 🎉" : "Nothing checked off yet")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.textPrimary)

                Text(filter == .remaining
                     ? "Every item on your list is completed."
                     : "Tap the circle on any item to mark it done.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            Button {
                withAnimation(AppMotion.standard) { filter = .all }
                AppHaptic.selection()
            } label: {
                Text("Show All")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 9)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .transition(.opacity)
        .animation(AppMotion.standard, value: filter)
    }

    // MARK: - Empty state

    /// Shown when the store has no items at all.
    /// Surfaces Smart mode as a value prop alongside the add CTA.
    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.4))

            VStack(spacing: AppSpacing.sm) {
                Text("Build your day")
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)

                VStack(spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                        Text("Add rides and turn on Smart mode")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Text("to get real-time recommendations.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
            }

            Button {
                isAddingItem = true
            } label: {
                Label("Add Your First Item", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Declaration order = left-to-right in the trailing area.
        // Filter (leftmost) → Sort (middle) → Add (rightmost).
        ToolbarItem(placement: .navigationBarTrailing) { filterMenu }
        ToolbarItem(placement: .navigationBarTrailing) { sortMenu }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isAddingItem = true
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Filter menu

    /// Icon-only filter menu matching the All Attractions sort-menu pattern.
    /// The funnel icon fills when a non-All filter is active to signal state.
    private var filterMenu: some View {
        Menu {
            ForEach(MyDayFilter.allCases, id: \.rawValue) { option in
                Button {
                    withAnimation(AppMotion.standard) { filter = option }
                    AppHaptic.selection()
                } label: {
                    Label(
                        option.rawValue,
                        systemImage: filter == option ? "checkmark" : option.systemImage
                    )
                }
            }
        } label: {
            Label("Filter", systemImage: filter == .all
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Sort menu

    /// Icon-only sort menu — identical visual language to the All Attractions page.
    private var sortMenu: some View {
        Menu {
            ForEach(SortMode.allCases) { mode in
                Button {
                    withAnimation(AppMotion.standard) { sortMode = mode }
                    AppHaptic.selection()
                } label: {
                    Label(
                        mode.rawValue,
                        systemImage: sortMode == mode ? "checkmark" : mode.systemImage
                    )
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - RideLog bridge

    /// Central toggle handler for all My Day checkmarks and swipe-to-complete actions.
    ///
    /// For `.ride` items:
    ///   • Completing  → creates a RideLog in SwiftData (with duplicate guard).
    ///   • Un-completing → removes the RideLog created by this My Day item.
    /// For all other types the store toggle is called without touching SwiftData.
    ///
    /// Call sites must wrap this in `withAnimation` themselves so the animation
    /// context is consistent with the surrounding swipe / button environment.
    private func handleToggle(item: MyDayItem) {
        let wasChecked = item.isChecked     // capture BEFORE mutation
        store.toggle(item)                  // flip isChecked, persist JSON

        guard item.type == .ride else {
            #if DEBUG
            print("ℹ️ [MyDay] toggle '\(item.title)' type=.\(item.type.rawValue) — RideLog skipped (non-ride)")
            #endif
            return
        }

        let itemKey = item.id.uuidString

        if !wasChecked {
            // ── Completing: create a RideLog (duplicate guard first) ───────────
            let existing = fetchRideLogs(myDayItemId: itemKey)
            guard existing.isEmpty else {
                #if DEBUG
                print("⏩ [MyDay] RideLog already exists for '\(item.title)' — duplicate skipped")
                #endif
                return
            }
            guard let ride = matchedRide(for: item) else {
                #if DEBUG
                print("⚠️ [MyDay] Ride not found for rideId='\(item.rideId ?? "nil")' — RideLog not created")
                #endif
                return
            }
            let log = RideLog(date: Date(), ride: ride, myDayItemId: itemKey)
            modelContext.insert(log)
            ride.logs.append(log)
            try? modelContext.save()
            #if DEBUG
            print("✅ [MyDay] RideLog created — '\(ride.name)' \(log.date) [myDayItemId=\(itemKey)]")
            #endif

            // Upsert ParkVisit for the park-local calendar day of the ride.
            if let park = Park(rawValue: ride.park) {
                ParkVisitService.upsertParkVisit(for: park, rideDate: log.date, context: modelContext)
            } else {
                #if DEBUG
                print("⚠️ [MyDay] Unknown park rawValue '\(ride.park)' — ParkVisit skipped")
                #endif
            }

        } else {
            // ── Un-completing: remove the associated RideLog ───────────────────
            let toDelete = fetchRideLogs(myDayItemId: itemKey)
            if toDelete.isEmpty {
                #if DEBUG
                print("ℹ️ [MyDay] No MyDay-sourced RideLog found to remove for '\(item.title)'")
                #endif
            } else {
                // Capture park + date BEFORE deletion so the cleanup check
                // can run against the post-deletion state of the store.
                let deletionTargets: [(park: Park, date: Date)] = toDelete.compactMap { log in
                    guard let ride = log.ride, let park = Park(rawValue: ride.park) else { return nil }
                    return (park, log.date)
                }

                toDelete.forEach { modelContext.delete($0) }
                try? modelContext.save()
                #if DEBUG
                print("🗑️ [MyDay] RideLog removed — '\(item.title)' [myDayItemId=\(itemKey)]")
                #endif

                // Cleanup ParkVisit for each affected park+day (retains if other
                // RideLogs still exist for that park on that park-local day).
                for target in deletionTargets {
                    ParkVisitService.cleanupParkVisitIfNeeded(
                        for:     target.park,
                        rideDate: target.date,
                        context: modelContext
                    )
                }
            }
        }
    }

    /// Fetches all RideLogs whose myDayItemId matches key.
    /// Uses an in-memory filter after a full fetch to avoid SwiftData #Predicate
    /// limitations with optional String comparisons across iOS 17 versions.
    private func fetchRideLogs(myDayItemId key: String) -> [RideLog] {
        let descriptor = FetchDescriptor<RideLog>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.myDayItemId == key }
    }

    // MARK: - Delete

    /// Single delete handler for ALL My Day item removal paths (trailing swipe,
    /// edit-mode .onDelete). Mirrors the cleanup contract of handleToggle:
    ///
    ///   • Ride items that were completed (isChecked == true) will have a linked
    ///     RideLog identified by myDayItemId. That log is deleted first, then
    ///     ParkVisitService.cleanupParkVisitIfNeeded is called so the ParkVisit
    ///     is removed only when no other RideLogs remain for that park+day.
    ///   • Non-ride items and unchecked ride items (no linked RideLog) are
    ///     removed from MyDayStore only — no SwiftData changes needed.
    ///
    /// store.remove(item) is always the final step so the UI update comes after
    /// SwiftData writes are committed.
    private func handleDelete(item: MyDayItem) {
        if item.type == .ride {
            let itemKey    = item.id.uuidString
            let linkedLogs = fetchRideLogs(myDayItemId: itemKey)

            if !linkedLogs.isEmpty {
                // Capture park+date BEFORE deletion so the cleanup check
                // runs against the post-deletion state of the store.
                let deletionTargets: [(park: Park, date: Date)] = linkedLogs.compactMap { log in
                    guard let ride = log.ride,
                          let park = Park(rawValue: ride.park) else { return nil }
                    return (park, log.date)
                }

                linkedLogs.forEach { modelContext.delete($0) }
                try? modelContext.save()

                #if DEBUG
                print("🗑️ [MyDay] Delete — \(linkedLogs.count) RideLog(s) removed for '\(item.title)' [myDayItemId=\(itemKey)]")
                #endif

                for target in deletionTargets {
                    ParkVisitService.cleanupParkVisitIfNeeded(
                        for:      target.park,
                        rideDate: target.date,
                        context:  modelContext
                    )
                }
            } else {
                #if DEBUG
                print("ℹ️ [MyDay] Delete — no linked RideLog for '\(item.title)' (item was not completed)")
                #endif
            }
        }

        // Always remove from MyDayStore regardless of type or completion state.
        store.remove(item)
    }

    private func deleteFromSection(offsets: IndexSet, sectionItems: [MyDayItem]) {
        let toDelete = offsets.map { sectionItems[$0] }
        withAnimation(AppMotion.standard) {
            for item in toDelete { handleDelete(item: item) }
        }
    }
}

// MARK: - SmartExplanationCard

/// One-time inline education card explaining what Smart sort does.
/// Shown above the list when Smart is active and the user has not yet
/// dismissed it. Dismissed permanently via @AppStorage.
///
/// Design: no modal, no alert — inline only. Animates in from the top.
private struct SmartExplanationCard: View {

    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // ── Header ─────────────────────────────────────────────────────────
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Let us guide your day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }

            // ── Body ───────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Smart mode picks what to ride next based on:")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)

                VStack(alignment: .leading, spacing: 5) {
                    SmartBulletRow(label: "Wait time")
                    SmartBulletRow(label: "Distance")
                    SmartBulletRow(label: "Park timing")
                }
            }

            // ── Dismiss CTA ────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }
}

/// A single bullet point row used inside SmartExplanationCard.
private struct SmartBulletRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.accentColor.opacity(0.45))
                .frame(width: 4, height: 4)
            Text(label)
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

// MARK: - SectionHeaderView

private struct SectionHeaderView: View {
    let section:     MyDaySection
    let itemCount:   Int
    let isCollapsed: Bool
    let onTap:       () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                // Section icon + title
                HStack(spacing: 6) {
                    Image(systemName: section.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(section.color)

                    Text(section.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }

                // Time range descriptor
                Text("·")
                    .foregroundStyle(AppColor.textTertiary)
                Text(section.timeRange)
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)

                Spacer()

                // Item count badge
                Text("\(itemCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .monospacedDigit()

                // Collapse chevron
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                    .rotationEffect(isCollapsed ? .degrees(-90) : .zero)
                    .animation(AppMotion.standard, value: isCollapsed)
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, 10)
            .background(AppColor.background)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MyDayItemRow

private struct MyDayItemRow: View {

    let item:        MyDayItem
    /// The SwiftData Ride resolved from item.rideId, or nil for non-ride items /
    /// items whose ride has not yet been seeded. Passed in from MyDayView which
    /// owns the @Query so the lookup is done once per row, not inside the row.
    var matchedRide: Ride?         = nil
    /// True when this row is the top smart-sort pick in the Anytime section.
    /// Defaults to false so all existing call sites compile without change.
    var isTopPick:   Bool          = false
    /// Called when the user taps the checkmark button or triggers the leading swipe.
    /// MyDayView owns this closure and routes it through handleToggle(item:) so that
    /// RideLog creation/deletion is handled alongside the store.toggle() call.
    let onToggle:    () -> Void
    let onSetTime:   () -> Void
    let onShowOnMap: (() -> Void)?

    @Environment(MyDayStore.self)        private var store
    @Environment(WaitTimeViewModel.self) private var waitTimeVM
    @Environment(LocationService.self)   private var locationService

    // MARK: - Live ride state

    /// Full live state for this item, or nil when the item has no matched Ride or
    /// live data has not yet arrived. Non-ride items always return nil.
    ///
    /// Uses liveState(matching: Ride) — name-based alias matching — instead of
    /// the unreliable liveState(for: rideId) string lookup that was missing hits.
    private var liveRideState: LiveRideState? {
        guard item.type == .ride, let ride = matchedRide else { return nil }
        return waitTimeVM.liveState(matching: ride)
    }

    /// Compact (label, color) pair derived from liveRideState.
    /// Covers all rideable and non-rideable states so nothing is silently hidden.
    private var liveStatusInfo: (label: String, color: Color)? {
        guard let state = liveRideState else { return nil }
        if state.status.isRideable {
            if let mins = state.waitMinutes {
                return (mins == 0 ? "Walk-on" : "\(mins) min", state.waitColor)
            }
            return ("Open", AppColor.success)
        }
        // Non-rideable: use the canonical display label from the model.
        // "Down" gets the error color; every other non-rideable state (Closed,
        // Temporarily Closed, etc.) gets the muted tertiary color.
        let label = state.status.displayLabel
        let color: Color = label.localizedCaseInsensitiveCompare("Down") == .orderedSame
            ? AppColor.error
            : AppColor.textTertiary
        return (label, color)
    }

    // MARK: - Reasoning text (top pick only)

    /// Compact dot-separated explanation of why this ride is the current top pick.
    /// Only populated when isTopPick is true and live data is available.
    ///
    /// Token assembly (up to 2 tokens):
    ///   1. Status/wait — derived from liveRideState:
    ///        walk-on (0 min) → "Walk-on"
    ///        1–N min         → "N min"
    ///        open, no data   → "Open"
    ///        not rideable    → displayLabel (e.g. "Closed", "Down")
    ///   2. Nearby — added when the user's GPS fix puts them within 400 m:
    ///        < 400 m         → "Nearby"
    ///
    /// The live status chip on the right edge of the row already shows the
    /// raw label ("8 min"). The reasoning line provides the *narrative* context —
    /// "8 min · Nearby" reads as "it's fast and close", which is the actual insight.
    private var reasoningText: String? {
        guard isTopPick else { return nil }

        var tokens: [String] = []

        // Token 1: live status / wait time
        if let state = liveRideState {
            if state.status.isRideable {
                if let mins = state.waitMinutes {
                    tokens.append(mins == 0 ? "Walk-on" : "\(mins) min")
                } else {
                    tokens.append("Open")
                }
            } else {
                tokens.append(state.status.displayLabel)
            }
        }

        // Token 2: nearby — requires a GPS fix and a known map coordinate.
        // MapCoordinateService.shared is a singleton (no environment plumbing needed).
        if let userLoc = locationService.userLocation,
           let rideId  = item.rideId,
           let parkId  = item.parkId,
           let ann     = MapCoordinateService.shared.annotation(forRideId: rideId, parkId: parkId) {
            let dist = userLoc.distance(from: CLLocation(latitude: ann.latitude, longitude: ann.longitude))
            if dist < 400 { tokens.append("Nearby") }
        }

        return tokens.isEmpty ? nil : tokens.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: AppSpacing.md) {

            // ── Type icon ──────────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(item.type.color.opacity(item.isChecked ? 0.06 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.isChecked ? "checkmark" : item.type.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.isChecked ? AppColor.textTertiary : item.type.color)
            }
            .animation(AppMotion.quick, value: item.isChecked)

            // ── Text column ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                // "Best now" badge — smart sort top pick only
                if isTopPick {
                    Label("Best now", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.10), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }

                // Title
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.isChecked
                                     ? AppColor.textTertiary
                                     : AppColor.textPrimary)
                    .strikethrough(item.isChecked, color: AppColor.textTertiary)
                    .lineLimit(2)

                // Reasoning line — top pick only, ride items only
                if let text = reasoningText {
                    Text(text)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                        .lineLimit(1)
                        .transition(.opacity)
                }

                // Subtitle row: type · land · time
                subtitleRow

                // "Show on Map" button (ride items only)
                if let showOnMap = onShowOnMap, !item.isChecked {
                    Button(action: showOnMap) {
                        Label("Show on Map", systemImage: "map")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)

            // ── Live status chip (ride items only) ─────────────────────────────
            if let (label, color) = liveStatusInfo {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.10), in: Capsule())
                    .animation(AppMotion.quick, value: label)
            }

            // ── Check button ───────────────────────────────────────────────────
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isChecked
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AppColor.success : AppColor.textTertiary)
            }
            .buttonStyle(.plain)
            .animation(AppMotion.quick, value: item.isChecked)
        }
        .padding(AppSpacing.md)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        .opacity(item.isChecked ? 0.65 : 1.0)
        .animation(AppMotion.quick, value: item.isChecked)
        .animation(AppMotion.standard, value: isTopPick)
        // Long-press context menu
        .contextMenu {
            // Show on Map — ride items with a map coordinate only.
            if let showOnMap = onShowOnMap, !item.isChecked {
                Button(action: showOnMap) {
                    Label("Show on Map", systemImage: "map")
                }
            }

            Button {
                onSetTime()
            } label: {
                Label(
                    item.scheduledTime == nil ? "Set Time" : "Change Time",
                    systemImage: "clock"
                )
            }

            if item.scheduledTime != nil {
                Button(role: .destructive) {
                    store.setScheduledTime(nil, for: item)
                } label: {
                    Label("Remove Time", systemImage: "clock.badge.xmark")
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleRow: some View {
        HStack(spacing: 4) {
            // Type label
            Text(item.type.label)
                .foregroundStyle(AppColor.textTertiary)

            // Land / location
            if let land = item.land, !land.isEmpty {
                Text("·").foregroundStyle(AppColor.textTertiary)
                Text(land).foregroundStyle(AppColor.textTertiary)
            }

            // Scheduled time
            if let time = item.formattedTime {
                Text("·").foregroundStyle(AppColor.textTertiary)
                Label(time, systemImage: "clock")
                    .foregroundStyle(AppColor.textSecondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

// MARK: - TimePickerSheet

/// Simple sheet for setting or changing an item's scheduled time.
private struct TimePickerSheet: View {

    let item:   MyDayItem
    /// Called with the new time (or nil to clear).
    let onSave: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTime: Date

    init(item: MyDayItem, onSave: @escaping (Date?) -> Void) {
        self.item   = item
        self.onSave = onSave
        // Default to next round hour if no existing time.
        _selectedTime = State(initialValue: item.scheduledTime ?? TimePickerSheet.defaultTime())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                // Item summary
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(item.type.color.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: item.type.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.type.color)
                    }
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)

                Divider()

                // Time picker
                DatePicker(
                    "Scheduled time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .navigationTitle(item.scheduledTime == nil ? "Set Time" : "Change Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedTime)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                // Only show "Remove" when there is an existing time to clear.
                if item.scheduledTime != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            onSave(nil)
                            dismiss()
                        } label: {
                            Label("Remove Time", systemImage: "clock.badge.xmark")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private static func defaultTime() -> Date {
        // Round up to the next half hour from now.
        let cal        = Calendar.current
        let now        = Date()
        var comps      = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute     = comps.minute ?? 0
        comps.minute   = minute < 30 ? 30 : 0
        if minute >= 30 { comps.hour = (comps.hour ?? 0) + 1 }
        comps.second   = 0
        return cal.date(from: comps) ?? now
    }
}

// MARK: - AddMyDayItemSheet

/// Bottom sheet for manually adding any item type to the checklist.
/// When the type is `.ride`, a searchable ride picker replaces the
/// free-form name field so every ride item is linked to a real Ride record.
struct AddMyDayItemSheet: View {

    /// The active park — used to scope the ride list.
    let park:  Park
    /// Called with the new item when the user taps Add.
    let onAdd: (MyDayItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType:      MyDayItemType = .ride
    @State private var title:             String        = ""
    @State private var location:          String        = ""
    @State private var detail:            String        = ""
    @State private var hasScheduledTime:  Bool          = false
    @State private var scheduledTime:     Date          = {
        let cal    = Calendar.current
        let now    = Date()
        var comps  = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = comps.minute ?? 0
        comps.minute  = minute < 30 ? 30 : 0
        if minute >= 30 { comps.hour = (comps.hour ?? 0) + 1 }
        comps.second  = 0
        return cal.date(from: comps) ?? now
    }()
    @State private var selectedRide:        Ride?              = nil
    @State private var showRidePicker:      Bool               = false
    @State private var selectedAttraction:  MasterAttraction?  = nil
    @State private var showAttractionPicker: Bool              = false

    /// The AttractionType to filter MasterAttractionPickerView with.
    /// Only meaningful when selectedType is .show or .character.
    private var attractionFilterType: AttractionType {
        selectedType == .show ? .show : .characterMeet
    }

    private var canAdd: Bool {
        switch selectedType {
        case .ride:               return selectedRide != nil
        case .show, .character:   return selectedAttraction != nil
        default:                  return !title.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                // ── Type picker ──────────────────────────────────────────────
                Section {
                    typePicker
                } header: {
                    Text("What are you adding?")
                }

                // ── Details ──────────────────────────────────────────────────
                Section {
                    if selectedType == .ride {
                        // Searchable ride picker row
                        Button {
                            showRidePicker = true
                        } label: {
                            HStack {
                                Text(selectedRide?.name ?? "Select a ride…")
                                    .foregroundStyle(
                                        selectedRide == nil
                                            ? AppColor.textTertiary
                                            : AppColor.textPrimary
                                    )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Auto-filled land display (read-only)
                        if let land = selectedRide?.land, !land.isEmpty {
                            HStack {
                                Text("Land")
                                    .foregroundStyle(AppColor.textSecondary)
                                Spacer()
                                Text(land)
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }

                        TextField("Notes (optional)", text: $detail)

                    } else if selectedType == .show || selectedType == .character {
                        // Searchable master-attraction picker row
                        Button {
                            showAttractionPicker = true
                        } label: {
                            HStack {
                                Text(selectedAttraction?.name
                                     ?? "Select a \(selectedType == .show ? "show" : "character")…")
                                    .foregroundStyle(
                                        selectedAttraction == nil
                                            ? AppColor.textTertiary
                                            : AppColor.textPrimary
                                    )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Auto-filled land display (read-only)
                        if let land = selectedAttraction?.land, !land.isEmpty {
                            HStack {
                                Text("Land")
                                    .foregroundStyle(AppColor.textSecondary)
                                Spacer()
                                Text(land)
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }

                        TextField("Notes (optional)", text: $detail)

                    } else {
                        TextField(selectedType.titlePlaceholder, text: $title)
                        TextField("Location (optional)", text: $location)
                        TextField("Notes (optional)", text: $detail)
                    }
                } header: {
                    Text("Details")
                }

                // ── Schedule ─────────────────────────────────────────────────
                Section {
                    Toggle("Set a time", isOn: $hasScheduledTime.animation(AppMotion.quick))

                    if hasScheduledTime {
                        DatePicker(
                            "Time",
                            selection: $scheduledTime,
                            displayedComponents: .hourAndMinute
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    Text("Schedule")
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commitAdd() }
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                }
            }
            // Ride picker pushed onto the NavigationStack.
            .navigationDestination(isPresented: $showRidePicker) {
                RidePickerView(park: park) { ride in
                    selectedRide   = ride
                    showRidePicker = false
                }
            }
            // Show / Character picker pushed onto the NavigationStack.
            .navigationDestination(isPresented: $showAttractionPicker) {
                MasterAttractionPickerView(
                    park:       park,
                    filterType: attractionFilterType
                ) { attraction in
                    selectedAttraction   = attraction
                    showAttractionPicker = false
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Clear picker state when the user switches item types.
        .onChange(of: selectedType) { _, _ in
            selectedRide       = nil
            selectedAttraction = nil
            title              = ""
            location           = ""
        }
    }

    // ── Type grid ─────────────────────────────────────────────────────────────

    private var typePicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(MyDayItemType.allCases) { type in
                TypeSelectionButton(
                    type:       type,
                    isSelected: selectedType == type
                ) {
                    withAnimation(AppMotion.quick) { selectedType = type }
                    AppHaptic.selection()
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .listRowBackground(Color.clear)
    }

    // ── Commit ────────────────────────────────────────────────────────────────

    private func commitAdd() {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespaces)

        if selectedType == .ride, let ride = selectedRide {
            // ── Ride path — linked to a SwiftData Ride record ─────────────────
            var item           = MyDayItem(title: ride.name, type: .ride)
            item.rideId        = ride.id
            item.land          = ride.land.isEmpty ? nil : ride.land
            item.parkId        = park.backendId
            item.detail        = trimmedDetail.isEmpty ? nil : trimmedDetail
            item.scheduledTime = hasScheduledTime ? scheduledTime : nil
            onAdd(item)

        } else if (selectedType == .show || selectedType == .character),
                  let attraction = selectedAttraction {
            // ── Show / Character path — linked to a MasterAttraction ──────────
            // rideId stores the stableID so "Show on Map" and coordinate
            // resolution both work for attractions where shouldAppearOnMap == true.
            var item           = MyDayItem(title: attraction.name, type: selectedType)
            item.rideId        = attraction.stableID
            item.land          = attraction.land.isEmpty ? nil : attraction.land
            item.parkId        = park.backendId
            item.detail        = trimmedDetail.isEmpty ? nil : trimmedDetail
            item.scheduledTime = hasScheduledTime ? scheduledTime : nil
            onAdd(item)

        } else {
            // ── Free-form path — Food, Shopping, Note, Custom ─────────────────
            let trimmedTitle    = title.trimmingCharacters(in: .whitespaces)
            let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

            var item              = MyDayItem(title: trimmedTitle, type: selectedType)
            item.land             = trimmedLocation.isEmpty ? nil : trimmedLocation
            item.detail           = trimmedDetail.isEmpty   ? nil : trimmedDetail
            item.scheduledTime    = hasScheduledTime ? scheduledTime : nil
            onAdd(item)
        }

        dismiss()
    }
}

// MARK: - RidePickerView

/// Full-screen searchable ride list scoped to a single park.
/// Grouped by land; sorted alphabetically within each land.
private struct RidePickerView: View {

    let park:     Park
    let onSelect: (Ride) -> Void

    @Query private var allRides: [Ride]
    @State private var searchText = ""

    // All rides for this park, alphabetically sorted.
    private var parkRides: [Ride] {
        allRides
            .filter { $0.park == park.rawValue }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // Filtered by current search query.
    private var filteredRides: [Ride] {
        guard !searchText.isEmpty else { return parkRides }
        let q = searchText.lowercased()
        return parkRides.filter {
            $0.name.lowercased().contains(q) || $0.land.lowercased().contains(q)
        }
    }

    // Rides grouped by land, each group sorted alphabetically.
    private var groupedRides: [(land: String, rides: [Ride])] {
        Dictionary(grouping: filteredRides, by: \.land)
            .map { (land: $0.key, rides: $0.value.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
            .sorted { $0.land.localizedCompare($1.land) == .orderedAscending }
    }

    var body: some View {
        List {
            if groupedRides.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(groupedRides, id: \.land) { group in
                    Section(group.land) {
                        ForEach(group.rides, id: \.id) { ride in
                            Button {
                                AppHaptic.selection()
                                onSelect(ride)
                            } label: {
                                Text(ride.name)
                                    .foregroundStyle(AppColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search \(park.shortName) rides…")
        .navigationTitle("\(park.shortName) Rides")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MasterAttractionPickerView

/// Full-screen searchable list of shows or characters for a single park.
/// Backed by RideMasterData static data (not SwiftData) so it works for
/// attraction types that are not seeded into the ride store.
/// Grouped by land; sorted alphabetically within each land.
private struct MasterAttractionPickerView: View {

    let park:       Park
    /// Filter to apply — must be .show or .characterMeet.
    let filterType: AttractionType
    let onSelect:   (MasterAttraction) -> Void

    @State private var searchText = ""

    private var navigationTitle: String {
        let kind = filterType == .show ? "Shows" : "Characters"
        return "\(park.shortName) \(kind)"
    }

    /// All attractions in this park matching the filter type, alphabetically sorted.
    private var parkAttractions: [MasterAttraction] {
        RideMasterData.all
            .filter { $0.park == park && $0.type == filterType }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Filtered by current search query.
    private var filteredAttractions: [MasterAttraction] {
        guard !searchText.isEmpty else { return parkAttractions }
        let q = searchText.lowercased()
        return parkAttractions.filter {
            $0.name.lowercased().contains(q) || $0.land.lowercased().contains(q)
        }
    }

    /// Attractions grouped by land, each group sorted alphabetically.
    private var grouped: [(land: String, attractions: [MasterAttraction])] {
        Dictionary(grouping: filteredAttractions, by: \.land)
            .map { (land: $0.key,
                    attractions: $0.value.sorted {
                        $0.name.localizedCompare($1.name) == .orderedAscending
                    }) }
            .sorted { $0.land.localizedCompare($1.land) == .orderedAscending }
    }

    var body: some View {
        let kindLabel = filterType == .show ? "shows" : "characters"

        List {
            if grouped.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No \(filterType == .show ? "Shows" : "Characters")",
                    systemImage: filterType == .show ? "theatermasks.fill" : "person.crop.circle.fill",
                    description: Text(
                        "\(park.displayName) doesn't have any \(kindLabel) in the current data."
                    )
                )
            } else if grouped.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(grouped, id: \.land) { group in
                    Section(group.land) {
                        ForEach(group.attractions, id: \.stableID) { attraction in
                            Button {
                                AppHaptic.selection()
                                onSelect(attraction)
                            } label: {
                                Text(attraction.name)
                                    .foregroundStyle(AppColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(
            text: $searchText,
            prompt: "Search \(park.shortName) \(kindLabel)…"
        )
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TypeSelectionButton

private struct TypeSelectionButton: View {
    let type:       MyDayItemType
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : type.color)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ? type.color : type.color.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                Text(type.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .animation(AppMotion.quick, value: isSelected)
    }
}

// MARK: - MyDayItemType title placeholder

extension MyDayItemType {
    var titlePlaceholder: String {
        switch self {
        case .ride:      return "Ride name"
        case .food:      return "Food or restaurant name"
        case .show:      return "Show name"
        case .character: return "Character name"
        case .shopping:  return "Item or store"
        case .note:      return "Note"
        case .custom:    return "What do you want to do?"
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftData

#Preview("My Day — with items") {
    let store = MyDayStore()

    // Morning rides
    var spaceMtn = MyDayItem(title: "Space Mountain", type: .ride,
                             land: "Tomorrowland", parkId: "magic-kingdom",
                             rideId: "mk|space-mountain")
    spaceMtn.scheduledTime = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date())
    store.add(spaceMtn)

    // Afternoon food + show
    var doleWhip = MyDayItem(title: "Dole Whip at Aloha Isle", type: .food,
                              land: "Adventureland")
    doleWhip.scheduledTime = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())
    store.add(doleWhip)

    var parade = MyDayItem(title: "Festival of Fantasy Parade", type: .show)
    parade.scheduledTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())
    store.add(parade)

    // Anytime (no time)
    store.add(MyDayItem(title: "Haunted Mansion", type: .ride,
                        land: "Liberty Square", parkId: "magic-kingdom",
                        rideId: "mk|haunted-mansion"))
    store.add(MyDayItem(title: "Sorcerer hat souvenir", type: .shopping))

    // Completed
    var done = MyDayItem(title: "Big Thunder Mountain", type: .ride, land: "Frontierland")
    done.isChecked = true
    done.scheduledTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
    store.add(done)

    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return MyDayView(selectedPark: .constant(.magicKingdom))
        .environment(store)
        .environment(WaitTimeViewModel(container: container))
        .environment(AppNavigationCoordinator())
        .environment(LocationService())
        .modelContainer(container)
}

#Preview("My Day — empty") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return MyDayView(selectedPark: .constant(.magicKingdom))
        .environment(MyDayStore())
        .environment(WaitTimeViewModel(container: container))
        .environment(AppNavigationCoordinator())
        .environment(LocationService())
        .modelContainer(container)
}

#Preview("Add item sheet") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return AddMyDayItemSheet(park: .magicKingdom) { _ in }
        .modelContainer(container)
}
#endif

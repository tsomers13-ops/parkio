// MyDayView.swift — Flexible park-day planning checklist with time-grouped sections.
//
// Feature overview:
//   • Four collapsible sections: Morning / Afternoon / Evening / Anytime
//   • Optional time slots per item — displayed as "9:30 AM" in rows
//   • Drag-to-reorder within the Anytime section (active only when filter = All)
//   • Swipe-to-delete on any row
//   • Toggle checked / unchecked with checkmark animation
//   • Filter bar: All / Remaining / Completed
//   • Stats row: x remaining, y done
//   • "Show on Map" action for ride items — switches to Map tab + selects ride
//   • Long-press row to set / change / remove the scheduled time
//
// Data: @Environment(MyDayStore.self) — injected once at app root.
// Navigation: @Environment(AppNavigationCoordinator.self) — for map handoff.

import SwiftUI

// MARK: - Filter

private enum MyDayFilter: String, CaseIterable {
    case all       = "All"
    case remaining = "Remaining"
    case completed = "Completed"
}

// MARK: - MyDayView

struct MyDayView: View {

    @Environment(MyDayStore.self)                private var store
    @Environment(WaitTimeViewModel.self)         private var waitTimeVM
    @Environment(AppNavigationCoordinator.self)  private var coordinator

    @State private var filter:            MyDayFilter    = .all
    @State private var isAddingItem:      Bool           = false
    @State private var editingTimeItem:   MyDayItem?     = nil
    @State private var collapsedSections: Set<MyDaySection> = []

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
                AddMyDayItemSheet { item in
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

    private var listContent: some View {
        VStack(spacing: 0) {
            // ── Filter picker ──────────────────────────────────────────────────
            filterBar
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

            // ── Stats + clear row ──────────────────────────────────────────────
            statsRow
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.bottom, AppSpacing.sm)

            // ── Grouped sections ───────────────────────────────────────────────
            List {
                ForEach(MyDaySection.allCases, id: \.self) { section in
                    sectionContent(for: section)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func sectionContent(for section: MyDaySection) -> some View {
        let sectionItems = items(for: section)
        if !sectionItems.isEmpty {
            Section {
                if !collapsedSections.contains(section) {
                    ForEach(sectionItems) { item in
                        MyDayItemRow(
                            item:        item,
                            onSetTime:   { editingTimeItem = item },
                            onShowOnMap: item.type == .ride && item.rideId != nil
                                ? { showOnMap(item: item) }
                                : nil
                        )
                        .environment(waitTimeVM)
                        .listRowInsets(
                            EdgeInsets(top: 4, leading: AppSpacing.screenEdge,
                                       bottom: 4, trailing: AppSpacing.screenEdge)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    // Reorder only in the Anytime section with unfiltered view.
                    .onMove(perform: section == .anytime && filter == .all
                        ? { from, to in store.moveSectionItems(sectionItems, from: from, toOffset: to) }
                        : nil
                    )
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

        // Anytime — preserve insertion order for drag-reorder.
        if section == .anytime { return filtered }

        // Timed sections — sort ascending by scheduled time.
        return filtered.sorted {
            guard let a = $0.scheduledTime, let b = $1.scheduledTime else {
                return $0.scheduledTime != nil // timed items bubble up
            }
            return a < b
        }
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

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(MyDayFilter.allCases, id: \.rawValue) { tab in
                let isActive = filter == tab
                Button {
                    withAnimation(AppMotion.standard) {
                        filter = tab
                    }
                    AppHaptic.selection()
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? .white : AppColor.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            isActive ? Color.accentColor : AppColor.skeleton,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .animation(AppMotion.quick, value: filter)
            }
            Spacer()
        }
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.4))

            VStack(spacing: AppSpacing.sm) {
                Text("Plan your park day")
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Text("Add rides, food stops, shows, and anything else you want to do today. Tap + to get started.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
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
        ToolbarItem(placement: .navigationBarTrailing) {
            if !store.items.isEmpty && filter == .all {
                EditButton()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isAddingItem = true
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Delete

    private func deleteFromSection(offsets: IndexSet, sectionItems: [MyDayItem]) {
        let toDelete = offsets.map { sectionItems[$0] }
        withAnimation(AppMotion.standard) {
            for item in toDelete { store.remove(item) }
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
    let onSetTime:   () -> Void
    let onShowOnMap: (() -> Void)?

    @Environment(MyDayStore.self)        private var store
    @Environment(WaitTimeViewModel.self) private var waitTimeVM

    // MARK: - Live wait for ride items

    private var liveWait: String? {
        guard item.type == .ride else { return nil }
        guard let rideId = item.rideId else { return nil }
        guard let state  = waitTimeVM.liveState(for: rideId),
              state.status.isRideable else { return nil }
        return state.waitMinutes.map { $0 == 0 ? "Walk-on" : "\($0) min" }
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
                // Title
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.isChecked
                                     ? AppColor.textTertiary
                                     : AppColor.textPrimary)
                    .strikethrough(item.isChecked, color: AppColor.textTertiary)
                    .lineLimit(2)

                // Subtitle row: type · land · time · live wait
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

            // ── Check button ───────────────────────────────────────────────────
            Button {
                withAnimation(AppMotion.quick) { store.toggle(item) }
                AppHaptic.light()
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
        // Long-press → time picker
        .contextMenu {
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

            // Live wait time (ride items only, when data available)
            if let wait = liveWait {
                Text("·").foregroundStyle(AppColor.textTertiary)
                Text(wait)
                    .foregroundStyle(AppColor.waitColor(
                        minutes: Int(wait.components(separatedBy: " ").first ?? "0") ?? 0
                    ))
                    .fontWeight(.medium)
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
struct AddMyDayItemSheet: View {

    /// Called with the new item when the user taps Add.
    let onAdd: (MyDayItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType:    MyDayItemType = .ride
    @State private var title:           String        = ""
    @State private var location:        String        = ""
    @State private var detail:          String        = ""
    @State private var hasScheduledTime: Bool         = false
    @State private var scheduledTime:   Date          = {
        // Default to next half-hour.
        let cal    = Calendar.current
        let now    = Date()
        var comps  = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = comps.minute ?? 0
        comps.minute  = minute < 30 ? 30 : 0
        if minute >= 30 { comps.hour = (comps.hour ?? 0) + 1 }
        comps.second  = 0
        return cal.date(from: comps) ?? now
    }()

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
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
                    TextField(selectedType.titlePlaceholder, text: $title)
                    TextField("Location (optional)", text: $location)
                    TextField("Notes (optional)", text: $detail)
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
        let trimmedTitle    = title.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedDetail   = detail.trimmingCharacters(in: .whitespaces)

        var item              = MyDayItem(title: trimmedTitle, type: selectedType)
        item.land             = trimmedLocation.isEmpty ? nil : trimmedLocation
        item.detail           = trimmedDetail.isEmpty   ? nil : trimmedDetail
        item.scheduledTime    = hasScheduledTime ? scheduledTime : nil

        onAdd(item)
        dismiss()
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
    return MyDayView()
        .environment(store)
        .environment(WaitTimeViewModel(container: container))
        .environment(AppNavigationCoordinator())
        .modelContainer(container)
}

#Preview("My Day — empty") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    return MyDayView()
        .environment(MyDayStore())
        .environment(WaitTimeViewModel(container: container))
        .environment(AppNavigationCoordinator())
        .modelContainer(container)
}

#Preview("Add item sheet") {
    AddMyDayItemSheet { _ in }
}
#endif

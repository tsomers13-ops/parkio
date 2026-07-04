// MyDayItem.swift — Model + store for the flexible My Day planning checklist.
//
// Architecture:
//   • MyDayItemType   — enum covering all park-day activity categories.
//   • MyDaySection    — grouping enum: Morning / Afternoon / Evening / Anytime.
//   • MyDayItem       — value type representing a single checklist entry.
//   • MyDayStore      — @Observable class owning the ordered item list,
//                       persisted as JSON in the app's Documents directory.
//
// Persistence:
//   JSON file in Documents — chosen over SwiftData to avoid schema
//   coupling with the ride data models. The file survives app updates
//   and is excluded from iCloud backup by default (park-day ephemeral data).
//
// Injection:
//   Create once in DisneyRideTrackerApp, inject via .environment(myDayStore).
//   All consumers read @Environment(MyDayStore.self).

import SwiftUI

// MARK: - MyDayItemType

enum MyDayItemType: String, Codable, CaseIterable, Identifiable {
    case ride      = "ride"
    case food      = "food"
    case show      = "show"
    case character = "character"
    case shopping  = "shopping"
    case note      = "note"
    case custom    = "custom"

    var id: String { rawValue }

    // ── Display ──────────────────────────────────────────────────────────────

    var label: String {
        switch self {
        case .ride:      return "Ride"
        case .food:      return "Food & Drink"
        case .show:      return "Show"
        case .character: return "Character"
        case .shopping:  return "Shopping"
        case .note:      return "Note"
        case .custom:    return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .ride:      return "ticket.fill"
        case .food:      return "fork.knife"
        case .show:      return "theatermasks.fill"
        case .character: return "person.crop.circle.fill"
        case .shopping:  return "bag.fill"
        case .note:      return "note.text"
        case .custom:    return "star.fill"
        }
    }

    /// Accent color used for the icon background and selected state.
    var color: Color {
        switch self {
        case .ride:      return Color.accentColor
        case .food:      return Color.orange
        case .show:      return Color.purple
        case .character: return Color.pink
        case .shopping:  return Color.indigo
        case .note:      return Color.yellow
        case .custom:    return Color.gray
        }
    }
}

// MARK: - MyDaySection

/// Time-based grouping for My Day checklist items.
/// Computed from MyDayItem.scheduledTime — items without a time fall into .anytime.
enum MyDaySection: String, CaseIterable, Hashable {
    case morning   = "Morning"
    case afternoon = "Afternoon"
    case evening   = "Evening"
    case anytime   = "Anytime"

    /// Short descriptor shown beneath the section title.
    var timeRange: String {
        switch self {
        case .morning:   return "Before 12 PM"
        case .afternoon: return "12 PM – 5 PM"
        case .evening:   return "After 5 PM"
        case .anytime:   return "No time set"
        }
    }

    var systemImage: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        case .anytime:   return "list.bullet"
        }
    }

    var color: Color {
        switch self {
        case .morning:   return Color.orange
        case .afternoon: return Color.yellow
        case .evening:   return Color.indigo
        case .anytime:   return Color.secondary
        }
    }
}

// MARK: - MyDayItem

/// A single entry in the My Day checklist.
/// Value type — mutations go through MyDayStore which handles persistence.
struct MyDayItem: Identifiable, Codable, Equatable {

    /// Stable UUID assigned on creation. Never changes.
    var id: UUID = UUID()

    /// Primary display text — ride name, show title, character name, etc.
    var title: String

    /// Category that drives the icon and color.
    var type: MyDayItemType

    /// Optional area string — land name, restaurant area, show venue, etc.
    var land: String?

    /// Backend park identifier — e.g. "magic-kingdom".
    /// Set for rides (via RidePickerView), shows, and character experiences
    /// (via MasterAttractionPickerView) so map cross-referencing works.
    var parkId: String?

    /// Stable attraction identifier.
    ///
    /// • Ride items    — stores the SwiftData `Ride.id`, which equals the
    ///                   RideMasterData stableID ("{Park.rawValue}|{land}|{name}").
    ///                   Used to resolve live wait times and map positions.
    ///
    /// • Show / Character items — stores the `MasterAttraction.stableID`
    ///   ("{Park.rawValue}|{land}|{name}") chosen in MasterAttractionPickerView.
    ///   Enables "Show on Map" for attractions where shouldAppearOnMap == true.
    ///
    /// Free-form items (food, shopping, note, custom) leave this nil.
    var rideId: String?

    /// Optional free-text detail — meeting time, reservation number, etc.
    var detail: String?

    /// Whether the item has been completed / checked off.
    var isChecked: Bool = false

    /// Timestamp used for "added X min ago" display and daily-reset detection.
    var addedAt: Date = Date()

    /// Optional scheduled start time for this activity.
    /// Determines which MyDaySection this item appears in.
    /// nil → .anytime section.
    var scheduledTime: Date? = nil
}

// MARK: - MyDayItem + section

extension MyDayItem {

    /// The time-based section this item belongs to.
    /// Computed from scheduledTime; items without a time are .anytime.
    var section: MyDaySection {
        guard let time = scheduledTime else { return .anytime }
        let hour = Calendar.current.component(.hour, from: time)
        switch hour {
        case 0..<12:  return .morning
        case 12..<17: return .afternoon
        default:      return .evening
        }
    }

    /// Formatted time string for display, e.g. "9:30 AM".
    var formattedTime: String? {
        guard let time = scheduledTime else { return nil }
        let fmt       = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: time)
    }
}

// MARK: - MyDayStore

@Observable
@MainActor
final class MyDayStore {

    // ── Ordered list — the source of truth for MyDayView ─────────────────────
    private(set) var items: [MyDayItem] = []

    // ── Persistence ───────────────────────────────────────────────────────────
    private let saveURL: URL

    // MARK: Init

    init() {
        saveURL = URL.documentsDirectory.appending(path: "MyDayItems.json")
        load()
    }

    // MARK: - Computed properties

    var remainingCount: Int { items.filter { !$0.isChecked }.count }
    var completedCount: Int { items.filter {  $0.isChecked }.count }

    // MARK: - CRUD

    /// Append a free-form item.
    func add(_ item: MyDayItem) {
        items.append(item)
        save()
    }

    /// Add a ride from the map/detail flow. Guard against duplicates by rideId.
    func addRide(
        rideId:  String,
        name:    String,
        land:    String?,
        parkId:  String?
    ) {
        guard !items.contains(where: { $0.rideId == rideId }) else { return }
        var item     = MyDayItem(title: name, type: .ride, land: land, parkId: parkId)
        item.rideId  = rideId
        items.append(item)
        save()
    }

    /// Remove a specific item.
    func remove(_ item: MyDayItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Remove items at the given offsets in the FULL `items` array.
    func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    /// Toggle the checked state for an item.
    func toggle(_ item: MyDayItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isChecked.toggle()
        save()
    }

    /// Move items (called by List.onMove — operates on the FULL array, not filtered).
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Reorder items within a section.
    ///
    /// Maps section-scoped offsets back to the full `items` array so that
    /// items in other sections retain their relative positions.
    /// Only makes sense for the Anytime section (timed sections are time-sorted).
    func moveSectionItems(_ sectionItems: [MyDayItem], from source: IndexSet, toOffset destination: Int) {
        var reordered = sectionItems
        reordered.move(fromOffsets: source, toOffset: destination)

        let sectionIdSet  = Set(sectionItems.map(\.id))
        let fullSlots     = items.indices.filter { sectionIdSet.contains(items[$0].id) }

        for (slot, reorderedItem) in zip(fullSlots, reordered) {
            items[slot] = reorderedItem
        }
        save()
    }

    /// Update the scheduled time for an item (pass nil to remove the time).
    func setScheduledTime(_ time: Date?, for item: MyDayItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].scheduledTime = time
        save()
    }

    /// Remove all completed items.
    func clearCompleted() {
        items.removeAll { $0.isChecked }
        save()
    }

    /// Remove all items (e.g. day reset).
    func clearAll() {
        items.removeAll()
        save()
    }

    // MARK: - Query helpers

    /// True when the given rideId is already in the list (checked or not).
    func containsRide(_ rideId: String) -> Bool {
        items.contains { $0.rideId == rideId }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard
            let data    = try? Data(contentsOf: saveURL),
            let decoded = try? JSONDecoder().decode([MyDayItem].self, from: data)
        else { return }
        items = decoded
    }
}

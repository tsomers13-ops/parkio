// DiningServiceStyle.swift — Guest-facing Quick service / Sit-down buckets.
//
// AttractionType stays the catalog's service type. This file is the only
// place that maps those cases onto the two buckets the dining lists filter
// by. It does not read or change any venue's stored type.

import Foundation

// MARK: - Bucket

/// Sit-down versus quick-service, for filtering dining lists.
///
/// Distinct from `AttractionType`. A venue keeps its catalog type; this is
/// only the bucket that type belongs to.
enum DiningServiceStyle: String, CaseIterable, Sendable, Identifiable {
    case quickService
    case sitDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickService: return "Quick service"
        case .sitDown:      return "Sit-down"
        }
    }
}

// MARK: - Filter

/// All / Quick service / Sit-down. `.all` is the default and returns every
/// venue it is given.
enum DiningServiceFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case quickService
    case sitDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:          return "All"
        case .quickService: return "Quick service"
        case .sitDown:      return "Sit-down"
        }
    }

    /// Visible title is `title`. The All option's accessibility label is
    /// more specific because the attractions category strip already has a
    /// button whose label is "All" — VoiceOver and XCUITest both match that
    /// label, and this filter must not steal that query.
    var accessibilityLabel: String {
        switch self {
        case .all:          return "All dining"
        case .quickService: return "Quick service"
        case .sitDown:      return "Sit-down"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .all:          return "parkio.dining.serviceFilter.all"
        case .quickService: return "parkio.dining.serviceFilter.quickService"
        case .sitDown:      return "parkio.dining.serviceFilter.sitDown"
        }
    }

    var style: DiningServiceStyle? {
        switch self {
        case .all:          return nil
        case .quickService: return .quickService
        case .sitDown:      return .sitDown
        }
    }

    /// True when `type` should stay on a list that is using this filter.
    /// `.all` keeps every type, including non-dining. A specific bucket
    /// keeps only types that map to that bucket.
    func includes(_ type: AttractionType) -> Bool {
        guard let style else { return true }
        return type.diningServiceStyle == style
    }

    /// Venues that pass this filter, in their original order.
    /// `.all` returns `venues` unchanged.
    func applied(to venues: [MasterAttraction]) -> [MasterAttraction] {
        guard style != nil else { return venues }
        return venues.filter { includes($0.type) }
    }
}

// MARK: - Mapping

extension AttractionType {

    /// The dining bucket for this service type, or nil when the type is not
    /// a dining venue.
    ///
    /// This switch is the only classification. New cases have to be placed
    /// here before they compile.
    ///
    /// - Quick service: counter restaurants, snack stands and carts, and
    ///   festival booths (walk-up counters, same family as a snack stand).
    ///   No venue currently uses `.festivalBooth`.
    /// - Sit-down: waiter-service restaurants. Lounges and bars are sit-down
    ///   for now; that placement is interim.
    ///
    /// There is no character-buffet or dinner-show case. Venues of that kind
    /// keep whatever service type the catalog already gives them.
    var diningServiceStyle: DiningServiceStyle? {
        switch self {
        case .quickService, .snackStand, .festivalBooth:
            return .quickService
        case .tableService, .lounge:
            return .sitDown
        case .ride, .show, .characterMeet, .walkthrough, .transport, .future:
            return nil
        }
    }
}

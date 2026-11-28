// RideLog.swift — SwiftData model for a single ride completion event.
//
// myDayItemId
// ────────────
// Optional UUID string identifying the MyDayItem that created this log.
// nil   → entry was created via QuickLogSheet (manual log).
// <uuid> → entry was created automatically when the user checked off a
//          My Day ride item.  Used by MyDayView.handleToggle(item:) to:
//   • prevent duplicates  (check → rapid re-check)
//   • undo the entry     (uncheck removes the log)
//
// SwiftData migrates existing rows automatically; they receive nil,
// which correctly identifies them as manually-logged rides.

import Foundation
import SwiftData

/// What the guest consumed during one dining visit.
///
/// This belongs to the individual visit rather than the venue: the same guest
/// can have food on one visit and only a drink on another. Existing logs have
/// no stored value and remain valid as "Not specified" through the optional
/// `RideLog.diningConsumption` accessor.
enum DiningConsumption: String, CaseIterable, Codable, Identifiable {
    case food
    case drink
    case foodAndDrink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:         return "Food"
        case .drink:        return "Drink"
        case .foodAndDrink: return "Food & Drink"
        }
    }

    var includesFood: Bool { self == .food || self == .foodAndDrink }
    var includesDrink: Bool { self == .drink || self == .foodAndDrink }
}

@Model
final class RideLog {
    var date: Date
    var ride: Ride?

    /// UUID string of the MyDayItem whose completion created this entry.
    /// nil for manually logged rides (QuickLogSheet path).
    var myDayItemId: String?

    /// Optional raw value keeps SwiftData storage migration additive. Existing
    /// ride and dining logs automatically remain nil ("Not specified").
    var diningConsumptionRawValue: String?

    var diningConsumption: DiningConsumption? {
        get { diningConsumptionRawValue.flatMap(DiningConsumption.init(rawValue:)) }
        set { diningConsumptionRawValue = newValue?.rawValue }
    }

    init(
        date: Date = Date(),
        ride: Ride? = nil,
        myDayItemId: String? = nil,
        diningConsumption: DiningConsumption? = nil
    ) {
        self.date                       = date
        self.ride                       = ride
        self.myDayItemId                = myDayItemId
        self.diningConsumptionRawValue  = diningConsumption?.rawValue
    }
}

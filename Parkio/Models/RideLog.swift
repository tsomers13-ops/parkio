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

@Model
final class RideLog {
    var date: Date
    var ride: Ride?

    /// UUID string of the MyDayItem whose completion created this entry.
    /// nil for manually logged rides (QuickLogSheet path).
    var myDayItemId: String?

    init(date: Date = Date(), ride: Ride? = nil, myDayItemId: String? = nil) {
        self.date        = date
        self.ride        = ride
        self.myDayItemId = myDayItemId
    }
}

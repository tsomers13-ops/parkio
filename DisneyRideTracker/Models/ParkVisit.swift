// ParkVisit.swift — SwiftData model for a single park visit day.
//
// visitDate
// ─────────
// Always stored as midnight of the park-local calendar day, computed in the
// park's IANA timezone (America/New_York for WDW, America/Los_Angeles for DL).
// Two rides logged on the same park-local day always produce the same visitDate
// value regardless of the device's local timezone, making equality checks
// reliable with a simple Date == Date comparison.
//
// source
// ──────
// "rideLog" — created automatically when a RideLog is created (the only
//              source for now).
// Future values: "manual" for user-initiated check-ins.
//
// Migration safety
// ────────────────
// The prior schema had parkName: String and visitYear: Int in addition to
// id/parkId/visitDate. Those fields are dropped here. SwiftData's automatic
// lightweight migration abandons the old columns and adds createdAt / source
// with no data to migrate (ParkVisit rows were never created — upsert logic
// was not wired until this version). The result is a clean v2 table.

import Foundation
import SwiftData

@Model
final class ParkVisit {
    @Attribute(.unique) var id: UUID
    /// park.backendId — e.g. "magic-kingdom", "epcot".
    var parkId:    String
    /// Midnight of the park-local calendar day in the park's IANA timezone.
    /// Computed by ParkVisitService.parkLocalDay(for:park:) before insertion.
    var visitDate: Date
    /// Wall-clock moment this record was first inserted.
    /// Optional so SwiftData's inferred migration can add this column as NULL-able
    /// on stores that were created before this field existed. All new inserts
    /// receive a non-nil value via the init default.
    var createdAt: Date?
    /// Origin of this record. "rideLog" for auto-created entries; "manual" for
    /// user-initiated check-ins. Optional for the same migration-safety reason
    /// as createdAt — nil only on rows pre-dating this schema version.
    var source:    String?

    init(
        id:        UUID   = UUID(),
        parkId:    String,
        visitDate: Date,
        source:    String = "rideLog",
        createdAt: Date   = Date()
    ) {
        self.id        = id
        self.parkId    = parkId
        self.visitDate = visitDate
        self.createdAt = createdAt
        self.source    = source
    }
}

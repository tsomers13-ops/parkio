// ParkVisitService.swift — Static helpers for upserting and cleaning up ParkVisit records.
//
// Design
// ──────
// Pure static functions that accept a ModelContext parameter. No @Observable,
// no shared singleton — the callers (MyDayView, QuickLogSheet) already hold a
// ModelContext via @Environment and pass it in directly.
//
// Date logic
// ──────────
// visitDate is always midnight of the *park-local* calendar day. Two Date values
// computed by parkLocalDay(for:park:) for any two timestamps on the same
// park-local calendar day will be bitwise-equal, so simple Date == Date
// comparisons in the in-memory filter work correctly.
//
// Idempotency
// ───────────
// upsertParkVisit is safe to call on every RideLog creation. It fetches all
// ParkVisits and filters in-memory (avoiding #Predicate optional-String issues
// across iOS 17 versions) before deciding whether to insert.
//
// Cleanup contract
// ────────────────
// cleanupParkVisitIfNeeded is called AFTER the RideLog has been deleted and
// saved. It checks whether any *other* RideLogs remain for the same park+day.
// If they do, the ParkVisit is retained. If none remain, it is deleted.
// This correctly handles mixed-source scenarios: a manual QuickLog entry for
// the same park+day prevents a My Day uncheck from removing the ParkVisit.

import Foundation
import SwiftData

enum ParkVisitService {

    // MARK: - Public API

    /// Upserts a ParkVisit for the given park on the park-local calendar day that
    /// contains `rideDate`. Safe to call on every RideLog creation — idempotent.
    ///
    /// - Parameters:
    ///   - park:     The park whose visit should be recorded.
    ///   - rideDate: The wall-clock time of the RideLog (may be user-selected past date).
    ///   - context:  The active ModelContext for SwiftData reads and writes.
    static func upsertParkVisit(
        for park:    Park,
        rideDate:    Date,
        context:     ModelContext
    ) {
        let localDay = parkLocalDay(for: rideDate, park: park)
        let parkId   = park.backendId

        #if DEBUG
        print("🔎 [ParkVisit] Upsert attempted — \(parkId) \(localDay)")
        #endif

        // In-memory filter: avoids #Predicate optional-String issues on iOS 17.
        let descriptor = FetchDescriptor<ParkVisit>()
        let all        = (try? context.fetch(descriptor)) ?? []
        let existing   = all.filter { $0.parkId == parkId && $0.visitDate == localDay }

        guard existing.isEmpty else {
            #if DEBUG
            print("⏩ [ParkVisit] Already exists for \(parkId) on \(localDay) — skipped")
            #endif
            return
        }

        let visit = ParkVisit(
            parkId:    parkId,
            visitDate: localDay,
            source:    "rideLog"
        )
        context.insert(visit)
        try? context.save()

        #if DEBUG
        print("✅ [ParkVisit] Created — \(parkId) \(localDay)")
        #endif
    }

    /// Removes the ParkVisit for the given park+day ONLY if no other RideLogs
    /// remain for that park on that park-local calendar day.
    ///
    /// Must be called AFTER the triggering RideLog(s) have been deleted and saved,
    /// so the remaining-log check reflects the post-deletion state.
    ///
    /// - Parameters:
    ///   - park:     The park whose visit may need cleanup.
    ///   - rideDate: The wall-clock time of the deleted RideLog.
    ///   - context:  The active ModelContext for SwiftData reads and writes.
    static func cleanupParkVisitIfNeeded(
        for park: Park,
        rideDate: Date,
        context:  ModelContext
    ) {
        let localDay = parkLocalDay(for: rideDate, park: park)
        let parkId   = park.backendId

        // Check whether any RideLogs remain for this park+day.
        let logDescriptor = FetchDescriptor<RideLog>()
        let allLogs       = (try? context.fetch(logDescriptor)) ?? []

        let remainingLogs = allLogs.filter { log in
            guard let ride     = log.ride,
                  let logPark  = Park(rawValue: ride.park) else { return false }
            return logPark.backendId == parkId
                && parkLocalDay(for: log.date, park: logPark) == localDay
        }

        guard remainingLogs.isEmpty else {
            #if DEBUG
            print("ℹ️ [ParkVisit] Retained — \(remainingLogs.count) RideLog(s) remain for \(parkId) on \(localDay)")
            #endif
            return
        }

        // No remaining logs — remove the ParkVisit if it exists.
        let visitDescriptor = FetchDescriptor<ParkVisit>()
        let allVisits       = (try? context.fetch(visitDescriptor)) ?? []
        let toDelete        = allVisits.filter {
            $0.parkId == parkId && $0.visitDate == localDay
        }

        guard !toDelete.isEmpty else {
            #if DEBUG
            print("ℹ️ [ParkVisit] No ParkVisit found to remove for \(parkId) on \(localDay)")
            #endif
            return
        }

        toDelete.forEach { context.delete($0) }
        try? context.save()

        #if DEBUG
        print("🗑️ [ParkVisit] Removed — \(parkId) \(localDay) (no remaining RideLogs)")
        #endif
    }

    // MARK: - Date helper

    /// Returns the park-local calendar day (midnight in the park's IANA timezone)
    /// for any wall-clock Date.
    ///
    /// Two timestamps that fall on the same park-local calendar day always return
    /// the same Date value, making equality comparisons safe.
    static func parkLocalDay(for date: Date, park: Park) -> Date {
        var cal      = Calendar(identifier: .gregorian)
        cal.timeZone = park.timeZone
        return cal.startOfDay(for: date)
    }
}

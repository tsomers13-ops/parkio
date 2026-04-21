// WaitTimePersistenceActor.swift — Background-isolated SwiftData persistence for wait-time cache.
//
// Why this exists:
//   WaitTimeViewModel is @MainActor. After a network fetch returns, it previously
//   ran WaitTimeCacheWriter.merge (N FetchDescriptor queries + N @Model mutations)
//   and context.save() synchronously on the main thread. On parks with 60-100
//   rides this blocks the main runloop long enough to drop animation frames and
//   stall map gestures.
//
// Solution:
//   @ModelActor gives the actor its own ModelContext backed by a private serial
//   executor that never runs on the main thread. WaitTimeViewModel awaits a single
//   call — mergeAndSave — which performs the entire write+read cycle off-main and
//   returns Sendable value types that can be handed back to @MainActor safely.
//
// Sendability:
//   LiveRideState is a pure-value struct (String, Int?, Bool, enum, Date).
//   WaitTrend and RideStatus are String-backed enums. All stored properties are
//   Sendable, so [LiveRideState] crosses the actor boundary without warnings.
//
// Thread safety of WaitTimeCacheWriter:
//   WaitTimeCacheWriter.merge takes a ModelContext parameter and operates only on
//   that context. Called here with the actor's own modelContext, all SwiftData
//   mutations are serialised on the actor's executor. The BackgroundRefreshService
//   uses its own separate ModelContext — multiple contexts on the same
//   ModelContainer are safe (SwiftData uses SQLite WAL mode under the hood).

import SwiftData
import Foundation

// MARK: - WaitTimePersistenceActor

/// A ModelActor that owns the write path for the WaitTimeCache store.
///
/// Every method runs on the actor's private serial executor (off the main thread).
/// Callers receive `[LiveRideState]` value types and assign them to `@MainActor`
/// state without crossing any concurrency boundary unsafely.
@ModelActor
actor WaitTimePersistenceActor {

    // MARK: - Write + read (one background hop for the entire cycle)

    /// Merge a decoded network response into the persistent store, save, then
    /// return the updated cache for the park as view-ready value types.
    ///
    /// Combines the write and the subsequent read into a single actor call so
    /// the caller (WaitTimeViewModel.fetchAndCache) does exactly one `await`
    /// for all SwiftData work, minimising actor-hop overhead.
    ///
    /// - Parameters:
    ///   - dto: The fully-decoded park live response from the network layer.
    ///   - stalenessThreshold: Seconds after which an entry is considered stale.
    ///     Passed in from WaitTimeViewModel.stalenessThresholdSeconds so this
    ///     actor stays free of polling-config knowledge.
    /// - Returns: Fresh `[LiveRideState]` reflecting the just-written rows.
    /// - Throws: Propagates any error from `ModelContext.save()` so the caller
    ///   can record a failure phase and surface it in the UI.
    func mergeAndSave(
        dto: ParkLiveDTO,
        stalenessThreshold: TimeInterval
    ) throws -> [LiveRideState] {
        // WaitTimeCacheWriter runs N FetchDescriptor queries + N @Model mutations.
        // All happen on this actor's executor — never touches the main thread.
        WaitTimeCacheWriter.merge(dto: dto, into: modelContext)
        try modelContext.save()

        // Read back the now-current rows for this park and convert to value types.
        // Doing the read here avoids a second actor hop and a second context.save
        // round-trip; the data we just wrote is immediately visible in the same context.
        return fetchStates(parkId: dto.parkId, stalenessThreshold: stalenessThreshold)
    }

    // MARK: - Private helpers

    /// Fetch all WaitTimeCache rows for a park from this actor's context and
    /// map them to Sendable value types. Called immediately after mergeAndSave
    /// so the returned snapshot is coherent with the just-written data.
    private func fetchStates(
        parkId: String,
        stalenessThreshold: TimeInterval
    ) -> [LiveRideState] {
        let descriptor = FetchDescriptor<WaitTimeCache>(
            predicate: #Predicate<WaitTimeCache> { $0.parkId == parkId }
        )
        guard let cached = try? modelContext.fetch(descriptor) else { return [] }

        let now = Date()
        return cached.map { entry in
            LiveRideState(
                id:                     entry.rideId,
                name:                   entry.rideName,
                land:                   "",       // WaitTimeCache has no land field
                parkId:                 entry.parkId,
                status:                 entry.status,
                waitMinutes:            entry.waitMinutes,
                singleRiderWaitMinutes: entry.singleRiderWaitMinutes,
                lightningLaneAvailable: entry.lightningLaneAvailable,
                trend:                  entry.trend,
                trendDeltaMinutes:      entry.trendDeltaMinutes,
                fetchedAt:              entry.fetchedAt,
                isStale:                entry.isStale
                                            || now.timeIntervalSince(entry.fetchedAt) > stalenessThreshold
            )
        }
    }
}

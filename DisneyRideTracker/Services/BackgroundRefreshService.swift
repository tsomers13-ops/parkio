// BackgroundRefreshService.swift — BGAppRefreshTask registration and scheduling.
//
// REQUIRED SETUP (one-time, in Xcode):
//   1. Target → Signing & Capabilities → + Background Modes
//      → enable "Background fetch" and "Background processing"
//   2. Info.plist → add key "BGTaskSchedulerPermittedIdentifiers" (Array)
//      → add item: "com.disneytracker.waittimes.refresh"
//
// Flow:
//   App launch → register handler → schedule next task
//   BGTaskScheduler fires → handler runs → fetch 1 park (active park)
//   → write to SwiftData cache → schedule next task
//
// Note: iOS throttles BGAppRefreshTask heavily. The system decides WHEN to run
// the task — the earliestBeginDate is only a lower bound. In practice you may
// get 1–2 runs per hour while the app is backgrounded. This supplements the
// foreground 3-minute timer, it does not replace it.

import BackgroundTasks
import SwiftData
import Foundation

enum BackgroundRefreshService {

    static let taskIdentifier = "com.disneytracker.waittimes.refresh"

    // ── Registration (call from App.init or application(_:didFinishLaunchingWithOptions:)) ──

    /// Register the BGAppRefreshTask handler.
    /// Must be called before the app finishes launching.
    static func registerHandler(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefresh(task: refreshTask, modelContainer: modelContainer)
        }
    }

    // ── Scheduling ────────────────────────────────────────────────────────────

    /// Schedule the next background refresh.
    /// Call this:
    ///   • After the handler completes (reschedule for next run)
    ///   • When the app enters background (scenePhase == .background)
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Ask for a refresh in ~15 minutes. System may delay further.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.notPermitted {
            // Background fetch not enabled in capabilities — dev mode or restricted device
            print("[BGTask] Not permitted — ensure Background Fetch is enabled in capabilities")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            // Already scheduled — ignore
        } catch {
            print("[BGTask] Failed to schedule: \(error)")
        }
    }

    // ── Handler ───────────────────────────────────────────────────────────────

    private static func handleRefresh(
        task: BGAppRefreshTask,
        modelContainer: ModelContainer
    ) {
        // Reschedule immediately so the next run is queued even if this one fails
        scheduleNext()

        // iOS will kill the task if it runs too long — set an expiry handler
        let fetchTask = Task {
            defer { task.setTaskCompleted(success: true) }

            do {
                // Refresh the last-active park (stored in UserDefaults)
                let parkId = UserDefaults.standard.string(
                    forKey: UserDefaultsKey.lastActiveParkId
                ) ?? "magic-kingdom"

                let dto = try await WaitTimeService.shared.fetchParkLive(parkId: parkId)

                // Write to SwiftData on a background context
                let context = ModelContext(modelContainer)
                WaitTimeCacheWriter.merge(dto: dto, into: context)
                try context.save()

                print("[BGTask] Refreshed \(parkId) in background")
            } catch {
                print("[BGTask] Refresh failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - UserDefaults keys

enum UserDefaultsKey {
    static let lastActiveParkId = "com.disneytracker.lastActiveParkId"
}

// MARK: - Cache writer (shared between foreground and background contexts)

enum WaitTimeCacheWriter {

    /// Merge a ParkLiveDTO into the given ModelContext.
    /// Uses upsert: update existing row, insert if missing.
    /// Context.save() is the caller's responsibility.
    static func merge(dto: ParkLiveDTO, into context: ModelContext) {
        let fetchedAt = ISO8601DateFormatter().date(from: dto.fetchedAt) ?? Date()
        // Local staleness: backend age + time since we received it
        let localAgeSeconds = dto.cacheAgeSeconds + 30  // approx transit time

        for ride in dto.rides {
            // Capture rideId as a plain local constant — #Predicate cannot
            // reach through a property chain on a captured struct/class.
            let rideId = ride.rideId
            let descriptor = FetchDescriptor<WaitTimeCache>(
                predicate: #Predicate<WaitTimeCache> { $0.rideId == rideId }
            )
            let existing = try? context.fetch(descriptor).first

            if let cached = existing {
                // Update in place (SwiftData tracks @Model mutations automatically)
                update(cached, from: ride, fetchedAt: fetchedAt,
                       cacheAge: dto.cacheAgeSeconds,
                       isStale: localAgeSeconds > 600,
                       source: dto.source)
            } else {
                let newEntry = WaitTimeCache(
                    rideId:                 ride.rideId,
                    parkId:                 dto.parkId,
                    rideName:               ride.name,
                    waitMinutes:            ride.waitMinutes,
                    singleRiderWaitMinutes: ride.singleRiderWaitMinutes,
                    lightningLaneAvailable: ride.lightningLaneAvailable,
                    statusRaw:              ride.status,
                    trendRaw:               ride.trend,
                    trendDeltaMinutes:      ride.trendDeltaMinutes,
                    fetchedAt:              fetchedAt,
                    backendCacheAgeSeconds: dto.cacheAgeSeconds,
                    isStale:                localAgeSeconds > 600,
                    sourceRaw:              dto.source
                )
                context.insert(newEntry)
            }
        }
    }

    private static func update(
        _ cached: WaitTimeCache,
        from ride: LiveRideDTO,
        fetchedAt: Date,
        cacheAge: Int,
        isStale: Bool,
        source: String
    ) {
        cached.rideName                = ride.name
        cached.waitMinutes             = ride.waitMinutes
        cached.singleRiderWaitMinutes  = ride.singleRiderWaitMinutes
        cached.lightningLaneAvailable  = ride.lightningLaneAvailable
        cached.statusRaw               = ride.status
        cached.trendRaw                = ride.trend
        cached.trendDeltaMinutes       = ride.trendDeltaMinutes
        cached.fetchedAt               = fetchedAt
        cached.backendCacheAgeSeconds  = cacheAge
        cached.isStale                 = isStale
        cached.sourceRaw               = source
    }
}

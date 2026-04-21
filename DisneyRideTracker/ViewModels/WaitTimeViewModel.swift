// WaitTimeViewModel.swift — @Observable class that drives HomeView and MyDayView.
//
// Responsibilities:
//   • Own the 3-minute foreground polling timer.
//   • Fetch live wait times from WaitTimeService.
//   • Delegate SwiftData writes to WaitTimePersistenceActor (off main thread).
//   • Expose typed, view-ready state (no DTOs, no raw strings).
//   • React to connectivity changes (ConnectivityMonitor).
//   • Provide all loading / error / stale states views need.
//
// Injection: Created once in DisneyRideTrackerApp and injected via .environment().
// Views: access via @Environment(WaitTimeViewModel.self).
//
// Two-actor concurrency model:
//   WaitTimeViewModel (@MainActor) owns UI state and polling timers.
//   WaitTimePersistenceActor (@ModelActor, background executor) owns all
//   SwiftData writes. After a network fetch completes, fetchAndCache does a
//   single `await persistenceActor.mergeAndSave(...)` — N FetchDescriptor
//   queries + N @Model mutations + context.save() + a read-back all happen
//   off the main thread. Only the resulting [LiveRideState] value types
//   (fully Sendable) are handed back to @MainActor for UI assignment.
//
// Task lifecycle (two independent loops):
//   pollingTask              — 3-min interval fetch; started/stopped with scene phase.
//   connectivityObserverTask — 1-sec connectivity poll; triggers immediate fetch on
//                              reconnect. Guarded identically to pollingTask so only
//                              one copy ever runs. Stopped on background, restarted
//                              on foreground, and cancelled on deinit.

import SwiftUI
import SwiftData
import Observation
import Foundation

// MARK: - View-ready ride state

/// What HomeView / MyDayView bind to per ride — no raw strings or DTOs.
struct LiveRideState: Identifiable {
    let id: String          // rideId
    let name: String
    let land: String
    let parkId: String
    let status: RideStatus
    let waitMinutes: Int?
    let singleRiderWaitMinutes: Int?
    let lightningLaneAvailable: Bool
    let trend: WaitTrend
    let trendDeltaMinutes: Int
    let fetchedAt: Date
    let isStale: Bool

    /// Convenience: formatted wait string for display.
    var waitDisplay: String {
        guard status.isRideable, let mins = waitMinutes else {
            return status.displayLabel
        }
        return mins == 0 ? "Walk-on" : "\(mins) min"
    }

    /// Wait band color (delegates to AppColor token).
    var waitColor: Color {
        guard status.isRideable, let mins = waitMinutes else {
            return AppColor.textTertiary
        }
        return AppColor.waitColor(minutes: mins)
    }
}

// MARK: - Fetch phase

enum FetchPhase: Equatable {
    case idle
    case loading
    case success(fetchedAt: Date)
    case failure(WaitTimeError)

    var isLoading: Bool { self == .loading }
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class WaitTimeViewModel {

    // ── Dependencies (injected) ───────────────────────────────────────────────
    private let container: ModelContainer
    private let service: WaitTimeService
    private let connectivity: ConnectivityMonitor

    // ── Background persistence ────────────────────────────────────────────────
    /// Owns all SwiftData write paths on a private background executor.
    /// Created once from the shared ModelContainer; safe to call concurrently
    /// with BackgroundRefreshService's own ModelContext (SQLite WAL mode).
    private let persistenceActor: WaitTimePersistenceActor

    // ── Polling config ────────────────────────────────────────────────────────
    let pollingIntervalSeconds: TimeInterval = 180   // 3 minutes
    let stalenessThresholdSeconds: TimeInterval = 600 // 10 minutes

    // ── Per-park fetch state ──────────────────────────────────────────────────
    /// Maps parkId → current FetchPhase. Drives loading spinners per tab.
    private(set) var fetchPhase: [String: FetchPhase] = [:]

    /// The last error for the most recently active park.
    var lastError: WaitTimeError? {
        guard case .failure(let e) = fetchPhase[activeParkId] else { return nil }
        return e
    }

    // ── Live ride states (read from SwiftData cache) ──────────────────────────
    /// All cached rides for the active park — refreshed after every write.
    private(set) var liveRides: [LiveRideState] = []

    // ── Active park ───────────────────────────────────────────────────────────
    /// The park currently displayed. Setting this triggers a cache read and
    /// — if stale — a background fetch.
    var activeParkId: String = UserDefaults.standard.string(
        forKey: UserDefaultsKey.lastActiveParkId
    ) ?? "magic-kingdom" {
        didSet {
            UserDefaults.standard.set(activeParkId, forKey: UserDefaultsKey.lastActiveParkId)
            reloadCacheForActivePark()
            refreshIfNeeded(parkId: activeParkId)
        }
    }

    // ── Staleness ─────────────────────────────────────────────────────────────
    /// The oldest fetchedAt across displayed rides, nil if no cache.
    var oldestFetchedAt: Date? {
        liveRides.map(\.fetchedAt).min()
    }

    var isStale: Bool {
        guard let oldest = oldestFetchedAt else { return true }
        return Date().timeIntervalSince(oldest) > stalenessThresholdSeconds
    }

    var lastUpdatedString: String {
        guard let date = oldestFetchedAt else { return "No data" }
        let age = Date().timeIntervalSince(date)
        switch age {
        case ..<60:     return "Just now"
        case ..<3600:   return "\(Int(age / 60)) min ago"
        default:        return "Over 1 hour ago"
        }
    }

    var staleBannerText: String? {
        guard !connectivity.isConnected else { return nil }
        guard oldestFetchedAt != nil else { return nil }
        return "Showing wait times from \(lastUpdatedString). No connection."
    }

    // ── Computed sections for HomeView ────────────────────────────────────────

    /// Up Next: unridden rides sorted by ascending wait time, capped at 6.
    /// "Unridden" is defined as: not in the user's RideLog for today.
    /// Here we sort by wait as proxy; actual ridden-today filter is done in HomeView.
    var upNextRides: [LiveRideState] {
        liveRides
            .filter { $0.status.isRideable }
            .sorted {
                ($0.waitMinutes ?? 999) < ($1.waitMinutes ?? 999)
            }
            .prefix(6)
            .map { $0 }
    }

    /// Rides currently down or in refurbishment — useful for My Day planning.
    var unavailableRides: [LiveRideState] {
        liveRides.filter { $0.status == .down || $0.status == .refurbishment }
    }

    // ── Task handles ─────────────────────────────────────────────────────────
    // Both loops are guarded: only one instance of each ever runs at a time.
    //
    // Swift only allows `nonisolated` on immutable (`let`) stored properties;
    // `var` requires `nonisolated(unsafe)`, which triggers its own warning on
    // Sendable types. The cleanest solution is a small `@unchecked Sendable`
    // wrapper so we get a `nonisolated let` binding (immutable reference,
    // mutable contents) that deinit — which is nonisolated even on @MainActor
    // classes (SE-0371 not yet default) — can safely call cancelAll() on.
    // All mutations to the handles happen on the main actor by contract;
    // deinit only ever reads/cancels, and only after all actor-isolated
    // references to self have already been released.
    private final class TaskHandles: @unchecked Sendable {
        var polling:              Task<Void, Never>?
        var connectivityObserver: Task<Void, Never>?
        func cancelAll() {
            polling?.cancel()
            connectivityObserver?.cancel()
        }
    }
    nonisolated private let taskHandles = TaskHandles()

    // ── Init ──────────────────────────────────────────────────────────────────

    init(
        container: ModelContainer,
        service: WaitTimeService = .shared,
        connectivity: ConnectivityMonitor = .shared
    ) {
        self.container         = container
        self.service           = service
        self.connectivity      = connectivity
        self.persistenceActor  = WaitTimePersistenceActor(modelContainer: container)
    }

    // ── Deinit ────────────────────────────────────────────────────────────────

    deinit {
        // Task.cancel() is thread-safe and actor-independent. Cancelling here
        // ensures no orphaned polling or observer tasks outlive the view model.
        taskHandles.cancelAll()
    }

    // MARK: - Lifecycle

    /// Call from ContentView.task{} — starts polling and connectivity watching.
    func onAppear() {
        reloadCacheForActivePark()
        startPolling()
        startConnectivityObserver()
    }

    /// Call from ContentView .onChange(of: scenePhase) when entering .background.
    func onBackground() {
        stopPolling()
        stopConnectivityObserver()
        BackgroundRefreshService.scheduleNext()
    }

    /// Call when returning to .active scene phase.
    func onForeground() {
        reloadCacheForActivePark()
        refreshIfNeeded(parkId: activeParkId)
        startPolling()
        startConnectivityObserver()
    }

    // MARK: - Manual refresh (pull-to-refresh)

    func refresh() async {
        await fetchAndCache(parkId: activeParkId)
    }

    // MARK: - Polling

    private func startPolling() {
        guard taskHandles.polling == nil || taskHandles.polling?.isCancelled == true else { return }

        taskHandles.polling = Task { [weak self] in
            guard let self else { return }
            // Initial fetch on start (delay slightly for UI to settle)
            try? await Task.sleep(for: .milliseconds(500))
            await self.fetchAndCache(parkId: self.activeParkId)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pollingIntervalSeconds))
                guard !Task.isCancelled else { break }
                // Only poll if connected — don't waste battery hitting a dead endpoint
                if self.connectivity.isConnected {
                    await self.fetchAndCache(parkId: self.activeParkId)
                }
            }
        }
    }

    private func stopPolling() {
        taskHandles.polling?.cancel()
        taskHandles.polling = nil
    }

    // MARK: - Connectivity observer

    /// Connectivity observer: when we regain connection, fetch immediately
    /// rather than waiting up to 3 minutes for the next poll tick.
    ///
    /// The guard mirrors startPolling — only one observer task runs at a time.
    /// Stopped symmetrically with stopConnectivityObserver() so no orphaned
    /// tasks accumulate across onBackground / onForeground / onAppear cycles.
    private func startConnectivityObserver() {
        guard taskHandles.connectivityObserver == nil || taskHandles.connectivityObserver?.isCancelled == true else { return }

        taskHandles.connectivityObserver = Task { [weak self] in
            guard let self else { return }
            var wasConnected = self.connectivity.isConnected

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                // `self` is already a strong non-optional binding from the guard above —
                // a second `guard let self` here would be a compile error (non-Optional).
                let isNowConnected = self.connectivity.isConnected
                if !wasConnected && isNowConnected {
                    // Just reconnected — fetch fresh data immediately
                    await self.fetchAndCache(parkId: self.activeParkId)
                }
                wasConnected = isNowConnected
            }
        }
    }

    private func stopConnectivityObserver() {
        taskHandles.connectivityObserver?.cancel()
        taskHandles.connectivityObserver = nil
    }

    // MARK: - Fetch orchestration

    /// Fetch if the cache is stale or missing — avoids redundant fetches.
    private func refreshIfNeeded(parkId: String) {
        guard connectivity.isConnected else { return }
        guard fetchPhase[parkId] != .loading else { return }

        // Check cache age before hitting the network
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WaitTimeCache>(
            predicate: #Predicate<WaitTimeCache> { $0.parkId == parkId }
        )
        let existing = try? context.fetch(descriptor)
        // fetchedAt is a non-optional Date — use map, not compactMap
        let oldest = existing?.map(\.fetchedAt).min()

        let cacheAge = oldest.map { Date().timeIntervalSince($0) } ?? .infinity
        if cacheAge < pollingIntervalSeconds {
            return  // Cache is fresh enough — skip fetch
        }

        Task {
            await fetchAndCache(parkId: parkId)
        }
    }

    /// Core fetch + write + reload cycle.
    @discardableResult
    func fetchAndCache(parkId: String) async -> Bool {
        guard connectivity.isConnected else {
            // Ensure stale flag is set on existing cache
            markCacheStale(parkId: parkId)
            return false
        }

        fetchPhase[parkId] = .loading

        do {
            let dto = try await service.fetchParkLive(parkId: parkId)

            // Merge + save + read-back all happen on persistenceActor's background
            // executor — never blocks the main thread. The returned [LiveRideState]
            // value types are Sendable and safe to assign directly to @MainActor state.
            let states = try await persistenceActor.mergeAndSave(
                dto:                dto,
                stalenessThreshold: stalenessThresholdSeconds
            )

            fetchPhase[parkId] = .success(fetchedAt: Date())

            // Assign the background-built snapshot directly — no second read needed.
            if parkId == activeParkId {
                liveRides = states
            }
            return true
        } catch let error as WaitTimeError {
            fetchPhase[parkId] = .failure(error)
            // Mark existing cache stale on error so UI shows the banner
            if error == .offline || error == .requestTimeout {
                markCacheStale(parkId: parkId)
            }
            return false
        } catch {
            fetchPhase[parkId] = .failure(.unknown(error.localizedDescription))
            return false
        }
    }

    // MARK: - Cache reads

    /// Read WaitTimeCache from SwiftData and populate liveRides.
    /// Called after every write and when activeParkId changes.
    private func reloadCacheForActivePark() {
        let parkId = activeParkId
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WaitTimeCache>(
            predicate: #Predicate<WaitTimeCache> { $0.parkId == parkId }
        )

        guard let cached = try? context.fetch(descriptor) else {
            liveRides = []
            return
        }

        liveRides = cached.map { entry in
            LiveRideState(
                id:                     entry.rideId,
                name:                   entry.rideName,
                land:                   "",
                parkId:                 entry.parkId,
                status:                 entry.status,
                waitMinutes:            entry.waitMinutes,
                singleRiderWaitMinutes: entry.singleRiderWaitMinutes,
                lightningLaneAvailable: entry.lightningLaneAvailable,
                trend:                  entry.trend,
                trendDeltaMinutes:      entry.trendDeltaMinutes,
                fetchedAt:              entry.fetchedAt,
                isStale:                entry.isStale || isEntryStale(entry)
            )
        }
    }

    /// Lookup live state for a local Ride by matching the backend's display name.
    ///
    /// Uses a two-pass approach:
    ///   1. Normalized exact match (strips ™ ® curly quotes punctuation — handles
    ///      ThemeParks.wiki quirks like "Indiana Jones™ Adventure: Temple of the Forbidden Eye")
    ///   2. Substring containment fallback (handles long API names that contain the seeder name)
    func liveState(matching ride: Ride) -> LiveRideState? {
        let target = Self.normalizedForMatching(ride.name)
        // Pass 1: exact normalized match
        if let hit = liveRides.first(where: { Self.normalizedForMatching($0.name) == target }) {
            return hit
        }
        // Pass 2: substring (e.g. "Indiana Jones Adventure" ⊂ "Indiana Jones™ Adventure: ...")
        return liveRides.first(where: {
            let api = Self.normalizedForMatching($0.name)
            return api.contains(target) || target.contains(api)
        })
    }

    /// Normalizes a ride name for fuzzy matching:
    /// • lowercase
    /// • strips ™ ® and similar Unicode decorators
    /// • collapses curly/smart quotes → straight apostrophe
    /// • removes terminal punctuation (!, ~)
    /// • strips separator characters that vary between sources:
    ///     - ":" removed  (e.g. "Guardians of the Galaxy: Cosmic Rewind" → "Guardians of the Galaxy Cosmic Rewind")
    ///     - "-" → space  (e.g. API "Under the Sea - Journey…" matches JSON "Under the Sea ~ Journey…")
    ///     - "/" → space  (e.g. "TRON Lightcycle / Run" → "TRON Lightcycle  Run" → collapsed)
    /// • collapses whitespace
    static func normalizedForMatching(_ s: String) -> String {
        s
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'") // RIGHT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2018}", with: "'") // LEFT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{02BC}", with: "'") // MODIFIER LETTER APOSTROPHE
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Legacy exact-ID lookup — kept for any callers that already have a backend rideId.
    func liveState(for rideId: String) -> LiveRideState? {
        liveRides.first { $0.id == rideId }
    }

    // MARK: - Stale helpers

    private func isEntryStale(_ entry: WaitTimeCache) -> Bool {
        Date().timeIntervalSince(entry.fetchedAt) > stalenessThresholdSeconds
    }

    private func markCacheStale(parkId: String) {
        liveRides = liveRides.map { state in
            guard state.parkId == parkId else { return state }
            return LiveRideState(
                id:                     state.id,
                name:                   state.name,
                land:                   state.land,
                parkId:                 state.parkId,
                status:                 state.status,
                waitMinutes:            state.waitMinutes,
                singleRiderWaitMinutes: state.singleRiderWaitMinutes,
                lightningLaneAvailable: state.lightningLaneAvailable,
                trend:                  state.trend,
                trendDeltaMinutes:      state.trendDeltaMinutes,
                fetchedAt:              state.fetchedAt,
                isStale:                true
            )
        }
    }

    // MARK: - Phase helpers for views

    var isLoadingActivePark: Bool {
        fetchPhase[activeParkId]?.isLoading ?? false
    }

    var hasDataForActivePark: Bool {
        !liveRides.isEmpty
    }

    func clearError() {
        fetchPhase[activeParkId] = .idle
    }
}

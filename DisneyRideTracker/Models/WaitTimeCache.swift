// WaitTimeCache.swift — SwiftData model for locally-cached live wait-time data.
//
// Lifecycle:
//   • Written by WaitTimeViewModel after every successful network fetch.
//   • Read by WaitTimeViewModel to populate HomeView / MyDayView.
//   • Never manually managed by the user — purely ephemeral operational data.
//   • Separate from Ride / RideLog (those are permanent user history).
//
// One row per ride. Each refresh overwrites the existing row via upsert.

import SwiftData
import Foundation

@Model final class WaitTimeCache {

    // ── Identity ──────────────────────────────────────────────────────────────
    /// Backend ride slug (e.g. "mk-space-mountain"). Unique so upsert works.
    /// NOTE: this does NOT match Ride.id (which is a stableID composite).
    ///       Use rideName for cross-referencing with the local Ride catalog.
    @Attribute(.unique) var rideId: String
    var parkId: String

    /// Human-readable ride name from the backend (e.g. "Space Mountain").
    /// Used to match WaitTimeCache rows to local Ride objects by name.
    var rideName: String

    // ── Live data ─────────────────────────────────────────────────────────────
    /// nil when the ride is closed, down, or not yet returned by the backend.
    var waitMinutes: Int?
    var singleRiderWaitMinutes: Int?
    var lightningLaneAvailable: Bool

    /// RideStatus rawValue: "OPERATING" | "DOWN" | "CLOSED" | "REFURBISHMENT" | "UNKNOWN"
    var statusRaw: String

    /// Trend rawValue: "RISING" | "FALLING" | "STABLE" | "UNKNOWN"
    var trendRaw: String

    /// Signed delta vs. 15-minutes-ago snapshot (backend-computed). Negative = shorter.
    var trendDeltaMinutes: Int

    // ── Freshness ─────────────────────────────────────────────────────────────
    /// When the backend fetched this row from the provider (ISO 8601 from backend).
    var fetchedAt: Date

    /// How many seconds old the backend's own cache was when it responded.
    var backendCacheAgeSeconds: Int

    /// true when data is older than WaitTimeViewModel.stalenessThreshold.
    var isStale: Bool

    /// Which provider served this data ("themeparks" | "queuetimes" | "cache-only").
    var sourceRaw: String

    // ── Convenience computed properties (not persisted) ───────────────────────

    var status: RideStatus {
        RideStatus(rawValue: statusRaw) ?? .unknown
    }

    var trend: WaitTrend {
        WaitTrend(rawValue: trendRaw) ?? .unknown
    }

    var source: WaitTimeSource {
        WaitTimeSource(rawValue: sourceRaw) ?? .cacheOnly
    }

    /// How stale this specific row is from the device's perspective.
    var localAgeSeconds: Int {
        Int(Date().timeIntervalSince(fetchedAt))
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    init(
        rideId: String,
        parkId: String,
        rideName: String,
        waitMinutes: Int?,
        singleRiderWaitMinutes: Int?,
        lightningLaneAvailable: Bool,
        statusRaw: String,
        trendRaw: String,
        trendDeltaMinutes: Int,
        fetchedAt: Date,
        backendCacheAgeSeconds: Int,
        isStale: Bool,
        sourceRaw: String
    ) {
        self.rideId                  = rideId
        self.parkId                  = parkId
        self.rideName                = rideName
        self.waitMinutes             = waitMinutes
        self.singleRiderWaitMinutes  = singleRiderWaitMinutes
        self.lightningLaneAvailable  = lightningLaneAvailable
        self.statusRaw               = statusRaw
        self.trendRaw                = trendRaw
        self.trendDeltaMinutes       = trendDeltaMinutes
        self.fetchedAt               = fetchedAt
        self.backendCacheAgeSeconds  = backendCacheAgeSeconds
        self.isStale                 = isStale
        self.sourceRaw               = sourceRaw
    }
}

// MARK: - Supporting enums

enum RideStatus: String {
    case operating     = "OPERATING"
    case down          = "DOWN"
    case closed        = "CLOSED"
    case refurbishment = "REFURBISHMENT"
    case unknown       = "UNKNOWN"

    var isRideable: Bool { self == .operating }

    var displayLabel: String {
        switch self {
        case .operating:     return "Open"
        case .down:          return "Temporarily Down"
        case .closed:        return "Closed"
        case .refurbishment: return "Refurbishment"
        case .unknown:       return "Unknown"
        }
    }
}

enum WaitTrend: String {
    case rising  = "RISING"
    case falling = "FALLING"
    case stable  = "STABLE"
    case unknown = "UNKNOWN"

    /// SF Symbol name for the trend arrow.
    var systemImage: String {
        switch self {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return "arrow.right"
        case .unknown: return "minus"
        }
    }
}

enum WaitTimeSource: String {
    case themeparks = "themeparks"
    case queuetimes = "queuetimes"
    case cacheOnly  = "cache-only"
}

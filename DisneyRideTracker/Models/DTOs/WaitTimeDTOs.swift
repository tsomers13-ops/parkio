// WaitTimeDTOs.swift — Decodable types that mirror the backend JSON contract.
//
// These types are ONLY used inside WaitTimeService for decoding.
// ViewModels and Views never touch DTOs — they use WaitTimeCache (SwiftData)
// and WaitTimeViewModel's computed properties instead.
//
// Backend contract defined in: backend/src/models/types.ts

import Foundation

// MARK: - Park Live Response

/// Top-level response from GET /v1/parks/:parkId/live
struct ParkLiveDTO: Decodable {
    let parkId: String
    let fetchedAt: String       // ISO 8601
    let servedAt: String        // ISO 8601
    let cacheAgeSeconds: Int
    let stale: Bool
    let source: String          // "themeparks" | "queuetimes" | "cache-only"
    let rides: [LiveRideDTO]
}

/// One ride entry in the live response.
struct LiveRideDTO: Decodable {
    let rideId: String
    let name: String
    let land: String
    let status: String                      // RideStatus rawValue
    let waitMinutes: Int?
    let singleRiderWaitMinutes: Int?
    let lightningLaneAvailable: Bool
    let trend: String                       // WaitTrend rawValue
    let trendDeltaMinutes: Int
    let lastUpdatedAt: String               // ISO 8601
}

// MARK: - Error Response

/// Structured error body returned by backend on 4xx/5xx.
struct APIErrorDTO: Decodable {
    let error: String
    let message: String
    let retryAfterSeconds: Int?
}

// MARK: - Snapshots Response

/// Response from GET /v1/rides/:rideId/snapshots
struct SnapshotsResponseDTO: Decodable {
    let rideId: String
    let count: Int
    let snapshots: [SnapshotDTO]
}

struct SnapshotDTO: Decodable {
    let waitMinutes: Int?
    let status: String
    let trend: String
    let trendDeltaMinutes: Int
    let recordedAt: String      // ISO 8601
    let source: String
}

// MARK: - Parks Catalog Response

struct ParksResponseDTO: Decodable {
    let parks: [ParkDTO]
}

struct ParkDTO: Decodable {
    let id: String
    let name: String
    let shortName: String
    let resort: String
    let timezone: String
}

// MARK: - Health Response (for debug/settings screen)

struct HealthResponseDTO: Decodable {
    let status: String
    let version: String
    let provider: String
    let redisConnected: Bool
    let lastCronRunAt: String?
}

// MARK: - Decoder Helper

extension JSONDecoder {
    /// Decoder configured for the backend's ISO 8601 date strings.
    static func backendDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

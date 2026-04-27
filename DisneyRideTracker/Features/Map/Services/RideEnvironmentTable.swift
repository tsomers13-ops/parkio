// RideEnvironmentTable.swift — Indoor / outdoor classification for ride ranking.
//
// Purpose:
//   WeatherSignal-aware ranking in bestNextRide needs to know whether a ride is
//   exposed to weather. This table is the single source of truth for that decision.
//
// Design:
//   Only outdoor rides are listed. Any ride not in the set is treated as indoor
//   (the safe default — an unknown ride will never be incorrectly pushed outdoors).
//
// Lookup:
//   RideEnvironmentTable.isOutdoor(_ ride: Ride) → Bool
//   Uses ride.id (the stableID: "Park.rawValue|land|name") for O(1) lookup.
//
// Maintenance:
//   Add a ride here when it has meaningful outdoor exposure — meaning guests
//   would experience rain, direct sun, or weather during the ride or its queue.
//   Do NOT list indoor dark rides, enclosed simulators, or covered theatres.
//
// stableID format: "{Park.rawValue}|{land}|{name}"

import Foundation

enum RideEnvironmentTable {

    // MARK: - Public API

    static func isOutdoor(_ ride: Ride) -> Bool {
        outdoorIDs.contains(ride.id)
    }

    // MARK: - Outdoor ride registry

    /// Derived from RideMasterData — the single source of truth for outdoor classification.
    /// To mark a ride as outdoor, set `outdoor: true` on its MasterAttraction entry.
    private static var outdoorIDs: Set<String> { RideMasterData.outdoorStableIDs }
}

// MARK: - DEBUG validation

#if DEBUG
extension RideEnvironmentTable {

    /// Logs any outdoor stableID that no longer matches a canonical RideSeeder ride.
    /// Run this after any seeder update to catch stale entries.
    static func validateOutdoorIDs() {
        let canonical = RideSeeder.canonicalRideIDs
        let stale = outdoorIDs.subtracting(canonical).sorted()

        if stale.isEmpty {
            print("✅ RideEnvironmentTable: all \(outdoorIDs.count) outdoor IDs are canonical")
        } else {
            for id in stale {
                print("⚠️ RideEnvironmentTable: '\(id)' is not a canonical stableID — may be stale")
            }
        }

        // Coverage summary
        let indoorCount = canonical.count - canonical.intersection(outdoorIDs).count
        let outdoorCount = canonical.intersection(outdoorIDs).count
        print("ℹ️ RideEnvironmentTable: \(outdoorCount) outdoor, \(indoorCount) indoor (default) of \(canonical.count) total")
    }
}
#endif

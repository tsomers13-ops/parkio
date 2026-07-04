//
//  RideSeeder.swift
//  Parkio
//
//  Populates the SwiftData store with the canonical ride list on every launch
//  and migrates older schemas in place so user logs are preserved across
//  structural changes to the park/land hierarchy.
//
//  Stale-row cleanup (runs every call):
//  ─────────────────────────────────────
//  Pass 1 — DELETE: rides whose `id` is not in the current canonical seed set
//    AND not in RideMasterData.typeByStableID. These are phantom rows from
//    pre-RideMasterData schemas, attractions removed from the park, or IDs
//    produced by an older seeder format. Deletion cascades to RideLogs.
//    (History for a non-existent attraction is not meaningful.)
//
//  Pass 2 — CORRECT IN-PLACE: rides whose `id` IS canonical but whose stored
//    `park`, `land`, or `name` fields have drifted from master data (e.g. a
//    botched migration, a partial overwrite). Corrected without deletion so
//    the user's ride-log history is preserved.
//
//  The same canonical gate (typeByStableID) used for stale-row removal is used
//  in HomeView at query time — so the two layers always agree on what is valid.
//

import Foundation
import SwiftData

enum RideSeeder {

    /// A structural description of a ride used only for seeding.
    struct Seed {
        let name: String
        let park: Park
        let land: String
    }

    /// Older schemas may have used different park names (e.g. the initial
    /// release grouped all four WDW parks under the single park "Walt Disney
    /// World"). When we look for an existing ride to migrate, we also try
    /// these legacy park names keyed by current park.
    private static let legacyParkNames: [Park: [String]] = [
        .magicKingdom:      ["Walt Disney World"],
        .epcot:             ["Walt Disney World"],
        .hollywoodStudios:  ["Walt Disney World"],
        .animalKingdom:     ["Walt Disney World"]
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Ride>()
        let existing = (try? context.fetch(descriptor)) ?? []

        // Look up existing rides by id AND by (park, name) so we can migrate a
        // ride whose land was renamed — or whose park was split into several
        // sub-parks — without losing the user's logged dates.
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var byParkName: [String: Ride] = [:]
        for ride in existing {
            byParkName["\(ride.park)|\(ride.name)"] = ride
        }

        var seenIDs = Set<String>()

        for (index, seed) in allSeeds.enumerated() {
            let newID = seed.stableID
            seenIDs.insert(newID)

            // 1. Exact id match — schema already current.
            if let ride = byID[newID] {
                ride.order = index
                continue
            }

            // 2. Same current park + ride name — land was renamed.
            if let ride = byParkName["\(seed.park.rawValue)|\(seed.name)"] {
                ride.id = newID
                ride.land = seed.land
                ride.order = index
                byID[newID] = ride
                continue
            }

            // 3. Legacy park rename (e.g. "Walt Disney World" → "Magic Kingdom").
            if let legacy = legacyParkNames[seed.park] {
                var migrated = false
                for legacyPark in legacy {
                    if let ride = byParkName["\(legacyPark)|\(seed.name)"] {
                        ride.id = newID
                        ride.park = seed.park.rawValue
                        ride.land = seed.land
                        ride.order = index
                        byID[newID] = ride
                        migrated = true
                        break
                    }
                }
                if migrated { continue }
            }

            // 4. Brand new ride.
            let ride = Ride(
                id: newID,
                name: seed.name,
                park: seed.park.rawValue,
                land: seed.land,
                order: index
            )
            context.insert(ride)
            byID[newID] = ride
        }

        // ── Pass 1: Remove stale rides ────────────────────────────────────────
        //
        // A ride is stale when its `id` is absent from the canonical seed set
        // OR from typeByStableID. Either condition alone is sufficient to prove the
        // ride has no valid corresponding master-data entry.
        //
        // Using typeByStableID as the authoritative gate (rather than only seenIDs)
        // ensures this cleanup logic stays in sync with the HomeView guard that
        // excludes rides at query time. If the two ever diverge, the more restrictive
        // check (not in typeByStableID) wins.
        //
        // ⚠️  Cascade: RideLog entries for deleted rides are also deleted.
        //     This is intentional — logs for non-existent attractions are not
        //     recoverable or meaningful to the user.
        var deletedIDSet  = Set<String>()  // for pass-2 guard
        var staleRemovedLog = [String]()   // for DEBUG output

        for ride in existing {
            let inSeedSet    = seenIDs.contains(ride.id)
            let inMasterData = RideMasterData.typeByStableID[ride.id] != nil

            // Delete if absent from EITHER the seed set OR typeByStableID.
            // The two should always agree; if they diverge (e.g. a ride was removed
            // from seedableAttractions but left in `all`, or vice-versa), err on the
            // side of removal to prevent silent ride-count inflation at query time.
            if !inSeedSet || !inMasterData {
                let reason = !inSeedSet ? "not in canonical seeds" : "not in typeByStableID"
                staleRemovedLog.append("\(ride.id)  [\(reason)]")
                deletedIDSet.insert(ride.id)
                context.delete(ride)
            }
        }

        // ── Pass 2: Correct drifted metadata in-place ────────────────────────
        //
        // Rides whose stableID is valid but whose stored park/land/name have
        // drifted from master data are corrected without deletion, preserving logs.
        var correctedIDs = [String]()
        for ride in existing where !deletedIDSet.contains(ride.id) {
            guard let master = masterByStableID[ride.id] else { continue }
            var didFix = false
            if ride.park != master.park.rawValue { ride.park = master.park.rawValue; didFix = true }
            if ride.land != master.land          { ride.land = master.land;          didFix = true }
            if ride.name != master.name          { ride.name = master.name;          didFix = true }
            if didFix { correctedIDs.append(ride.id) }
        }

        try? context.save()

#if DEBUG
        printSeedSummary(staleRemoved: staleRemovedLog, corrected: correctedIDs)
        validateLandAssignments()
#endif
    }

    // MARK: - Ride List

    /// Derived from RideMasterData — the single source of truth for all park attractions.
    /// Adding, removing, or renaming a ride is done exclusively in RideMasterData.swift;
    /// this seeder picks up the change automatically on next launch.
    static let allSeeds: [Seed] = RideMasterData.seedableAttractions.map {
        Seed(name: $0.name, park: $0.park, land: $0.land)
    }

    static var canonicalRideIDs: Set<String> {
        Set(allSeeds.map(\.stableID))
    }

    // MARK: - Private helpers

    /// Cached stableID → MasterAttraction lookup for seeded attractions only.
    /// Used by pass-2 metadata correction.
    private static let masterByStableID: [String: MasterAttraction] = {
        var map = [String: MasterAttraction](minimumCapacity: RideMasterData.seedableAttractions.count)
        for a in RideMasterData.seedableAttractions { map[a.stableID] = a }
        return map
    }()
}

private extension RideSeeder.Seed {
    /// Deterministic unique ID so we can add new rides in later versions of the
    /// app without duplicating rides that already exist in the user's database.
    var stableID: String {
        "\(park.rawValue)|\(land)|\(name)"
    }
}

// MARK: - DEBUG validation & summary

#if DEBUG
private extension RideSeeder {

    /// Prints the stale-cleanup summary and per-park seeded counts.
    /// Called at the end of every seedIfNeeded run in DEBUG builds.
    static func printSeedSummary(staleRemoved: [String], corrected: [String]) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🌱 RideSeeder — seed summary")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // ── Stale-row report ─────────────────────────────────────────────
        if staleRemoved.isEmpty {
            print("✅ Stale rows removed : 0  (no phantom or unrecognised IDs)")
        } else {
            print("🗑️  Stale rows removed : \(staleRemoved.count)")
            for entry in staleRemoved {
                print("   — \(entry)")
            }
            print("   ↳ Ride logs for these attractions were cascade-deleted.")
        }

        // ── Metadata-correction report ────────────────────────────────────
        if corrected.isEmpty {
            print("✅ Metadata corrections: 0  (all park/land/name fields match master data)")
        } else {
            print("🔧 Metadata corrections: \(corrected.count)  (park/land/name fixed in-place; logs preserved)")
            for id in corrected {
                print("   ~ \(id)")
            }
        }

        // ── Per-park seeded counts ────────────────────────────────────────
        print("────────────────────────────────────────────")
        print("📊 Final seeded counts per park:")
        for park in Park.allCases {
            let seeds      = allSeeds.filter { $0.park == park }
            let rideSeeds  = seeds.filter { RideMasterData.typeByStableID[$0.stableID] == .ride }
            let nonRide    = seeds.count - rideSeeds.count
            print("   \(park.rawValue.padding(toLength: 28, withPad: " ", startingAt: 0))"
                + "\(seeds.count) total  "
                + "(\(rideSeeds.count) rides · \(nonRide) non-rides excluded from counts)")
        }
        let totalSeeds     = allSeeds.count
        let totalRideSeeds = allSeeds.filter { RideMasterData.typeByStableID[$0.stableID] == .ride }.count
        print("   \("TOTAL".padding(toLength: 28, withPad: " ", startingAt: 0))"
            + "\(totalSeeds) total  "
            + "(\(totalRideSeeds) rides · \(totalSeeds - totalRideSeeds) non-rides)")

        // ── typeByStableID coverage check ─────────────────────────────────
        // Every seeded ID should appear in typeByStableID. A gap here means
        // seedableAttractions and all have diverged — investigate RideMasterData.
        let missingFromIndex = allSeeds.filter {
            RideMasterData.typeByStableID[$0.stableID] == nil
        }
        if missingFromIndex.isEmpty {
            print("✅ typeByStableID coverage: all \(totalSeeds) seeds present")
        } else {
            print("⚠️  typeByStableID GAPS — \(missingFromIndex.count) seed(s) missing from index:")
            for seed in missingFromIndex {
                print("   ⚠️  \(seed.stableID)")
            }
            print("   ↳ These IDs will be EXCLUDED from ride counts at query time.")
            print("   ↳ Check that seedableAttractions and all are consistent in RideMasterData.")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// Logs any seed whose land is not present in Park.lands for that park.
    /// Catches mismatches between seeder land strings and the canonical land list.
    static func validateLandAssignments() {
        var mismatches: [(Seed, String)] = []
        for seed in allSeeds {
            if !seed.park.lands.contains(seed.land) {
                mismatches.append((seed, "land '\(seed.land)' not in Park.lands for \(seed.park.rawValue)"))
            }
        }
        if !mismatches.isEmpty {
            for (seed, reason) in mismatches {
                print("⚠️ RideSeeder: \(seed.park.rawValue) — \(seed.name) — \(reason)")
            }
        }

        // Detect duplicate stableIDs (would cause SwiftData constraint violation).
        let ids = allSeeds.map(\.stableID)
        let dupes = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys
        for dupe in dupes.sorted() {
            print("⚠️ RideSeeder: duplicate stableID '\(dupe)'")
        }
    }
}
#endif

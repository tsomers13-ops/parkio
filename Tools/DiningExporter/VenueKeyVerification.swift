//
//  VenueKeyVerification.swift
//  dining-export
//
//  Cross-checks the generated venueKey mapping against the real Dining models.
//
//  The Website owns venueKey; this app owns the venues. Neither side can see
//  the other at build time, so this is where the two are reconciled — against
//  the actual 86 venues, not a fixture that could drift.
//
//  It reads the JSON sidecar the Website generator emits, never the generated
//  Swift file: parsing Swift source to recover data it already has would be
//  exactly the fragility this pipeline exists to avoid.
//
//  Every check fails closed. A mapping that is wrong is worse than no mapping,
//  because it would file a guest's rating against someone else's restaurant.
//

import Foundation

enum VenueKeyVerification {

    struct Sidecar: Decodable {
        let sourceSha256: String
        let count: Int
        let byStableID: [String: String]
    }

    struct Result {
        var eligible: [String]
        var ineligible: [String]
        var problems: [String]
        var sourceSha256: String
    }

    /// Parks whose venues the ratings backend accepts today.
    static let pilotParkIds: Set<String> = ["epcot", "hollywood-studios"]

    static func verify(
        sidecarPath: String,
        venues: [(stableID: String, parkId: String, name: String)]
    ) throws -> Result {
        let data = try Data(contentsOf: URL(fileURLWithPath: sidecarPath))
        let sidecar = try JSONDecoder().decode(Sidecar.self, from: data)
        let mapping = sidecar.byStableID

        var problems: [String] = []

        // The pilot boundary, taken from the app's own data.
        let eligible = venues.filter { pilotParkIds.contains($0.parkId) }
        let ineligible = venues.filter { !pilotParkIds.contains($0.parkId) }

        // 1. Every eligible venue must have a venueKey.
        for venue in eligible where mapping[venue.stableID] == nil {
            problems.append("eligible venue has no venueKey: \(venue.stableID)")
        }

        // 2. No venue outside the pilot may have one — that would mean the
        //    backend quietly expanded without an explicit gate.
        for venue in ineligible where mapping[venue.stableID] != nil {
            problems.append("venue outside the pilot has a venueKey: \(venue.stableID)")
        }

        // 3. No mapping may point at a venue this app does not have.
        let known = Set(venues.map(\.stableID))
        for stableID in mapping.keys where !known.contains(stableID) {
            problems.append("venueKey mapped to an unknown venue: \(stableID)")
        }

        // 4. Two venues must never share a venueKey.
        var seen: [String: String] = [:]
        for (stableID, key) in mapping.sorted(by: { $0.key < $1.key }) {
            if let first = seen[key] {
                problems.append("venueKey '\(key)' is claimed by both \(first) and \(stableID)")
            }
            seen[key] = stableID
        }

        // 5. The count must match both the sidecar's own claim and the pilot.
        if mapping.count != sidecar.count {
            problems.append("sidecar claims \(sidecar.count) entries but contains \(mapping.count)")
        }
        if mapping.count != eligible.count {
            problems.append(
                "mapping has \(mapping.count) entries but \(eligible.count) venues are eligible"
            )
        }

        return Result(
            eligible: eligible.map(\.stableID).sorted(),
            ineligible: ineligible.map(\.stableID).sorted(),
            problems: problems,
            sourceSha256: sidecar.sourceSha256
        )
    }
}

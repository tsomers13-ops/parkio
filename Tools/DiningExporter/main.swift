//
//  main.swift
//  dining-export
//
//  Exports every Dining venue from the real Parkio Swift models to a
//  deterministic JSON document. Two runs against an unchanged working tree
//  must produce byte-identical output.
//
//  Usage: dining-export --output <path> [--repo <path>]
//

import Foundation

// MARK: - Arguments

func argument(_ name: String, default fallback: String? = nil) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
    return args[i + 1]
}

guard let outputPath = argument("--output") else {
    FileHandle.standardError.write(Data("usage: dining-export --output <path> [--repo <path>]\n".utf8))
    exit(2)
}
let repo = URL(fileURLWithPath: argument("--repo", default: FileManager.default.currentDirectoryPath)!)
    .standardizedFileURL

/// Dining types this exporter knows how to serialize. A new dining case added
/// to AttractionType will fail the run loudly rather than export silently.
let supportedDiningTypes: Set<String> = [
    "quickService", "snackStand", "tableService", "lounge", "festivalBooth"
]

do {
    // MARK: - Provenance

    let provenance = try GitProvenance.resolve(repo: repo)

    // MARK: - Source data (real models — no parsing)

    #if DEBUG
    // Reuse the app's own integrity checks; prints warnings, never throws.
    RideMasterData.validate()
    #endif

    let diningAttractions = RideMasterData.all.filter { $0.type.isDining }
    let (coordinateIndex, coordinateDuplicates) = try CoordinateSource.load(repo: repo)

    // MARK: - Validation

    var failures: [String] = []

    let idCounts = Dictionary(grouping: diningAttractions.map(\.stableID), by: { $0 })
        .filter { $0.value.count > 1 }.keys.sorted()
    for id in idCounts { failures.append("duplicate dining stableID: \(id)") }

    for id in coordinateDuplicates {
        failures.append("duplicate coordinate id in \(CoordinateSource.relativePath): \(id)")
    }

    for attraction in diningAttractions where !supportedDiningTypes.contains(attraction.type.rawValue) {
        failures.append("unsupported dining type '\(attraction.type.rawValue)' on \(attraction.stableID)")
    }

    for attraction in diningAttractions {
        guard let coordinate = coordinateIndex[attraction.stableID] else { continue }
        if !coordinate.lat.isFinite || !coordinate.lon.isFinite
            || coordinate.lat < -90 || coordinate.lat > 90
            || coordinate.lon < -180 || coordinate.lon > 180
            || (coordinate.lat == 0 && coordinate.lon == 0) {
            failures.append("malformed coordinate for \(attraction.stableID): (\(coordinate.lat), \(coordinate.lon))")
        }
        if coordinate.parkId != attraction.park.backendId {
            failures.append("coordinate parkId '\(coordinate.parkId)' != model parkId '\(attraction.park.backendId)' for \(attraction.stableID)")
        }
    }

    guard failures.isEmpty else { throw ExportError.validation(failures) }

    // MARK: - Build (deterministic ordering)

    let venues: [DiningVenue] = diningAttractions
        .map { attraction in
            let coordinate = coordinateIndex[attraction.stableID]
                .map { ExportCoordinate(lat: $0.lat, lon: $0.lon) }

            let editorial = attraction.dining.map { metadata in
                Editorial(
                    priceTier: metadata.priceTier.rawValue,
                    parkioScore: metadata.parkioScore,
                    shortVerdict: metadata.shortVerdict,
                    signatureItems: metadata.signatureItems,
                    mobileOrderAvailable: metadata.mobileOrderAvailable,
                    indoorSeating: metadata.indoorSeating,
                    kidFriendly: metadata.kidFriendly,
                    dietaryFlags: metadata.dietaryFlags.map(\.rawValue).sorted()
                )
            }

            return DiningVenue(
                id: attraction.stableID,
                name: attraction.name,
                park: attraction.park.rawValue,
                parkId: attraction.park.backendId,
                land: attraction.land,
                type: attraction.type.rawValue,
                externalId: attraction.themeparksEntityId,
                coordinate: coordinate,
                editorial: editorial
            )
        }
        .sorted { $0.id < $1.id }

    let export = DiningExport(
        schemaVersion: 1,
        generator: "dining-export",
        sourceCommit: provenance.commit,
        sourceDirty: provenance.dirty,
        venueCount: venues.count,
        venues: venues
    )

    // MARK: - Encode

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    var data = try encoder.encode(export)
    data.append(0x0A)  // trailing newline

    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: outputURL, options: .atomic)

    // MARK: - Summary

    func tally<T: Hashable & Comparable>(_ key: (DiningVenue) -> T) -> String {
        Dictionary(grouping: venues, by: key)
            .map { "\($0.key)=\($0.value.count)" }.sorted().joined(separator: " ")
    }

    print("wrote \(outputURL.path) (\(data.count) bytes)")
    print("  sourceCommit : \(provenance.commit)")
    print("  sourceDirty  : \(provenance.dirty)")
    if provenance.dirty {
        for path in provenance.dirtyPaths { print("      dirty: \(path)") }
    }
    print("  venues       : \(venues.count)")
    print("  by park      : \(tally { $0.parkId })")
    print("  by type      : \(tally { $0.type })")
    print("  coordinates  : \(venues.filter { $0.coordinate != nil }.count)/\(venues.count)")
    print("  editorial    : \(venues.filter { $0.editorial != nil }.count) (factual-only \(venues.filter { $0.editorial == nil }.count))")
    print("  externalId   : \(venues.filter { $0.externalId != nil }.count) (absent \(venues.filter { $0.externalId == nil }.count))")

} catch {
    FileHandle.standardError.write(Data("dining-export: \(error)\n".utf8))
    exit(1)
}

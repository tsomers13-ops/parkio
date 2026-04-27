// MapCoordinateService.swift — Loads ride map positions.
//
// Coordinates are loaded from MapCoordinates.json in the app bundle. The JSON
// is the single source of truth so coordinate fixes cannot drift from a stale
// embedded fallback.
//
// JSON format:
//   The top-level object maps park backendId keys → arrays of ride entries.
//   Keys prefixed with "_" (e.g. "_comment", "_coord_note") are documentation
//   annotations and are silently skipped by MapCoordinatesFile. Any valid park
//   key whose value cannot be decoded as [MapRideAnnotation] is also skipped
//   with a DEBUG warning rather than aborting the entire decode.
//
// ── CRITICAL: why MapCoordinatesFile does NOT use a single-value container ────
//
//   The JSON file contains a top-level "_comment" key whose value is a [String]
//   array. A single-value-container decode of [String: [MapRideAnnotation]] hits
//   "_comment", tries to decode [String] as [MapRideAnnotation], and throws —
//   causing try? in MapCoordinateService.init to swallow the error and fall back
//   to annotationsByPark = [:]. The result is zero annotations and zero map pins.
//
//   The keyed-container approach below iterates allKeys, skips any key that
//   starts with "_", and decodes each remaining value independently so a single
//   malformed entry can never destroy all other parks.

import Foundation
import MapKit

// MARK: - JSON root

private struct MapCoordinatesFile: Decodable {
    let parks: [String: [MapRideAnnotation]]

    // Dynamic CodingKey so we can iterate every key in the top-level object.
    private struct ParkKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ParkKey.self)
        var result: [String: [MapRideAnnotation]] = [:]
        for key in container.allKeys {
            // Skip documentation / note fields ("_comment", "_coord_note", etc.).
            guard !key.stringValue.hasPrefix("_") else { continue }
            do {
                result[key.stringValue] = try container.decode([MapRideAnnotation].self, forKey: key)
            } catch {
                // A single undecodable park entry must not abort all other parks.
#if DEBUG
                print("⚠️ MapCoordinatesFile: failed to decode park '\(key.stringValue)': \(error)")
#endif
            }
        }
        self.parks = result
    }
}

// MARK: - Service

struct MapCoordinateService {

    private let annotationsByPark: [String: [MapRideAnnotation]]

    // MARK: - Init

    init(bundle: Bundle = .main) {
        if let url  = bundle.url(forResource: "MapCoordinates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(MapCoordinatesFile.self, from: data) {
            let parks = file.parks
#if DEBUG
            Self.validate(annotationsByPark: parks, source: "MapCoordinates.json")
            let allAnnotations = parks.values.flatMap { $0 }
            RideCoordinateTable.validatePriorityLookups(annotations: allAnnotations)
#endif
            annotationsByPark = parks
            return
        }
#if DEBUG
        print("⚠️ MapCoordinateService: MapCoordinates.json was not found or could not be decoded.")
#endif
        annotationsByPark = [:]
    }

    // MARK: - Public API

    func annotations(for parkId: String) -> [MapRideAnnotation] {
        annotationsByPark[parkId] ?? []
    }

    func annotation(forRideId rideId: String, parkId: String) -> MapRideAnnotation? {
        annotations(for: parkId).first { $0.id == rideId }
    }

    func hasCoordinates(for parkId: String) -> Bool {
        !(annotationsByPark[parkId]?.isEmpty ?? true)
    }

    static let shared = MapCoordinateService()

    // MARK: - Preview stub

    static func stub(for parkId: String = "magic-kingdom") -> MapCoordinateService {
        MapCoordinateService(preloaded: [
            parkId: [
                MapRideAnnotation.stub(id: "1", name: "Space Mountain",          lat: 28.4196, lon: -81.5759, category: .thrill),
                MapRideAnnotation.stub(id: "2", name: "Big Thunder Mountain",     lat: 28.4192, lon: -81.5838, category: .thrill),
                MapRideAnnotation.stub(id: "3", name: "Haunted Mansion",          lat: 28.4213, lon: -81.5833, category: .darkRide),
                MapRideAnnotation.stub(id: "4", name: "Pirates of the Caribbean", lat: 28.4191, lon: -81.5845, category: .darkRide),
                MapRideAnnotation.stub(id: "5", name: "it's a small world",       lat: 28.4218, lon: -81.5807, category: .family),
            ]
        ])
    }

    fileprivate init(preloaded: [String: [MapRideAnnotation]]) {
#if DEBUG
        Self.validate(annotationsByPark: preloaded, source: "preloaded coordinates")
#endif
        annotationsByPark = preloaded
    }
}

#if DEBUG
private extension MapCoordinateService {

    struct ParkBounds {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double

        func contains(_ annotation: MapRideAnnotation) -> Bool {
            annotation.latitude >= minLat
                && annotation.latitude <= maxLat
                && annotation.longitude >= minLon
                && annotation.longitude <= maxLon
        }
    }

    static let roughParkBounds: [String: ParkBounds] = [
        "magic-kingdom": .init(minLat: 28.4160, maxLat: 28.4230, minLon: -81.5865, maxLon: -81.5750),
        "epcot": .init(minLat: 28.3670, maxLat: 28.3765, minLon: -81.5545, maxLon: -81.5450),
        "hollywood-studios": .init(minLat: 28.3525, maxLat: 28.3610, minLon: -81.5650, maxLon: -81.5560),
        "animal-kingdom": .init(minLat: 28.3530, maxLat: 28.3630, minLon: -81.5945, maxLon: -81.5860),
        "disneyland": .init(minLat: 33.8090, maxLat: 33.8165, minLon: -117.9240, maxLon: -117.9160),
        "california-adventure": .init(minLat: 33.8040, maxLat: 33.8095, minLon: -117.9240, maxLon: -117.9160)
    ]

    static func validate(annotationsByPark: [String: [MapRideAnnotation]], source: String) {
        var ids: [String: [String]] = [:]
        var coordinateOwners: [String: [String]] = [:]
        let canonicalIDs = RideSeeder.canonicalRideIDs

        for (parkId, annotations) in annotationsByPark {
            for annotation in annotations {
                ids[annotation.id, default: []].append(parkId)

                // Wrong park assignment: annotation listed under a different parkId key than its own.
                if annotation.parkId != parkId {
                    print("⚠️ MapCoordinateService[\(source)]: WRONG PARK — \(annotation.id) has parkId=\(annotation.parkId) but is listed under '\(parkId)'.")
                }

                // Ride ID mismatch: annotation id not in the canonical seeder set.
                if !canonicalIDs.contains(annotation.id) {
                    print("⚠️ MapCoordinateService[\(source)]: ID MISMATCH — '\(annotation.id)' is not a canonical RideSeeder stableID.")
                }

                // Out-of-bounds coordinate check.
                if let bounds = roughParkBounds[parkId], !bounds.contains(annotation) {
                    print("⚠️ MapCoordinateService[\(source)]: BAD COORD — \(annotation.id) at (\(annotation.latitude), \(annotation.longitude)) is outside rough \(parkId) bounds.")
                }

                // Duplicate coordinate detection.
                let coordinateKey = String(format: "%.6f,%.6f", annotation.latitude, annotation.longitude)
                coordinateOwners[coordinateKey, default: []].append(annotation.id)
            }
        }

        // Duplicate ID detection across parks.
        for (id, parks) in ids where parks.count > 1 {
            print("⚠️ MapCoordinateService[\(source)]: DUPLICATE ID — '\(id)' appears in \(parks.joined(separator: ", ")).")
        }

        // Duplicate coordinate (two different rides sharing the same GPS pin).
        for (coordinate, owners) in coordinateOwners where owners.count > 1 {
            print("⚠️ MapCoordinateService[\(source)]: DUPLICATE COORD \(coordinate): \(owners.joined(separator: " | ")).")
        }

        // Missing coordinates: rides in the canonical seeder with no matching annotation.
        let jsonIDs = Set(ids.keys)
        let missing = canonicalIDs.subtracting(jsonIDs).sorted()
        if !missing.isEmpty {
            for id in missing {
                print("⚠️ MapCoordinateService[\(source)]: MISSING COORD — '\(id)' has no entry in \(source).")
            }
        } else {
            print("✅ MapCoordinateService[\(source)]: all \(canonicalIDs.count) canonical rides have coordinates.")
        }

        // Wrong land: JSON land field differs from the park's canonical land list.
        let parkByBackendId: [String: Park] = Dictionary(
            uniqueKeysWithValues: Park.allCases.map { ($0.backendId, $0) }
        )
        for (parkId, annotations) in annotationsByPark {
            guard let park = parkByBackendId[parkId] else { continue }
            let validLands = Set(park.lands)
            for annotation in annotations where !validLands.contains(annotation.land) {
                print("⚠️ MapCoordinateService[\(source)]: WRONG LAND — '\(annotation.rideName)' [\(parkId)] land='\(annotation.land)' not in Park.lands.")
            }
        }

        // ThemeParks.wiki entity ID coverage.
        // Every annotation whose entityId is still nil degrades wait-time matching
        // to name-based heuristics instead of O(1) ID lookup.
        // Populate via: GET https://api.themeparks.wiki/v1/entity/{park.themeparksEntityId}/live
        let allAnnotations  = annotationsByPark.values.flatMap { $0 }
        let withEntityId    = allAnnotations.filter { $0.entityId != nil }
        let missingEntityId = allAnnotations.filter { $0.entityId == nil }
        if missingEntityId.isEmpty {
            print("✅ MapCoordinateService[\(source)]: all \(allAnnotations.count) annotations have ThemeParks entity IDs.")
        } else {
            print("ℹ️ MapCoordinateService[\(source)]: entity ID coverage \(withEntityId.count)/\(allAnnotations.count) — \(missingEntityId.count) missing:")
            // Group by park so the output is easier to action.
            let byPark = Dictionary(grouping: missingEntityId, by: \.parkId)
            for parkId in byPark.keys.sorted() {
                let names = byPark[parkId]!.map(\.rideName).sorted()
                print("  [\(parkId)] — \(names.joined(separator: ", "))")
            }
            print("  → Populate entityId via GET https://api.themeparks.wiki/v1/entity/{park.themeparksEntityId}/live")
        }
    }
}
#endif

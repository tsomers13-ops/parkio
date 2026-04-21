// MapCoordinateService.swift — Loads ride map positions.
//
// Coordinates are loaded from MapCoordinates.json in the app bundle. The JSON
// is the single source of truth so coordinate fixes cannot drift from a stale
// embedded fallback.

import Foundation
import MapKit

// MARK: - JSON root

private struct MapCoordinatesFile: Decodable {
    let parks: [String: [MapRideAnnotation]]
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        parks = try container.decode([String: [MapRideAnnotation]].self)
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

                if annotation.parkId != parkId {
                    print("⚠️ MapCoordinateService[\(source)]: \(annotation.id) has parkId=\(annotation.parkId), but is listed under \(parkId).")
                }

                if !canonicalIDs.contains(annotation.id) {
                    print("⚠️ MapCoordinateService[\(source)]: \(annotation.id) is not a canonical RideSeeder stable ID.")
                }

                if let bounds = roughParkBounds[parkId], !bounds.contains(annotation) {
                    print("⚠️ MapCoordinateService[\(source)]: \(annotation.id) coordinate (\(annotation.latitude), \(annotation.longitude)) is outside rough \(parkId) bounds.")
                }

                let coordinateKey = String(format: "%.6f,%.6f", annotation.latitude, annotation.longitude)
                coordinateOwners[coordinateKey, default: []].append(annotation.id)
            }
        }

        for (id, parks) in ids where parks.count > 1 {
            print("⚠️ MapCoordinateService[\(source)]: duplicate annotation id \(id) appears in \(parks.joined(separator: ", ")).")
        }

        for (coordinate, owners) in coordinateOwners where owners.count > 1 {
            print("⚠️ MapCoordinateService[\(source)]: duplicate coordinate \(coordinate) is shared by \(owners.joined(separator: " | ")).")
        }
    }
}
#endif

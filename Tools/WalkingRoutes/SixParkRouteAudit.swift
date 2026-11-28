// Compile: xcrun swiftc -parse-as-library Tools/WalkingRoutes/SixParkRouteAudit.swift -o /tmp/parkio-six-park-route-audit
// Run:     /tmp/parkio-six-park-route-audit
//
// Live MapKit audit for representative high-priority attraction pairs in all
// six supported parks. Output is tab-separated so a dated run can be retained
// and compared without making live network results part of unit-test gating.

import Foundation
import CoreLocation
import MapKit

struct Sample {
    let park: String
    let firstName: String
    let first: CLLocationCoordinate2D
    let secondName: String
    let second: CLLocationCoordinate2D
}

let samples = [
    Sample(park: "Magic Kingdom", firstName: "Pirates", first: .init(latitude: 28.4177224, longitude: -81.5849315), secondName: "Space Mountain entrance", second: .init(latitude: 28.4193970, longitude: -81.5781302)),
    Sample(park: "EPCOT", firstName: "Remy", first: .init(latitude: 28.3679240, longitude: -81.5528604), secondName: "Cosmic Rewind", second: .init(latitude: 28.3755204, longitude: -81.5469465)),
    Sample(park: "Hollywood Studios", firstName: "Tower of Terror", first: .init(latitude: 28.3600158, longitude: -81.5599404), secondName: "Rise", second: .init(latitude: 28.3542873, longitude: -81.5604814)),
    Sample(park: "Animal Kingdom", firstName: "Safari", first: .init(latitude: 28.3597274, longitude: -81.5924065), secondName: "Flight of Passage", second: .init(latitude: 28.3548608, longitude: -81.5928263)),
    Sample(park: "Disneyland", firstName: "Space Mountain", first: .init(latitude: 33.8109695, longitude: -117.9175005), secondName: "Rise", second: .init(latitude: 33.8143946, longitude: -117.9227172)),
    Sample(park: "California Adventure", firstName: "Guardians", first: .init(latitude: 33.8066246, longitude: -117.9169048), secondName: "Radiator Springs Racers", second: .init(latitude: 33.8049938, longitude: -117.9188610))
]

func route(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
    let request = MKDirections.Request()
    request.source = MKMapItem(location: CLLocation(latitude: source.latitude, longitude: source.longitude), address: nil)
    request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
    request.transportType = .walking
    request.requestsAlternateRoutes = false
    guard let route = try await MKDirections(request: request).calculate().routes.first else {
        throw NSError(domain: "SixParkRouteAudit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No route returned"])
    }
    return route
}

func endpointSnap(_ route: MKRoute, requested: CLLocationCoordinate2D, first: Bool) -> CLLocationDistance {
    var coordinates = [CLLocationCoordinate2D](repeating: .init(), count: route.polyline.pointCount)
    route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: route.polyline.pointCount))
    guard let routed = first ? coordinates.first : coordinates.last else { return .nan }
    return CLLocation(latitude: requested.latitude, longitude: requested.longitude)
        .distance(from: CLLocation(latitude: routed.latitude, longitude: routed.longitude))
}

@main
enum SixParkRouteAudit {
    static func main() async {
        print("park\tdirection\tstraight_m\troute_m\teta_min\tstart_snap_m\tend_snap_m\tsteps\tstatus")
        for sample in samples {
            for (fromName, source, toName, destination) in [
                (sample.firstName, sample.first, sample.secondName, sample.second),
                (sample.secondName, sample.second, sample.firstName, sample.first)
            ] {
                let direction = "\(fromName) -> \(toName)"
                let straight = CLLocation(latitude: source.latitude, longitude: source.longitude)
                    .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
                do {
                    let result = try await route(from: source, to: destination)
                    print([sample.park, direction, "\(Int(straight.rounded()))", "\(Int(result.distance.rounded()))", "\(Int(ceil(result.expectedTravelTime / 60)))", "\(Int(endpointSnap(result, requested: source, first: true).rounded()))", "\(Int(endpointSnap(result, requested: destination, first: false).rounded()))", "\(result.steps.count)", "ok"].joined(separator: "\t"))
                } catch {
                    print([sample.park, direction, "\(Int(straight.rounded()))", "", "", "", "", "", "error: \(error.localizedDescription)"].joined(separator: "\t"))
                }
            }
        }
    }
}

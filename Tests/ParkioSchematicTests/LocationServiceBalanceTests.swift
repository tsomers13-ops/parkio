// LocationServiceBalanceTests.swift — A handoff between the EPCOT canvas
// and a MapKit park must not drop the location stream while either still
// holds it.

import CoreLocation
import SwiftUI
import XCTest

@testable import Parkio

@MainActor
final class LocationServiceBalanceTests: XCTestCase {

    func testLastReleaseStopsAndAnOverlappingClientDoesNot() async {
        let service = makeService(.authorizedWhenInUse)
        let first = service.acquireLocationUpdates()
        let second = service.acquireLocationUpdates()
        XCTAssertEqual(service.locationClientCount, 2)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates(first)
        await waitForStream(service, streaming: true)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates(second)
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertTrue(service.isStreamingLocation)
        await waitForStream(service, streaming: false)
        XCTAssertFalse(service.isStreamingLocation)
    }

    func testReleaseThenAcquireInTheSameTurnKeepsStreaming() async {
        let service = makeService(.authorizedWhenInUse)
        let first = service.acquireLocationUpdates()
        service.releaseLocationUpdates(first)
        let second = service.acquireLocationUpdates()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates(second)
        await waitForStream(service, streaming: false)
        XCTAssertFalse(service.isStreamingLocation)
    }

    func testExtraReleaseAndUnpairedStartDoNotUnbalanceTheCount() async {
        let service = makeService(.authorizedWhenInUse)
        service.releaseLocationUpdates(UUID())
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertFalse(service.isStreamingLocation)

        let hold = service.acquireLocationUpdates()
        service.startUpdating()
        XCTAssertEqual(service.locationClientCount, 1)
        service.releaseLocationUpdates(hold)
        service.releaseLocationUpdates(hold)
        await waitForStream(service, streaming: false)
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertFalse(service.isStreamingLocation)
    }

    func testHoldWhileNotDeterminedOrDeniedStartsStreamingOnGrant() {
        let service = makeService(.notDetermined)
        service.acquireLocationUpdates()
        service.startUpdating()
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertFalse(service.isStreamingLocation)

        service.noteAuthorizationStatus(.denied)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertFalse(service.isStreamingLocation)

        service.noteAuthorizationStatus(.authorizedWhenInUse)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)
    }

    func testGrantedAtLaunchWithNoMapOpenPopulatesUserLocation() async {
        let service = makeService(.authorizedWhenInUse)
        service.acquireLocationUpdates()
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)

        let fix = CLLocation(latitude: 28.3747, longitude: -81.5494)
        service.locationManager(CLLocationManager(), didUpdateLocations: [fix])
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline, service.userLocation == nil {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(service.userLocation?.coordinate.latitude ?? 0, 28.3747, accuracy: 0.0001)
        XCTAssertEqual(service.userLocation?.coordinate.longitude ?? 0, -81.5494, accuracy: 0.0001)
    }

    func testRevokeWhileHeldStopsAndRegrantResumes() {
        let service = makeService(.authorizedWhenInUse)
        service.acquireLocationUpdates()
        XCTAssertTrue(service.isStreamingLocation)

        service.noteAuthorizationStatus(.denied)
        XCTAssertFalse(service.isStreamingLocation)
        XCTAssertEqual(service.locationClientCount, 1)

        service.noteAuthorizationStatus(.authorizedWhenInUse)
        XCTAssertTrue(service.isStreamingLocation)
        XCTAssertEqual(service.locationClientCount, 1)
    }

    func testAccuracyUsesTheMostPreciseOverlappingHold() {
        let service = makeService(.authorizedWhenInUse)
        let app = service.acquireLocationUpdates(accuracy: kCLLocationAccuracyHundredMeters)
        XCTAssertEqual(service.desiredLocationAccuracy, kCLLocationAccuracyHundredMeters)

        let map = service.acquireLocationUpdates(accuracy: kCLLocationAccuracyBest)
        XCTAssertEqual(service.locationClientCount, 2)
        XCTAssertEqual(service.desiredLocationAccuracy, kCLLocationAccuracyBest)

        service.releaseLocationUpdates(map)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertEqual(service.desiredLocationAccuracy, kCLLocationAccuracyHundredMeters)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates(app)
    }

    func testDistanceFilterUsesTheMostDemandingOverlappingHold() {
        let service = makeService(.authorizedWhenInUse)
        let app = service.acquireLocationUpdates(
            accuracy: kCLLocationAccuracyHundredMeters,
            distanceFilter: 25
        )
        XCTAssertEqual(service.desiredDistanceFilter, 25)

        let map = service.acquireLocationUpdates(distanceFilter: 5)
        XCTAssertEqual(service.locationClientCount, 2)
        XCTAssertEqual(service.desiredDistanceFilter, 5)

        service.releaseLocationUpdates(map)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertEqual(service.desiredDistanceFilter, 25)

        service.releaseLocationUpdates(app)
    }

    func testInactiveKeepsTheForegroundHoldAndBackgroundReleasesIt() {
        XCTAssertTrue(ForegroundLocationPolicy.holdsLocation(.active))
        XCTAssertTrue(ForegroundLocationPolicy.holdsLocation(.inactive))
        XCTAssertFalse(ForegroundLocationPolicy.holdsLocation(.background))
    }

    func testGrantWithNoHoldDoesNotStreamBeyondTheButton() {
        let service = makeService(.notDetermined)
        service.noteAuthorizationStatus(.authorizedAlways)
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertFalse(service.isStreamingLocation)

        service.startUpdating()
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertTrue(service.isStreamingLocation)
    }

    private func makeService(_ status: CLAuthorizationStatus) -> LocationService {
        let service = LocationService()
        service.acceptsManagerAuthorizationUpdates = false
        service.noteAuthorizationStatus(status)
        return service
    }

    private func waitForStream(_ service: LocationService, streaming: Bool) async {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if service.isStreamingLocation == streaming { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

// LocationServiceBalanceTests.swift — A handoff between the EPCOT canvas
// and a MapKit park must not drop the location stream while either still
// holds it.

import XCTest

@testable import Parkio

@MainActor
final class LocationServiceBalanceTests: XCTestCase {

    func testLastReleaseStopsAndAnOverlappingClientDoesNot() async {
        let service = LocationService()
        service.acquireLocationUpdates()
        service.acquireLocationUpdates()
        XCTAssertEqual(service.locationClientCount, 2)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates()
        await waitForStream(service, streaming: true)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates()
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertTrue(service.isStreamingLocation)
        await waitForStream(service, streaming: false)
        XCTAssertFalse(service.isStreamingLocation)
    }

    func testReleaseThenAcquireInTheSameTurnKeepsStreaming() async {
        let service = LocationService()
        service.acquireLocationUpdates()
        service.releaseLocationUpdates()
        service.acquireLocationUpdates()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(service.locationClientCount, 1)
        XCTAssertTrue(service.isStreamingLocation)

        service.releaseLocationUpdates()
        await waitForStream(service, streaming: false)
        XCTAssertFalse(service.isStreamingLocation)
    }

    func testExtraReleaseAndUnpairedStartDoNotUnbalanceTheCount() async {
        let service = LocationService()
        service.releaseLocationUpdates()
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertFalse(service.isStreamingLocation)

        service.acquireLocationUpdates()
        service.startUpdating()
        XCTAssertEqual(service.locationClientCount, 1)
        service.releaseLocationUpdates()
        service.releaseLocationUpdates()
        await waitForStream(service, streaming: false)
        XCTAssertEqual(service.locationClientCount, 0)
        XCTAssertFalse(service.isStreamingLocation)
    }

    private func waitForStream(_ service: LocationService, streaming: Bool) async {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if service.isStreamingLocation == streaming { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

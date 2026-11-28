import XCTest
import CoreLocation

@testable import Parkio

@MainActor
final class WalkingRouteModelTests: XCTestCase {

    func testEndpointResolverUsesTargetedEntranceOverrideWithoutChangingOtherPins() {
        let spaceMountainPin = CLLocationCoordinate2D(latitude: 28.4191503, longitude: -81.5772484)
        let resolvedSpaceMountain = WalkingRouteEndpointResolver.coordinate(
            for: "Magic Kingdom|Tomorrowland|Space Mountain",
            fallback: spaceMountainPin
        )
        XCTAssertEqual(resolvedSpaceMountain.latitude, 28.4193970, accuracy: 0.000_000_1)
        XCTAssertEqual(resolvedSpaceMountain.longitude, -81.5781302, accuracy: 0.000_000_1)

        let cosmicRewind = CLLocationCoordinate2D(latitude: 28.3755204, longitude: -81.5469465)
        let unchanged = WalkingRouteEndpointResolver.coordinate(
            for: "EPCOT|World Discovery|Guardians of the Galaxy: Cosmic Rewind",
            fallback: cosmicRewind
        )
        XCTAssertEqual(unchanged.latitude, cosmicRewind.latitude)
        XCTAssertEqual(unchanged.longitude, cosmicRewind.longitude)
    }

    func testAppleMapsHandoffUsesSameResolvedEntranceAsRouteRequest() {
        let buildingCenter = CLLocationCoordinate2D(latitude: 28.4191503, longitude: -81.5772484)
        let handoff = WalkingDirectionsLauncher.resolvedCoordinate(
            destinationID: "Magic Kingdom|Tomorrowland|Space Mountain",
            coordinate: buildingCenter
        )
        let routeEndpoint = WalkingRouteEndpointResolver.coordinate(
            for: "Magic Kingdom|Tomorrowland|Space Mountain",
            fallback: buildingCenter
        )

        XCTAssertEqual(handoff.latitude, routeEndpoint.latitude, accuracy: 0.000_000_1)
        XCTAssertEqual(handoff.longitude, routeEndpoint.longitude, accuracy: 0.000_000_1)
        XCTAssertNotEqual(handoff.latitude, buildingCenter.latitude)
    }

    func testSuccessfulRoutePublishesProviderDistanceAndETA() async {
        let expected = route(distance: 469, minutes: 6)
        let provider = FakeWalkingRouteProvider { _, _ in expected }
        let model = makeModel(provider: provider)

        model.update(
            source: location(latitude: 33.8049938, longitude: -117.9188610),
            destination: .init(latitude: 33.8046179, longitude: -117.9207802),
            destinationID: "dca|incredicoaster",
            authorizationStatus: .authorizedWhenInUse
        )

        await waitUntil { model.state == .available(expected) }
        XCTAssertEqual(model.route?.distance, 469)
        XCTAssertEqual(model.route?.estimatedMinutes, 6)
        XCTAssertEqual(provider.callCount, 1)
    }

    func testLocationDeniedDoesNotCallProvider() {
        let provider = FakeWalkingRouteProvider { _, _ in self.route(distance: 100, minutes: 2) }
        let model = makeModel(provider: provider)

        model.update(
            source: location(latitude: 28.4, longitude: -81.5),
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .denied
        )

        XCTAssertEqual(model.state, .unavailable(.locationDenied))
        XCTAssertEqual(provider.callCount, 0)
    }

    func testNotDeterminedRequestsNoRouteUntilUserActs() {
        let provider = FakeWalkingRouteProvider { _, _ in self.route(distance: 100, minutes: 2) }
        let model = makeModel(provider: provider)

        model.update(
            source: nil,
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .notDetermined
        )

        XCTAssertEqual(model.state, .unavailable(.permissionRequired))
        XCTAssertEqual(provider.callCount, 0)
    }

    func testPoorOrMissingLocationDoesNotClaimWalkingDistance() {
        let provider = FakeWalkingRouteProvider { _, _ in self.route(distance: 100, minutes: 2) }
        let model = makeModel(provider: provider)
        let inaccurate = CLLocation(
            coordinate: .init(latitude: 28.4, longitude: -81.5),
            altitude: 0,
            horizontalAccuracy: 250,
            verticalAccuracy: 10,
            timestamp: Date()
        )

        model.update(
            source: inaccurate,
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )

        XCTAssertEqual(model.state, .unavailable(.locationUnavailable))
        XCTAssertEqual(provider.callCount, 0)
    }

    func testStaleAndImplausiblyFutureLocationsDoNotCallProvider() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let provider = FakeWalkingRouteProvider { _, _ in self.route(distance: 100, minutes: 2) }
        let model = makeModel(provider: provider, now: { now })

        for timestamp in [now.addingTimeInterval(-31), now.addingTimeInterval(6)] {
            model.update(
                source: location(latitude: 28.4, longitude: -81.5, timestamp: timestamp),
                destination: .init(latitude: 28.41, longitude: -81.51),
                destinationID: "ride",
                authorizationStatus: .authorizedWhenInUse
            )

            XCTAssertEqual(model.state, .unavailable(.locationUnavailable))
        }
        XCTAssertEqual(provider.callCount, 0)
    }

    func testMapReentryRejectsRetainedFixUntilFreshLocationArrives() async {
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        let expected = route(distance: 240, minutes: 4)
        let provider = FakeWalkingRouteProvider { _, _ in expected }
        let model = makeModel(provider: provider, now: { now })
        let retainedLocation = location(latitude: 28.4, longitude: -81.5, timestamp: now)
        let destination = CLLocationCoordinate2D(latitude: 28.41, longitude: -81.51)

        model.update(
            source: retainedLocation,
            destination: destination,
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { model.state == .available(expected) }

        model.cancel()
        now.addTimeInterval(31)
        model.update(
            source: retainedLocation,
            destination: destination,
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        XCTAssertEqual(model.state, .unavailable(.locationUnavailable))

        model.update(
            source: location(latitude: 28.4, longitude: -81.5, timestamp: now),
            destination: destination,
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { model.state == .available(expected) }
        XCTAssertEqual(provider.callCount, 1, "a fresh same-position fix may safely reuse the cached route")
    }

    func testOfflineAndNoRouteErrorsStayExplicit() async {
        for (error, expectedReason) in [
            (WalkingRouteProviderError.network, WalkingRouteUnavailableReason.network),
            (.noRoute, .noRoute),
            (.throttled, .throttled),
            (.server, .server)
        ] {
            let provider = FakeWalkingRouteProvider { _, _ in throw error }
            let model = makeModel(provider: provider)
            model.update(
                source: location(latitude: 28.4, longitude: -81.5),
                destination: .init(latitude: 28.41, longitude: -81.51),
                destinationID: "ride-\(expectedReason)",
                authorizationStatus: .authorizedWhenInUse
            )

            await waitUntil { model.state == .unavailable(expectedReason) }
            XCTAssertNil(model.route)
        }
    }

    func testRetryRecoversFromOfflineWithoutMovement() async {
        let expected = route(distance: 420, minutes: 7)
        var attempt = 0
        let provider = FakeWalkingRouteProvider { _, _ in
            attempt += 1
            if attempt == 1 { throw WalkingRouteProviderError.network }
            return expected
        }
        let model = makeModel(provider: provider)

        model.update(
            source: location(latitude: 28.4, longitude: -81.5),
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { model.state == .unavailable(.network) }

        model.retry()

        await waitUntil { model.state == .available(expected) }
        XCTAssertEqual(provider.callCount, 2)
    }

    func testRetryRefusesSourceThatBecameStale() async {
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        let provider = FakeWalkingRouteProvider { _, _ in throw WalkingRouteProviderError.network }
        let model = makeModel(provider: provider, now: { now })

        model.update(
            source: location(latitude: 28.4, longitude: -81.5, timestamp: now),
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { model.state == .unavailable(.network) }

        now.addTimeInterval(31)
        model.retry()

        XCTAssertEqual(model.state, .unavailable(.locationUnavailable))
        XCTAssertEqual(provider.callCount, 1)
    }

    func testNearbyLocationUpdateReusesBoundedCacheCell() async {
        let expected = route(distance: 300, minutes: 5)
        let provider = FakeWalkingRouteProvider { _, _ in expected }
        let model = makeModel(provider: provider)
        let destination = CLLocationCoordinate2D(latitude: 28.42, longitude: -81.58)

        model.update(
            source: location(latitude: 28.41000, longitude: -81.58000),
            destination: destination,
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { model.state == .available(expected) }

        model.update(
            source: location(latitude: 28.41001, longitude: -81.58001),
            destination: destination,
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )

        XCTAssertEqual(model.state, .available(expected))
        XCTAssertEqual(provider.callCount, 1)
    }

    func testCacheEvictsOldestEntryAtConfiguredBound() async {
        let expected = route(distance: 300, minutes: 5)
        let provider = FakeWalkingRouteProvider { _, _ in expected }
        let model = WalkingRouteModel(
            provider: provider,
            debounceNanoseconds: 0,
            cacheLifetime: 120,
            sourceGridDegrees: 0.00045,
            maxCacheEntries: 2
        )
        let source = location(latitude: 28.41, longitude: -81.58)

        for index in 1...3 {
            model.update(
                source: source,
                destination: .init(latitude: 28.42 + Double(index) / 1_000, longitude: -81.58),
                destinationID: "ride-\(index)",
                authorizationStatus: .authorizedWhenInUse
            )
            await waitUntil { model.state == .available(expected) }
        }

        model.update(
            source: source,
            destination: .init(latitude: 28.421, longitude: -81.58),
            destinationID: "ride-1",
            authorizationStatus: .authorizedWhenInUse
        )
        await waitUntil { provider.callCount == 4 && model.state == .available(expected) }
        XCTAssertEqual(model.state, .available(expected))
    }

    func testDebounceSuppressesSupersededRequestBeforeProviderCall() async {
        let expected = route(distance: 180, minutes: 3)
        let provider = FakeWalkingRouteProvider { _, _ in expected }
        let model = WalkingRouteModel(
            provider: provider,
            debounceNanoseconds: 50_000_000,
            cacheLifetime: 120,
            sourceGridDegrees: 0.00045,
            maxCacheEntries: 4
        )
        let source = location(latitude: 28.41, longitude: -81.58)

        model.update(
            source: source,
            destination: .init(latitude: 1, longitude: 1),
            destinationID: "superseded",
            authorizationStatus: .authorizedWhenInUse
        )
        try? await Task.sleep(nanoseconds: 10_000_000)
        model.update(
            source: source,
            destination: .init(latitude: 2, longitude: 2),
            destinationID: "current",
            authorizationStatus: .authorizedWhenInUse
        )

        await waitUntil { model.state == .available(expected) }
        XCTAssertEqual(provider.callCount, 1)
    }

    func testRapidSelectionChangeCannotPublishStaleRoute() async {
        let oldRoute = route(distance: 900, minutes: 14)
        let newRoute = route(distance: 180, minutes: 3)
        let provider = FakeWalkingRouteProvider { _, destination in
            let delay: TimeInterval = destination.latitude == 1 ? 0.20 : 0.02
            let value = destination.latitude == 1 ? oldRoute : newRoute
            return await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    continuation.resume(returning: value)
                }
            }
        }
        let model = makeModel(provider: provider)
        let source = location(latitude: 0.5, longitude: 0.5)

        model.update(
            source: source,
            destination: .init(latitude: 1, longitude: 1),
            destinationID: "old",
            authorizationStatus: .authorizedWhenInUse
        )
        await Task.yield()
        model.update(
            source: source,
            destination: .init(latitude: 2, longitude: 2),
            destinationID: "new",
            authorizationStatus: .authorizedWhenInUse
        )

        await waitUntil { model.state == .available(newRoute) }
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(model.state, .available(newRoute))
        XCTAssertEqual(provider.callCount, 2)
    }

    func testClearingSelectionCancelsAndReturnsToIdle() async {
        let provider = FakeWalkingRouteProvider { _, _ in
            try await Task.sleep(nanoseconds: 100_000_000)
            return self.route(distance: 100, minutes: 2)
        }
        let model = makeModel(provider: provider)

        model.update(
            source: location(latitude: 28.4, longitude: -81.5),
            destination: .init(latitude: 28.41, longitude: -81.51),
            destinationID: "ride",
            authorizationStatus: .authorizedWhenInUse
        )
        model.update(
            source: location(latitude: 28.4, longitude: -81.5),
            destination: nil,
            destinationID: nil,
            authorizationStatus: .authorizedWhenInUse
        )

        XCTAssertEqual(model.state, .idle)
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(model.state, .idle)
    }

    private func makeModel(
        provider: FakeWalkingRouteProvider,
        now: @escaping () -> Date = Date.init
    ) -> WalkingRouteModel {
        WalkingRouteModel(
            provider: provider,
            debounceNanoseconds: 0,
            cacheLifetime: 120,
            sourceGridDegrees: 0.00045,
            maxCacheEntries: 4,
            now: now
        )
    }

    private func route(distance: CLLocationDistance, minutes: Int) -> WalkingRoute {
        WalkingRoute(
            distance: distance,
            expectedTravelTime: TimeInterval(minutes * 60),
            coordinates: [
                .init(latitude: 1, longitude: 1),
                .init(latitude: 2, longitude: 2)
            ]
        )
    }

    private func location(
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date()
    ) -> CLLocation {
        CLLocation(
            coordinate: .init(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: timestamp
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "condition was not met before timeout")
    }
}

private final class FakeWalkingRouteProvider: WalkingRouteProviding {
    typealias Handler = (
        CLLocationCoordinate2D,
        CLLocationCoordinate2D
    ) async throws -> WalkingRoute

    private let handler: Handler
    private(set) var callCount = 0

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func route(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> WalkingRoute {
        callCount += 1
        return try await handler(source, destination)
    }
}

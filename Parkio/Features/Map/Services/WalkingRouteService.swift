// WalkingRouteService.swift — routed pedestrian distance and ETA for map selections.
//
// The route provider is deliberately injectable. Production uses MKDirections;
// tests use deterministic fakes so network availability and Apple Maps data never
// make the test suite flaky.

import Foundation
import CoreLocation
import MapKit
import Observation

// MARK: - Route value

struct WalkingRoute: Equatable {
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let coordinates: [CLLocationCoordinate2D]

    var estimatedMinutes: Int {
        max(1, Int(ceil(expectedTravelTime / 60)))
    }

    var formattedDistance: String {
        RideAnnotation.formattedDistance(distance)
    }

    static func == (lhs: WalkingRoute, rhs: WalkingRoute) -> Bool {
        guard lhs.distance == rhs.distance,
              lhs.expectedTravelTime == rhs.expectedTravelTime,
              lhs.coordinates.count == rhs.coordinates.count else { return false }

        return zip(lhs.coordinates, rhs.coordinates).allSatisfy { lhsCoordinate, rhsCoordinate in
            lhsCoordinate.latitude == rhsCoordinate.latitude
                && lhsCoordinate.longitude == rhsCoordinate.longitude
        }
    }
}

// MARK: - Provider

enum WalkingRouteProviderError: Error, Equatable {
    case noRoute
    case network
    case throttled
    case server
    case unknown
}

protocol WalkingRouteProviding {
    func route(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> WalkingRoute
}

struct MapKitWalkingRouteProvider: WalkingRouteProviding {
    func route(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> WalkingRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw WalkingRouteProviderError.noRoute
            }

            var coordinates = [CLLocationCoordinate2D](
                repeating: CLLocationCoordinate2D(),
                count: route.polyline.pointCount
            )
            route.polyline.getCoordinates(
                &coordinates,
                range: NSRange(location: 0, length: route.polyline.pointCount)
            )

            return WalkingRoute(
                distance: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                coordinates: coordinates
            )
        } catch let error as WalkingRouteProviderError {
            throw error
        } catch let error as MKError {
            switch error.code {
            case .directionsNotFound:
                throw WalkingRouteProviderError.noRoute
            case .loadingThrottled:
                throw WalkingRouteProviderError.throttled
            case .serverFailure:
                throw WalkingRouteProviderError.server
            default:
                throw WalkingRouteProviderError.network
            }
        } catch is URLError {
            throw WalkingRouteProviderError.network
        } catch {
            throw WalkingRouteProviderError.unknown
        }
    }
}

// MARK: - Presentation state

enum WalkingRouteUnavailableReason: Equatable {
    case permissionRequired
    case locationDenied
    case locationUnavailable
    case noRoute
    case network
    case throttled
    case server
    case unknown

    var message: String {
        switch self {
        case .permissionRequired:
            return "Enable location for walking distance and time."
        case .locationDenied:
            return "Location access is off."
        case .locationUnavailable:
            return "Waiting for an accurate location."
        case .noRoute:
            return "No walking route is available for this destination."
        case .network:
            return "Walking route unavailable while offline."
        case .throttled:
            return "Walking routes are temporarily busy."
        case .server:
            return "Apple Maps routing is temporarily unavailable."
        case .unknown:
            return "Walking route unavailable."
        }
    }
}

enum WalkingRouteState: Equatable {
    case idle
    case loading
    case available(WalkingRoute)
    case unavailable(WalkingRouteUnavailableReason)

    var route: WalkingRoute? {
        guard case let .available(route) = self else { return nil }
        return route
    }
}

// MARK: - Routing-only endpoint resolution

enum WalkingRouteEndpointResolver {
    /// Keep visual pin coordinates independent from routing destinations. Add an
    /// override only after a route ends at a building centre, backstage area, or
    /// otherwise inaccessible point. A two-direction audit of representative
    /// priority-one attractions in all six parks found one >75 m destination snap:
    /// Magic Kingdom's Space Mountain pin is the show-building centre. Route to
    /// the public entrance path while leaving the visual pin unchanged.
    private static let overrides: [String: CLLocationCoordinate2D] = [
        "Magic Kingdom|Tomorrowland|Space Mountain": CLLocationCoordinate2D(
            latitude: 28.4193970,
            longitude: -81.5781302
        )
    ]

    static func coordinate(
        for destinationID: String,
        fallback: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        overrides[destinationID] ?? fallback
    }
}

// MARK: - Shared route model

@MainActor
@Observable
final class WalkingRouteModel {
    private(set) var state: WalkingRouteState = .idle

    private let provider: any WalkingRouteProviding
    private let debounceNanoseconds: UInt64
    private let cacheLifetime: TimeInterval
    private let sourceGridDegrees: Double
    private let maxCacheEntries: Int
    private let maximumLocationAge: TimeInterval
    private let futureLocationTolerance: TimeInterval
    private let now: () -> Date

    private var requestTask: Task<Void, Never>?
    private var requestSerial = 0
    private var cache: [CacheKey: CacheEntry] = [:]
    private var latestRequest: RouteRequest?

    init(
        provider: any WalkingRouteProviding = MapKitWalkingRouteProvider(),
        debounceNanoseconds: UInt64 = 350_000_000,
        cacheLifetime: TimeInterval = 120,
        sourceGridDegrees: Double = 0.00045,
        maxCacheEntries: Int = 24,
        maximumLocationAge: TimeInterval = 30,
        futureLocationTolerance: TimeInterval = 5,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.debounceNanoseconds = debounceNanoseconds
        self.cacheLifetime = cacheLifetime
        self.sourceGridDegrees = sourceGridDegrees
        self.maxCacheEntries = max(1, maxCacheEntries)
        self.maximumLocationAge = maximumLocationAge
        self.futureLocationTolerance = futureLocationTolerance
        self.now = now
    }

    var route: WalkingRoute? { state.route }

    func update(
        source: CLLocation?,
        destination: CLLocationCoordinate2D?,
        destinationID: String?,
        authorizationStatus: CLAuthorizationStatus
    ) {
        guard let destination, let destinationID else {
            latestRequest = nil
            cancelAndSet(.idle)
            return
        }

        latestRequest = RouteRequest(
            source: source,
            destination: destination,
            destinationID: destinationID,
            authorizationStatus: authorizationStatus
        )

        switch authorizationStatus {
        case .notDetermined:
            cancelAndSet(.unavailable(.permissionRequired))
            return
        case .denied, .restricted:
            cancelAndSet(.unavailable(.locationDenied))
            return
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            cancelAndSet(.unavailable(.locationUnavailable))
            return
        }

        guard let source,
              source.horizontalAccuracy >= 0,
              source.horizontalAccuracy <= 150,
              isFresh(source, at: now()) else {
            cancelAndSet(.unavailable(.locationUnavailable))
            return
        }

        startRoute(source: source, destination: destination, destinationID: destinationID)
    }

    /// Repeats the latest failed request without requiring movement or a new
    /// selection. The stored location is revalidated at tap time, so a retry can
    /// never turn a stale pre-background fix into a walking estimate.
    func retry() {
        guard let request = latestRequest else { return }

        switch request.authorizationStatus {
        case .notDetermined:
            cancelAndSet(.unavailable(.permissionRequired))
            return
        case .denied, .restricted:
            cancelAndSet(.unavailable(.locationDenied))
            return
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            cancelAndSet(.unavailable(.locationUnavailable))
            return
        }

        guard let source = request.source,
              source.horizontalAccuracy >= 0,
              source.horizontalAccuracy <= 150,
              isFresh(source, at: now()) else {
            cancelAndSet(.unavailable(.locationUnavailable))
            return
        }

        startRoute(
            source: source,
            destination: request.destination,
            destinationID: request.destinationID,
            bypassDebounce: true
        )
    }

    private func startRoute(
        source: CLLocation,
        destination: CLLocationCoordinate2D,
        destinationID: String,
        bypassDebounce: Bool = false
    ) {

        let routeDestination = WalkingRouteEndpointResolver.coordinate(
            for: destinationID,
            fallback: destination
        )
        let key = CacheKey(
            destinationID: destinationID,
            source: source.coordinate,
            sourceGridDegrees: sourceGridDegrees
        )

        let requestDate = now()
        removeExpiredCacheEntries(now: requestDate)
        if let cached = cache[key], requestDate.timeIntervalSince(cached.createdAt) <= cacheLifetime {
            requestTask?.cancel()
            requestSerial += 1
            state = .available(cached.route)
            return
        }

        requestTask?.cancel()
        requestSerial += 1
        let serial = requestSerial
        state = .loading

        requestTask = Task { [weak self] in
            guard let self else { return }

            do {
                if debounceNanoseconds > 0, !bypassDebounce {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                }
                let route = try await provider.route(
                    from: source.coordinate,
                    to: routeDestination
                )
                guard !Task.isCancelled, serial == requestSerial else { return }
                insert(route, for: key, now: now())
                state = .available(route)
            } catch is CancellationError {
                return
            } catch let error as WalkingRouteProviderError {
                guard !Task.isCancelled, serial == requestSerial else { return }
                state = .unavailable(Self.reason(for: error))
            } catch {
                guard !Task.isCancelled, serial == requestSerial else { return }
                state = .unavailable(.unknown)
            }
        }
    }

    func cancel() {
        latestRequest = nil
        cancelAndSet(.idle)
    }

    private func isFresh(_ location: CLLocation, at date: Date) -> Bool {
        let age = date.timeIntervalSince(location.timestamp)
        return age >= -futureLocationTolerance && age <= maximumLocationAge
    }

    private func cancelAndSet(_ newState: WalkingRouteState) {
        requestTask?.cancel()
        requestTask = nil
        requestSerial += 1
        state = newState
    }

    private func insert(_ route: WalkingRoute, for key: CacheKey, now: Date) {
        if cache.count >= maxCacheEntries,
           let oldestKey = cache.min(by: { $0.value.createdAt < $1.value.createdAt })?.key {
            cache.removeValue(forKey: oldestKey)
        }
        cache[key] = CacheEntry(route: route, createdAt: now)
    }

    private func removeExpiredCacheEntries(now: Date) {
        cache = cache.filter { now.timeIntervalSince($0.value.createdAt) <= cacheLifetime }
    }

    private static func reason(for error: WalkingRouteProviderError) -> WalkingRouteUnavailableReason {
        switch error {
        case .noRoute:   return .noRoute
        case .network:   return .network
        case .throttled: return .throttled
        case .server:    return .server
        case .unknown:   return .unknown
        }
    }

    private struct CacheEntry {
        let route: WalkingRoute
        let createdAt: Date
    }

    private struct RouteRequest {
        let source: CLLocation?
        let destination: CLLocationCoordinate2D
        let destinationID: String
        let authorizationStatus: CLAuthorizationStatus
    }

    private struct CacheKey: Hashable {
        let destinationID: String
        let latitudeCell: Int
        let longitudeCell: Int

        init(
            destinationID: String,
            source: CLLocationCoordinate2D,
            sourceGridDegrees: Double
        ) {
            self.destinationID = destinationID
            self.latitudeCell = Int((source.latitude / sourceGridDegrees).rounded())
            self.longitudeCell = Int((source.longitude / sourceGridDegrees).rounded())
        }
    }
}

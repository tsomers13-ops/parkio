// WaitTimeService.swift — Live wait-time fetching.
//
// Data source strategy:
//   • DEFAULT: calls ThemeParks.wiki directly (free, no key required).
//     Works immediately in the simulator with no backend setup.
//   • CUSTOM BACKEND: activated when WAIT_TIME_API_URL in Info.plist is set
//     to a non-localhost URL (e.g. your Fly.io deployment).
//
// Implemented as a Swift actor for data-race safety.

import Foundation

// MARK: - Error types

enum WaitTimeError: LocalizedError, Equatable {
    case offline
    case serverUnavailable(retryAfterSeconds: Int)
    case notFound(parkId: String)
    case rateLimited
    case decodingFailed(String)
    case requestTimeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection."
        case .serverUnavailable:
            return "Wait time service is temporarily unavailable."
        case .notFound(let parkId):
            return "Park \"\(parkId)\" not found."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .decodingFailed(let detail):
            return "Unexpected data from server: \(detail)"
        case .requestTimeout:
            return "The request timed out. Check your connection."
        case .unknown(let msg):
            return msg
        }
    }

    var isRetryable: Bool {
        switch self {
        case .serverUnavailable, .requestTimeout, .unknown: return true
        default: return false
        }
    }

    /// Compact label for toolbar / banner display.
    var shortLabel: String {
        switch self {
        case .offline:              return "Offline"
        case .serverUnavailable:    return "Service down"
        case .notFound:             return "Park not found"
        case .rateLimited:          return "Rate limited"
        case .decodingFailed:       return "Bad response"
        case .requestTimeout:       return "Timed out"
        case .unknown:              return "Error"
        }
    }
}

// MARK: - ThemeParks.wiki raw DTOs (private — not used outside this file)

private struct TPWDestinationsResponse: Decodable {
    let destinations: [TPWDestination]
}

private struct TPWDestination: Decodable {
    let id: String
    let name: String
    let parks: [TPWParkRef]
}

private struct TPWParkRef: Decodable {
    let id: String
    let name: String
}

private struct TPWLiveResponse: Decodable {
    let liveData: [TPWLiveEntry]
}

private struct TPWLiveEntry: Decodable {
    let id: String
    let name: String
    let entityType: String
    let status: String?
    let lastUpdated: String?
    let queue: TPWQueue?
}

private struct TPWQueue: Decodable {
    let standby: TPWWaitSlot?
    let singleRider: TPWWaitSlot?
    let paidReturnTime: TPWSlotState?

    enum CodingKeys: String, CodingKey {
        case standby      = "STANDBY"
        case singleRider  = "SINGLE_RIDER"
        case paidReturnTime = "PAID_RETURN_TIME"
    }
}

private struct TPWWaitSlot: Decodable {
    let waitTime: Int?
}

private struct TPWSlotState: Decodable {
    let state: String?
}

// MARK: - Park → ThemeParks.wiki UUID mapping

private let themeparksEntityUUIDs: [String: String] = [
    "magic-kingdom":        "75ea578a-adc8-4116-a54d-dccb60765ef0",
    "epcot":                "47f90d2c-e191-4239-a466-5892ef59a88b",
    "hollywood-studios":    "288747d1-8b4f-4a64-867e-ea7c9b27bad8",
    "animal-kingdom":       "1c84a229-8862-4648-9c71-378ddd2a7a5c",
    "disneyland":           "7340550b-c14d-4def-80bb-acdb51d49a66",
    "california-adventure": "832fcd51-ea19-4e77-85c7-75d5843b127c"
]

// MARK: - Service

actor WaitTimeService {

    static let shared = WaitTimeService()

    // ── Configuration ─────────────────────────────────────────────────────────

    private let themeparksBase = URL(string: "https://api.themeparks.wiki/v1")!

    /// Discovered park UUIDs — populated lazily by discoverParkUUIDs().
    /// Key = our backendId ("magic-kingdom"), value = ThemeParks.wiki entity UUID.
    private var resolvedUUIDs: [String: String] = [:]
    private var uuidDiscoveryDone = false

    /// Non-nil only when a real (non-localhost) custom backend URL is configured.
    private let backendBase: URL?
    private let apiKey: String

    private let session: URLSession
    private let backendDecoder: JSONDecoder

    // ── Init ──────────────────────────────────────────────────────────────────

    private init() {
        let urlString = Bundle.main.object(
            forInfoDictionaryKey: "WAIT_TIME_API_URL"
        ) as? String ?? ""

        // Use custom backend only when URL is set and points somewhere real.
        let isLocalhost = urlString.isEmpty
            || urlString.contains("localhost")
            || urlString.contains("127.0.0.1")
        backendBase = isLocalhost ? nil : URL(string: urlString)

        apiKey = Bundle.main.object(
            forInfoDictionaryKey: "WAIT_TIME_API_KEY"
        ) as? String ?? ""

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 12
        config.timeoutIntervalForResource = 25
        config.waitsForConnectivity       = false
        config.urlCache                   = nil
        config.requestCachePolicy         = .reloadIgnoringLocalCacheData
        if !apiKey.isEmpty {
            config.httpAdditionalHeaders = ["X-App-Key": apiKey]
        }

        session = URLSession(configuration: config)
        backendDecoder = JSONDecoder.backendDecoder()
    }

    // MARK: - Public API

    /// Fetch live wait times for one park.
    /// Uses ThemeParks.wiki directly unless a custom backend is configured.
    func fetchParkLive(parkId: String) async throws -> ParkLiveDTO {
        if let backend = backendBase {
            let url = backend
                .appendingPathComponent("v1/parks")
                .appendingPathComponent(parkId)
                .appendingPathComponent("live")
            return try await backendPerform(url: url, retryCount: 1)
        }
        return try await fetchDirectFromThemeParks(parkId: parkId)
    }

    /// Fetch snapshots for chart data (custom backend only — returns empty in direct mode).
    func fetchSnapshots(rideId: String, limit: Int = 20) async throws -> SnapshotsResponseDTO {
        guard let backend = backendBase else {
            return SnapshotsResponseDTO(rideId: rideId, count: 0, snapshots: [])
        }
        var components = URLComponents(
            url: backend.appendingPathComponent("v1/rides/\(rideId)/snapshots"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        return try await backendPerform(url: components.url!, retryCount: 0)
    }

    /// Health check (custom backend only — returns a mock response in direct mode).
    func fetchHealth() async throws -> HealthResponseDTO {
        guard let backend = backendBase else {
            return HealthResponseDTO(
                status: "ok (direct)",
                version: "direct",
                provider: "themeparks.wiki",
                redisConnected: false,
                lastCronRunAt: nil
            )
        }
        let url = backend.appendingPathComponent("v1/health")
        return try await backendPerform(url: url, retryCount: 0)
    }

    // MARK: - ThemeParks.wiki direct path

    private func fetchDirectFromThemeParks(parkId: String) async throws -> ParkLiveDTO {
        let uuid = try await resolveUUID(for: parkId)
        let url = themeparksBase
            .appendingPathComponent("entity")
            .appendingPathComponent(uuid)
            .appendingPathComponent("live")

        var request = URLRequest(url: url)
        request.setValue("Parkio/1.0 (iOS; github.com/parkio)",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw classify(urlError: urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw WaitTimeError.unknown("Non-HTTP response from ThemeParks.wiki")
        }
        switch http.statusCode {
        case 200...299: break
        case 404: throw WaitTimeError.notFound(parkId: parkId)
        case 429: throw WaitTimeError.rateLimited
        case 503: throw WaitTimeError.serverUnavailable(retryAfterSeconds: 60)
        default:  throw WaitTimeError.unknown("ThemeParks.wiki HTTP \(http.statusCode)")
        }

        let tpw: TPWLiveResponse
        do {
            tpw = try JSONDecoder().decode(TPWLiveResponse.self, from: data)
        } catch {
            throw WaitTimeError.decodingFailed(error.localizedDescription)
        }

        return buildParkLiveDTO(parkId: parkId, tpw: tpw)
    }

    // MARK: - UUID resolution

    /// Returns the ThemeParks.wiki entity UUID for a given backend park ID.
    /// Tries dynamic discovery first; falls back to hardcoded values.
    private func resolveUUID(for parkId: String) async throws -> String {
        // Already resolved this session
        if let uuid = resolvedUUIDs[parkId] { return uuid }

        // Attempt discovery once per app session
        if !uuidDiscoveryDone {
            await discoverParkUUIDs()
        }

        if let uuid = resolvedUUIDs[parkId] { return uuid }

        // Final fallback: hardcoded UUIDs
        if let uuid = themeparksEntityUUIDs[parkId] { return uuid }

        throw WaitTimeError.notFound(parkId: parkId)
    }

    /// Calls /destinations, parses all Disney parks, and populates resolvedUUIDs.
    private func discoverParkUUIDs() async {
        uuidDiscoveryDone = true

        let url = themeparksBase.appendingPathComponent("destinations")
        var request = URLRequest(url: url)
        request.setValue("Parkio/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json",             forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let result = try? JSONDecoder().decode(TPWDestinationsResponse.self, from: data)
        else { return }

        for destination in result.destinations {
            // Only care about Disney destinations
            guard destination.name.lowercased().contains("disney") else { continue }
            for park in destination.parks {
                if let backendId = matchParkName(
                    park.name,
                    destinationName: destination.name
                ) {
                    resolvedUUIDs[backendId] = park.id
                }
            }
        }
    }

    /// Maps a ThemeParks.wiki park display name to our backend park ID.
    private func matchParkName(_ name: String, destinationName: String) -> String? {
        let n = name.lowercased()
        let d = destinationName.lowercased()

        if d.contains("walt disney world") {
            if n.contains("magic kingdom")     { return "magic-kingdom"     }
            if n.contains("epcot")             { return "epcot"             }
            if n.contains("hollywood studios") { return "hollywood-studios" }
            if n.contains("animal kingdom")    { return "animal-kingdom"    }
        }

        if d == "disneyland resort" {
            if n == "disneyland park"               { return "disneyland"           }
            if n.contains("california adventure")   { return "california-adventure" }
        }

        return nil
    }

    /// Map ThemeParks.wiki response → ParkLiveDTO (our internal contract).
    private func buildParkLiveDTO(parkId: String, tpw: TPWLiveResponse) -> ParkLiveDTO {
        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())

        let rides: [LiveRideDTO] = tpw.liveData
            .filter { $0.entityType.uppercased() == "ATTRACTION" }
            .map { entry in
                LiveRideDTO(
                    rideId:                 entry.id,
                    name:                   entry.name,
                    land:                   "",        // not in TPW live response
                    status:                 mapStatus(entry.status),
                    waitMinutes:            entry.queue?.standby?.waitTime,
                    singleRiderWaitMinutes: entry.queue?.singleRider?.waitTime,
                    lightningLaneAvailable: entry.queue?.paidReturnTime != nil,
                    trend:                  "STABLE",
                    trendDeltaMinutes:      0,
                    lastUpdatedAt:          entry.lastUpdated ?? nowString
                )
            }

        return ParkLiveDTO(
            parkId:          parkId,
            fetchedAt:       nowString,
            servedAt:        nowString,
            cacheAgeSeconds: 0,
            stale:           false,
            source:          "themeparks",
            rides:           rides
        )
    }

    private func mapStatus(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "OPERATING":     return "OPERATING"
        case "DOWN":          return "DOWN"
        case "CLOSED":        return "CLOSED"
        case "REFURBISHMENT": return "REFURBISHMENT"
        default:              return "UNKNOWN"
        }
    }

    // MARK: - Custom backend helpers

    private func backendPerform<T: Decodable>(url: URL, retryCount: Int) async throws -> T {
        do {
            return try await backendGet(url: url)
        } catch let error as WaitTimeError where error.isRetryable && retryCount > 0 {
            try await Task.sleep(for: .seconds(1))
            return try await backendPerform(url: url, retryCount: retryCount - 1)
        }
    }

    private func backendGet<T: Decodable>(url: URL) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: URLRequest(url: url))
        } catch let urlError as URLError {
            throw classify(urlError: urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw WaitTimeError.unknown("Non-HTTP response")
        }

        switch http.statusCode {
        case 200...299: break
        case 401: throw WaitTimeError.unknown("Invalid API key — check WAIT_TIME_API_KEY in Info.plist")
        case 404:
            let parkId = url.pathComponents.dropLast().last ?? "unknown"
            throw WaitTimeError.notFound(parkId: parkId)
        case 429: throw WaitTimeError.rateLimited
        case 503:
            let retryAfter = (try? backendDecoder.decode(APIErrorDTO.self, from: data))?.retryAfterSeconds ?? 60
            throw WaitTimeError.serverUnavailable(retryAfterSeconds: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            throw WaitTimeError.unknown("HTTP \(http.statusCode): \(body.prefix(200))")
        }

        do {
            return try backendDecoder.decode(T.self, from: data)
        } catch {
            throw WaitTimeError.decodingFailed(error.localizedDescription)
        }
    }

    private func classify(urlError: URLError) -> WaitTimeError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .requestTimeout
        default:
            return .unknown(urlError.localizedDescription)
        }
    }
}

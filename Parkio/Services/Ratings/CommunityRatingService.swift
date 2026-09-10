// CommunityRatingService.swift — read/write client for Parkio Community Dining Ratings.
//
// One community, two transports. The website identifies a guest with a signed
// HttpOnly cookie; this app identifies one with an opaque bearer credential
// issued by /api/identity/anonymous/ and kept in the Keychain. Both resolve
// server-side to the same anonymous raterId and write the same rows, so a
// rating left in the app and one left on the website are the same community.
//
// Identity is provisioned lazily and only when it is actually needed:
//
//   aggregate / summaries  →  no credential, never provisions
//   myRating               →  uses a credential if one exists, never creates one
//   submit                 →  provisions on demand
//
// So browsing Dining leaves a guest with no identity at all, exactly as
// browsing the website does.
//
// The server is the source of truth. A failed write is reported as a failure —
// this layer never pretends a rating was saved, and never queues it for later.

import Foundation

// MARK: - Transport

/// The one piece of URLSession this service needs, so tests can supply a fake
/// without a network or a URLProtocol subclass.
protocol RatingHTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: RatingHTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CommunityRatingError.decodingFailed
        }
        return (data, http)
    }
}

// MARK: - Service

actor CommunityRatingService {

    private let transport: RatingHTTPTransport
    private let credentials: RatingCredentialStore
    private let baseURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        transport: RatingHTTPTransport = URLSession.shared,
        credentials: RatingCredentialStore = KeychainRatingCredentialStore(),
        baseURL: URL = ParkioAPI.baseURL
    ) {
        self.transport = transport
        self.credentials = credentials
        self.baseURL = baseURL
    }

    // MARK: - Public reads (no identity)

    /// Full aggregate for one venue. Requires no identity and creates none.
    func aggregate(venueKey: String) async throws -> CommunityRatingAggregate {
        let request = try makeRequest(path: ParkioAPI.ratingsPath(venueKey: venueKey), method: "GET")
        let (data, http) = try await perform(request)
        try check(http, data: data, venueKey: venueKey)
        return try decode(CommunityRatingAggregate.self, from: data)
    }

    /// Compact aggregates for many venues in ONE request — the same endpoint
    /// the website's discovery cards use. Never one request per venue.
    func summaries(venueKeys: [String]) async throws -> [String: CommunityRatingSummary] {
        guard !venueKeys.isEmpty else { return [:] }
        let request = try makeRequest(
            path: ParkioAPI.bulkRatingsPath(venueKeys: venueKeys),
            method: "GET"
        )
        let (data, http) = try await perform(request)
        try check(http, data: data, venueKey: nil)
        return try decode(CommunityRatingSummaryResponse.self, from: data).ratings
    }

    // MARK: - Personal read (uses identity, never creates one)

    /// This guest's own rating, or nil.
    ///
    /// Returns nil without any network call when the device has no credential:
    /// an unidentified guest provably has no rating, and asking would only
    /// create an identity we promised not to create on a read.
    func myRating(venueKey: String) async throws -> PersonalDiningRating? {
        guard let credential = try? credentials.load(), !credential.isEmpty else { return nil }

        var request = try makeRequest(path: ParkioAPI.myRatingPath(venueKey: venueKey), method: "GET")
        authorize(&request, credential: credential)

        let (data, http) = try await perform(request)

        // A rejected credential is stale, not a hard failure for a read.
        // Discard it and answer honestly: we do not know of a rating.
        if http.statusCode == 401 {
            try? credentials.delete()
            return nil
        }
        try check(http, data: data, venueKey: venueKey)
        return try decode(PersonalRatingResponse.self, from: data).rating
    }

    // MARK: - Write (provisions identity on demand)

    /// Submit or revise this guest's rating.
    ///
    /// The response is authoritative: callers should replace what they were
    /// showing with `aggregate` rather than incrementing a count, because an
    /// update must not add a vote and only the server knows which case it was.
    func submit(
        _ submission: DiningRatingSubmission,
        venueKey: String
    ) async throws -> DiningRatingSubmissionResult {
        guard submission.isValid else { throw CommunityRatingError.notRateable }

        let credential = try await currentOrNewCredential()

        do {
            return try await send(submission, venueKey: venueKey, credential: credential)
        } catch CommunityRatingError.invalidCredential {
            // The stored credential was rejected, so nothing was written under
            // it. Replace the identity and try exactly once more.
            //
            // Retrying is safe specifically because this failure means the
            // write did not happen — this is not a blanket retry, and no other
            // error is retried here.
            try? credentials.delete()
            let fresh = try await provisionCredential()
            return try await send(submission, venueKey: venueKey, credential: fresh)
        }
    }

    private func send(
        _ submission: DiningRatingSubmission,
        venueKey: String,
        credential: String
    ) async throws -> DiningRatingSubmissionResult {
        var request = try makeRequest(path: ParkioAPI.ratingsPath(venueKey: venueKey), method: "POST")
        authorize(&request, credential: credential)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(submission)

        let (data, http) = try await perform(request)
        try check(http, data: data, venueKey: venueKey)

        let body = try decode(DiningRatingSubmissionResponse.self, from: data)
        return DiningRatingSubmissionResult(
            outcome: http.statusCode == 201 ? .created : .updated,
            rating: body.rating,
            aggregate: body.aggregate
        )
    }

    // MARK: - Identity

    /// The stored credential, provisioning one if this device has none.
    private func currentOrNewCredential() async throws -> String {
        if let existing = try? credentials.load(), !existing.isEmpty { return existing }
        return try await provisionCredential()
    }

    /// Ask the server for a fresh anonymous identity and store it.
    private func provisionCredential() async throws -> String {
        let request = try makeRequest(path: ParkioAPI.anonymousIdentityPath, method: "POST")
        let (data, http) = try await perform(request)
        guard http.statusCode == 201 || http.statusCode == 200 else {
            if http.statusCode == 503 { throw CommunityRatingError.serviceUnavailable }
            throw CommunityRatingError.server(status: http.statusCode)
        }
        let issued = try decode(IssuedCredential.self, from: data)
        guard !issued.credential.isEmpty else { throw CommunityRatingError.decodingFailed }

        // A save failure is not fatal to this submission — the rating can
        // still be filed — but the guest would get a new identity next launch,
        // so it is worth failing loudly rather than silently losing identity.
        try credentials.save(issued.credential)
        return issued.credential
    }

    private struct IssuedCredential: Decodable { let credential: String }

    /// Bearer, per the usual convention. Never a query parameter, never a URL
    /// component, and never logged — see the note in `perform`.
    private func authorize(_ request: inout URLRequest, credential: String) {
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - Plumbing

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = ParkioAPI.url(path: path, base: baseURL) else {
            throw CommunityRatingError.decodingFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The credential is the only identity; no cookie storage is involved,
        // and none should be, so the app can never accidentally reuse or leak
        // a browser identity.
        request.httpShouldHandleCookies = false
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as CommunityRatingError {
            throw error
        } catch {
            // Nothing about the request is logged here. The Authorization
            // header would otherwise be the easiest credential leak in the
            // app, and a URLError says everything useful anyway.
            throw CommunityRatingError.networkUnavailable
        }
    }

    private func check(_ http: HTTPURLResponse, data: Data, venueKey: String?) throws {
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw CommunityRatingError.invalidCredential
        case 404:
            throw CommunityRatingError.unknownVenue(venueKey: venueKey ?? "")
        case 400:
            throw CommunityRatingError.validationFailed(message: errorMessage(from: data))
        case 503:
            // The backend distinguishes "cannot read" from "cannot write".
            let code = errorCode(from: data)
            throw code == "ratings_write_failed"
                ? CommunityRatingError.writeFailed
                : CommunityRatingError.serviceUnavailable
        default:
            throw CommunityRatingError.server(status: http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder.decode(type, from: data) }
        catch { throw CommunityRatingError.decodingFailed }
    }

    private struct APIError: Decodable { let error: String?; let message: String? }

    private func errorCode(from data: Data) -> String? {
        try? decoder.decode(APIError.self, from: data).error
    }

    private func errorMessage(from data: Data) -> String? {
        try? decoder.decode(APIError.self, from: data).message
    }
}

// MARK: - Eligibility

extension CommunityRatingService {

    /// Resolve a venue's rating identity from its iOS stableID.
    ///
    /// Returns nil for the 24 venues outside the current 62-venue pilot. There
    /// is no name matching and no guessing: a venue without a mapped venueKey
    /// is simply not rateable yet, and asking the backend about it would be a
    /// request we already know is a 404.
    nonisolated static func venueKey(forStableID stableID: String) -> String? {
        DiningVenueKeys.venueKey(forStableID: stableID)
    }

    nonisolated static func isRateable(stableID: String) -> Bool {
        DiningVenueKeys.isRateable(stableID: stableID)
    }
}

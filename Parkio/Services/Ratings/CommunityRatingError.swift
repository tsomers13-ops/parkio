// CommunityRatingError.swift — typed failures from the Community Ratings API.
//
// The cases are kept distinct on purpose. UI will almost certainly collapse
// most of them into one calm sentence, but the service layer must not do that
// collapsing: "the network is off", "this venue cannot be rated" and "your
// stored identity is stale" call for different behaviour, and only a caller
// that can tell them apart can choose.
//
// In particular `unavailable` must never be turned into an aggregate of zero.
// Zero ratings is a fact about a restaurant; unavailable is a fact about us.

import Foundation

enum CommunityRatingError: Error, Equatable {

    /// No usable connection. Nothing was sent.
    case networkUnavailable

    /// The ratings service answered, but cannot serve ratings right now (503).
    /// NOT the same as "this venue has no ratings".
    case serviceUnavailable

    /// This venueKey is not one the backend accepts (404). For iOS this
    /// normally means the venue is outside the current 62-venue pilot and
    /// should never have been asked about.
    case unknownVenue(venueKey: String)

    /// The stored credential was rejected (401). The credential should be
    /// discarded and a new anonymous identity provisioned.
    case invalidCredential

    /// The submission was rejected as malformed (400). A bug on this side.
    case validationFailed(message: String?)

    /// The write reached the server and did not happen. Never report success.
    case writeFailed

    /// Any other non-success status.
    case server(status: Int)

    /// The response was not the shape this app expects.
    case decodingFailed

    /// The app tried to rate a venue with no venueKey, or with values outside
    /// 1–5. Caught locally so a bad request is never sent.
    case notRateable

    /// Whether discarding the credential and retrying could plausibly help.
    var suggestsCredentialRefresh: Bool {
        self == .invalidCredential
    }
}

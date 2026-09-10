// CommunityRatingModels.swift — wire contract for Parkio Community Dining Ratings.
//
// These mirror the live Website API exactly; they are not a local model the app
// is free to reshape. The same rows back the website and this app, so a rating
// left here and a rating left on parkio.info land in the same community.
//
// Deliberately NOT to be confused with `DiningRating`, which is the private,
// on-device journal (favourite, notes, never leaves the device). This file is
// about the public, server-owned community score. Different data, different
// lifetime, different privacy story — hence different names.
//
// Two invariants carried from the backend:
//   • Zero is not the same as unavailable. An unrated venue has count 0 and a
//     nil average — never 0.0, which reads as "rated, and bad".
//   • Each optional dimension carries its own count, because a venue can have
//     40 Overall ratings and 6 Value ratings.

import Foundation

// MARK: - Aggregate

/// The public community aggregate for one venue.
struct CommunityRatingAggregate: Codable, Equatable, Sendable {

    let venueKey: String

    /// Number of Overall ratings. Zero is a fact, not a failure.
    let ratingCount: Int

    /// `nil` when nobody has rated this venue. Never 0.0 in that case.
    let overallAverage: Double?

    let tasteAverage: Double?
    let tasteCount: Int
    let valueAverage: Double?
    let valueCount: Int
    let qualityAverage: Double?
    let qualityCount: Int

    /// True when at least one guest has rated this venue.
    var hasRatings: Bool { ratingCount > 0 && overallAverage != nil }
}

/// The compact shape returned by the bulk discovery endpoint.
struct CommunityRatingSummary: Codable, Equatable, Sendable {
    let ratingCount: Int
    let overallAverage: Double?

    var hasRatings: Bool { ratingCount > 0 && overallAverage != nil }
}

/// `GET /api/dining/ratings/?venueKeys=…`
struct CommunityRatingSummaryResponse: Codable, Equatable, Sendable {
    let ratings: [String: CommunityRatingSummary]
}

// MARK: - Personal rating

/// This guest's own current rating for a venue.
///
/// Optional dimensions are genuinely optional: `nil` means "not answered",
/// never zero and never a copy of `overall`.
struct PersonalDiningRating: Codable, Equatable, Sendable {
    let overall: Int
    let taste: Int?
    let value: Int?
    let quality: Int?
}

/// `GET /api/dining/[venueKey]/ratings/me/` — `rating` is null when the guest
/// has not rated this venue, or is not identified at all.
struct PersonalRatingResponse: Codable, Equatable, Sendable {
    let venueKey: String
    let rating: PersonalDiningRating?
}

// MARK: - Submission

/// What the guest is submitting.
///
/// Encoding omits unanswered dimensions entirely rather than sending null, so
/// an unanswered Taste never reaches the database as a value.
struct DiningRatingSubmission: Equatable, Sendable {

    /// Required. Whole stars only.
    let overall: Int
    let taste: Int?
    let value: Int?
    let quality: Int?

    init(overall: Int, taste: Int? = nil, value: Int? = nil, quality: Int? = nil) {
        self.overall = overall
        self.taste = taste
        self.value = value
        self.quality = quality
    }

    /// 1–5 whole stars, matching the backend's validation and the D1 CHECK.
    static let starRange = 1...5

    var isValid: Bool {
        guard Self.starRange.contains(overall) else { return false }
        for dimension in [taste, value, quality] {
            if let dimension, !Self.starRange.contains(dimension) { return false }
        }
        return true
    }
}

extension DiningRatingSubmission: Encodable {
    enum CodingKeys: String, CodingKey { case overall, taste, value, quality }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overall, forKey: .overall)
        // encodeIfPresent, never encode(nil): the backend rejects unknown
        // shapes and treats an absent dimension as "not answered".
        try container.encodeIfPresent(taste, forKey: .taste)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(quality, forKey: .quality)
    }
}

/// `POST /api/dining/[venueKey]/ratings/` response.
///
/// The aggregate here is authoritative — callers replace what they were
/// showing rather than incrementing a count locally, because an update must
/// not add a vote and only the server knows which case it was.
struct DiningRatingSubmissionResponse: Codable, Equatable, Sendable {
    let rating: PersonalDiningRating
    let aggregate: CommunityRatingAggregate?
}

/// Whether the server created a new rating or revised an existing one.
enum DiningRatingWriteOutcome: Equatable, Sendable {
    case created
    case updated
}

struct DiningRatingSubmissionResult: Equatable, Sendable {
    let outcome: DiningRatingWriteOutcome
    let rating: PersonalDiningRating
    let aggregate: CommunityRatingAggregate?
}

// DiningRatingStore.swift — Observable store for user dining ratings.
//
// Persistence: UserDefaults + JSONEncoder/JSONDecoder.
//   Key:    "parkio_diningRatings_v1"
//   Format: [String: DiningRating] keyed by attractionID (stableID).
//
// Matches the persistence approach used for attraction favourites —
// UserDefaults JSON encoding, decoded once on init, written atomically on change.
//
// Injection:
//   Created once in DisneyRideTrackerApp, injected via .environment(diningRatingStore).
//   Consumers read: @Environment(DiningRatingStore.self) private var ratingStore

import SwiftUI

// MARK: - DiningRatingStore

@Observable
@MainActor
final class DiningRatingStore {

    // ── Source of truth ───────────────────────────────────────────────────────
    /// All saved ratings, keyed by attractionID (MasterAttraction stableID).
    private(set) var ratings: [String: DiningRating] = [:]

    // ── UserDefaults key ──────────────────────────────────────────────────────
    private let storageKey = "parkio_diningRatings_v1"

    // MARK: - Init

    init() { load() }

    // MARK: - Read

    /// Rating for the given stableID, or nil if the user hasn't rated this venue.
    func rating(for attractionID: String) -> DiningRating? {
        ratings[attractionID]
    }

    // MARK: - Write

    /// Persist a new or updated rating.
    func save(_ rating: DiningRating) {
        ratings[rating.attractionID] = rating
        persist()
    }

    /// Remove a rating entirely (used for future "delete review" UX).
    func delete(attractionID: String) {
        ratings.removeValue(forKey: attractionID)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: DiningRating].self, from: data)
        else { return }
        ratings = decoded
    }
}

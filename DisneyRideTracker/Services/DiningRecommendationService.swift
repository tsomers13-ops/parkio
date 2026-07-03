// DiningRecommendationService.swift — Personalised dining ranking engine.
//
// Design goals
// ────────────
// • Pure Swift — no SwiftUI, no persistence, no async.
// • Stateless — all inputs are explicit; the call site controls caching.
// • Extensible — scoring weights are isolated to Weight constants. Future
//   signals (time-of-day, Mobile Order, crowd level, distance, weather,
//   meal-type preference) can be added without restructuring call sites.
//
// Scoring model (Phase 2)
// ───────────────────────
//   Tier 1  Favourites       : 1 000 pts + (stars × 100) + parkioScore
//   Tier 2  Rated ★★★–★★★★★ : (stars × 100) + parkioScore
//   Tier 3  Rated ★–★★       : (stars × 100) + parkioScore
//   Tier 4  Unrated           : parkioScore (0–10)
//
// Within each tier, parkioScore acts as a fractional tiebreaker so Parkio
// editorial judgment still separates venues that share a user rating tier.
//
// Graceful fallback: when the user has no dining ratings at all, every venue
// scores in Tier 4 — ranking is identical to Phase 1 parkioScore order.
//
// Phase 3 extension points (not wired yet — see DiningRecommendationContext):
//   • currentHour      → breakfast / lunch / dinner type filtering
//   • crowdLevel       → prefer Mobile Order when park is busy
//   • userLocation     → distance-weight nearby venues
//   • mealTypeFilter   → quick service vs. table service preference

import Foundation

// MARK: - DiningRecommendationService

@MainActor
enum DiningRecommendationService {

    // MARK: - Weight constants

    private enum Weight {
        /// Points per user star (1★ = 100, 5★ = 500).
        static let perStar:    Double = 100
        /// Bonus for isFavorite — elevates favourites above all non-favourite rated venues.
        static let favorite:   Double = 1_000
        /// parkioScore (0–10) contributes directly as a tiebreaker fraction.
        /// No scaling needed — 10 pts is large enough to separate venues within
        /// each tier but small enough never to cross a tier boundary.
    }

    // MARK: - Public API

    /// Returns the top `limit` personalised dining recommendations for `park`.
    ///
    /// - Parameters:
    ///   - park:  The park whose seeded dining venues are scored.
    ///   - store: The user's `DiningRatingStore` (read-only).
    ///   - limit: Maximum recommendations to return (default 3 for home card).
    /// - Returns: Array of `DiningRecommendation`, sorted best-first.
    static func topRecommendations(
        for park: Park,
        store: DiningRatingStore,
        limit: Int = 3
    ) -> [DiningRecommendation] {
        let venues = RideMasterData.topDining(for: park)
        return Array(rank(venues, store: store).prefix(limit))
    }

    /// Score and rank an arbitrary array of dining venues.
    ///
    /// Use this when you already have a filtered subset of venues and want
    /// them sorted by personalised score (e.g. the full dining list view).
    static func rank(
        _ venues: [MasterAttraction],
        store: DiningRatingStore
    ) -> [DiningRecommendation] {
        venues
            .map { recommend(venue: $0, store: store) }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.venue.name < $1.venue.name   // A–Z tiebreaker
            }
    }

    /// Score and label a single venue against the user's rating history.
    ///
    /// Returns a `DiningRecommendation` with composite score and label —
    /// useful for per-venue display without re-ranking the full set.
    static func recommend(
        venue: MasterAttraction,
        store: DiningRatingStore
    ) -> DiningRecommendation {
        let rating = store.rating(for: venue.stableID)
        return DiningRecommendation(
            venue:  venue,
            rating: rating,
            score:  computeScore(venue: venue, rating: rating),
            label:  computeLabel(rating: rating)
        )
    }

    // MARK: - Private scoring

    private static func computeScore(
        venue: MasterAttraction,
        rating: DiningRating?
    ) -> Double {
        // Editorial base — always present, acts as fractional tiebreaker.
        let editorial = Double(venue.dining?.parkioScore ?? 0)

        guard let r = rating else {
            // Unrated: score is editorial only (Tier 4, 0–10 pts).
            return editorial
        }

        // Tier 1/2/3: rating-based score + editorial tiebreaker.
        let favBonus  = r.isFavorite ? Weight.favorite : 0
        let ratingPts = Double(r.rating) * Weight.perStar
        return favBonus + ratingPts + editorial
    }

    private static func computeLabel(
        rating: DiningRating?
    ) -> DiningRecommendation.Label {
        guard let r = rating else { return .neverTried }

        // Favourite label takes precedence over star count — "One of your
        // favorites" is the strongest signal we can surface, regardless of
        // how many stars the user awarded on that visit.
        if r.isFavorite { return .markedFavorite }

        switch r.rating {
        case 5:    return .lovedLastTrip
        case 4, 3: return .highlyRated(r.rating)
        case 2:    return .previouslyRated(r.rating)
        default:   return .wouldAvoid(r.rating)   // 1★
        }
    }
}

// MARK: - DiningRecommendationContext (Phase 3 stub)

/// Contextual signals that can influence ranking in a future version.
/// None of these are wired into the scoring algorithm yet — they are here
/// as a design record so Phase 3 can extend the service without changing
/// call sites that don't need the extra context.
struct DiningRecommendationContext: Sendable {
    /// Hour of day (0–23). Used to filter by meal type in a future version.
    var currentHour:    Int?
    /// Preferred meal type filter. nil = no preference.
    var mealType:       MealTypeHint?
    /// Park-wide crowd index (0.0 = empty, 1.0 = peak). Future: boost Mobile
    /// Order venues when crowds are high.
    var crowdLevel:     Double?

    enum MealTypeHint: Sendable {
        case breakfast, lunch, dinner, snack
    }
}

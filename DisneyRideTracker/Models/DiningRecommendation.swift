// DiningRecommendation.swift — Result type for DiningRecommendationService.
//
// Encapsulates a venue, its user rating, a composite ranking score, and a
// human-readable label so every call site gets everything it needs without
// re-running the same logic.
//
// Pure value type — no SwiftUI, no persistence, no async.

import Foundation

// MARK: - DiningRecommendation

struct DiningRecommendation: Identifiable, Sendable {

    /// The venue being scored.
    let venue:  MasterAttraction

    /// The user's persisted rating, or nil if never rated.
    let rating: DiningRating?

    /// Composite score computed by DiningRecommendationService.
    /// Higher = better; used for sorting only — never displayed to users.
    let score: Double

    /// Context-aware label derived from the user's rating history.
    let label: Label

    // Identifiable conformance mirrors MasterAttraction.stableID.
    var id: String { venue.stableID }

    // MARK: - Label

    /// Human-readable context, computed from user rating state.
    enum Label: Sendable {
        /// User rated this ★★★★★ and hasn't marked it a favourite.
        case lovedLastTrip
        /// User marked this as a Favourite (any star count).
        case markedFavorite
        /// User rated 3 or 4 stars.
        case highlyRated(Int)
        /// User rated 2 stars — neutral, informational.
        case previouslyRated(Int)
        /// User rated 1 star — gentle warning label.
        case wouldAvoid(Int)
        /// No entry in DiningRatingStore.
        case neverTried

        // MARK: Display

        /// Short natural-language copy for list rows and home cards.
        var displayString: String {
            switch self {
            case .lovedLastTrip:
                return "Loved this last trip"
            case .markedFavorite:
                return "One of your favorites"
            case .highlyRated(let n):
                return n == 4 ? "Really enjoyed this" : "Decent, worth a try"
            case .previouslyRated(let n):
                return "Previously rated \(starGlyph(n))"
            case .wouldAvoid(let n):
                return "Avoid? You rated this \(starGlyph(n))"
            case .neverTried:
                return "Haven't tried this yet"
            }
        }

        /// SF Symbol for use alongside the label text.
        var systemImage: String {
            switch self {
            case .markedFavorite:  return "heart.fill"
            case .lovedLastTrip:   return "star.fill"
            case .highlyRated:     return "star.leadinghalf.filled"
            case .previouslyRated: return "star.slash"
            case .wouldAvoid:      return "exclamationmark.circle"
            case .neverTried:      return "fork.knife"
            }
        }

        /// True for ★★★★☆ and above, or marked favourite.
        var isPositive: Bool {
            switch self {
            case .lovedLastTrip, .markedFavorite, .highlyRated: return true
            default: return false
            }
        }

        /// True when the user has never rated this venue.
        var isUnvisited: Bool {
            if case .neverTried = self { return true }
            return false
        }

        // MARK: Private

        private func starGlyph(_ filled: Int) -> String {
            String(repeating: "★", count: max(0, filled)) +
            String(repeating: "☆", count: max(0, 5 - filled))
        }
    }
}

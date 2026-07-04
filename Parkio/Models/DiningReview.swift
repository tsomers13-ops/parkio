// DiningReview.swift — SwiftData stub for future user dining reviews.
//
// STATUS: DATA STRUCTURE ONLY — NOT registered in ModelContainer schema.
//
// This model reserves the review fields for Parkio's second dining iteration.
// The model compiles today so the schema design can be reviewed and iterated on
// before any UI is built.
//
// When review UI is ready:
//   1. Add DiningReview.self to the Schema array in ParkioApp.swift.
//   2. Build DiningReviewSheet (capture wouldGoBack, foodRating, itemOrdered, shortTip).
//   3. Aggregate wouldGoBack% and average foodRating per venue and surface in
//      the dining list card (DiningVenueRow) and the venue detail view.
//
// Relationship to DiningMetadata:
//   DiningMetadata — Parkio editorial, static, always present for dining venues.
//   DiningReview   — user-generated, persisted per visit, nil until user logs a meal.
//
// TODO: Add DiningReview.self to ParkioApp.swift schema when ready:
//   Schema([Ride.self, RideLog.self, WaitTimeCache.self, ParkVisit.self, DiningReview.self])

import Foundation
import SwiftData

@Model
final class DiningReview {

    @Attribute(.unique) var id: UUID

    /// stableID of the reviewed venue — matches MasterAttraction.stableID.
    /// Format: "{Park.rawValue}|{land}|{venueName}"
    var venueId: String

    /// Wall-clock time the meal was eaten (not when the review was submitted).
    var timestamp: Date

    // MARK: - Review fields (all optional — captured progressively via UI)

    /// Would the guest come back specifically for this venue?
    var wouldGoBack: Bool?

    /// Food quality rating, 1–5 stars.
    var foodRating: Int?

    /// Was the food worth what it cost?
    var worthPrice: Bool?

    /// Specific item the guest ordered (informs future "what to order" suggestions).
    var itemOrdered: String?

    /// One-sentence tip for the next guest. E.g. "Ask for extra sauce."
    var shortTip: String?

    // MARK: - Init

    init(
        id:          UUID    = UUID(),
        venueId:     String,
        timestamp:   Date    = Date(),
        wouldGoBack: Bool?   = nil,
        foodRating:  Int?    = nil,
        worthPrice:  Bool?   = nil,
        itemOrdered: String? = nil,
        shortTip:    String? = nil
    ) {
        self.id          = id
        self.venueId     = venueId
        self.timestamp   = timestamp
        self.wouldGoBack = wouldGoBack
        self.foodRating  = foodRating
        self.worthPrice  = worthPrice
        self.itemOrdered = itemOrdered
        self.shortTip    = shortTip
    }
}

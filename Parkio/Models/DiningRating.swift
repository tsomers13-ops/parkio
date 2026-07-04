// DiningRating.swift — On-device user rating for a dining venue.
//
// Stored by DiningRatingStore as [attractionID: DiningRating] via
// JSONEncoder / UserDefaults — the same persistence pattern used for
// attraction favourites and recently-viewed lists.
//
// attractionID is the MasterAttraction stableID: "{Park.rawValue}|{land}|{name}".
//
// No accounts, cloud sync, or social features. Data never leaves the device.

import Foundation

// MARK: - DiningRating

struct DiningRating: Codable, Equatable {

    // MARK: Identity

    /// stableID of the rated venue — matches MasterAttraction.stableID and Ride.id.
    var attractionID: String

    // MARK: Rating fields

    /// Overall quality rating, 1–5 stars.
    var rating: Int

    /// User has marked this venue as a personal favourite.
    var isFavorite: Bool

    /// Personal note, max 200 characters. Empty string when not provided.
    var notes: String

    // MARK: Timestamps

    /// Date of the user's most-recent logged visit, if any.
    /// Updated from Ride.mostRecentDate each time a rating is saved.
    var lastVisited: Date?

    /// Timestamp when this rating was last saved.
    var dateRated: Date

    // MARK: Init

    init(
        attractionID: String,
        rating:       Int,
        isFavorite:   Bool   = false,
        notes:        String = "",
        lastVisited:  Date?  = nil,
        dateRated:    Date   = Date()
    ) {
        self.attractionID = attractionID
        self.rating       = max(1, min(5, rating))
        self.isFavorite   = isFavorite
        self.notes        = String(notes.prefix(200))
        self.lastVisited  = lastVisited
        self.dateRated    = dateRated
    }
}

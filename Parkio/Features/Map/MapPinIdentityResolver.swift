// MapPinIdentityResolver.swift — Pure name-matching algorithm behind
// ParkMapPin's canonical stableID resolution (see ParkMapPinResolution.swift
// for the real-data wiring).
//
// ParkMapPin.internalRideId is a short calibration handle (e.g. "mk|space-mountain",
// "mk|dining|be-our-guest") used only for pin identity and stagger-animation
// timing — it was never the canonical stableID scheme ("Park|Land|Name") every
// other layer of the app uses (RideMasterData, SwiftData Ride records,
// MapRideAnnotation, DiningVenueKeys). This resolver bridges that gap so a pin
// tap can drive the same ride-selection / dining-detail flows the rest of the
// app already uses, with no fake coordinates and no duplicated identity table.
//
// Matching tiers (first match wins) mirror WaitTimeViewModel's live-data name
// matching so a shortened map label (e.g. "Buzz Lightyear" for the canonical
// "Buzz Lightyear's Space Ranger Spin") never breaks resolution:
//   1. Exact name match
//   2. Alias match
//   3. Normalized substring containment
//
// Deliberately independent of RideMasterData/Park — takes plain candidate
// tuples — so the matching algorithm itself is unit testable via `swift test`
// without a UIKit/SwiftData-linked target.

import Foundation

struct StableIDCandidate {
    let name: String
    let aliases: [String]
    let stableID: String
}

enum MapPinIdentityResolver {

    /// Resolves a display name to a candidate's stableID, or nil if none matches.
    static func resolve(displayName: String, among candidates: [StableIDCandidate]) -> String? {
        if let exact = candidates.first(where: { $0.name == displayName }) {
            return exact.stableID
        }
        if let aliasMatch = candidates.first(where: { $0.aliases.contains(displayName) }) {
            return aliasMatch.stableID
        }
        let normalizedPin = normalized(displayName)
        if let containsMatch = candidates.first(where: { normalized($0.name).contains(normalizedPin) }) {
            return containsMatch.stableID
        }
        return nil
    }

    /// Same normalization as WaitTimeViewModel.normalizedForMatching — duplicated
    /// here (not imported) so this resolver stays Foundation-only and independently
    /// unit-testable without pulling SwiftUI/SwiftData into its dependency graph.
    static func normalized(_ s: String) -> String {
        s
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'") // RIGHT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{2018}", with: "'") // LEFT SINGLE QUOTATION MARK
            .replacingOccurrences(of: "\u{02BC}", with: "'") // MODIFIER LETTER APOSTROPHE
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "\u{2013}", with: " ") // EN DASH — must precede hyphen-minus line
            .replacingOccurrences(of: "\u{2014}", with: " ") // EM DASH
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

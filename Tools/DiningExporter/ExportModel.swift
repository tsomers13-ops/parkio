//
//  ExportModel.swift
//  dining-export
//
//  Exporter-only DTOs describing the generated Dining dataset.
//  These are a serialization contract, not a second source of truth: every
//  value is read from the real `MasterAttraction` / `DiningMetadata` models.
//

import Foundation

/// Top-level export document.
struct DiningExport: Encodable {
    let schemaVersion: Int
    let generator: String
    /// Commit the content was read from, resolved from Git at runtime.
    let sourceCommit: String
    /// True when the working tree differs from `sourceCommit` (see GitProvenance).
    let sourceDirty: Bool
    let venueCount: Int
    let venues: [DiningVenue]
}

/// One Dining venue. Deliberately carries no Website slug — public URL
/// assignment is Gate 2B and must not depend on the rename-sensitive iOS ID.
struct DiningVenue: Encodable {
    /// iOS stableID ("Park|Land|Name"). Internal join key only.
    let id: String
    let name: String
    let park: String
    let parkId: String
    let land: String
    let type: String
    /// ThemeParks.wiki entity UUID, omitted when the venue has none.
    let externalId: String?
    /// Omitted when the venue has no entry in MapCoordinates.json.
    let coordinate: ExportCoordinate?
    /// Omitted entirely when the venue has no DiningMetadata (factual-only venue).
    let editorial: Editorial?
}

struct ExportCoordinate: Encodable {
    let lat: Double
    let lon: Double
}

/// Editorial layer — present only for venues Parkio has actually reviewed.
struct Editorial: Encodable {
    let priceTier: Int
    let parkioScore: Int
    let shortVerdict: String
    let signatureItems: [String]
    let mobileOrderAvailable: Bool
    let indoorSeating: Bool
    let kidFriendly: Bool
    /// Sorted — the model stores an unordered Set.
    let dietaryFlags: [String]
}

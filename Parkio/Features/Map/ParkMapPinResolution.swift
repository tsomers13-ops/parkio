// ParkMapPinResolution.swift — Wires MapPinIdentityResolver's pure matching
// algorithm to the real RideMasterData/Park catalog.
//
// Kept separate from MapPinIdentityResolver.swift (which stays Foundation-only
// for unit testing) because RideMasterData/Park are not available to the
// ParkioMapTests SPM target — this file is compiled only as part of the app.

import Foundation

extension ParkMapPin {
    /// Canonical Ride stableID ("Park|Land|Name") this pin represents, resolved
    /// from its display name against the real RideMasterData catalog — nil if
    /// no MasterAttraction matches.
    var stableID: String? {
        guard let park = Park.fromBackendId(parkId) else { return nil }
        let candidates = RideMasterData.all
            .filter { $0.park == park }
            .map { StableIDCandidate(name: $0.name, aliases: $0.aliases, stableID: $0.stableID) }
        return MapPinIdentityResolver.resolve(displayName: displayName, among: candidates)
    }
}

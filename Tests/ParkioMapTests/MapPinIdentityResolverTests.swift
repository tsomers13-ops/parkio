// MapPinIdentityResolverTests.swift — the tiered name-matching algorithm that
// resolves a ParkMapPin's short display name to its canonical stableID.
//
// Fixtures mirror the real Magic Kingdom mismatches this resolver exists to
// handle (see ParkMapPinResolution.swift / ParkMapPinData.swift):
//   • "Buzz Lightyear" (pin)      → "Buzz Lightyear's Space Ranger Spin" (canonical)
//   • "WDW Railroad" (pin)        → "Walt Disney World Railroad" (canonical, via alias)
//   • "Little Mermaid" (pin)      → "Under the Sea – Journey of The Little Mermaid" (en dash)
//   • "it's a small world" (pin)  → "It's a Small World" (canonical, via alias, case-only)

import XCTest

@testable import Parkio

final class MapPinIdentityResolverTests: XCTestCase {

    private let candidates: [StableIDCandidate] = [
        .init(name: "Space Mountain", aliases: [], stableID: "MK|Tomorrowland|Space Mountain"),
        .init(
            name: "Buzz Lightyear's Space Ranger Spin", aliases: [],
            stableID: "MK|Tomorrowland|Buzz Lightyear's Space Ranger Spin"
        ),
        .init(
            name: "Walt Disney World Railroad", aliases: ["WDW Railroad"],
            stableID: "MK|Main Street, U.S.A.|Walt Disney World Railroad"
        ),
        .init(
            name: "Under the Sea \u{2013} Journey of The Little Mermaid", aliases: [],
            stableID: "MK|Fantasyland|Under the Sea \u{2013} Journey of The Little Mermaid"
        ),
        .init(
            name: "It's a Small World", aliases: ["it's a small world"],
            stableID: "MK|Fantasyland|It's a Small World"
        ),
        .init(
            name: "Tony's Town Square Restaurant", aliases: [],
            stableID: "MK|Main Street, U.S.A.|Tony's Town Square Restaurant"
        ),
    ]

    func testExactNameMatch() {
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "Space Mountain", among: candidates),
            "MK|Tomorrowland|Space Mountain"
        )
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "Tony's Town Square Restaurant", among: candidates),
            "MK|Main Street, U.S.A.|Tony's Town Square Restaurant"
        )
    }

    func testAliasMatchHandlesAnAcronymStyleMapLabel() {
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "WDW Railroad", among: candidates),
            "MK|Main Street, U.S.A.|Walt Disney World Railroad"
        )
    }

    func testAliasMatchIsCaseAndCharacterExact() {
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "it's a small world", among: candidates),
            "MK|Fantasyland|It's a Small World"
        )
    }

    func testNormalizedContainmentHandlesAShortenedDisplayName() {
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "Buzz Lightyear", among: candidates),
            "MK|Tomorrowland|Buzz Lightyear's Space Ranger Spin"
        )
    }

    func testNormalizedContainmentHandlesAnEnDashInTheCanonicalName() {
        XCTAssertEqual(
            MapPinIdentityResolver.resolve(displayName: "Little Mermaid", among: candidates),
            "MK|Fantasyland|Under the Sea \u{2013} Journey of The Little Mermaid"
        )
    }

    func testNoMatchReturnsNilRatherThanGuessing() {
        XCTAssertNil(MapPinIdentityResolver.resolve(displayName: "Splash Mountain", among: candidates))
    }

    func testResolutionIsScopedToTheGivenCandidateList() {
        // A pin's own park's candidates only — cross-park name collisions must
        // never resolve to the wrong park's attraction.
        let empty: [StableIDCandidate] = []
        XCTAssertNil(MapPinIdentityResolver.resolve(displayName: "Space Mountain", among: empty))
    }
}

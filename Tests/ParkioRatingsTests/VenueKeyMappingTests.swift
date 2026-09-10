import XCTest

/// The cross-platform identity mapping.
///
/// The 62/24 boundary against the real 86 iOS venues is verified separately by
/// `dining-export --verify-venue-keys`, which owns the Dining models. These
/// tests cover the mapping's own integrity.
final class VenueKeyMappingTests: XCTestCase {

    func testMapsExactlyTheCurrentPilot() {
        XCTAssertEqual(DiningVenueKeys.byStableID.count, 62)
        XCTAssertEqual(DiningVenueKeys.expectedCount, 62)
        XCTAssertEqual(DiningVenueKeys.byStableID.count, DiningVenueKeys.expectedCount)
    }

    func testNoTwoVenuesShareAVenueKey() {
        let keys = Array(DiningVenueKeys.byStableID.values)
        XCTAssertEqual(Set(keys).count, keys.count, "two iOS venues map to one venueKey")
    }

    func testEveryVenueKeyIsWellFormed() {
        let pattern = try! NSRegularExpression(pattern: "^(ep|hs)-[a-z0-9]+(-[a-z0-9]+)*$")
        for key in DiningVenueKeys.byStableID.values {
            let range = NSRange(key.startIndex..., in: key)
            XCTAssertNotNil(
                pattern.firstMatch(in: key, range: range),
                "malformed venueKey '\(key)'"
            )
        }
    }

    func testEveryKeyIsAParkLandNameStableID() {
        for stableID in DiningVenueKeys.byStableID.keys {
            XCTAssertEqual(
                stableID.components(separatedBy: "|").count, 3,
                "stableID is not Park|land|name: '\(stableID)'"
            )
        }
    }

    func testOnlyEpcotAndHollywoodStudiosArePresent() {
        // The pilot is EPCOT + DHS. Anything else means the mapping was
        // regenerated against an expanded backend without an explicit gate.
        let parks = Set(DiningVenueKeys.byStableID.keys.compactMap { $0.components(separatedBy: "|").first })
        XCTAssertEqual(parks, ["EPCOT", "Hollywood Studios"])
    }

    func testPrefixMatchesPark() {
        for (stableID, key) in DiningVenueKeys.byStableID {
            let park = stableID.components(separatedBy: "|").first
            if park == "EPCOT" {
                XCTAssertTrue(key.hasPrefix("ep-"), "\(key) is not an EPCOT key")
            } else {
                XCTAssertTrue(key.hasPrefix("hs-"), "\(key) is not a DHS key")
            }
        }
    }

    func testResolvesAKnownVenue() {
        XCTAssertEqual(
            DiningVenueKeys.venueKey(forStableID: "EPCOT|World Showcase|Le Cellier Steakhouse"),
            "ep-le-cellier"
        )
        XCTAssertTrue(DiningVenueKeys.isRateable(stableID: "EPCOT|World Showcase|Le Cellier Steakhouse"))
    }

    func testVenueOutsideThePilotIsNotRateable() {
        // A real Magic Kingdom venue: present in the app, not yet backed by
        // the ratings service. It must resolve to nil, not be guessed at.
        let mk = "Magic Kingdom|Liberty Square|Columbia Harbour House"
        XCTAssertNil(DiningVenueKeys.venueKey(forStableID: mk))
        XCTAssertFalse(DiningVenueKeys.isRateable(stableID: mk))
    }

    func testNoFuzzyMatching() {
        // Near-misses must fail closed rather than resolve to the real venue.
        for near in [
            "EPCOT|World Showcase|Le Cellier",
            "EPCOT|World Showcase|le cellier steakhouse",
            "Epcot|World Showcase|Le Cellier Steakhouse",
            "Le Cellier Steakhouse",
            "ep-le-cellier",
        ] {
            XCTAssertNil(DiningVenueKeys.venueKey(forStableID: near), "'\(near)' should not resolve")
        }
    }

    func testServiceExposesTheSameMapping() {
        XCTAssertEqual(
            CommunityRatingService.venueKey(forStableID: "EPCOT|World Showcase|Le Cellier Steakhouse"),
            "ep-le-cellier"
        )
        XCTAssertFalse(CommunityRatingService.isRateable(stableID: "Disneyland|Fantasyland|Nowhere"))
    }
}

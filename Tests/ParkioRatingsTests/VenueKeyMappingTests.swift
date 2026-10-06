import XCTest

@testable import Parkio

/// The cross-platform identity mapping.
///
/// The exact boundary against the real iOS venues is verified separately by
/// `dining-export --verify-venue-keys`, which owns the Dining models. These
/// tests cover the mapping's own integrity.
final class VenueKeyMappingTests: XCTestCase {

    func testMapsExactlyTheCurrentPilot() {
        XCTAssertEqual(DiningVenueKeys.byStableID.count, 193)
        XCTAssertEqual(DiningVenueKeys.expectedCount, 193)
        XCTAssertEqual(DiningVenueKeys.byStableID.count, DiningVenueKeys.expectedCount)
    }

    func testNoTwoVenuesShareAVenueKey() {
        let keys = Array(DiningVenueKeys.byStableID.values)
        XCTAssertEqual(Set(keys).count, keys.count, "two iOS venues map to one venueKey")
    }

    func testEveryVenueKeyIsWellFormed() {
        let pattern = try! NSRegularExpression(pattern: "^(ep|hs|mk|ak|dl|dca)-[a-z0-9]+(-[a-z0-9]+)*$")
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

    func testOnlyTheSixSupportedDiningParksArePresent() {
        // All six Dining parks are now eligible — EPCOT, Hollywood Studios,
        // Magic Kingdom, Animal Kingdom, Disneyland, and Disney California
        // Adventure. Anything else means the mapping was regenerated against
        // an expanded backend without an explicit gate.
        let parks = Set(DiningVenueKeys.byStableID.keys.compactMap { $0.components(separatedBy: "|").first })
        XCTAssertEqual(parks, ["EPCOT", "Hollywood Studios", "Magic Kingdom", "Animal Kingdom", "Disneyland", "Disney California Adventure"])
    }

    func testPrefixMatchesPark() {
        for (stableID, key) in DiningVenueKeys.byStableID {
            let park = stableID.components(separatedBy: "|").first
            switch park {
            case "EPCOT":
                XCTAssertTrue(key.hasPrefix("ep-"), "\(key) is not an EPCOT key")
            case "Hollywood Studios":
                XCTAssertTrue(key.hasPrefix("hs-"), "\(key) is not a DHS key")
            case "Magic Kingdom":
                XCTAssertTrue(key.hasPrefix("mk-"), "\(key) is not a Magic Kingdom key")
            case "Animal Kingdom":
                XCTAssertTrue(key.hasPrefix("ak-"), "\(key) is not an Animal Kingdom key")
            case "Disneyland":
                XCTAssertTrue(key.hasPrefix("dl-"), "\(key) is not a Disneyland key")
            case "Disney California Adventure":
                XCTAssertTrue(key.hasPrefix("dca-"), "\(key) is not a Disney California Adventure key")
            default:
                XCTFail("unexpected park in mapping: \(park ?? "nil")")
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

    func testUnsupportedVenueIsNotRateable() {
        // A synthetic, unsupported identity: no real Dining park in Parkio
        // is modeled but Community-Ratings-ineligible anymore (all six are
        // eligible), so this exercises the generic unknown-identity path
        // rather than a park-eligibility boundary. It must resolve to nil,
        // not be guessed at.
        let unsupported = "Unsupported Park|Unknown Land|Unknown Venue"
        XCTAssertNil(DiningVenueKeys.venueKey(forStableID: unsupported))
        XCTAssertFalse(DiningVenueKeys.isRateable(stableID: unsupported))
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
        XCTAssertFalse(CommunityRatingService.isRateable(stableID: "Disney California Adventure|Nowhere|Nowhere"))
    }
}

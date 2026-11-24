// DiningPriceTierTests.swift — catalog price tiers and the list-row price text.
//
// A venue with no tier must render no price at all. AttractionRow shows
// RideMasterData.diningPriceText only when that string is non-nil, so a nil
// result is the row's empty price, not a "$" placeholder.

import XCTest
@testable import Parkio

final class DiningPriceTierTests: XCTestCase {

    private var diningVenues: [MasterAttraction] {
        RideMasterData.all.filter { $0.type.isDining }
    }

    func testExactly175VenuesHaveATierAnd18HaveNone() {
        let tiered = diningVenues.filter { $0.dining?.priceTier != nil }
        let blank = diningVenues.filter { $0.dining?.priceTier == nil }
        XCTAssertEqual(diningVenues.count, 193)
        XCTAssertEqual(tiered.count, 175)
        XCTAssertEqual(blank.count, 18)
    }

    func testSpotCheckTiers() {
        XCTAssertEqual(price("Cinderella's Royal Table", park: .magicKingdom), .signature)
        XCTAssertEqual(price("Sunshine Seasons", park: .epcot), .budget)
        XCTAssertEqual(price("Le Cellier Steakhouse", park: .epcot), .upscale)
        // Same name in two parks, different tiers.
        XCTAssertEqual(
            price("Docking Bay 7 Food and Cargo", park: .hollywoodStudios),
            .moderate
        )
        XCTAssertEqual(
            price("Docking Bay 7 Food and Cargo", park: .disneyland),
            .budget
        )
    }

    func testBlankTierRendersNoDollarText() {
        let blanks = diningVenues.filter { $0.dining?.priceTier == nil }
        XCTAssertEqual(blanks.count, 18)
        for venue in blanks {
            let text = RideMasterData.diningPriceText(stableID: venue.stableID)
            XCTAssertNil(text, "\(venue.name) should render no price text")
        }

        let lounge = venue("The Hollywood Brown Derby Lounge", park: .hollywoodStudios)
        XCTAssertNil(lounge.dining?.priceTier)
        XCTAssertEqual(lounge.dining?.parkioScore, 8)
        XCTAssertEqual(
            lounge.dining?.shortVerdict,
            "Walk-up bar bites from a signature restaurant. Order the Cobb salad and grapefruit cake."
        )

        let grab = venue("GRAB-N-GOOF", park: .epcot)
        XCTAssertEqual(grab.type, .snackStand)
        XCTAssertNil(grab.dining)
        XCTAssertNil(RideMasterData.diningPriceText(stableID: grab.stableID))
    }

    func testTieredPriceTextIsTheTierGlyphs() {
        for venue in diningVenues {
            guard let tier = venue.dining?.priceTier else { continue }
            XCTAssertEqual(
                RideMasterData.diningPriceText(stableID: venue.stableID),
                String(repeating: "$", count: tier.rawValue),
                venue.name
            )
        }
        XCTAssertEqual(
            RideMasterData.diningPriceText(
                stableID: venue("Cinderella's Royal Table", park: .magicKingdom).stableID
            ),
            "$$$$"
        )
        XCTAssertEqual(
            RideMasterData.diningPriceText(
                stableID: venue("Sunshine Seasons", park: .epcot).stableID
            ),
            "$"
        )
        XCTAssertEqual(
            RideMasterData.diningPriceText(
                stableID: venue("Le Cellier Steakhouse", park: .epcot).stableID
            ),
            "$$$"
        )
    }

    private func venue(_ name: String, park: Park) -> MasterAttraction {
        let matches = diningVenues.filter { $0.name == name && $0.park == park }
        XCTAssertEqual(matches.count, 1, "\(park.rawValue) \(name)")
        return matches[0]
    }

    private func price(_ name: String, park: Park) -> PriceTier? {
        venue(name, park: park).dining?.priceTier
    }
}

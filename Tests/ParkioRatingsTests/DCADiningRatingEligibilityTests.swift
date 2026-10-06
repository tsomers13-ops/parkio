import XCTest

@testable import Parkio

/// Rating eligibility and identity-integrity guard for the 38-venue Disney
/// California Adventure Dining catalog (RideMasterData.dcaDining). DCA is
/// the sixth and final park to complete Community Ratings eligibility —
/// every stableID below is listed explicitly from the catalog itself, not
/// derived, so a regression in either the dining catalog or the generated
/// venueKey mapping fails this test rather than silently losing rating
/// eligibility for a venue a guest can actually see on the Dining list.
final class DCADiningRatingEligibilityTests: XCTestCase {

    private let dcaDiningStableIDs: [String] = [
        "Disney California Adventure|Avengers Campus|Pym Test Kitchen",
        "Disney California Adventure|Avengers Campus|Pym Tasting Lab",
        "Disney California Adventure|Avengers Campus|Shawarma Palace",
        "Disney California Adventure|Avengers Campus|Terran Treats",
        "Disney California Adventure|Cars Land|Flo's V8 Café",
        "Disney California Adventure|Cars Land|Cozy Cone Motel",
        "Disney California Adventure|Cars Land|Fillmore's Taste-In",
        "Disney California Adventure|Pixar Pier|Lamplight Lounge",
        "Disney California Adventure|Pixar Pier|Adorable Snowman Frosted Treats",
        "Disney California Adventure|Pixar Pier|Angry Dogs",
        "Disney California Adventure|Pixar Pier|Jack-Jack Cookie Num Nums",
        "Disney California Adventure|Pixar Pier|Poultry Palace",
        "Disney California Adventure|Pixar Pier|Señor Buzz Churros",
        "Disney California Adventure|Paradise Gardens Park|Corn Dog Castle",
        "Disney California Adventure|Paradise Gardens Park|Boardwalk Pizza & Pasta",
        "Disney California Adventure|Paradise Gardens Park|Paradise Garden Grill",
        "Disney California Adventure|Paradise Gardens Park|Bayside Brews",
        "Disney California Adventure|Grizzly Peak|Smokejumpers Grill",
        "Disney California Adventure|Buena Vista Street|Carthay Circle Restaurant",
        "Disney California Adventure|Buena Vista Street|Carthay Circle Lounge",
        "Disney California Adventure|Buena Vista Street|Clarabelle's Hand-Scooped Ice Cream",
        "Disney California Adventure|Buena Vista Street|Fiddler, Fifer & Practical Cafe",
        "Disney California Adventure|Hollywood Land|Award Wieners",
        "Disney California Adventure|Hollywood Land|Studio Catering Co.",
        "Disney California Adventure|Hollywood Land|Hollywood Lounge",
        "Disney California Adventure|Hollywood Land|Fairfax Market",
        "Disney California Adventure|Hollywood Land|Schmoozies!",
        "Disney California Adventure|San Fransokyo Square|Ghirardelli® Soda Fountain and Chocolate Shop",
        "Disney California Adventure|San Fransokyo Square|Cocina Cucamonga Mexican Grill",
        "Disney California Adventure|San Fransokyo Square|Lucky Fortune Cookery",
        "Disney California Adventure|San Fransokyo Square|Aunt Cass Café",
        "Disney California Adventure|San Fransokyo Square|Port of San Fransokyo Cervecería",
        "Disney California Adventure|San Fransokyo Square|Rita's Turbine Blenders",
        "Disney California Adventure|San Fransokyo Square|Cappuccino Cart",
        "Disney California Adventure|Performance Corridor|Wine Country Trattoria",
        "Disney California Adventure|Performance Corridor|Sonoma Terrace",
        "Disney California Adventure|Performance Corridor|Mendocino Terrace",
        "Disney California Adventure|Performance Corridor|Magic Key Terrace - Magic Key Holder Dining",
    ]

    /// Coordinates were verified via ThemeParks.wiki for these 28; the other
    /// 10 intentionally ship with no pin (no legitimate source found).
    private let coordinateVerifiedStableIDs: Set<String> = [
        "Disney California Adventure|Avengers Campus|Pym Test Kitchen",
        "Disney California Adventure|Avengers Campus|Pym Tasting Lab",
        "Disney California Adventure|Cars Land|Flo's V8 Café",
        "Disney California Adventure|Cars Land|Cozy Cone Motel",
        "Disney California Adventure|Pixar Pier|Lamplight Lounge",
        "Disney California Adventure|Pixar Pier|Adorable Snowman Frosted Treats",
        "Disney California Adventure|Paradise Gardens Park|Corn Dog Castle",
        "Disney California Adventure|Paradise Gardens Park|Boardwalk Pizza & Pasta",
        "Disney California Adventure|Paradise Gardens Park|Paradise Garden Grill",
        "Disney California Adventure|Paradise Gardens Park|Bayside Brews",
        "Disney California Adventure|Grizzly Peak|Smokejumpers Grill",
        "Disney California Adventure|Buena Vista Street|Carthay Circle Restaurant",
        "Disney California Adventure|Buena Vista Street|Carthay Circle Lounge",
        "Disney California Adventure|Buena Vista Street|Clarabelle's Hand-Scooped Ice Cream",
        "Disney California Adventure|Hollywood Land|Award Wieners",
        "Disney California Adventure|Hollywood Land|Studio Catering Co.",
        "Disney California Adventure|Hollywood Land|Hollywood Lounge",
        "Disney California Adventure|Hollywood Land|Schmoozies!",
        "Disney California Adventure|San Fransokyo Square|Cocina Cucamonga Mexican Grill",
        "Disney California Adventure|San Fransokyo Square|Lucky Fortune Cookery",
        "Disney California Adventure|San Fransokyo Square|Aunt Cass Café",
        "Disney California Adventure|San Fransokyo Square|Port of San Fransokyo Cervecería",
        "Disney California Adventure|San Fransokyo Square|Rita's Turbine Blenders",
        "Disney California Adventure|San Fransokyo Square|Cappuccino Cart",
        "Disney California Adventure|Performance Corridor|Wine Country Trattoria",
        "Disney California Adventure|Performance Corridor|Sonoma Terrace",
        "Disney California Adventure|Performance Corridor|Mendocino Terrace",
        "Disney California Adventure|Performance Corridor|Magic Key Terrace - Magic Key Holder Dining",
    ]

    /// The 10 venues with no verified coordinate — must NOT have a map pin.
    private let noCoordinateStableIDs: [String] = [
        "Disney California Adventure|Avengers Campus|Shawarma Palace",
        "Disney California Adventure|Avengers Campus|Terran Treats",
        "Disney California Adventure|Cars Land|Fillmore's Taste-In",
        "Disney California Adventure|Pixar Pier|Angry Dogs",
        "Disney California Adventure|Pixar Pier|Jack-Jack Cookie Num Nums",
        "Disney California Adventure|Pixar Pier|Poultry Palace",
        "Disney California Adventure|Pixar Pier|Señor Buzz Churros",
        "Disney California Adventure|Buena Vista Street|Fiddler, Fifer & Practical Cafe",
        "Disney California Adventure|Hollywood Land|Fairfax Market",
        "Disney California Adventure|San Fransokyo Square|Ghirardelli® Soda Fountain and Chocolate Shop",
    ]

    func testAllThirtyEightDCADiningVenuesAreListed() {
        XCTAssertEqual(dcaDiningStableIDs.count, 38)
        XCTAssertEqual(Set(dcaDiningStableIDs).count, 38, "duplicate stableID in the fixture list")
    }

    func testFixtureMatchesTheLiveCatalogExactly() {
        let catalogIDs = Set(RideMasterData.dcaDining.map(\.stableID))
        XCTAssertEqual(
            Set(dcaDiningStableIDs), catalogIDs,
            "fixture list has drifted from RideMasterData.dcaDining — update both together"
        )
    }

    func testEveryVenueLandIsValidForDCA() {
        let validLands = Set(Park.californiaAdventure.lands)
        for attraction in RideMasterData.dcaDining {
            XCTAssertTrue(
                validLands.contains(attraction.land),
                "\(attraction.stableID) uses land '\(attraction.land)', not in Park.lands for California Adventure"
            )
        }
    }

    func testSanFransokyoSquareAndPerformanceCorridorAreValidDCALands() {
        XCTAssertTrue(Park.californiaAdventure.lands.contains("San Fransokyo Square"))
        XCTAssertTrue(Park.californiaAdventure.lands.contains("Performance Corridor"))
    }

    func testBoudinBreadCartWasNotAddedAsAnIdentity() {
        // Excluded by Product decision: no first-party page, land not
        // first-party verifiable, cart-class identity.
        let ids = Set(RideMasterData.dcaDining.map(\.stableID))
        XCTAssertFalse(ids.contains { $0.hasSuffix("|Boudin Bread Cart") })
    }

    func testLamplightLoungeBoardwalkDiningIsNotADuplicateIdentity() {
        // Excluded as a separate identity by Product decision — same
        // building as Lamplight Lounge (confirmed via identical
        // ThemeParks.wiki coordinates), represented through that single
        // existing identity instead.
        let ids = Set(RideMasterData.dcaDining.map(\.stableID))
        XCTAssertFalse(ids.contains("Disney California Adventure|Pixar Pier|Lamplight Lounge - Boardwalk Dining"))
        XCTAssertTrue(ids.contains("Disney California Adventure|Pixar Pier|Lamplight Lounge"))
    }

    func testMagicKeyTerraceIsIncludedDespiteAccessRestriction() {
        // Real permanent physical venue; the Magic Key access restriction
        // does not make it cease to exist — Product decision 2026-10-06.
        let ids = Set(RideMasterData.dcaDining.map(\.stableID))
        XCTAssertTrue(ids.contains("Disney California Adventure|Performance Corridor|Magic Key Terrace - Magic Key Holder Dining"))
    }

    func testCoordinateCoverageMatchesTheVerifiedSet() {
        let service = MapCoordinateService.shared
        for stableID in coordinateVerifiedStableIDs {
            XCTAssertNotNil(
                service.annotation(forRideId: stableID, parkId: "california-adventure"),
                "\(stableID) should have a verified coordinate"
            )
        }
        for stableID in noCoordinateStableIDs {
            XCTAssertNil(
                service.annotation(forRideId: stableID, parkId: "california-adventure"),
                "\(stableID) should NOT have a map pin — no verified coordinate exists"
            )
        }
    }

    func testEveryDCADiningVenueIsRateable() {
        for stableID in dcaDiningStableIDs {
            XCTAssertTrue(
                DiningVenueKeys.isRateable(stableID: stableID),
                "\(stableID) is in the DCA Dining catalog but has no venueKey — the Community section would never appear for a real venue"
            )
            XCTAssertNotNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testEveryDCADiningVenueResolvesToADcaVenueKey() {
        for stableID in dcaDiningStableIDs {
            guard let key = DiningVenueKeys.venueKey(forStableID: stableID) else {
                XCTFail("\(stableID) has no venueKey")
                continue
            }
            XCTAssertTrue(key.hasPrefix("dca-"), "\(stableID) mapped to non-DCA venueKey '\(key)'")
        }
    }

    func testAllSixDiningParksAreNowCommunityRatingsEligible() {
        // DCA was the last ineligible park — after this expansion there is
        // no concept of "a real Parkio Dining park intentionally outside
        // Community Ratings" left in the product.
        let parks = Set(DiningVenueKeys.byStableID.keys.compactMap { $0.components(separatedBy: "|").first })
        XCTAssertEqual(parks, ["EPCOT", "Hollywood Studios", "Magic Kingdom", "Animal Kingdom", "Disneyland", "Disney California Adventure"])
    }
}

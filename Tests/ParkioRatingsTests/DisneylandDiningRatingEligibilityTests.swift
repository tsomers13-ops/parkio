import XCTest

@testable import Parkio

/// Rating eligibility and identity-integrity guard for the 35-venue Disneyland
/// Dining catalog (RideMasterData.disneylandDining). Every stableID below is
/// listed explicitly from the catalog itself, not derived, so a regression in
/// either the dining catalog or the generated venueKey mapping fails this
/// test rather than silently losing rating eligibility for a venue a guest
/// can actually see on the Dining list.
final class DisneylandDiningRatingEligibilityTests: XCTestCase {

    private let disneylandDiningStableIDs: [String] = [
        "Disneyland|Main Street, U.S.A.|Carnation Café",
        "Disneyland|Main Street, U.S.A.|Gibson Girl Ice Cream Parlor",
        "Disneyland|Main Street, U.S.A.|Jolly Holiday Bakery Cafe",
        "Disneyland|Main Street, U.S.A.|Little Red Wagon",
        "Disneyland|Main Street, U.S.A.|Market House",
        "Disneyland|Main Street, U.S.A.|Refreshment Corner",
        "Disneyland|Main Street, U.S.A.|Plaza Inn",
        "Disneyland|Adventureland|The Tropical Hideaway",
        "Disneyland|Adventureland|Bengal Barbecue",
        "Disneyland|Adventureland|South Seas Traders",
        "Disneyland|Adventureland|Tiki Juice Bar",
        "Disneyland|New Orleans Square|Blue Bayou Restaurant",
        "Disneyland|New Orleans Square|Cafe Orleans",
        "Disneyland|New Orleans Square|Harbour Galley",
        "Disneyland|New Orleans Square|Mint Julep Bar",
        "Disneyland|New Orleans Square|Royal Street Veranda",
        "Disneyland|New Orleans Square|Tiana's Palace",
        "Disneyland|Bayou Country|Hungry Bear Barbecue Jamboree",
        "Disneyland|Frontierland|The Golden Horseshoe",
        "Disneyland|Frontierland|Rancho del Zocalo Restaurante",
        "Disneyland|Frontierland|River Belle Terrace",
        "Disneyland|Frontierland|Stage Door Café",
        "Disneyland|Fantasyland|Edelweiss Snacks",
        "Disneyland|Fantasyland|Maurice's Treats",
        "Disneyland|Fantasyland|Red Rose Taverne",
        "Disneyland|Fantasyland|Troubadour Tavern",
        "Disneyland|Mickey's Toontown|Café Daisy",
        "Disneyland|Mickey's Toontown|Good Boy! Grocers",
        "Disneyland|Tomorrowland|Galactic Grill",
        "Disneyland|Tomorrowland|Alien Pizza Planet",
        "Disneyland|Star Wars: Galaxy's Edge|Docking Bay 7 Food and Cargo",
        "Disneyland|Star Wars: Galaxy's Edge|Kat Saka's Kettle",
        "Disneyland|Star Wars: Galaxy's Edge|Milk Stand",
        "Disneyland|Star Wars: Galaxy's Edge|Oga's Cantina at the Disneyland Resort",
        "Disneyland|Star Wars: Galaxy's Edge|Ronto Roasters",
    ]

    /// Coordinates were verified via ThemeParks.wiki for these 28; the other
    /// 7 intentionally ship with no pin (no legitimate source found).
    private let coordinateVerifiedStableIDs: Set<String> = [
        "Disneyland|Main Street, U.S.A.|Carnation Café",
        "Disneyland|Main Street, U.S.A.|Gibson Girl Ice Cream Parlor",
        "Disneyland|Main Street, U.S.A.|Jolly Holiday Bakery Cafe",
        "Disneyland|Main Street, U.S.A.|Little Red Wagon",
        "Disneyland|Main Street, U.S.A.|Refreshment Corner",
        "Disneyland|Main Street, U.S.A.|Plaza Inn",
        "Disneyland|Adventureland|The Tropical Hideaway",
        "Disneyland|Adventureland|Bengal Barbecue",
        "Disneyland|Adventureland|Tiki Juice Bar",
        "Disneyland|New Orleans Square|Blue Bayou Restaurant",
        "Disneyland|New Orleans Square|Cafe Orleans",
        "Disneyland|New Orleans Square|Harbour Galley",
        "Disneyland|New Orleans Square|Mint Julep Bar",
        "Disneyland|New Orleans Square|Royal Street Veranda",
        "Disneyland|New Orleans Square|Tiana's Palace",
        "Disneyland|Bayou Country|Hungry Bear Barbecue Jamboree",
        "Disneyland|Frontierland|River Belle Terrace",
        "Disneyland|Frontierland|Stage Door Café",
        "Disneyland|Fantasyland|Edelweiss Snacks",
        "Disneyland|Fantasyland|Red Rose Taverne",
        "Disneyland|Fantasyland|Troubadour Tavern",
        "Disneyland|Mickey's Toontown|Café Daisy",
        "Disneyland|Tomorrowland|Galactic Grill",
        "Disneyland|Tomorrowland|Alien Pizza Planet",
        "Disneyland|Star Wars: Galaxy's Edge|Docking Bay 7 Food and Cargo",
        "Disneyland|Star Wars: Galaxy's Edge|Milk Stand",
        "Disneyland|Star Wars: Galaxy's Edge|Oga's Cantina at the Disneyland Resort",
        "Disneyland|Star Wars: Galaxy's Edge|Ronto Roasters",
    ]

    /// The 7 venues with no verified coordinate — must NOT have a map pin.
    private let noCoordinateStableIDs: [String] = [
        "Disneyland|Main Street, U.S.A.|Market House",
        "Disneyland|Adventureland|South Seas Traders",
        "Disneyland|Frontierland|The Golden Horseshoe",
        "Disneyland|Frontierland|Rancho del Zocalo Restaurante",
        "Disneyland|Fantasyland|Maurice's Treats",
        "Disneyland|Mickey's Toontown|Good Boy! Grocers",
        "Disneyland|Star Wars: Galaxy's Edge|Kat Saka's Kettle",
    ]

    func testAllThirtyFiveDisneylandDiningVenuesAreListed() {
        XCTAssertEqual(disneylandDiningStableIDs.count, 35)
        XCTAssertEqual(Set(disneylandDiningStableIDs).count, 35, "duplicate stableID in the fixture list")
    }

    func testFixtureMatchesTheLiveCatalogExactly() {
        let catalogIDs = Set(RideMasterData.disneylandDining.map(\.stableID))
        XCTAssertEqual(
            Set(disneylandDiningStableIDs), catalogIDs,
            "fixture list has drifted from RideMasterData.disneylandDining — update both together"
        )
    }

    func testEveryVenueLandIsValidForDisneyland() {
        let validLands = Set(Park.disneyland.lands)
        for attraction in RideMasterData.disneylandDining {
            XCTAssertTrue(
                validLands.contains(attraction.land),
                "\(attraction.stableID) uses land '\(attraction.land)', not in Park.lands for Disneyland"
            )
        }
    }

    func testCritterCountryIsNoLongerAValidDisneylandLand() {
        XCTAssertFalse(
            Park.disneyland.lands.contains("Critter Country"),
            "Critter Country should have been replaced by Bayou Country"
        )
        XCTAssertTrue(Park.disneyland.lands.contains("Bayou Country"))
    }

    func testApprovedIdentityMigrationsAreReflectedInTheCatalog() {
        let ids = Set(RideMasterData.disneylandDining.map(\.stableID))
        XCTAssertTrue(ids.contains("Disneyland|Bayou Country|Hungry Bear Barbecue Jamboree"))
        XCTAssertFalse(ids.contains("Disneyland|Critter Country|Hungry Bear Restaurant"))
        XCTAssertTrue(ids.contains("Disneyland|Adventureland|The Tropical Hideaway"))
        XCTAssertFalse(ids.contains("Disneyland|Adventureland|Tropical Hideaway"))
        XCTAssertTrue(ids.contains("Disneyland|New Orleans Square|Cafe Orleans"))
        XCTAssertFalse(ids.contains("Disneyland|New Orleans Square|Café Orleans"))
    }

    func testCoordinateCoverageMatchesTheVerifiedSet() {
        let service = MapCoordinateService.shared
        for stableID in coordinateVerifiedStableIDs {
            XCTAssertNotNil(
                service.annotation(forRideId: stableID, parkId: "disneyland"),
                "\(stableID) should have a verified coordinate"
            )
        }
        for stableID in noCoordinateStableIDs {
            XCTAssertNil(
                service.annotation(forRideId: stableID, parkId: "disneyland"),
                "\(stableID) should NOT have a map pin — no verified coordinate exists"
            )
        }
    }

    func testEveryDisneylandDiningVenueIsRateable() {
        for stableID in disneylandDiningStableIDs {
            XCTAssertTrue(
                DiningVenueKeys.isRateable(stableID: stableID),
                "\(stableID) is in the Disneyland Dining catalog but has no venueKey — the Community section would never appear for a real venue"
            )
            XCTAssertNotNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testEveryDisneylandDiningVenueResolvesToADlVenueKey() {
        for stableID in disneylandDiningStableIDs {
            guard let key = DiningVenueKeys.venueKey(forStableID: stableID) else {
                XCTFail("\(stableID) has no venueKey")
                continue
            }
            XCTAssertTrue(key.hasPrefix("dl-"), "\(stableID) mapped to non-Disneyland venueKey '\(key)'")
        }
    }
}

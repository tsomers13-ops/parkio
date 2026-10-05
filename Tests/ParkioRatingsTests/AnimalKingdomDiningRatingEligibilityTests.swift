import XCTest

@testable import Parkio

/// Rating eligibility for the 27-venue Animal Kingdom Dining catalog
/// (RideMasterData.akDining). Unlike Magic Kingdom, Animal Kingdom has no
/// custom map canvas — every venue below is listed explicitly from the
/// catalog itself, not derived from map pin data, so a regression in either
/// the dining catalog or the generated venueKey mapping fails this test
/// rather than silently losing rating eligibility for a venue a guest can
/// actually see on the Dining list.
final class AnimalKingdomDiningRatingEligibilityTests: XCTestCase {

    private let animalKingdomDiningStableIDs: [String] = [
        "Animal Kingdom|Discovery Island|Flame Tree Barbecue",
        "Animal Kingdom|Discovery Island|Tiffins Restaurant",
        "Animal Kingdom|Discovery Island|Pizzafari",
        "Animal Kingdom|Discovery Island|Creature Comforts",
        "Animal Kingdom|Discovery Island|Nomad Lounge & Cocktail Bar",
        "Animal Kingdom|Discovery Island|Isle of Java",
        "Animal Kingdom|Discovery Island|Eight Spoon Café",
        "Animal Kingdom|Discovery Island|The Smiling Crocodile",
        "Animal Kingdom|Discovery Island|Terra Treats and Snack Shop",
        "Animal Kingdom|Africa|Harambe Market",
        "Animal Kingdom|Africa|Tusker House Restaurant",
        "Animal Kingdom|Africa|Kusafiri Coffee Shop & Bakery",
        "Animal Kingdom|Africa|Dawa Bar",
        "Animal Kingdom|Africa|Tamu Tamu Refreshments",
        "Animal Kingdom|Africa|Harambe Fruit Market",
        "Animal Kingdom|Africa|Mahindi",
        "Animal Kingdom|Asia|Yak & Yeti Local Food Cafes",
        "Animal Kingdom|Asia|Yak & Yeti Restaurant",
        "Animal Kingdom|Asia|Thirsty River Bar & Trek Snacks",
        "Animal Kingdom|Asia|Yak & Yeti Quality Beverages",
        "Animal Kingdom|Asia|Warung Outpost",
        "Animal Kingdom|Asia|Drinkwallah",
        "Animal Kingdom|Asia|Caravan Road",
        "Animal Kingdom|Asia|Anandapur Ice Cream Truck",
        "Animal Kingdom|Pandora|Satu'li Canteen",
        "Animal Kingdom|Pandora|Pongu Pongu",
        "Animal Kingdom|Main Entrance|Rainforest Cafe at Disney's Animal Kingdom",
    ]

    func testAllTwentySevenAnimalKingdomDiningVenuesAreListed() {
        XCTAssertEqual(animalKingdomDiningStableIDs.count, 27)
        XCTAssertEqual(Set(animalKingdomDiningStableIDs).count, 27, "duplicate stableID in the fixture list")
    }

    func testFixtureMatchesTheLiveCatalogExactly() {
        let catalogIDs = Set(RideMasterData.akDining.map(\.stableID))
        XCTAssertEqual(
            Set(animalKingdomDiningStableIDs), catalogIDs,
            "fixture list has drifted from RideMasterData.akDining — update both together"
        )
    }

    func testEveryAnimalKingdomDiningVenueIsRateable() {
        for stableID in animalKingdomDiningStableIDs {
            XCTAssertTrue(
                DiningVenueKeys.isRateable(stableID: stableID),
                "\(stableID) is in the Animal Kingdom Dining catalog but has no venueKey — the Community section would never appear for a real venue"
            )
            XCTAssertNotNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testEveryAnimalKingdomDiningVenueResolvesToAnAkVenueKey() {
        for stableID in animalKingdomDiningStableIDs {
            guard let key = DiningVenueKeys.venueKey(forStableID: stableID) else {
                XCTFail("\(stableID) has no venueKey")
                continue
            }
            XCTAssertTrue(key.hasPrefix("ak-"), "\(stableID) mapped to non-AK venueKey '\(key)'")
        }
    }
}

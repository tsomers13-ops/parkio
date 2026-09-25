import XCTest

/// Rating eligibility for the 31 Magic Kingdom dining pins added to the custom
/// map canvas (ParkMapPinData.magicKingdomPins). Each stableID below is the
/// canonical "Park|Land|Name" identity MapPinIdentityResolver resolves a
/// dining pin's display name to (see ParkMapPinResolution.swift) — listed
/// here explicitly, not derived, so a regression in either the map pin data
/// or the generated venueKey mapping fails this test rather than silently
/// losing rating eligibility for a venue a guest can actually tap.
final class MagicKingdomMapDiningRatingEligibilityTests: XCTestCase {

    private let magicKingdomDiningStableIDs: [String] = [
        "Magic Kingdom|Main Street, U.S.A.|Tony's Town Square Restaurant",
        "Magic Kingdom|Main Street, U.S.A.|Main Street Bakery",
        "Magic Kingdom|Main Street, U.S.A.|The Plaza Restaurant",
        "Magic Kingdom|Main Street, U.S.A.|Plaza Ice Cream Parlor",
        "Magic Kingdom|Main Street, U.S.A.|Casey's Corner",
        "Magic Kingdom|Main Street, U.S.A.|The Crystal Palace",
        "Magic Kingdom|Adventureland|Spring Roll Snack Cart",
        "Magic Kingdom|Adventureland|Sunshine Tree Terrace",
        "Magic Kingdom|Adventureland|Jungle Navigation Co. LTD Skipper Canteen",
        "Magic Kingdom|Adventureland|Aloha Isle",
        "Magic Kingdom|Adventureland|The Beak and Barrel",
        "Magic Kingdom|Frontierland|Golden Oak Outpost",
        "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe",
        "Magic Kingdom|Liberty Square|The Diamond Horseshoe",
        "Magic Kingdom|Liberty Square|Liberty Tree Tavern",
        "Magic Kingdom|Liberty Square|Sleepy Hollow",
        "Magic Kingdom|Fantasyland|Pinocchio Village Haus",
        "Magic Kingdom|Fantasyland|Cinderella's Royal Table",
        "Magic Kingdom|Fantasyland|The Friar's Nook",
        "Magic Kingdom|Fantasyland|Storybook Treats",
        "Magic Kingdom|Fantasyland|Be Our Guest Restaurant",
        "Magic Kingdom|Fantasyland|Gaston's Tavern",
        "Magic Kingdom|Fantasyland|Prince Eric's Village Market",
        "Magic Kingdom|Fantasyland|Cheshire Café",
        "Magic Kingdom|Tomorrowland|Energy Bytes",
        "Magic Kingdom|Tomorrowland|Cosmic Ray's Starlight Café",
        "Magic Kingdom|Tomorrowland|Auntie Gravity's Galactic Goodies",
        "Magic Kingdom|Tomorrowland|AstroFizz Hosted by Coca-Cola",
        "Magic Kingdom|Tomorrowland|Joffrey's Coffee & Tea Company",
        "Magic Kingdom|Tomorrowland|The Lunching Pad",
        "Magic Kingdom|Tomorrowland|Fireworks Dessert Parties at Tomorrowland Terrace Restaurant",
    ]

    func testAllThirtyOneMagicKingdomMapDiningPinsAreListed() {
        XCTAssertEqual(magicKingdomDiningStableIDs.count, 31)
        XCTAssertEqual(Set(magicKingdomDiningStableIDs).count, 31, "duplicate stableID in the fixture list")
    }

    func testEveryMagicKingdomMapDiningPinIsRateable() {
        for stableID in magicKingdomDiningStableIDs {
            XCTAssertTrue(
                DiningVenueKeys.isRateable(stableID: stableID),
                "\(stableID) resolved from a map pin but has no venueKey — tapping it would open a rating UI with nothing to submit against"
            )
            XCTAssertNotNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testEveryMagicKingdomMapDiningPinResolvesToAnMkVenueKey() {
        for stableID in magicKingdomDiningStableIDs {
            guard let key = DiningVenueKeys.venueKey(forStableID: stableID) else {
                XCTFail("\(stableID) has no venueKey")
                continue
            }
            XCTAssertTrue(key.hasPrefix("mk-"), "\(stableID) mapped to non-MK venueKey '\(key)'")
        }
    }
}

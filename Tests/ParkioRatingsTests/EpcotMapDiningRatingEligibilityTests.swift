import XCTest

@testable import Parkio

/// Rating eligibility for the 41 EPCOT dining pins added to the Explore Map
/// canvas (ParkMapPinData.epcotPins). Mirrors
/// MagicKingdomMapDiningRatingEligibilityTests: each stableID below is the
/// canonical "Park|Land|Name" identity MapPinIdentityResolver resolves a
/// dining pin's display name to (see ParkMapPinResolution.swift) — listed
/// explicitly, not derived, so a regression in either the map pin data or the
/// generated venueKey mapping fails this test rather than silently losing
/// rating eligibility for a venue a guest can actually tap.
///
/// "Space 220 Lounge" is deliberately excluded — it has no map pin (map: nil
/// in RideMasterData+Dining.swift, identical coordinate to Space 220
/// Restaurant) even though it does have its own venueKey.
final class EpcotMapDiningRatingEligibilityTests: XCTestCase {

    private let epcotDiningStableIDs: [String] = [
        "EPCOT|World Celebration|Connections Eatery",
        "EPCOT|World Celebration|GEO-82",
        "EPCOT|World Celebration|GRAB-N-GOOF",
        "EPCOT|World Discovery|Space 220 Restaurant",
        "EPCOT|World Nature|Sunshine Seasons",
        "EPCOT|World Nature|Garden Grill Restaurant",
        "EPCOT|World Showcase|La Cantina de San Angel",
        "EPCOT|World Showcase|San Angel Inn Restaurante",
        "EPCOT|World Showcase|La Hacienda de San Angel",
        "EPCOT|World Showcase|La Cava del Tequila",
        "EPCOT|World Showcase|Choza de Margarita",
        "EPCOT|World Showcase|Akershus Royal Banquet Hall",
        "EPCOT|World Showcase|Nine Dragons Restaurant",
        "EPCOT|World Showcase|Refreshment Outpost",
        "EPCOT|World Showcase|Biergarten Restaurant",
        "EPCOT|World Showcase|Sommerfest",
        "EPCOT|World Showcase|Karamell-K\u{00FC}che",
        "EPCOT|World Showcase|Tutto Italia Ristorante",
        "EPCOT|World Showcase|Via Napoli Ristorante e Pizzeria",
        "EPCOT|World Showcase|Tutto Gusto Wine Cellar",
        "EPCOT|World Showcase|Regal Eagle Smokehouse",
        "EPCOT|World Showcase|Fife & Drum Tavern",
        "EPCOT|World Showcase|Block & Hans",
        "EPCOT|World Showcase|Katsura Grill",
        "EPCOT|World Showcase|Teppan Edo",
        "EPCOT|World Showcase|Takumi-Tei",
        "EPCOT|World Showcase|Shiki-Sai: Sushi Izakaya",
        "EPCOT|World Showcase|Tangierine Café",
        "EPCOT|World Showcase|Spice Road Table",
        "EPCOT|World Showcase|Les Halles Boulangerie-Patisserie",
        "EPCOT|World Showcase|L'Artisan des Glaces",
        "EPCOT|World Showcase|Monsieur Paul",
        "EPCOT|World Showcase|Chefs de France",
        "EPCOT|World Showcase|Les Vins des Chefs de France",
        "EPCOT|World Showcase|La Crêperie de Paris",
        "EPCOT|World Showcase|Rose & Crown Dining Room",
        "EPCOT|World Showcase|Rose & Crown Pub",
        "EPCOT|World Showcase|UK Beer Cart",
        "EPCOT|World Showcase|Yorkshire County Fish Shop",
        "EPCOT|World Showcase|Le Cellier Steakhouse",
        "EPCOT|World Showcase|La Poutinerie",
    ]

    func testAllFortyOneEpcotMapDiningPinsAreListed() {
        XCTAssertEqual(epcotDiningStableIDs.count, 41)
        XCTAssertEqual(Set(epcotDiningStableIDs).count, 41, "duplicate stableID in the fixture list")
    }

    func testEveryEpcotMapDiningPinIsRateable() {
        for stableID in epcotDiningStableIDs {
            XCTAssertTrue(
                DiningVenueKeys.isRateable(stableID: stableID),
                "\(stableID) resolved from a map pin but has no venueKey — tapping it would open a rating UI with nothing to submit against"
            )
            XCTAssertNotNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testEveryEpcotMapDiningPinResolvesToAnEpVenueKey() {
        for stableID in epcotDiningStableIDs {
            guard let key = DiningVenueKeys.venueKey(forStableID: stableID) else {
                XCTFail("\(stableID) has no venueKey")
                continue
            }
            XCTAssertTrue(key.hasPrefix("ep-"), "\(stableID) mapped to non-EPCOT venueKey '\(key)'")
        }
    }

    /// The one dining venue in this land that is deliberately map-ineligible —
    /// guarding against someone "fixing" the gap by inventing a fake pin.
    func testSpace220LoungeHasNoMapPinDespiteHavingAVenueKey() {
        let diningPins = ParkMapPinData.embeddedPins["epcot"]?.filter {
            $0.internalRideId.hasPrefix("ep|dining|")
        } ?? []
        XCTAssertFalse(
            diningPins.contains { $0.displayName == "Space 220 Lounge" },
            "Space 220 Lounge shares its coordinate with Space 220 Restaurant and must not get its own pin"
        )
        XCTAssertNotNil(DiningVenueKeys.venueKey(forStableID: "EPCOT|World Discovery|Space 220 Lounge"))
    }
}

// MapModeAvailabilityTests.swift — which parks get the Explore/Live toggle.

import XCTest
@testable import Parkio

final class MapModeAvailabilityTests: XCTestCase {

    func testMagicKingdomHasAnExploreMap() {
        XCTAssertTrue(MapModeAvailability.isExploreMapAvailable(forParkId: "magic-kingdom"))
    }

    func testEpcotHasAnExploreMap() {
        XCTAssertTrue(MapModeAvailability.isExploreMapAvailable(forParkId: "epcot"))
    }

    func testParksWithoutCalibratedArtworkStayLiveMapOnly() {
        for parkId in ["hollywood-studios", "animal-kingdom", "disneyland", "california-adventure"] {
            XCTAssertFalse(
                MapModeAvailability.isExploreMapAvailable(forParkId: parkId),
                "\(parkId) has no calibrated Explore Map yet and must not offer the toggle"
            )
        }
    }

    func testUnknownParkIdDoesNotAccidentallyGetTheToggle() {
        XCTAssertFalse(MapModeAvailability.isExploreMapAvailable(forParkId: "not-a-real-park"))
    }
}

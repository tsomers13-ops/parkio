// MapRoutingDecisionTests.swift — the live-routing decision that keeps Magic
// Kingdom on the custom image canvas while every other park stays on the live
// MapKit experience.

import XCTest

final class MapRoutingDecisionTests: XCTestCase {

    func testMagicKingdomUsesTheCustomCanvas() {
        XCTAssertEqual(MapRoutingDecision.renderMode(forParkId: "magic-kingdom"), .customCanvas)
    }

    func testEveryOtherParkUsesTheLiveMap() {
        for parkId in ["epcot", "hollywood-studios", "animal-kingdom", "disneyland", "california-adventure"] {
            XCTAssertEqual(
                MapRoutingDecision.renderMode(forParkId: parkId), .liveMap,
                "\(parkId) must keep the live MapKit experience"
            )
        }
    }

    func testUnknownParkIdDoesNotAccidentallyGetTheCanvas() {
        XCTAssertEqual(MapRoutingDecision.renderMode(forParkId: "not-a-real-park"), .liveMap)
    }
}

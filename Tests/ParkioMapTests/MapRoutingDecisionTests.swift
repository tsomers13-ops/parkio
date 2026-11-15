// MapRoutingDecisionTests.swift — Magic Kingdom and EPCOT use the custom
// canvas. Every other park stays on the live MapKit experience.

import XCTest

@testable import Parkio

final class MapRoutingDecisionTests: XCTestCase {

    func testMagicKingdomUsesTheCustomCanvas() {
        XCTAssertEqual(MapRoutingDecision.renderMode(forParkId: "magic-kingdom"), .customCanvas)
    }

    func testEpcotUsesTheCustomCanvas() {
        XCTAssertEqual(MapRoutingDecision.renderMode(forParkId: "epcot"), .customCanvas)
    }

    func testEveryOtherParkUsesTheLiveMap() {
        for parkId in ["hollywood-studios", "animal-kingdom", "disneyland", "california-adventure"] {
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

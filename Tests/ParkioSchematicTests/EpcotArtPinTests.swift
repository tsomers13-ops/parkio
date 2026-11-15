// EpcotArtPinTests.swift — Every illustrated EPCOT pin sits on the art
// and resolves to a catalog attraction or dining venue.

import XCTest

@testable import Parkio

final class EpcotArtPinTests: XCTestCase {

    func testEveryEpcotPinLiesInTheCentralArtAndResolves() {
        let catalog = Set(RideMasterData.all.map(\.stableID))
        XCTAssertFalse(ParkMapPinData.epcotPins.isEmpty)
        for pin in ParkMapPinData.epcotPins {
            XCTAssertGreaterThanOrEqual(pin.mapX, 0.05, pin.displayName)
            XCTAssertLessThanOrEqual(pin.mapX, 0.95, pin.displayName)
            XCTAssertGreaterThanOrEqual(pin.mapY, 0.05, pin.displayName)
            XCTAssertLessThanOrEqual(pin.mapY, 0.95, pin.displayName)
            let stableID = pin.stableID
            XCTAssertNotNil(stableID, pin.displayName)
            if let stableID {
                XCTAssertTrue(catalog.contains(stableID), stableID)
                XCTAssertTrue(
                    stableID.hasPrefix("EPCOT|"),
                    "\(pin.displayName) resolved to \(stableID)"
                )
                let match = RideMasterData.all.first { $0.stableID == stableID }
                let nameMatches = match?.name == pin.displayName
                    || match?.aliases.contains(pin.displayName) == true
                XCTAssertTrue(
                    nameMatches,
                    "\(pin.displayName) resolved to \(stableID)"
                )
            }
        }
    }

    func testAddedDiningVenuesArePinnedOnTheArt() {
        let names = Set(ParkMapPinData.epcotPins.map(\.displayName))
        for name in [
            "Sunshine Seasons",
            "Katsura Grill",
            "La Cantina de San Angel",
            "Les Halles Boulangerie-Patisserie",
            "L'Artisan des Glaces",
        ] {
            XCTAssertTrue(names.contains(name), name)
        }
    }
}

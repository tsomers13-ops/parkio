// ParkMapPinDataTests.swift — coverage and shape checks for the embedded pin
// data behind the Magic Kingdom custom map canvas.

import XCTest

final class ParkMapPinDataTests: XCTestCase {

    private var magicKingdomPins: [ParkMapPin] {
        ParkMapPinData.embeddedPins["magic-kingdom"] ?? []
    }

    private var diningPins: [ParkMapPin] {
        magicKingdomPins.filter { $0.internalRideId.hasPrefix("mk|dining|") }
    }

    // MARK: - Exact 31 dining-pin coverage

    func testExactlyThirtyOneDiningPins() {
        XCTAssertEqual(diningPins.count, 31)
    }

    func testDiningPinsAreUniquelyIdentified() {
        let ids = diningPins.map(\.internalRideId)
        XCTAssertEqual(Set(ids).count, ids.count, "two dining pins share an internalRideId")
    }

    func testDiningPinsAreAllScopedToMagicKingdom() {
        for pin in diningPins {
            XCTAssertEqual(pin.parkId, "magic-kingdom")
        }
    }

    func testNonDiningPinsAreExactlyTheRemainingTwenty() {
        XCTAssertEqual(magicKingdomPins.count - diningPins.count, 20)
    }

    // MARK: - No fake coordinates

    func testNoMagicKingdomPinIsOutOfTheNormalizedMapBounds() {
        for pin in magicKingdomPins {
            XCTAssertFalse(
                pin.isOutOfBounds,
                "\(pin.displayName) has mapX/mapY outside 0...1 — not a valid normalized map position"
            )
        }
    }

    // MARK: - Every embedded park has pins

    func testEveryEmbeddedParkHasAtLeastOnePin() {
        for (parkId, pins) in ParkMapPinData.embeddedPins {
            XCTAssertFalse(pins.isEmpty, "\(parkId) has no pins")
        }
    }

    func testPinIdentityMatchesItsOwnPark() {
        for (parkId, pins) in ParkMapPinData.embeddedPins {
            for pin in pins {
                XCTAssertEqual(pin.parkId, parkId, "\(pin.internalRideId) is filed under the wrong park key")
            }
        }
    }
}

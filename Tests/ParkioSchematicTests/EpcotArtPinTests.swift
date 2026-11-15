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

    func testUnpinnedVenuesAreAbsentAndNotPlacedAtCenter() {
        let names = [
            "Disney Character Spot",
            "Space 220 Lounge",
        ]
        let pins = ParkMapPinData.epcotPins
        let annotations = MapCoordinateService.shared.annotations(for: "epcot")
        for name in names {
            XCTAssertNil(pins.first { $0.displayName == name }, name)
            let attraction = RideMasterData.all.first { $0.name == name }
            XCTAssertNotNil(attraction, name)
            XCTAssertNotNil(attraction?.stableID, name)
            guard let annotation = annotations.first(where: { $0.rideName == name }) else {
                continue
            }
            let point = MapSchematicProjection.normalize(
                latitude: annotation.latitude,
                longitude: annotation.longitude,
                bounds: MapSchematicProjection.epcotBounds,
                orientation: .northDown
            )
            if let point {
                XCTAssertFalse(
                    abs(point.x - 0.5) < 0.001 && abs(point.y - 0.5) < 0.001,
                    "\(name) projected to the canvas center"
                )
            }
        }
        XCTAssertFalse(
            pins.contains { abs($0.mapX - 0.5) < 0.001 && abs($0.mapY - 0.5) < 0.001 },
            "an EPCOT pin sits at the canvas center"
        )
    }

    func testPlacedServicePinsProjectInsideTheCentralArt() {
        let annotations = MapCoordinateService.shared.annotations(for: "epcot")
        for pin in ParkMapPinData.epcotServicePins {
            XCTAssertGreaterThanOrEqual(pin.mapX, 0.05, pin.displayName)
            XCTAssertLessThanOrEqual(pin.mapX, 0.95, pin.displayName)
            XCTAssertGreaterThanOrEqual(pin.mapY, 0.05, pin.displayName)
            XCTAssertLessThanOrEqual(pin.mapY, 0.95, pin.displayName)
            let source = annotations.first { $0.rideName == pin.displayName }
            XCTAssertNotNil(source, pin.displayName)
            let point = source.flatMap {
                MapSchematicProjection.normalize(
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    bounds: MapSchematicProjection.epcotBounds,
                    orientation: .northDown
                )
            }
            XCTAssertNotNil(point, pin.displayName)
        }
    }

    func testEpcotCoordinatesWithoutAnArtPinAreExactlyTheExpectedSet() {
        let pinned = Set(ParkMapPinData.epcotPins.map(\.displayName))
            .union(ParkMapPinData.epcotServicePins.map(\.displayName))
        let annotations = MapCoordinateService.shared.annotations(for: "epcot")
        let missing = Set(annotations.compactMap { annotation -> String? in
            let suffix = annotation.id.split(separator: "|").last.map(String.init) ?? ""
            let placed = pinned.contains(annotation.rideName) || pinned.contains(suffix)
            return placed ? nil : annotation.rideName
        })
        XCTAssertEqual(missing, [])
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

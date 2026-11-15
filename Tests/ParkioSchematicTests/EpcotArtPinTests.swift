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

    func testServicePinsDoNotOverlapEachOtherOrDiningPins() {
        let composition = EPCOTComposition.make()
        let viewport = composition.defaultViewport
        // iPhone 17 point size, the device the map screenshots are taken on.
        // Width is the tighter fit axis for the 1170×1152 canvas.
        // Dining pins inside one pavilion are allowed to stack; this only
        // checks service pins against each other and against dining pins.
        let zoom = min(
            402 / (composition.contentSize.width * viewport.width),
            874 / (composition.contentSize.height * viewport.height)
        )
        let diningNames = Set(RideMasterData.all.filter(\.type.isDining).map(\.name))
        let diningPins = ParkMapPinData.epcotPins.filter { diningNames.contains($0.displayName) }
        func center(_ pin: ParkMapPin) -> CGPoint {
            CGPoint(
                x: pin.mapX * composition.contentSize.width,
                y: pin.mapY * composition.contentSize.height
            )
        }
        func radius(_ pin: ParkMapPin) -> CGFloat {
            if pin.serviceSystemImage != nil {
                return ParkMapPin.serviceMarkerDiameter / 2 / zoom
            }
            // Priority 3 dining draws MinimalPinView's 15pt white circle in
            // canvas space. Higher priorities draw the 18pt dot plus its 3pt ring.
            return pin.priority >= 3 ? 7.5 : 10.5
        }
        func assertNoOverlap(_ a: ParkMapPin, _ b: ParkMapPin) {
            let gap = hypot(center(a).x - center(b).x, center(a).y - center(b).y)
            XCTAssertGreaterThanOrEqual(
                gap,
                radius(a) + radius(b) - 0.5,
                "\(a.displayName) overlaps \(b.displayName)"
            )
        }
        let services = ParkMapPinData.epcotServicePins
        for i in services.indices {
            for j in services.indices where j > i {
                assertNoOverlap(services[i], services[j])
            }
            for dining in diningPins {
                assertNoOverlap(services[i], dining)
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

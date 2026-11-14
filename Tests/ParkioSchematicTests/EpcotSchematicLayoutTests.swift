// EpcotSchematicLayoutTests.swift — GPS already stored in MapCoordinates.json
// projects onto the EPCOT canvas without invented coordinates.
//
// The latitudes and longitudes below are copied from that file. The bounds
// are the EPCOT validation window written in the same file's header.

import CoreGraphics
import XCTest

@testable import Parkio

final class EpcotSchematicLayoutTests: XCTestCase {

    // MapCoordinates.json — EPCOT entries.
    private let spaceshipEarth = EpcotAttractionSample(
        id: "EPCOT|World Celebration|Spaceship Earth",
        name: "Spaceship Earth",
        land: "World Celebration",
        latitude: 28.3752928,
        longitude: -81.5493965,
        priority: 1
    )
    private let figment = EpcotAttractionSample(
        id: "EPCOT|World Celebration|Journey Into Imagination With Figment",
        name: "Journey Into Imagination With Figment",
        land: "World Celebration",
        latitude: 28.3699000,
        longitude: -81.5531000,
        priority: 2
    )
    private let guardians = EpcotAttractionSample(
        id: "EPCOT|World Discovery|Guardians of the Galaxy: Cosmic Rewind",
        name: "Guardians of the Galaxy: Cosmic Rewind",
        land: "World Discovery",
        latitude: 28.3755204,
        longitude: -81.5469465,
        priority: 1
    )
    private let frozen = EpcotAttractionSample(
        id: "EPCOT|World Showcase|Frozen Ever After",
        name: "Frozen Ever After",
        land: "World Showcase",
        latitude: 28.3708027,
        longitude: -81.5462347,
        priority: 1
    )
    private let remy = EpcotAttractionSample(
        id: "EPCOT|World Showcase|Remy's Ratatouille Adventure",
        name: "Remy's Ratatouille Adventure",
        land: "World Showcase",
        latitude: 28.3679240,
        longitude: -81.5528604,
        priority: 1
    )
    private let granFiesta = EpcotAttractionSample(
        id: "EPCOT|World Showcase|Gran Fiesta Tour",
        name: "Gran Fiesta Tour Starring The Three Caballeros",
        land: "World Showcase",
        latitude: 28.3719200,
        longitude: -81.5468700,
        priority: 2
    )

    private var layout: EpcotSchematicLayout {
        EpcotSchematicLayout.make(from: [
            spaceshipEarth, figment, guardians, frozen, remy, granFiesta,
            // MapCoordinates.json — other World Celebration entries, so the
            // land has enough points for the outlier check to see Figment.
            EpcotAttractionSample(id: "EPCOT|World Celebration|Connections Eatery", name: "Connections Eatery", land: "World Celebration", latitude: 28.3743400792775, longitude: -81.5484700507225, priority: 2),
            EpcotAttractionSample(id: "EPCOT|World Celebration|GEO-82", name: "GEO-82", land: "World Celebration", latitude: 28.37466514737089, longitude: -81.5496073600167, priority: 2),
            EpcotAttractionSample(id: "EPCOT|World Celebration|GRAB-N-GOOF", name: "GRAB-N-GOOF", land: "World Celebration", latitude: 28.3736946934633, longitude: -81.54990394851295, priority: 2),
        ])
    }

    func testProjectedPointsStayInsideTheCanvasMargin() {
        let point = MapSchematicProjection.normalize(
            latitude: spaceshipEarth.latitude,
            longitude: spaceshipEarth.longitude,
            bounds: MapSchematicProjection.epcotBounds
        )
        XCTAssertGreaterThanOrEqual(point.x, MapSchematicProjection.canvasInset)
        XCTAssertLessThanOrEqual(point.x, 1 - MapSchematicProjection.canvasInset)
        XCTAssertGreaterThanOrEqual(point.y, MapSchematicProjection.canvasInset)
        XCTAssertLessThanOrEqual(point.y, 1 - MapSchematicProjection.canvasInset)
    }

    func testSpaceshipEarthIsNorthOfTheShowcaseRing() {
        let built = layout
        let earth = pin(spaceshipEarth.name, in: built)
        let norway = pin(frozen.name, in: built)
        let france = pin(remy.name, in: built)
        XCTAssertLessThan(earth.y, norway.y)
        XCTAssertLessThan(earth.y, france.y)
    }

    func testShowcasePinsSitOnOppositeSidesOfTheLagoon() {
        let built = layout
        let norway = pin(frozen.name, in: built)
        let france = pin(remy.name, in: built)
        let mexico = pin(granFiesta.name, in: built)
        guard let lagoon = built.lagoon else {
            return XCTFail("World Showcase coordinates did not produce a lagoon")
        }
        let centerX = lagoon.x + lagoon.width / 2
        XCTAssertGreaterThan(norway.x, centerX)
        XCTAssertLessThan(france.x, centerX)
        XCTAssertGreaterThan(mexico.x, centerX)
        XCTAssertLessThan(distance(norway, to: lagoon), 0.45)
        XCTAssertGreaterThan(distance(norway, to: lagoon), lagoon.width / 2)
    }

    func testGuardiansLandBlockIsEastOfSpaceshipEarthAndInsideTheCanvas() {
        let built = layout
        let discovery = built.landBlocks.first { $0.label == "World Discovery" }
        let earth = built.spaceshipEarth
        XCTAssertNotNil(discovery)
        XCTAssertEqual(earth?.label, "Spaceship Earth")
        if let discovery, let earth {
            XCTAssertGreaterThan(discovery.x, earth.x)
            XCTAssertGreaterThanOrEqual(discovery.x, 0.02)
            XCTAssertLessThanOrEqual(discovery.x + discovery.width, 0.98)
        }
    }

    func testFigmentKeepsItsCoordinateButDoesNotStretchWorldCelebration() {
        let built = layout
        let figmentPin = pin(figment.name, in: built)
        let celebration = built.landBlocks.first { $0.label == "World Celebration" }
        XCTAssertGreaterThan(figmentPin.y, 0.55)
        XCTAssertNotNil(celebration)
        if let celebration {
            XCTAssertLessThan(celebration.y + celebration.height, figmentPin.y)
        }
    }

    func testDefaultViewportContainsEveryEpcotBlock() {
        let composition = EPCOTComposition.make(layout: layout)
        XCTAssertEqual(composition.defaultViewport, CGRect(x: 0, y: 0, width: 1, height: 1))
        let viewport = composition.defaultViewport
        for shape in composition.shapes {
            let frame = frame(of: shape.geometry)
            XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 0.001, shape.id)
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY - 0.001, shape.id)
            XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 0.001, shape.id)
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY + 0.001, shape.id)
        }
    }

    func testSpaceshipEarthShapeCarriesALabel() {
        let composition = EPCOTComposition.make(layout: layout)
        let landmark = composition.shapes.first { $0.id == "ep-spaceship-earth" }
        XCTAssertEqual(landmark?.label, "Spaceship Earth")
        XCTAssertEqual(landmark?.type, .landmark)
    }

    private func pin(_ name: String, in layout: EpcotSchematicLayout) -> EpcotSchematicLayout.Pin {
        guard let pin = layout.pins.first(where: { $0.name == name }) else {
            XCTFail("Missing pin \(name)")
            return EpcotSchematicLayout.Pin(id: "", name: name, x: 0, y: 0, priority: 0)
        }
        return pin
    }

    private func distance(
        _ pin: EpcotSchematicLayout.Pin,
        to block: EpcotSchematicLayout.Block
    ) -> Double {
        let cx = block.x + block.width / 2
        let cy = block.y + block.height / 2
        return hypot(pin.x - cx, pin.y - cy)
    }

    private func frame(of geometry: ShapeGeometry) -> CGRect {
        switch geometry {
        case .rect(let rect), .roundedRect(let rect, _), .ellipse(let rect):
            return rect
        case .polygon(let points):
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            return CGRect(
                x: xs.min() ?? 0,
                y: ys.min() ?? 0,
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
        }
    }
}

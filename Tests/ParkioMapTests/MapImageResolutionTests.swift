// MapImageResolutionTests.swift — production map art must never be silently
// swapped for placeholder art, in DEBUG or in release.

import XCTest

final class MapImageResolutionTests: XCTestCase {

    func testProductionArtWinsInDebugEvenWhenMockAlsoExists() {
        let name = MapImageResolution.imageName(forParkId: "magic-kingdom", isDebugBuild: true) { asset in
            asset == "magic_kingdom_map" || asset == "magic_kingdom_map_mock"
        }
        XCTAssertEqual(name, "magic_kingdom_map")
    }

    func testProductionArtWinsInReleaseEvenWhenMockAlsoExists() {
        let name = MapImageResolution.imageName(forParkId: "magic-kingdom", isDebugBuild: false) { asset in
            asset == "magic_kingdom_map" || asset == "magic_kingdom_map_mock"
        }
        XCTAssertEqual(name, "magic_kingdom_map")
    }

    func testMagicKingdomResolvesToItsProductionAssetOnly() {
        // Mirrors the real asset catalog: only the production asset exists.
        let name = MapImageResolution.imageName(forParkId: "magic-kingdom", isDebugBuild: true) { asset in
            asset == "magic_kingdom_map"
        }
        XCTAssertEqual(name, "magic_kingdom_map")
    }

    func testDebugFallsBackToMockWhenProductionArtIsMissing() {
        let name = MapImageResolution.imageName(forParkId: "disneyland", isDebugBuild: true) { asset in
            asset == "disneyland_map_mock"
        }
        XCTAssertEqual(name, "disneyland_map_mock")
    }

    func testReleaseNeverSubstitutesMockEvenWhenProductionArtIsMissing() {
        let name = MapImageResolution.imageName(forParkId: "disneyland", isDebugBuild: false) { asset in
            asset == "disneyland_map_mock"
        }
        XCTAssertEqual(name, "disneyland_map", "release must never fall back to placeholder art")
    }

    func testHyphenatedParkIdsAreUnderscored() {
        let name = MapImageResolution.imageName(forParkId: "hollywood-studios", isDebugBuild: false) { _ in false }
        XCTAssertEqual(name, "hollywood_studios_map")
    }
}

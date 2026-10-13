// EpcotExploreMapUITests.swift — the regression unit tests cannot see: does
// the Explore/Live toggle actually switch map surfaces, and do EPCOT's new
// attraction and dining pins open the right screen when tapped, on the real
// ParkMapCanvasView wiring.
//
// Mirrors MagicKingdomMapDiningNavigationUITests's pattern (launch args,
// element(_:) helper, expectation-based waits where timing matters).

import XCTest

final class EpcotExploreMapUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Deterministic entry: Map tab, EPCOT selected.
        app.launchArguments += ["-parkio-uitests", "-parkio-open-epcot-map"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Attraction pins carry live wait-time state in their accessibility label
    /// once WaitTimeViewModel's fetch completes — matching on the prefix keeps
    /// this test independent of whether that fetch has resolved yet.
    private func buttonNamed(startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    // MARK: - Explore / Live toggle

    /// EPCOT defaults to the Explore Map (MapModeAvailability.isExploreMapAvailable
    /// is true for EPCOT) — the Zoom In / Zoom Out controls are Explore-Map-only
    /// (MapZoomControls, the accessible alternative to pinch-to-zoom), so their
    /// presence is a reliable signal of which surface is actually on screen.
    func testExploreLiveToggleSwitchesTheMapSurface() {
        let exploreButton = app.buttons["Explore Map"]
        let liveButton = app.buttons["Live Map"]
        XCTAssertTrue(exploreButton.waitForExistence(timeout: timeout), "Explore/Live toggle never appeared")
        XCTAssertTrue(liveButton.exists)

        XCTAssertTrue(
            app.buttons["Zoom In"].waitForExistence(timeout: timeout),
            "EPCOT should default to the Explore Map, which has accessible zoom controls"
        )

        liveButton.tap()
        XCTAssertFalse(
            app.buttons["Zoom In"].waitForExistence(timeout: 5),
            "Zoom In is Explore-Map-only and must disappear once Live Map is selected"
        )

        exploreButton.tap()
        XCTAssertTrue(
            app.buttons["Zoom In"].waitForExistence(timeout: timeout),
            "switching back to Explore Map should bring the zoom controls back"
        )
    }

    // MARK: - Pin navigation (Explore Map)

    /// Soarin' — a World Nature attraction pin, calibrated priority 1 (always
    /// visible, no stagger-in wait needed beyond the initial pin animation).
    /// The pin's displayName is the shortened "Soarin'" (MapPinIdentityResolver
    /// resolves it to the canonical "Soarin' Around the World" via its
    /// normalized-substring tier, the same shortened-label convention Magic
    /// Kingdom's pins already use) — the bottom sheet shows the canonical name.
    func testTappingAnEpcotAttractionPinOpensTheRideBottomSheetNotDiningDetail() {
        let pin = buttonNamed(startingWith: "Soarin")
        XCTAssertTrue(pin.waitForExistence(timeout: timeout), "EPCOT attraction pin never appeared on the Explore Map")

        pin.tap()

        XCTAssertTrue(
            app.staticTexts["Soarin' Around the World"].waitForExistence(timeout: timeout),
            "ride bottom sheet did not open for the tapped attraction pin"
        )
        XCTAssertFalse(
            element("parkio.dining.detail").exists,
            "an attraction pin opened the dining detail sheet instead of the ride bottom sheet"
        )
    }

    /// Sunshine Seasons — a World Nature dining pin, calibrated priority 1.
    /// Does NOT assert on the Community rating CTA — same backend-rollout-timing
    /// caveat as MagicKingdomMapDiningNavigationUITests; the venueKey mapping
    /// itself is locked in by EpcotMapDiningRatingEligibilityTests.
    func testTappingAnEpcotDiningPinOpensThatVenuesDiningDetail() {
        let pin = app.buttons["Sunshine Seasons"]
        XCTAssertTrue(pin.waitForExistence(timeout: timeout), "EPCOT dining pin never appeared on the Explore Map")

        pin.tap()

        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "dining detail did not open for the tapped pin")
        XCTAssertTrue(
            app.staticTexts["Sunshine Seasons"].waitForExistence(timeout: timeout),
            "dining detail opened but is not showing the tapped venue"
        )
    }

    // MARK: - Filter bar (shared MapOverlayFilterBar)

    /// Smoke test: the same filter bar RealMapScreen uses is present on the
    /// Explore Map and survives a tap without dismissing the map or crashing.
    /// Actual filtering behavior (MapViewModel.passes(marker:)) is identical
    /// code on both surfaces by construction — see ParkMapCanvasView.sortedPins.
    func testFilterBarIsPresentAndTappableOnTheExploreMap() {
        let chip = app.buttons["Hide Closed"]
        XCTAssertTrue(chip.waitForExistence(timeout: timeout), "shared filter bar did not appear on the Explore Map")

        chip.tap()

        XCTAssertTrue(app.buttons["Hide Closed"].exists, "toggling a filter chip should not dismiss the map")
    }
}

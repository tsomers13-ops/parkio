// MagicKingdomMapDiningNavigationUITests.swift — the regression unit tests
// cannot see: does tapping a Magic Kingdom dining pin on the LIVE custom map
// canvas actually open that exact venue's dining detail?
//
// Unit tests (ParkioMapTests) cover the pure stableID-resolution algorithm and
// pin data coverage in isolation. They cannot observe whether the real
// ParkMapCanvasView wiring — SwiftData Ride lookup, sheet presentation,
// dismissing any active ride selection first — actually produces the right
// screen when a guest taps a pin. This exercises that live path.

import XCTest

final class MagicKingdomMapDiningNavigationUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Deterministic entry: Map tab, Magic Kingdom selected.
        app.launchArguments += ["-parkio-uitests", "-parkio-open-mk-map"]
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
    /// (e.g. "Space Mountain, 45 min wait") once WaitTimeViewModel's fetch
    /// completes — unlike dining pins, which never gain that suffix. Matching
    /// on the prefix keeps this test independent of whether that fetch has
    /// resolved yet.
    private func buttonNamed(startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Be Our Guest Restaurant — a Fantasyland dining pin near the top of the
    /// default Magic Kingdom viewport, calibrated priority 1 (always visible,
    /// no stagger-in wait needed beyond the initial pin animation).
    ///
    /// Does NOT assert on `parkio.community.rateCTA`: the live ratings backend
    /// (parkio.info) has not yet been deployed with the Magic Kingdom venueKeys
    /// this task minted locally — GET /api/dining/mk-*/ratings/ currently 404s
    /// ("Unknown dining venue"), same as any brand-new venueKey before its first
    /// backend deploy. CommunityRatingSection fails soft on that (renders
    /// EmptyView, see its `.unavailable` case) rather than showing an error, so
    /// asserting the CTA here would make this test depend on backend rollout
    /// timing instead of this app's own wiring. The venueKey mapping itself —
    /// the part actually owned by this app — is locked in by
    /// MagicKingdomMapDiningRatingEligibilityTests (ParkioRatingsTests).
    func testTappingAMagicKingdomDiningPinOpensThatVenuesDiningDetail() {
        let pin = app.buttons["Be Our Guest Restaurant"]
        XCTAssertTrue(pin.waitForExistence(timeout: timeout), "Magic Kingdom dining pin never appeared on the map")

        pin.tap()

        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "dining detail did not open for the tapped pin")

        XCTAssertTrue(
            app.staticTexts["Be Our Guest Restaurant"].waitForExistence(timeout: timeout),
            "dining detail opened but is not showing the tapped venue"
        )
    }

    /// The other branch of the same tap-routing logic: an attraction pin must
    /// keep using the existing ride bottom sheet (peek detent, wait time, Log
    /// Ride), not the dining detail sheet — proving handlePinTap's dining-vs-ride
    /// split resolves both kinds of pin correctly, not just dining ones.
    func testTappingAMagicKingdomAttractionPinOpensTheRideBottomSheetNotDiningDetail() {
        let pin = buttonNamed(startingWith: "Space Mountain")
        XCTAssertTrue(pin.waitForExistence(timeout: timeout), "Magic Kingdom attraction pin never appeared on the map")

        pin.tap()

        XCTAssertTrue(
            app.staticTexts["Space Mountain"].waitForExistence(timeout: timeout),
            "ride bottom sheet did not open for the tapped attraction pin"
        )
        XCTAssertFalse(
            element("parkio.dining.detail").exists,
            "an attraction pin opened the dining detail sheet instead of the ride bottom sheet"
        )
    }
}

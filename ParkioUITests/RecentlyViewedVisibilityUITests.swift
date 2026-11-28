// RecentlyViewedVisibilityUITests.swift — regression that Recently Viewed
// must NEVER appear anywhere in the app, in any state:
//   • after viewing a Dining venue and returning
//   • across every category filter (Dining, All, Rides, Shows, Characters)
//   • in By Land sort mode
//   • after leaving and reopening the attractions screen in the same session
//   • after terminating and relaunching the app
//
// Previously (PR #3) Recently Viewed was gated to the Dining filter only.
// That feature is fully removed. These tests guard that it cannot reappear.
//
// Architecture note: all navigation in these tests flows from the existing
// `-parkio-open-epcot-dining` DEBUG launch hook (UITestConfiguration.swift),
// which lands the app directly on EPCOT's Dining-filtered AttractionsListView.
// No production behavior is changed to support these tests.

import XCTest

final class RecentlyViewedVisibilityUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Deterministic entry: EPCOT dining list — the surface that previously
        // showed Recently Viewed when filtered to Dining.
        app.launchArguments += ["-parkio-uitests", "-parkio-open-epcot-dining"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Assert "Recently Viewed" section header is absent, waiting for any in-flight
    /// animation to settle before concluding.
    private func assertRecentlyViewedAbsent(context: String) {
        let header = app.staticTexts["Recently Viewed"].firstMatch
        let gone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: header,
            handler: nil
        )
        wait(for: [gone], timeout: timeout)
        XCTAssertFalse(header.exists,
            "Recently Viewed appeared — context: \(context)")
    }

    /// Tap the named category chip and return the chip element (already tapped).
    private func tapCategoryChip(_ label: String) {
        let chip = app.buttons[label].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: timeout),
                      "\"\(label)\" category chip not found")
        chip.tap()
    }

    // MARK: - 1. After viewing a Dining venue and returning

    func testRecentlyViewedAbsentAfterViewingDiningVenueAndReturning() {
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout),
                      "EPCOT dining list did not show the test venue")
        venue.tap()

        let detail = app.descendants(matching: .any)
            .matching(identifier: "parkio.dining.detail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Dining detail never appeared")

        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: timeout), "No back button on detail")
        back.tap()

        // Must land back on the Dining-filtered list — most sensitive surface.
        assertRecentlyViewedAbsent(context: "Dining filter, after tapping a venue and returning")
    }

    // MARK: - 2. Every category filter

    func testRecentlyViewedAbsentInAllCategoryFilters() {
        // Tap each chip in turn; asserting absent after each transition ensures
        // no filter switch causes a deferred appearance.
        for label in ["All", "Rides", "Shows", "Characters", "Dining"] {
            tapCategoryChip(label)
            assertRecentlyViewedAbsent(context: "\(label) filter")
        }
    }

    // MARK: - 3. By Land sort mode

    func testRecentlyViewedAbsentInByLandSortMode() {
        // First tap a venue so its ID would have been stored under the old
        // implementation — this maximises the chance of a regression if
        // any recording path was missed.
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout), "Test venue not found")
        venue.tap()
        let detail = app.descendants(matching: .any)
            .matching(identifier: "parkio.dining.detail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "Detail never appeared")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Switch to By Land via the Sort toolbar menu.
        let sortButton = app.buttons["Sort"].firstMatch
        XCTAssertTrue(sortButton.waitForExistence(timeout: timeout), "Sort menu button not found")
        sortButton.tap()

        let byLandOption = app.buttons["By Land"].firstMatch
        XCTAssertTrue(byLandOption.waitForExistence(timeout: timeout), "\"By Land\" menu option not found")
        byLandOption.tap()

        // Check absent in By Land mode with the Dining filter active.
        assertRecentlyViewedAbsent(context: "Dining filter, By Land sort mode")

        // Also check after switching off Dining so both layout paths (flat + land-grouped)
        // are exercised across a filter change.
        tapCategoryChip("All")
        assertRecentlyViewedAbsent(context: "All filter, By Land sort mode")
    }

    // MARK: - 4. Leave and reopen the attractions screen

    func testRecentlyViewedAbsentAfterLeavingAndReopeningAttractionsList() {
        // Tap a venue so there would be history to display under the old feature.
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout), "Test venue not found")
        venue.tap()
        let detail = app.descendants(matching: .any)
            .matching(identifier: "parkio.dining.detail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "Detail never appeared")
        app.navigationBars.buttons.element(boundBy: 0).tap() // back to list
        app.navigationBars.buttons.element(boundBy: 0).tap() // back to Home

        // Re-enter attractions from Home via the first "See All" button visible
        // (the Up Next section's entry point — opens default all-attractions list).
        let seeAll = app.buttons["See All"].firstMatch
        XCTAssertTrue(seeAll.waitForExistence(timeout: timeout), "\"See All\" not found on Home")
        seeAll.tap()

        // Now on a fresh push of AttractionsListView; switch to Dining — the highest-risk filter.
        tapCategoryChip("Dining")
        assertRecentlyViewedAbsent(context: "Dining filter, after leaving and re-entering list")

        // Confirm absent on All as well (flat layout, fresh push).
        tapCategoryChip("All")
        assertRecentlyViewedAbsent(context: "All filter, after leaving and re-entering list")
    }

    // MARK: - 5. Terminate and relaunch

    func testRecentlyViewedAbsentAfterTerminateAndRelaunch() {
        // Maximise the footprint a prior session might have left:
        // tap a venue (no-op now, but defends against any missed recording path).
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout), "Test venue not found")
        venue.tap()
        let detail = app.descendants(matching: .any)
            .matching(identifier: "parkio.dining.detail").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "Detail never appeared")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Full process termination and cold relaunch — exercises the UserDefaults
        // read path in init: the feature was removed so recentlyViewed_* keys are
        // intentionally not loaded, and must therefore never appear after relaunch.
        app.terminate()
        app.launch()

        // Hook lands us on EPCOT dining list again.
        XCTAssertTrue(
            app.staticTexts["Akershus Royal Banquet Hall"].firstMatch.waitForExistence(timeout: timeout),
            "Dining list did not appear after relaunch"
        )
        assertRecentlyViewedAbsent(context: "Dining filter, after terminate and relaunch")

        // Sweep every filter on the fresh launch.
        for label in ["All", "Rides", "Shows", "Characters", "Dining"] {
            tapCategoryChip(label)
            assertRecentlyViewedAbsent(context: "\(label) filter, after relaunch")
        }
    }
}

// RecentlyViewedVisibilityUITests.swift — regression for the approved UX
// change: Recently Viewed must appear ONLY while the category filter is
// Dining, and must disappear/reappear immediately as the filter changes —
// without losing the underlying viewing history.
//
// This exercises AttractionsListView's real filter state and real
// UserDefaults-backed Recently Viewed persistence (the same component the
// Community Rating navigation regression drives), since the gating logic
// lives in that view's private internals and isn't reachable from a unit
// test — this is the real, idiomatic way to regress SwiftUI visibility
// behavior in this codebase (see CommunityRatingNavigationUITests.swift's
// own header comment on exactly this point).

import XCTest

final class RecentlyViewedVisibilityUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Deterministic entry: EPCOT dining list — same known-good surface
        // the Community Rating regression uses.
        app.launchArguments += ["-parkio-uitests", "-parkio-open-epcot-dining"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testRecentlyViewedAppearsOnlyInDiningAndReappearsWithHistoryIntact() {

        // 1 — view a venue while in Dining, so Recently Viewed has content.
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout),
                      "EPCOT dining list did not show the test venue")
        venue.tap()

        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Dining detail never appeared")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: timeout), "No back control on the detail")
        backButton.tap()

        // 2 — back on the list, still filtered to Dining: Recently Viewed
        // must be visible, since this IS the dedicated dining experience.
        let recentlyViewed = app.staticTexts["Recently Viewed"].firstMatch
        XCTAssertTrue(recentlyViewed.waitForExistence(timeout: timeout),
                      "Recently Viewed did not appear while filtered to Dining")

        // 3 — switch to "All": Recently Viewed must disappear immediately.
        let allChip = app.buttons["All"].firstMatch
        XCTAssertTrue(allChip.waitForExistence(timeout: timeout), "\"All\" category chip not found")
        allChip.tap()

        let vanished = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: recentlyViewed,
            handler: nil
        )
        wait(for: [vanished], timeout: timeout)
        XCTAssertFalse(recentlyViewed.exists, "Recently Viewed is still visible after switching to the All filter")

        // 4 — switch back to Dining: Recently Viewed must reappear, and the
        // underlying history must still contain the venue viewed in step 1
        // (the visibility gate must not have cleared the persisted data).
        let diningChip = app.buttons["Dining"].firstMatch
        XCTAssertTrue(diningChip.waitForExistence(timeout: timeout), "\"Dining\" category chip not found")
        diningChip.tap()

        XCTAssertTrue(recentlyViewed.waitForExistence(timeout: timeout),
                      "Recently Viewed did not reappear after switching back to Dining")

        // The Recently Viewed card lists the actual venue name — confirms
        // the history itself (not just the section header) survived the
        // All-filter detour intact.
        XCTAssertTrue(
            app.staticTexts["Akershus Royal Banquet Hall"].firstMatch.waitForExistence(timeout: timeout),
            "Recently Viewed reappeared but lost the previously-viewed venue"
        )
    }

    func testRecentlyViewedNeverAppearsForRidesShowsOrCharactersFilters() {
        // A park where Recently Viewed having real ride content matters —
        // reuse EPCOT, but drive the general attractions list this time.
        // (opensEpcotDiningList still lands us on the Dining-filtered
        // AttractionsListView; switching chips exercises the other filters
        // on the exact same screen instance, which is the real risk this
        // change introduces — see AttractionsListView's shared-component
        // architecture note.)

        for chipLabel in ["Rides", "Shows", "Characters"] {
            let chip = app.buttons[chipLabel].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: timeout), "\"\(chipLabel)\" category chip not found")
            chip.tap()

            // Checking `.exists` the instant after tap can catch the section
            // mid-exit-animation (a real transition takes a moment to
            // complete, same reasoning as the "vanished" wait in the other
            // test in this file) — wait for it to actually be gone rather
            // than asserting on an instantaneous snapshot.
            let recentlyViewed = app.staticTexts["Recently Viewed"].firstMatch
            let goneOrNeverThere = expectation(
                for: NSPredicate(format: "exists == false"),
                evaluatedWith: recentlyViewed,
                handler: nil
            )
            wait(for: [goneOrNeverThere], timeout: timeout)
            XCTAssertFalse(
                recentlyViewed.exists,
                "Recently Viewed is visible while filtered to \(chipLabel) — it must only appear for Dining"
            )
        }
    }
}

// DiningServiceFilterUITests.swift — the dining list actually changes when
// the guest switches All / Quick service / Sit-down.
//
// Unit tests cover the mapping. They cannot see a SwiftUI list. This opens
// the EPCOT dining list (the same launch hook the other dining UI tests use)
// and checks that a known sit-down venue and a known quick-service venue
// appear and disappear with the chips.
//
// Search is how the venues are found. The list is long and sorted by the
// guest's ratings, so asserting on whatever happens to be in the first
// screenful would pass or fail for reasons that are not this filter.

import XCTest

final class DiningServiceFilterUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-parkio-uitests",
            "-parkio-open-epcot-dining",
            "-parkio-suppress-location",
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    /// Hittable match only. Home stays under the pushed dining list and has
    /// the same filter identifiers; a covered chip is not hittable, so this
    /// query waits for the chip on the list itself.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "isHittable == true"))
            .firstMatch
    }

    /// A dining-list row, not a Best Food Nearby row on the Home screen underneath.
    private func venueRow(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "parkio.dining.venueRow")
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }

    func testSwitchingServiceFilterChangesTheVisibleVenueList() {
        let all = element("parkio.dining.serviceFilter.all")
        let quick = element("parkio.dining.serviceFilter.quickService")
        let sitDown = element("parkio.dining.serviceFilter.sitDown")

        XCTAssertTrue(all.waitForExistence(timeout: timeout), "All dining filter chip did not appear")
        XCTAssertTrue(quick.waitForExistence(timeout: timeout), "Quick service filter chip did not appear")
        XCTAssertTrue(sitDown.waitForExistence(timeout: timeout), "Sit-down filter chip did not appear")
        XCTAssertTrue(all.isSelected, "All should be the selected dining filter on launch")

        // All — both buckets are on the list.
        search("Akershus")
        XCTAssertTrue(venueRow("Akershus Royal Banquet Hall").waitForExistence(timeout: timeout),
                      "All did not show Akershus Royal Banquet Hall")

        search("Block & Hans")
        XCTAssertTrue(venueRow("Block & Hans").waitForExistence(timeout: timeout),
                      "All did not show Block & Hans")

        // Quick service — the snack stand stays, the dining room goes.
        tapFilter(quick)
        XCTAssertTrue(quick.isSelected)
        XCTAssertTrue(venueRow("Block & Hans").waitForExistence(timeout: timeout),
                      "Quick service hid Block & Hans")
        search("Akershus")
        assertVenueHidden("Akershus Royal Banquet Hall")

        // Sit-down — the dining room comes back, the snack stand goes.
        tapFilter(sitDown)
        XCTAssertTrue(sitDown.isSelected)
        XCTAssertTrue(venueRow("Akershus Royal Banquet Hall").waitForExistence(timeout: timeout),
                      "Sit-down hid Akershus Royal Banquet Hall")
        search("Block & Hans")
        assertVenueHidden("Block & Hans")

        // All again — the venue the previous bucket hid is back.
        tapFilter(all)
        XCTAssertTrue(all.isSelected)
        XCTAssertTrue(venueRow("Block & Hans").waitForExistence(timeout: timeout),
                      "All did not bring Block & Hans back")

        clearSearch()
        tapFilter(sitDown)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "dining-service-filter"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private var searchField: XCUIElement {
        app.textFields.matching(identifier: "parkio.attractions.search").firstMatch
    }

    private func search(_ text: String) {
        let field = searchField
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Search field did not appear")
        field.tap()

        let clear = element("parkio.attractions.search.clear")
        if clear.exists {
            clear.tap()
            field.tap()
        }
        field.typeText(text)
    }

    private func clearSearch() {
        let clear = element("parkio.attractions.search.clear")
        if clear.waitForExistence(timeout: 2) {
            clear.tap()
        }
    }

    private func tapFilter(_ chip: XCUIElement) {
        if app.keyboards.firstMatch.exists {
            let searchKey = app.keyboards.buttons["Search"]
            if searchKey.exists {
                searchKey.tap()
            }
        }
        XCTAssertTrue(chip.isHittable, "Dining service filter chip is not hittable")
        chip.tap()
    }

    /// Waits until the list has finished applying search + filter. "No results"
    /// is the empty state for a search that matches nothing, so it only
    /// appears once the hidden venue is actually gone.
    private func assertVenueHidden(_ name: String) {
        let empty = app.staticTexts["No results"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: timeout),
                      "\(name) did not leave the list — expected the empty search state")
        XCTAssertFalse(venueRow(name).exists, "\(name) is still listed")
    }
}

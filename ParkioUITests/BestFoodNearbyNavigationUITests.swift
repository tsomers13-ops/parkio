// BestFoodNearbyNavigationUITests.swift — UAT defect regression.
//
// Best Food Nearby rendered venue recommendations on Home that looked like
// discovery results but were inert: the row was a bare HStack with no tap
// affordance, so tapping a venue did nothing. Rows now open the canonical
// Dining detail.
//
// The assertion that matters is that the detail which opens is the CANONICAL
// one — identified by `parkio.dining.detail`, the same identifier the Community
// regression uses — and not some Home-specific variant. Tapping "succeeding"
// proves nothing on its own.

import XCTest

final class BestFoodNearbyNavigationUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // EPCOT only — its venues carry Parkio editorial scores, so Best Food
        // Nearby is populated. Recommendation selection and order are untouched.
        app.launchArguments += ["-parkio-uitests", "-parkio-select-epcot"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testTappingABestFoodNearbyRowOpensThatVenuesDiningDetail() {

        // 1 — scroll Home until the card is on screen. Bounded, and it asserts
        // rather than scrolling forever.
        //
        // Queried as a button on purpose: that is what the fix makes the row,
        // and it is the thing the UAT defect was missing. If the row regresses
        // to an inert HStack this query finds nothing and the test fails here.
        let rows = app.buttons.matching(identifier: "parkio.home.bestFood.row")
        var swipes = 0
        while rows.count == 0 && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertGreaterThan(rows.count, 0,
                             "No tappable Best Food Nearby rows on Home — the UAT defect")

        let first = rows.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: timeout))

        // 2 — tap it. Whether it is genuinely interactive is settled by what
        // happens next, not by an isHittable probe on a container.
        first.tap()

        // 3 — the CANONICAL dining detail, not a Home-specific screen.
        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Tapping a recommendation did not open the canonical Dining detail")

        // 4 — and it is a real dining detail: the private journal section is
        // part of the canonical screen, so its presence rules out a stub.
        XCTAssertTrue(app.staticTexts["Your private notes"].waitForExistence(timeout: timeout),
                      "Detail is missing the canonical private journal section")

        // 5 — dismiss returns to Home with the card still there.
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: timeout), "No Done control on the dining detail")
        done.tap()

        XCTAssertTrue(app.staticTexts["Best Food Nearby"].waitForExistence(timeout: timeout),
                      "Dismissing the detail did not return to Home")
        XCTAssertFalse(detail.exists, "Dining detail is still presented after Done")
    }
}

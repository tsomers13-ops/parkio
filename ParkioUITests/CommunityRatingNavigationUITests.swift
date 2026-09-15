// CommunityRatingNavigationUITests.swift — the regression 132 unit tests could not see.
//
// Community Ratings were release-blocking in 1.0.5 (20): the form was a sheet
// presented from the dining detail, which is itself a sheet. SwiftUI tore the
// nested presentation down on arrival and took the dining detail with it, so
// the guest landed back on All Attractions. The whole unit suite stayed green
// throughout, because none of it can observe SwiftUI presentation.
//
// This exercises the real navigation path and asserts the one thing that
// actually distinguishes working from broken: after Back, is the DINING DETAIL
// still on screen, or are we on the list?
//
// Note the detail is identified by `parkio.dining.detail`, not by the venue
// name. The name is visible on the attractions list too, so asserting on it
// would pass in exactly the broken case this test exists to catch.

import XCTest

final class CommunityRatingNavigationUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Generous because a cold launch seeds SwiftData; nothing here waits on the
    /// Community API, which is never required for the view to render its CTA.
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Deterministic entry: EPCOT dining list, not whatever park was last
        // used. See UITestConfiguration — inert outside DEBUG.
        app.launchArguments += ["-parkio-uitests", "-parkio-open-epcot-dining"]
        app.launch()
    }

    /// Identifier lookup that does not assume an element type.
    ///
    /// SwiftUI decides what a `List` or `Form` becomes in the accessibility
    /// tree, and it is not stable across containers — a detail inside a sheet
    /// is not the same element type as one on a navigation stack. Matching on
    /// identifier alone keeps the test about navigation rather than about
    /// XCUIElementType trivia.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testCommunityRatingFormOpensAndBackReturnsToTheSameDiningDetail() {

        // 1 — an eligible venue on the EPCOT dining list.
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout),
                      "EPCOT dining list did not show the test venue")
        venue.tap()

        // 2 — its dining detail.
        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Dining detail never appeared")

        // 3 — the Community CTA. Waiting on it also lets the detail settle,
        // which is what the separate first-tap defect is sensitive to.
        let rateCTA = element("parkio.community.rateCTA")
        XCTAssertTrue(rateCTA.waitForExistence(timeout: timeout),
                      "Community CTA never appeared — venue may not be Community-eligible")
        XCTAssertTrue(rateCTA.isHittable, "Community CTA is not hittable")
        rateCTA.tap()

        // 4 — the form is really there. Identifier AND a real control, so a
        // bare container cannot pass for a usable form.
        let form = element("parkio.community.ratingForm")
        XCTAssertTrue(form.waitForExistence(timeout: timeout),
                      "Community Rating form did not appear")
        XCTAssertTrue(app.staticTexts["Overall"].waitForExistence(timeout: timeout),
                      "Community form is missing the Overall control")

        // A real interactive control, so a bare container cannot pass for a
        // usable form.
        XCTAssertTrue(app.buttons["Submit"].waitForExistence(timeout: timeout),
                      "Community form is missing its Submit control")

        // 5 — and it STAYS there. The old defect dismissed within a frame or two
        // of appearing, so "still here shortly afterwards" is the regression
        // signal. An INVERTED expectation states that directly: fail if the form
        // ever stops existing during the window. This is an assertion with a
        // bound, not a sleep papering over a race — if the form vanishes at any
        // point the expectation fulfils and the test fails immediately.
        let vanished = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: form,
            handler: nil
        )
        vanished.isInverted = true
        wait(for: [vanished], timeout: 3)
        XCTAssertTrue(form.exists, "Community form vanished after appearing")

        // 6 — Back.
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: timeout), "No back control on the form")
        backButton.tap()

        // 7 — THE ASSERTION THAT MATTERS.
        // Broken architecture landed here on All Attractions. The dining detail
        // must still be presented.
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Back did not return to the dining detail — the presentation stack collapsed")
        XCTAssertTrue(rateCTA.waitForExistence(timeout: timeout),
                      "Dining detail returned without its Community section")
        XCTAssertFalse(form.exists, "Community form is still present after Back")
    }
}

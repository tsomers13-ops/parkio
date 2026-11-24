// DiningPriceKeyUITests.swift — the price key is findable, complete, and dismissible.
//
// The dining list opens the key as a sheet. The dining detail pushes it,
// because that detail is already a sheet and a second sheet dismisses it.

import XCTest

final class DiningPriceKeyUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-parkio-uitests", "-parkio-open-epcot-dining", "-parkio-suppress-location"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testDiningListPriceKeyOpensShowsAllRangesAndDismisses() {
        let key = element("parkio.dining.priceKey.list")
        XCTAssertTrue(key.waitForExistence(timeout: timeout), "Dining list has no Price key")
        XCTAssertEqual(key.label, "Price key")
        key.tap()

        assertKeyShowsEveryRange()

        let done = element("parkio.dining.priceKey.done")
        XCTAssertTrue(done.waitForExistence(timeout: timeout), "Price key has no Done button")
        done.tap()

        let panel = element("parkio.dining.priceKey.panel")
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)
        wait(for: [dismissed], timeout: timeout)
    }

    func testDiningDetailPriceKeyOpensShowsAllRangesAndDismisses() {
        let venue = app.staticTexts["Akershus Royal Banquet Hall"].firstMatch
        XCTAssertTrue(venue.waitForExistence(timeout: timeout), "EPCOT dining list did not show the test venue")
        venue.tap()

        let detail = element("parkio.dining.detail")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout), "Dining detail never appeared")

        let key = element("parkio.dining.priceKey.detail")
        XCTAssertTrue(key.waitForExistence(timeout: timeout), "Dining detail has no Price key")
        XCTAssertEqual(key.label, "Price key")
        key.tap()

        assertKeyShowsEveryRange()

        let back = app.navigationBars["Price key"].buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: timeout), "Price key has no way back to the detail")
        back.tap()

        let panel = element("parkio.dining.priceKey.panel")
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)
        wait(for: [dismissed], timeout: timeout)
        XCTAssertTrue(detail.exists, "Leaving the price key left the dining detail")
    }

    private func assertKeyShowsEveryRange() {
        let panel = element("parkio.dining.priceKey.panel")
        XCTAssertTrue(panel.waitForExistence(timeout: timeout), "Price key did not open")
        let one = element("parkio.dining.priceKey.band.1")
        XCTAssertTrue(one.waitForExistence(timeout: timeout))
        XCTAssertEqual(one.label, "One dollar sign, under 14 dollars and 99 cents per adult")
        XCTAssertEqual(
            element("parkio.dining.priceKey.band.2").label,
            "Two dollar signs, 15 to 34 dollars and 99 cents per adult"
        )
        XCTAssertEqual(
            element("parkio.dining.priceKey.band.3").label,
            "Three dollar signs, 35 to 59 dollars and 99 cents per adult"
        )
        XCTAssertEqual(
            element("parkio.dining.priceKey.band.4").label,
            "Four dollar signs, 60 dollars and up per adult"
        )
        XCTAssertTrue(element("parkio.dining.priceKey.note").exists)
        XCTAssertTrue(app.staticTexts["Per adult, before tax and tip."].exists)
    }
}

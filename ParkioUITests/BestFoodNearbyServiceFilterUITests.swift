// BestFoodNearbyServiceFilterUITests.swift — the Home dining filter.
//
// Best Food Nearby is a second list of venues. Its chips must change which
// venues are on the card, show which option is selected, and offer a 44pt
// tap target. The same bar is on the full dining list, so the size check
// opens that list and measures those chips too.

import XCTest

final class BestFoodNearbyServiceFilterUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 30

    /// EPCOT's top three unrated recommendations are all quick service
    /// (L'Artisan des Glaces, Les Halles, Katsura Grill). Katsura Grill is
    /// the plain-named one. Akershus is the first sit-down venue by name
    /// once the score is a tie at zero, so it leads the Sit-down card.
    private let quickVenue = "Katsura Grill"
    private let sitDownVenue = "Akershus Royal Banquet Hall"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-parkio-uitests",
            "-parkio-select-epcot",
            "-parkio-suppress-location",
        ]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func homeChip(_ rawValue: String) -> XCUIElement {
        element("parkio.home.dining.serviceFilter.\(rawValue)")
    }

    private func listChip(_ rawValue: String) -> XCUIElement {
        element("parkio.dining.serviceFilter.\(rawValue)")
    }

    private func bestFoodVenue(_ name: String) -> XCUIElement {
        element("parkio.home.bestFood.row.\(name)")
    }

    func testSwitchingBestFoodNearbyFilterChangesTheVisibleVenues() {
        let all = reveal(homeChip("all"))
        let quick = homeChip("quickService")
        let sitDown = homeChip("sitDown")

        waitUntilSelected(all, "All should be selected on Home")
        XCTAssertTrue(bestFoodVenue(quickVenue).waitForExistence(timeout: timeout),
                      "All did not show \(quickVenue)")
        XCTAssertFalse(bestFoodVenue(sitDownVenue).exists,
                       "\(sitDownVenue) was on the All card")

        sitDown.tap()
        waitUntilSelected(sitDown, "Sit-down did not become selected")
        waitUntilNotSelected(all, "All stayed selected")
        XCTAssertTrue(bestFoodVenue(sitDownVenue).waitForExistence(timeout: timeout),
                      "Sit-down did not show \(sitDownVenue)")
        waitUntilGone(bestFoodVenue(quickVenue), "\(quickVenue) stayed on the card under Sit-down")

        quick.tap()
        waitUntilSelected(quick, "Quick service did not become selected")
        waitUntilNotSelected(sitDown, "Sit-down stayed selected")
        XCTAssertTrue(bestFoodVenue(quickVenue).waitForExistence(timeout: timeout),
                      "Quick service did not bring \(quickVenue) back")
        waitUntilGone(bestFoodVenue(sitDownVenue), "\(sitDownVenue) stayed on the card under Quick service")

        all.tap()
        waitUntilSelected(all, "All did not become selected again")
        waitUntilNotSelected(quick, "Quick service stayed selected")
        XCTAssertTrue(bestFoodVenue(quickVenue).waitForExistence(timeout: timeout),
                      "All did not show \(quickVenue)")

        sitDown.tap()
        XCTAssertTrue(bestFoodVenue(sitDownVenue).waitForExistence(timeout: timeout))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "dining-service-filter-home"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testHomeAndDiningListFilterChipsAreAtLeast44PointsTall() {
        for rawValue in ["all", "quickService", "sitDown"] {
            assertTapTarget(reveal(homeChip(rawValue)), "Home \(rawValue)")
        }

        let browse = app.buttons["Browse all food & dining"].firstMatch
        reveal(browse)
        browse.tap()

        for rawValue in ["all", "quickService", "sitDown"] {
            assertTapTarget(reveal(listChip(rawValue)), "Dining list \(rawValue)")
        }
    }

    private func reveal(_ element: XCUIElement) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "\(element.identifier) did not appear")
        var swipes = 0
        while !element.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        return element
    }

    private func waitUntilSelected(_ chip: XCUIElement, _ message: String) {
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: chip)
        wait(for: [selected], timeout: timeout)
        XCTAssertTrue(chip.isSelected, message)
    }

    private func waitUntilNotSelected(_ chip: XCUIElement, _ message: String) {
        let unselected = expectation(for: NSPredicate(format: "isSelected == false"), evaluatedWith: chip)
        wait(for: [unselected], timeout: timeout)
        XCTAssertFalse(chip.isSelected, message)
    }

    private func waitUntilGone(_ element: XCUIElement, _ message: String) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
        XCTAssertFalse(element.exists, message)
    }

    private func assertTapTarget(_ chip: XCUIElement, _ name: String) {
        XCTAssertTrue(chip.isHittable, "\(name) chip is not on screen")
        XCTAssertGreaterThanOrEqual(
            chip.frame.height, 44,
            "\(name) chip is \(chip.frame.height)pt tall"
        )
        XCTAssertGreaterThanOrEqual(
            chip.frame.width, 44,
            "\(name) chip is \(chip.frame.width)pt wide"
        )
    }
}

// MapScreenshotUITests.swift — captures the Magic Kingdom and EPCOT map
// canvases for the CI artifact. These are screenshots, not behavior asserts.

import XCTest

final class MapScreenshotUITests: XCTestCase {

    func testCaptureMagicKingdomMap() {
        let shot = launchMap(selectEpcot: false)
        attach(shot, name: "magic-kingdom-map")
    }

    func testCaptureEpcotMap() {
        let shot = launchMap(selectEpcot: true, hideUserDot: true)
        attach(shot, name: "epcot-map")
    }

    func testEpcotUserLocationDotIsVisible() {
        let app = launchMapApp(selectEpcot: true)
        let dot = app.descendants(matching: .any)["Your location"]
        XCTAssertTrue(dot.waitForExistence(timeout: 20), "EPCOT user location dot did not appear")
        attach(XCUIScreen.main.screenshot(), name: "epcot-map-dot")
    }

    private func launchMap(selectEpcot: Bool, hideUserDot: Bool = false) -> XCUIScreenshot {
        _ = launchMapApp(selectEpcot: selectEpcot, hideUserDot: hideUserDot)
        return XCUIScreen.main.screenshot()
    }

    private func launchMapApp(selectEpcot: Bool, hideUserDot: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-parkio-uitests", "-parkio-open-map"]
        if selectEpcot {
            app.launchArguments += ["-parkio-select-epcot", "-parkio-show-services"]
        }
        if hideUserDot {
            app.launchArguments += ["-parkio-hide-user-dot"]
        }
        app.launch()

        let mapTitle = app.navigationBars["Map"]
        XCTAssertTrue(mapTitle.waitForExistence(timeout: 25), "Map tab did not open")
        // Let the canvas finish its first fit before the shot.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        return app
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

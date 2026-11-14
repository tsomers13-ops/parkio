// MapScreenshotUITests.swift — captures the Magic Kingdom and EPCOT map
// canvases for the CI artifact. These are screenshots, not behavior asserts.

import XCTest

final class MapScreenshotUITests: XCTestCase {

    func testCaptureMagicKingdomMap() {
        let shot = launchMap(selectEpcot: false)
        attach(shot, name: "magic-kingdom-map")
    }

    func testCaptureEpcotMap() {
        let shot = launchMap(selectEpcot: true)
        attach(shot, name: "epcot-map")
    }

    private func launchMap(selectEpcot: Bool) -> XCUIScreenshot {
        let app = XCUIApplication()
        app.launchArguments += ["-parkio-uitests", "-parkio-open-map"]
        if selectEpcot {
            app.launchArguments += ["-parkio-select-epcot"]
        }
        app.launch()

        let mapTitle = app.navigationBars["Map"]
        XCTAssertTrue(mapTitle.waitForExistence(timeout: 25), "Map tab did not open")
        // Let the canvas finish its first fit before the shot.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        return XCUIScreen.main.screenshot()
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

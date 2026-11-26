import XCTest

@MainActor
final class StarMapUITests: XCTestCase {

    func testMapControlsAndCatalogueNavigation() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["map-catalogue-summary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["map-catalogue-summary"].label.contains("50 pc"))
        XCTAssertFalse(app.staticTexts["Star rendering unavailable"].exists)
        attachScreenshot(of: app, named: "Expanded star field")

        // Grid controls must remain usable while the Sun is selected.
        app.buttons["Map controls"].tap()
        app.swipeUp()
        XCTAssertTrue(app.switches["Milky Way wireframe"].isEnabled)
        app.buttons["Done"].tap()

        captureMarker("galactic-context", "begin")
        app.segmentedControls.buttons["Milky Way"].tap()
        XCTAssertTrue(app.staticTexts["Zoom in to resolve individual stars"].waitForExistence(timeout: 3))
        app.buttons["Map controls"].tap()
        XCTAssertTrue(app.navigationBars["Map Controls"].waitForExistence(timeout: 3))
        app.sliders["Field of view"].adjust(toNormalizedSliderPosition: 0.7)
        app.buttons["Orbit left"].tap()
        app.buttons["Orbit up"].tap()
        app.buttons["Done"].tap()
        attachScreenshot(of: app, named: "Milky Way")
        captureMarker("galactic-context", "end")
        captureMarker("display-controls", "begin")
        app.buttons["Map controls"].tap()
        app.swipeUp()
        app.sliders["Marker size"].adjust(toNormalizedSliderPosition: 0.8)
        attachScreenshot(of: app, named: "Map controls")
        app.switches["Milky Way wireframe"].tap()
        app.buttons["Done"].tap()
        attachScreenshot(of: app, named: "Wireframe hidden")
        app.buttons["Reset view"].tap()
        XCTAssertTrue(app.staticTexts["map-catalogue-summary"].waitForExistence(timeout: 3))
        captureMarker("display-controls", "end")

        captureMarker("catalogue", "begin")
        app.tabBars.buttons["Catalogue"].tap()
        XCTAssertTrue(app.staticTexts["Proxima Centauri"].waitForExistence(timeout: 3))
        attachScreenshot(of: app, named: "Catalogue")
        app.staticTexts["Proxima Centauri"].tap()
        XCTAssertTrue(app.staticTexts["Temperature class"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Gaia radius"].exists)
        attachScreenshot(of: app, named: "Stellar properties")
        app.tabBars.buttons["3D Map"].tap()
        XCTAssertTrue(app.staticTexts["map-catalogue-summary"].waitForExistence(timeout: 3))
        captureMarker("catalogue", "end")
    }

    func testOrbitZoomAndStarSelection() {
        let app = XCUIApplication()
        app.launch()
        let map = app.otherElements["star-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        captureMarker("orbit-zoom-selection", "begin")
        attachScreenshot(of: app, named: "Before zoom")
        map.pinch(withScale: 4, velocity: 1)
        attachScreenshot(of: app, named: "Small stars revealed")
        map.swipeLeft()
        attachScreenshot(of: app, named: "Billboards after orbit")
        app.buttons["Reset view"].tap()

        // A point within the rendered nearby-star cloud, away from the Sun marker.
        let star = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        star.tap()
        XCTAssertTrue(app.staticTexts["Temperature class"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "Star details")
        app.buttons["Done"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        captureMarker("orbit-zoom-selection", "end")
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Time markers let a simulator recording be split into focused feature clips.
    private func captureMarker(_ feature: String, _ boundary: String) {
        print("GAIA_CAPTURE \(feature) \(boundary) \(Date().timeIntervalSince1970)")
    }
}

import XCTest

@MainActor
final class StarMapUITests: XCTestCase {

    func testMapControlsAndCatalogueNavigation() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["315 stars within 10 pc · Sun at the centre"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "Nearby stars")

        app.segmentedControls.buttons["Milky Way"].tap()
        XCTAssertTrue(app.staticTexts["Nearby stars cluster around the Sun at this scale"].waitForExistence(timeout: 3))
        app.buttons["Map controls"].tap()
        XCTAssertTrue(app.navigationBars["Map Controls"].waitForExistence(timeout: 3))
        app.sliders["Field of view"].adjust(toNormalizedSliderPosition: 0.7)
        app.buttons["Orbit left"].tap()
        app.buttons["Orbit up"].tap()
        app.buttons["Done"].tap()
        attachScreenshot(of: app, named: "Milky Way")
        app.buttons["Map controls"].tap()
        app.swipeUp()
        app.switches["Constant screen size"].tap()
        app.switches["Milky Way wireframe"].tap()
        app.buttons["Done"].tap()
        app.buttons["Reset view"].tap()
        XCTAssertTrue(app.staticTexts["315 stars within 10 pc · Sun at the centre"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Catalogue"].tap()
        XCTAssertTrue(app.staticTexts["Proxima Centauri"].waitForExistence(timeout: 3))
        app.staticTexts["Proxima Centauri"].tap()
        XCTAssertTrue(app.staticTexts["Source ID"].waitForExistence(timeout: 3))
        app.tabBars.buttons["3D Map"].tap()
        XCTAssertTrue(app.staticTexts["315 stars within 10 pc · Sun at the centre"].waitForExistence(timeout: 3))
    }

    func testOrbitZoomAndStarSelection() {
        let app = XCUIApplication()
        app.launch()
        let map = app.otherElements["star-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        map.swipeLeft()
        map.pinch(withScale: 1.5, velocity: 1)
        app.buttons["Reset view"].tap()

        // A point within the rendered nearby-star cloud, away from the Sun marker.
        let star = map.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        star.tap()
        XCTAssertTrue(app.staticTexts["Source ID"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

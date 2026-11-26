import XCTest
import UIKit

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
        reveal(app.switches["Milky Way wireframe"], in: app)
        XCTAssertTrue(app.switches["Milky Way wireframe"].isEnabled)
        app.buttons["Done"].tap()

        captureMarker("galactic-context", "begin")
        app.segmentedControls.buttons["Milky Way"].tap()
        assertVisibleStarBudget(in: app)
        app.buttons["Map controls"].tap()
        XCTAssertTrue(app.navigationBars["Map Controls"].waitForExistence(timeout: 3))
        reveal(app.sliders["Field of view"], in: app)
        app.sliders["Field of view"].adjust(toNormalizedSliderPosition: 0.7)
        app.buttons["Orbit left"].tap()
        app.buttons["Orbit up"].tap()
        app.buttons["Done"].tap()
        attachScreenshot(of: app, named: "Milky Way")
        captureMarker("galactic-context", "end")
        captureMarker("display-controls", "begin")
        app.buttons["Map controls"].tap()
        reveal(app.sliders["Marker size"], in: app)
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
        let name = app.staticTexts["selected-star-name"]
        let data = app.buttons["selected-star-data"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(data.isHittable)
        XCTAssertFalse(app.staticTexts["Temperature class"].exists)
        attachScreenshot(of: app, named: "Selected star overlay")
        let before = name.frame
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55))
            .press(forDuration: 0.05, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.59, dy: 0.55)))
        XCTAssertTrue(name.exists)
        XCTAssertNotEqual(name.frame, before)
        data.tap()
        XCTAssertTrue(app.staticTexts["Temperature class"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "Star details")
        app.buttons["Done"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        XCTAssertTrue(data.waitForExistence(timeout: 3))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.05)).tap()
        XCTAssertFalse(data.exists)
        captureMarker("orbit-zoom-selection", "end")
    }

    func testMilkyWayStarsSurviveCameraSwitchesAndExtremeZoom() {
        let app = XCUIApplication()
        app.launch()
        let map = app.otherElements["star-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        captureMarker("adaptive-visibility", "begin")
        app.segmentedControls.buttons["Milky Way"].tap()
        assertVisibleStarBudget(in: app)
        attachScreenshot(of: app, named: "Milky Way stars")
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.34, dy: 0.465)).tap()
        XCTAssertTrue(app.buttons["selected-star-data"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Temperature class"].exists)
        attachScreenshot(of: app, named: "Milky Way selection")
        map.pinch(withScale: 0.2, velocity: -1)
        assertVisibleStarBudget(in: app)
        attachScreenshot(of: app, named: "Distant stars remain visible")
        map.pinch(withScale: 20, velocity: 4)
        assertVisibleStarBudget(in: app)
        attachScreenshot(of: app, named: "Zoom keeps catalogue in frame")
        app.segmentedControls.buttons["Sun"].tap()
        assertVisibleStarBudget(in: app)
        attachScreenshot(of: app, named: "Sun camera stars")
        captureMarker("adaptive-visibility", "end")
    }

    private func assertVisibleStarBudget(in app: XCUIApplication) {
        let summary = app.staticTexts["map-catalogue-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        let count = Int(summary.label.split(separator: " ").first ?? "0") ?? 0
        XCTAssertTrue((100...1_000).contains(count), "Unexpected star count: \(summary.label)")
    }

    func testGlowControlsUpdateTheMapWhileSheetIsOpen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["star-map"].waitForExistence(timeout: 10))
        app.buttons["Map controls"].tap()
        let size = app.sliders["Glow size"]
        let intensity = app.sliders["Glow intensity"]
        let bias = app.sliders["Glow bias"]
        XCTAssertTrue(bias.waitForExistence(timeout: 3))
        let defaults = [size, intensity, bias].map { $0.value as? String }

        captureMarker("live-glow-controls", "begin")
        size.adjust(toNormalizedSliderPosition: 0.6)
        bias.adjust(toNormalizedSliderPosition: 0)
        intensity.adjust(toNormalizedSliderPosition: 0)
        let unlit = try previewBrightness(app.screenshot())
        attachScreenshot(of: app, named: "Glows off")

        intensity.adjust(toNormalizedSliderPosition: 0.55)
        let broad = try previewBrightness(app.screenshot())
        XCTAssertGreaterThan(broad, unlit * 1.1, "The visible map must brighten before dismissing controls")
        attachScreenshot(of: app, named: "Live glow controls")
        bias.adjust(toNormalizedSliderPosition: 1)
        XCTAssertLessThan(try previewBrightness(app.screenshot()), broad)
        attachScreenshot(of: app, named: "Concentrated glow")

        app.buttons["Reset glow"].tap()
        XCTAssertEqual([size, intensity, bias].map { $0.value as? String }, defaults)
        captureMarker("live-glow-controls", "end")
        app.buttons["Done"].tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    /// Samples only the exposed star field above the medium sheet, excluding labels and controls.
    private func previewBrightness(_ screenshot: XCUIScreenshot) throws -> Double {
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let region = CGRect(x: Double(image.width) * 0.05, y: Double(image.height) * 0.25,
                            width: Double(image.width) * 0.9, height: Double(image.height) * 0.15)
        let crop = try XCTUnwrap(image.cropping(to: region))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height,
                                                 bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        }
        return stride(from: 0, to: pixels.count, by: 4).reduce(0.0) {
            $0 + Double(pixels[$1]) + Double(pixels[$1 + 1]) + Double(pixels[$1 + 2])
        }
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

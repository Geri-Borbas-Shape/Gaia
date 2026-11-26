import Foundation
import Testing
@testable import Gaia

@Test func galacticAxesHaveExpectedDirections() {
    let cases: [(Double, Double, SIMD3<Double>)] = [
        (0, 0, [10, 0, 0]),
        (90, 0, [0, 10, 0]),
        (180, 0, [-10, 0, 0]),
        (270, 0, [0, -10, 0]),
        (0, 90, [0, 0, 10]),
        (0, -90, [0, 0, -10])
    ]
    for (longitude, latitude, expected) in cases {
        let position = Star.galacticPosition(longitude: longitude, latitude: latitude, distance: 10)
        for axis in 0..<3 {
            #expect(abs(position[axis] - expected[axis]) < 1e-10)
        }
    }
}

@Test func cataloguePositionsPreserveDistanceAndHandedness() throws {
    for star in try StarRepository.bundled().stars {
        let position = star.galacticPositionInParsecs
        let distance = (position * position).sum().squareRoot()
        #expect(abs(distance - star.distanceInParsecs) < 1e-10)
        #expect(star.scenePosition.x == Float(position.x))
        #expect(star.scenePosition.y == Float(position.z))
        #expect(star.scenePosition.z == Float(-position.y))
    }
}

@Test func proximaHasExpectedScenePosition() throws {
    let proxima = try #require(try StarRepository.bundled().stars.first)
    #expect(abs(proxima.scenePosition.x - 0.9027) < 0.001)
    #expect(abs(proxima.scenePosition.y - -0.04357) < 0.001)
    #expect(abs(proxima.scenePosition.z - 0.9372) < 0.001)
}

@Test func screenSizeCompensatesForDepthAndViewport() {
    let radius = StarMapProjection.markerRadius(diameter: 10, depth: 20, fieldOfView: 90, viewportHeight: 1_000)
    #expect(abs(radius - 0.2) < 0.0001)
    let farther = StarMapProjection.markerRadius(diameter: 10, depth: 40, fieldOfView: 90, viewportHeight: 1_000)
    #expect(abs(farther - radius * 2) < 0.0001)
    let taller = StarMapProjection.markerRadius(diameter: 10, depth: 20, fieldOfView: 90, viewportHeight: 2_000)
    #expect(abs(taller - radius / 2) < 0.0001)
    let narrower = StarMapProjection.markerRadius(diameter: 10, depth: 20, fieldOfView: 45, viewportHeight: 1_000)
    #expect(narrower < radius)
}

@Test func invalidProjectionDoesNotProduceVisibleMarkers() {
    #expect(StarMapProjection.markerRadius(diameter: 5, depth: -1, fieldOfView: 50, viewportHeight: 800) == 0)
    #expect(StarMapProjection.markerRadius(diameter: 5, depth: 10, fieldOfView: 50, viewportHeight: 0) == 0)
    #expect(StarMapProjection.markerRadius(diameter: 5, depth: 10, fieldOfView: 180, viewportHeight: 800) == 0)
}

@Test func resetRestoresLocalViewAndCanBeRepeated() {
    var options = StarMapOptions()
    options.focus = .galacticCenter
    options.fieldOfView = 10
    options.showsMilkyWay = false
    options.glow = .init(size: 4, intensity: 1, bias: 0.25)
    options.reset()
    #expect(options.focus == .sun)
    #expect(options.fieldOfView == 50)
    #expect(options.showsMilkyWay)
    #expect(options.glow == StarGlowSettings())
    #expect(options.resetID == 1)
    options.reset()
    #expect(options.resetID == 2)
}

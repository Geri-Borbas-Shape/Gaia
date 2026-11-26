import Foundation

struct StarMapOptions: Equatable {

    enum Focus: String, CaseIterable, Identifiable {
        case sun = "Sun"
        case galacticCenter = "Milky Way"

        var id: Self { self }

        var center: SIMD3<Float> {
            switch self {
            case .sun: .zero
            case .galacticCenter: SIMD3(8_178, -20.8, 0)
            }
        }

        var distance: Float {
            switch self {
            case .sun: 45
            case .galacticCenter: 55_000
            }
        }
    }

    var focus = Focus.sun
    var fieldOfView = 50.0
    var markerSize = 5.0
    var constantScreenSize = true
    var showsMilkyWay = true
    var resetID = 0
    var horizontalOrbit = 0
    var verticalOrbit = 0

    mutating func reset() {
        let nextID = resetID + 1
        self = Self()
        resetID = nextID
    }
}

enum StarMapProjection {

    /// Radius of a unit sphere for a requested diameter in screen points, using camera-space depth.
    static func markerRadius(diameter: Float, depth: Float, fieldOfView: Float, viewportHeight: Float) -> Float {
        guard diameter > 0, depth > 0, viewportHeight > 0, fieldOfView > 0, fieldOfView < 180 else { return 0 }
        return diameter * depth * tan(fieldOfView * .pi / 360) / viewportHeight
    }
}

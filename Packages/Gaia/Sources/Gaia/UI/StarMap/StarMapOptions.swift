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
            case .sun: 140
            case .galacticCenter: 55_000
            }
        }
    }

    var focus = Focus.sun
    var fieldOfView = 50.0
    var markerSize = 5.0
    var visibleStarCount = Double(StarVisibility.defaultCount)
    var glow = StarGlowSettings()
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

struct StarGlowSettings: Equatable {
    /// Scale relative to the original three-radius halo; leaves the core unchanged.
    var size = 1.0
    var intensity = 0.16
    /// Exponent of the halo profile: below one spreads it; above one concentrates it.
    var bias = 1.0
}

enum StarMapProjection {

    /// Shared with StarGlow.metal through custom uniforms. All stars use the same exaggeration.
    static let parsecsPerSolarRadius: Float = 0.0125
    static let minimumDiameter: Float = 0.75
    static let glowExtent: Float = 3

    static func worldRadius(solarRadius: Float, markerSize: Float) -> Float {
        solarRadius * markerSize * parsecsPerSolarRadius
    }

    static func projectedDiameter(radius: Float, depth: Float, fieldOfView: Float, viewportHeight: Float) -> Float {
        guard radius.isFinite, radius > 0, depth.isFinite, depth > 0,
              viewportHeight > 0, fieldOfView > 0, fieldOfView < 180 else { return 0 }
        return radius * viewportHeight / (depth * tan(fieldOfView * .pi / 360))
    }

    /// Radius of a unit sphere for a requested diameter in screen points, using camera-space depth.
    static func markerRadius(diameter: Float, depth: Float, fieldOfView: Float, viewportHeight: Float) -> Float {
        guard diameter > 0, depth > 0, viewportHeight > 0, fieldOfView > 0, fieldOfView < 180 else { return 0 }
        return diameter * depth * tan(fieldOfView * .pi / 360) / viewportHeight
    }
}

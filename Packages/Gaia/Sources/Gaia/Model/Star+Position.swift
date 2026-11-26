import Foundation

public extension Star {

    /// Sun-centred Galactic Cartesian coordinates in parsecs: X toward l=0°, Y toward l=90°, Z north.
    var galacticPositionInParsecs: SIMD3<Double> {
        Self.galacticPosition(longitude: galacticLongitude, latitude: galacticLatitude, distance: distanceInParsecs)
    }

    internal static func galacticPosition(longitude: Double, latitude: Double, distance: Double) -> SIMD3<Double> {
        let longitude = longitude * .pi / 180
        let latitude = latitude * .pi / 180
        return SIMD3(
            distance * cos(latitude) * cos(longitude),
            distance * cos(latitude) * sin(longitude),
            distance * sin(latitude)
        )
    }

    /// RealityKit uses Y up; one scene unit is one parsec.
    internal var scenePosition: SIMD3<Float> {
        let position = galacticPositionInParsecs
        return SIMD3(Float(position.x), Float(position.z), Float(-position.y))
    }
}

import simd
import Testing
@testable import Gaia

private func cameraMatrix(center: SIMD3<Float>, direction: SIMD3<Float>, distance: Float) -> simd_float4x4 {
    let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), direction))
    let up = simd_cross(direction, right)
    let position = center + direction * distance
    return simd_float4x4([right.x, up.x, direction.x, 0], [right.y, up.y, direction.y, 0],
                        [right.z, up.z, direction.z, 0],
                        [-simd_dot(right, position), -simd_dot(up, position), -simd_dot(direction, position), 1])
}

@Test func visibilityPrefersLargeApparentStarsAndHasAHardBudget() {
    let sources = (1...1_500).map { StarVisibility.Source(position: [0, 0, -100], radius: Float($0)) }
    let equal = Array(repeating: StarVisibility.Source(position: [0, 0, -100], radius: 1), count: 1_500)
    for count in [100, 500, 1_000] {
        let frame = StarVisibility(sources: sources).frame(worldToView: matrix_identity_float4x4,
            viewport: [400, 600], fieldOfView: 50, markerSize: 5, targetCount: count)
        #expect(frame.stars.count == count)
        #expect(Set(frame.stars.map(\.index)) == Set((1_500 - count)..<1_500))
        #expect(frame.stars.allSatisfy { frame.displayedDiameter($0) <= StarVisibility.maximumDiameter })
        #expect(StarVisibility(sources: equal).frame(worldToView: matrix_identity_float4x4,
            viewport: [400, 600], fieldOfView: 50, markerSize: 5, targetCount: count).stars.count == count)
    }
}

@Test func visibilityExcludesOffscreenAndBehindCameraStars() {
    let policy = StarVisibility(sources: [.init(position: [0, 0, -10], radius: 1),
        .init(position: [0, 0, 10], radius: 1_000), .init(position: [100, 0, -10], radius: 1_000)])
    let frame = policy.frame(worldToView: matrix_identity_float4x4, viewport: [400, 600], fieldOfView: 50, markerSize: 5)
    #expect(frame.stars.map(\.index) == [0])
    #expect(frame.stars[0].point == [200, 300])
}

@Test func nearbyCatalogueStaysVisibleAcrossCameraAndZoomExtremes() throws {
    let policy = StarVisibility(sources: try StarRepository.bundled().stars.map {
        .init(position: $0.scenePosition, radius: Float($0.appearance.radius))
    })
    let directions: [SIMD3<Float>] = [simd_normalize([0.53, 0.43, 0.73]), simd_normalize([-0.8, -0.3, 0.1])]
    for center in [SIMD3<Float>.zero, StarMapOptions.Focus.galacticCenter.center] {
        for requested: Float in [0.5, 140, 100_000] {
            for fieldOfView: Float in [10, 80] {
                for direction in directions {
                    for count in [100, 1_000] {
                        let viewport = SIMD2<Float>(400, 600)
                        let distance = policy.cameraDistance(center: center, direction: direction, requested: requested,
                                                            viewport: viewport, fieldOfView: fieldOfView, targetCount: count)
                        let frame = policy.frame(worldToView: cameraMatrix(center: center, direction: direction, distance: distance),
                                                 viewport: viewport, fieldOfView: fieldOfView, markerSize: 5, targetCount: count)
                        #expect(frame.stars.count == count)
                        #expect(frame.stars.allSatisfy { frame.displayedDiameter($0) >= 1.99 })
                        #expect(distance >= requested)
                    }
                }
            }
        }
    }
}

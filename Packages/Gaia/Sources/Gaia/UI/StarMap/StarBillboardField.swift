#if os(iOS)
import Metal
import RealityKit

/// One batched core mesh plus a separate screen-blended Metal glow pass.
@MainActor
final class StarBillboardField {
    struct Marker {
        let star: Star?
        let position: SIMD3<Float>
        let radius: Float
        let color: SIMD3<Float>
    }

    private struct Vertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
        var uv: SIMD2<Float>
        var radius: SIMD2<Float>
    }

    let markers: [Marker]
    let entity: ModelEntity
    let glowPass: StarGlowPass
    private var material: CustomMaterial
    private let mesh: LowLevelMesh
    private let meshBounds: BoundingBox
    private var visibleIndices: [Int]?

    init(stars: [Star]) throws {
        let markers = stars.map { star in
            let appearance = star.appearance
            return Marker(star: star, position: star.scenePosition,
                          radius: Float(appearance.radius), color: appearance.color)
        } + [Marker(star: nil, position: .zero, radius: 1, color: StarAppearance.color(temperature: 5_772))]
        self.markers = markers

        guard let device = MTLCreateSystemDefaultDevice() else { throw RenderError.noMetalDevice }
        let library = try device.makeDefaultLibrary(bundle: .module)
        material = try CustomMaterial(
            surfaceShader: .init(named: "starCoreSurface", in: library),
            geometryModifier: .init(named: "starBillboardGeometry", in: library),
            lightingModel: .unlit
        )
        material.blending = .opaque
        material.faceCulling = .none
        material.writesDepth = true
        glowPass = try StarGlowPass(stars: markers.map {
            .init(positionRadius: SIMD4($0.position, $0.radius), color: SIMD4($0.color, 1))
        }, device: device, library: library)

        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: markers.count * 4,
            vertexAttributes: [
                .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
                .init(semantic: .color, format: .float4, offset: MemoryLayout<Vertex>.offset(of: \.color)!),
                .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
                .init(semantic: .uv1, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.radius)!)
            ],
            vertexLayouts: [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)],
            indexCapacity: min(markers.count, StarVisibility.maximumCount) * 6
        )
        let mesh = try LowLevelMesh(descriptor: descriptor)
        self.mesh = mesh
        let corners: [SIMD2<Float>] = [[-1, -1], [1, -1], [1, 1], [-1, 1]]
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
            let vertices = bytes.bindMemory(to: Vertex.self)
            for (index, marker) in markers.enumerated() {
                for corner in 0..<4 {
                    vertices[index * 4 + corner] = Vertex(
                        position: marker.position, color: SIMD4(marker.color, 1),
                        uv: corners[corner], radius: [marker.radius, 0]
                    )
                }
            }
        }
        mesh.withUnsafeMutableIndices { bytes in
            let indices = bytes.bindMemory(to: UInt32.self)
            for index in 0..<min(markers.count, StarVisibility.maximumCount) {
                for (offset, corner) in [0, 1, 2, 0, 2, 3].enumerated() {
                    indices[index * 6 + offset] = UInt32(index * 4 + corner)
                }
            }
        }
        // Geometry modifiers can extend beyond the stored point positions. Include the maximum
        // slider size and quad extent in the mesh bounds so RealityKit does not cull visible cores.
        var lower = SIMD3<Float>(repeating: .infinity)
        var upper = SIMD3<Float>(repeating: -.infinity)
        for marker in markers {
            let extent = SIMD3<Float>(repeating: StarMapProjection.worldRadius(solarRadius: marker.radius, markerSize: 12)
                                      * StarMapProjection.glowExtent)
            lower = simd_min(lower, marker.position - extent)
            upper = simd_max(upper, marker.position + extent)
        }
        meshBounds = BoundingBox(min: lower, max: upper)
        mesh.parts.replaceAll([.init(indexCount: min(markers.count, StarVisibility.maximumCount) * 6, bounds: meshBounds)])
        let resource = try MeshResource(from: mesh)
        entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = "Gaia star billboards"
    }

    func update(markerSize: Float, viewportHeight: Float, visibility: StarVisibility.Frame) {
        let indices = visibility.stars.map(\.index).sorted()
        if indices != visibleIndices {
            mesh.withUnsafeMutableIndices { bytes in
                let buffer = bytes.bindMemory(to: UInt32.self)
                for (slot, index) in indices.enumerated() {
                    for (offset, corner) in [0, 1, 2, 0, 2, 3].enumerated() {
                        buffer[slot * 6 + offset] = UInt32(index * 4 + corner)
                    }
                }
            }
            mesh.parts.replaceAll([.init(indexCount: indices.count * 6, bounds: meshBounds)])
            glowPass.setVisibleIndices(indices)
            visibleIndices = indices
        }
        let uniforms = SIMD4(markerSize * StarMapProjection.parsecsPerSolarRadius * visibility.scale, viewportHeight,
                             visibility.threshold * visibility.scale, StarVisibility.maximumDiameter)
        guard material.custom.value != uniforms else { return }
        material.custom.value = uniforms
        entity.model?.materials = [material]
    }

    private enum RenderError: Error { case noMetalDevice }
}
#endif

#if os(iOS)
import Metal
import RealityKit

/// One shared mesh with separate core and halo passes. The shader faces each quad toward the camera.
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
    private let glow: ModelEntity
    private var material: CustomMaterial
    private var glowMaterial: CustomMaterial

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
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        material.faceCulling = .none
        material.writesDepth = true
        glowMaterial = try CustomMaterial(
            surfaceShader: .init(named: "starGlowSurface", in: library),
            geometryModifier: .init(named: "starBillboardGeometry", in: library),
            lightingModel: .unlit
        )
        glowMaterial.blending = .transparent(opacity: .init(floatLiteral: 1))
        glowMaterial.faceCulling = .none
        glowMaterial.writesDepth = false

        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: markers.count * 4,
            vertexAttributes: [
                .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
                .init(semantic: .color, format: .float4, offset: MemoryLayout<Vertex>.offset(of: \.color)!),
                .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
                .init(semantic: .uv1, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.radius)!)
            ],
            vertexLayouts: [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)],
            indexCapacity: markers.count * 6
        )
        let mesh = try LowLevelMesh(descriptor: descriptor)
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
            for index in markers.indices {
                for (offset, corner) in [0, 1, 2, 0, 2, 3].enumerated() {
                    indices[index * 6 + offset] = UInt32(index * 4 + corner)
                }
            }
        }
        // Geometry modifiers can extend beyond the stored point positions. Include the maximum
        // slider radius and glow in the mesh bounds so RealityKit does not cull visible halos.
        var lower = SIMD3<Float>(repeating: .infinity)
        var upper = SIMD3<Float>(repeating: -.infinity)
        for marker in markers {
            let extent = SIMD3<Float>(repeating: StarMapProjection.worldRadius(solarRadius: marker.radius, markerSize: 12)
                                      * StarMapProjection.glowExtent)
            lower = simd_min(lower, marker.position - extent)
            upper = simd_max(upper, marker.position + extent)
        }
        mesh.parts.replaceAll([.init(indexCount: markers.count * 6, bounds: BoundingBox(min: lower, max: upper))])
        let resource = try MeshResource(from: mesh)
        entity = ModelEntity(mesh: resource, materials: [material])
        glow = ModelEntity(mesh: resource, materials: [glowMaterial])
        let ordering = ModelSortGroup()
        entity.components.set(ModelSortGroupComponent(group: ordering, order: 0))
        glow.components.set(ModelSortGroupComponent(group: ordering, order: 1))
        entity.addChild(glow)
        entity.name = "Gaia star billboards"
    }

    func update(markerSize: Float, viewportHeight: Float) {
        let uniforms = SIMD4(markerSize * StarMapProjection.parsecsPerSolarRadius, viewportHeight,
                             StarMapProjection.minimumDiameter, StarMapProjection.glowExtent)
        guard material.custom.value != uniforms else { return }
        material.custom.value = uniforms
        glowMaterial.custom.value = uniforms
        entity.model?.materials = [material]
        glow.model?.materials = [glowMaterial]
    }

    private enum RenderError: Error { case noMetalDevice }
}
#endif

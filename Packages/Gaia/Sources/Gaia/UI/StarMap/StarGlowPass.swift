import Foundation
import Metal
import simd

/// Draws every halo over the completed scene using screen blending, without a depth attachment.
/// The lock protects frame uniforms and cached pipelines during updates and encoding.
final class StarGlowPass: @unchecked Sendable {
    struct Star {
        var positionRadius: SIMD4<Float>
        var color: SIMD4<Float>
    }

    private struct Uniforms {
        var worldToView = matrix_identity_float4x4
        var projection = matrix_identity_float4x4
        var controls = SIMD4<Float>(0, 0, StarMapProjection.minimumDiameter, StarMapProjection.glowExtent)
        var glow = SIMD4<Float>(0.16, 1, StarMapProjection.glowExtent, 0)
        var visibility = SIMD4<Float>(StarVisibility.maximumDiameter, 0, 0, 0)
    }

    private let device: any MTLDevice
    private let library: any MTLLibrary
    private let stars: any MTLBuffer
    private var visibleIndices: [UInt32]
    private let lock = NSLock()
    private var uniforms = Uniforms()
    private var pipelines: [MTLPixelFormat: (copy: any MTLRenderPipelineState, glow: any MTLRenderPipelineState)] = [:]

    init(stars: [Star], device: any MTLDevice, library: (any MTLLibrary)? = nil) throws {
        self.device = device
        self.library = try library ?? device.makeDefaultLibrary(bundle: .module)
        visibleIndices = (0..<min(stars.count, StarVisibility.targetCount)).map(UInt32.init)
        guard let buffer = stars.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw RenderError.bufferUnavailable }
        self.stars = buffer
        self.stars.label = "Star glow instances"
    }

    func setVisibleIndices(_ indices: [Int]) {
        precondition(indices.count <= StarVisibility.targetCount)
        lock.lock()
        defer { lock.unlock() }
        visibleIndices = indices.map(UInt32.init)
    }

    func update(worldToView: simd_float4x4, markerSize: Float, viewportHeight: Float,
                glow: StarGlowSettings = .init(), visibility: StarVisibility.Frame? = nil) {
        lock.lock()
        defer { lock.unlock() }
        uniforms.worldToView = worldToView
        let scale = visibility?.scale ?? 1
        uniforms.controls.x = markerSize * StarMapProjection.parsecsPerSolarRadius * scale
        uniforms.controls.y = viewportHeight
        uniforms.controls.z = (visibility?.threshold ?? StarMapProjection.minimumDiameter) * scale
        uniforms.controls.w = StarMapProjection.glowExtent * Float(glow.size)
        uniforms.glow.x = Float(glow.intensity)
        uniforms.glow.y = Float(glow.bias)
    }

    func encode(source: any MTLTexture, target: any MTLTexture, commandBuffer: any MTLCommandBuffer,
                projection: simd_float4x4) throws {
        lock.lock()
        defer { lock.unlock() }
        let pipeline = try pipelines(for: target.pixelFormat)
        var frame = uniforms
        frame.projection = projection
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        // Deliberately no depth texture: every halo is drawn on top of all stars and the grid.
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderError.encoderUnavailable
        }
        encoder.label = "Star glow: screen blend after scene"
        encoder.setRenderPipelineState(pipeline.copy)
        encoder.setFragmentTexture(source, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.setRenderPipelineState(pipeline.glow)
        encoder.setVertexBuffer(stars, offset: 0, index: 0)
        encoder.setVertexBytes(&frame, length: MemoryLayout<Uniforms>.stride, index: 1)
        if !visibleIndices.isEmpty {
            // At most 500 indices (2 KB), copied by Metal into this frame's command buffer.
            visibleIndices.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 2) }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: visibleIndices.count)
        }
        encoder.endEncoding()
    }

    private func pipelines(for format: MTLPixelFormat) throws -> (copy: any MTLRenderPipelineState, glow: any MTLRenderPipelineState) {
        if let cached = pipelines[format] { return cached }
        let copy = MTLRenderPipelineDescriptor()
        copy.label = "Copy completed star scene"
        copy.vertexFunction = library.makeFunction(name: "starSceneCopyVertex")
        copy.fragmentFunction = library.makeFunction(name: "starSceneCopyFragment")
        copy.colorAttachments[0].pixelFormat = format

        let glow = MTLRenderPipelineDescriptor()
        glow.label = "Screen-blended star billboards"
        glow.vertexFunction = library.makeFunction(name: "starGlowVertex")
        glow.fragmentFunction = library.makeFunction(name: "starGlowFragment")
        let color = glow.colorAttachments[0]!
        color.pixelFormat = format
        color.isBlendingEnabled = true
        color.rgbBlendOperation = .add
        color.sourceRGBBlendFactor = .one
        color.destinationRGBBlendFactor = .oneMinusSourceColor
        // Screen: source + destination × (1 − source). Preserve the scene's alpha.
        color.alphaBlendOperation = .add
        color.sourceAlphaBlendFactor = .zero
        color.destinationAlphaBlendFactor = .one
        let result = (copy: try device.makeRenderPipelineState(descriptor: copy),
                      glow: try device.makeRenderPipelineState(descriptor: glow))
        pipelines[format] = result
        return result
    }

    private enum RenderError: Error { case bufferUnavailable, encoderUnavailable }
}

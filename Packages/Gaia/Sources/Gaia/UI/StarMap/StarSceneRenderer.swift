#if os(iOS)
import MetalKit
import RealityKit

/// RealityKit renders the cores/grid first; Metal then screen-blends every halo over that image.
@MainActor
final class StarSceneRenderer {
    private let scene: RealityRenderer
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let event: any MTLSharedEvent
    private let inFlight = DispatchSemaphore(value: 3)
    private var completedFrameValue: UInt64 = 0
    private var sceneTexture: (any MTLTexture)?
    private var cameraOutput: RealityRenderer.CameraOutput?

    init(root: Entity, camera: Entity, device: any MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(), let event = device.makeSharedEvent() else {
            throw RenderError.resourcesUnavailable
        }
        self.queue = queue
        self.event = event
        scene = try RealityRenderer()
        scene.entities.append(root)
        scene.activeCamera = camera
        scene.cameraSettings.colorBackground = .color(UIColor.black.cgColor)
        scene.cameraSettings.antialiasing = .multisample4X
    }

    func render(in view: MTKView, deltaTime: TimeInterval, glow: StarGlowPass, projection: simd_float4x4) throws {
        guard inFlight.wait(timeout: .now()) == .success else { return }
        var committed = false
        defer { if !committed { inFlight.signal() } }
        guard let drawable = view.currentDrawable, let command = queue.makeCommandBuffer() else { return }
        let size = view.drawableSize
        if sceneTexture?.width != Int(size.width) || sceneTexture?.height != Int(size.height) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: view.colorPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false
            )
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw RenderError.resourcesUnavailable }
            texture.label = "Star cores and Galactic grid"
            sceneTexture = texture
            cameraOutput = try .init(.singleProjection(colorTexture: texture))
        }
        guard let sceneTexture, let cameraOutput else { return }
        let sceneReady = completedFrameValue + 1
        let frameReady = completedFrameValue + 2
        // Both queues share this texture. Do not overwrite it until the previous glow pass finishes.
        try scene.updateAndRender(
            deltaTime: deltaTime, cameraOutput: cameraOutput,
            actionsBeforeRender: [.wait(for: event, value: completedFrameValue)],
            actionsAfterRender: [.signal(event, value: sceneReady)]
        )
        command.encodeWaitForEvent(event, value: sceneReady)
        try glow.encode(source: sceneTexture, target: drawable.texture, commandBuffer: command, projection: projection)
        command.encodeSignalEvent(event, value: frameReady)
        command.present(drawable)
        let semaphore = inFlight
        command.addCompletedHandler { _ in semaphore.signal() }
        command.commit()
        committed = true
        completedFrameValue = frameReady
    }

    private enum RenderError: Error { case resourcesUnavailable }
}
#endif

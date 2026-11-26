#if os(iOS)
import MetalKit
import RealityKit
import SwiftUI
import OSLog

/// Camera and selection around a GPU-rendered field of star billboards.
@MainActor
final class StarMapScene: NSObject, MTKViewDelegate {

    private weak var view: MTKView?
    private let root = Entity()
    private let camera = PerspectiveCamera()
    private let milkyWay = Entity()
    private var starField: StarBillboardField?
    private var renderingFailed = false
    private var renderer: StarSceneRenderer?
    private var previousFrameTime: TimeInterval?
    private var options = StarMapOptions()
    private var center = SIMD3<Float>.zero
    private var orbitDistance = StarMapOptions.Focus.sun.distance
    private var targetDistance = StarMapOptions.Focus.sun.distance
    private var yaw: Float = .pi / 5
    private var pitch: Float = .pi / 7
    private var reduceMotion = false
    var onSelect: ((Star) -> Void)?

    init(stars: [Star]) {
        super.init()

        camera.camera = PerspectiveCameraComponent(
            near: 0.01,
            far: 200_000,
            fieldOfViewInDegrees: 50,
            fieldOfViewOrientation: .vertical
        )
        root.addChild(camera)

        do {
            let field = try StarBillboardField(stars: stars)
            starField = field
            root.addChild(field.entity)
        } catch {
            renderingFailed = true
            Logger.catalog.error("Star shader failed to load: \(error, privacy: .public)")
        }

        milkyWay.position = StarMapOptions.Focus.galacticCenter.center
        milkyWay.addChild(Self.disk(height: 335, color: UIColor(white: 0.6, alpha: 1)))
        milkyWay.addChild(Self.disk(height: 2_600, color: UIColor(white: 0.35, alpha: 1)))
        root.addChild(milkyWay)
        positionCamera()
    }

    func attach(to view: MTKView) {
        self.view = view
        view.delegate = self
        do {
            guard let device = view.device else { throw CocoaError(.featureUnsupported) }
            renderer = try StarSceneRenderer(root: root, camera: camera, device: device)
        } catch {
            renderingFailed = true
            Logger.catalog.error("Star renderer failed: \(error, privacy: .public)")
        }
        if renderingFailed {
            let message = UILabel()
            message.text = "Star rendering unavailable"
            message.textColor = .white
            message.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(orbit(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
        let tap = UITapGestureRecognizer(target: self, action: #selector(selectStar(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    func update(options next: StarMapOptions, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        if next.resetID != options.resetID {
            yaw = .pi / 5
            pitch = .pi / 7
        } else {
            yaw += Float(next.horizontalOrbit - options.horizontalOrbit) * .pi / 12
            pitch += Float(next.verticalOrbit - options.verticalOrbit) * .pi / 12
            clampPitch()
        }
        if next.focus != options.focus || next.resetID != options.resetID {
            targetDistance = next.focus.distance
        }
        options = next
        camera.camera.fieldOfViewInDegrees = Float(next.fieldOfView)
        milkyWay.isEnabled = next.showsMilkyWay
        if reduceMotion {
            center = next.focus.center
            orbitDistance = targetDistance
        }
    }

    func setActive(_ active: Bool) {
        view?.isPaused = !active || renderingFailed
        if !active { previousFrameTime = nil }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard view.bounds.height > 0, view.bounds.width > 0, let starField else { return }
        let time = CACurrentMediaTime()
        let delta = min(time - (previousFrameTime ?? time), 0.1)
        previousFrameTime = time
        tick(deltaTime: Float(delta))
        do {
            try renderer?.render(in: view, deltaTime: delta, glow: starField.glowPass, projection: projectionMatrix)
        } catch {
            renderingFailed = true
            view.isPaused = true
            Logger.catalog.error("Star frame failed: \(error, privacy: .public)")
        }
    }

    private var projectionMatrix: simd_float4x4 {
        let aspect = Float((view?.bounds.width ?? 1) / max(view?.bounds.height ?? 1, 1))
        let y = 1 / tan(Float(options.fieldOfView) * .pi / 360)
        let near = camera.camera.near, far = camera.camera.far
        return simd_float4x4([y / aspect, 0, 0, 0], [0, y, 0, 0],
                            [0, 0, far / (near - far), -1], [0, 0, near * far / (near - far), 0])
    }

    private func project(_ position: SIMD3<Float>) -> CGPoint? {
        guard let view else { return nil }
        let clip = projectionMatrix * simd_inverse(camera.transform.matrix) * SIMD4(position, 1)
        guard clip.w > 0 else { return nil }
        return CGPoint(x: CGFloat(clip.x / clip.w + 1) * view.bounds.width / 2,
                       y: CGFloat(1 - clip.y / clip.w) * view.bounds.height / 2)
    }

    private func tick(deltaTime: Float) {
        let blend: Float = reduceMotion ? 1 : 1 - exp(-min(deltaTime, 0.1) * 8)
        center += (options.focus.center - center) * blend
        orbitDistance += (targetDistance - orbitDistance) * blend
        positionCamera()
        updateMarkers()
    }

    private func positionCamera() {
        let direction = SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
        camera.look(at: center, from: center + direction * orbitDistance, relativeTo: nil)
    }

    private func updateMarkers() {
        guard let view, view.bounds.height > 0 else { return }
        starField?.update(markerSize: Float(options.markerSize), viewportHeight: Float(view.bounds.height))
        starField?.glowPass.update(worldToView: simd_inverse(camera.transform.matrix),
                                  markerSize: Float(options.markerSize), viewportHeight: Float(view.bounds.height))
    }

    @objc private func orbit(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        yaw -= Float(translation.x) * 0.006
        pitch += Float(translation.y) * 0.006
        clampPitch()
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func zoom(_ gesture: UIPinchGestureRecognizer) {
        targetDistance = min(max(targetDistance / Float(gesture.scale), 0.5), 100_000)
        gesture.scale = 1
    }

    @objc private func selectStar(_ gesture: UITapGestureRecognizer) {
        guard let view else { return }
        let tap = gesture.location(in: view)
        let worldToCamera = simd_inverse(camera.transform.matrix)
        // Match the shader's visibility threshold, so hidden stars cannot steal a tap.
        let candidate = starField?.markers.compactMap { marker -> (Star, CGFloat)? in
            guard let star = marker.star else { return nil }
            let depth = -(worldToCamera * SIMD4(marker.position, 1)).z
            let diameter = StarMapProjection.projectedDiameter(
                radius: StarMapProjection.worldRadius(solarRadius: marker.radius, markerSize: Float(options.markerSize)),
                depth: depth, fieldOfView: Float(options.fieldOfView), viewportHeight: Float(view.bounds.height)
            )
            guard depth > camera.camera.near, diameter >= StarMapProjection.minimumDiameter,
                  let point = project(marker.position), view.bounds.contains(point) else { return nil }
            let distance = hypot(point.x - tap.x, point.y - tap.y)
            return distance <= max(12, CGFloat(diameter) / 2) ? (star, distance) : nil
        }.min { $0.1 < $1.1 }
        if let star = candidate?.0 { onSelect?(star) }
    }

    private func clampPitch() {
        pitch = min(max(pitch, -.pi / 2 + 0.05), .pi / 2 - 0.05)
    }

    private static func disk(height: Float, color: UIColor) -> ModelEntity {
        var material = UnlitMaterial(color: color)
        material.triangleFillMode = .lines
        material.faceCulling = .none
        return ModelEntity(
            mesh: .generateCylinder(height: height, radius: 13_400),
            materials: [material]
        )
    }
}
#endif

#if os(iOS)
import Combine
import RealityKit
import SwiftUI
import OSLog

/// Camera and selection around a GPU-rendered field of star billboards.
@MainActor
final class StarMapScene: NSObject {

    private weak var view: ARView?
    private let root = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let milkyWay = Entity()
    private var starField: StarBillboardField?
    private var renderingFailed = false
    private var subscription: Cancellable?
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

    func attach(to view: ARView) {
        self.view = view
        view.scene.addAnchor(root)
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
        guard let view else { return }
        if active, subscription == nil {
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                // RealityKit delivers scene updates on the main thread.
                MainActor.assumeIsolated {
                    self?.tick(deltaTime: Float(event.deltaTime))
                }
            }
        } else if !active {
            subscription?.cancel()
            subscription = nil
        }
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
                  let point = view.project(marker.position), view.bounds.contains(point) else { return nil }
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

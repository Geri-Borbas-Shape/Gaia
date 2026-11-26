#if os(iOS)
import Combine
import RealityKit
import SwiftUI

/// Adapts Stars' entity hierarchy, camera controls, wireframes and screen-size markers to Gaia.
@MainActor
final class StarMapScene: NSObject {

    private weak var view: ARView?
    private let root = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let milkyWay = Entity()
    private let starsByID: [Int64: Star]
    private var markers: [ModelEntity] = []
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
        starsByID = Dictionary(uniqueKeysWithValues: stars.map { ($0.id, $0) })
        super.init()

        camera.camera = PerspectiveCameraComponent(near: 0.01, far: 200_000, fieldOfViewInDegrees: 50)
        root.addChild(camera)

        let mesh = MeshResource.generateSphere(radius: 1)
        for star in stars {
            let marker = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: UIColor(star.color))])
            marker.position = star.scenePosition
            marker.name = String(star.id)
            markers.append(marker)
            root.addChild(marker)
        }
        let sun = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .yellow)])
        sun.name = "Sun"
        markers.append(sun)
        root.addChild(sun)

        milkyWay.position = StarMapOptions.Focus.galacticCenter.center
        milkyWay.addChild(Self.disk(height: 335, color: UIColor(white: 0.6, alpha: 1)))
        milkyWay.addChild(Self.disk(height: 2_600, color: UIColor(white: 0.35, alpha: 1)))
        root.addChild(milkyWay)
        positionCamera()
    }

    func attach(to view: ARView) {
        self.view = view
        view.scene.addAnchor(root)
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
        milkyWay.isEnabled = next.showsMilkyWay && next.focus == .galacticCenter
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
        let worldToCamera = simd_inverse(camera.transform.matrix)
        for marker in markers {
            let isSun = marker.name == "Sun"
            let diameter = Float(options.markerSize) * (isSun ? 2 : 1)
            let position = marker.position
            let depth = -(worldToCamera * SIMD4(position.x, position.y, position.z, 1)).z
            marker.isEnabled = depth > camera.camera.near
            let radius: Float
            if options.constantScreenSize || isSun {
                radius = StarMapProjection.markerRadius(
                    diameter: diameter,
                    depth: depth,
                    fieldOfView: Float(options.fieldOfView),
                    viewportHeight: Float(view.bounds.height)
                )
            } else {
                radius = Float(options.markerSize) * 0.015
            }
            marker.scale = SIMD3(repeating: radius)
        }
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
        // A screen-space hit area keeps small markers tappable at both astronomical scales.
        let candidate = markers.compactMap { marker -> (ModelEntity, CGFloat)? in
            guard marker.isEnabled,
                  let point = view.project(marker.position), view.bounds.contains(point) else { return nil }
            let distance = hypot(point.x - tap.x, point.y - tap.y)
            return distance <= 22 ? (marker, distance) : nil
        }.min { $0.1 < $1.1 }
        if let marker = candidate?.0, let id = Int64(marker.name), let star = starsByID[id] {
            onSelect?(star)
        }
    }

    private func clampPitch() {
        pitch = min(max(pitch, -.pi / 2 + 0.05), .pi / 2 - 0.05)
    }

    private static func disk(height: Float, color: UIColor) -> Entity {
        let disk = Entity()
        let mesh = MeshResource.generateBox(size: 1)
        let material = UnlitMaterial(color: color)
        let segments = 64
        let radius: Float = 13_400

        func point(_ index: Int, _ y: Float) -> SIMD3<Float> {
            let angle = Float(index) / Float(segments) * 2 * .pi
            return SIMD3(radius * cos(angle), y, radius * sin(angle))
        }

        func line(from start: SIMD3<Float>, to end: SIMD3<Float>) {
            let line = ModelEntity(mesh: mesh, materials: [material])
            line.position = (start + end) / 2
            line.scale = SIMD3(100, simd_distance(start, end), 100)
            line.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(end - start))
            disk.addChild(line)
        }

        // Explicit edges work on iOS 17 and avoid the cylinder's triangulation diagonals.
        for index in 0..<segments {
            for y in [-height / 2, height / 2] {
                line(from: point(index, y), to: point(index + 1, y))
            }
            if index.isMultiple(of: 8) {
                line(from: point(index, -height / 2), to: point(index, height / 2))
            }
        }
        return disk
    }
}
#endif

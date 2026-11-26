#if os(iOS)
import MetalKit
import RealityKit
import SwiftUI
import OSLog

/// Camera and selection around a GPU-rendered field of star billboards.
@MainActor
final class StarMapScene: NSObject, MTKViewDelegate {

    private weak var view: MTKView?
    private weak var selectionOverlay: StarSelectionOverlay?
    private var selectedIndex: Int?
    private var visibilityPolicy: StarVisibility?
    private var visibleFrame = StarVisibility.Frame()
    private var lastCamera: simd_float4x4?
    private var lastViewport = SIMD2<Float>.zero
    private var lastMarkerSize: Double = 0
    private var lastFieldOfView: Double = 0
    private var reportedCount = -1
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
    var onOpenDetails: ((Star) -> Void)?
    var onVisibleCountChange: ((Int) -> Void)?

    init(stars: [Star]) {
        super.init()

        camera.camera = PerspectiveCameraComponent(
            near: 0.01,
            far: 2_000_000,
            fieldOfViewInDegrees: 50,
            fieldOfViewOrientation: .vertical
        )
        root.addChild(camera)

        do {
            let field = try StarBillboardField(stars: stars)
            starField = field
            visibilityPolicy = StarVisibility(sources: field.markers.map { .init(position: $0.position, radius: $0.radius) })
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

    func attach(to canvas: StarMapCanvas) {
        let view = canvas.metalView
        self.view = view
        selectionOverlay = canvas.selection
        canvas.selection.onOpenDetails = { [weak self] in
            guard let self, let index = self.selectedIndex, let star = self.starField?.markers[index].star else { return }
            self.onOpenDetails?(star)
        }
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
            selectedIndex = nil
            selectionOverlay?.isHidden = true
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

    private func tick(deltaTime: Float) {
        let blend: Float = reduceMotion ? 1 : 1 - exp(-min(deltaTime, 0.1) * 8)
        center += (options.focus.center - center) * blend
        orbitDistance += (targetDistance - orbitDistance) * blend
        positionCamera()
        updateMarkers()
    }

    private func positionCamera() {
        let direction = SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
        if let view, let policy = visibilityPolicy {
            let safeDistance = policy.cameraDistance(center: center, direction: direction, requested: orbitDistance,
                viewport: SIMD2(Float(view.bounds.width), Float(view.bounds.height)), fieldOfView: Float(options.fieldOfView))
            if safeDistance > orbitDistance {
                orbitDistance = safeDistance
                if simd_distance(center, options.focus.center) < 0.01 { targetDistance = max(targetDistance, safeDistance) }
            }
        }
        camera.look(at: center, from: center + direction * orbitDistance, relativeTo: nil)
    }

    private func updateMarkers() {
        guard let view, view.bounds.height > 0, let policy = visibilityPolicy else { return }
        let worldToView = simd_inverse(camera.transform.matrix)
        let viewport = SIMD2(Float(view.bounds.width), Float(view.bounds.height))
        if lastCamera != worldToView || lastViewport != viewport || lastMarkerSize != options.markerSize
            || lastFieldOfView != options.fieldOfView {
            visibleFrame = policy.frame(worldToView: worldToView, viewport: viewport,
                                        fieldOfView: Float(options.fieldOfView), markerSize: Float(options.markerSize))
            lastCamera = worldToView
            lastViewport = viewport
            lastMarkerSize = options.markerSize
            lastFieldOfView = options.fieldOfView
        }
        starField?.update(markerSize: Float(options.markerSize), viewportHeight: viewport.y, visibility: visibleFrame)
        starField?.glowPass.update(worldToView: worldToView, markerSize: Float(options.markerSize),
                                  viewportHeight: viewport.y, glow: options.glow, visibility: visibleFrame)
        if reportedCount != visibleFrame.stars.count {
            reportedCount = visibleFrame.stars.count
            view.accessibilityValue = "\(reportedCount) stars shown"
            onVisibleCountChange?(reportedCount)
        }
        updateSelection()
    }

    private func updateSelection() {
        guard let index = selectedIndex, let projected = visibleFrame.stars.first(where: { $0.index == index }),
              let star = starField?.markers[index].star else {
            selectionOverlay?.isHidden = true
            return
        }
        selectionOverlay?.show(star: star, point: projected.point, diameter: visibleFrame.displayedDiameter(projected))
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
        let location = gesture.location(in: view)
        let tap = SIMD2(Float(location.x), Float(location.y))
        // Use exactly the projected candidates and sizes chosen for the rendered frame.
        let candidate = visibleFrame.stars.filter { star in
            starField?.markers[star.index].star != nil
                && simd_distance(star.point, tap) <= max(12, visibleFrame.displayedDiameter(star) / 2)
        }.min {
            let first = simd_distance($0.point, tap), second = simd_distance($1.point, tap)
            // At Galactic scale many centres overlap; prefer the foreground core.
            return abs(first - second) < 1 ? $0.depth < $1.depth : first < second
        }
        selectedIndex = candidate?.index
        updateSelection()
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

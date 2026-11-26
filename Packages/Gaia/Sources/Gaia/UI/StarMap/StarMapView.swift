#if os(iOS)
import RealityKit
import SwiftUI

/// A non-AR RealityKit host for the interactive star map.
struct StarMapView: UIViewRepresentable {
    let stars: [Star]
    let options: StarMapOptions
    let isActive: Bool
    let reduceMotion: Bool
    let onSelect: (Star) -> Void

    func makeCoordinator() -> StarMapScene {
        StarMapScene(stars: stars)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.black)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Interactive 3D star map"
        view.accessibilityHint = "Use Map Controls to rotate the view, or the Catalogue tab to browse individual stars."
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.update(options: options, reduceMotion: reduceMotion)
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ view: ARView, coordinator: StarMapScene) {
        coordinator.setActive(false)
        view.scene.anchors.removeAll()
    }
}
#endif

#if os(iOS)
import RealityKit
import MetalKit
import SwiftUI

/// Metal host for the RealityKit scene followed by screen-blended star glow.
struct StarMapView: UIViewRepresentable {
    let stars: [Star]
    let options: StarMapOptions
    let isActive: Bool
    let reduceMotion: Bool
    let onSelect: (Star) -> Void

    func makeCoordinator() -> StarMapScene {
        StarMapScene(stars: stars)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Interactive 3D star map"
        view.accessibilityHint = "Use Map Controls to rotate the view, or the Catalogue tab to browse individual stars."
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.update(options: options, reduceMotion: reduceMotion)
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ view: MTKView, coordinator: StarMapScene) {
        coordinator.setActive(false)
        view.delegate = nil
    }
}
#endif

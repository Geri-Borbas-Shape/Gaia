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
    let onOpenDetails: (Star) -> Void
    let onVisibleCountChange: (Int) -> Void

    func makeCoordinator() -> StarMapScene {
        StarMapScene(stars: stars)
    }

    func makeUIView(context: Context) -> StarMapCanvas {
        let canvas = StarMapCanvas()
        let view = canvas.metalView
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Interactive 3D star map"
        view.accessibilityHint = "Use Map Controls to rotate the view, or the Catalogue tab to browse individual stars."
        context.coordinator.attach(to: canvas)
        return canvas
    }

    func updateUIView(_ view: StarMapCanvas, context: Context) {
        context.coordinator.onOpenDetails = onOpenDetails
        context.coordinator.onVisibleCountChange = onVisibleCountChange
        context.coordinator.update(options: options, reduceMotion: reduceMotion)
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ view: StarMapCanvas, coordinator: StarMapScene) {
        coordinator.setActive(false)
        view.metalView.delegate = nil
    }
}
#endif

import Foundation
import simd

/// One camera-based policy for both views, rendering, and hit testing.
struct StarVisibility {
    struct Source {
        var position: SIMD3<Float>
        var radius: Float
    }

    struct Projected {
        let index: Int
        let point: SIMD2<Float>
        let diameter: Float
        let depth: Float
    }

    struct Frame {
        var stars: [Projected] = []
        var threshold: Float = .infinity
        var scale: Float = 1

        func displayedDiameter(_ star: Projected) -> Float {
            min(star.diameter * scale, StarVisibility.maximumDiameter)
        }
    }

    static let defaultCount = 500
    static let minimumCount = 100
    static let maximumCount = 1_000
    static let maximumDiameter: Float = 24
    let sources: [Source]

    private static func boundedCount(_ count: Int) -> Int {
        min(max(count, minimumCount), maximumCount)
    }

    func frame(worldToView: simd_float4x4, viewport: SIMD2<Float>, fieldOfView: Float,
               markerSize: Float, targetCount: Int = Self.defaultCount) -> Frame {
        guard viewport.x > 0, viewport.y > 0 else { return Frame() }
        let targetCount = Self.boundedCount(targetCount)
        let projectionY = 1 / tan(fieldOfView * .pi / 360)
        let projectionX = projectionY * viewport.y / viewport.x
        let radiusScale = markerSize * StarMapProjection.parsecsPerSolarRadius
        var heap: [Projected] = []
        heap.reserveCapacity(targetCount)
        var nextDiameter: Float = 0

        // A bounded min-heap avoids sorting the whole catalogue on every camera move.
        for (index, source) in sources.enumerated() {
            let position = worldToView * SIMD4(source.position, 1)
            let depth = -position.z
            guard depth > 0.01, depth < 2_000_000 else { continue }
            let ndc = SIMD2(position.x * projectionX, position.y * projectionY) / depth
            guard abs(ndc.x) <= 1, abs(ndc.y) <= 1 else { continue }
            let diameter = source.radius * radiusScale * projectionY * viewport.y / depth
            guard diameter.isFinite, diameter > 0 else { continue }
            let candidate = Projected(index: index, point: (ndc * [1, -1] + 1) * viewport / 2,
                                      diameter: diameter, depth: depth)
            if heap.count < targetCount {
                heap.append(candidate)
                var child = heap.count - 1
                while child > 0 {
                    let parent = (child - 1) / 2
                    guard heap[child].diameter < heap[parent].diameter else { break }
                    heap.swapAt(child, parent)
                    child = parent
                }
            } else if diameter > heap[0].diameter {
                nextDiameter = max(nextDiameter, heap[0].diameter)
                heap[0] = candidate
                var parent = 0
                while parent * 2 + 1 < heap.count {
                    var child = parent * 2 + 1
                    if child + 1 < heap.count, heap[child + 1].diameter < heap[child].diameter { child += 1 }
                    guard heap[child].diameter < heap[parent].diameter else { break }
                    heap.swapAt(parent, child)
                    parent = child
                }
            } else {
                nextDiameter = max(nextDiameter, diameter)
            }
        }
        guard let smallest = heap.first else { return Frame() }
        // Midpoint keeps CPU/GPU rounding away from the cutoff. The screen-size floor
        // promotes distant markers, while the cutoff still excludes smaller stars.
        let threshold = min((smallest.diameter + nextDiameter) / 2, smallest.diameter * 0.99999)
        let scale = max(1, max(1.5, markerSize * 0.4) / smallest.diameter)
        return Frame(stars: heap, threshold: threshold, scale: scale)
    }

    /// Back away only if a requested camera would leave fewer than the chosen count in frame.
    /// This keeps zooming toward empty Galactic-centre space from losing the nearby sample.
    func cameraDistance(center: SIMD3<Float>, direction: SIMD3<Float>, requested: Float,
                        viewport: SIMD2<Float>, fieldOfView: Float, targetCount: Int = Self.defaultCount) -> Float {
        let targetCount = min(sources.count, Self.boundedCount(targetCount))
        guard targetCount > 0, viewport.x > 0, viewport.y > 0 else { return requested }
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), direction))
        let up = simd_cross(direction, right)
        let tangentY = tan(fieldOfView * .pi / 360)
        let tangentX = tangentY * viewport.x / viewport.y
        let side = simd_dot(center, right), vertical = simd_dot(center, up)
        let along = simd_dot(center, direction)
        func hasEnoughStars(_ distance: Float) -> Bool {
            var count = 0
            for source in sources {
                let relative = source.position - center
                let depth = distance - simd_dot(relative, direction)
                if depth > 0.01,
                   abs(simd_dot(relative, right)) <= depth * tangentX,
                   abs(simd_dot(relative, up)) <= depth * tangentY {
                    count += 1
                    if count >= targetCount { return true }
                }
            }
            return false
        }
        guard !hasEnoughStars(requested) else { return requested }
        let radius = sources.reduce(Float(0)) { max($0, simd_length($1.position)) }
        var lower = requested
        var upper = max(requested, max((abs(side) + radius) / tangentX,
                                       (abs(vertical) + radius) / tangentY) + radius - along)
        for _ in 0..<10 {
            let middle = (lower + upper) / 2
            if hasEnoughStars(middle) { upper = middle } else { lower = middle }
        }
        return upper + max(0.1, upper * 0.001)
    }
}

import Metal
import simd
import Testing
@testable import Gaia

private func renderGlow(_ stars: [StarGlowPass.Star], background: [UInt8] = [80, 120, 160, 255],
                        settings: StarGlowSettings = .init(), visibleIndices: [Int]? = nil) throws -> [UInt8] {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 64, height: 64, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.shaderRead, .renderTarget]
    let source = try #require(device.makeTexture(descriptor: descriptor))
    let target = try #require(device.makeTexture(descriptor: descriptor))
    let pixels = (0..<(64 * 64)).flatMap { _ in background }
    pixels.withUnsafeBytes {
        source.replace(region: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 64 * 4)
    }
    let pass = try StarGlowPass(stars: stars, device: device)
    if let visibleIndices { pass.setVisibleIndices(visibleIndices) }
    pass.update(worldToView: matrix_identity_float4x4, markerSize: 12, viewportHeight: 64, glow: settings)
    let projection = simd_float4x4([1, 0, 0, 0], [0, 1, 0, 0], [0, 0, -1, -1], [0, 0, -0.01, 0])
    let command = try #require(queue.makeCommandBuffer())
    try pass.encode(source: source, target: target, commandBuffer: command, projection: projection)
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed)
    var result = [UInt8](repeating: 0, count: pixels.count)
    result.withUnsafeMutableBytes {
        target.getBytes($0.baseAddress!, bytesPerRow: 64 * 4, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
    }
    return result
}

private let warmGlow = StarGlowPass.Star(positionRadius: [0, 0, -5, 2], color: [0.9, 0.3, 0.1, 1])
private let coolGlow = StarGlowPass.Star(positionRadius: [0, 0, -10, 4], color: [0.1, 0.5, 1, 1])

@Test func screenGlowOnlyBrightensAndPreservesAlpha() throws {
    let image = try renderGlow([warmGlow, coolGlow])
    let base: [UInt8] = [80, 120, 160, 255]
    for index in image.indices { #expect(image[index] >= base[index % 4]) }
    let centre = (32 * 64 + 32) * 4
    #expect(image[centre] > 80 && image[centre + 2] > 160)
    #expect(image[centre + 3] == 255)
}

@Test func screenGlowMatchesScreenEquationAndIsOrderIndependent() throws {
    let first = try renderGlow([warmGlow, coolGlow])
    let reversed = try renderGlow([coolGlow, warmGlow])
    for index in first.indices { #expect(abs(Int(first[index]) - Int(reversed[index])) <= 1) }
    let centre = (32 * 64 + 32) * 4
    let base: [Float] = [80, 120, 160]
    for channel in 0..<3 {
        let a = warmGlow.color[channel] * 0.16
        let b = coolGlow.color[channel] * 0.16
        let expected = (1 - (1 - base[channel] / 255) * (1 - a) * (1 - b)) * 255
        #expect(abs(Float(first[centre + channel]) - expected) <= 2)
    }
}

@Test func unresolvedAndBehindCameraGlowsLeaveSceneUntouched() throws {
    let small = StarGlowPass.Star(positionRadius: [0, 0, -5, 0.001], color: [1, 1, 1, 1])
    let behind = StarGlowPass.Star(positionRadius: [0, 0, 5, 100], color: [1, 1, 1, 1])
    let image = try renderGlow([small, behind])
    let base: [UInt8] = [80, 120, 160, 255]
    #expect(image == (0..<(64 * 64)).flatMap { _ in base })
}

@Test func glowControlsChangeExtentBrightnessAndFalloff() throws {
    let background: [UInt8] = [0, 0, 0, 255]
    let off = try renderGlow([warmGlow], background: background, settings: .init(intensity: 0))
    #expect(off == (0..<(64 * 64)).flatMap { _ in background })

    let normal = try renderGlow([warmGlow], background: background)
    let bright = try renderGlow([warmGlow], background: background, settings: .init(intensity: 1))
    let wide = try renderGlow([warmGlow], background: background, settings: .init(size: 3))
    let soft = try renderGlow([warmGlow], background: background, settings: .init(bias: 0.25))
    let tight = try renderGlow([warmGlow], background: background, settings: .init(bias: 4))
    let centre = (32 * 64 + 32) * 4
    let wing = (32 * 64 + 35) * 4
    #expect(bright[centre] > normal[centre])
    #expect(wide[wing] > normal[wing])
    #expect(soft[wing] > normal[wing] && normal[wing] > tight[wing])
    #expect(soft[centre] == tight[centre]) // Bias preserves peak intensity.
}

@Test func onlyChosenStarsContributeToTheGlowPass() throws {
    let selected = try renderGlow([warmGlow, coolGlow], visibleIndices: [1])
    #expect(selected == (try renderGlow([coolGlow])))
    let empty = try renderGlow([warmGlow, coolGlow], visibleIndices: [])
    #expect(empty == (0..<(64 * 64)).flatMap { _ in [UInt8(80), 120, 160, 255] })
}

@Test func glowPassSupportsTheFullThousandStarBudget() throws {
    var stars = Array(repeating: StarGlowPass.Star(positionRadius: [0, 0, -5, 2], color: [0, 0, 0, 1]), count: 1_000)
    stars[999] = warmGlow
    let image = try renderGlow(stars, visibleIndices: Array(0..<1_000))
    #expect(image == (try renderGlow([warmGlow])))
}

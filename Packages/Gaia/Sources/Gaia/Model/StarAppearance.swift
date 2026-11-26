import Foundation

/// Display estimates, not a replacement for the catalogue's astrophysical measurements.
struct StarAppearance: Sendable {
    let temperature: Double?
    let radius: Double
    let hasMeasuredRadius: Bool

    init(star: Star) {
        temperature = Self.valid(star.effectiveTemperature, in: 500...100_000)
            ?? star.colorIndex.flatMap(Self.temperatureFromColor)
        if let measured = Self.valid(star.radiusInSolarRadii, in: 0.001...3_000) {
            radius = measured
            hasMeasuredRadius = true
        } else {
            radius = Self.estimatedRadius(absoluteMagnitude: star.absoluteMagnitude, temperature: temperature)
            hasMeasuredRadius = false
        }
    }

    /// Broad temperature class only; luminosity class and composition cannot be inferred here.
    var temperatureClass: String {
        guard let temperature else { return "Unknown" }
        switch temperature {
        case 30_000...: return "O"
        case 10_000...: return "B"
        case 7_500...: return "A"
        case 6_000...: return "F"
        case 5_200...: return "G"
        case 3_700...: return "K"
        default: return "M"
        }
    }

    var color: SIMD3<Float> { Self.color(temperature: temperature) }

    /// Smooth illustrative blackbody palette. Missing photometry stays neutral.
    static func color(temperature: Double?) -> SIMD3<Float> {
        guard let temperature, temperature.isFinite else { return SIMD3(repeating: 0.65) }
        let stops: [(Double, SIMD3<Float>)] = [
            (2_000, [1, 0.38, 0.16]), (3_000, [1, 0.59, 0.35]),
            (4_500, [1, 0.79, 0.59]), (5_772, [1, 0.94, 0.82]),
            (7_500, [0.88, 0.93, 1]), (10_000, [0.71, 0.82, 1]),
            (30_000, [0.56, 0.70, 1])
        ]
        for index in 1..<stops.count where temperature < stops[index].0 {
            let lower = stops[index - 1], upper = stops[index]
            let blend = Float(max(0, (temperature - lower.0) / (upper.0 - lower.0)))
            return lower.1 + (upper.1 - lower.1) * blend
        }
        return stops.last!.1
    }

    /// Coarse BP−RP lookup for sources without a GSP-Phot temperature; no extinction correction.
    static func temperatureFromColor(_ color: Double) -> Double? {
        guard color.isFinite else { return nil }
        let stops = [(-0.5, 30_000.0), (0, 10_000), (0.5, 7_500), (0.82, 5_772),
                     (1.5, 4_000), (2.5, 3_200), (4, 2_500), (5, 2_000)]
        for index in 1..<stops.count where color < stops[index].0 {
            let lower = stops[index - 1], upper = stops[index]
            let blend = max(0, (color - lower.0) / (upper.0 - lower.0))
            return lower.1 + (upper.1 - lower.1) * blend
        }
        return stops.last!.1
    }

    /// Rough photometric radius: compare G-band luminosity and blackbody surface brightness
    /// at 673 nm with the Sun (M_G ≈ 4.67, T = 5772 K). This is not a bolometric fit.
    static func estimatedRadius(absoluteMagnitude: Double?, temperature: Double?) -> Double {
        guard let magnitude = absoluteMagnitude, magnitude.isFinite,
              let temperature = valid(temperature, in: 500...100_000) else { return 1 }
        let luminosityRatio = pow(10, -0.4 * (min(max(magnitude, -10), 30) - 4.67))
        let planckExponent = 0.01438776877 / 673e-9
        let surfaceBrightnessRatio = expm1(planckExponent / temperature) / expm1(planckExponent / 5_772)
        return min(max(sqrt(luminosityRatio * surfaceBrightnessRatio), 0.005), 1_000)
    }

    private static func valid(_ value: Double?, in range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }
}

extension Star {
    var appearance: StarAppearance { StarAppearance(star: self) }
}

import Foundation

/// A Milky Way star from Gaia DR3 (epoch J2016.0).
public struct Star: Identifiable, Hashable, Sendable {

    /// Gaia DR3 source identifier.
    public let id: Int64
    public let name: String?

    /// Degrees (ICRS).
    public let rightAscension: Double
    public let declination: Double

    /// Degrees, measured from the galactic centre along the galactic plane.
    public let galacticLongitude: Double
    public let galacticLatitude: Double

    /// Milliarcseconds.
    public let parallax: Double
    public let parallaxError: Double

    /// Milliarcseconds per year, in right ascension and declination.
    public let properMotion: SIMD2<Double>

    /// Apparent magnitude in the Gaia G band.
    public let magnitude: Double?

    /// Gaia BP−RP colour index.
    public let colorIndex: Double?

    /// Kelvin.
    public let effectiveTemperature: Double?

    /// Kilometres per second, positive when receding.
    public let radialVelocity: Double?

    /// GSP-Phot radius in solar radii, when available in Gaia DR3.
    public var radiusInSolarRadii: Double? = nil
}

// MARK: - Derived values

public extension Star {

    static let lightYearsPerParsec = 3.26156

    /// Kilometres per second per (arcsecond per year × parsec).
    static let transverseVelocityFactor = 4.74047

    var title: String {
        name ?? "Gaia DR3 \(id)"
    }

    var distanceInParsecs: Double {
        1000 / parallax
    }

    /// One-sigma distance uncertainty from the parallax error.
    var distanceErrorInParsecs: Double {
        1000 * parallaxError / (parallax * parallax)
    }

    var distanceInLightYears: Double {
        distanceInParsecs * Self.lightYearsPerParsec
    }

    /// Absolute G magnitude from the distance modulus.
    var absoluteMagnitude: Double? {
        magnitude.map { $0 - 5 * (log10(distanceInParsecs) - 1) }
    }

    /// Milliarcseconds per year.
    var totalProperMotion: Double {
        (properMotion.x * properMotion.x + properMotion.y * properMotion.y).squareRoot()
    }

    /// Kilometres per second across the line of sight.
    var transverseVelocity: Double {
        Self.transverseVelocityFactor * totalProperMotion / parallax
    }
}

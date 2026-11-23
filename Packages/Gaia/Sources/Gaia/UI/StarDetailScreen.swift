import SwiftUI

/// Gaia DR3 measurements and derived values of one star.
struct StarDetailScreen: View {

    let star: Star

    var body: some View {
        List {
            Section("Derived") {
                row("Distance", star.distanceInLightYears, unit: "ly")
                row("Distance error", star.distanceErrorInParsecs * Star.lightYearsPerParsec, unit: "ly", digits: UI.positionDigits)
                row("Absolute magnitude", star.absoluteMagnitude)
                row("Transverse velocity", star.transverseVelocity, unit: "km/s")
            }
            Section("Position") {
                row("Right ascension", star.rightAscension, unit: "°", digits: UI.positionDigits)
                row("Declination", star.declination, unit: "°", digits: UI.positionDigits)
                row("Galactic longitude", star.galacticLongitude, unit: "°", digits: UI.positionDigits)
                row("Galactic latitude", star.galacticLatitude, unit: "°", digits: UI.positionDigits)
            }
            Section("Gaia DR3") {
                LabeledContent("Source ID", value: String(star.id))
                row("Parallax", star.parallax, unit: "mas")
                row("Proper motion", star.totalProperMotion, unit: "mas/yr")
                row("Magnitude (G)", star.magnitude)
                row("Colour (BP−RP)", star.colorIndex)
                row("Temperature", star.effectiveTemperature, unit: "K", digits: 0)
                row("Radial velocity", star.radialVelocity, unit: "km/s")
            }
        }
        .navigationTitle(star.title)
    }

    private func row(_ title: String, _ value: Double?, unit: String = "", digits: Int = UI.digits) -> some View {
        LabeledContent(title, value: value.map {
            "\($0.formatted(.number.precision(.fractionLength(digits)))) \(unit)".trimmingCharacters(in: .whitespaces)
        } ?? UI.missing)
    }
}

// MARK: - UI Constants

extension StarDetailScreen {
    enum UI {
        static let digits = 2
        static let positionDigits = 4
        static let missing = "—"
    }
}

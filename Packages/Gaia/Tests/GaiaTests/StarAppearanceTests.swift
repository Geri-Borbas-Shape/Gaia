import Foundation
import Testing
@testable import Gaia

private func sampleStar(temperature: Double? = nil, color: Double? = nil, radius: Double? = nil,
                        magnitude: Double? = nil) -> Star {
    Star(id: 1, name: nil, rightAscension: 0, declination: 0, galacticLongitude: 0, galacticLatitude: 0,
         parallax: 100, parallaxError: 0.1, properMotion: .zero, magnitude: magnitude,
         colorIndex: color, effectiveTemperature: temperature, radialVelocity: nil, radiusInSolarRadii: radius)
}

@Test func catalogueRadiusAndTemperatureTakePriority() {
    let appearance = sampleStar(temperature: 15_000, color: 3, radius: 5).appearance
    #expect(appearance.radius == 5)
    #expect(appearance.hasMeasuredRadius)
    #expect(appearance.temperature == 15_000)
    #expect(appearance.temperatureClass == "B")
    #expect(appearance.color.z > appearance.color.x)
}

@Test func missingMeasurementsUseMarkedEstimates() {
    let cool = sampleStar(color: 3, magnitude: 12).appearance
    #expect(cool.temperatureClass == "M")
    #expect(!cool.hasMeasuredRadius)
    #expect(cool.radius > 0 && cool.radius < 1)
    #expect(cool.color.x > cool.color.z)
    let unknown = sampleStar().appearance
    #expect(unknown.temperature == nil)
    #expect(unknown.temperatureClass == "Unknown")
    #expect(unknown.color.x == unknown.color.z)
    #expect(unknown.radius == 1)
}

@Test func invalidMeasurementsCannotProduceInvalidGeometry() {
    let appearance = sampleStar(temperature: .nan, color: .infinity, radius: -.infinity, magnitude: .nan).appearance
    #expect(appearance.radius.isFinite && appearance.radius > 0)
    #expect(!appearance.hasMeasuredRadius)
    #expect(appearance.temperature == nil)
}

@Test func photometricEstimateDistinguishesWhiteDwarfsAndGiants() {
    let dwarf = StarAppearance.estimatedRadius(absoluteMagnitude: 12, temperature: 20_000)
    let sun = StarAppearance.estimatedRadius(absoluteMagnitude: 4.67, temperature: 5_772)
    let giant = StarAppearance.estimatedRadius(absoluteMagnitude: 0, temperature: 4_500)
    #expect(dwarf < 0.1)
    #expect(abs(sun - 1) < 0.0001)
    #expect(giant > 10)
}

@Test func colorTransitionsAreContinuousAndTemperatureOrdered() {
    let cool = StarAppearance.color(temperature: 3_000)
    let sun = StarAppearance.color(temperature: 5_772)
    let hot = StarAppearance.color(temperature: 20_000)
    #expect(cool.z < sun.z && sun.z < hot.z)
    let lower = StarAppearance.color(temperature: 5_771.99)
    let upper = StarAppearance.color(temperature: 5_772.01)
    #expect(abs(lower.y - upper.y) < 0.001)
}

@Test func smallStarsBecomeVisibleOnlyWhenProjectedSizeAllows() {
    let radius = StarMapProjection.worldRadius(solarRadius: 0.15, markerSize: 5)
    let distant = StarMapProjection.projectedDiameter(radius: radius, depth: 50, fieldOfView: 50, viewportHeight: 600)
    let close = StarMapProjection.projectedDiameter(radius: radius, depth: 5, fieldOfView: 50, viewportHeight: 600)
    #expect(distant < StarMapProjection.minimumDiameter)
    #expect(close >= StarMapProjection.minimumDiameter)
    #expect(abs(close / distant - 10) < 0.001)
    #expect(StarMapProjection.projectedDiameter(radius: radius, depth: -5, fieldOfView: 50, viewportHeight: 600) == 0)
    #expect(StarMapProjection.projectedDiameter(radius: .nan, depth: 5, fieldOfView: 50, viewportHeight: 600) == 0)
}

@Test func markerSizePreservesRadiusRatios() {
    let dwarf = StarMapProjection.worldRadius(solarRadius: 0.1, markerSize: 5)
    let sun = StarMapProjection.worldRadius(solarRadius: 1, markerSize: 5)
    let giant = StarMapProjection.worldRadius(solarRadius: 10, markerSize: 5)
    #expect(abs(sun / dwarf - 10) < 0.001)
    #expect(abs(giant / sun - 10) < 0.001)
}

@Test func parserAcceptsLegacyAndExpandedCatalogues() throws {
    let header = "source_id,ra,dec,l,b,parallax,parallax_error,pmra,pmdec,phot_g_mean_mag,bp_rp,teff_gspphot,radial_velocity"
    let row = "1,0,0,0,0,100,0.1,0,0,4.67,0.82,5772,0"
    let legacy = try #require(CatalogParser().stars(from: header + "\n" + row).first)
    #expect(legacy.radiusInSolarRadii == nil)
    let expanded = try #require(CatalogParser().stars(from: header + ",radius_gspphot\n" + row + ",1").first)
    #expect(expanded.radiusInSolarRadii == 1)
}

import Testing
@testable import Gaia

@Test func bundledCatalogueLoads() throws {
    let store = try StarRepository.bundled()
    #expect(store.stars.count == 315)
}

@Test func nearestStarIsProximaCentauri() throws {
    let nearest = try #require(try StarRepository.bundled().stars().first)
    #expect(nearest.id == 5853498713190525696)
    #expect(nearest.name == "Proxima Centauri")
    #expect(abs(nearest.distanceInLightYears - 4.2465) < 0.001)
}

@Test func derivedValuesOfBarnardsStar() throws {
    let store = try StarRepository.bundled()
    let barnard = try #require(store.stars.first { $0.id == 4472832130942575872 })
    #expect(abs(barnard.totalProperMotion - 10393.35) < 0.01)
    #expect(abs(barnard.transverseVelocity - 90.08) < 0.01)
    #expect(abs(barnard.distanceErrorInParsecs - 0.000134) < 0.000001)
    #expect(abs(try #require(barnard.absoluteMagnitude) - 11.88) < 0.01)
}

@Test func photometryIsOptional() throws {
    let store = try StarRepository.bundled()
    #expect(store.stars.filter { $0.magnitude == nil }.count == 2)
    #expect(store.stars(sortedBy: .brightness).last?.magnitude == nil)
}

@Test func queriesFilterAndSort() throws {
    let store = try StarRepository.bundled()
    #expect(store.stars(matching: "sirius").map(\.name) == ["Sirius B"])
    #expect(store.stars(matching: "4472832130942575872").map(\.name) == ["Barnard's Star"])
    #expect(store.stars(within: 2).map(\.name) == ["Proxima Centauri", "Barnard's Star"])
    #expect(store.stars(sortedBy: .name).first?.name == "61 Cygni A")
    #expect(store.stars().allSatisfy { $0.distanceInParsecs <= 8 })
    #expect(store.stars().count < store.stars.count)
}

@Test func missingColumnThrows() {
    #expect(throws: CatalogParser.ParseError.missingColumn("dec")) {
        try CatalogParser().stars(from: "source_id,ra\n1,2")
    }
}

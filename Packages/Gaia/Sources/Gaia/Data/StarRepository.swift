import Foundation

/// Holds the parsed catalogue and answers list queries.
public struct StarRepository: Sendable {

    public enum Sort: String, CaseIterable, Identifiable, Sendable {
        case distance = "Distance"
        case brightness = "Brightness"
        case name = "Name"

        public var id: Self { self }
    }

    public enum LoadError: Error {
        case missingResource
    }

    /// Parsecs.
    public static let defaultMaximumDistance = 8.0

    public let stars: [Star]
    public let maximumDistance: Double

    public init(stars: [Star] = []) {
        self.stars = stars
        maximumDistance = stars.lazy.map(\.distanceInParsecs).max() ?? 0
    }

    /// Loads `nearby_stars.csv` from the package bundle.
    public static func bundled() throws -> StarRepository {
        try bundledResult.get()
    }

    /// The bundled file is immutable; share one parsed sample between the map and list.
    private static let bundledResult: Result<StarRepository, Error> = Result {
        guard let url = Bundle.module.url(forResource: "nearby_stars", withExtension: "csv") else {
            throw LoadError.missingResource
        }
        let csv = try String(contentsOf: url, encoding: .utf8)
        return StarRepository(stars: try CatalogParser().stars(from: csv))
    }

    public func stars(
        matching searchText: String = "",
        within maximumDistance: Double = defaultMaximumDistance,
        sortedBy sort: Sort = .distance
    ) -> [Star] {
        stars
            .filter { $0.distanceInParsecs <= maximumDistance }
            .filter { searchText.isEmpty || $0.matches(searchText) }
            .sorted(by: sort.areInIncreasingOrder)
    }
}

// MARK: - Sorting and search

extension StarRepository.Sort {

    var areInIncreasingOrder: (Star, Star) -> Bool {
        switch self {
        case .distance: { $0.distanceInParsecs < $1.distanceInParsecs }
        case .brightness: { ($0.magnitude ?? .infinity) < ($1.magnitude ?? .infinity) }
        case .name: { ($0.name ?? "~", $0.id) < ($1.name ?? "~", $1.id) }
        }
    }
}

extension Star {

    func matches(_ searchText: String) -> Bool {
        title.localizedCaseInsensitiveContains(searchText) || String(id).contains(searchText)
    }
}

import Foundation
import Observation
import OSLog

/// State of the star list: the loaded catalogue, the search text and the sort order.
@MainActor
@Observable
public final class StarListViewModel {

    public var searchText = ""
    public var sort = CatalogStore.Sort.distance
    public private(set) var hasFailed = false

    private var store = CatalogStore()

    public init() {}

    public var stars: [Star] {
        store.stars(matching: searchText, sortedBy: sort)
    }

    public func load() {
        do {
            store = try CatalogStore.bundled()
            hasFailed = false
        } catch {
            Logger.catalog.error("Catalogue failed to load: \(error, privacy: .public)")
            hasFailed = true
        }
    }
}

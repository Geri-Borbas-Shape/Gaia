import Foundation
import OSLog

/// Parses the CSV exported from the ESA Gaia archive into stars.
public struct CatalogParser: Sendable {

    public enum ParseError: Error, Equatable {
        case missingColumn(String)
    }

    enum Column: String, CaseIterable {
        case source_id, ra, dec, l, b, parallax, parallax_error, pmra, pmdec
        case phot_g_mean_mag, bp_rp, teff_gspphot, radial_velocity
        case radius_gspphot
    }

    public init() {}

    public func stars(from csv: String) throws -> [Star] {

        var lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }

        // Header.
        let header = Self.fields(of: lines.removeFirst())
        let indices = Dictionary(header.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        for column in Column.allCases where column != .radius_gspphot && indices[column.rawValue] == nil {
            throw ParseError.missingColumn(column.rawValue)
        }

        // Rows.
        return lines.compactMap { line in
            let row = Row(fields: Self.fields(of: line), indices: indices)
            guard let star = star(from: row) else {
                Logger.catalog.warning("Skipped row: \(line, privacy: .public)")
                return nil
            }
            return star
        }
    }
}

// MARK: - Rows

extension CatalogParser {

    struct Row {
        let fields: [String]
        let indices: [String: Int]

        func string(_ column: Column) -> String? {
            guard let index = indices[column.rawValue], index < fields.count, !fields[index].isEmpty else { return nil }
            return fields[index]
        }

        func double(_ column: Column) -> Double? {
            guard let value = string(column).flatMap(Double.init), value.isFinite else { return nil }
            return value
        }
    }

    static func fields(of line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }

    /// Position, parallax and proper motion are required, photometry and velocities are optional.
    func star(from row: Row) -> Star? {
        guard
            let id = row.string(.source_id).flatMap(Int64.init),
            let rightAscension = row.double(.ra),
            let declination = row.double(.dec),
            let galacticLongitude = row.double(.l),
            let galacticLatitude = row.double(.b),
            let parallax = row.double(.parallax),
            let parallaxError = row.double(.parallax_error),
            let properMotionRightAscension = row.double(.pmra),
            let properMotionDeclination = row.double(.pmdec),
            parallax > 0
        else { return nil }

        return Star(
            id: id,
            name: StarNames.bySourceID[id],
            rightAscension: rightAscension,
            declination: declination,
            galacticLongitude: galacticLongitude,
            galacticLatitude: galacticLatitude,
            parallax: parallax,
            parallaxError: parallaxError,
            properMotion: SIMD2<Double>(properMotionRightAscension, properMotionDeclination),
            magnitude: row.double(.phot_g_mean_mag),
            colorIndex: row.double(.bp_rp),
            effectiveTemperature: row.double(.teff_gspphot),
            radialVelocity: row.double(.radial_velocity),
            radiusInSolarRadii: row.double(.radius_gspphot)
        )
    }
}

// MARK: - Logging

extension Logger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.Gaia"
    static let catalog = Logger(subsystem: subsystem, category: "Catalog")
}

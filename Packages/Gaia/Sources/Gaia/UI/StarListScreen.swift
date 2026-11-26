import SwiftUI

/// Searchable, sortable list of the nearby stars.
public struct StarListScreen: View {

    @State private var viewModel = StarListViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            List(viewModel.stars) { star in
                NavigationLink(value: star) {
                    StarRow(star: star)
                }
            }
            .overlay {
                if viewModel.hasFailed {
                    ContentUnavailableView("Catalogue unavailable", systemImage: "sparkles")
                }
            }
            .navigationTitle("Nearby Stars")
            .navigationDestination(for: Star.self) { star in
                StarDetailScreen(star: star)
            }
            .searchable(text: $viewModel.searchText, prompt: "Name or Gaia source ID")
            .toolbar {
                Picker("Sort", selection: $viewModel.sort) {
                    ForEach(StarRepository.Sort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

/// One star in the list: colour dot, title and distance.
struct StarRow: View {

    let star: Star

    var body: some View {
        HStack(spacing: UI.spacing) {
            Circle()
                .fill(star.color)
                .frame(width: UI.dotSize, height: UI.dotSize)
            VStack(alignment: .leading) {
                Text(star.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(star.magnitude.map { "G \($0.formatted(.number.precision(.fractionLength(UI.magnitudeDigits))))" } ?? "No magnitude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(star.distanceInLightYears.formatted(.number.precision(.fractionLength(UI.distanceDigits)))) ly")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - UI Constants

extension StarRow {
    enum UI {
        static let spacing = 12.0
        static let dotSize = 14.0
        static let distanceDigits = 2
        static let magnitudeDigits = 2
    }
}

#Preview {
    StarListScreen()
}

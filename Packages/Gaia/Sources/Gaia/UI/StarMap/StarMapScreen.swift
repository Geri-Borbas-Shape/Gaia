#if os(iOS)
import SwiftUI

struct StarMapScreen: View {

    @State private var catalogue = StarListViewModel()
    @State private var options = StarMapOptions()
    @State private var selectedStar: Star?
    @State private var showsControls = false
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                if catalogue.hasFailed {
                    ContentUnavailableView {
                        Label("Catalogue unavailable", systemImage: "sparkles")
                    } actions: {
                        Button("Retry") { Task { await catalogue.load() } }
                    }
                } else if catalogue.allStars.isEmpty {
                    ProgressView("Loading stars")
                } else {
                    StarMapView(
                        stars: catalogue.allStars,
                        options: options,
                        isActive: isVisible && scenePhase == .active && selectedStar == nil,
                        reduceMotion: reduceMotion,
                        onSelect: { selectedStar = $0 }
                    )
                    .accessibilityIdentifier("star-map")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    Picker("Orbit centre", selection: $options.focus) {
                        ForEach(StarMapOptions.Focus.allCases) { focus in
                            Text(focus.rawValue).tag(focus)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(options.focus == .sun
                         ? "\(catalogue.allStars.count.formatted()) stars within \(catalogue.catalogueRadius) pc · Sun at the centre"
                         : "Zoom in to resolve individual stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("map-catalogue-summary")
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .background(.black)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    HStack(spacing: 16) {
                        Label("Cool", systemImage: "circle.fill").foregroundStyle(.orange)
                        Label("Hot", systemImage: "circle.fill").foregroundStyle(.cyan)
                    }
                    Text("Drag to orbit · Pinch to zoom · Tap a star")
                        .foregroundStyle(.secondary)
                    Text("Sizes exaggerated · Zoom reveals smaller stars")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.black)
            }
            .navigationTitle("Nearby Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset view", systemImage: "arrow.counterclockwise") { options.reset() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Map controls", systemImage: "slider.horizontal.3") { showsControls = true }
                }
            }
            .sheet(isPresented: $showsControls) {
                StarMapControls(options: $options)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedStar) { star in
                StarMapDetail(star: star)
            }
            .task { await catalogue.load() }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        }
        .preferredColorScheme(.dark)
    }
}

private struct StarMapDetail: View {
    let star: Star
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StarDetailScreen(star: star)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    GaiaScreen()
}
#endif

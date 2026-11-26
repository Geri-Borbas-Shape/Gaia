import SwiftUI

/// The catalogue and its spatial view share the same bundled Gaia data.
public struct GaiaScreen: View {

    public init() {}

    public var body: some View {
        TabView {
            #if os(iOS)
            StarMapScreen()
                .tabItem { Label("3D Map", systemImage: "globe") }
            #endif

            StarListScreen()
                .tabItem { Label("Catalogue", systemImage: "list.bullet") }
        }
    }
}

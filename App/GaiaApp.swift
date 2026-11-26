import SwiftUI
import Gaia

/// App entry point, shows the 3D map and catalogue.
@main
struct GaiaApp: App {

    var body: some Scene {
        WindowGroup {
            GaiaScreen()
        }
    }
}

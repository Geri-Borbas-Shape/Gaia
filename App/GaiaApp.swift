import SwiftUI
import Gaia

/// App entry point, shows the star list.
@main
struct GaiaApp: App {

    var body: some Scene {
        WindowGroup {
            StarListScreen()
        }
    }
}

#if os(iOS)
import SwiftUI

struct StarMapControls: View {
    @Binding var options: StarMapOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera") {
                    LabeledContent("Field of view", value: "\(Int(options.fieldOfView))°")
                    Slider(value: $options.fieldOfView, in: 10...80, step: 1) {
                        Text("Field of view")
                    }
                    .accessibilityValue("\(Int(options.fieldOfView)) degrees")
                    HStack {
                        Button("Orbit left", systemImage: "arrow.left") { options.horizontalOrbit -= 1 }
                        Button("Orbit right", systemImage: "arrow.right") { options.horizontalOrbit += 1 }
                        Spacer()
                        Button("Orbit up", systemImage: "arrow.up") { options.verticalOrbit += 1 }
                        Button("Orbit down", systemImage: "arrow.down") { options.verticalOrbit -= 1 }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
                Section {
                    LabeledContent("Marker size", value: options.markerSize.formatted(.number.precision(.fractionLength(0))))
                    Slider(value: $options.markerSize, in: 2...12, step: 1) {
                        Text("Marker size")
                    }
                    Toggle("Milky Way wireframe", isOn: $options.showsMilkyWay)
                } footer: {
                    Text("Star sizes follow their radii, exaggerated for visibility. Zoom in to reveal smaller stars. Colours follow temperature; missing measurements are estimated. The Milky Way grid stays available in both views.")
                }
            }
            .navigationTitle("Map Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif

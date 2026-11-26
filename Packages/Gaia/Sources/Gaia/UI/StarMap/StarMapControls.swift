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
                    Toggle("Constant screen size", isOn: $options.constantScreenSize)
                    Toggle("Milky Way wireframe", isOn: $options.showsMilkyWay)
                        .disabled(options.focus != .galacticCenter)
                } footer: {
                    Text("Constant screen size keeps distant stars visible as you move. Turn it off for perspective-scaled spheres. Sizes do not represent stellar radii. The wireframe is available in the Milky Way view.")
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

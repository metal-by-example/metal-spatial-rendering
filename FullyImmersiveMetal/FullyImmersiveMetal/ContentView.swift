import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @Binding private var immersionStyle: any ImmersionStyle

    @State private var showImmersiveSpace = false
    @State private var useMixedImmersion = false
    @State private var passthroughCutoffAngle = 60.0

    private let rendererConfiguration: SRConfiguration

    init(_ immersionStyle: Binding<any ImmersionStyle>, _ rendererConfig: SRConfiguration) {
        _immersionStyle = immersionStyle
        rendererConfiguration = rendererConfig
    }

    var body: some View {
        VStack {
            Toggle(showImmersiveSpace ? "Exit Immersive Space" : "Launch Immersive Space", isOn: $showImmersiveSpace)
                .toggleStyle(.button)
                .padding()
            if #available(visionOS 2, *) {
                VStack {
                    Toggle(useMixedImmersion ? "Use Full Immersion" : "Use Mixed Immersion", isOn: $useMixedImmersion)
                        .toggleStyle(.button)
                    if useMixedImmersion {
                        VStack {
                            Text("Cutoff Angle: \(Int(passthroughCutoffAngle))°")
                                .monospacedDigit()
                            Slider(value: $passthroughCutoffAngle, in: 0...180)
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
        .onChange(of: useMixedImmersion) { _, _ in
            immersionStyle = useMixedImmersion ? .mixed : .full
            if immersionStyle is FullImmersionStyle {
                rendererConfiguration.immersionStyle = .full
            } else {
                rendererConfiguration.immersionStyle = .mixed
            }
        }
        .onChange(of: passthroughCutoffAngle) { oldValue, newValue in
            rendererConfiguration.portalCutoffAngle = newValue
        }
    }
}

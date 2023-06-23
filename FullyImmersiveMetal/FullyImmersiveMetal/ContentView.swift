import SwiftUI
import RealityKit

struct ContentView: View {
    @State var showImmersiveSpace = false
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        VStack {
            Toggle(showImmersiveSpace ? "Exit Immersive Space" : "Launch Immersive Space", isOn: $showImmersiveSpace)
                .toggleStyle(.button)
        }
        .padding()
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}

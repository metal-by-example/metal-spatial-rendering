import SwiftUI
import CompositorServices

struct MetalLayerConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities,
                           configuration: inout LayerRenderer.Configuration)
    {
        let supportsFoveation = capabilities.supportsFoveation
        let supportedLayouts = capabilities.supportedLayouts(options: supportsFoveation ? [.foveationEnabled] : [])
        
        // The device supports the `dedicated` and `layered` layouts, and optionally `shared` when foveation is disabled
        // The simulator supports the `dedicated` and `shared` layouts.
        // However, since we use vertex amplification to implement shared rendering, it won't work on the simulator in this project.
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .dedicated
        configuration.isFoveationEnabled = supportsFoveation
        configuration.colorFormat = .rgba16Float
    }
}

@main
struct FullyImmersiveMetalApp: App {
    @State var immersionStyle: (any ImmersionStyle) = FullImmersionStyle.full
    @State var rendererConfig = SRConfiguration(immersionStyle: .full)

    var body: some Scene {
        WindowGroup {
            ContentView($immersionStyle, rendererConfig)
                .frame(minWidth: 480, maxWidth: 480, minHeight: 200, maxHeight: 320)
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "ImmersiveSpace") {
            CompositorLayer(configuration: MetalLayerConfiguration()) { layerRenderer in
                SpatialRenderer_InitAndRun(layerRenderer, rendererConfig)
            }
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed, .full)
    }
}

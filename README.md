# Immersive Spatial Rendering with Metal in visionOS

This sample is a minimal example of rendering a immersive spatial experience with Metal, ARKit, and visionOS Compositing Services.

![Example screenshot of spatial rendering](screenshots/01.png)

When running on the Simulator, the app uses the [`.dedicated`](https://developer.apple.com/documentation/compositorservices/layerrenderer/layout/dedicated) layout. When running on an Apple Vision Pro, the app uses the [`.layered`](https://developer.apple.com/documentation/compositorservices/layerrenderer/layout/layered) layout along with [Metal vertex amplification](https://developer.apple.com/documentation/metal/render_passes/improving_rendering_performance_with_vertex_amplification) to efficiently render both stereo views in a single pass.

When running on a visionOS 2 simulator or device, the app enables the [mixed immersion style](https://developer.apple.com/documentation/swiftui/immersionstyle/mixed) and enables the user to progressively select how much of the real world is visible via passthrough.
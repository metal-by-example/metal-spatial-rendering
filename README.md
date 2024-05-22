# Immersive Spatial Rendering with Metal in visionOS

This sample is a minimal example of rendering a fully immersive spatial experience with Metal, ARKit, and visionOS Compositing Services.

Modify the [`layout` property of `LayerRenderer.Configuration` in 'App.swift'][1] to try different compositing modes:

* `dedicated` renders the scene in two passes to two different textures. It is supported by both the device and the simulator.

* `layered` renders the scene in a single pass to a single array texture by setting `render_target_array_index` in the vertex shader. It is supported only by the device.

* `shared` renders the scene in a single pass to a single texture by setting `viewport_array_index` in the vertex shader. It is supported only by the simulator.

![Example screenshot of spatial rendering](screenshots/01.png)

[1]: ./FullyImmersiveMetal/FullyImmersiveMetal/App.swift#L13

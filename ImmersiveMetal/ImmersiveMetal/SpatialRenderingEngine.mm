#include "SpatialRenderingEngine.h"
#include "SpatialRenderer.h"
#include "ShaderTypes.h"
#include "Mesh.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ARKit/ARKit.h>
#import <Spatial/Spatial.h>

@implementation SRConfiguration

- (instancetype)initWithImmersionStyle:(SRImmersionStyle)immersionStyle {
    if (self = [super init]) {
        _immersionStyle = immersionStyle;
        _portalCutoffAngle = 180.0f;
    }
    return self;
}

- (instancetype)init {
    return [self initWithImmersionStyle:SRImmersionStyleFull];
}

@end

class SpatialRenderingEngine {
public:
    SpatialRenderingEngine(cp_layer_renderer_t layerRenderer, SRConfiguration *configuration) :
        _layerRenderer(layerRenderer)
    {
        _renderer = std::make_unique<SpatialRenderer>(layerRenderer, configuration);
        runWorldTrackingARSession();
    }

    ~SpatialRenderingEngine() {
        ar_session_stop(_arSession);
    }

    void runLoop() {
        while (_running) {
            @autoreleasepool {
                switch (cp_layer_renderer_get_state(_layerRenderer)) {
                    case cp_layer_renderer_state_paused:
                        cp_layer_renderer_wait_until_running(_layerRenderer);
                        break;
                        
                    case cp_layer_renderer_state_running:
                        renderFrame();
                        break;
                        
                        
                    case cp_layer_renderer_state_invalidated:
                        _running = false;
                        break;
                }
            }
        }
    }

    void renderFrame() {
        cp_frame_t frame = cp_layer_renderer_query_next_frame(_layerRenderer);
        if (frame == nullptr) {
            return;
        }

        cp_frame_timing_t timing = cp_frame_predict_timing(frame);
        if (timing == nullptr) {
            return;
        }

        cp_frame_start_update(frame);
        
        //gather_inputs(engine, timing);
        //update_frame(engine, timing, input_state);

        cp_frame_end_update(frame);
        
        cp_time_wait_until(cp_frame_timing_get_optimal_input_time(timing));
        
        cp_frame_start_submission(frame);
        cp_drawable_t drawable = cp_frame_query_drawable(frame);
        if (drawable == nullptr) {
            return;
        }

        cp_frame_timing_t actualTiming = cp_drawable_get_frame_timing(drawable);
        ar_device_anchor_t anchor = createPoseForTiming(actualTiming);
        cp_drawable_set_device_anchor(drawable, anchor);

        _renderer->drawAndPresent(frame, drawable);

        cp_frame_end_submission(frame);
    }

private:
    void runWorldTrackingARSession() {
        ar_world_tracking_configuration_t worldTrackingConfiguration = ar_world_tracking_configuration_create();
        _worldTrackingProvider = ar_world_tracking_provider_create(worldTrackingConfiguration);

        ar_data_providers_t dataProviders = ar_data_providers_create_with_data_providers(_worldTrackingProvider, nil);

        _arSession = ar_session_create();
        ar_session_run(_arSession, dataProviders);
    }

    ar_device_anchor_t createPoseForTiming(cp_frame_timing_t timing) {
        ar_device_anchor_t outAnchor = ar_device_anchor_create();
        cp_time_t presentationTime = cp_frame_timing_get_presentation_time(timing);
        CFTimeInterval queryTime = cp_time_to_cf_time_interval(presentationTime);
        ar_device_anchor_query_status_t status = ar_world_tracking_provider_query_device_anchor_at_timestamp(_worldTrackingProvider, queryTime, outAnchor);
        if (status != ar_device_anchor_query_status_success) {
            NSLog(@"Failed to get estimated pose from world tracking provider for presentation timestamp %0.3f", queryTime);
        }
        return outAnchor;
    }

    ar_session_t _arSession;
    ar_world_tracking_provider_t _worldTrackingProvider;
    cp_layer_renderer_t _layerRenderer;
    std::unique_ptr<SpatialRenderer> _renderer;
    bool _running = true;
};

@interface RenderThread : NSThread {
    cp_layer_renderer_t _layerRenderer;
    std::unique_ptr<SpatialRenderingEngine> _engine;
}

- (instancetype)initWithLayerRenderer:(cp_layer_renderer_t)layerRenderer
                        configuration:(SRConfiguration *)configuration;

@end

@implementation RenderThread

- (instancetype)initWithLayerRenderer:(cp_layer_renderer_t)layerRenderer
                        configuration:(SRConfiguration *)configuration
{
    if (self = [self init]) {
        _layerRenderer = layerRenderer;
        _engine = std::make_unique<SpatialRenderingEngine>(layerRenderer, configuration);
    }
    return self;
}

- (void)main {
    _engine->runLoop();
}

@end

void SpatialRenderer_InitAndRun(cp_layer_renderer_t layerRenderer, SRConfiguration *configuration) {
    RenderThread *renderThread = [[RenderThread alloc] initWithLayerRenderer:layerRenderer configuration:configuration];
    renderThread.name = @"Spatial Renderer Thread";
    [renderThread start];
}

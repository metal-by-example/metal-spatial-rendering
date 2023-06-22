
#include "SpatialRenderingEngine.h"
#include "SpatialRenderer.h"
#include "ShaderTypes.h"
#include "Mesh.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ARKit/ARKit.h>
#import <Spatial/Spatial.h>

class SpatialRenderingEngine {
public:
    static void run(cp_layer_renderer_t layerRenderer) {
        auto engine = std::make_unique<SpatialRenderingEngine>(layerRenderer);
        engine->runLoop();
    }

    SpatialRenderingEngine(cp_layer_renderer_t layerRenderer) :
        _layerRenderer(layerRenderer)
    {
        _renderer = std::make_unique<SpatialRenderer>(layerRenderer);
        runWorldTrackingARSession();
    }

    ~SpatialRenderingEngine() {
        ar_session_stop_all_data_providers(_arSession);
    }

    void runLoop() {
        while (_running)
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
        ar_pose_t pose = createPoseForTiming(actualTiming);
        cp_drawable_set_ar_pose(drawable, pose);

        _renderer->drawAndPresent(frame, drawable);

        cp_frame_end_submission(frame);
    }

private:
    void runWorldTrackingARSession() {
        ar_world_tracking_configuration_t worldTrackingConfiguration = ar_world_tracking_configuration_create();
        _worldTrackingProvider = ar_world_tracking_provider_create(worldTrackingConfiguration);

        ar_data_providers_t dataProviders = ar_data_providers_create_with_providers(_worldTrackingProvider, nil);

        _arSession = ar_session_create();
        ar_session_run(_arSession, dataProviders);
    }

    ar_pose_t createPoseForTiming(cp_frame_timing_t timing) {
        ar_pose_t outPose = ar_pose_create();
        cp_time_t presentationTime = cp_frame_timing_get_presentation_time(timing);
        CFTimeInterval queryTime = cp_time_to_cf_time_interval(presentationTime);
        ar_pose_status_t status = ar_world_tracking_provider_query_pose_at_timestamp(_worldTrackingProvider, queryTime, outPose);
        if (status != ar_pose_status_success) {
            NSLog(@"Failed to get estimated pose from world tracking provider for presentation timestamp %0.3f", queryTime);
        }
        return outPose;
    }

    ar_session_t _arSession;
    ar_world_tracking_provider_t _worldTrackingProvider;
    cp_layer_renderer_t _layerRenderer;
    std::unique_ptr<SpatialRenderer> _renderer;
    bool _running = true;
};

@interface RenderThread : NSThread {
    cp_layer_renderer_t _layerRenderer;
}

- (instancetype)initWithLayerRenderer:(cp_layer_renderer_t)layerRenderer;

@end

@implementation RenderThread

- (instancetype)initWithLayerRenderer:(cp_layer_renderer_t)layerRenderer {
    if (self = [self init]) {
        _layerRenderer = layerRenderer;
    }
    return self;
}

- (void)main {
    SpatialRenderingEngine::run(_layerRenderer);
}

@end

void SpatialRenderer_InitAndRun(cp_layer_renderer_t layerRenderer) {
    RenderThread *renderThread = [[RenderThread alloc] initWithLayerRenderer:layerRenderer];
    renderThread.name = @"Spatial Renderer Thread";
    [renderThread start];
}

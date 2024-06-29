#pragma once

#import <Foundation/Foundation.h>
#import <CompositorServices/CompositorServices.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SRImmersionStyle) {
    SRImmersionStyleFull,
    SRImmersionStyleMixed,
};

// A type for communicating immersion style changes from SwiftUI views to the low-level rendering layer
@interface SRConfiguration : NSObject
@property (assign) SRImmersionStyle immersionStyle;
@property (assign) CGFloat portalCutoffAngle;
- (instancetype)initWithImmersionStyle:(SRImmersionStyle)immersionStyle;
@end

#if __cplusplus
extern "C" {
#endif

void SpatialRenderer_InitAndRun(cp_layer_renderer_t layerRenderer, SRConfiguration *configuration);

#if __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

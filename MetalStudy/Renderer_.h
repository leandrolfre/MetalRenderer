//
//  Renderer.h
//  MetalStudy
//
//  Created by Leandro Freire on 23/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end


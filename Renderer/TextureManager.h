//
//  TextureManager.h
//  MetalStudy
//
//  Created by Leandro Freire on 15/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <MetalKit/MetalKit.h>

@interface TextureManager : NSObject
{
    NSMutableDictionary* _textureCache;
}
+(id)sharedManager;
-(id<MTLTexture>) loadTexture:(NSString*) imageName device:(id<MTLDevice>)device SRGB:(BOOL) srgb;

@end

//
//  TextureManager.m
//  MetalStudy
//
//  Created by Leandro Freire on 15/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "TextureManager.h"

@implementation TextureManager

static TextureManager *sharedMyManager = nil;

-(instancetype)init
{
    if (self = [super init])
    {
        _textureCache = [[NSMutableDictionary dictionary] retain];
    }
    return self;
}

+(id)sharedManager {
    
        if(!sharedMyManager)
            sharedMyManager = [[super allocWithZone:NULL] init];
    
    return sharedMyManager;
}

-(id<MTLTexture>) loadTexture:(NSString*) imageName device:(id<MTLDevice>)device SRGB:(BOOL) srgb
{
    MTKTextureLoader* loader = [[[MTKTextureLoader alloc] initWithDevice:device] autorelease];
    
    NSURL* assetUrl = [[NSBundle mainBundle] URLForResource:[imageName substringToIndex:[imageName rangeOfString:@"."].location] withExtension:@"tga"];
    id<MTLTexture> texture = [_textureCache objectForKey:imageName];
    if (!texture)
    {
        texture = [loader newTextureWithContentsOfURL:assetUrl
                                              options:@{ MTKTextureLoaderOptionOrigin : MTKTextureLoaderOriginBottomLeft,
                                                         MTKTextureLoaderOptionSRGB : @(srgb),
                                                         MTKTextureLoaderOptionGenerateMipmaps : @YES
                                                         }
                                                error:nil];
        _textureCache[imageName] = texture;
    }
    
    
    return texture;
}

@end

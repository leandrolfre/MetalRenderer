//
//  Primitive.h
//  MetalStudy
//
//  Created by Leandro Freire on 27/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MDLMesh;
@class MTLDevice;

@interface Primitive : NSObject
{
    
}

+(MDLMesh*)makeCube:(id)device withSize:(float)size;
+(MDLMesh*)makeSphere:(id)device withSize:(float)size;
@end

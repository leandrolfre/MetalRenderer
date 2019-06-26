//
//  GameViewController.h
//  MetalStudy
//
//  Created by Leandro Freire on 23/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Renderer;

// Our macOS view controller.
@interface GameViewController : NSViewController
{
    Renderer* _renderer;
}

@end

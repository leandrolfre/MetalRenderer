//
//  GameViewController.h
//  MetalStudyIOS
//
//  Created by Leandro Freire on 29/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Renderer;

// Our iOS view controller
@interface GameViewController : UIViewController
{
    Renderer* _renderer;
    CGFloat _previousScale;
}

@end

//
//  GameViewController.m
//  MetalStudyIOS
//
//  Created by Leandro Freire on 29/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "GameViewController.h"
#import "Renderer.h"
#import <UIKit/UIKit.h>

@implementation GameViewController
{
    MTKView *_view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //init metal
    _view = (MTKView *)self.view;
    _renderer = [[Renderer alloc] initWithView:(MTKView *)self.view mode:RenderModeForward];
    _previousScale = 1.0;
    [_view addGestureRecognizer:[[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)] autorelease]];
    [_view addGestureRecognizer:[[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)] autorelease]];
}

-(void)handleGesture:(UIPanGestureRecognizer*)gesture
{
    CGPoint translation = [gesture translationInView:_view];
    [_renderer lookAt:translation];
    [gesture setTranslation:CGPointZero inView:_view];
}

-(void)handlePinch:(UIPinchGestureRecognizer*)gesture
{
    float sensitivity = 0.2f;
    CGFloat delta = (gesture.scale - _previousScale) * -1.0;
    [_renderer zoomCam:delta sensitivity:sensitivity];
    _previousScale = gesture.scale;
    
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        _previousScale = 1.0;
    }
}

@end

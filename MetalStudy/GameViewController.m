//
//  GameViewController.m
//  MetalStudy
//
//  Created by Leandro Freire on 23/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "GameViewController.h"
#import "Renderer.h"
#import <AppKit/NSPanGestureRecognizer.h>

@implementation GameViewController
{
    MTKView *_view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //init metal
    _view = (MTKView *)self.view;
    _renderer = [[Renderer alloc] initWithView:(MTKView *)self.view];
    
    NSPanGestureRecognizer* gesture = [[NSPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    [_view addGestureRecognizer:gesture];
}

-(void)handleGesture:(NSPanGestureRecognizer*)gesture
{
    CGPoint translation = [gesture translationInView:_view];
    //NSLog(@"Recgnizer %f %f", translation.x, translation.y);
    [_renderer lookAt:translation];
    [gesture setTranslation:CGPointZero inView:_view];
}

- (void)scrollWheel:(NSEvent *)event
{
    float sensitivity = 0.01f;
    [_renderer zoomCam:event.scrollingDeltaY sensitivity:sensitivity];
}

@end

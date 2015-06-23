//
//  MainScene.m
//  Cocos2dPhysicsPart2
//
//  Created by Vitaliy Voronok on 6/23/15.
//  Copyright (c) 2015 Vitaliy Voronok. All rights reserved.
//

#import "MainScene.h"

@implementation MainScene

#pragma mark -
#pragma mark Class Methods

+ (CCScene *)scene {
    // 'scene' is an autorelease object.
    CCScene *scene = [CCScene node];
    
    // 'layer' is an autorelease object.
    MainScene *layer = [self node];
    
    // add layer as a child to scene
    [scene addChild:layer];
    
    // return the scene
    return scene;
}

@end

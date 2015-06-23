//
//  MainScene.m
//  Cocos2dPhysicsPart2
//
//  Created by Vitaliy Voronok on 6/23/15.
//  Copyright (c) 2015 Vitaliy Voronok. All rights reserved.
//

#import "MainScene.h"

#import "Box2D.h"
#import "GLES-Render.h"

#define isIPad UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
#define PTM_RATIO (isIPad ? 64 : 32)

@interface MainScene ()
@property (nonatomic, assign)   CGSize  winSize;

@property (nonatomic, assign)   b2World         *physicsWorld;
@property (nonatomic, assign)   GLESDebugDraw   *debugDraw;

- (void)setupPhysics;

@end

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

#pragma mark -
#pragma mark Initialization and Dealocation

- (void)dealloc {
    delete self.physicsWorld;
}

- (id)init {
    self = [super init];
    
    if (self) {
        self.winSize = [CCDirector sharedDirector].winSize;
        
        NSLog(@"---- %@", NSStringFromCGSize(self.winSize));
        self.touchEnabled = YES;
        
        CCLayerColor *layerColor = [CCLayerColor layerWithColor:ccc4(50, 45, 30, 255)];
        [self addChild:layerColor z:-10];
        
        [self setupPhysics];
        
//        [self scheduleUpdate];
//        [self schedule:@selector(tick:)];
    }
    
    return self;
}

#pragma mark -
#pragma mark Accessors

#pragma mark -
#pragma mark Touch Handle

#pragma mark -
#pragma mark Life Cycle

- (void)update:(ccTime)delta {
    
}

// Debug Draw Physics body
#if DEBUG
- (void)draw {
    [super draw];
    
    if (self.physicsWorld != NULL) {
        ccGLEnableVertexAttribs(kCCVertexAttribFlag_Position);
        kmGLPushMatrix();
        self.physicsWorld  -> DrawDebugData();
        kmGLPopMatrix();
    }
}
#endif

#pragma mark -
#pragma mark Public

#pragma mark -
#pragma mark Private

- (void)setupPhysics {
    b2Vec2 gravity = b2Vec2(0.0f, -1.0f);
    self.physicsWorld = new b2World(gravity);
    self.physicsWorld->DrawDebugData();
    
    //************** Physic border around screan *******************//
    
    // for the screenBorder body we'll need these values
    CGSize screenSize = self.winSize;
    float widthInMeters = screenSize.width / PTM_RATIO;
    float heightInMeters = screenSize.height / PTM_RATIO;
    b2Vec2 lowerLeftCorner = b2Vec2(0, 0);
    b2Vec2 lowerRightCorner = b2Vec2(widthInMeters, 0);
    b2Vec2 upperLeftCorner = b2Vec2(0, heightInMeters);
    b2Vec2 upperRightCorner = b2Vec2(widthInMeters, heightInMeters);
    
    // static container body, with the collisions at screen borders
    b2BodyDef screenBorderDef;
    screenBorderDef.position.Set(0, 0);
    b2Body* screenBorderBody = self.physicsWorld->CreateBody(&screenBorderDef);
    b2EdgeShape screenBorderShape;
    
    // Create fixtures for the four borders (the border shape is re-used)
    screenBorderShape.Set(lowerLeftCorner, lowerRightCorner);
    screenBorderBody->CreateFixture(&screenBorderShape, 0);
    screenBorderShape.Set(lowerRightCorner, upperRightCorner);
    screenBorderBody->CreateFixture(&screenBorderShape, 0);
    screenBorderShape.Set(upperRightCorner, upperLeftCorner);
    screenBorderBody->CreateFixture(&screenBorderShape, 0);
    screenBorderShape.Set(upperLeftCorner, lowerLeftCorner);
    screenBorderBody->CreateFixture(&screenBorderShape, 0);
    
    //************************************************************//
    
    _debugDraw = new GLESDebugDraw(PTM_RATIO);
    self.physicsWorld->SetDebugDraw(_debugDraw);
    uint32 flags = 0;
    flags += b2Draw::e_shapeBit;
    //    flags += b2Draw::e_jointBit;
    //    flags += b2Draw::e_aabbBit;
    //    flags += b2Draw::e_pairBit;
    //    flags += b2Draw::e_centerOfMassBit;
    _debugDraw->SetFlags(flags);
}

@end

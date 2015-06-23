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
@property (nonatomic, assign)   CGSize          winSize;
@property (nonatomic, assign)   NSUInteger      screenScale;

@property (nonatomic, assign)   b2World         *physicsWorld;
@property (nonatomic, assign)   GLESDebugDraw   *debugDraw;

@property (nonatomic, assign)   CCNode          *gameNode;
@property (nonatomic, strong)   CCSprite        *catNode;
@property (nonatomic, strong)   CCSprite        *bedNode;
@property (nonatomic, assign)   NSUInteger      currentLevel;

- (void)setupPhysics;
- (void)initializeScene;
- (void)addCatBed;

- (NSString *)fileNameWithScaleFromName:(NSString *)name;

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
        self.screenScale = [[UIScreen mainScreen] scale];
        
        self.gameNode = [CCNode node];
        self.gameNode.zOrder = -1;
        [self addChild:self.gameNode];
        
        
        NSLog(@"---- %@", NSStringFromCGSize(self.winSize));
        self.touchEnabled = YES;
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"CocosSprites.plist"];
        CCSpriteBatchNode *spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"CocosSprites.png"];
        
        [self addChild:spriteSheet];
        
        [self setupPhysics];
        
        [self initializeScene];
        
        self.currentLevel = 1;
        [self setupLevel:self.currentLevel];
        
//        [self scheduleUpdate];
        [self schedule:@selector(tick:)];
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

- (void)tick:(ccTime) dt {
    self.physicsWorld->Step(dt, 10, 10);
    
    b2Body *body = self.physicsWorld->GetBodyList();
    
    while (body) {
        CCSprite *sprite = (__bridge CCSprite *)body->GetUserData();
        
        b2Vec2 position = body->GetPosition();
        CGPoint spritePosition = ccp(position.x * PTM_RATIO, position.y * PTM_RATIO);
        
        if (spritePosition.x < -self.winSize.width
            || spritePosition.y < -self.winSize.height
            || spritePosition.x > 2 * self.winSize.width
            || spritePosition.y > 2 * self.winSize.height)
        {
            b2Body *nextBody = body->GetNext();
            
            self.physicsWorld->DestroyBody(body);
            [sprite removeFromParent];
            body = nextBody;
        } else {
            sprite.position = spritePosition;
            sprite.rotation = -1 * CC_RADIANS_TO_DEGREES(body->GetAngle());
            body = body->GetNext();
        }
    }
}

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
//        flags += b2Draw::e_jointBit;
//        flags += b2Draw::e_aabbBit;
//        flags += b2Draw::e_pairBit;
//        flags += b2Draw::e_centerOfMassBit;
    _debugDraw->SetFlags(flags);
}

- (void)initializeScene {
    NSString *spriteName = [self fileNameWithScaleFromName:@"background"];
    CCSprite *background = [CCSprite spriteWithFile:spriteName];

    background.position = CGPointMake(self.winSize.width / 2, self.winSize.height / 2);
    background.zOrder = -100;
    
    [self addChild:background];
    
    [self addCatBed];
}

- (void)addCatBed {
    NSString *spriteName = [self fileNameWithScaleFromName:@"cat_bed"];
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:spriteName];
    
    CCSprite *bed = [CCSprite spriteWithSpriteFrame:frame];
    
    bed.position = CGPointMake(270, 15);
    bed.zOrder = -10;
    
    [self addChild:bed];
    
    self.bedNode = bed;

    b2BodyDef physicsBodyDef;
    
    physicsBodyDef.type = b2_staticBody;
    physicsBodyDef.position.Set(bed.position.x / PTM_RATIO, bed.position.y / PTM_RATIO);
    
    physicsBodyDef.userData = (__bridge void *)bed;
    
    b2Body *physicsBody = self.physicsWorld->CreateBody(&physicsBodyDef);
    
    b2PolygonShape spriteShape;
    spriteShape.SetAsBox(self.scaleX * 20 / PTM_RATIO, self.scaleY * 10 / PTM_RATIO); // (30,40)
    
    physicsBody->CreateFixture(&spriteShape, 0);
}

- (void)addCatAtPosition:(CGPoint)position {
    NSString *spriteName = [self fileNameWithScaleFromName:@"cat_sleepy"];
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:spriteName];
    
    CCSprite *catNode = [CCSprite spriteWithSpriteFrame:frame];
    catNode.position = position;
    [self.gameNode addChild:catNode];
    
    self.catNode = catNode;

    
    b2BodyDef physicsBodyDef;
    
    physicsBodyDef.type = b2_dynamicBody;
    physicsBodyDef.position.Set(catNode.position.x / PTM_RATIO, catNode.position.y / PTM_RATIO);
    
    physicsBodyDef.userData = (__bridge void *)catNode;
    
    b2Body *physicsBody = self.physicsWorld->CreateBody(&physicsBodyDef);
    
    b2PolygonShape spriteShape;
    spriteShape.SetAsBox((catNode.contentSize.width - 40) / PTM_RATIO / 2,
                         (catNode.contentSize.height - 10) / PTM_RATIO / 2);
    
    physicsBody->CreateFixture(&spriteShape, 0);
//    b2FixtureDef spriteShapeDef;
//    spriteShapeDef.shape = &spriteShape;
//    spriteShapeDef.density = 10.00;
//    spriteShapeDef.friction = .2f;
//    spriteShapeDef.restitution = .8f;
//    
//    physicsBody->CreateFixture(&spriteShapeDef);
}

- (NSString *)fileNameWithScaleFromName:(NSString *)name {
    return [NSString stringWithFormat:@"%@%@.png", name, (self.screenScale != 1) ? @"@2x" : @""];
}

- (void)setupLevel:(int)levelNum {
    //load the plist file
    NSString *fileName = [NSString stringWithFormat:@"level%i",levelNum];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName
                                                         ofType:@"plist"];
    
    NSDictionary *level = [NSDictionary dictionaryWithContentsOfFile:filePath];
    
    [self addCatAtPosition: CGPointFromString(level[@"catPosition"])];
}

@end

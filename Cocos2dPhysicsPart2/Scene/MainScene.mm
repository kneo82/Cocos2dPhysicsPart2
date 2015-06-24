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
#import "CCPhysicsSprite.h"

#import "SimpleAudioEngine.h"

typedef NS_OPTIONS(uint32_t, CNPhysicsCategory) {
    CNPhysicsCategoryCat = 1 << 0, // 0001 = 1
    CNPhysicsCategoryBlock = 1 << 1, // 0010 = 2
    CNPhysicsCategoryBed = 1 << 2, // 0100 = 4
};

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

- (CCPhysicsSprite *)spriteWithName:(NSString *)name
                               rect:(CGRect)rect
                           bodyType:(b2BodyType)type
                    categoryBitMask:(CNPhysicsCategory)categoryMask
                   collisionBitMask:(CNPhysicsCategory)collisionMask;

- (void)setupPhysics;
- (void)initializeScene;
- (void)addCatBed;

- (NSString *)fileNameWithScaleFromName:(NSString *)name;

- (void)setupLevel:(int)levelNum;
- (void)addBlocksFromArray:(NSArray*)blocks;
- (void)tick:(ccTime)dt;
- (void)addCatAtPosition:(CGPoint)position;
- (CCSprite *)addBlockWithRect:(CGRect)blockRect;

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
        [[SimpleAudioEngine sharedEngine] preloadBackgroundMusic:@"bgMusic.mp3"];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"pop.mp3"];
        [[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"bgMusic.mp3"];
        
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

- (void)registerWithTouchDispatcher {
    [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self priority:kCCMenuHandlerPriority swallowsTouches:NO];
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    NSLog(@"ccTouchBegan");

    CGPoint location = [touch locationInView:[touch view]];
    location = [[CCDirector sharedDirector] convertToGL:location];
    
    location = [self convertToNodeSpace:location];
    
    b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
    
    for (int i = 0; i < self.gameNode.children.count; i++) {
        CCNode *node = [self.gameNode.children objectAtIndex:i];
        
        if ([node isMemberOfClass:[CCPhysicsSprite class]]) {
            CCPhysicsSprite *sprite = (CCPhysicsSprite *)node;
            b2Body *body = sprite.b2Body;
            
            for(b2Fixture *fixture = body->GetFixtureList(); fixture; fixture=fixture->GetNext()) {
                b2Filter filter = fixture->GetFilterData();
                if (filter.categoryBits == CNPhysicsCategoryBlock && fixture->TestPoint(locationWorld)) {
                    [self.gameNode removeChild:sprite];
                    
                    self.physicsWorld -> DestroyBody(body);
                    [[SimpleAudioEngine sharedEngine] playEffect:@"pop.mp3" pitch:1.0f pan:0.0f gain:1.0f];
                    
                    return YES;
                }
            }

        }
    }

    return YES;
}

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

- (void)tick:(ccTime)dt {
    int32 velocityIterations = 8;
    int32 positionIterations = 1;

    self.physicsWorld->Step(dt, velocityIterations, positionIterations);
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
    NSString *name = [self fileNameWithScaleFromName:@"cat_bed"];
    
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:name];
    
    CGRect bodyRect = frame.rect;
    bodyRect.origin = CGPointMake(270, 15);
    bodyRect.size = CGSizeMake(40, 30);
    
    CCSprite *bed = [self spriteWithName:@"cat_bed"
                                        rect:bodyRect
                                    bodyType:b2_dynamicBody
                             categoryBitMask:CNPhysicsCategoryBed
                            collisionBitMask:0];

    bed.zOrder = -10;
    
    [self addChild:bed];
    
    self.bedNode = bed;
}

- (void)addCatAtPosition:(CGPoint)position {
    NSString *name = [self fileNameWithScaleFromName:@"cat_sleepy"];
    
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:name];
    CGRect bodyRect = frame.rect;
    bodyRect.origin = position;
    bodyRect.size = CGSizeMake((bodyRect.size.width - 40), (bodyRect.size.height - 10));
    
    CCSprite *catNode = [self spriteWithName:@"cat_sleepy"
                                        rect:bodyRect
                                    bodyType:b2_dynamicBody
                             categoryBitMask:CNPhysicsCategoryCat
                            collisionBitMask:CNPhysicsCategoryBlock | CNPhysicsCategoryCat];
    
    [self.gameNode addChild:catNode];
    
    self.catNode = catNode;
}

- (void)addBlocksFromArray:(NSArray*)blocks {
    for (NSDictionary *block in blocks) {
        CCSprite *blockSprite = [self addBlockWithRect:CGRectFromString(block[@"rect"])];
        [self.gameNode addChild:blockSprite]; }
}

- (CCSprite *)addBlockWithRect:(CGRect)blockRect {
    NSString *textureName = [NSString stringWithFormat:@"%.fx%.f",
                                                         blockRect.size.width,
                                                         blockRect.size.height];
    
    CCSprite *sprite = [self spriteWithName:textureName
                                       rect:blockRect
                                   bodyType:b2_dynamicBody
                            categoryBitMask:CNPhysicsCategoryBlock
                           collisionBitMask:CNPhysicsCategoryBlock | CNPhysicsCategoryCat];
    
    return sprite;
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
    
    [self addBlocksFromArray:level[@"blocks"]];
}

- (CCPhysicsSprite *)spriteWithName:(NSString *)name
                               rect:(CGRect)rect
                           bodyType:(b2BodyType)type
                    categoryBitMask:(CNPhysicsCategory)categoryMask
                   collisionBitMask:(CNPhysicsCategory)collisionMask
{
    NSString *textureName = [self fileNameWithScaleFromName:name];
    
    CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:textureName];
    
    CCPhysicsSprite *sprite = [CCPhysicsSprite spriteWithSpriteFrame:frame];
    
    b2BodyDef bodyDef;
    bodyDef.type = type;
    
    bodyDef.position.Set(rect.origin.x / PTM_RATIO, rect.origin.y / PTM_RATIO);
    b2Body *body = self.physicsWorld->CreateBody(&bodyDef);
    
    // Define another box shape for our dynamic body.
    b2PolygonShape spriteShape;
    spriteShape.SetAsBox(rect.size.width / PTM_RATIO / 2, rect.size.height / PTM_RATIO / 2);
    
    // Define the dynamic body fixture.
    b2FixtureDef fixtureDef;
    
    if (collisionMask > 0) {
        fixtureDef.filter.maskBits = collisionMask;
    }
    
    fixtureDef.filter.categoryBits = categoryMask;
    
    fixtureDef.shape = &spriteShape;
    fixtureDef.density = 10.0f;
    fixtureDef.friction = 0.5f;
    fixtureDef.restitution = 0.2f;
    body->CreateFixture(&fixtureDef);
    
    //    body->CreateFixture(&spriteShape, 0);
    
    [sprite setPTMRatio:PTM_RATIO];
    [sprite setB2Body:body];
    sprite.position = rect.origin;
    
    return sprite;
}

@end
